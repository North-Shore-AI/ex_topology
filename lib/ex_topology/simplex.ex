defmodule ExTopology.Simplex do
  @moduledoc """
  Simplicial complex construction and manipulation.

  A simplex is the simplest possible polytope in a given dimension:
  - 0-simplex: A point
  - 1-simplex: A line segment (2 vertices)
  - 2-simplex: A triangle (3 vertices)
  - 3-simplex: A tetrahedron (4 vertices)

  This module represents simplices as sorted lists of vertex indices,
  enabling efficient face enumeration and boundary operator computation.

  ## Examples

      iex> ExTopology.Simplex.dimension([0, 1, 2])
      2

      iex> ExTopology.Simplex.faces([0, 1, 2])
      [[1, 2], [0, 2], [0, 1]]

      iex> ExTopology.Simplex.boundary([0, 1, 2])
      [{1, [1, 2]}, {-1, [0, 2]}, {1, [0, 1]}]
  """

  @type vertex :: non_neg_integer()
  @type simplex :: [vertex()]
  @type boundary_chain :: [{sign :: integer(), simplex()}]

  @doc """
  Returns the dimension of a simplex.

  A k-simplex has dimension k and contains k+1 vertices.

  ## Parameters

  - `simplex` - List of vertex indices (will be sorted)

  ## Returns

  - Integer dimension (number of vertices - 1)

  ## Examples

      iex> ExTopology.Simplex.dimension([0])
      0

      iex> ExTopology.Simplex.dimension([0, 1])
      1

      iex> ExTopology.Simplex.dimension([0, 1, 2])
      2

      iex> ExTopology.Simplex.dimension([])
      -1
  """
  @spec dimension(simplex()) :: integer()
  def dimension([]), do: -1
  def dimension(simplex), do: length(simplex) - 1

  @doc """
  Normalizes a simplex by sorting vertices and removing duplicates.

  ## Parameters

  - `simplex` - List of vertex indices

  ## Returns

  - Sorted, deduplicated list of vertices

  ## Examples

      iex> ExTopology.Simplex.normalize([2, 0, 1])
      [0, 1, 2]

      iex> ExTopology.Simplex.normalize([1, 2, 1])
      [1, 2]
  """
  @spec normalize(simplex()) :: simplex()
  def normalize(simplex) do
    simplex |> Enum.sort() |> Enum.uniq()
  end

  @doc """
  Returns all faces (k-1 dimensional subsimplices) of a simplex.

  A face is obtained by removing one vertex from the simplex.

  ## Parameters

  - `simplex` - List of vertex indices

  ## Returns

  - List of faces (each face is a list of vertices)

  ## Examples

      iex> ExTopology.Simplex.faces([0, 1])
      [[1], [0]]

      iex> ExTopology.Simplex.faces([0, 1, 2])
      [[1, 2], [0, 2], [0, 1]]

      iex> ExTopology.Simplex.faces([0, 1, 2, 3])
      [[1, 2, 3], [0, 2, 3], [0, 1, 3], [0, 1, 2]]
  """
  @spec faces(simplex()) :: [simplex()]
  def faces([]), do: []

  def faces(simplex) do
    normalized = normalize(simplex)

    for i <- 0..(length(normalized) - 1) do
      List.delete_at(normalized, i)
    end
  end

  @doc """
  Returns all k-dimensional faces of a simplex.

  ## Parameters

  - `simplex` - List of vertex indices
  - `k` - Dimension of faces to return

  ## Returns

  - List of k-faces

  ## Examples

      iex> ExTopology.Simplex.k_faces([0, 1, 2], 0)
      [[0], [1], [2]]

      iex> ExTopology.Simplex.k_faces([0, 1, 2], 1)
      [[0, 1], [0, 2], [1, 2]]

      iex> ExTopology.Simplex.k_faces([0, 1, 2, 3], 1)
      [[0, 1], [0, 2], [0, 3], [1, 2], [1, 3], [2, 3]]
  """
  @spec k_faces(simplex(), non_neg_integer()) :: [simplex()]
  def k_faces(simplex, k) do
    normalized = normalize(simplex)
    combinations(normalized, k + 1)
  end

  @doc """
  Computes the boundary operator ∂ for a simplex.

  The boundary of a k-simplex is a formal sum of its (k-1)-faces
  with alternating signs. The sign of the i-th face is (-1)^i.

  ## Parameters

  - `simplex` - List of vertex indices

  ## Returns

  - List of tuples `{sign, face}` where sign is +1 or -1

  ## Examples

      iex> ExTopology.Simplex.boundary([0, 1])
      [{1, [1]}, {-1, [0]}]

      iex> ExTopology.Simplex.boundary([0, 1, 2])
      [{1, [1, 2]}, {-1, [0, 2]}, {1, [0, 1]}]

  ## Mathematical Background

  The boundary operator satisfies ∂∂ = 0, meaning the boundary
  of a boundary is always empty (fundamental theorem of homology).
  """
  @spec boundary(simplex()) :: boundary_chain()
  def boundary([]), do: []

  def boundary(simplex) do
    normalized = normalize(simplex)

    normalized
    |> Enum.with_index()
    |> Enum.map(fn {_vertex, i} ->
      sign = if rem(i, 2) == 0, do: 1, else: -1
      face = List.delete_at(normalized, i)
      {sign, face}
    end)
  end

  @doc """
  Checks if one simplex is a face of another.

  ## Parameters

  - `face` - Potential face simplex
  - `simplex` - Parent simplex

  ## Returns

  - `true` if face is a subset of simplex, `false` otherwise

  ## Examples

      iex> ExTopology.Simplex.face?([0, 1], [0, 1, 2])
      true

      iex> ExTopology.Simplex.face?([0, 3], [0, 1, 2])
      false
  """
  @spec face?(simplex(), simplex()) :: boolean()
  def face?(face, simplex) do
    face_set = MapSet.new(normalize(face))
    simplex_set = MapSet.new(normalize(simplex))
    MapSet.subset?(face_set, simplex_set)
  end

  @doc """
  Builds a clique complex from a graph.

  A clique complex includes all complete subgraphs (cliques) as simplices.
  If vertices {0,1,2} form a triangle in the graph, the complex includes
  the 2-simplex [0,1,2] and all its faces.

  ## Parameters

  - `graph` - A libgraph Graph struct
  - `opts` - Keyword list:
    - `:max_dimension` - Maximum simplex dimension to include (default: 2)

  ## Returns

  - Map of dimension to list of simplices: `%{0 => [...], 1 => [...], ...}`

  ## Examples

      iex> g = Graph.new() |> Graph.add_edges([{0, 1}, {1, 2}, {2, 0}])
      iex> complex = ExTopology.Simplex.clique_complex(g)
      iex> length(complex[2])
      1
      iex> complex[2]
      [[0, 1, 2]]
  """
  @spec clique_complex(Graph.t(), keyword()) :: %{non_neg_integer() => [simplex()]}
  def clique_complex(graph, opts \\ []) do
    max_dim = Keyword.get(opts, :max_dimension, 2)
    vertices = Graph.vertices(graph)

    # Start with 0-simplices (vertices)
    complex = %{0 => Enum.map(vertices, &[&1])}

    # Build up dimensions incrementally
    build_clique_complex(graph, complex, vertices, 1, max_dim)
  end

  # Private helper functions

  defp build_clique_complex(_graph, complex, _vertices, dim, max_dim) when dim > max_dim do
    complex
  end

  defp build_clique_complex(graph, complex, vertices, dim, max_dim) do
    # Get all potential (dim)-simplices from (dim-1)-simplices
    prev_simplices = Map.get(complex, dim - 1, [])

    # Generate candidate simplices by extending previous dimension
    candidates =
      for simplex <- prev_simplices,
          v <- vertices,
          v > Enum.max(simplex) do
        Enum.sort([v | simplex])
      end
      |> Enum.uniq()

    # Filter to only those that are cliques
    dim_simplices =
      candidates
      |> Enum.filter(fn simplex -> clique?(graph, simplex) end)

    complex = Map.put(complex, dim, dim_simplices)

    build_clique_complex(graph, complex, vertices, dim + 1, max_dim)
  end

  defp clique?(graph, vertices) do
    # Check if all pairs of vertices are connected
    pairs = combinations(vertices, 2)

    Enum.all?(pairs, fn [v1, v2] ->
      Graph.edge(graph, v1, v2) != nil or Graph.edge(graph, v2, v1) != nil
    end)
  end

  defp combinations(_, 0), do: [[]]
  defp combinations([], _), do: []

  defp combinations([h | t], k) do
    for(rest <- combinations(t, k - 1), do: [h | rest]) ++ combinations(t, k)
  end

  @doc """
  Returns all simplices in a complex up to a given dimension.

  ## Parameters

  - `complex` - Map of dimension to simplices
  - `max_dim` - Maximum dimension (default: all)

  ## Returns

  - Flat list of all simplices

  ## Examples

      iex> complex = %{0 => [[0], [1]], 1 => [[0, 1]]}
      iex> ExTopology.Simplex.all_simplices(complex)
      [[0], [1], [0, 1]]
  """
  @spec all_simplices(%{non_neg_integer() => [simplex()]}, non_neg_integer() | nil) :: [
          simplex()
        ]
  def all_simplices(complex, max_dim \\ nil) do
    dims = if max_dim, do: 0..max_dim, else: Map.keys(complex)

    for dim <- dims, simplex <- Map.get(complex, dim, []) do
      simplex
    end
  end

  @doc """
  Computes the skeleton (all simplices up to dimension k) of a complex.

  ## Parameters

  - `complex` - Map of dimension to simplices
  - `k` - Dimension of skeleton

  ## Returns

  - Map containing only dimensions 0 through k

  ## Examples

      iex> complex = %{0 => [[0]], 1 => [[0, 1]], 2 => [[0, 1, 2]]}
      iex> ExTopology.Simplex.skeleton(complex, 1)
      %{0 => [[0]], 1 => [[0, 1]]}
  """
  @spec skeleton(%{non_neg_integer() => [simplex()]}, non_neg_integer()) :: %{
          non_neg_integer() => [simplex()]
        }
  def skeleton(complex, k) do
    complex
    |> Enum.filter(fn {dim, _} -> dim <= k end)
    |> Map.new()
  end
end
