# ADR-0005: Sparse Matrix Strategy

## Status

Accepted

## Context

Topological computations often involve sparse structures:

- **Distance matrices**: Full n×n matrices are dense, but thresholded adjacency is sparse
- **Boundary matrices**: Simplicial complex boundary operators are very sparse
- **k-NN graphs**: Each vertex has exactly k neighbors (sparse)
- **Adjacency matrices**: Many graphs have O(n) or O(n log n) edges vs O(n²) possible

Memory and performance scale dramatically with sparsity handling:

| n (points) | Dense n×n | Sparse (k=10) | Savings |
|------------|-----------|---------------|---------|
| 1,000      | 8 MB      | 80 KB         | 100x    |
| 10,000     | 800 MB    | 800 KB        | 1000x   |
| 100,000    | 80 GB     | 8 MB          | 10000x  |

## Decision

**Use a dual-representation strategy: dense Nx tensors for small/medium data, sparse representations for large-scale.**

### Strategy

1. **Default to dense Nx tensors** for datasets < 5,000 points
2. **Provide sparse alternatives** via Map-based representations
3. **Let users choose** based on their scale and hardware

### Dense Path (Nx)

```elixir
defmodule ExTopology.Foundation.Distance do
  import Nx.Defn

  @doc "Dense pairwise distance matrix - O(n²) space"
  defn euclidean_matrix(points) do
    # points: {n, d}
    diff = Nx.new_axis(points, 1) - Nx.new_axis(points, 0)
    Nx.sqrt(Nx.sum(diff * diff, axes: [-1]))
  end
end
```

### Sparse Path (Map-based)

```elixir
defmodule ExTopology.Foundation.SparseDistance do
  @moduledoc """
  Sparse distance representations for large-scale computation.
  Only stores distances below threshold or k-nearest neighbors.
  """

  defstruct [:n, :entries]  # entries: %{{i, j} => distance}

  @doc "Build sparse distance map with only entries <= threshold"
  def from_points_threshold(points, threshold) do
    n = length(points)
    entries =
      for i <- 0..(n-2),
          j <- (i+1)..(n-1),
          d = distance(Enum.at(points, i), Enum.at(points, j)),
          d <= threshold,
          into: %{} do
        {{i, j}, d}
      end

    %__MODULE__{n: n, entries: entries}
  end

  @doc "Build sparse distance map with only k-nearest neighbors"
  def from_points_knn(points, k) do
    points
    |> Enum.with_index()
    |> Enum.flat_map(fn {p, i} ->
      points
      |> Enum.with_index()
      |> Enum.reject(fn {_, j} -> i == j end)
      |> Enum.map(fn {q, j} -> {j, distance(p, q)} end)
      |> Enum.sort_by(&elem(&1, 1))
      |> Enum.take(k)
      |> Enum.map(fn {j, d} -> {{min(i, j), max(i, j)}, d} end)
    end)
    |> Enum.uniq_by(&elem(&1, 0))
    |> Map.new()
    |> then(&%__MODULE__{n: length(points), entries: &1})
  end
end
```

### Boundary Matrix Representation

Boundary matrices are extremely sparse - use coordinate list format:

```elixir
defmodule ExTopology.Structure.BoundaryMatrix do
  @moduledoc """
  Sparse boundary matrix for homology computation.

  For a simplicial complex, the boundary matrix ∂_k maps
  k-simplices to (k-1)-simplices. Entries are ±1 or 0,
  with very few non-zeros per column.
  """

  defstruct [:rows, :cols, :entries]  # entries: [{row, col, value}]

  def from_complex(complex, dimension) do
    k_simplices = complex.simplices[dimension] |> MapSet.to_list()
    k_minus_1_simplices = complex.simplices[dimension - 1] |> MapSet.to_list()

    # Build index maps
    row_index = k_minus_1_simplices |> Enum.with_index() |> Map.new()
    col_index = k_simplices |> Enum.with_index() |> Map.new()

    entries =
      for {simplex, col} <- col_index,
          {face, sign} <- faces_with_signs(simplex),
          row = Map.get(row_index, face) do
        {row, col, sign}
      end

    %__MODULE__{
      rows: map_size(row_index),
      cols: map_size(col_index),
      entries: entries
    }
  end
end
```

## Consequences

### Positive

1. **Scalability**: Sparse path enables 100K+ point analysis
2. **Flexibility**: Users choose based on their needs
3. **Performance**: Dense path leverages Nx/EXLA acceleration
4. **Memory efficiency**: Sparse matrices use 100-10000x less memory

### Negative

1. **Code duplication**: Some algorithms need sparse and dense variants
2. **Complexity**: Users must understand when to use which path
3. **Interop overhead**: Converting between representations

### Mitigations

- Provide automatic selection based on data size
- Document clear guidelines for representation choice
- Use protocols/behaviours to unify APIs where possible

## Future: Native Sparse Tensor Support

Nx has preliminary sparse tensor support. When mature, we can:

```elixir
# Future Nx sparse API (not yet stable)
sparse_matrix = Nx.sparse_from_triplets(rows, cols, values, shape: {m, n})
```

Monitor Nx development and migrate when sparse support stabilizes.

## References

- [Nx Sparse RFC](https://github.com/elixir-nx/nx/issues/1234)
- GUDHI sparse matrix handling
- SciPy sparse matrix documentation
