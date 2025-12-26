# Changelog

All notable changes to ExTopology will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2025-12-25

### Added

- **Crucible Stage Integration**
  - `ExTopology.Stage` - Crucible.Stage implementation for TDA metrics in experiment pipelines
  - Computes Betti numbers, persistence diagrams, fragility scores, and embedding metrics
  - Configurable options: `:data_key`, `:compute`, `:k`, `:max_dimension`
  - Results stored in `ctx.metrics[:tda]` with detailed data in assigns

- **Documentation**
  - Crucible Integration section in README with usage examples
  - Implementation documentation in `docs/20251225/`
  - Gap analysis and current state documentation

- **New Logo**
  - Updated `assets/ex_topology.svg` with TDA-themed design featuring persistence diagrams and Betti numbers

### Changed

- **Code Quality Improvements (Credo compliance)**
  - Renamed `is_face?/2` to `face?/2` in `ExTopology.Simplex`
  - Renamed `is_clique?/1` to `clique?/1` (internal function)
  - Refactored `entropy/1` in `ExTopology.Diagram` to reduce nesting
  - Refactored `feature_stability_scores/2` in `ExTopology.Fragility`
  - Refactored `compute_betti_number/2` in `ExTopology.Persistence`
  - Simplified `validate/1` in `ExTopology.Filtration` (removed redundant `with` clause)
  - Fixed alias ordering in multiple modules

### Fixed

- Proper handling of edge cases in persistence computations
- Improved tensor validation in Stage module

---

## [0.1.1] - 2025-11-24

### Added

- **Persistent Homology** - Full TDA pipeline
  - `ExTopology.Simplex` - Simplicial complex operations, face enumeration, boundary operator
  - `ExTopology.Filtration` - Vietoris-Rips filtration construction
  - `ExTopology.Persistence` - Persistent homology computation via matrix reduction
  - `ExTopology.Diagram` - Persistence diagram analysis, bottleneck/Wasserstein distances
  - `ExTopology.Fragility` - Topological stability and sensitivity analysis

- **New Features**
  - Clique complex construction from graphs
  - Persistence landscapes
  - Point removal sensitivity analysis
  - Edge perturbation sensitivity
  - Feature stability scoring
  - Critical point identification
  - Robustness scoring

- **Testing**
  - 171 new tests for persistent homology modules
  - Property-based tests for mathematical invariants (∂∂ = 0, birth ≤ death)
  - Total: 371 tests (101 doctests, 22 properties, 248 unit tests)

- **Examples**
  - `persistence_basics.exs` - Persistent homology workflow introduction
  - `simplicial_complexes.exs` - Simplex operations, faces, boundary operator ∂
  - `persistence_landscapes.exs` - Diagram analysis, distances, landscapes
  - `topological_fragility.exs` - Point removal sensitivity, stability analysis
  - `clique_complexes.exs` - Graph-based TDA, weighted filtrations

- **Documentation**
  - Comprehensive README with full API reference
  - Usage examples for all modules
  - Common workflow patterns
  - Expanded examples/README.md with all 11 examples

### Fixed

- `Diagram.entropy/1` now handles zero persistence values (birth == death)

### Changed

- Updated module documentation groupings in ExDoc
- README restructured with features table and detailed module reference

## [0.1.0] - 2025-11-24

### Added

- **Core Modules**
  - `ExTopology.Distance` - Pairwise distance matrices (Euclidean, Manhattan, cosine, Chebyshev, Minkowski)
  - `ExTopology.Neighborhood` - Graph construction (k-NN, ε-ball, Gabriel, RNG)
  - `ExTopology.Graph` - Topological invariants (β₀, β₁, Euler characteristic)
  - `ExTopology.Embedding` - Embedding quality metrics (k-NN variance, density, isolation scores)
  - `ExTopology.Statistics` - Statistical analysis (Pearson/Spearman correlation, Cohen's d, z-scores, IQR)

- **Examples**
  - `quick_examples.exs` - Comprehensive feature tour
  - `correlation_network.exs` - Build networks from correlations
  - `group_comparision.exs` - Statistical group comparison
  - `neighborhood_graphs.exs` - Compare graph constructions
  - `outlier_detection.exs` - Find anomalies in embeddings
  - `spatial_connectivity.exs` - Multi-scale spatial analysis

- **Testing**
  - 200 tests (49 doctests, 22 properties, 129 unit tests)
  - Property-based tests for Euler characteristic invariant
  - Property-based tests for distance matrix properties

- **Documentation**
  - Architecture Decision Records (ADRs) in `docs/adrs/`
  - Examples README with detailed descriptions

### Dependencies

- `libgraph ~> 0.16` - Graph algorithms
- `nx ~> 0.7` - Numerical computing
- `scholar ~> 0.3` - Machine learning utilities
- `stream_data ~> 1.0` - Property-based testing
