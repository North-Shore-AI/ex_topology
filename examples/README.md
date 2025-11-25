# ExTopology Examples

This directory contains runnable examples demonstrating ExTopology's capabilities for topological data analysis.

## Running Examples

### Run All Examples

```bash
./examples/run_all_exs.sh
```

### Run Individual Examples

```bash
mix run examples/quick_examples.exs
mix run examples/correlation_network.exs
mix run examples/group_comparision.exs
mix run examples/neighborhood_graphs.exs
mix run examples/outlier_detection.exs
mix run examples/spatial_connectivity.exs
```

## Example Descriptions

### 1. `quick_examples.exs` - Comprehensive Feature Tour

A 6-part walkthrough covering all major features:

1. **Distance Matrices**: Euclidean, Manhattan, cosine distances
2. **Graph Topology**: Betti numbers (β₀, β₁), Euler characteristic, tree detection
3. **Neighborhood Graphs**: k-NN and ε-ball graph construction, cluster detection
4. **Embedding Analysis**: k-NN variance, density estimation, outlier detection
5. **Statistical Analysis**: Pearson correlation, Cohen's d effect size, z-scores
6. **Complete Workflow**: End-to-end cluster analysis pipeline

**Best for**: Getting started, understanding the full API.

---

### 2. `correlation_network.exs` - Building Networks from Correlations

Demonstrates converting multivariate data into a correlation network:

- Compute Pearson correlation matrix for gene expression data
- Transform correlations to distances: `d = 1 - |r|`
- Build ε-ball graph connecting highly correlated variables
- Analyze network topology (components, cycles)

**Use case**: Gene co-expression networks, variable clustering, feature relationships.

**Key concepts**: `Statistics.correlation_matrix/1`, `Neighborhood.from_distance_matrix/2`

---

### 3. `group_comparision.exs` - Statistical Group Analysis

Compare experimental groups using statistical measures:

- Summary statistics (mean, std, median, quartiles)
- Effect size with Cohen's d
- Coefficient of variation for relative spread
- Z-scores for within-group outlier detection
- IQR for robust spread estimation

**Use case**: A/B testing, treatment vs control analysis, experimental design.

**Key concepts**: `Statistics.cohens_d/2`, `Statistics.z_scores/1`, `Statistics.summary/1`

---

### 4. `neighborhood_graphs.exs` - Comparing Graph Constructions

Build and compare different neighborhood graph types on the same point set:

- **k-NN graph** (mutual): Connect points that are mutual k-nearest neighbors
- **ε-ball graph**: Connect points within distance ε
- **Gabriel graph**: Edge (i,j) exists if no other point in the diametric circle
- **Relative neighborhood graph (RNG)**: Stricter than Gabriel, sparser

Shows how different constructions yield different topologies on the same data.

**Use case**: Choosing appropriate neighborhood structure for your analysis.

**Key concepts**: `Neighborhood.knn_graph/2`, `Neighborhood.epsilon_graph/2`, `Neighborhood.gabriel_graph/1`

---

### 5. `outlier_detection.exs` - Finding Anomalies in Embeddings

Detect outliers in low-dimensional embeddings:

- Generate synthetic data with planted outliers
- Compute k-NN distances and isolation scores
- Identify sparse points (low local density)
- Analyze distance distribution statistics

**Use case**: Quality control in dimensionality reduction, anomaly detection.

**Key concepts**: `Embedding.isolation_scores/2`, `Embedding.sparse_points/2`, `Embedding.statistics/2`

---

### 6. `spatial_connectivity.exs` - Multi-Scale Spatial Analysis

Analyze spatial sampling locations with varying connectivity thresholds:

- Build ε-ball graphs at multiple scales (ε = 0.3, 1.0, 8.0)
- Watch topology change: clusters merge as ε increases
- Compute local density and identify sparse regions
- Find spatial outliers (isolated sampling stations)

**Use case**: Ecology/environmental sampling, sensor networks, geographic analysis.

**Key concepts**: Multi-scale topology, `Topo.beta_zero/1` tracking component merging

---

## Understanding the Output

### Betti Numbers

- **β₀ (beta_zero)**: Number of connected components. Drops when clusters merge.
- **β₁ (beta_one)**: Number of independent cycles. Increases with redundant connections.
- **χ (Euler characteristic)**: V - E = β₀ - β₁. Topological invariant.

### Effect Sizes

- **Cohen's d**: Standardized mean difference
  - |d| < 0.2: negligible
  - 0.2 ≤ |d| < 0.5: small
  - 0.5 ≤ |d| < 0.8: medium
  - |d| ≥ 0.8: large

### Isolation Scores

Higher isolation score = more anomalous (far from neighbors relative to their local density).

---

## Extending the Examples

To create your own examples:

```elixir
# 1. Alias the modules you need
alias ExTopology.{Distance, Neighborhood, Embedding, Statistics}
alias ExTopology.Graph, as: Topo

# 2. Prepare your data as Nx tensors
points = Nx.tensor(your_data)

# 3. Build graphs and compute invariants
g = Neighborhood.knn_graph(points, k: 5)
inv = Topo.invariants(g)

IO.puts("Components: #{inv.beta_zero}")
IO.puts("Cycles: #{inv.beta_one}")
```
