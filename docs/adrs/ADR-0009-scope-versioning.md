# ADR-0009: Scope Definition and Versioning

## Status

Accepted

## Context

ex_topology could theoretically encompass all of computational topology. Without explicit scope boundaries, the project risks:

- Feature creep into research-grade functionality
- Never shipping a usable v1.0
- Unclear API stability guarantees
- Confusion about what problems the library solves

### Stakeholder Needs

| Stakeholder | Primary Need | Timeline |
|-------------|--------------|----------|
| CNS/Crucible | β₁, kNN variance, fragility | Now |
| Nordic Road | Generic topology metrics | Q4 2025 |
| Elixir community | First topology library | When stable |
| Research users | Full TDA | Not committed |

## Decision

**Define explicit scope tiers with versioning commitments.**

### v0.1.0 - Minimum Viable Topology (Target: 2 weeks)

**Goal**: Extract CNS topology code into reusable library.

| Feature | Status | Notes |
|---------|--------|-------|
| `ExTopology.Graph.beta_zero/1` | In scope | Connected components |
| `ExTopology.Graph.beta_one/1` | In scope | Cyclomatic number |
| `ExTopology.Graph.euler_characteristic/1` | In scope | V - E |
| `ExTopology.Neighborhood.knn_graph/2` | In scope | k-NN graph construction |
| `ExTopology.Neighborhood.epsilon_graph/2` | In scope | ε-ball graph |
| `ExTopology.Distance.euclidean_matrix/1` | In scope | Pairwise distances |
| `ExTopology.Distance.cosine_matrix/1` | In scope | Cosine distances |

**API Stability**: Experimental. Breaking changes expected.

```elixir
# v0.1.0 public API
ExTopology.Graph.beta_zero(graph)
ExTopology.Graph.beta_one(graph)
ExTopology.Graph.euler_characteristic(graph)
ExTopology.Neighborhood.knn_graph(points, k: 10)
ExTopology.Neighborhood.epsilon_graph(points, epsilon: 0.5)
ExTopology.Distance.euclidean_matrix(tensor)
ExTopology.Distance.cosine_matrix(tensor)
```

### v0.2.0 - Embedding Metrics (Target: +2 weeks)

**Goal**: Generic embedding analysis tools.

| Feature | Status | Notes |
|---------|--------|-------|
| `ExTopology.Embedding.knn_variance/2` | In scope | Local density variance |
| `ExTopology.Embedding.knn_distances/2` | In scope | Distance statistics |
| `ExTopology.Embedding.density_estimate/2` | In scope | Local density |
| `ExTopology.Statistics.correlation/2` | In scope | Pearson/Spearman |

**API Stability**: Experimental. Breaking changes possible.

### v1.0.0 - Stable Release (Target: Q4 2025)

**Goal**: Production-ready graph topology with stable API.

| Feature | Status | Commitment |
|---------|--------|------------|
| All v0.1-0.2 features | Stable | No breaking changes |
| Comprehensive documentation | Required | Hexdocs complete |
| Property-based tests | Required | Mathematical invariants |
| Cross-validation | Required | NetworkX validation |
| Performance benchmarks | Required | Published baselines |

**API Stability**: Stable. Semantic versioning enforced.

**Not in v1.0**:
- Simplicial complexes
- Boundary matrices
- Persistent homology
- Persistence diagrams
- Higher Betti numbers (β₂+)

### v2.0.0 - Extended Topology (Not Scheduled)

**Goal**: If research needs demand it.

| Feature | Status | Trigger |
|---------|--------|---------|
| Simplicial complex construction | Deferred | Concrete use case |
| Vietoris-Rips complex | Deferred | Need β₂+ |
| Boundary matrices | Deferred | Need exact Betti |
| Persistent homology | Deferred | Research budget |
| NIF acceleration | Deferred | Performance ceiling |

**Commitment**: None. Will evaluate when/if concrete needs emerge.

## Explicit Non-Goals

These are **out of scope** for ex_topology entirely:

| Non-Goal | Reason | Alternative |
|----------|--------|-------------|
| Visualization | Separate concern | Use VegaLite, D3 |
| Graph database integration | Application layer | User implements |
| Distributed computation | Complexity | Use Flow/Broadway |
| Real-time streaming | Different problem | Use GenStage |
| Machine learning models | Nx ecosystem | Use Scholar, Axon |
| Domain-specific adapters | Keep generic | CNS implements own |

## Module Structure

```
lib/ex_topology/
├── graph.ex              # β₀, β₁, χ (v0.1)
├── neighborhood.ex       # kNN, ε-ball graphs (v0.1)
├── distance.ex           # Distance matrices (v0.1)
├── embedding.ex          # Embedding metrics (v0.2)
├── statistics.ex         # Correlation, variance (v0.2)
└── [future]/             # v2.0+ only
    ├── simplicial.ex
    ├── boundary.ex
    └── persistence.ex
```

## Versioning Policy

```
MAJOR.MINOR.PATCH

MAJOR: Breaking API changes (v1.0 → v2.0)
MINOR: New features, backward compatible (v1.0 → v1.1)
PATCH: Bug fixes only (v1.0.0 → v1.0.1)
```

### Pre-1.0 Policy

- v0.x releases may have breaking changes in any release
- CHANGELOG must document all breaking changes
- Deprecation warnings when possible

### Post-1.0 Policy

- Breaking changes require MAJOR version bump
- Deprecated functions supported for 2 MINOR versions
- Security fixes may bypass deprecation cycle

## Consequences

### Positive

1. **Clear expectations**: Users know what's stable
2. **Focused development**: Don't build speculative features
3. **Shippable milestones**: v0.1 is achievable in days
4. **Clean separation**: Domain adapters stay in domain packages

### Negative

1. **Limited scope**: Can't market as "full TDA library"
2. **Future planning**: v2.0 scope undefined
3. **Research gaps**: Won't serve all academic use cases

## Migration Path for CNS

```elixir
# Current CNS code
CNS.Logic.Betti.cyclomatic_number(graph)
CNS.Topology.Surrogates.knn_variance(embeddings)

# After ex_topology v0.2
ExTopology.Graph.beta_one(graph)
ExTopology.Embedding.knn_variance(embeddings)

# CNS becomes thin wrapper
defmodule CNS.Topology.Surrogates do
  defdelegate cyclomatic_number(graph), to: ExTopology.Graph, as: :beta_one
  defdelegate knn_variance(embeddings), to: ExTopology.Embedding
end
```

## Timeline Summary

```
Week 1-2:  v0.1.0 - Graph topology (β₀, β₁, neighborhoods)
Week 3-4:  v0.2.0 - Embedding metrics
Week 5-8:  Testing, docs, benchmarks
Q4 2025:   v1.0.0 - Stable release
TBD:       v2.0.0 - If needed
```

## References

- Semantic Versioning 2.0.0 (semver.org)
- Elixir library guidelines
- Revised ADR-0003 (phase definitions)
- Nordic Road product roadmap
