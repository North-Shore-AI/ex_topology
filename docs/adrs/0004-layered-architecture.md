# ADR-0004: Layered Architecture Design

## Status

Accepted

## Context

ex_topology must serve multiple use cases:

1. **CNS (Conceptual Neighborhood Space)**: Surrogate computation, Betti numbers for cognitive neighborhoods
2. **General TDA**: Persistent homology for arbitrary point cloud analysis
3. **Graph Analytics**: Generic graph metrics and algorithms
4. **Research**: Extensible foundation for topology research

A clean architecture enables reuse across these domains while maintaining clear boundaries.

## Decision

**Implement a four-layer architecture with strict dependency direction.**

```
┌─────────────────────────────────────────────────────────────────┐
│                    Layer 4: Domain Integration                   │
│  (CNS adapters, Crucible stages, application-specific APIs)     │
├─────────────────────────────────────────────────────────────────┤
│                    Layer 3: TDA Algorithms                       │
│  (Persistent Homology, Filtrations, Persistence Diagrams)       │
├─────────────────────────────────────────────────────────────────┤
│                  Layer 2: Data Structures                        │
│  (Simplicial Complexes, Neighborhood Graphs, Distance Matrices) │
├─────────────────────────────────────────────────────────────────┤
│                   Layer 1: Foundations                           │
│  (libgraph, Nx, Scholar, Statistics)                            │
└─────────────────────────────────────────────────────────────────┘
```

### Layer 1: Foundations

External dependencies and basic numerical operations:

```elixir
# ExTopology.Foundation.Distance
defmodule ExTopology.Foundation.Distance do
  import Nx.Defn

  defn euclidean(a, b), do: Nx.sqrt(Nx.sum((a - b) ** 2))
  defn euclidean_matrix(points), do: ...
  defn cosine_similarity(a, b), do: ...
end

# ExTopology.Foundation.Statistics
defmodule ExTopology.Foundation.Statistics do
  def variance(tensor), do: ...
  def correlation_matrix(data), do: ...
  def knn_variance(points, k), do: ...  # Extracted from CNS
end
```

### Layer 2: Data Structures

Core topological data structures:

```elixir
# ExTopology.Structure.SimplicalComplex
defmodule ExTopology.Structure.SimplicialComplex do
  defstruct [:vertices, :simplices, :dimension]

  def new(), do: ...
  def add_simplex(complex, simplex), do: ...
  def faces(simplex), do: ...
  def star(complex, simplex), do: ...
  def link(complex, simplex), do: ...
end

# ExTopology.Structure.NeighborhoodGraph
defmodule ExTopology.Structure.NeighborhoodGraph do
  def knn_graph(points, k), do: ...
  def epsilon_graph(points, epsilon), do: ...
  def from_distance_matrix(distances, threshold), do: ...
end

# ExTopology.Structure.Filtration
defmodule ExTopology.Structure.Filtration do
  defstruct [:complexes, :scales]

  def vietoris_rips(points, scales), do: ...
  def alpha(points, scales), do: ...
end
```

### Layer 3: TDA Algorithms

Topological analysis algorithms:

```elixir
# ExTopology.TDA.Betti
defmodule ExTopology.TDA.Betti do
  @doc "Compute Betti numbers β₀, β₁, β₂, ..."
  def compute(complex), do: ...

  @doc "Compute only β₁ (cyclomatic number) efficiently"
  def beta_one(graph), do: ...  # Extracted from CNS.Logic.Betti
end

# ExTopology.TDA.PersistentHomology
defmodule ExTopology.TDA.PersistentHomology do
  def persistence(filtration), do: ...
  def persistence_diagram(persistence_result), do: ...
  def bottleneck_distance(diagram1, diagram2), do: ...
end

# ExTopology.TDA.Fragility (from CNS)
defmodule ExTopology.TDA.Fragility do
  @doc "Compute topological fragility score"
  def compute(graph, opts \\ []), do: ...
end
```

### Layer 4: Domain Integration

Application-specific adapters (NOT in ex_topology itself):

```elixir
# In crucible_framework or cns:
defmodule CNS.Topology.Adapter do
  alias ExTopology.TDA.{Betti, Fragility}
  alias ExTopology.Foundation.Statistics

  def compute_surrogates(embeddings, opts) do
    k = opts[:k] || 10
    distances = ExTopology.Foundation.Distance.euclidean_matrix(embeddings)
    knn_var = Statistics.knn_variance(embeddings, k)
    beta_one = Betti.beta_one(graph_from_distances(distances, opts[:threshold]))
    fragility = Fragility.compute(graph, opts)

    %{knn_variance: knn_var, beta_one: beta_one, fragility: fragility}
  end
end
```

## Consequences

### Positive

1. **Clear boundaries**: Each layer has defined responsibilities
2. **Testability**: Layers can be tested independently
3. **Reusability**: Lower layers serve multiple higher-layer use cases
4. **Extensibility**: New algorithms slot into existing structure
5. **Dependency clarity**: Strict upward-only dependencies

### Negative

1. **Indirection**: May need to traverse layers for simple operations
2. **API surface**: Multiple modules to learn

### Module Structure

```
lib/ex_topology/
├── foundation/
│   ├── distance.ex
│   ├── statistics.ex
│   └── graph_utils.ex
├── structure/
│   ├── simplicial_complex.ex
│   ├── neighborhood_graph.ex
│   ├── filtration.ex
│   └── distance_matrix.ex
└── tda/
    ├── betti.ex
    ├── persistent_homology.ex
    ├── fragility.ex
    └── persistence_diagram.ex
```

## References

- "Clean Architecture" by Robert C. Martin
- Hexagonal Architecture (Ports & Adapters)
- Current CNS module structure (to be refactored)
