# ADR-0001: Use libgraph for Graph Algorithms

## Status

Accepted

## Context

ex_topology requires graph data structures and algorithms as a foundational layer for topological computations. Key operations include:

- Graph construction from point clouds and distance matrices
- Neighborhood graphs (k-NN, epsilon-ball)
- Connected component detection
- Cycle detection for Betti number computation
- Path algorithms for filtration construction

We evaluated several options for graph support in Elixir:

### Option A: libgraph (bitwalker/libgraph)
- **Maturity**: 8+ years, 496 stars, actively maintained
- **API**: Rich graph operations including BFS, DFS, dijkstra, a*, topsort
- **Performance**: Pure Elixir, ETS-backed option available
- **License**: MIT

### Option B: Custom Implementation
- Full control over data structures
- Can optimize for specific TDA patterns
- Significant development effort
- Risk of bugs in fundamental algorithms

### Option C: Nx-based Graph Representation
- Adjacency matrices as tensors
- GPU acceleration possible
- Limited graph algorithm support in Scholar
- Awkward API for graph mutations

## Decision

**Use libgraph as the primary graph library.**

libgraph provides production-tested implementations of all required graph algorithms. Its pure Elixir implementation integrates cleanly with our architecture, and the extensive API covers our needs:

```elixir
# Example: Building a k-NN graph from distance matrix
defmodule ExTopology.Graph.KNN do
  def from_distances(distances, k) do
    n = tuple_size(distances)

    Graph.new()
    |> add_vertices(0..(n-1))
    |> add_knn_edges(distances, k)
  end

  defp add_knn_edges(graph, distances, k) do
    # For each vertex, connect to k nearest neighbors
    Enum.reduce(0..(tuple_size(distances)-1), graph, fn i, g ->
      neighbors = find_k_nearest(distances, i, k)
      Enum.reduce(neighbors, g, fn j, g2 ->
        Graph.add_edge(g2, i, j, weight: elem(elem(distances, i), j))
      end)
    end)
  end
end
```

## Consequences

### Positive

1. **Proven correctness**: libgraph's algorithms are battle-tested
2. **Rich API**: BFS, DFS, dijkstra, components, cycles all available
3. **Clean integration**: Pure Elixir, no NIFs or external dependencies
4. **Maintained**: Active development and community support
5. **Documentation**: Comprehensive docs and examples

### Negative

1. **Performance ceiling**: Pure Elixir may be slower than native implementations for very large graphs
2. **Memory overhead**: Functional data structures use more memory than mutable alternatives
3. **API constraints**: Must work within libgraph's design decisions

### Mitigations

- For large-scale performance needs, we can add optional Nx-based sparse matrix backends
- Memory overhead is acceptable for typical TDA workloads (thousands of vertices)
- libgraph's API is flexible enough for our use cases

## References

- [libgraph GitHub](https://github.com/bitwalker/libgraph)
- [libgraph Hexdocs](https://hexdocs.pm/libgraph)
- CNS.Logic.Betti - Current cycle detection implementation that will migrate to ex_topology
