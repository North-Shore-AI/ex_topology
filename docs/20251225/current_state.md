# ExTopology - Current State Documentation

**Date**: 2025-12-25
**Version**: 0.1.1
**Status**: Full TDA pipeline implemented (371 tests passing per README)

## Overview

ExTopology is a generic Topological Data Analysis (TDA) library for Elixir. It provides foundational topology algorithms for the North-Shore-AI ecosystem, including distance computations, neighborhood graphs, Betti numbers, persistent homology, and topological fragility analysis.

## Architecture

```
Domain Layer (NOT in ex_topology)
+-- CNS (Fragility, SNO, Chirality)
+-- CodeAnalysis (TechDebt, Coupling)
+-- ... other domains

ex_topology (GENERIC)
+-- Layer 3: Analysis (Fragility, Diagram)
+-- Layer 2: Algorithms (Graph, Persistence, Filtration)
+-- Layer 1: Structures (Neighborhood, Distance, Simplex)

Foundation (External)
+-- libgraph, Nx / Scholar, Erlang stdlib
```

## Dependencies

From `mix.exs` (lines 42-59):

| Dependency | Version | Purpose |
|------------|---------|---------|
| `libgraph` | ~> 0.16 | Graph data structures and algorithms |
| `nx` | ~> 0.7 | Numerical computing (tensors) |
| `scholar` | ~> 0.3 | ML algorithms |
| `stream_data` | ~> 1.0 | Property-based testing (dev/test) |
| `benchee` | ~> 1.0 | Benchmarking (dev) |
| `ex_doc` | ~> 0.31 | Documentation (dev) |
| `dialyxir` | ~> 1.4 | Static analysis (dev/test) |
| `credo` | ~> 1.7 | Code quality (dev/test) |

## Module Structure

### Core Module

**File**: `/home/home/p/g/North-Shore-AI/ex_topology/lib/ex_topology.ex`

```elixir
defmodule ExTopology do
  @spec version() :: String.t()  # Line 56-57
end
```

Returns library version string "0.1.0".

---

### Layer 1: Data Structures

#### ExTopology.Distance

**File**: `/home/home/p/g/North-Shore-AI/ex_topology/lib/ex_topology/distance.ex`

Pairwise distance matrix computation using Nx tensors.

| Function | Line | Signature | Description |
|----------|------|-----------|-------------|
| `euclidean_matrix/1` | 78-95 | `(Nx.Tensor.t()) :: Nx.Tensor.t()` | L2 distance matrix |
| `cosine_matrix/1` | 128-141 | `(Nx.Tensor.t()) :: Nx.Tensor.t()` | Cosine distance matrix |
| `manhattan_matrix/1` | 172-179 | `(Nx.Tensor.t()) :: Nx.Tensor.t()` | L1 distance matrix |
| `chebyshev_matrix/1` | 210-217 | `(Nx.Tensor.t()) :: Nx.Tensor.t()` | L-infinity distance matrix |
| `minkowski_matrix/2` | 262-269 | `(Nx.Tensor.t(), number()) :: Nx.Tensor.t()` | Lp distance matrix |
| `squared_euclidean_matrix/1` | 299-306 | `(Nx.Tensor.t()) :: Nx.Tensor.t()` | Squared Euclidean (faster) |
| `distance/3` | 335-346 | `(Nx.Tensor.t(), Nx.Tensor.t(), keyword()) :: Nx.Tensor.t()` | Point-to-point distance |
| `pairwise/2` | 373-386 | `(Nx.Tensor.t(), keyword()) :: Nx.Tensor.t()` | Generic pairwise with metric option |

**Implementation Notes**:
- Uses `Nx.Defn` for JIT-compiled numerical operations
- Broadcasting via `Nx.new_axis/2` for efficient pairwise computation
- All matrices are symmetric with zero diagonal

---

#### ExTopology.Neighborhood

**File**: `/home/home/p/g/North-Shore-AI/ex_topology/lib/ex_topology/neighborhood.ex`

Neighborhood graph construction from point clouds.

