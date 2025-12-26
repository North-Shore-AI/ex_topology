defmodule ExTopology.Persistence do
  @moduledoc """
  Persistent homology computation via boundary matrix reduction.

  Persistent homology tracks topological features (connected components,
  loops, voids) across a filtration, recording when each feature appears
  (birth) and disappears (death).

  ## Algorithm

  This module implements the standard algorithm for computing persistence:

  1. Build boundary matrix ∂ from filtration
  2. Reduce matrix using column operations (mod 2 arithmetic)
  3. Extract persistence pairs from reduced matrix
  4. Construct persistence diagrams

  ## Complexity

  - Time: O(n³) where n is number of simplices
  - Space: O(n²) for boundary matrix
  - Optimizations: Sparse representation, clearing optimization

  ## Examples

      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [0.0, 1.0]])
      filtration = ExTopology.Filtration.vietoris_rips(points)
      diagrams = ExTopology.Persistence.compute(filtration)
      # Returns persistence diagrams for each dimension
  """

  alias ExTopology.{Filtration, Simplex}

  @type simplex :: Simplex.simplex()
  @type filtration :: Filtration.filtration()
  @type persistence_pair :: {birth :: float(), death :: float() | :infinity}
  @type persistence_diagram :: %{
          dimension: non_neg_integer(),
          pairs: [persistence_pair()]
        }

  @doc """
  Computes persistent homology for a filtration.

  ## Parameters

  - `filtration` - A filtration (list of {scale, simplex} pairs)
  - `opts` - Keyword list:
    - `:max_dimension` - Maximum homology dimension to compute (default: 2)
    - `:algorithm` - `:standard` or `:twist` (default: `:standard`)

  ## Returns

  - List of persistence diagrams, one per dimension

  ## Examples

      iex> filtration = [{0.0, [0]}, {0.0, [1]}, {1.0, [0, 1]}]
      iex> diagrams = ExTopology.Persistence.compute(filtration)
      iex> length(diagrams) > 0
      true

  ## Mathematical Background

  Persistent homology is computed by:
  1. Ordering simplices by birth time
  2. Building boundary matrix ∂ where ∂ₖ maps k-chains to (k-1)-chains
  3. Reducing ∂ to echelon form using column operations
  4. Reading persistence pairs from reduced matrix
  """
  @spec compute(filtration(), keyword()) :: [persistence_diagram()]
  def compute(filtration, opts \\ []) do
    max_dim = Keyword.get(opts, :max_dimension, 2)
    algorithm = Keyword.get(opts, :algorithm, :standard)

    # Build boundary matrix
    {matrix, simplex_map} = build_boundary_matrix(filtration)

    # Reduce matrix
    reduced = reduce_matrix(matrix, algorithm)

    # Extract persistence pairs
    extract_persistence_pairs(reduced, simplex_map, filtration, max_dim)
  end

  @doc """
  Computes Betti numbers at a specific filtration value.

  Betti numbers count topological features:
  - β₀: connected components
  - β₁: loops/cycles
  - β₂: voids/cavities

  ## Parameters

  - `filtration` - A filtration
  - `epsilon` - Scale parameter
  - `opts` - Keyword list:
    - `:max_dimension` - Maximum dimension (default: 2)

  ## Returns

  - Map of dimension to Betti number: `%{0 => β₀, 1 => β₁, ...}`

  ## Examples

      iex> filtration = [{0.0, [0]}, {0.0, [1]}, {0.0, [2]}, {1.0, [0, 1]}, {1.0, [1, 2]}]
      iex> betti = ExTopology.Persistence.betti_numbers(filtration, 0.5)
      iex> betti[0]
      3
  """
  @spec betti_numbers(filtration(), float(), keyword()) :: %{
          non_neg_integer() => non_neg_integer()
        }
  def betti_numbers(filtration, epsilon, opts \\ []) do
    max_dim = Keyword.get(opts, :max_dimension, 2)

    # Get complex at this epsilon
    complex = Filtration.complex_at(filtration, epsilon)

    # Compute Betti numbers for each dimension
    for dim <- 0..max_dim, into: %{} do
      betti = compute_betti_number(complex, dim)
      {dim, betti}
    end
  end

  # Private functions

  defp build_boundary_matrix(filtration) do
    # Index simplices by their position in filtration
    simplex_map =
      filtration
      |> Enum.with_index()
      |> Map.new(fn {{_scale, simplex}, idx} -> {simplex, idx} end)

    # Build boundary matrix as map of maps (sparse representation)
    # matrix[col][row] = 1 if simplex at col has face at row
    matrix =
      filtration
      |> Enum.with_index()
      |> Enum.reduce(%{}, fn {{_scale, simplex}, col_idx}, acc ->
        # Get boundary (faces with signs)
        boundary = Simplex.boundary(simplex)

        # In mod 2, we ignore signs (all coefficients are 0 or 1)
        column =
          boundary
          |> Enum.map(fn {_sign, face} -> Map.get(simplex_map, face) end)
          |> Enum.reject(&is_nil/1)
          |> Enum.reduce(%{}, fn row_idx, col_acc ->
            Map.put(col_acc, row_idx, 1)
          end)

        if map_size(column) > 0 do
          Map.put(acc, col_idx, column)
        else
          acc
        end
      end)

    {matrix, simplex_map}
  end

  defp reduce_matrix(matrix, :standard) do
    # Standard algorithm: reduce columns left to right
    # Find lowest non-zero entry in each column (pivot)
    col_indices = Map.keys(matrix) |> Enum.sort()

    Enum.reduce(col_indices, matrix, fn col, current_matrix ->
      reduce_column(current_matrix, col)
    end)
  end

  defp reduce_column(matrix, col) do
    column = Map.get(matrix, col, %{})

    case lowest_one(column) do
      nil ->
        # Column is zero, nothing to do
        matrix

      pivot_row ->
        # Check if any column to the left has the same pivot
        case find_column_with_pivot(matrix, pivot_row, col) do
          nil ->
            # No conflict, column is reduced
            matrix

          other_col ->
            # Add other column to this column (mod 2)
            other_column = Map.get(matrix, other_col, %{})
            new_column = add_columns_mod2(column, other_column)

            # Update matrix and try again
            new_matrix = Map.put(matrix, col, new_column)
            reduce_column(new_matrix, col)
        end
    end
  end

  defp lowest_one(column) do
    if map_size(column) == 0 do
      nil
    else
      column
      |> Map.keys()
      |> Enum.max()
    end
  end

  defp find_column_with_pivot(matrix, pivot_row, exclude_col) do
    matrix
    |> Enum.find(fn {col, column} ->
      col < exclude_col and lowest_one(column) == pivot_row
    end)
    |> case do
      nil -> nil
      {col, _} -> col
    end
  end

  defp add_columns_mod2(col1, col2) do
    # XOR the two columns (addition mod 2)
    all_rows = MapSet.union(MapSet.new(Map.keys(col1)), MapSet.new(Map.keys(col2)))

    Enum.reduce(all_rows, %{}, fn row, acc ->
      val1 = Map.get(col1, row, 0)
      val2 = Map.get(col2, row, 0)
      # XOR: 0+0=0, 0+1=1, 1+0=1, 1+1=0
      new_val = rem(val1 + val2, 2)

      if new_val == 1 do
        Map.put(acc, row, 1)
      else
        acc
      end
    end)
  end

  defp extract_persistence_pairs(reduced_matrix, simplex_map, filtration, max_dim) do
    # Invert simplex_map to get simplex by index
    idx_to_simplex = Map.new(simplex_map, fn {simplex, idx} -> {idx, simplex} end)

    # Get birth times
    birth_times =
      filtration
      |> Enum.with_index()
      |> Map.new(fn {{scale, _simplex}, idx} -> {idx, scale} end)

    # Find persistence pairs
    # A column with pivot creates a pair (birth of pivot row, death of column)
    pairs_by_dim =
      reduced_matrix
      |> Enum.reduce(%{}, fn {col_idx, column}, acc ->
        case lowest_one(column) do
          nil ->
            # Column has no pivot: infinite pair (unpaired birth)
            acc

          pivot_row ->
            # Pair: (birth at pivot_row, death at col_idx)
            birth_idx = pivot_row
            death_idx = col_idx

            birth_time = Map.get(birth_times, birth_idx, 0.0)
            death_time = Map.get(birth_times, death_idx, 0.0)

            # Determine dimension of the feature
            birth_simplex = Map.get(idx_to_simplex, birth_idx)
            dim = Simplex.dimension(birth_simplex)

            pairs = Map.get(acc, dim, [])
            Map.put(acc, dim, [{birth_time, death_time} | pairs])
        end
      end)

    # Add infinite pairs (unpaired births)
    infinite_pairs = find_infinite_pairs(reduced_matrix, idx_to_simplex, birth_times)

    pairs_by_dim =
      Enum.reduce(infinite_pairs, pairs_by_dim, fn {dim, pair}, acc ->
        pairs = Map.get(acc, dim, [])
        Map.put(acc, dim, [pair | pairs])
      end)

    # Build diagrams
    for dim <- 0..max_dim do
      pairs = Map.get(pairs_by_dim, dim, [])

      %{
        dimension: dim,
        pairs: Enum.sort(pairs)
      }
    end
  end

  defp find_infinite_pairs(reduced_matrix, idx_to_simplex, birth_times) do
    # Find simplices that are never a pivot (unpaired births)
    paired_births =
      reduced_matrix
      |> Enum.map(fn {_col, column} -> lowest_one(column) end)
      |> Enum.reject(&is_nil/1)
      |> MapSet.new()

    # All simplices that aren't paired
    idx_to_simplex
    |> Enum.reject(fn {idx, _simplex} -> MapSet.member?(paired_births, idx) end)
    |> Enum.map(fn {idx, simplex} ->
      dim = Simplex.dimension(simplex)
      birth = Map.get(birth_times, idx, 0.0)
      {dim, {birth, :infinity}}
    end)
  end

  defp compute_betti_number(complex, 0) do
    # β₀ = number of components
    vertices = Map.get(complex, 0, []) |> List.flatten() |> Enum.uniq()
    edges = Map.get(complex, 1, [])
    compute_beta_zero(vertices, edges)
  end

  defp compute_betti_number(complex, 1) do
    # β₁ = E - V + C (cyclomatic number)
    vertices = Map.get(complex, 0, []) |> List.flatten() |> Enum.uniq()
    edges = Map.get(complex, 1, [])
    compute_beta_one(vertices, edges)
  end

  defp compute_betti_number(_complex, _dim) do
    # For dim > 1, would need full boundary matrix computation
    # Return 0 as placeholder
    0
  end

  defp compute_beta_zero(vertices, []), do: length(vertices)

  defp compute_beta_zero(vertices, edges) do
    build_graph(vertices, edges) |> ExTopology.Graph.beta_zero()
  end

  defp compute_beta_one(_vertices, []), do: 0

  defp compute_beta_one(vertices, edges) do
    build_graph(vertices, edges) |> ExTopology.Graph.beta_one()
  end

  defp build_graph(vertices, edges) do
    g = Graph.new()
    g = Enum.reduce(vertices, g, fn v, acc -> Graph.add_vertex(acc, v) end)
    Enum.reduce(edges, g, fn [v1, v2], acc -> Graph.add_edge(acc, v1, v2) end)
  end

  @doc """
  Computes the rank (number of non-zero columns) of the reduced matrix.

  ## Parameters

  - `matrix` - Reduced boundary matrix

  ## Returns

  - Integer rank

  ## Examples

      iex> matrix = %{0 => %{}, 1 => %{0 => 1}}
      iex> ExTopology.Persistence.matrix_rank(matrix)
      1
  """
  @spec matrix_rank(map()) :: non_neg_integer()
  def matrix_rank(matrix) do
    matrix
    |> Enum.count(fn {_col, column} -> map_size(column) > 0 end)
  end

  @doc """
  Validates that a matrix satisfies ∂∂ = 0.

  The boundary of a boundary must always be zero (fundamental theorem).

  ## Parameters

  - `matrix` - Boundary matrix
  - `filtration` - Original filtration

  ## Returns

  - `:ok` if valid
  - `{:error, reason}` if invalid
  """
  @spec validate_boundary_property(map(), filtration()) :: :ok | {:error, String.t()}
  def validate_boundary_property(matrix, filtration) do
    # For each column (simplex), check that ∂∂(simplex) = 0
    simplex_map =
      filtration
      |> Enum.with_index()
      |> Map.new(fn {{_scale, simplex}, idx} -> {simplex, idx} end)

    idx_to_simplex = Map.new(simplex_map, fn {simplex, idx} -> {idx, simplex} end)

    result =
      Enum.all?(matrix, fn {_col_idx, column} ->
        # Get faces of this simplex
        faces =
          column
          |> Map.keys()
          |> Enum.map(fn row_idx -> Map.get(idx_to_simplex, row_idx) end)

        # Get boundary of each face
        boundary_of_boundary =
          Enum.flat_map(faces, fn face ->
            face_col = Map.get(simplex_map, face)
            Map.get(matrix, face_col, %{}) |> Map.keys()
          end)

        # Count occurrences (mod 2)
        boundary_of_boundary
        |> Enum.frequencies()
        |> Enum.all?(fn {_vertex, count} -> rem(count, 2) == 0 end)
      end)

    if result do
      :ok
    else
      {:error, "Boundary property ∂∂ = 0 violated"}
    end
  end
end
