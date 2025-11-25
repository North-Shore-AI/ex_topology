defmodule ExTopology.Statistics do
  @moduledoc """
  Statistical measures for topological analysis.

  This module provides statistical functions commonly used in conjunction
  with topological analysis, including correlation measures and effect sizes.

  ## Functions

  - **Correlation**: Pearson and Spearman correlation coefficients
  - **Effect Size**: Cohen's d and related measures
  - **Descriptive**: Mean, variance, standard deviation with Nx tensors
  """

  import Nx.Defn

  @doc """
  Computes the Pearson correlation coefficient between two vectors.

  Pearson correlation measures linear relationship between variables.

      r = cov(X, Y) / (std(X) * std(Y))

  Range: [-1, 1] where:
  - 1 = perfect positive correlation
  - 0 = no linear correlation
  - -1 = perfect negative correlation

  ## Parameters

  - `x` - First vector (Nx tensor or list)
  - `y` - Second vector (same length as x)

  ## Returns

  - Scalar correlation coefficient

  ## Examples

      iex> x = Nx.tensor([1.0, 2.0, 3.0, 4.0, 5.0])
      iex> y = Nx.tensor([2.0, 4.0, 6.0, 8.0, 10.0])
      iex> r = ExTopology.Statistics.pearson(x, y) |> Nx.to_number()
      iex> Float.round(r, 4)
      1.0

      iex> x = Nx.tensor([1.0, 2.0, 3.0, 4.0, 5.0])
      iex> y = Nx.tensor([5.0, 4.0, 3.0, 2.0, 1.0])
      iex> r = ExTopology.Statistics.pearson(x, y) |> Nx.to_number()
      iex> Float.round(r, 4)
      -1.0
  """
  @spec pearson(Nx.Tensor.t() | list(), Nx.Tensor.t() | list()) :: Nx.Tensor.t()
  def pearson(x, y) do
    x_tensor = ensure_tensor(x)
    y_tensor = ensure_tensor(y)
    pearson_impl(x_tensor, y_tensor)
  end

  defnp pearson_impl(x, y) do
    # Means
    mean_x = Nx.mean(x)
    mean_y = Nx.mean(y)

    # Deviations from mean
    dx = x - mean_x
    dy = y - mean_y

    # Covariance (numerator)
    cov = Nx.sum(dx * dy)

    # Standard deviations (denominator)
    std_x = Nx.sqrt(Nx.sum(dx * dx))
    std_y = Nx.sqrt(Nx.sum(dy * dy))

    # Correlation
    cov / (std_x * std_y + 1.0e-10)
  end

  @doc """
  Computes the Spearman rank correlation coefficient.

  Spearman correlation is the Pearson correlation of the ranks.
  It measures monotonic (not necessarily linear) relationships.

  ## Parameters

  - `x` - First vector (Nx tensor or list)
  - `y` - Second vector (same length as x)

  ## Returns

  - Scalar correlation coefficient in [-1, 1]

  ## Examples

      # Perfect monotonic relationship (even if not linear)
      iex> x = [1, 2, 3, 4, 5]
      iex> y = [1, 4, 9, 16, 25]  # y = x^2, monotonic increasing
      iex> r = ExTopology.Statistics.spearman(x, y) |> Nx.to_number()
      iex> Float.round(r, 4)
      1.0

  ## Note

  Uses average ranks for ties.
  """
  @spec spearman(Nx.Tensor.t() | list(), Nx.Tensor.t() | list()) :: Nx.Tensor.t()
  def spearman(x, y) do
    x_list = to_list(x)
    y_list = to_list(y)

    ranks_x = compute_ranks(x_list)
    ranks_y = compute_ranks(y_list)

    pearson(ranks_x, ranks_y)
  end

  @doc """
  Computes correlation with configurable method.

  ## Parameters

  - `x` - First vector
  - `y` - Second vector
  - `opts` - Keyword list:
    - `:method` - `:pearson` or `:spearman` (default: `:pearson`)

  ## Returns

  - Scalar correlation coefficient

  ## Examples

      iex> x = [1.0, 2.0, 3.0, 4.0]
      iex> y = [2.0, 4.0, 6.0, 8.0]
      iex> ExTopology.Statistics.correlation(x, y, method: :pearson) |> Nx.to_number()
      1.0
  """
  @spec correlation(Nx.Tensor.t() | list(), Nx.Tensor.t() | list(), keyword()) :: Nx.Tensor.t()
  def correlation(x, y, opts \\ []) do
    method = Keyword.get(opts, :method, :pearson)

    case method do
      :pearson -> pearson(x, y)
      :spearman -> spearman(x, y)
      other -> raise ArgumentError, "Unknown correlation method: #{inspect(other)}"
    end
  end

  @doc """
  Computes correlation matrix for multiple variables.

  ## Parameters

  - `data` - Matrix where each column is a variable, shape `{n, p}`

  ## Returns

  - Correlation matrix of shape `{p, p}`

  ## Examples

      iex> data = Nx.tensor([[1.0, 2.0], [2.0, 4.0], [3.0, 6.0], [4.0, 8.0]])
      iex> corr = ExTopology.Statistics.correlation_matrix(data)
      iex> Nx.shape(corr)
      {2, 2}
  """
  @spec correlation_matrix(Nx.Tensor.t()) :: Nx.Tensor.t()
  def correlation_matrix(data) do
    {_n, p} = Nx.shape(data)

    # Build correlation matrix
    rows =
      for i <- 0..(p - 1) do
        row =
          for j <- 0..(p - 1) do
            col_i = data[[.., i]]
            col_j = data[[.., j]]
            pearson(col_i, col_j) |> Nx.to_number()
          end

        row
      end

    Nx.tensor(rows)
  end

  @doc """
  Computes Cohen's d effect size between two groups.

  Cohen's d measures the standardized difference between means:

      d = (mean1 - mean2) / pooled_std

  Interpretation (Cohen's conventions):
  - |d| < 0.2: negligible
  - 0.2 <= |d| < 0.5: small
  - 0.5 <= |d| < 0.8: medium
  - |d| >= 0.8: large

  ## Parameters

  - `group1` - First group (Nx tensor or list)
  - `group2` - Second group (Nx tensor or list)

  ## Returns

  - Scalar effect size (positive if group1 > group2)

  ## Examples

      iex> g1 = Nx.tensor([2.0, 3.0, 4.0, 5.0, 6.0])
      iex> g2 = Nx.tensor([1.0, 2.0, 3.0, 4.0, 5.0])
      iex> d = ExTopology.Statistics.cohens_d(g1, g2) |> Nx.to_number()
      iex> Float.round(d, 2)
      0.71
  """
  @spec cohens_d(Nx.Tensor.t() | list(), Nx.Tensor.t() | list()) :: Nx.Tensor.t()
  def cohens_d(group1, group2) do
    g1 = ensure_tensor(group1)
    g2 = ensure_tensor(group2)
    cohens_d_impl(g1, g2)
  end

  defnp cohens_d_impl(g1, g2) do
    n1 = Nx.size(g1)
    n2 = Nx.size(g2)

    mean1 = Nx.mean(g1)
    mean2 = Nx.mean(g2)

    var1 = Nx.variance(g1)
    var2 = Nx.variance(g2)

    # Pooled standard deviation
    pooled_var = ((n1 - 1) * var1 + (n2 - 1) * var2) / (n1 + n2 - 2)
    pooled_std = Nx.sqrt(pooled_var)

    (mean1 - mean2) / (pooled_std + 1.0e-10)
  end

  @doc """
  Computes the coefficient of variation (CV).

  CV = std / mean, expressed as a ratio or percentage.
  Useful for comparing variability across different scales.

  ## Parameters

  - `x` - Vector of values
  - `opts` - Keyword list:
    - `:as_percent` - Return as percentage (default: false)

  ## Returns

  - Scalar CV value

  ## Examples

      iex> x = Nx.tensor([10.0, 12.0, 11.0, 13.0, 9.0])
      iex> cv = ExTopology.Statistics.coefficient_of_variation(x) |> Nx.to_number()
      iex> cv > 0 and cv < 1
      true
  """
  @spec coefficient_of_variation(Nx.Tensor.t() | list(), keyword()) :: Nx.Tensor.t()
  def coefficient_of_variation(x, opts \\ []) do
    as_percent = Keyword.get(opts, :as_percent, false)
    x_tensor = ensure_tensor(x)

    cv = cv_impl(x_tensor)

    if as_percent do
      Nx.multiply(cv, 100)
    else
      cv
    end
  end

  defnp cv_impl(x) do
    mean = Nx.mean(x)
    std = Nx.standard_deviation(x)
    std / (Nx.abs(mean) + 1.0e-10)
  end

  @doc """
  Computes z-scores (standard scores) for a vector.

  z = (x - mean) / std

  ## Parameters

  - `x` - Vector of values

  ## Returns

  - Tensor of z-scores with same shape as input

  ## Examples

      iex> x = Nx.tensor([1.0, 2.0, 3.0, 4.0, 5.0])
      iex> z = ExTopology.Statistics.z_scores(x)
      iex> Nx.to_number(Nx.mean(z)) |> Float.round(6)
      0.0
  """
  @spec z_scores(Nx.Tensor.t() | list()) :: Nx.Tensor.t()
  def z_scores(x) do
    x_tensor = ensure_tensor(x)
    z_scores_impl(x_tensor)
  end

  defnp z_scores_impl(x) do
    mean = Nx.mean(x)
    std = Nx.standard_deviation(x)
    (x - mean) / (std + 1.0e-10)
  end

  @doc """
  Computes the interquartile range (IQR).

  IQR = Q3 - Q1 (75th percentile - 25th percentile)

  ## Parameters

  - `x` - Vector of values

  ## Returns

  - Scalar IQR value

  ## Examples

      iex> x = Nx.tensor([1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0])
      iex> iqr = ExTopology.Statistics.iqr(x) |> Nx.to_number()
      iex> iqr > 0
      true
  """
  @spec iqr(Nx.Tensor.t() | list()) :: Nx.Tensor.t()
  def iqr(x) do
    x_list = to_list(x) |> Enum.sort()
    n = length(x_list)

    q1_idx = round(n * 0.25)
    q3_idx = round(n * 0.75)

    q1 = Enum.at(x_list, max(q1_idx, 0))
    q3 = Enum.at(x_list, min(q3_idx, n - 1))

    Nx.tensor(q3 - q1)
  end

  @doc """
  Computes summary statistics for a vector.

  ## Parameters

  - `x` - Vector of values

  ## Returns

  - Map with statistics: mean, std, min, max, median, q1, q3

  ## Examples

      iex> x = [1, 2, 3, 4, 5]
      iex> stats = ExTopology.Statistics.summary(x)
      iex> Map.keys(stats) |> Enum.sort()
      [:count, :max, :mean, :median, :min, :q1, :q3, :std]
  """
  @spec summary(Nx.Tensor.t() | list()) :: map()
  def summary(x) do
    x_list = to_list(x) |> Enum.sort()
    x_tensor = ensure_tensor(x)
    n = length(x_list)

    q1_idx = round(n * 0.25)
    q3_idx = round(n * 0.75)
    median_idx = div(n, 2)

    %{
      count: n,
      mean: Nx.to_number(Nx.mean(x_tensor)),
      std: Nx.to_number(Nx.standard_deviation(x_tensor)),
      min: Enum.at(x_list, 0),
      max: Enum.at(x_list, n - 1),
      median: Enum.at(x_list, median_idx),
      q1: Enum.at(x_list, max(q1_idx, 0)),
      q3: Enum.at(x_list, min(q3_idx, n - 1))
    }
  end

  # Private helpers

  defp ensure_tensor(x) when is_list(x), do: Nx.tensor(x)
  defp ensure_tensor(%Nx.Tensor{} = t), do: t

  defp to_list(%Nx.Tensor{} = t), do: Nx.to_flat_list(t)
  defp to_list(x) when is_list(x), do: List.flatten(x)

  defp compute_ranks(values) do
    # Assign ranks with average for ties
    n = length(values)

    indexed = values |> Enum.with_index()
    sorted = Enum.sort_by(indexed, fn {v, _i} -> v end)

    # Group by value for tie handling
    groups =
      sorted
      |> Enum.chunk_by(fn {v, _i} -> v end)
      |> Enum.with_index(1)

    # Assign average rank to each group
    rank_map =
      groups
      |> Enum.flat_map(fn {group, start_rank} ->
        group_size = length(group)
        avg_rank = start_rank + (group_size - 1) / 2

        Enum.map(group, fn {_v, original_idx} ->
          {original_idx, avg_rank}
        end)
      end)
      |> Map.new()

    0..(n - 1)
    |> Enum.map(&Map.get(rank_map, &1))
    |> Nx.tensor()
  end
end
