<p align="center">
  <img src="assets/ex_topology.svg" alt="ExTopology" width="200">
</p>

# ExTopology

[![Hex.pm](https://img.shields.io/hexpm/v/ex_topology.svg)](https://hex.pm/packages/ex_topology)
[![Docs](https://img.shields.io/badge/docs-hexdocs.pm-blue.svg)](https://hexdocs.pm/ex_topology)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

**Generic Topological Data Analysis for Elixir**

ExTopology provides foundational topology and TDA algorithms for the Elixir ecosystem. It includes distance computations, neighborhood graphs, Betti numbers, persistent homology, and topological fragility analysis.

## Status

**v0.2.0** - Crucible Stage integration and code quality improvements.

## Installation

```elixir
def deps do
  [
    {:ex_topology, github: "North-Shore-AI/ex_topology"}
  ]
end
```

## Features Overview

| Module | Purpose |
|--------|---------|
| `Distance` | Pairwise distance matrices (Euclidean, cosine, Manhattan, etc.) |
| `Neighborhood` | Graph construction (k-NN, ε-ball, Gabriel, RNG) |
| `Graph` | Topological invariants (β₀, β₁, Euler characteristic) |
| `Embedding` | Embedding quality metrics (k-NN variance, density, isolation) |
| `Statistics` | Statistical analysis (correlation, effect size, z-scores) |
| `Simplex` | Simplicial complex operations (faces, boundary operator) |
| `Filtration` | Vietoris-Rips and graph filtrations |
| `Persistence` | Persistent homology computation |
| `Diagram` | Persistence diagram analysis and distances |
| `Fragility` | Topological stability and sensitivity analysis |

---

## Quick Start

```elixir
alias ExTopology.{Distance, Neighborhood, Embedding, Statistics}
alias ExTopology.{Simplex, Filtration, Persistence, Diagram, Fragility}
alias ExTopology.Graph, as: Topo

# Sample point cloud
points = Nx.tensor([
  [0.0, 0.0],
  [1.0, 0.0],
  [0.5, 0.866]
])

# Compute persistent homology
filtration = Filtration.vietoris_rips(points, max_dimension: 2)
diagrams = Persistence.compute(filtration)

# Analyze the H₁ diagram (cycles)
h1 = Enum.find(diagrams, & &1.dimension == 1)
Diagram.total_persistence(h1)
```

---

## Module Reference

### Distance Matrices

Compute pairwise distances between points in a dataset.

```elixir
alias ExTopology.Distance

points = Nx.tensor([[0.0, 0.0], [3.0, 4.0], [1.0, 0.0]])

# Euclidean distance (L2)
Distance.euclidean_matrix(points)
# => 3x3 tensor with d(0,1) = 5.0

# Manhattan distance (L1)
Distance.manhattan_matrix(points)

# Cosine distance (1 - cosine similarity)
Distance.cosine_matrix(points)

# Chebyshev distance (L∞)
Distance.chebyshev_matrix(points)

# Minkowski distance (Lp)
Distance.minkowski_matrix(points, 3)  # p=3

# Generic pairwise with metric option
Distance.pairwise(points, metric: :euclidean)
```

### Neighborhood Graphs

Build graphs connecting nearby points.

```elixir
alias ExTopology.Neighborhood

points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [0.5, 0.5], [10.0, 10.0]])

# k-Nearest Neighbors graph
g = Neighborhood.knn_graph(points, k: 2)
g = Neighborhood.knn_graph(points, k: 2, mutual: true)  # Mutual k-NN
g = Neighborhood.knn_graph(points, k: 2, weighted: true) # Edge weights = distances

# Epsilon-ball graph (connect points within distance ε)
g = Neighborhood.epsilon_graph(points, epsilon: 1.5)
g = Neighborhood.epsilon_graph(points, epsilon: 1.5, strict: true)  # < instead of <=

# Gabriel graph (edge if no point in diametric circle)
g = Neighborhood.gabriel_graph(points)

# Relative Neighborhood Graph (stricter than Gabriel)
g = Neighborhood.relative_neighborhood_graph(points)

# Build from precomputed distance matrix
dists = Distance.euclidean_matrix(points)
g = Neighborhood.from_distance_matrix(dists, k: 3)
g = Neighborhood.from_distance_matrix(dists, epsilon: 2.0)
```

### Graph Topology

Compute topological invariants of graphs.

```elixir
alias ExTopology.Graph, as: Topo

# Build a graph (using libgraph)
g = Graph.new() |> Graph.add_edges([{:a, :b}, {:b, :c}, {:c, :a}])

# Betti numbers
Topo.beta_zero(g)           # β₀ = number of connected components
Topo.beta_one(g)            # β₁ = number of independent cycles

# Euler characteristic
Topo.euler_characteristic(g)  # χ = V - E = β₀ - β₁

# Graph properties
Topo.connected?(g)          # Single component?
Topo.tree?(g)               # Connected and acyclic?
Topo.forest?(g)             # Acyclic (possibly disconnected)?

# All invariants at once
Topo.invariants(g)
# => %{vertices: 3, edges: 3, beta_zero: 1, beta_one: 1,
#      euler_characteristic: 0, components: 1}

# Edge counting (handles undirected)
Topo.num_edges(g)
Topo.num_vertices(g)
```

### Embedding Analysis

Analyze quality and structure of point embeddings.

```elixir
alias ExTopology.Embedding

points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [2.0, 0.0], [100.0, 0.0]])

# k-NN variance (lower = more uniform spacing)
Embedding.knn_variance(points, k: 2)
Embedding.knn_variance(points, k: 2, reduce: :none)  # Per-point variance
Embedding.knn_variance(points, k: 2, reduce: :max)   # Maximum variance

# k-NN distances
Embedding.knn_distances(points, k: 2)      # Shape: {n, k}
Embedding.mean_knn_distance(points, k: 2)  # Shape: {n}

# Local density (inverse of mean k-NN distance)
Embedding.local_density(points, k: 3)

# Isolation scores (outlier detection)
scores = Embedding.isolation_scores(points, k: 3)
# Point 3 (at 100.0) will have highest score

# Find sparse points (potential outliers)
Embedding.sparse_points(points, k: 3, percentile: 10)
# => Indices of bottom 10% density points

# Comprehensive statistics
Embedding.statistics(points, k: 3)
# => %{n_points: 4, dimensions: 2, knn_variance: ...,
#      mean_knn_distance: ..., density_mean: ..., density_std: ...}
```

### Statistical Analysis

Statistical measures for data analysis.

```elixir
alias ExTopology.Statistics

x = Nx.tensor([1.0, 2.0, 3.0, 4.0, 5.0])
y = Nx.tensor([2.0, 4.0, 5.0, 4.0, 5.0])

# Correlation
Statistics.pearson(x, y)                    # Pearson r
Statistics.spearman(x, y)                   # Spearman rank correlation
Statistics.correlation(x, y, method: :spearman)

# Correlation matrix (columns = variables)
data = Nx.tensor([[1.0, 2.0], [2.0, 4.0], [3.0, 6.0]])
Statistics.correlation_matrix(data)

# Effect size
group1 = Nx.tensor([1.0, 1.1, 0.9, 1.2])
group2 = Nx.tensor([2.0, 2.1, 1.9, 2.2])
Statistics.cohens_d(group1, group2)  # Cohen's d

# Descriptive statistics
Statistics.summary([1, 2, 3, 4, 5])
# => %{count: 5, mean: 3.0, std: 1.41, min: 1, max: 5,
#      median: 3, q1: 2, q3: 4}

# Other measures
Statistics.z_scores(x)                      # Standardized scores
Statistics.iqr(x)                           # Interquartile range
Statistics.coefficient_of_variation(x)      # CV = std/mean
Statistics.coefficient_of_variation(x, as_percent: true)
```

---

## Persistent Homology

### Simplicial Complexes

```elixir
alias ExTopology.Simplex

# Create simplices (vertices as sorted integer lists)
v = Simplex.new([0])           # 0-simplex (vertex)
e = Simplex.new([0, 1])        # 1-simplex (edge)
t = Simplex.new([0, 1, 2])     # 2-simplex (triangle)

# Dimension
Simplex.dimension(t)  # => 2

# Faces (boundary)
Simplex.faces(t)      # => [[0, 1], [0, 2], [1, 2]]
Simplex.faces(t, 0)   # => [[0], [1], [2]]  (vertices)

# Boundary operator
Simplex.boundary(t)
# => [{[0, 1], 1}, {[0, 2], -1}, {[1, 2], 1}]  (with orientations)

# Build clique complex from graph
g = Graph.new() |> Graph.add_edges([{0, 1}, {1, 2}, {0, 2}])
Simplex.clique_complex(g, max_dimension: 2)
# => [[0], [1], [2], [0, 1], [0, 2], [1, 2], [0, 1, 2]]
```

### Filtrations

```elixir
alias ExTopology.Filtration

points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [0.5, 0.866]])

# Vietoris-Rips filtration
filtration = Filtration.vietoris_rips(points, max_dimension: 2)
# => [{0.0, [0]}, {0.0, [1]}, {0.0, [2]},
#     {1.0, [0, 1]}, {1.0, [0, 2]}, {1.0, [1, 2]},
#     {1.0, [0, 1, 2]}]

# With distance threshold
filtration = Filtration.vietoris_rips(points,
  max_dimension: 2,
  max_scale: 2.0
)

# From precomputed distances
dists = Distance.euclidean_matrix(points)
filtration = Filtration.vietoris_rips_from_distances(dists, max_dimension: 2)

# Extract complex at specific scale
Filtration.complex_at_scale(filtration, 0.5)

# Get critical values (scales where topology changes)
Filtration.critical_values(filtration)

# Validate filtration (faces appear before cofaces)
Filtration.valid?(filtration)
```

### Computing Persistence

```elixir
alias ExTopology.Persistence

points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [0.5, 0.866]])
filtration = Filtration.vietoris_rips(points, max_dimension: 2)

# Compute persistent homology
diagrams = Persistence.compute(filtration)
# => [%{dimension: 0, pairs: [...]}, %{dimension: 1, pairs: [...]}]

# Each diagram contains (birth, death) pairs
h0 = Enum.find(diagrams, & &1.dimension == 0)
h1 = Enum.find(diagrams, & &1.dimension == 1)

# Pairs format: {birth_scale, death_scale}
# death = :infinity means the feature never dies

# Betti numbers at specific scale
Persistence.betti_numbers(filtration, 0.5)
# => %{0 => 3, 1 => 0}  (3 components, no cycles at scale 0.5)

# Persistence pairs directly
Persistence.persistence_pairs(filtration)
```

### Persistence Diagrams

```elixir
alias ExTopology.Diagram

# Assuming we have computed diagrams
diagrams = Persistence.compute(filtration)
h1 = Enum.find(diagrams, & &1.dimension == 1)

# Summary statistics
Diagram.total_persistence(h1)      # Sum of (death - birth)
Diagram.max_persistence(h1)        # Longest-lived feature
Diagram.persistence_entropy(h1)    # Entropy of persistence distribution
Diagram.summary_statistics(h1)     # All stats

# Filter by persistence
Diagram.filter_by_persistence(h1, min: 0.5)
Diagram.filter_by_persistence(h1, max: 2.0)

# Filter by birth/death time
Diagram.filter_by_birth(h1, min: 0.0, max: 1.0)
Diagram.filter_by_death(h1, min: 0.5)

# Number of features
Diagram.count(h1)
Diagram.count_finite(h1)    # Exclude :infinity deaths
Diagram.count_infinite(h1)  # Only :infinity deaths

# Distance between diagrams
d1 = %{dimension: 1, pairs: [{0.0, 1.0}, {0.5, 1.5}]}
d2 = %{dimension: 1, pairs: [{0.0, 1.1}, {0.4, 1.6}]}

Diagram.bottleneck_distance(d1, d2)   # L∞ matching distance
Diagram.wasserstein_distance(d1, d2)  # L1 matching distance (p=1)
Diagram.wasserstein_distance(d1, d2, p: 2)  # L2 (p=2)

# Persistence landscapes
Diagram.persistence_landscape(h1, resolution: 100)
```

### Topological Fragility

```elixir
alias ExTopology.Fragility

points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [0.5, 0.866], [0.5, 0.3]])

# Point removal sensitivity
# How much does removing each point change the topology?
scores = Fragility.point_removal_sensitivity(points, k: 2)
# => Tensor of sensitivity scores per point

# Identify critical points (high sensitivity)
Fragility.identify_critical_points(scores, threshold: 0.8)
# => Indices of points whose removal significantly changes topology

# Edge perturbation sensitivity (for graphs)
g = Neighborhood.epsilon_graph(points, epsilon: 1.0)
Fragility.edge_sensitivity(g)

# Feature stability
# How stable are persistence features under noise?
Fragility.feature_stability(points, noise_level: 0.1, samples: 10)

# Overall robustness score
Fragility.robustness_score(points, k: 3)
# => Single score in [0, 1], higher = more robust

# Local fragility (per-point)
Fragility.local_fragility(points, k: 3)

# Bottleneck stability threshold
# Minimum perturbation to change topology
Fragility.bottleneck_stability_threshold(points)
```

---

## Common Workflows

### Cluster Detection

```elixir
# 1. Build neighborhood graph
points = load_your_data()
g = Neighborhood.epsilon_graph(points, epsilon: find_good_epsilon(points))

# 2. Count clusters
n_clusters = Topo.beta_zero(g)

# 3. Verify via persistent homology
filtration = Filtration.vietoris_rips(points, max_dimension: 1)
diagrams = Persistence.compute(filtration)
h0 = Enum.find(diagrams, & &1.dimension == 0)

# Long-lived H0 features = stable clusters
stable_clusters = Diagram.filter_by_persistence(h0, min: threshold)
```

### Outlier Detection

```elixir
# Method 1: Isolation scores
scores = Embedding.isolation_scores(points, k: 5)
outliers = Embedding.sparse_points(points, k: 5, percentile: 5)

# Method 2: Topological fragility
sensitivity = Fragility.point_removal_sensitivity(points, k: 5)
critical = Fragility.identify_critical_points(sensitivity, threshold: 0.9)
```

### Embedding Quality Assessment

```elixir
# Check if embedding preserves local structure
variance = Embedding.knn_variance(points, k: 10)
# Low variance = uniform local density = good embedding

# Check for holes/voids
filtration = Filtration.vietoris_rips(points, max_dimension: 2)
diagrams = Persistence.compute(filtration)
h1 = Enum.find(diagrams, & &1.dimension == 1)

# Persistent H1 features = real cycles in data
significant_cycles = Diagram.filter_by_persistence(h1, min: 0.5)
```

### Comparing Datasets

```elixir
# Compute persistence for both datasets
d1 = compute_h1_diagram(dataset1)
d2 = compute_h1_diagram(dataset2)

# Measure topological similarity
distance = Diagram.bottleneck_distance(d1, d2)
# Small distance = similar topological structure
```

---

## Examples

Run the included examples:

```bash
# Run all examples
./examples/run_all_exs.sh

# Core examples (v0.1.0)
mix run examples/quick_examples.exs        # Feature tour
mix run examples/correlation_network.exs   # Build network from correlations
mix run examples/group_comparision.exs     # Statistical comparison
mix run examples/neighborhood_graphs.exs   # Compare graph constructions
mix run examples/outlier_detection.exs     # Find anomalies
mix run examples/spatial_connectivity.exs  # Multi-scale analysis

# Persistent homology examples (v0.1.1)
mix run examples/persistence_basics.exs    # TDA workflow introduction
mix run examples/simplicial_complexes.exs  # Simplex operations
mix run examples/persistence_landscapes.exs # Diagram analysis
mix run examples/topological_fragility.exs # Stability analysis
mix run examples/clique_complexes.exs      # Graph-based TDA
```

See [examples/README.md](examples/README.md) for detailed descriptions.

---

## Architecture

ExTopology is the topology layer for the North-Shore-AI ecosystem:

```
┌─────────────────────────────────────────────────────────────┐
│                         Applications                        │
│            CNS experiments | Crucible stages | apps         │
├─────────────────────────────────────────────────────────────┤
│                          ExTopology                         │
│  Persistence | Diagram | Fragility | Simplex | Filtration   │
│  Graph | Distance | Neighborhood | Embedding                │
├─────────────────────────────────────────────────────────────┤
│                         Foundations                         │
│                  libgraph | Nx | Scholar                    │
└─────────────────────────────────────────────────────────────┘
```

Architecture decision records: [docs/adrs/](https://github.com/North-Shore-AI/ex_topology/tree/main/docs/adrs)

---

## Crucible Integration

ExTopology can be used as a stage in Crucible experiment pipelines via `ExTopology.Stage`.

### Basic Usage

```elixir
pipeline = [
  {Crucible.Stage.DataLoad, %{dataset: "embeddings"}},
  {ExTopology.Stage, %{
    data_key: :embeddings,
    compute: [:betti, :persistence, :fragility, :embedding],
    k: 10,
    max_dimension: 1
  }}
]
```

### Available Metrics

The stage computes TDA metrics and stores them in `ctx.metrics[:tda]`:

| Option | Metrics | Description |
|--------|---------|-------------|
| `:betti` | `beta_zero`, `beta_one`, `euler_characteristic` | Graph topology invariants |
| `:persistence` | `total_persistence`, `max_persistence` | Persistent homology summary |
| `:fragility` | `robustness_score`, `mean_sensitivity` | Topological stability |
| `:embedding` | `knn_variance`, `mean_knn_distance`, `density_mean` | Embedding quality |

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `:data_key` | `:embeddings` | Key in `ctx.assigns` containing point cloud data |
| `:compute` | `[:betti, :embedding]` | List of metric categories to compute |
| `:k` | `10` | Number of neighbors for k-NN graph |
| `:max_dimension` | `1` | Maximum dimension for persistence computation |

### Output

Results are stored in:
- `ctx.metrics[:tda]` - Summary metrics map
- `ctx.assigns[:tda_diagrams]` - Persistence diagrams (if `:persistence` computed)
- `ctx.assigns[:tda_fragility]` - Fragility details (if `:fragility` computed)

### Example

```elixir
alias ExTopology.Stage

# Create context with embeddings
ctx = %{
  assigns: %{embeddings: Nx.tensor([[0.0, 0.0], [1.0, 0.0], [0.5, 0.866]])},
  metrics: %{}
}

# Run TDA analysis
{:ok, result} = Stage.run(ctx, %{
  compute: [:betti, :persistence],
  k: 2
})

# Access results
result.metrics[:tda][:beta_zero]      # Number of connected components
result.metrics[:tda][:beta_one]       # Number of independent cycles
result.metrics[:tda][:total_persistence]  # Sum of feature lifetimes
```

---

## Contributing

Contributions are welcome. Please ensure:

- All tests pass: `mix test`
- Code is formatted: `mix format`
- No Credo issues: `mix credo --strict`

---

## License

MIT License - see [LICENSE](LICENSE)
