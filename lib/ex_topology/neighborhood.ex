defmodule ExTopology.Neighborhood do
  @moduledoc """
  Neighborhood graph construction from point clouds.

  This module constructs graphs from point data using various neighborhood
  definitions. The resulting libgraph structures can be analyzed using
  `ExTopology.Graph` for topological properties.

  ## Graph Types

  - **k-NN graph**: Connect each point to its k nearest neighbors
  - **ε-ball graph**: Connect points within distance ε of each other
  - **Mutual k-NN**: Connect only if both points are in each other's k-NN

  ## Usage

      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [0.5, 0.5], [5.0, 5.0]])

      # k-NN graph with k=2
      knn = ExTopology.Neighborhood.knn_graph(points, k: 2)
      ExTopology.Graph.beta_zero(knn)  # Number of components

      # ε-ball graph with radius 1.5
      eps = ExTopology.Neighborhood.epsilon_graph(points, epsilon: 1.5)
      ExTopology.Graph.beta_one(eps)   # Number of cycles

  ## Sparsity

  Neighborhood graphs are inherently sparse:
  - k-NN graph: O(nk) edges
  - ε-ball graph: Depends on ε and data distribution

  libgraph handles this efficiently with map-based adjacency.
  """

  alias ExTopology.Distance

  @type point_input :: Nx.Tensor.t() | [[number()]]
  @type graph :: Graph.t()

  @doc """
  Constructs a k-nearest neighbors graph.

  Each vertex is connected to its k nearest neighbors (excluding itself).
  The graph is undirected: if A is a neighbor of B, B connects to A.

  ## Parameters

  - `points` - Nx tensor of shape `{n, d}` or list of point lists
  - `opts` - Keyword list:
    - `:k` - Number of nearest neighbors (required)
    - `:metric` - Distance metric (default: `:euclidean`)
    - `:weighted` - Include edge weights (default: `false`)
    - `:mutual` - Only connect if mutual k-NN (default: `false`)

  ## Returns

  - Undirected libgraph `Graph.t()`

  ## Examples

      # Simple 2D points
      iex> points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [0.5, 1.0]])
      iex> g = ExTopology.Neighborhood.knn_graph(points, k: 1)
      iex> Graph.num_vertices(g)
      3
      iex> Graph.num_edges(g) >= 1
      true

      # With weights
      iex> points = Nx.tensor([[0.0, 0.0], [1.0, 0.0]])
      iex> g = ExTopology.Neighborhood.knn_graph(points, k: 1, weighted: true)
      iex> Graph.edges(g) |> hd() |> Map.get(:weight)
      1.0

  ## Complexity

  - Time: O(n² d) for distance computation + O(n k log n) for neighbor selection
  - Space: O(n²) for distance matrix, O(nk) for graph
  """
  @spec knn_graph(point_input(), keyword()) :: graph()
  def knn_graph(points, opts) do
    k = Keyword.fetch!(opts, :k)
    metric = Keyword.get(opts, :metric, :euclidean)
    weighted = Keyword.get(opts, :weighted, false)
    mutual = Keyword.get(opts, :mutual, false)

    points_tensor = ensure_tensor(points)
    {n, _d} = Nx.shape(points_tensor)

    if k >= n do
      raise ArgumentError, "k (#{k}) must be less than number of points (#{n})"
    end

    distances = Distance.pairwise(points_tensor, metric: metric)
    distance_matrix = Nx.to_list(distances)

    graph = Graph.new(type: :undirected) |> Graph.add_vertices(Enum.to_list(0..(n - 1)))

    if mutual do
      build_mutual_knn_graph(graph, distance_matrix, k, weighted)
    else
      build_knn_graph(graph, distance_matrix, k, weighted)
    end
  end

  @doc """
  Constructs an ε-ball (radius) neighborhood graph.

  Two vertices are connected if their distance is at most ε.
  This creates a symmetric, undirected graph.

  ## Parameters

  - `points` - Nx tensor of shape `{n, d}` or list of point lists
  - `opts` - Keyword list:
    - `:epsilon` - Maximum distance for connection (required)
    - `:metric` - Distance metric (default: `:euclidean`)
    - `:weighted` - Include edge weights (default: `false`)
    - `:strict` - Use `<` instead of `<=` (default: `false`)

  ## Returns

  - Undirected libgraph `Graph.t()`

  ## Examples

      iex> points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [5.0, 0.0]])
      iex> g = ExTopology.Neighborhood.epsilon_graph(points, epsilon: 1.5)
      iex> Graph.num_edges(g)
      1

      # Points within epsilon are connected
      iex> points = Nx.tensor([[0.0, 0.0], [0.5, 0.0], [1.0, 0.0]])
      iex> g = ExTopology.Neighborhood.epsilon_graph(points, epsilon: 0.6)
      iex> Graph.num_edges(g)
      2

  ## Complexity

  - Time: O(n² d) for distance computation
  - Space: O(n²) worst case (dense graph if ε is large)
  """
  @spec epsilon_graph(point_input(), keyword()) :: graph()
  def epsilon_graph(points, opts) do
    epsilon = Keyword.fetch!(opts, :epsilon)
    metric = Keyword.get(opts, :metric, :euclidean)
    weighted = Keyword.get(opts, :weighted, false)
    strict = Keyword.get(opts, :strict, false)

    if epsilon <= 0 do
      raise ArgumentError, "epsilon must be positive, got: #{epsilon}"
    end

    points_tensor = ensure_tensor(points)
    {n, _d} = Nx.shape(points_tensor)

    distances = Distance.pairwise(points_tensor, metric: metric)
    distance_matrix = Nx.to_list(distances)

    graph = Graph.new(type: :undirected) |> Graph.add_vertices(Enum.to_list(0..(n - 1)))

    build_epsilon_graph(graph, distance_matrix, epsilon, weighted, strict)
  end

  @doc """
  Constructs a graph from a precomputed distance matrix.

  Useful when you have custom distance computations or want to avoid
  recomputing distances.

  ## Parameters

  - `distance_matrix` - Nx tensor of shape `{n, n}` or nested list
  - `opts` - Keyword list with either:
    - `:k` - For k-NN graph construction
    - `:epsilon` - For ε-ball graph construction
    - `:weighted` - Include edge weights (default: `false`)

  ## Returns

  - Undirected libgraph `Graph.t()`

  ## Examples

      iex> dists = Nx.tensor([[0.0, 1.0, 5.0], [1.0, 0.0, 4.0], [5.0, 4.0, 0.0]])
      iex> g = ExTopology.Neighborhood.from_distance_matrix(dists, k: 1)
      iex> Graph.num_edges(g)
      2
  """
  @spec from_distance_matrix(Nx.Tensor.t() | [[number()]], keyword()) :: graph()
  def from_distance_matrix(distance_matrix, opts) do
    weighted = Keyword.get(opts, :weighted, false)

    matrix =
      case distance_matrix do
        %Nx.Tensor{} -> Nx.to_list(distance_matrix)
        list when is_list(list) -> list
      end

    n = length(matrix)
    graph = Graph.new(type: :undirected) |> Graph.add_vertices(Enum.to_list(0..(n - 1)))

    cond do
      Keyword.has_key?(opts, :k) ->
        k = Keyword.fetch!(opts, :k)
        build_knn_graph(graph, matrix, k, weighted)

      Keyword.has_key?(opts, :epsilon) ->
        epsilon = Keyword.fetch!(opts, :epsilon)
        strict = Keyword.get(opts, :strict, false)
        build_epsilon_graph(graph, matrix, epsilon, weighted, strict)

      true ->
        raise ArgumentError, "Must provide either :k or :epsilon option"
    end
  end

  @doc """
  Constructs a Gabriel graph from points.

  In a Gabriel graph, two points p and q are connected if no other point
  lies within the circle with diameter pq. This creates a subgraph of the
  Delaunay triangulation.

  ## Parameters

  - `points` - Nx tensor of shape `{n, d}` or list of point lists
  - `opts` - Keyword list:
    - `:weighted` - Include edge weights (default: `false`)

  ## Returns

  - Undirected libgraph `Graph.t()`

  ## Examples

      iex> points = Nx.tensor([[0.0, 0.0], [2.0, 0.0], [1.0, 1.0]])
      iex> g = ExTopology.Neighborhood.gabriel_graph(points)
      iex> Graph.num_vertices(g)
      3
  """
  @spec gabriel_graph(point_input(), keyword()) :: graph()
  def gabriel_graph(points, opts \\ []) do
    weighted = Keyword.get(opts, :weighted, false)

    points_tensor = ensure_tensor(points)
    points_list = Nx.to_list(points_tensor)
    {n, _d} = Nx.shape(points_tensor)

    distances = Distance.squared_euclidean_matrix(points_tensor)
    sq_dist_matrix = Nx.to_list(distances)

    graph = Graph.new(type: :undirected) |> Graph.add_vertices(Enum.to_list(0..(n - 1)))

    # For each pair (i, j), check Gabriel condition
    edges =
      for i <- 0..(n - 2),
          j <- (i + 1)..(n - 1),
          gabriel_condition?(points_list, sq_dist_matrix, i, j),
          do: {i, j, Enum.at(Enum.at(sq_dist_matrix, i), j) |> :math.sqrt()}

    add_edges_to_graph(graph, edges, weighted)
  end

  @doc """
  Constructs a relative neighborhood graph from points.

  In a relative neighborhood graph, two points p and q are connected if
  there is no third point r such that max(d(p,r), d(q,r)) < d(p,q).
  This is a supergraph of the Gabriel graph.

  ## Parameters

  - `points` - Nx tensor of shape `{n, d}` or list of point lists
  - `opts` - Keyword list:
    - `:weighted` - Include edge weights (default: `false`)

  ## Returns

  - Undirected libgraph `Graph.t()`
  """
  @spec relative_neighborhood_graph(point_input(), keyword()) :: graph()
  def relative_neighborhood_graph(points, opts \\ []) do
    weighted = Keyword.get(opts, :weighted, false)

    points_tensor = ensure_tensor(points)
    {n, _d} = Nx.shape(points_tensor)

    distances = Distance.euclidean_matrix(points_tensor)
    dist_matrix = Nx.to_list(distances)

    graph = Graph.new(type: :undirected) |> Graph.add_vertices(Enum.to_list(0..(n - 1)))

    # For each pair (i, j), check RNG condition
    edges =
      for i <- 0..(n - 2),
          j <- (i + 1)..(n - 1),
          rng_condition?(dist_matrix, i, j, n),
          do: {i, j, Enum.at(Enum.at(dist_matrix, i), j)}

    add_edges_to_graph(graph, edges, weighted)
  end

  # Private helper functions

  defp ensure_tensor(points) when is_list(points), do: Nx.tensor(points)
  defp ensure_tensor(%Nx.Tensor{} = tensor), do: tensor

  defp build_knn_graph(graph, distance_matrix, k, weighted) do
    n = length(distance_matrix)

    edges =
      for i <- 0..(n - 1) do
        row = Enum.at(distance_matrix, i)

        # Get indices sorted by distance, excluding self (index i)
        neighbors =
          row
          |> Enum.with_index()
          |> Enum.reject(fn {_dist, idx} -> idx == i end)
          |> Enum.sort_by(fn {dist, _idx} -> dist end)
          |> Enum.take(k)
          |> Enum.map(fn {dist, idx} -> {i, idx, dist} end)

        neighbors
      end
      |> List.flatten()
      |> Enum.uniq_by(fn {i, j, _} -> {min(i, j), max(i, j)} end)

    add_edges_to_graph(graph, edges, weighted)
  end

  defp build_mutual_knn_graph(graph, distance_matrix, k, weighted) do
    n = length(distance_matrix)

    # Find k-NN for each point
    knn_sets =
      for i <- 0..(n - 1), into: %{} do
        row = Enum.at(distance_matrix, i)

        neighbors =
          row
          |> Enum.with_index()
          |> Enum.reject(fn {_dist, idx} -> idx == i end)
          |> Enum.sort_by(fn {dist, _idx} -> dist end)
          |> Enum.take(k)
          |> Enum.map(fn {_dist, idx} -> idx end)
          |> MapSet.new()

        {i, neighbors}
      end

    # Only keep edges where both are in each other's k-NN
    edges =
      for i <- 0..(n - 2),
          j <- (i + 1)..(n - 1),
          MapSet.member?(knn_sets[i], j) and MapSet.member?(knn_sets[j], i) do
        dist = Enum.at(Enum.at(distance_matrix, i), j)
        {i, j, dist}
      end

    add_edges_to_graph(graph, edges, weighted)
  end

  defp build_epsilon_graph(graph, distance_matrix, epsilon, weighted, strict) do
    n = length(distance_matrix)
    compare_fn = if strict, do: &Kernel.</2, else: &Kernel.<=/2

    edges =
      for i <- 0..(n - 2),
          j <- (i + 1)..(n - 1),
          dist = Enum.at(Enum.at(distance_matrix, i), j),
          compare_fn.(dist, epsilon) and dist > 0 do
        {i, j, dist}
      end

    add_edges_to_graph(graph, edges, weighted)
  end

  defp add_edges_to_graph(graph, edges, weighted) do
    Enum.reduce(edges, graph, fn {i, j, dist}, g ->
      if weighted do
        Graph.add_edge(g, i, j, weight: dist)
      else
        Graph.add_edge(g, i, j)
      end
    end)
  end

  defp gabriel_condition?(points_list, sq_dist_matrix, i, j) do
    # Gabriel condition: no point k lies within circle with diameter (i, j)
    # Equivalent: for all k != i,j: d(i,k)² + d(j,k)² >= d(i,j)²
    n = length(points_list)
    sq_dist_ij = Enum.at(Enum.at(sq_dist_matrix, i), j)

    Enum.all?(0..(n - 1), fn k ->
      if k == i or k == j do
        true
      else
        sq_dist_ik = Enum.at(Enum.at(sq_dist_matrix, i), k)
        sq_dist_jk = Enum.at(Enum.at(sq_dist_matrix, j), k)
        sq_dist_ik + sq_dist_jk >= sq_dist_ij
      end
    end)
  end

  defp rng_condition?(dist_matrix, i, j, n) do
    # RNG condition: no point k such that max(d(i,k), d(j,k)) < d(i,j)
    dist_ij = Enum.at(Enum.at(dist_matrix, i), j)

    Enum.all?(0..(n - 1), fn k ->
      if k == i or k == j do
        true
      else
        dist_ik = Enum.at(Enum.at(dist_matrix, i), k)
        dist_jk = Enum.at(Enum.at(dist_matrix, j), k)
        max(dist_ik, dist_jk) >= dist_ij
      end
    end)
  end
end
