# Architecture Decision Records

This directory contains Architecture Decision Records (ADRs) for ex_topology.

## Index

| ADR | Title | Status |
|-----|-------|--------|
| [0001](0001-use-libgraph-for-graph-algorithms.md) | Use libgraph for Graph Algorithms | Accepted |
| [0002](0002-use-nx-scholar-for-numerical-foundations.md) | Use Nx/Scholar for Numerical Foundations | Accepted |
| [0003](0003-build-tda-from-scratch.md) | Build TDA from Scratch | Accepted |
| [0004](0004-layered-architecture.md) | Layered Architecture Design | Accepted |
| [0005](0005-sparse-matrix-strategy.md) | Sparse Matrix Strategy | Accepted |
| [0006](0006-api-design-principles.md) | API Design Principles | Accepted |

## About ADRs

Architecture Decision Records capture important architectural decisions along with their context and consequences. Each ADR describes a single decision and follows this template:

- **Status**: Proposed, Accepted, Deprecated, Superseded
- **Context**: What forces led to this decision?
- **Decision**: What is the change being made?
- **Consequences**: What are the positive and negative effects?

## Adding New ADRs

1. Copy the template below
2. Number sequentially (0007, 0008, etc.)
3. Use lowercase-with-dashes naming: `0007-decision-title.md`
4. Update the index above

## Template

```markdown
# ADR-NNNN: Title

## Status

Proposed | Accepted | Deprecated | Superseded by [ADR-XXXX](link)

## Context

What is the issue that we're seeing that is motivating this decision?

## Decision

What is the change that we're proposing and/or doing?

## Consequences

What becomes easier or more difficult to do because of this change?
```

## References

- [ADR GitHub Organization](https://adr.github.io/)
- Michael Nygard's original [blog post](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
