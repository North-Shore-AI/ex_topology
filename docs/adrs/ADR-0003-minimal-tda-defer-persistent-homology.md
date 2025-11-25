# ADR-0003: Minimal TDA Implementation, Defer Persistent Homology

## Status

Accepted (Revised)

*Supersedes original ADR-0003 "Build TDA from Scratch"*

## Context

ex_topology needs topological computation capabilities. The original ADR proposed building full TDA (including persistent homology) from scratch in pure Elixir. 

**This was overscoped.** Analysis of actual requirements reveals:

### What Nordic Road/CNS Actually Needs (Now through Dec 2025)

| Capability | Used For | Complexity |
|------------|----------|------------|
| β₀ (connected components) | Fragmentation detection | Trivial (libgraph) |
| β₁ (cyclomatic number) | Circular reasoning detection | Trivial: `E - V + C` |
| k-NN variance | Embedding fragility | Scholar has this |
| Distance matrices | Neighborhood construction | Nx has this |

### What Full TDA Requires (Not Needed Yet)

| Capability | Complexity | Risk |
|------------|------------|------|
| Simplicial complex construction | Medium | Moderate |
| Boundary matrix reduction | High | High—mod-2 arithmetic |
| Persistent homology | Very High | Very High—algorithm subtlety |
| Persistence diagrams | Medium | Depends on PH |
| Bottleneck/Wasserstein distance | High | Numerical stability |

### Why "Build Full TDA from Scratch" Was Wrong

1. **Persistent homology is hard**: Ripser's performance comes from years of optimization (clearing, apparent pairs, cohomology, implicit matrices). Naive implementations are 100-1000x slower.

2. **Correctness is hard to verify**: TDA + Elixir expertise is vanishingly rare. Who reviews?

3. **It's not needed yet**: CNS uses β₁, not persistence barcodes.

4. **YAGNI**: Building speculative infrastructure violates "don't paint into corners" principle.

## Decision

**Implement minimal topology primitives now. Defer persistent homology until concrete need exists.**

### Phase 1: Graph Topology (Implement Now)

These are trivial and cover current needs:

```elixir
defmodule ExTopology.Graph do
  @moduledoc """
  Graph-theoretic topology measures.
  Thin wrapper over libgraph with topology-specific API.
  """

  @doc """
  β₀: Number of connected components.
  
  ## Example
      iex> g = Graph.new() |> Graph.add_edges([{1,2}, {3,4}])
      iex> ExTopology.Graph.beta_zero(g)
      2
  """
  def beta_zero(graph) do
    graph |> Graph.components() |> length()
  end

  @doc """
  β₁: Cyclomatic number (first Betti number for graphs).
  
  β₁ = E - V + C where:
  - E = edge count
  - V = vertex count  
  - C = component count
  
  Measures independent cycles / circular dependencies.
  
  ## Example
      iex> triangle = Graph.new() |> Graph.add_edges([{1,2}, {2,3}, {3,1}])
      iex> ExTopology.Graph.beta_one(triangle)
      1
  """
  def beta_one(graph) do
    edges = Graph.num_edges(graph)
    vertices = Graph.num_vertices(graph)
    components = beta_zero(graph)
    edges - vertices + components
  end

  @doc """
  Euler characteristic: χ = V - E + F
  For graphs (no faces): χ = V - E = C - β₁
  """
  def euler_characteristic(graph) do
    Graph.num_vertices(graph) - Graph.num_edges(graph)
  end
end
```

### Phase 2: Embedding Metrics (Implement Now)

Extract from CNS, expose generically:

```elixir
defmodule ExTopology.Embedding do
  @moduledoc """
  Topological measures on point clouds / embeddings.
  """

  import Nx.Defn

  @doc """
  k-NN variance: measures local density consistency.
  High variance → fragile/unstable embedding regions.
  """
  defn knn_variance(points, k \\ 10) do
    distances = pairwise_distances(points)
    knn_dists = top_k_per_row(distances, k)
    Nx.variance(knn_dists, axes: [1]) |> Nx.mean()
  end

  @doc """
  Local outlier factor approximation.
  """
  defn lof_scores(points, k \\ 10) do
    # ... implementation
  end
end
```

### Phase 3: Simplicial Complexes (Defer)

Only implement if a concrete use case emerges requiring β₂+:

```elixir
# DO NOT IMPLEMENT YET
defmodule ExTopology.SimplicialComplex do
  # Vietoris-Rips construction
  # Boundary matrices
  # Higher Betti numbers
end
```

### Phase 4: Persistent Homology (Defer Indefinitely)

If persistent homology becomes necessary:

1. **First**: Evaluate NIF wrapper around Ripser/GUDHI
2. **Second**: Consider Pythonx interop
3. **Last resort**: Pure Elixir implementation

Do NOT build pure-Elixir persistent homology speculatively.

## Consequences

### Positive

1. **Ships faster**: Phase 1-2 is days of work, not months
2. **Lower risk**: Graph algorithms are well-understood
3. **Correct by construction**: β₁ formula can't be wrong
4. **Matches actual need**: CNS doesn't use persistence diagrams
5. **Preserves optionality**: Can add PH later via NIFs if needed

### Negative

1. **Limited scope**: Can't compute β₂+ without Phase 3
2. **No persistence diagrams**: Research applications limited
3. **May need to revisit**: If requirements change

### What This Explicitly Defers

| Capability | Status | Revisit Trigger |
|------------|--------|-----------------|
| Simplicial complexes | Deferred | Need β₂ or higher |
| Boundary matrix reduction | Deferred | Need exact Betti numbers for complexes |
| Persistent homology | Deferred indefinitely | Research requirement with budget |
| Persistence diagrams | Deferred indefinitely | Same as above |

## Validation

Phase 1-2 outputs can be validated against:
- NetworkX (Python) for graph metrics
- Manual calculation for small examples
- Property tests: β₀ ≥ 1, β₁ ≥ 0, χ = β₀ - β₁ for graphs

## References

- Ripser paper: "Ripser: efficient computation of Vietoris-Rips persistence barcodes"
- Original CNS.Logic.Betti implementation
- libgraph documentation