| Function | Line | Signature | Description |
|----------|------|-----------|-------------|
| `knn_graph/2` | 81-105 | `(point_input(), keyword()) :: Graph.t()` | k-nearest neighbors graph |
| `epsilon_graph/2` | 144-164 | `(point_input(), keyword()) :: Graph.t()` | Epsilon-ball graph |
| `from_distance_matrix/2` | 191-217 | `(Nx.Tensor.t(), keyword()) :: Graph.t()` | Graph from precomputed distances |
| `gabriel_graph/2` | 243-264 | `(point_input(), keyword()) :: Graph.t()` | Gabriel graph |
| `relative_neighborhood_graph/2` | 283-303 | `(point_input(), keyword()) :: Graph.t()` | Relative neighborhood graph |

**Options**:
- `:k` - Number of nearest neighbors
- `:epsilon` - Radius threshold
- `:metric` - Distance metric (default: `:euclidean`)
- `:weighted` - Include edge weights (default: `false`)
- `:mutual` - Mutual k-NN only (default: `false`)
- `:strict` - Use `<` instead of `<=` (default: `false`)

---

#### ExTopology.Simplex

**File**: `/home/home/p/g/North-Shore-AI/ex_topology/lib/ex_topology/simplex.ex`

Simplicial complex operations.

| Function | Line | Signature | Description |
|----------|------|-----------|-------------|
| `dimension/1` | 57-59 | `(simplex()) :: integer()` | Returns k for k-simplex |
| `normalize/1` | 80-83 | `(simplex()) :: simplex()` | Sort and deduplicate vertices |
| `faces/1` | 109-118 | `(simplex()) :: [simplex()]` | All (k-1)-dimensional faces |
| `k_faces/2` | 143-147 | `(simplex(), non_neg_integer()) :: [simplex()]` | All k-dimensional faces |
| `boundary/1` | 176-189 | `(simplex()) :: boundary_chain()` | Boundary operator with signs |
| `is_face?/2` | 211-216 | `(simplex(), simplex()) :: boolean()` | Check face relationship |
| `clique_complex/2` | 244-254 | `(Graph.t(), keyword()) :: map()` | Build clique complex from graph |
| `all_simplices/2` | 319-328 | `(map(), non_neg_integer()) :: [simplex()]` | Flatten complex to list |
| `skeleton/2` | 348-355 | `(map(), non_neg_integer()) :: map()` | k-skeleton of complex |

**Types**:
- `simplex :: [non_neg_integer()]` - Sorted list of vertex indices
- `boundary_chain :: [{sign :: integer(), simplex()}]`

---

### Layer 2: Algorithms

#### ExTopology.Graph

**File**: `/home/home/p/g/North-Shore-AI/ex_topology/lib/ex_topology/graph.ex`

Graph-theoretic topology measures.

| Function | Line | Signature | Description |
|----------|------|-----------|-------------|
| `beta_zero/1` | 77-82 | `(Graph.t()) :: non_neg_integer()` | Number of connected components |
| `beta_one/1` | 134-143 | `(Graph.t()) :: non_neg_integer()` | Cyclomatic number (independent cycles) |
| `euler_characteristic/1` | 190-193 | `(Graph.t()) :: integer()` | V - E = beta_0 - beta_1 |
| `num_edges/1` | 218-221 | `(Graph.t()) :: non_neg_integer()` | Edge count |
| `num_vertices/1` | 243-246 | `(Graph.t()) :: non_neg_integer()` | Vertex count |
| `connected?/1` | 275-278 | `(Graph.t()) :: boolean()` | beta_0 == 1 |
| `tree?/1` | 308-311 | `(Graph.t()) :: boolean()` | Connected and acyclic |
| `forest?/1` | 341-344 | `(Graph.t()) :: boolean()` | Acyclic (possibly disconnected) |
| `invariants/1` | 376-397 | `(Graph.t()) :: map()` | All invariants in one call |

**Mathematical Relations**:
- beta_1 = |E| - |V| + beta_0
- euler_characteristic = |V| - |E| = beta_0 - beta_1

---

#### ExTopology.Filtration

**File**: `/home/home/p/g/North-Shore-AI/ex_topology/lib/ex_topology/filtration.ex`

Filtration construction for persistent homology.

