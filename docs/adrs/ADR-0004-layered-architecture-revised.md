# ADR-0004: Layered Architecture Design

## Status

Accepted (Revised)

*Fixes layer boundary violations in original ADR*

## Context

ex_topology must serve multiple use cases while maintaining clear boundaries:

1. **Generic topology**: Graph metrics usable by any application
2. **CNS integration**: Domain-specific interpretation of topology
3. **Future domains**: Code analysis, knowledge graphs, etc.

The original ADR incorrectly placed domain-specific concepts (Fragility) in generic layers.

## Decision

**Implement a three-layer architecture. Domain-specific code stays OUT of ex_topology.**

```
┌─────────────────────────────────────────────────────────────────┐
│              DOMAIN LAYER (NOT in ex_topology)                  │
│                                                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │     CNS     │  │ CodeAnalysis│  │ KnowledgeKG │  ...         │
│  │ • Fragility │  │ • TechDebt  │  │ • Inference │              │
│  │ • SNO score │  │ • Coupling  │  │ • Cycles    │              │
│  │ • Chirality │  │ • Cohesion  │  │ • Paths     │              │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘              │
│         │                │                │                      │
└─────────┼────────────────┼────────────────┼─────────────────────┘
          │                │                │
          └────────────────┼────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                    ex_topology (GENERIC)                         │
│                                                                  │
│  Layer 2: Algorithms                                             │
│  ├── ExTopology.Graph       (β₀, β₁, χ)                         │
│  ├── ExTopology.Embedding   (kNN variance, density)             │
│  └── ExTopology.Statistics  (correlation, variance)             │
│                                                                  │
│  Layer 1: Structures                                             │
│  ├── ExTopology.Neighborhood (kNN graph, ε-ball graph)          │
│  └── ExTopology.Distance     (matrices, metrics)                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                           │
                           │ depends on
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                    FOUNDATION (External)                         │
│                                                                  │
│  libgraph          Nx / Scholar         Erlang stdlib           │
│  • Graph struct    • Tensors            • :digraph              │
│  • BFS/DFS         • Distance metrics   • :math                 │
│  • Components      • Linear algebra                             │
│  • Cycles          • Statistics                                 │
└─────────────────────────────────────────────────────────────────┘
```

### What's IN ex_topology (Generic)

```elixir
# Layer 1: Structures
defmodule ExTopology.Distance do
  @moduledoc "Distance matrix computation - domain agnostic"
  defn euclidean_matrix(points), do: ...
  defn cosine_matrix(points), do: ...
  defn pairwise(points, metric), do: ...
end

defmodule ExTopology.Neighborhood do
  @moduledoc "Neighborhood graph construction - domain agnostic"
  def knn_graph(points, opts), do: ...
  def epsilon_graph(points, epsilon), do: ...
  def from_distance_matrix(matrix, opts), do: ...
end

# Layer 2: Algorithms  
defmodule ExTopology.Graph do
  @moduledoc "Graph topology metrics - domain agnostic"
  def beta_zero(graph), do: ...      # Connected components
  def beta_one(graph), do: ...       # Cyclomatic number
  def euler_characteristic(graph), do: ...
end

defmodule ExTopology.Embedding do
  @moduledoc "Embedding analysis - domain agnostic"
  defn knn_variance(points, k), do: ...
  defn knn_distances(points, k), do: ...
  defn local_density(points, k), do: ...
end

defmodule ExTopology.Statistics do
  @moduledoc "Statistical measures - domain agnostic"
  def correlation(x, y, type \\ :pearson), do: ...
  def effect_size(x, y), do: ...
end
```

### What's OUT of ex_topology (Domain-Specific)

```elixir
# In CNS package, NOT ex_topology:
defmodule CNS.Topology.Fragility do
  @moduledoc """
  CNS-specific fragility score.
  
  Fragility = f(β₁, kNN_variance, domain_weights)
  
  This interpretation of topology metrics is CNS-specific.
  Other domains would compute different composite scores.
  """
  
  alias ExTopology.{Graph, Embedding}
  
  def compute(sno, opts \\ []) do
    graph = sno_to_graph(sno)
    embeddings = sno_to_embeddings(sno)
    
    beta_1 = Graph.beta_one(graph)
    knn_var = Embedding.knn_variance(embeddings, opts[:k] || 10)
    
    # CNS-specific weighting and interpretation
    weighted_score(beta_1, knn_var, opts)
  end
  
  defp weighted_score(beta_1, knn_var, opts) do
    w1 = opts[:beta_weight] || 0.6
    w2 = opts[:variance_weight] || 0.4
    w1 * normalize(beta_1) + w2 * normalize(knn_var)
  end
end

# In a hypothetical code analysis package:
defmodule CodeAnalysis.Topology.TechnicalDebt do
  @moduledoc """
  Code-specific interpretation of topology.
  
  Uses same primitives, different meaning:
  - β₁ = circular dependencies (bad)
  - Components = isolated modules (maybe good)
  """
  
  alias ExTopology.Graph
  
  def circular_dependency_score(dep_graph) do
    Graph.beta_one(dep_graph) / Graph.num_vertices(dep_graph)
  end
end
```

### Boundary Rules

| Concept | In ex_topology? | Reason |
|---------|-----------------|--------|
| β₁ (cyclomatic number) | ✅ Yes | Pure math, no interpretation |
| kNN variance | ✅ Yes | Pure statistics |
| Distance matrix | ✅ Yes | Pure computation |
| "Fragility score" | ❌ No | CNS interpretation |
| "Chirality" | ❌ No | CNS concept |
| "Technical debt" | ❌ No | Code analysis concept |
| "Circular reasoning" | ❌ No | CNS interpretation of β₁ |

### Test: Is It Generic?

Before adding anything to ex_topology, ask:

1. **Would this make sense in a different domain?**
   - "β₁" → Yes, it's graph theory
   - "Fragility" → No, it's CNS-specific weighting

2. **Does it require domain knowledge to interpret?**
   - "kNN variance" → No, it's pure statistics
   - "SNO coherence" → Yes, requires knowing what SNO means

3. **Could two domains use it differently?**
   - "Distance matrix" → Same computation, different meaning
   - "Causal link score" → Only makes sense for CNS

## Consequences

### Positive

1. **Clean boundaries**: ex_topology stays domain-agnostic
2. **Reusable**: Any domain can use the primitives
3. **Testable**: Generic code has generic tests
4. **Maintainable**: Domain changes don't touch ex_topology

### Negative

1. **Indirection**: CNS must wrap ex_topology calls
2. **Duplication risk**: Domains might duplicate composite patterns

### Mitigations

For common composite patterns, document recipes:

```elixir
# In ex_topology docs, not code:
@moduledoc """
## Recipes

### Computing a "fragility-like" score

Many domains want a composite score from β₁ and embedding variance.
Here's a pattern:

    beta_1 = ExTopology.Graph.beta_one(graph)
    variance = ExTopology.Embedding.knn_variance(points, k: 10)
    
    # Your domain-specific combination:
    score = your_weighting_function(beta_1, variance)

See CNS.Topology.Fragility for a concrete example.
"""
```

## References

- Hexagonal Architecture (Ports & Adapters)
- "Clean Architecture" - Robert C. Martin
- Revised ADR-0003 (scope definition)
- ADR-0009 (versioning - domain code out of scope)
