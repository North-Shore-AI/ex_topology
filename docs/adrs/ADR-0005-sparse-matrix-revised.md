# ADR-0005: Sparse Matrix Strategy

## Status

Accepted (Revised)

*Clarifies scope and defers sparse boundary matrices*

## Context

The original ADR proposed a dual dense/sparse strategy with Map-based sparse representations. This was problematic:

### Problems with Original Proposal

1. **Map-of-tuples is wrong for matrix operations**
   ```elixir
   # Original proposal
   defstruct [:n, :entries]  # entries: %{{i, j} => distance}
   ```
   
   This is COO (Coordinate) format. It's fine for construction but terrible for:
   - Column iteration (needed for boundary matrix reduction)
   - Matrix-vector multiplication
   - Row/column slicing

2. **No commitment to specific format**
   
   Different algorithms need different sparse formats:
   - CSC (Compressed Sparse Column): Good for column operations
   - CSR (Compressed Sparse Row): Good for row operations  
   - COO: Good for construction, bad for computation

3. **Premature optimization**
   
   Per revised ADR-0003, we're not implementing boundary matrix operations yet. Sparse matrix design is YAGNI.

### What Actually Needs Sparsity?

| Data Structure | Dense Size | Sparse? | Current Need |
|----------------|------------|---------|--------------|
| Distance matrix | O(n²) | Usually dense | Yes (Phase 2) |
| k-NN graph | O(nk) | Inherently sparse | Yes (Phase 1) |
| Adjacency matrix | O(n²) | Often sparse | Via libgraph |
| Boundary matrix | O(n²) | Very sparse | No (Phase 3+) |

**Key insight**: libgraph already handles sparse graph representation efficiently. We don't need our own sparse adjacency matrices.

## Decision

**Use libgraph for sparse graph structures. Use dense Nx tensors for distance matrices. Defer sparse boundary matrices.**

### What We Implement Now

#### Sparse Graphs: Use libgraph

```elixir
defmodule ExTopology.Graph.Neighborhood do
  @moduledoc """
  Construct neighborhood graphs from point clouds.
  Uses libgraph for sparse representation.
  """

  @doc """
  k-NN graph: connect each point to k nearest neighbors.
  
  Returns libgraph Graph (sparse by nature).
  Memory: O(nk) edges, not O(n²).
  """
  def knn_graph(points, k) when is_list(points) do
    n = length(points)
    distances = compute_distances(points)
    
    Graph.new(type: :undirected)
    |> Graph.add_vertices(0..(n-1))
    |> add_knn_edges(distances, k)
  end

  defp add_knn_edges(graph, distances, k) do
    n = tuple_size(distances)
    
    Enum.reduce(0..(n-1), graph, fn i, g ->
      neighbors = 
        0..(n-1)
        |> Enum.reject(&(&1 == i))
        |> Enum.sort_by(&elem(elem(distances, i), &1))
        |> Enum.take(k)
      
      Enum.reduce(neighbors, g, fn j, g2 ->
        Graph.add_edge(g2, i, j)
      end)
    end)
  end

  @doc """
  ε-ball graph: connect points within distance ε.
  
  Sparse when ε is small relative to data spread.
  """
  def epsilon_graph(points, epsilon) do
    n = length(points)
    distances = compute_distances(points)
    
    edges = 
      for i <- 0..(n-2),
          j <- (i+1)..(n-1),
          elem(elem(distances, i), j) <= epsilon do
        {i, j}
      end
    
    Graph.new(type: :undirected)
    |> Graph.add_vertices(0..(n-1))
    |> Graph.add_edges(edges)
  end
end
```

#### Dense Distance Matrices: Use Nx

