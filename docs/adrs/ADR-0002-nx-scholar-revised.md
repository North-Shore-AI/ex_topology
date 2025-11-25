# ADR-0002: Use Nx/Scholar for Numerical Foundations

## Status

Accepted (Revised)

*Adds explicit decision on coefficient field arithmetic*

## Context

ex_topology requires efficient numerical computation for:

- Distance matrix computation (Euclidean, Manhattan, Minkowski, cosine)
- k-Nearest Neighbor queries
- Statistical measures (variance, correlation)
- Linear algebra operations (matrix rank, reduction)

### Critical Issue: Coefficient Fields

Topological Data Analysis traditionally uses **mod-2 arithmetic** (coefficients in Z/2Z = {0, 1}). This matters for:

- Boundary matrix entries: ±1 mod 2 = 1
- Matrix reduction: additions are XOR operations
- Rank computation: must be exact, not numerical

**Nx provides floating-point tensors**, not exact integer arithmetic. This creates a fundamental tension.

### Options for Coefficient Handling

**Option A: Floating-Point Approximation**
- Use Nx as-is with f32/f64
- Compute rank via SVD, threshold singular values
- Risk: Numerical errors give wrong Betti numbers
- Suitable for: Small complexes, approximate answers

**Option B: Integer Tensors with Explicit Mod**
- Use Nx.s32 or Nx.u8 tensors
- Apply `Nx.remainder(x, 2)` after additions
- Exact mod-2 arithmetic
- Suitable for: Correct answers, moderate size

**Option C: Pure Elixir Z/2Z Implementation**
- Don't use Nx for boundary matrices
- Implement Gaussian elimination over Z/2Z directly
- Maximum control, no numerical issues
- Suitable for: Correctness-critical applications

**Option D: Defer to Phase 3+**
- Don't implement boundary matrix operations now
- Graph-based β₀, β₁ don't need this (see revised ADR-0003)
- Revisit when/if higher Betti numbers needed

## Decision

**Use Nx for distance/embedding computations. Defer coefficient field decision until boundary matrices are needed.**

### Rationale

Per revised ADR-0003, we're implementing:
- Phase 1: Graph topology (β₀, β₁) — no matrices needed
- Phase 2: Embedding metrics — floating-point is correct

Boundary matrix reduction (where Z/2Z matters) is deferred to Phase 3+.

### Current Scope: Floating-Point is Fine

```elixir
defmodule ExTopology.Foundation.Distance do
  import Nx.Defn

  @doc """
  Pairwise Euclidean distance matrix.
  
  Floating-point is mathematically correct here—distances are real numbers.
  """
  defn euclidean_matrix(points) do
    # points: {n, d} tensor
    diff = Nx.new_axis(points, 1) - Nx.new_axis(points, 0)
    Nx.sqrt(Nx.sum(diff * diff, axes: [-1]))
  end

  @doc """
  Pairwise cosine distance: 1 - cosine_similarity
  """
  defn cosine_matrix(points) do
    norms = Nx.sqrt(Nx.sum(points * points, axes: [1], keep_axes: true))
    normalized = points / norms
    similarity = Nx.dot(normalized, [1], normalized, [1])
    1.0 - similarity
  end
end

defmodule ExTopology.Foundation.Statistics do
  import Nx.Defn

  @doc """
  Variance of k-NN distances per point.
  Floating-point is correct—variance is a real number.
  """
  defn knn_variance(distances, k) do
    sorted = Nx.sort(distances, axis: 1)
    knn = sorted[[.., 1..k]]  # Exclude self (distance 0)
    Nx.variance(knn, axes: [1])
  end
end
```

### Future Scope: When Boundary Matrices Are Needed

If Phase 3 is implemented, use **Option B (Integer Tensors)**:

```elixir
defmodule ExTopology.Homology.BoundaryMatrix do
  @moduledoc """
  DEFERRED - Do not implement until needed.
  
  When implemented, use integer tensors with explicit mod-2:
  """

  import Nx.Defn

  # Boundary matrices have entries in {-1, 0, 1}
  # In Z/2Z: -1 ≡ 1, so entries are in {0, 1}
  
  defn reduce_column(matrix, col, pivot_row) do
    # Add pivot column to current column (mod 2)
    pivot_col = matrix[[.., pivot_row]]
    current_col = matrix[[.., col]]
    
    # XOR is addition in Z/2Z for {0,1} values
    new_col = Nx.bitwise_xor(
      Nx.as_type(current_col, :u8),
      Nx.as_type(pivot_col, :u8)
    )
    
    Nx.put_slice(matrix, [0, col], Nx.new_axis(new_col, 1))
  end

  defn matrix_rank_z2(matrix) do
    # Gaussian elimination over Z/2Z
    # Returns exact rank, not numerical approximation
    # ... implementation when needed
  end
end
```

### Explicit Non-Decision

We are **NOT** deciding on Z/2Z implementation now because:

1. Current requirements (β₀, β₁ for graphs) don't need it
2. The right choice depends on scale requirements we don't have yet
3. Premature optimization / architecture

When boundary matrices are needed, evaluate:
- Dataset sizes (determines if Nx overhead is worth it)
- Performance requirements (determines if NIFs needed)
- Correctness requirements (determines if approximation acceptable)

## Consequences

### Positive

1. **Nx for what it's good at**: Distances, statistics, embeddings
2. **No premature decisions**: Z/2Z choice deferred appropriately
3. **Hardware acceleration**: EXLA/GPU for distance matrices
4. **Correct by construction**: Float arithmetic is correct for current scope

### Negative

1. **Open question**: Z/2Z strategy unresolved
2. **Future work**: Will need to revisit for Phase 3

### Dependencies

```elixir
# mix.exs - Current
defp deps do
  [
    {:nx, "~> 0.7"},
    {:scholar, "~> 0.3"},
    # Optional backends
    {:exla, "~> 0.7", optional: true},
    {:torchx, "~> 0.7", optional: true}
  ]
end
```

## Appendix: Why SVD-Based Rank Fails for Z/2Z

```elixir
# WRONG approach for mod-2 rank:
def bad_rank_z2(matrix) do
  {_u, s, _vt} = Nx.LinAlg.svd(matrix)
  Nx.sum(Nx.greater(s, 1.0e-10))  # Counts non-zero singular values
end

# Problem: This gives rank over ℝ, not Z/2Z
# 
# Example: [[1, 1], [1, 1]]
# - Rank over ℝ: 1 (rows are identical)
# - Rank over Z/2Z: 1 (same, but for different reason)
#
# Example: [[1, 0, 1], [0, 1, 1], [1, 1, 0]]
# - Rank over ℝ: 2 (third row = first + second)
# - Rank over Z/2Z: 2 (third row = first XOR second)
# - SVD might give rank 3 due to numerical noise!
```

## References

- [Nx Documentation](https://hexdocs.pm/nx)
- [Scholar Documentation](https://hexdocs.pm/scholar)
- "Computing Persistent Homology" - Zomorodian & Carlsson
- Revised ADR-0003 (Minimal TDA scope)
