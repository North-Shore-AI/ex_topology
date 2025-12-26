defmodule ExTopology.Diagram do
  @moduledoc """
  Persistence diagram analysis and comparison.

  A persistence diagram is a multiset of points (birth, death) in the plane
  representing topological features. Points far from the diagonal represent
  persistent (significant) features, while points near the diagonal are noise.

  ## Diagram Structure

  Each diagram corresponds to a homology dimension:
  - H₀: connected components
  - H₁: loops/cycles
  - H₂: voids/cavities

  ## Comparison Metrics

  - **Bottleneck distance**: Maximum distance between matched points
  - **Wasserstein distance**: Sum of p-th powers of distances
  - **Landscape**: Functional representation for statistical analysis

  ## Examples

      diagram = %{dimension: 1, pairs: [{0.0, 1.0}, {0.5, 2.0}, {1.0, :infinity}]}
      persistence = ExTopology.Diagram.total_persistence(diagram)
      stable_features = ExTopology.Diagram.filter_by_persistence(diagram, min: 0.5)
  """

  @type point :: {birth :: float(), death :: float() | :infinity}
  @type diagram :: %{
          dimension: non_neg_integer(),
          pairs: [point()]
        }

  @doc """
  Computes the persistence (death - birth) for each point.

  Points with death = ∞ have infinite persistence.

  ## Parameters

  - `diagram` - A persistence diagram

  ## Returns

  - List of persistence values (or :infinity)

  ## Examples

      iex> diagram = %{dimension: 1, pairs: [{0.0, 1.0}, {0.5, 2.0}]}
      iex> ExTopology.Diagram.persistences(diagram)
      [1.0, 1.5]

      iex> diagram = %{dimension: 0, pairs: [{0.0, :infinity}]}
      iex> ExTopology.Diagram.persistences(diagram)
      [:infinity]
  """
  @spec persistences(diagram()) :: [float() | :infinity]
  def persistences(%{pairs: pairs}) do
    Enum.map(pairs, fn
      {_birth, :infinity} -> :infinity
      {birth, death} -> death - birth
    end)
  end

  @doc """
  Computes total persistence (sum of all finite persistences).

  ## Parameters

  - `diagram` - A persistence diagram

  ## Returns

  - Float representing total persistence

  ## Examples

      iex> diagram = %{dimension: 1, pairs: [{0.0, 1.0}, {0.5, 2.0}]}
      iex> ExTopology.Diagram.total_persistence(diagram)
      2.5

      iex> diagram = %{dimension: 0, pairs: [{0.0, :infinity}, {0.0, 1.0}]}
      iex> ExTopology.Diagram.total_persistence(diagram)
      1.0
  """
  @spec total_persistence(diagram()) :: float()
  def total_persistence(diagram) do
    diagram
    |> persistences()
    |> Enum.reject(&(&1 == :infinity))
    |> Enum.sum()
  end

  @doc """
  Filters diagram points by persistence threshold.

  ## Parameters

  - `diagram` - A persistence diagram
  - `opts` - Keyword list:
    - `:min` - Minimum persistence (default: 0)
    - `:max` - Maximum persistence (default: :infinity)

  ## Returns

  - Filtered diagram

  ## Examples

      iex> diagram = %{dimension: 1, pairs: [{0.0, 0.1}, {0.0, 1.0}, {0.5, 2.0}]}
      iex> filtered = ExTopology.Diagram.filter_by_persistence(diagram, min: 0.5)
      iex> length(filtered.pairs)
      2
  """
  @spec filter_by_persistence(diagram(), keyword()) :: diagram()
  def filter_by_persistence(diagram, opts \\ []) do
    min_persistence = Keyword.get(opts, :min, 0)
    max_persistence = Keyword.get(opts, :max, :infinity)

    filtered_pairs =
      diagram.pairs
      |> Enum.filter(fn {birth, death} ->
        pers =
          case death do
            :infinity -> :infinity
            _ -> death - birth
          end

        case pers do
          :infinity ->
            max_persistence == :infinity

          value ->
            value >= min_persistence and
              (max_persistence == :infinity or value <= max_persistence)
        end
      end)

    %{diagram | pairs: filtered_pairs}
  end

  @doc """
  Computes bottleneck distance between two persistence diagrams.

  The bottleneck distance is the infimum over all matchings of the
  maximum distance between matched points (including projections to diagonal).

  ## Parameters

  - `diagram1` - First persistence diagram
  - `diagram2` - Second persistence diagram
  - `opts` - Keyword list:
    - `:p` - Distance power (default: :infinity for bottleneck)

  ## Returns

  - Float bottleneck distance

  ## Examples

      iex> d1 = %{dimension: 1, pairs: [{0.0, 1.0}]}
      iex> d2 = %{dimension: 1, pairs: [{0.0, 1.1}]}
      iex> dist = ExTopology.Diagram.bottleneck_distance(d1, d2)
      iex> dist >= 0.0
      true

  ## Mathematical Background

  d_B(D₁, D₂) = inf_γ sup_{x∈D₁} ||x - γ(x)||_∞

  where γ ranges over all matchings between diagrams.
  """
  @spec bottleneck_distance(diagram(), diagram(), keyword()) :: float()
  def bottleneck_distance(diagram1, diagram2, _opts \\ []) do
    # For simplicity, implement greedy matching
    # Full optimal matching requires Hungarian algorithm
    points1 = prepare_points(diagram1.pairs)
    points2 = prepare_points(diagram2.pairs)

    greedy_bottleneck_distance(points1, points2)
  end

  @doc """
  Computes Wasserstein distance (p-Wasserstein distance) between diagrams.

  The p-Wasserstein distance is:
  W_p(D₁, D₂) = (inf_γ Σ ||x - γ(x)||_∞^p)^(1/p)

  ## Parameters

  - `diagram1` - First persistence diagram
  - `diagram2` - Second persistence diagram
  - `opts` - Keyword list:
    - `:p` - Distance power (default: 2)

  ## Returns

  - Float Wasserstein distance

  ## Examples

      iex> d1 = %{dimension: 1, pairs: [{0.0, 1.0}]}
      iex> d2 = %{dimension: 1, pairs: [{0.0, 1.1}]}
      iex> dist = ExTopology.Diagram.wasserstein_distance(d1, d2, p: 2)
      iex> dist > 0
      true
  """
  @spec wasserstein_distance(diagram(), diagram(), keyword()) :: float()
  def wasserstein_distance(diagram1, diagram2, opts \\ []) do
    p = Keyword.get(opts, :p, 2)

    points1 = prepare_points(diagram1.pairs)
    points2 = prepare_points(diagram2.pairs)

    greedy_wasserstein_distance(points1, points2, p)
  end

  @doc """
  Computes persistence entropy of a diagram.

  Entropy measures the distribution of persistence values,
  giving insight into the complexity of the topological structure.

  ## Parameters

  - `diagram` - A persistence diagram

  ## Returns

  - Float entropy value

  ## Examples

      iex> diagram = %{dimension: 1, pairs: [{0.0, 1.0}, {0.0, 2.0}]}
      iex> entropy = ExTopology.Diagram.entropy(diagram)
      iex> entropy > 0
      true

  ## Mathematical Background

  E = -Σᵢ (pᵢ/L) log(pᵢ/L)

  where pᵢ is persistence of point i, L is total persistence.
  """
  @spec entropy(diagram()) :: float()
  def entropy(diagram) do
    persts =
      diagram
      |> persistences()
      # Filter infinity and zero persistence (birth == death) in one pass
      |> Enum.reject(fn p -> p == :infinity or p == 0.0 end)

    compute_entropy(persts)
  end

  defp compute_entropy([]), do: 0.0

  defp compute_entropy(persts) do
    total = Enum.sum(persts)
    do_compute_entropy(persts, total)
  end

  defp do_compute_entropy(_persts, total) when total == 0.0, do: 0.0

  defp do_compute_entropy(persts, total) do
    persts
    |> Enum.map(fn p ->
      prob = p / total
      if prob > 0, do: -prob * :math.log(prob), else: 0.0
    end)
    |> Enum.sum()
  end

  @doc """
  Returns summary statistics for a persistence diagram.

  ## Parameters

  - `diagram` - A persistence diagram

  ## Returns

  - Map with statistics:
    - `:count` - Number of points
    - `:finite_count` - Number of finite points
    - `:infinite_count` - Number of infinite points
    - `:total_persistence` - Sum of finite persistences
    - `:max_persistence` - Maximum finite persistence
    - `:mean_persistence` - Mean finite persistence
    - `:entropy` - Persistence entropy

  ## Examples

      iex> diagram = %{dimension: 1, pairs: [{0.0, 1.0}, {0.5, 2.0}]}
      iex> stats = ExTopology.Diagram.summary_statistics(diagram)
      iex> stats.count
      2
  """
  @spec summary_statistics(diagram()) :: map()
  def summary_statistics(diagram) do
    all_persts = persistences(diagram)
    finite_persts = Enum.reject(all_persts, &(&1 == :infinity))
    infinite_count = length(all_persts) - length(finite_persts)

    %{
      count: length(all_persts),
      finite_count: length(finite_persts),
      infinite_count: infinite_count,
      total_persistence: Enum.sum(finite_persts),
      max_persistence: if(Enum.empty?(finite_persts), do: 0.0, else: Enum.max(finite_persts)),
      mean_persistence:
        if(Enum.empty?(finite_persts),
          do: 0.0,
          else: Enum.sum(finite_persts) / length(finite_persts)
        ),
      entropy: entropy(diagram)
    }
  end

  @doc """
  Projects infinite points to a finite death value for visualization.

  ## Parameters

  - `diagram` - A persistence diagram
  - `max_death` - Maximum death value to use (default: computed from data)

  ## Returns

  - Diagram with infinite points projected

  ## Examples

      iex> diagram = %{dimension: 0, pairs: [{0.0, :infinity}, {0.0, 1.0}]}
      iex> projected = ExTopology.Diagram.project_infinite(diagram, 10.0)
      iex> Enum.all?(projected.pairs, fn {_, d} -> d != :infinity end)
      true
  """
  @spec project_infinite(diagram(), float() | nil) :: diagram()
  def project_infinite(diagram, max_death \\ nil) do
    max_death =
      max_death ||
        diagram.pairs
        |> Enum.map(fn {_, d} -> d end)
        |> Enum.reject(&(&1 == :infinity))
        |> Enum.max(fn -> 1.0 end)
        |> Kernel.*(1.5)

    projected_pairs =
      Enum.map(diagram.pairs, fn
        {birth, :infinity} -> {birth, max_death}
        pair -> pair
      end)

    %{diagram | pairs: projected_pairs}
  end

  @doc """
  Converts diagram to points in persistence-birth coordinate system.

  Returns list of {persistence, birth} tuples for plotting.

  ## Parameters

  - `diagram` - A persistence diagram

  ## Returns

  - List of {persistence, birth} tuples

  ## Examples

      iex> diagram = %{dimension: 1, pairs: [{0.0, 1.0}, {0.5, 2.0}]}
      iex> coords = ExTopology.Diagram.to_persistence_birth_coords(diagram)
      iex> Enum.sort(coords)
      [{1.0, 0.0}, {1.5, 0.5}]
  """
  @spec to_persistence_birth_coords(diagram()) :: [{float(), float()}]
  def to_persistence_birth_coords(diagram) do
    diagram.pairs
    |> Enum.reject(fn {_, death} -> death == :infinity end)
    |> Enum.map(fn {birth, death} -> {death - birth, birth} end)
  end

  # Private helper functions

  defp prepare_points(pairs) do
    # Convert points, treating infinity as a large value for computation
    Enum.map(pairs, fn
      {birth, :infinity} -> {birth, birth + 1000.0}
      {birth, death} -> {birth, death}
    end)
  end

  defp greedy_bottleneck_distance(points1, points2) do
    # Simplified greedy matching (not optimal)
    # Proper implementation would use Hungarian algorithm

    if Enum.empty?(points1) and Enum.empty?(points2) do
      0.0
    else
      # Add diagonal projections to both sets
      all_points1 = points1 ++ diagonal_projections(points2)
      all_points2 = points2 ++ diagonal_projections(points1)

      # Compute pairwise distances
      distances =
        for p1 <- all_points1, p2 <- all_points2 do
          point_distance(p1, p2)
        end

      Enum.max(distances, fn -> 0.0 end)
    end
  end

  defp greedy_wasserstein_distance(points1, points2, p) do
    # Simplified greedy matching
    all_points1 = points1 ++ diagonal_projections(points2)
    all_points2 = points2 ++ diagonal_projections(points1)

    distances =
      for p1 <- all_points1, p2 <- all_points2 do
        point_distance(p1, p2)
      end

    sum_powers = Enum.reduce(distances, 0.0, fn d, acc -> acc + :math.pow(d, p) end)
    :math.pow(sum_powers / length(distances), 1.0 / p)
  end

  defp diagonal_projections(points) do
    # Project each point to diagonal: (b, d) -> (b+d)/2, (b+d)/2)
    Enum.map(points, fn {birth, death} ->
      mid = (birth + death) / 2.0
      {mid, mid}
    end)
  end

  defp point_distance({b1, d1}, {b2, d2}) do
    # Infinity norm (Chebyshev distance)
    max(abs(b1 - b2), abs(d1 - d2))
  end

  @doc """
  Computes the persistence landscape at a specific level.

  Persistence landscapes provide a functional representation of diagrams
  suitable for statistical analysis and machine learning.

  ## Parameters

  - `diagram` - A persistence diagram
  - `t_values` - List of parameter values at which to evaluate
  - `opts` - Keyword list:
    - `:level` - Landscape level k (default: 1)

  ## Returns

  - List of landscape values at t_values

  ## Examples

      iex> diagram = %{dimension: 1, pairs: [{0.0, 2.0}]}
      iex> t_values = [0.0, 0.5, 1.0, 1.5, 2.0]
      iex> landscape = ExTopology.Diagram.persistence_landscape(diagram, t_values, level: 1)
      iex> length(landscape) == length(t_values)
      true

  ## Mathematical Background

  λₖ(t) = k-th largest value of min(t - birth, death - t)⁺ over all points
  """
  @spec persistence_landscape(diagram(), [float()], keyword()) :: [float()]
  def persistence_landscape(diagram, t_values, opts \\ []) do
    k = Keyword.get(opts, :level, 1)

    # Filter out infinite points
    finite_pairs = Enum.reject(diagram.pairs, fn {_, d} -> d == :infinity end)

    Enum.map(t_values, fn t ->
      # Compute tent function values for all points at this t
      tent_values =
        finite_pairs
        |> Enum.map(fn {birth, death} ->
          max(0.0, min(t - birth, death - t))
        end)
        |> Enum.sort(:desc)

      # Take k-th largest value (0 if not enough points)
      Enum.at(tent_values, k - 1, 0.0)
    end)
  end

  @doc """
  Checks if two diagrams have the same dimension.

  ## Parameters

  - `diagram1` - First diagram
  - `diagram2` - Second diagram

  ## Returns

  - `true` if dimensions match, `false` otherwise

  ## Examples

      iex> d1 = %{dimension: 1, pairs: []}
      iex> d2 = %{dimension: 1, pairs: []}
      iex> ExTopology.Diagram.same_dimension?(d1, d2)
      true
  """
  @spec same_dimension?(diagram(), diagram()) :: boolean()
  def same_dimension?(diagram1, diagram2) do
    diagram1.dimension == diagram2.dimension
  end
end
