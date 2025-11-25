# ExTopology Examples

This directory contains runnable examples demonstrating ExTopology's capabilities for topological data analysis.

## Running Examples

### Run All Examples

```bash
./examples/run_all_exs.sh
```

### Run Individual Examples

```bash
# Core functionality (v0.1.0)
mix run examples/quick_examples.exs
mix run examples/correlation_network.exs
mix run examples/group_comparision.exs
mix run examples/neighborhood_graphs.exs
mix run examples/outlier_detection.exs
mix run examples/spatial_connectivity.exs

# Persistent homology (v0.1.1)
mix run examples/persistence_basics.exs
mix run examples/simplicial_complexes.exs
mix run examples/persistence_landscapes.exs
mix run examples/topological_fragility.exs
mix run examples/clique_complexes.exs
```

---

## Core Examples (v0.1.0)

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

## Persistent Homology Examples (v0.1.1)

### 7. `persistence_basics.exs` - Persistent Homology Introduction

Complete introduction to persistent homology workflow:

- Build Vietoris-Rips filtration from point clouds
- Compute persistence diagrams
- Interpret birth/death times of topological features
- Track Betti numbers across scales
- Understand the evolution of topology

**Use case**: Learning TDA fundamentals, first persistent homology analysis.

**Key concepts**: `Filtration.vietoris_rips/2`, `Persistence.compute/2`, `Persistence.betti_numbers/3`

**Output includes**:
- Filtration structure and critical values
- Persistence diagrams for H₀, H₁, H₂
- Feature interpretation (components, loops, voids)
- Betti number evolution across scales

---

### 8. `simplicial_complexes.exs` - Working with Simplices

Deep dive into simplicial complex structures:

- Simplex basics: vertices, edges, triangles, tetrahedra
- Face enumeration and k-faces
- Boundary operator ∂ with alternating signs
- Fundamental theorem: ∂∂ = 0
- Building clique complexes from graphs
- Complex skeletons

**Use case**: Understanding TDA foundations, working with abstract complexes.

**Key concepts**: `Simplex.dimension/1`, `Simplex.faces/1`, `Simplex.boundary/1`, `Simplex.clique_complex/2`

**Mathematical background**:
- Boundary of edge [0,1]: ∂[0,1] = +[1] - [0]
- Boundary of triangle [0,1,2]: ∂[0,1,2] = +[1,2] - [0,2] + [0,1]
- The theorem ∂∂ = 0 is verified by showing all terms cancel

---

### 9. `persistence_landscapes.exs` - Diagram Analysis

Advanced persistence diagram analysis and comparison:

- Diagram statistics (total persistence, entropy, max persistence)
- Filtering features by persistence threshold
- Comparing diagrams with bottleneck distance
- Comparing diagrams with Wasserstein distance
- Persistence landscapes for statistical analysis
- Coordinate transformations (birth-death vs persistence-birth)
- Handling infinite features

**Use case**: Comparing topological structures, statistical analysis of TDA output.

**Key concepts**: `Diagram.summary_statistics/1`, `Diagram.bottleneck_distance/2`, `Diagram.persistence_landscape/3`

**Output includes**:
- Full diagram statistics
- Distance comparisons (similar vs different topology)
- ASCII visualization of persistence landscapes
- Multi-level landscape analysis

---

### 10. `topological_fragility.exs` - Stability Analysis

Analyze robustness and sensitivity of topological features:

- Point removal sensitivity: how topology changes when points removed
- Identifying critical points in data
- Feature stability scores based on persistence
- Local fragility analysis around specific points
- Bottleneck stability threshold
- Overall robustness scoring

**Use case**: Validating TDA findings, identifying influential data points, network analysis.

**Key concepts**: `Fragility.point_removal_sensitivity/2`, `Fragility.identify_critical_points/2`, `Fragility.robustness_score/2`

**Practical applications**:
- Network node importance (hub detection)
- Data quality assessment
- Reliability of topological features

---

### 11. `clique_complexes.exs` - Graph-Based TDA

Topological analysis starting from graph data:

- Building clique complexes from graphs
- Weighted graph filtrations
- Persistent homology on networks
- Critical values and topology evolution
- Extracting complex at specific scales
- Comparing point cloud vs graph approaches

**Use case**: Network analysis, social networks, citation networks, biological networks.

**Key concepts**: `Simplex.clique_complex/2`, `Filtration.from_graph/2`, `Filtration.complex_at/2`

**Output includes**:
- Clique complex structure by dimension
- Graph topological invariants
- Filtration evolution
- Research collaboration network example

---

## Understanding the Output

### Betti Numbers

- **β₀ (beta_zero)**: Number of connected components. Drops when clusters merge.
- **β₁ (beta_one)**: Number of independent cycles. Increases with redundant connections.
- **β₂ (beta_two)**: Number of voids/cavities. Requires 2-simplices (triangles) to form.
- **χ (Euler characteristic)**: V - E + F = β₀ - β₁ + β₂. Topological invariant.

### Persistence

- **Birth**: Scale at which a topological feature first appears
- **Death**: Scale at which the feature disappears
- **Persistence**: death - birth (significance/stability of feature)
- Features with high persistence are significant; low persistence = noise

### Effect Sizes

- **Cohen's d**: Standardized mean difference
  - |d| < 0.2: negligible
  - 0.2 ≤ |d| < 0.5: small
  - 0.5 ≤ |d| < 0.8: medium
  - |d| ≥ 0.8: large

### Isolation Scores

Higher isolation score = more anomalous (far from neighbors relative to their local density).

### Fragility Scores

Higher fragility = more topological impact when point/edge is removed.

---

## Extending the Examples

### Basic Setup

```elixir
# Alias the modules you need
alias ExTopology.{Distance, Neighborhood, Embedding, Statistics}
alias ExTopology.{Simplex, Filtration, Persistence, Diagram, Fragility}
alias ExTopology.Graph, as: Topo

# Prepare your data as Nx tensors
points = Nx.tensor(your_data)
```

### Graph Topology Workflow

```elixir
# Build a neighborhood graph
g = Neighborhood.knn_graph(points, k: 5)

# Compute invariants
inv = Topo.invariants(g)
IO.puts("Components: #{inv.beta_zero}")
IO.puts("Cycles: #{inv.beta_one}")
```

### Persistent Homology Workflow

```elixir
# Build filtration
filtration = Filtration.vietoris_rips(points, max_dimension: 2)

# Compute persistence
diagrams = Persistence.compute(filtration)

# Analyze each dimension
Enum.each(diagrams, fn diagram ->
  stats = Diagram.summary_statistics(diagram)
  IO.puts("H#{diagram.dimension}: #{stats.count} features, max persistence #{stats.max_persistence}")
end)
```

### Fragility Analysis Workflow

```elixir
# Find critical points
scores = Fragility.point_removal_sensitivity(points)
critical = Fragility.identify_critical_points(scores, top_k: 3)
IO.puts("Most influential points: #{inspect(critical)}")

# Overall robustness
robustness = Fragility.robustness_score(points)
IO.puts("Robustness: #{Float.round(robustness, 3)}")
```

---

## Example Dependencies

All examples require the ExTopology library to be installed. From the project root:

```bash
mix deps.get
mix compile
```

Some examples may take a few seconds to run due to persistent homology computations.