| Function | Line | Signature | Description |
|----------|------|-----------|-------------|
| `vietoris_rips/2` | 65-80 | `(Nx.Tensor.t(), keyword()) :: filtration()` | VR filtration from points |
| `complex_at/2` | 104-113 | `(filtration(), scale()) :: map()` | Extract complex at epsilon |
| `critical_values/1` | 132-138 | `(filtration()) :: [scale()]` | Unique scale values |
| `from_graph/2` | 164-193 | `(Graph.t(), keyword()) :: filtration()` | Filtration from weighted graph |
| `validate/1` | 319-325 | `(filtration()) :: :ok | {:error, String.t()}` | Validate filtration ordering |

**Types**:
- `filtration :: [{scale :: float(), simplex :: [integer()]}]`
- `scale :: float()`

**Options**:
- `:max_dimension` - Maximum simplex dimension (default: 2)
- `:max_epsilon` - Maximum scale parameter
- `:metric` - Distance metric (default: `:euclidean`)

---

#### ExTopology.Persistence

**File**: `/home/home/p/g/North-Shore-AI/ex_topology/lib/ex_topology/persistence.ex`

Persistent homology computation via boundary matrix reduction.

| Function | Line | Signature | Description |
|----------|------|-----------|-------------|
| `compute/2` | 71-84 | `(filtration(), keyword()) :: [persistence_diagram()]` | Compute persistence diagrams |
| `betti_numbers/3` | 112-126 | `(filtration(), float(), keyword()) :: map()` | Betti numbers at scale |
| `matrix_rank/1` | 374-378 | `(map()) :: non_neg_integer()` | Rank of reduced matrix |
| `validate_boundary_property/2` | 395-431 | `(map(), filtration()) :: :ok | {:error, String.t()}` | Verify boundary^2 = 0 |

**Types**:
- `persistence_pair :: {birth :: float(), death :: float() | :infinity}`
- `persistence_diagram :: %{dimension: non_neg_integer(), pairs: [persistence_pair()]}`

**Algorithm**:
1. Build boundary matrix from filtration
2. Reduce using column operations (mod 2)
3. Extract persistence pairs from reduced matrix

---

### Layer 3: Analysis

#### ExTopology.Diagram

**File**: `/home/home/p/g/North-Shore-AI/ex_topology/lib/ex_topology/diagram.ex`

Persistence diagram analysis and comparison.

| Function | Line | Signature | Description |
|----------|------|-----------|-------------|
| `persistences/1` | 58-64 | `(diagram()) :: [float() | :infinity]` | List of persistence values |
| `total_persistence/1` | 87-93 | `(diagram()) :: float()` | Sum of finite persistences |
| `filter_by_persistence/2` | 116-141 | `(diagram(), keyword()) :: diagram()` | Filter by min/max persistence |
| `bottleneck_distance/3` | 174-182 | `(diagram(), diagram(), keyword()) :: float()` | Bottleneck distance |
| `wasserstein_distance/3` | 209-217 | `(diagram(), diagram(), keyword()) :: float()` | Wasserstein distance |
| `entropy/1` | 246-271 | `(diagram()) :: float()` | Persistence entropy |
| `summary_statistics/1` | 298-317 | `(diagram()) :: map()` | All statistics |
| `project_infinite/2` | 338-355 | `(diagram(), float()) :: diagram()` | Project infinity to finite |
| `to_persistence_birth_coords/1` | 377-382 | `(diagram()) :: [{float(), float()}]` | Convert for plotting |
| `persistence_landscape/3` | 471-490 | `(diagram(), [float()], keyword()) :: [float()]` | Landscape at level k |
| `same_dimension?/2` | 511-514 | `(diagram(), diagram()) :: boolean()` | Check dimension match |

**Summary Statistics Map**:
- `:count` - Total points
- `:finite_count` - Finite points
- `:infinite_count` - Infinite points
- `:total_persistence` - Sum of persistences
- `:max_persistence` - Maximum persistence
- `:mean_persistence` - Mean persistence
- `:entropy` - Persistence entropy

---

#### ExTopology.Fragility

**File**: `/home/home/p/g/North-Shore-AI/ex_topology/lib/ex_topology/fragility.ex`

Topological fragility and stability analysis.

