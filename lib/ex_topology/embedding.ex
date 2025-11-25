defmodule ExTopology.Embedding do
  @moduledoc """
  Topological measures for point cloud embeddings.

  This module provides metrics for analyzing the local and global structure
  of point embeddings, useful for evaluating embedding quality and detecting
  structural anomalies.

  ## Key Metrics

  - **k-NN variance**: Measures consistency of local neighborhood distances
  - **Local density**: Estimates point density in the embedding space
  - **Isolation score**: Identifies outliers based on neighborhood distances
  - **Neighborhood stability**: Measures how stable neighborhoods are

  ## Use Cases

  - **Embedding quality**: High k-NN variance indicates unstable regions
  - **Outlier detection**: Points with unusual local density
  - **Cluster analysis**: Density-based structure identification
  - **Fragility detection**: Regions where small perturbations have large effects

  ## Example

      points = Nx.tensor([...])  # Your embedding

      # Overall embedding quality
      variance = ExTopology.Embedding.knn_variance(points, k: 10)

      # Per-point analysis
      densities = ExTopology.Embedding.local_density(points, k: 10)
      outlier_scores = ExTopology.Embedding.isolation_scores(points, k: 10)
  """

  alias ExTopology.Distance

  @doc """
  Computes the k-NN distance variance across all points.

  For each point, this measures the variance of distances to its k nearest
  neighbors. High variance indicates inconsistent neighborhood structure,
  which may suggest embedding instability or fragility.

  ## Parameters

  - `points` - Nx tensor of shape `{n, d}`
  - `opts` - Keyword list:
    - `:k` - Number of neighbors (default: 10)
    - `:metric` - Distance metric (default: `:euclidean`)
    - `:reduce` - Reduction method: `:mean`, `:max`, `:none` (default: `:mean`)

  ## Returns

  - If `reduce: :mean`: Scalar tensor with mean variance
  - If `reduce: :max`: Scalar tensor with max variance
  - If `reduce: :none`: Tensor of shape `{n}` with per-point variances

  ## Examples

      iex> points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [2.0, 0.0], [3.0, 0.0]])
      iex> var = ExTopology.Embedding.knn_variance(points, k: 2)
      iex> Nx.to_number(var) < 0.1  # Uniform spacing = low variance
      true

  ## Interpretation

  - Low variance: Consistent neighborhood structure (good)
  - High variance: Irregular spacing or outliers (may indicate issues)
  """
  @spec knn_variance(Nx.Tensor.t(), keyword()) :: Nx.Tensor.t()
  def knn_variance(points, opts \\ []) do
    k = Keyword.get(opts, :k, 10)
    metric = Keyword.get(opts, :metric, :euclidean)
    reduce = Keyword.get(opts, :reduce, :mean)

    {n, _d} = Nx.shape(points)
    k = min(k, n - 1)

    if k < 1 do
      raise ArgumentError, "k must be at least 1, got: #{k}"
    end

    distances = Distance.pairwise(points, metric: metric)
    knn_dists = get_knn_distances(distances, k)
    per_point_variance = Nx.variance(knn_dists, axes: [1])

    case reduce do
      :mean -> Nx.mean(per_point_variance)
      :max -> Nx.reduce_max(per_point_variance)
      :none -> per_point_variance
      other -> raise ArgumentError, "Unknown reduction: #{inspect(other)}"
    end
  end

  @doc """
  Computes the k-NN distances for each point.

  Returns the distances to the k nearest neighbors (excluding self).

  ## Parameters

  - `points` - Nx tensor of shape `{n, d}`
  - `opts` - Keyword list:
    - `:k` - Number of neighbors (default: 10)
    - `:metric` - Distance metric (default: `:euclidean`)

  ## Returns

  - Tensor of shape `{n, k}` with k-NN distances per point

  ## Examples

      iex> points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [3.0, 0.0]])
      iex> dists = ExTopology.Embedding.knn_distances(points, k: 1)
      iex> Nx.shape(dists)
      {3, 1}
  """
  @spec knn_distances(Nx.Tensor.t(), keyword()) :: Nx.Tensor.t()
  def knn_distances(points, opts \\ []) do
    k = Keyword.get(opts, :k, 10)
    metric = Keyword.get(opts, :metric, :euclidean)

    {n, _d} = Nx.shape(points)
    k = min(k, n - 1)

    distances = Distance.pairwise(points, metric: metric)
    get_knn_distances(distances, k)
  end

  @doc """
  Estimates local density for each point using k-NN distances.

  Higher values indicate denser regions. Computed as the inverse of
  the mean k-NN distance.

  ## Parameters

  - `points` - Nx tensor of shape `{n, d}`
  - `opts` - Keyword list:
    - `:k` - Number of neighbors (default: 10)
    - `:metric` - Distance metric (default: `:euclidean`)

  ## Returns

  - Tensor of shape `{n}` with density estimate per point

  ## Examples

      iex> points = Nx.tensor([[0.0, 0.0], [0.1, 0.0], [0.2, 0.0], [10.0, 0.0]])
      iex> densities = ExTopology.Embedding.local_density(points, k: 2)
      iex> Nx.to_number(densities[0]) > Nx.to_number(densities[3])
      true

  ## Note

  Points in sparse regions have lower density (larger k-NN distances).
  """
  @spec local_density(Nx.Tensor.t(), keyword()) :: Nx.Tensor.t()
  def local_density(points, opts \\ []) do
    k = Keyword.get(opts, :k, 10)
    metric = Keyword.get(opts, :metric, :euclidean)

    {n, _d} = Nx.shape(points)
    k = min(k, n - 1)

    distances = Distance.pairwise(points, metric: metric)
    knn_dists = get_knn_distances(distances, k)
    mean_knn_dist = Nx.mean(knn_dists, axes: [1])

    # Density = 1 / mean_distance (with small epsilon to avoid division by zero)
    Nx.divide(1.0, Nx.add(mean_knn_dist, 1.0e-10))
  end

  @doc """
  Computes isolation scores for outlier detection.

  Based on k-NN distances - points far from their neighbors have high
  isolation scores. Uses the Local Outlier Factor (LOF) concept.

  ## Parameters

  - `points` - Nx tensor of shape `{n, d}`
  - `opts` - Keyword list:
    - `:k` - Number of neighbors (default: 10)
    - `:metric` - Distance metric (default: `:euclidean`)

  ## Returns

  - Tensor of shape `{n}` with isolation scores per point
  - Scores > 1 indicate potential outliers

  ## Examples

      iex> points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [2.0, 0.0], [100.0, 0.0]])
      iex> scores = ExTopology.Embedding.isolation_scores(points, k: 2)
      iex> Nx.to_number(scores[3]) > Nx.to_number(scores[0])
      true
  """
  @spec isolation_scores(Nx.Tensor.t(), keyword()) :: Nx.Tensor.t()
  def isolation_scores(points, opts \\ []) do
    k = Keyword.get(opts, :k, 10)
    metric = Keyword.get(opts, :metric, :euclidean)

    {n, _d} = Nx.shape(points)
    k = min(k, n - 1)

    distances = Distance.pairwise(points, metric: metric)
    knn_dists = get_knn_distances(distances, k)

    # Compute local reachability density for each point
    # Using simplified LOF: ratio of point's mean k-NN distance to neighbors' mean
    mean_knn_dist = Nx.mean(knn_dists, axes: [1])

    # Get indices of k nearest neighbors
    knn_indices = get_knn_indices(distances, k)

    # For each point, compute ratio to neighbors
    compute_lof_scores(mean_knn_dist, knn_indices)
  end

  @doc """
  Computes the mean k-NN distance for each point.

  This is a simpler alternative to full density estimation.

  ## Parameters

  - `points` - Nx tensor of shape `{n, d}`
  - `opts` - Keyword list:
    - `:k` - Number of neighbors (default: 10)
    - `:metric` - Distance metric (default: `:euclidean`)

  ## Returns

  - Tensor of shape `{n}` with mean k-NN distance per point

  ## Examples

      iex> points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [2.0, 0.0]])
      iex> mean_dists = ExTopology.Embedding.mean_knn_distance(points, k: 1)
      iex> Nx.shape(mean_dists)
      {3}
  """
  @spec mean_knn_distance(Nx.Tensor.t(), keyword()) :: Nx.Tensor.t()
  def mean_knn_distance(points, opts \\ []) do
    k = Keyword.get(opts, :k, 10)
    metric = Keyword.get(opts, :metric, :euclidean)

    {n, _d} = Nx.shape(points)
    k = min(k, n - 1)

    distances = Distance.pairwise(points, metric: metric)
    knn_dists = get_knn_distances(distances, k)

    Nx.mean(knn_dists, axes: [1])
  end

  @doc """
  Computes global embedding statistics.

  Returns a summary of embedding structure including variance,
  density statistics, and potential issues.

  ## Parameters

  - `points` - Nx tensor of shape `{n, d}`
  - `opts` - Keyword list:
    - `:k` - Number of neighbors for local metrics (default: 10)

  ## Returns

  - Map with embedding statistics

  ## Examples

      iex> points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [2.0, 0.0], [3.0, 0.0]])
      iex> stats = ExTopology.Embedding.statistics(points, k: 2)
      iex> Map.keys(stats)
      [:knn_variance, :mean_knn_distance, :density_mean, :density_std, :n_points, :dimensions]
  """
  @spec statistics(Nx.Tensor.t(), keyword()) :: map()
  def statistics(points, opts \\ []) do
    k = Keyword.get(opts, :k, 10)
    {n, d} = Nx.shape(points)
    k = min(k, n - 1)

    distances = Distance.pairwise(points, metric: :euclidean)
    knn_dists = get_knn_distances(distances, k)

    per_point_variance = Nx.variance(knn_dists, axes: [1])
    mean_knn_dist = Nx.mean(knn_dists, axes: [1])
    densities = Nx.divide(1.0, Nx.add(mean_knn_dist, 1.0e-10))

    %{
      n_points: n,
      dimensions: d,
      knn_variance: Nx.to_number(Nx.mean(per_point_variance)),
      mean_knn_distance: Nx.to_number(Nx.mean(mean_knn_dist)),
      density_mean: Nx.to_number(Nx.mean(densities)),
      density_std: Nx.to_number(Nx.standard_deviation(densities))
    }
  end

  @doc """
  Identifies points in low-density regions.

  Points below the density threshold are considered sparse/isolated.

  ## Parameters

  - `points` - Nx tensor of shape `{n, d}`
  - `opts` - Keyword list:
    - `:k` - Number of neighbors (default: 10)
    - `:percentile` - Density percentile threshold (default: 10)

  ## Returns

  - List of indices for points in low-density regions
  """
  @spec sparse_points(Nx.Tensor.t(), keyword()) :: [non_neg_integer()]
  def sparse_points(points, opts \\ []) do
    k = Keyword.get(opts, :k, 10)
    percentile = Keyword.get(opts, :percentile, 10)

    densities = local_density(points, k: k)
    density_list = Nx.to_flat_list(densities)

    sorted_densities = Enum.sort(density_list)
    threshold_idx = round(length(sorted_densities) * percentile / 100)
    threshold = Enum.at(sorted_densities, max(threshold_idx, 0))

    density_list
    |> Enum.with_index()
    |> Enum.filter(fn {d, _idx} -> d <= threshold end)
    |> Enum.map(fn {_d, idx} -> idx end)
  end

  # Private helper functions

  defp get_knn_distances(distances, k) do
    # Sort each row and take indices 1 to k (excluding self at index 0)
    sorted = Nx.sort(distances, axis: 1)
    # Skip first column (self-distance = 0) and take k neighbors
    Nx.slice(sorted, [0, 1], [Nx.axis_size(sorted, 0), k])
  end

  defp get_knn_indices(distances, k) do
    # Get indices of k nearest neighbors for each point
    distances
    |> Nx.to_list()
    |> Enum.map(fn row ->
      row
      |> Enum.with_index()
      |> Enum.sort_by(fn {dist, _idx} -> dist end)
      |> Enum.slice(1, k)
      |> Enum.map(fn {_dist, idx} -> idx end)
    end)
  end

  defp compute_lof_scores(mean_knn_dist, knn_indices) do
    mean_dists = Nx.to_flat_list(mean_knn_dist)

    scores =
      Enum.zip(mean_dists, knn_indices)
      |> Enum.map(fn {my_dist, neighbor_indices} ->
        neighbor_dists = Enum.map(neighbor_indices, &Enum.at(mean_dists, &1))
        avg_neighbor_dist = Enum.sum(neighbor_dists) / max(length(neighbor_dists), 1)

        if avg_neighbor_dist > 1.0e-10 do
          my_dist / avg_neighbor_dist
        else
          1.0
        end
      end)

    Nx.tensor(scores)
  end
end
