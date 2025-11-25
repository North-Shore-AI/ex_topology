# ExTopology

**Generic Topological Data Analysis for Elixir**

ExTopology provides foundational topology and TDA algorithms for the Elixir ecosystem. It extracts generic mathematical operations from domain-specific implementations, making them reusable across applications.

## Status

**Pre-Alpha** - Architecture defined, implementation in progress.

## Vision

ExTopology is the topology layer for the North-Shore-AI ecosystem:

```
┌─────────────────────────────────────────────────────────────┐
│                    Applications                              │
│  (CNS experiments, Crucible stages, custom applications)    │
├─────────────────────────────────────────────────────────────┤
│                    ExTopology                                │
│  (Betti numbers, persistent homology, graph metrics)        │
├─────────────────────────────────────────────────────────────┤
│                    Foundations                               │
│  (libgraph, Nx, Scholar)                                    │
└─────────────────────────────────────────────────────────────┘
```

## Planned Features

### Layer 1: Foundations
- Distance computations (Euclidean, cosine, custom metrics)
- Statistical measures (variance, correlation, kNN statistics)
- Graph utilities built on libgraph

### Layer 2: Data Structures
- Simplicial complexes
- Neighborhood graphs (k-NN, epsilon-ball)
- Filtrations (Vietoris-Rips, Alpha)
- Sparse distance matrices

### Layer 3: TDA Algorithms
- Betti number computation
- Persistent homology
- Topological fragility metrics
- Persistence diagrams

## Architecture Decisions

See [docs/adrs/](docs/adrs/) for architecture decision records:

- [ADR-0001: Use libgraph for Graph Algorithms](docs/adrs/0001-use-libgraph-for-graph-algorithms.md)
- [ADR-0002: Use Nx/Scholar for Numerical Foundations](docs/adrs/0002-use-nx-scholar-for-numerical-foundations.md)
- [ADR-0003: Build TDA from Scratch](docs/adrs/0003-build-tda-from-scratch.md)
- [ADR-0004: Layered Architecture Design](docs/adrs/0004-layered-architecture.md)
- [ADR-0005: Sparse Matrix Strategy](docs/adrs/0005-sparse-matrix-strategy.md)
- [ADR-0006: API Design Principles](docs/adrs/0006-api-design-principles.md)

## Installation

*Not yet published to Hex.*

```elixir
def deps do
  [
    {:ex_topology, github: "North-Shore-AI/ex_topology"}
  ]
end
```

## Motivation

The CNS (Conceptual Neighborhood Space) implementation in crucible_framework contains generic topology algorithms that are useful beyond CNS:

- **β₁ (Betti number)**: Graph cycle counting - useful for any connectivity analysis
- **kNN variance**: Neighborhood stability - useful for embedding quality
- **Topological fragility**: Structural robustness - useful for network analysis

ExTopology extracts these algorithms into a reusable library, enabling:

1. **Crucible experiments** to use topology without CNS coupling
2. **Other applications** to leverage battle-tested TDA code
3. **Research** on topology algorithms independent of specific domains

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup.

## License

MIT License - see [LICENSE](LICENSE)