| Function | Line | Signature | Description |
|----------|------|-----------|-------------|
| `point_removal_sensitivity/2` | 66-94 | `(Nx.Tensor.t(), keyword()) :: map()` | Per-point fragility scores |
| `edge_perturbation_sensitivity/2` | 119-151 | `(Graph.t(), keyword()) :: map()` | Per-edge fragility scores |
| `feature_stability_scores/2` | 182-206 | `(diagram(), keyword()) :: [float()]` | Persistence-based stability |
| `identify_critical_points/2` | 229-255 | `(map(), keyword()) :: [integer()]` | Find fragile points |
| `bottleneck_stability/2` | 280-305 | `(Nx.Tensor.t(), keyword()) :: float()` | Minimum perturbation threshold |
| `local_fragility/3` | 328-363 | `(Nx.Tensor.t(), integer(), keyword()) :: map()` | Analyze single point |
| `robustness_score/2` | 441-457 | `(Nx.Tensor.t(), keyword()) :: float()` | Overall robustness [0,1] |

**Fragility Score Interpretation**:
- Higher score = more fragile (removal causes topology change)
- Uses bottleneck distance to measure topology change

---

#### ExTopology.Embedding

**File**: `/home/home/p/g/North-Shore-AI/ex_topology/lib/ex_topology/embedding.ex`

Embedding quality metrics.

| Function | Line | Signature | Description |
|----------|------|-----------|-------------|
| `knn_variance/2` | 70-93 | `(Nx.Tensor.t(), keyword()) :: Nx.Tensor.t()` | k-NN distance variance |
| `knn_distances/2` | 118-128 | `(Nx.Tensor.t(), keyword()) :: Nx.Tensor.t()` | k-NN distances per point |
| `local_density/2` | 158-172 | `(Nx.Tensor.t(), keyword()) :: Nx.Tensor.t()` | Local density estimate |
| `isolation_scores/2` | 199-219 | `(Nx.Tensor.t(), keyword()) :: Nx.Tensor.t()` | Outlier detection (LOF-style) |
| `mean_knn_distance/2` | 244-256 | `(Nx.Tensor.t(), keyword()) :: Nx.Tensor.t()` | Mean k-NN distance |
| `statistics/2` | 281-302 | `(Nx.Tensor.t(), keyword()) :: map()` | Comprehensive statistics |
| `sparse_points/2` | 320-336 | `(Nx.Tensor.t(), keyword()) :: [integer()]` | Low-density point indices |

**Statistics Map**:
- `:n_points` - Number of points
- `:dimensions` - Dimensionality
- `:knn_variance` - Mean k-NN variance
- `:mean_knn_distance` - Mean k-NN distance
- `:density_mean` - Mean local density
- `:density_std` - Density standard deviation

---

#### ExTopology.Statistics

**File**: `/home/home/p/g/North-Shore-AI/ex_topology/lib/ex_topology/statistics.ex`

Statistical measures for topological analysis.

| Function | Line | Signature | Description |
|----------|------|-----------|-------------|
| `pearson/2` | 52-57 | `(Nx.Tensor.t(), Nx.Tensor.t()) :: Nx.Tensor.t()` | Pearson correlation |
| `spearman/2` | 107-116 | `(Nx.Tensor.t(), Nx.Tensor.t()) :: Nx.Tensor.t()` | Spearman rank correlation |
| `correlation/3` | 139-148 | `(Nx.Tensor.t(), Nx.Tensor.t(), keyword()) :: Nx.Tensor.t()` | Generic correlation |
| `correlation_matrix/1` | 168-186 | `(Nx.Tensor.t()) :: Nx.Tensor.t()` | Correlation matrix |
| `cohens_d/2` | 218-223 | `(Nx.Tensor.t(), Nx.Tensor.t()) :: Nx.Tensor.t()` | Cohen's d effect size |
| `coefficient_of_variation/2` | 265-277 | `(Nx.Tensor.t(), keyword()) :: Nx.Tensor.t()` | CV = std/mean |
| `z_scores/1` | 305-309 | `(Nx.Tensor.t()) :: Nx.Tensor.t()` | Standardized scores |
| `iqr/1` | 337-349 | `(Nx.Tensor.t()) :: Nx.Tensor.t()` | Interquartile range |
| `summary/1` | 369-389 | `(Nx.Tensor.t()) :: map()` | Descriptive statistics |

