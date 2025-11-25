# ADR-0002: Use Nx/Scholar for Numerical Foundations

## Status

Accepted

## Context

ex_topology requires efficient numerical computation for:

- Distance matrix computation (Euclidean, Manhattan, Minkowski, cosine)
- k-Nearest Neighbor queries
- Statistical measures (variance, correlation, covariance)
- Linear algebra operations (eigenvalues for spectral methods)
- Matrix operations (sparse representations, slicing)

The Elixir ecosystem offers several options:

### Option A: Nx + Scholar
- **Nx**: Numerical Elixir, tensor-based computation
- **Scholar**: Traditional ML algorithms built on Nx
- **Backends**: EXLA (XLA/GPU), Torchx (LibTorch), BinaryBackend (pure Elixir)
- **Maturity**: 3+ years, production-ready, Dashbit-maintained

### Option B: Pure Elixir with :math
- No dependencies
- Portable
- Very slow for large datasets
- No vectorization

### Option C: Rustler NIFs
- Maximum performance
- Complex build process
- Maintenance burden
- Breaks OTP fault isolation

## Decision

**Use Nx as the numerical foundation with Scholar for statistical algorithms.**

Nx provides the tensor abstraction we need, with optional GPU acceleration. Scholar adds k-NN, distance metrics, and statistics:

```elixir
defmodule ExTopology.Distance do
  import Nx.Defn

  @doc """
  Compute pairwise Euclidean distance matrix.
  GPU-accelerated when EXLA backend is configured.
  """
  defn euclidean_matrix(points) do
    # points: {n, d} tensor
    # result: {n, n} distance matrix
    diff = Nx.new_axis(points, 1) - Nx.new_axis(points, 0)
    Nx.sqrt(Nx.sum(diff * diff, axes: [-1]))
  end
end

defmodule ExTopology.Neighbors do
  alias Scholar.Neighbors.KNearestNeighbors

  def build_knn(points, k) do
    model = KNearestNeighbors.fit(points, num_neighbors: k)
    {indices, distances} = KNearestNeighbors.predict(model, points)
    {indices, distances}
  end
end
```

## Consequences

### Positive

1. **Hardware acceleration**: EXLA enables GPU computation for large point clouds
2. **Proven algorithms**: Scholar's k-NN is numerically stable and tested
3. **Ecosystem alignment**: Nx is the standard for numerical Elixir
4. **Defn compilation**: JIT compilation for hot paths
5. **Backend flexibility**: Can swap backends without code changes

### Negative

1. **Learning curve**: Nx's functional tensor API differs from NumPy
2. **Compilation time**: EXLA has noticeable startup overhead
3. **Backend complexity**: Different backends have different capabilities

### Mitigations

- Provide BinaryBackend fallback for simple cases
- Cache compiled functions where possible
- Document backend selection guidance

## Nx Dependencies

```elixir
# mix.exs
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

## References

- [Nx GitHub](https://github.com/elixir-nx/nx)
- [Scholar GitHub](https://github.com/elixir-nx/scholar)
- [Nx Guides](https://hexdocs.pm/nx/intro-to-nx.html)
- CNS.Topology.Surrogates - Current kNN variance implementation to migrate
