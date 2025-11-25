defmodule ExTopology.Filtration do
  @moduledoc """
  Filtration construction for persistent homology.

  A filtration is a nested sequence of simplicial complexes:
  K₀ ⊆ K₁ ⊆ K₂ ⊆ ... ⊆ Kₙ

  Each complex Kᵢ is obtained by adding simplices at a given scale parameter ε.
  Persistent homology tracks how topological features (connected components,
  loops, voids) appear and disappear across this sequence.

  ## Supported Filtrations

  - **Vietoris-Rips**: Build simplices from ε-neighborhoods
  - **Čech**: Build simplices from ε-balls (approximated by VR)
  - **Alpha**: Build simplices from Delaunay triangulation (future)

  ## Examples

      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [0.5, 0.866]])
      filtration = ExTopology.Filtration.vietoris_rips(points, max_epsilon: 2.0, max_dimension: 2)
      # Returns list of {scale, simplex} pairs ordered by appearance time
  """

  alias ExTopology.{Distance, Simplex}

  @type simplex :: Simplex.simplex()
  @type scale :: float()
  @type filtration_step :: {scale(), simplex()}
  @type filtration :: [filtration_step()]

  @doc """
  Constructs a Vietoris-Rips filtration from point cloud data.

  The Vietoris-Rips complex at scale ε includes a k-simplex [v₀, ..., vₖ]
  if all pairwise distances d(vᵢ, vⱼ) ≤ ε.

  ## Parameters

  - `points` - Nx tensor of shape `{n, d}` representing n points in d dimensions
  - `opts` - Keyword list:
    - `:max_epsilon` - Maximum scale parameter (default: auto-computed from data)
    - `:max_dimension` - Maximum simplex dimension (default: 2)
    - `:num_steps` - Number of filtration steps (default: 50)
    - `:metric` - Distance metric (default: `:euclidean`)

  ## Returns

  - List of `{epsilon, simplex}` tuples sorted by epsilon (birth time)

  ## Examples

      iex> points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [0.0, 1.0]])
      iex> filtration = ExTopology.Filtration.vietoris_rips(points, max_epsilon: 2.0, max_dimension: 1)
      iex> length(filtration) > 0
      true

  ## Mathematical Background

  The Vietoris-Rips complex is built by:
  1. Computing pairwise distances between all points
  2. For each ε, including all simplices where max pairwise distance ≤ ε
  3. Assigning birth time = max distance among simplex vertices
  """
  @spec vietoris_rips(Nx.Tensor.t(), keyword()) :: filtration()
  def vietoris_rips(points, opts \\ []) do
    # Extract options
    max_dim = Keyword.get(opts, :max_dimension, 2)
    metric = Keyword.get(opts, :metric, :euclidean)

    # Compute distance matrix
    dist_matrix = Distance.pairwise(points, metric: metric)

    # Get vertices (point indices)
    n = Nx.axis_size(points, 0)
    vertices = Enum.to_list(0..(n - 1))

    # Build filtration by iteratively adding simplices
    build_vr_filtration(dist_matrix, vertices, max_dim)
  end

  @doc """
  Extracts the simplicial complex at a specific filtration value.

  ## Parameters

  - `filtration` - A filtration (list of {scale, simplex} pairs)
  - `epsilon` - The scale parameter

  ## Returns

  - Map of dimension to list of simplices (all simplices with birth time ≤ epsilon)

  ## Examples

      iex> filtration = [{0.0, [0]}, {0.0, [1]}, {1.0, [0, 1]}]
      iex> ExTopology.Filtration.complex_at(filtration, 0.5)
      %{0 => [[0], [1]]}

      iex> filtration = [{0.0, [0]}, {0.0, [1]}, {1.0, [0, 1]}]
      iex> ExTopology.Filtration.complex_at(filtration, 1.5)
      %{0 => [[0], [1]], 1 => [[0, 1]]}
  """
  @spec complex_at(filtration(), scale()) :: %{non_neg_integer() => [simplex()]}
  def complex_at(filtration, epsilon) do
    filtration
    |> Enum.filter(fn {scale, _simplex} -> scale <= epsilon end)
    |> Enum.group_by(
      fn {_scale, simplex} -> Simplex.dimension(simplex) end,
      fn {_scale, simplex} -> simplex end
    )
    |> Map.new()
  end

  @doc """
  Returns all critical values (birth times) in the filtration.

  ## Parameters

  - `filtration` - A filtration

  ## Returns

  - Sorted list of unique scale values

  ## Examples

      iex> filtration = [{0.0, [0]}, {1.0, [1]}, {1.0, [0, 1]}, {2.0, [0, 1, 2]}]
      iex> ExTopology.Filtration.critical_values(filtration)
      [0.0, 1.0, 2.0]
  """
  @spec critical_values(filtration()) :: [scale()]
  def critical_values(filtration) do
    filtration
    |> Enum.map(fn {scale, _} -> scale end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc """
  Builds a filtration from a weighted graph.

  Each edge has a weight representing its appearance time.
  Vertices appear at time 0, edges at their weight, and higher
  simplices at the maximum weight among their edges.

  ## Parameters

  - `graph` - A libgraph Graph struct with weighted edges
  - `opts` - Keyword list:
    - `:max_dimension` - Maximum simplex dimension (default: 2)

  ## Returns

  - Filtration list

  ## Examples

      iex> g = Graph.new() |> Graph.add_edge(0, 1, weight: 1.0) |> Graph.add_edge(1, 2, weight: 1.5)
      iex> filtration = ExTopology.Filtration.from_graph(g, max_dimension: 1)
      iex> Enum.any?(filtration, fn {scale, _} -> scale == 1.0 end)
      true
  """
  @spec from_graph(Graph.t(), keyword()) :: filtration()
  def from_graph(graph, opts \\ []) do
    max_dim = Keyword.get(opts, :max_dimension, 2)

    # Add vertices at time 0
    vertices = Graph.vertices(graph)
    vertex_steps = Enum.map(vertices, fn v -> {0.0, [v]} end)

    # Add edges at their weights
    edge_steps =
      graph
      |> Graph.edges()
      |> Enum.map(fn edge ->
        weight = edge.weight || 0.0
        simplex = Enum.sort([edge.v1, edge.v2])
        {weight, simplex}
      end)

    # Build higher dimensional simplices if requested
    all_steps = vertex_steps ++ edge_steps

    if max_dim > 1 do
      # Build clique complex and assign birth times
      higher_steps = build_higher_simplices(graph, max_dim)
      all_steps ++ higher_steps
    else
      all_steps
    end
    |> Enum.sort_by(fn {scale, _} -> scale end)
  end

  # Private helper functions

  defp build_vr_filtration(dist_matrix, vertices, max_dim) do
    # Start with 0-simplices (all vertices appear at time 0)
    vertex_steps = Enum.map(vertices, fn v -> {0.0, [v]} end)

    # Build 1-simplices (edges) if needed
    all_steps =
      if max_dim >= 1 do
        edge_steps =
          for i <- vertices,
              j <- vertices,
              i < j do
            distance = Nx.to_number(dist_matrix[i][j])
            {distance, Enum.sort([i, j])}
          end

        vertex_steps ++ edge_steps
      else
        vertex_steps
      end

    # Build higher-dimensional simplices if needed
    all_steps =
      if max_dim > 1 do
        higher_steps = build_higher_vr_simplices(dist_matrix, vertices, max_dim)
        all_steps ++ higher_steps
      else
        all_steps
      end

    Enum.sort_by(all_steps, fn {scale, _} -> scale end)
  end

  defp build_higher_vr_simplices(dist_matrix, vertices, max_dim) do
    # Build simplices dimension by dimension
    Enum.reduce(2..max_dim, [], fn dim, acc ->
      dim_simplices = generate_vr_simplices(dist_matrix, vertices, dim)
      acc ++ dim_simplices
    end)
  end

  defp generate_vr_simplices(dist_matrix, vertices, dim) do
    # Generate all combinations of (dim+1) vertices
    vertices
    |> combinations(dim + 1)
    |> Enum.map(fn simplex ->
      # Birth time is max pairwise distance
      birth_time = simplex_birth_time(dist_matrix, simplex)
      {birth_time, Enum.sort(simplex)}
    end)
  end

  defp simplex_birth_time(dist_matrix, vertices) do
    # Max pairwise distance among vertices
    pairs = combinations(vertices, 2)

    pairs
    |> Enum.map(fn [i, j] ->
      Nx.to_number(dist_matrix[i][j])
    end)
    |> Enum.max(fn -> 0.0 end)
  end

  defp build_higher_simplices(graph, max_dim) do
    # Build clique complex
    complex = Simplex.clique_complex(graph, max_dimension: max_dim)

    # Assign birth times based on edge weights
    for dim <- 2..max_dim,
        simplex <- Map.get(complex, dim, []) do
      birth = compute_simplex_birth(graph, simplex)
      {birth, simplex}
    end
  end

  defp compute_simplex_birth(graph, simplex) do
    # Birth time is max weight among all edges in the simplex
    pairs = combinations(simplex, 2)

    pairs
    |> Enum.map(fn [v1, v2] ->
      case Graph.edge(graph, v1, v2) || Graph.edge(graph, v2, v1) do
        nil -> :infinity
        edge -> edge.weight
      end
    end)
    |> Enum.reject(&(&1 == :infinity))
    |> Enum.max(fn -> 0.0 end)
  end

  defp combinations(_, 0), do: [[]]
  defp combinations([], _), do: []

  defp combinations([h | t], k) do
    for(rest <- combinations(t, k - 1), do: [h | rest]) ++ combinations(t, k)
  end

  @doc """
  Validates that a filtration is properly ordered.

  A valid filtration must have:
  1. Non-decreasing scale values
  2. Each simplex appears after all its faces

  ## Parameters

  - `filtration` - A filtration to validate

  ## Returns

  - `:ok` if valid
  - `{:error, reason}` if invalid

  ## Examples

      iex> valid = [{0.0, [0]}, {0.0, [1]}, {1.0, [0, 1]}]
      iex> ExTopology.Filtration.validate(valid)
      :ok

      iex> invalid = [{1.0, [0, 1]}, {2.0, [0]}]
      iex> ExTopology.Filtration.validate(invalid)
      {:error, "Simplex [0, 1] appears before its face [1]"}
  """
  @spec validate(filtration()) :: :ok | {:error, String.t()}
  def validate(filtration) do
    with :ok <- check_ordering(filtration),
         :ok <- check_faces(filtration) do
      :ok
    end
  end

  defp check_ordering(filtration) do
    scales = Enum.map(filtration, fn {scale, _} -> scale end)

    if scales == Enum.sort(scales) do
      :ok
    else
      {:error, "Filtration is not properly ordered by scale"}
    end
  end

  defp check_faces(filtration) do
    # Build set of simplices seen so far
    Enum.reduce_while(filtration, MapSet.new(), fn {_scale, simplex}, seen ->
      faces = Simplex.faces(simplex)

      missing_faces = Enum.reject(faces, fn face -> MapSet.member?(seen, face) end)

      if Enum.empty?(missing_faces) or Simplex.dimension(simplex) == 0 do
        {:cont, MapSet.put(seen, simplex)}
      else
        {:halt,
         {:error,
          "Simplex #{inspect(simplex)} appears before its face #{inspect(hd(missing_faces))}"}}
      end
    end)
    |> case do
      %MapSet{} -> :ok
      error -> error
    end
  end
end
