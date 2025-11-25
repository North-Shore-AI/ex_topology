defmodule ExTopology.Graph do
  @moduledoc """
  Graph-theoretic topology measures.

  This module provides fundamental topological invariants for graphs,
  implemented as thin wrappers over libgraph with a topology-specific API.

  ## Betti Numbers

  For graphs (1-dimensional simplicial complexes):

  - **β₀** (beta zero): Number of connected components
  - **β₁** (beta one): Cyclomatic number (independent cycles)

  These satisfy the Euler characteristic relation: χ = β₀ - β₁

  ## Examples

      iex> graph = Graph.new() |> Graph.add_edges([{1, 2}, {2, 3}, {3, 1}])
      iex> ExTopology.Graph.beta_zero(graph)
      1
      iex> ExTopology.Graph.beta_one(graph)
      1
      iex> ExTopology.Graph.euler_characteristic(graph)
      0

  ## Mathematical Background

  For a graph G = (V, E) with C connected components:

  - β₀ = C (number of connected components)
  - β₁ = |E| - |V| + C (cyclomatic complexity / circuit rank)
  - χ = |V| - |E| = β₀ - β₁ (Euler characteristic)

  The cyclomatic number β₁ counts the number of independent cycles in the graph.
  A tree has β₁ = 0, while each additional edge creates one new independent cycle.
  """

  @type graph :: Graph.t()

  @doc """
  Computes β₀ (beta zero): the number of connected components.

  β₀ counts the number of disconnected subgraphs. A fully connected graph
  has β₀ = 1, while n isolated vertices have β₀ = n.

  ## Parameters

  - `graph` - A libgraph Graph struct

  ## Returns

  - Non-negative integer representing the number of connected components
  - Returns 0 for an empty graph (no vertices)

  ## Examples

      iex> g = Graph.new() |> Graph.add_vertex(:a)
      iex> ExTopology.Graph.beta_zero(g)
      1

      iex> g = Graph.new() |> Graph.add_vertices([:a, :b, :c])
      iex> ExTopology.Graph.beta_zero(g)
      3

      iex> g = Graph.new() |> Graph.add_edges([{:a, :b}, {:b, :c}])
      iex> ExTopology.Graph.beta_zero(g)
      1

      iex> ExTopology.Graph.beta_zero(Graph.new())
      0

  ## Mathematical Definition

  β₀ = dim(H₀(G)) = number of path-connected components
  """
  @spec beta_zero(graph()) :: non_neg_integer()
  def beta_zero(graph) do
    graph
    |> Graph.components()
    |> length()
  end

  @doc """
  Computes β₁ (beta one): the cyclomatic number (first Betti number).

  β₁ measures the number of independent cycles in the graph. It's computed as:

      β₁ = |E| - |V| + C

  where E is edges, V is vertices, and C is connected components.

  ## Parameters

  - `graph` - A libgraph Graph struct

  ## Returns

  - Non-negative integer representing the number of independent cycles

  ## Examples

      # A tree has no cycles
      iex> tree = Graph.new() |> Graph.add_edges([{1, 2}, {1, 3}, {2, 4}])
      iex> ExTopology.Graph.beta_one(tree)
      0

      # A triangle has one cycle
      iex> triangle = Graph.new() |> Graph.add_edges([{1, 2}, {2, 3}, {3, 1}])
      iex> ExTopology.Graph.beta_one(triangle)
      1

      # Two disjoint triangles have two cycles
      iex> g = Graph.new()
      ...> |> Graph.add_edges([{1, 2}, {2, 3}, {3, 1}])
      ...> |> Graph.add_edges([{4, 5}, {5, 6}, {6, 4}])
      iex> ExTopology.Graph.beta_one(g)
      2

      # Complete graph K4: 4 vertices, 6 edges, 1 component
      # β₁ = 6 - 4 + 1 = 3
      iex> k4 = Graph.new() |> Graph.add_edges([
      ...>   {1, 2}, {1, 3}, {1, 4}, {2, 3}, {2, 4}, {3, 4}
      ...> ])
      iex> ExTopology.Graph.beta_one(k4)
      3

  ## Mathematical Definition

  β₁ = dim(H₁(G)) = |E| - |V| + |C|

  Also known as the circuit rank or cyclomatic complexity.
  """
  @spec beta_one(graph()) :: non_neg_integer()
  def beta_one(graph) do
    edges = num_edges(graph)
    vertices = Graph.num_vertices(graph)
    components = beta_zero(graph)

    # β₁ = E - V + C
    # This is always non-negative for any graph
    edges - vertices + components
  end

  @doc """
  Computes the Euler characteristic χ (chi) of a graph.

  For graphs: χ = |V| - |E| = β₀ - β₁

  The Euler characteristic is a fundamental topological invariant.

  ## Parameters

  - `graph` - A libgraph Graph struct

  ## Returns

  - Integer (can be negative, zero, or positive)

  ## Examples

      # Single vertex: χ = 1 - 0 = 1
      iex> g = Graph.new() |> Graph.add_vertex(:a)
      iex> ExTopology.Graph.euler_characteristic(g)
      1

      # Triangle: χ = 3 - 3 = 0
      iex> triangle = Graph.new() |> Graph.add_edges([{1, 2}, {2, 3}, {3, 1}])
      iex> ExTopology.Graph.euler_characteristic(triangle)
      0

      # Tree with 4 vertices: χ = 4 - 3 = 1
      iex> tree = Graph.new() |> Graph.add_edges([{1, 2}, {1, 3}, {1, 4}])
      iex> ExTopology.Graph.euler_characteristic(tree)
      1

      # K4: χ = 4 - 6 = -2
      iex> k4 = Graph.new() |> Graph.add_edges([
      ...>   {1, 2}, {1, 3}, {1, 4}, {2, 3}, {2, 4}, {3, 4}
      ...> ])
      iex> ExTopology.Graph.euler_characteristic(k4)
      -2

  ## Mathematical Definition

  χ(G) = |V| - |E| = β₀ - β₁

  For connected graphs: χ = 1 - β₁
  """
  @spec euler_characteristic(graph()) :: integer()
  def euler_characteristic(graph) do
    Graph.num_vertices(graph) - num_edges(graph)
  end

  @doc """
  Returns the number of edges in the graph.

  For undirected graphs, each edge is counted once.
  For directed graphs, each directed edge is counted.

  ## Parameters

  - `graph` - A libgraph Graph struct

  ## Returns

  - Non-negative integer

  ## Examples

      iex> g = Graph.new() |> Graph.add_edges([{1, 2}, {2, 3}])
      iex> ExTopology.Graph.num_edges(g)
      2

      iex> ExTopology.Graph.num_edges(Graph.new())
      0
  """
  @spec num_edges(graph()) :: non_neg_integer()
  def num_edges(graph) do
    Graph.num_edges(graph)
  end

  @doc """
  Returns the number of vertices in the graph.

  ## Parameters

  - `graph` - A libgraph Graph struct

  ## Returns

  - Non-negative integer

  ## Examples

      iex> g = Graph.new() |> Graph.add_vertices([1, 2, 3])
      iex> ExTopology.Graph.num_vertices(g)
      3

      iex> ExTopology.Graph.num_vertices(Graph.new())
      0
  """
  @spec num_vertices(graph()) :: non_neg_integer()
  def num_vertices(graph) do
    Graph.num_vertices(graph)
  end

  @doc """
  Checks if the graph is connected (β₀ = 1).

  A graph is connected if there is a path between every pair of vertices.

  ## Parameters

  - `graph` - A libgraph Graph struct

  ## Returns

  - `true` if the graph is connected (exactly one component)
  - `false` otherwise (including empty graphs)

  ## Examples

      iex> g = Graph.new() |> Graph.add_edges([{1, 2}, {2, 3}])
      iex> ExTopology.Graph.connected?(g)
      true

      iex> g = Graph.new() |> Graph.add_vertices([1, 2])
      iex> ExTopology.Graph.connected?(g)
      false

      iex> ExTopology.Graph.connected?(Graph.new())
      false
  """
  @spec connected?(graph()) :: boolean()
  def connected?(graph) do
    beta_zero(graph) == 1
  end

  @doc """
  Checks if the graph is a tree (connected and acyclic).

  A tree satisfies: β₀ = 1 and β₁ = 0

  ## Parameters

  - `graph` - A libgraph Graph struct

  ## Returns

  - `true` if the graph is a tree
  - `false` otherwise

  ## Examples

      iex> tree = Graph.new() |> Graph.add_edges([{1, 2}, {1, 3}, {2, 4}])
      iex> ExTopology.Graph.tree?(tree)
      true

      iex> cycle = Graph.new() |> Graph.add_edges([{1, 2}, {2, 3}, {3, 1}])
      iex> ExTopology.Graph.tree?(cycle)
      false

      iex> forest = Graph.new() |> Graph.add_edges([{1, 2}, {3, 4}])
      iex> ExTopology.Graph.tree?(forest)
      false
  """
  @spec tree?(graph()) :: boolean()
  def tree?(graph) do
    connected?(graph) and beta_one(graph) == 0
  end

  @doc """
  Checks if the graph is a forest (acyclic, possibly disconnected).

  A forest satisfies: β₁ = 0 (no cycles)

  ## Parameters

  - `graph` - A libgraph Graph struct

  ## Returns

  - `true` if the graph is a forest (acyclic)
  - `false` otherwise

  ## Examples

      iex> forest = Graph.new() |> Graph.add_edges([{1, 2}, {3, 4}])
      iex> ExTopology.Graph.forest?(forest)
      true

      iex> tree = Graph.new() |> Graph.add_edges([{1, 2}, {1, 3}])
      iex> ExTopology.Graph.forest?(tree)
      true

      iex> cycle = Graph.new() |> Graph.add_edges([{1, 2}, {2, 3}, {3, 1}])
      iex> ExTopology.Graph.forest?(cycle)
      false
  """
  @spec forest?(graph()) :: boolean()
  def forest?(graph) do
    beta_one(graph) == 0
  end

  @doc """
  Returns all topological invariants for the graph.

  ## Parameters

  - `graph` - A libgraph Graph struct

  ## Returns

  A map with:
  - `:vertices` - Number of vertices
  - `:edges` - Number of edges
  - `:components` - Number of connected components (β₀)
  - `:beta_zero` - Same as components
  - `:beta_one` - Cyclomatic number
  - `:euler_characteristic` - χ = V - E

  ## Examples

      iex> g = Graph.new() |> Graph.add_edges([{1, 2}, {2, 3}, {3, 1}])
      iex> ExTopology.Graph.invariants(g)
      %{
        vertices: 3,
        edges: 3,
        components: 1,
        beta_zero: 1,
        beta_one: 1,
        euler_characteristic: 0
      }
  """
  @spec invariants(graph()) :: %{
          vertices: non_neg_integer(),
          edges: non_neg_integer(),
          components: non_neg_integer(),
          beta_zero: non_neg_integer(),
          beta_one: non_neg_integer(),
          euler_characteristic: integer()
        }
  def invariants(graph) do
    v = Graph.num_vertices(graph)
    e = num_edges(graph)
    c = beta_zero(graph)

    %{
      vertices: v,
      edges: e,
      components: c,
      beta_zero: c,
      beta_one: e - v + c,
      euler_characteristic: v - e
    }
  end
end