---

## Test Coverage

### Test Files

| File | Module | Key Tests |
|------|--------|-----------|
| `test/ex_topology_test.exs` | `ExTopology` | Version test, doctests |
| `test/ex_topology/graph_test.exs` | `ExTopology.Graph` | Betti numbers, invariants |
| `test/ex_topology/distance_test.exs` | `ExTopology.Distance` | Distance metrics |
| `test/ex_topology/neighborhood_test.exs` | `ExTopology.Neighborhood` | Graph construction |
| `test/ex_topology/simplex_test.exs` | `ExTopology.Simplex` | Simplex operations |
| `test/ex_topology/filtration_test.exs` | `ExTopology.Filtration` | VR filtration, validation |
| `test/ex_topology/persistence_test.exs` | `ExTopology.Persistence` | Homology computation |
| `test/ex_topology/diagram_test.exs` | `ExTopology.Diagram` | Diagram analysis |
| `test/ex_topology/fragility_test.exs` | `ExTopology.Fragility` | Stability analysis |
| `test/ex_topology/embedding_test.exs` | `ExTopology.Embedding` | Embedding metrics |
| `test/ex_topology/statistics_test.exs` | `ExTopology.Statistics` | Statistical functions |
| `test/property/distance_property_test.exs` | Property tests | Distance properties |
| `test/property/graph_property_test.exs` | Property tests | Graph properties |

### Test Commands

```bash
mix test                        # All tests
mix test --cover               # With coverage
mix test.property              # Property tests only
mix test.cross_validation      # Cross-validation tests
```

---

## Examples

Location: `/home/home/p/g/North-Shore-AI/ex_topology/examples/`

| Example | Description |
|---------|-------------|
| `quick_examples.exs` | Feature tour |
| `correlation_network.exs` | Build network from correlations |
| `group_comparision.exs` | Statistical comparison |
| `neighborhood_graphs.exs` | Compare graph constructions |
| `outlier_detection.exs` | Find anomalies |
| `spatial_connectivity.exs` | Multi-scale analysis |
| `persistence_basics.exs` | TDA workflow introduction |
| `simplicial_complexes.exs` | Simplex operations |
| `persistence_landscapes.exs` | Diagram analysis |
| `topological_fragility.exs` | Stability analysis |
| `clique_complexes.exs` | Graph-based TDA |

---

## Documentation

### ADRs (Architecture Decision Records)

Location: `/home/home/p/g/North-Shore-AI/ex_topology/docs/adrs/`

| ADR | Topic |
|-----|-------|
| ADR-0001 | Use libgraph for graph algorithms |
| ADR-0002 | Nx/Scholar for numerical computing |
| ADR-0003 | Minimal TDA, defer persistent homology (superseded) |
| ADR-0004 | Layered architecture |
| ADR-0005 | Sparse matrix representation |
| ADR-0006 | API design principles |
| ADR-0007 | NIF escape hatch (if needed) |
| ADR-0008 | Testing for correctness |
| ADR-0009 | Scope and versioning |

---

## Integration Points

### CNS Integration

From ADR-0009, ex_topology is designed to be used by CNS:

```elixir
# CNS becomes thin wrapper
defmodule CNS.Topology.Surrogates do
  defdelegate cyclomatic_number(graph), to: ExTopology.Graph, as: :beta_one
  defdelegate knn_variance(embeddings), to: ExTopology.Embedding
end
```

### Crucible Framework Integration

Currently, no `Crucible.Stage` implementation exists in ex_topology. The related stage `Crucible.Stage.Analysis.TDAValidation` exists in crucible_framework and uses an adapter pattern.

---

## Quality Tools

```bash
mix format           # Code formatting
mix credo --strict   # Code quality
mix dialyzer         # Static analysis
```

---

## Version History

| Version | Features |
|---------|----------|
| 0.1.0 | Graph topology, Distance, Neighborhood, Embedding, Statistics |
| 0.1.1 | Simplex, Filtration, Persistence, Diagram, Fragility (full TDA) |
