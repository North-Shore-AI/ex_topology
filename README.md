# ExTopology

![ExTopology logo](assets/ex_topology.svg)

[![Hex.pm](https://img.shields.io/hexpm/v/ex_topology.svg)](https://hex.pm/packages/ex_topology)
[![Docs](https://img.shields.io/badge/docs-hexdocs.pm-blue.svg)](https://hexdocs.pm/ex_topology)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

**Generic Topological Data Analysis for Elixir**

ExTopology provides foundational topology and TDA algorithms for the Elixir ecosystem. It extracts generic mathematical operations from domain-specific implementations, making them reusable across applications.

## Status

**v0.1.0** - Core features implemented and tested (200 tests passing).

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

Architecture decision records live in the repository but are not shipped with the Hex package or docs. You can browse them on GitHub:
https://github.com/North-Shore-AI/ex_topology/tree/main/docs/adrs

## Installation

*Not yet published to Hex.*

```elixir
def deps do
  [
    {:ex_topology, github: "North-Shore-AI/ex_topology"}
  ]
end
```

## Quick Start

```elixir
alias ExTopology.{Distance, Neighborhood, Embedding, Statistics}
alias ExTopology.Graph, as: Topo

# Compute pairwise distances
points = Nx.tensor([[0.0, 0.0], [3.0, 4.0], [1.0, 0.0]])
dists = Distance.euclidean_matrix(points)

# Build neighborhood graph
g = Neighborhood.epsilon_graph(points, epsilon: 5.5)

# Compute topological invariants
Topo.beta_zero(g)           # Connected components
Topo.beta_one(g)            # Independent cycles
Topo.euler_characteristic(g) # V - E

# Analyze embedding quality
Embedding.knn_variance(points, k: 2)
Embedding.isolation_scores(points, k: 2)

# Statistical analysis
Statistics.pearson(x, y)
Statistics.cohens_d(group1, group2)
```

## Examples

Run the included examples to see ExTopology in action:

```bash
# Run all examples
./examples/run_all_exs.sh

# Or run individually
mix run examples/quick_examples.exs
mix run examples/correlation_network.exs
mix run examples/outlier_detection.exs
```

See [examples/README.md](examples/README.md) for detailed descriptions.

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

Contributions are welcome; development setup docs will be added soon.

## License

MIT License - see [LICENSE](LICENSE)