```elixir
defmodule ExTopology.Foundation.Distance do
  import Nx.Defn

  @doc """
  Full pairwise distance matrix.
  
  Dense O(n²) representation. For n > 10,000 points,
  consider computing distances on-demand or using 
  approximate methods.
  """
  defn euclidean_matrix(points) do
    diff = Nx.new_axis(points, 1) - Nx.new_axis(points, 0)
    Nx.sqrt(Nx.sum(diff * diff, axes: [-1]))
  end

  @doc """
  Thresholded distance matrix (sparse-ish via masking).
  
  Returns full matrix but with Inf for distances > threshold.
  Not true sparse, but reduces downstream computation.
  """
  defn thresholded_distances(points, threshold) do
    dists = euclidean_matrix(points)
    Nx.select(Nx.less_equal(dists, threshold), dists, Nx.Constants.infinity())
  end
end
```

### What We Explicitly Defer

#### Sparse Boundary Matrices

When (if) Phase 3 requires boundary matrix reduction:

```elixir
defmodule ExTopology.Homology.SparseBoundary do
  @moduledoc """
  DEFERRED - Do not implement until Phase 3.
  
  When implemented, use CSC (Compressed Sparse Column) format
  because boundary matrix reduction processes columns left-to-right.
  """

  # CSC format:
  # - values: non-zero entries, column by column
  # - row_indices: row index for each value
  # - col_pointers: index into values where each column starts
  
  defstruct [:rows, :cols, :values, :row_indices, :col_pointers]

  @doc """
  CSC is optimal for the standard persistence algorithm:
  
  for j = 0 to num_cols - 1:
    while col[j] has entries and pivot exists:
      add pivot column to col[j]  # Need fast column access
  
  COO would require scanning entire matrix for each column.
  CSC gives O(nnz_in_column) access.
  """
end
```

### Scale Guidelines

| Point Count | Distance Matrix | Recommendation |
|-------------|-----------------|----------------|
| < 1,000 | 8 MB | Dense Nx, no concerns |
| 1,000-5,000 | 200 MB | Dense Nx, watch memory |
| 5,000-10,000 | 800 MB | Dense Nx with EXLA |
| > 10,000 | > 800 MB | Don't compute full matrix |

For > 10,000 points, use:
- k-NN graph (sparse) instead of full distance matrix
- Approximate nearest neighbors (HNSWLib)
- Sampling/landmarks approaches

## Consequences

### Positive

1. **No premature abstraction**: Don't build sparse matrices we won't use
2. **Leverage libgraph**: Already handles sparse graphs well
3. **Clear guidance**: Users know when dense is okay
4. **Deferred complexity**: CSC format chosen but not implemented

### Negative

1. **Scale ceiling**: Dense matrices limit point count
2. **Future work**: Must implement CSC if Phase 3 happens

### Explicit Non-Decisions

- **Sparse tensor format**: Wait for Nx sparse support to mature
- **CSC vs CSR**: Decided (CSC) but not implemented
- **Approximate algorithms**: Out of scope for ex_topology core

## Appendix: Why COO is Wrong for Persistence

```elixir
# The persistence algorithm (simplified):
def reduce(boundary_matrix) do
  for col_j <- 0..(num_cols - 1) do
    while has_pivot?(col_j) and pivot_exists_for_row?(low(col_j)) do
      pivot_col = get_pivot_column(low(col_j))
      add_columns_mod2(col_j, pivot_col)  # <-- This needs fast column access
    end
  end
end

# With COO (Map of {row, col} => value):
# add_columns_mod2 requires:
# 1. Find all entries where col == pivot_col  -> O(nnz) scan
# 2. Find all entries where col == col_j      -> O(nnz) scan
# 3. Merge and XOR                            -> O(col_nnz)
# Total: O(nnz) per column operation = O(nnz * num_cols) overall

# With CSC:
# add_columns_mod2 requires:
# 1. Access col_pointers[pivot_col] and col_pointers[col_j] -> O(1)
# 2. Iterate entries in those columns                        -> O(col_nnz)
# Total: O(col_nnz) per operation = O(nnz) overall

# For a complex with 10k simplices and 1% density:
# COO: ~1 billion operations
# CSC: ~100k operations
# That's 10,000x difference.
```

## References

- libgraph internals (Map-based adjacency, efficient for sparse graphs)
- "Sparse Matrix Representations" - Davis, Rajamanickam, Sid-Lakhdar
- Ripser paper (implicit matrix representation)
- Revised ADR-0003 (Phase definitions)
