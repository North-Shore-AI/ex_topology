# Architecture Decision Records for ex_topology

## Index

| ADR | Title | Status |
|-----|-------|--------|
| [0001](ADR-0001-use-libgraph.md) | Use libgraph for Graph Algorithms | Accepted (unchanged) |
| [0002](ADR-0002-nx-scholar-revised.md) | Use Nx/Scholar for Numerical Foundations | **Revised** |
| [0003](ADR-0003-minimal-tda-defer-persistent-homology.md) | Minimal TDA, Defer Persistent Homology | **Revised** (supersedes original) |
| [0004](ADR-0004-layered-architecture-revised.md) | Layered Architecture Design | **Revised** |
| [0005](ADR-0005-sparse-matrix-revised.md) | Sparse Matrix Strategy | **Revised** |
| [0006](ADR-0006-api-design.md) | API Design Principles | Accepted (unchanged) |
| [0007](ADR-0007-nif-escape-hatch.md) | NIF Escape Hatch Strategy | **New** |
| [0008](ADR-0008-testing-correctness.md) | Testing and Correctness Validation | **New** |
| [0009](ADR-0009-scope-versioning.md) | Scope Definition and Versioning | **New** |

## Summary of Key Decisions

### What ex_topology IS (v1.0)

- Graph topology: β₀, β₁, Euler characteristic
- Neighborhood graphs: k-NN, ε-ball construction
- Distance matrices: Euclidean, cosine, etc.
- Embedding metrics: k-NN variance, local density
- **Generic, domain-agnostic primitives**

### What ex_topology is NOT

- Full TDA library (no persistent homology in v1.0)
- Domain-specific adapters (CNS stays in CNS)
- Visualization (use VegaLite)
- Research-grade algorithms (unless concrete need)

### Architecture Summary

```
Domain Layer (NOT in ex_topology)
├── CNS (Fragility, SNO, Chirality)
├── CodeAnalysis (TechDebt, Coupling)
└── ... other domains

ex_topology (GENERIC)
├── Layer 2: Algorithms (Graph, Embedding, Statistics)
└── Layer 1: Structures (Neighborhood, Distance)

Foundation (External)
├── libgraph
├── Nx / Scholar
└── Erlang stdlib
```

### Versioning

- **v0.1.0**: Graph topology (β₀, β₁, neighborhoods) - Target: 2 weeks
- **v0.2.0**: Embedding metrics - Target: +2 weeks  
- **v1.0.0**: Stable release - Target: Q4 2025
- **v2.0.0**: Extended TDA - Not scheduled

## Revision History

### Key Changes from Original ADRs

**ADR-0003**: Changed from "Build TDA from Scratch" to "Minimal TDA, Defer Persistent Homology"
- Original scope was overambitious
- CNS doesn't need full TDA
- Persistent homology is hard to implement correctly
  
**ADR-0002**: Added explicit decision on Z/2Z coefficient arithmetic
- Original glossed over fundamental numerical issue
- SVD-based rank fails for mod-2 arithmetic
- Decision deferred until boundary matrices needed

**ADR-0004**: Removed Fragility from generic layers
- Fragility is CNS-specific, not generic topology
- Domain interpretation stays in domain packages

**ADR-0005**: Committed to CSC format, removed naive COO proposal
- Map-of-tuples is wrong for matrix operations
- CSC format chosen for boundary matrices (when needed)
- Implementation deferred

### New ADRs Added

**ADR-0007**: NIF Escape Hatch Strategy
- Defines when NIFs are justified
- Phase 1-2 never needs NIFs
- Ripser wrapper if persistent homology built

**ADR-0008**: Testing and Correctness Validation
- Property-based tests for mathematical invariants
- Cross-validation against NetworkX
- Three-tier testing strategy

**ADR-0009**: Scope Definition and Versioning
- Explicit v0.1/v0.2/v1.0/v2.0 boundaries
- Clear timeline (v1.0 by Q4 2025)
- Migration path for CNS

## The Core Reframe

The original ADRs read like "we're going to build a comprehensive topology library."

The revised versions say:

**v0.1-v1.0 (now through Q4 2025):**
- β₀, β₁ via libgraph (trivial)
- k-NN variance via Scholar (already exists)
- Distance matrices via Nx (already exists)
- ~80% composition, ~20% new code

**v2.0+ (not scheduled):**
- Simplicial complexes, boundary matrices, persistent homology
- Only if concrete research need emerges
- Likely via NIF wrapper around Ripser, not pure Elixir

**The honest assessment**: CNS needs are covered by about 50 lines of new code wrapping existing libraries. Building full TDA would be a multi-month research project with unclear ROI.
