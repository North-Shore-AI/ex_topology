# ExTopology - Gap Analysis

**Date**: 2025-12-25
**Version**: 0.1.1

## Executive Summary

ExTopology provides a comprehensive TDA implementation with persistence diagrams, filtrations, and fragility metrics. However, it lacks integration with the Crucible framework's Stage behaviour, limiting its use in ML experiment pipelines. This document identifies gaps and areas for improvement.

---

## Critical Gaps

### 1. No Crucible.Stage Implementation

**Severity**: High
**Impact**: Cannot use ExTopology directly in Crucible experiment pipelines

**Current State**:
- ExTopology has no dependency on crucible_framework or crucible_ir
- No `ExTopology.Stage` module exists
- The `Crucible.Stage.Analysis.TDAValidation` in crucible_framework uses a TDA adapter pattern but requires external implementation

**Required**:
- Implement `ExTopology.Stage` module that implements `Crucible.Stage` behaviour
- Stage should:
  - Extract point cloud data from context (e.g., embeddings)
  - Compute TDA metrics (persistence, fragility, Betti numbers)
  - Merge results into context metrics

**Reference**:
- `Crucible.Stage` behaviour: `/home/home/p/g/North-Shore-AI/crucible_framework/lib/crucible/stage.ex`
- Example stage: `/home/home/p/g/North-Shore-AI/crucible_framework/lib/crucible/stage/analysis/tda_validation.ex`

---

### 2. Missing TDA Adapter Implementation

**Severity**: High
**Impact**: crucible_framework's TDAValidation stage uses a noop adapter

**Current State**:
- `Crucible.Analysis.TDANoop` exists in crucible_framework as default
- No `Crucible.Analysis.TDAAdapter` implementation uses ExTopology

**Required**:
- Implement adapter that bridges crucible_framework to ExTopology
- Could be in ex_topology as optional dependency or in crucible_framework

---

## Moderate Gaps

### 3. Version Mismatch

**Severity**: Low
**Impact**: Cosmetic inconsistency

**Current State**:
- `mix.exs` line 4: `@version "0.1.1"`
- `lib/ex_topology.ex` line 57: `def version, do: "0.1.0"`

**Required**:
- Update `lib/ex_topology.ex` to return "0.1.1"

---

### 4. Missing Doctest Coverage

**Severity**: Low
**Impact**: Documentation examples not verified

**Current State**:
- Main modules have doctests
- Some complex functions lack doctests (e.g., `Persistence.compute/2`)

**Required**:
- Add doctests to key persistence functions

---

### 5. Limited Distance Metrics

**Severity**: Low
**Impact**: Users may need additional metrics

**Current State**:
- Euclidean, Cosine, Manhattan, Chebyshev, Minkowski

**Could Add**:
- Jaccard distance (for binary data)
- Hamming distance (for categorical)
- Mahalanobis distance (for covariance-aware)

---

### 6. No Streaming/Lazy Support

**Severity**: Low
**Impact**: Memory issues with very large datasets

**Current State**:
- All computations are eager
- Full distance matrices loaded in memory

**Could Add**:
- Streaming k-NN using approximate algorithms
- Lazy filtration construction

---

## Minor Gaps

### 7. Missing Visualization Support

**Severity**: Very Low
**Impact**: Users need external tools for plotting

**Current State**:
- No visualization functions
- ADR-0009 explicitly marks this as out of scope

**Note**: Per ADR, use VegaLite or D3 externally

---

### 8. No Alpha Complex

**Severity**: Low
**Impact**: VR complex may be less efficient for some point clouds

**Current State**:
- Only Vietoris-Rips filtration implemented
- Alpha complex deferred to future version

**Could Add**:
- Delaunay-based alpha complex (requires computational geometry)

---

### 9. Bottleneck/Wasserstein Approximation

**Severity**: Low
**Impact**: Distance calculations use greedy matching

**Current State**:
- `Diagram.bottleneck_distance/3` uses greedy matching (line 177-182)
- `Diagram.wasserstein_distance/3` uses greedy matching (line 210-217)
- Not optimal (Hungarian algorithm would be better)

**Note**: Comments acknowledge this limitation

---

### 10. No Persistence Barcodes

**Severity**: Very Low
**Impact**: Alternative representation not available

**Current State**:
- Diagrams as `%{dimension: d, pairs: [{birth, death}, ...]}`
- No barcode representation

**Could Add**:
- `Diagram.to_barcode/1` - convert to barcode format

---

## Test Gaps

### 11. Property Test Coverage

**Severity**: Low
**Impact**: Some edge cases may not be tested

**Current State**:
- Property tests for Distance and Graph
- Missing property tests for Persistence, Diagram, Fragility

**Required**:
- Add property tests verifying:
  - birth <= death for all pairs
  - Total Betti numbers match at critical values
  - Distances are symmetric and non-negative

---

### 12. Cross-Validation Tests

**Severity**: Low
**Impact**: No comparison with reference implementations

**Current State**:
- Alias defined: `mix test.cross_validation`
- May not have actual cross-validation tests

**Could Add**:
- Compare results with Python ripser/giotto-tda
- Verify Betti numbers match NetworkX for graph examples

---

## Documentation Gaps

### 13. API Changelog

**Severity**: Low
**Impact**: Users unsure what changed between versions

**Current State**:
- CHANGELOG.md exists but may not be complete
- No @since annotations on functions

**Could Add**:
- @since tags on new functions
- Complete CHANGELOG entries

---

### 14. Performance Documentation

**Severity**: Low
**Impact**: Users unsure about scalability

**Current State**:
- Distance.ex mentions scale guidelines (lines 26-33)
- No benchmark results published

**Could Add**:
- Benchmark results in docs
- Memory usage guidelines

---

## Dependency Gaps

### 15. Optional EXLA/TorchX Support

**Severity**: Low
**Impact**: No GPU acceleration

**Current State**:
- EXLA and TorchX commented out in mix.exs (lines 56-58)
- Documentation mentions "Consider EXLA backend"

**Could Add**:
- Document how to enable GPU backends
- Test with EXLA backend

---

## Summary Priority Matrix

| Gap | Priority | Effort | Impact |
|-----|----------|--------|--------|
| 1. Crucible.Stage implementation | Critical | Medium | High |
| 2. TDA Adapter | Critical | Low | High |
| 3. Version mismatch | Low | Trivial | Low |
| 4. Doctest coverage | Low | Low | Medium |
| 5. Distance metrics | Low | Medium | Low |
| 6. Streaming support | Low | High | Medium |
| 7. Visualization | Very Low | N/A | Out of scope |
| 8. Alpha complex | Low | High | Low |
| 9. Optimal matching | Low | Medium | Low |
| 10. Barcodes | Very Low | Low | Low |
| 11. Property tests | Low | Medium | Medium |
| 12. Cross-validation | Low | Medium | Medium |
| 13. Changelog | Low | Low | Low |
| 14. Performance docs | Low | Medium | Medium |
| 15. GPU support | Low | Low | Low |

---

## Recommended Action Items

### Immediate (This Sprint)

1. **Implement `ExTopology.Stage`** - Critical for Crucible integration
2. **Fix version mismatch** - Trivial fix
3. **Add basic property tests for Persistence** - Improve confidence

### Near-Term (Next Release)

4. **Implement TDA Adapter** in crucible_framework using ExTopology
5. **Add cross-validation tests** against Python reference
6. **Complete CHANGELOG.md**

### Future (v0.2.x)

7. Consider additional distance metrics
8. Consider alpha complex implementation
9. Document performance characteristics
