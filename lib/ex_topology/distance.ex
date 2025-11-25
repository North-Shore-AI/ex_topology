defmodule ExTopology.Distance do
  @moduledoc """
  Distance matrix computation for point clouds.

  This module provides efficient pairwise distance calculations using Nx tensors.
  All distance functions produce symmetric matrices with zero diagonal.

  ## Supported Metrics

  - **Euclidean** (L2): `√(Σ(xᵢ - yᵢ)²)` - Standard geometric distance
  - **Cosine**: `1 - cos(θ)` - Angular distance, useful for embeddings
  - **Manhattan** (L1): `Σ|xᵢ - yᵢ|` - City-block distance
  - **Chebyshev** (L∞): `max|xᵢ - yᵢ|` - Maximum coordinate difference
  - **Minkowski** (Lp): `(Σ|xᵢ - yᵢ|ᵖ)^(1/p)` - Generalized distance

  ## Usage

      points = Nx.tensor([[0.0, 0.0], [3.0, 4.0], [1.0, 1.0]])
      ExTopology.Distance.euclidean_matrix(points)
      #=> Nx.tensor([
      #=>   [0.0, 5.0, 1.414...],
      #=>   [5.0, 0.0, 3.605...],
      #=>   [1.414..., 3.605..., 0.0]
      #=> ])

  ## Scale Guidelines

  | Point Count | Memory | Recommendation |
  |-------------|--------|----------------|
  | < 1,000 | 8 MB | Dense matrices work well |
  | 1,000-5,000 | 200 MB | Watch memory usage |
  | 5,000-10,000 | 800 MB | Consider EXLA backend |
  | > 10,000 | > 800 MB | Use k-NN graphs instead |
  """

  import Nx.Defn

  @doc """
  Computes pairwise Euclidean (L2) distance matrix.

  The Euclidean distance between points x and y is:

      d(x, y) = √(Σᵢ(xᵢ - yᵢ)²)

  ## Parameters

  - `points` - Nx tensor of shape `{n, d}` where n is number of points
    and d is dimensionality

  ## Returns

  - Nx tensor of shape `{n, n}` containing pairwise distances
  - Matrix is symmetric with zero diagonal

  ## Examples

      iex> points = Nx.tensor([[0.0, 0.0], [3.0, 4.0]])
      iex> ExTopology.Distance.euclidean_matrix(points)
      #Nx.Tensor<
        f32[2][2]
        [
          [0.0, 5.0],
          [5.0, 0.0]
        ]
      >

      iex> points = Nx.tensor([[0.0], [1.0], [3.0]])
      iex> ExTopology.Distance.euclidean_matrix(points)
      #Nx.Tensor<
        f32[3][3]
        [
          [0.0, 1.0, 3.0],
          [1.0, 0.0, 2.0],
          [3.0, 2.0, 0.0]
        ]
      >
  """
  @spec euclidean_matrix(Nx.Tensor.t()) :: Nx.Tensor.t()
  defn euclidean_matrix(points) do
    # points: {n, d}
    # Compute: ||x - y||₂ for all pairs

    # Expand dims for broadcasting
    # points_i: {n, 1, d}
    # points_j: {1, n, d}
    points_i = Nx.new_axis(points, 1)
    points_j = Nx.new_axis(points, 0)

    # diff: {n, n, d}
    diff = points_i - points_j

    # Sum squared differences along last axis
    # distances: {n, n}
    Nx.sqrt(Nx.sum(diff * diff, axes: [-1]))
  end

  @doc """
  Computes pairwise cosine distance matrix.

  Cosine distance is defined as: `d(x, y) = 1 - cos(θ)`

  where cos(θ) = (x · y) / (||x|| ||y||)

  Range: [0, 2] where 0 = identical direction, 1 = orthogonal, 2 = opposite

  ## Parameters

  - `points` - Nx tensor of shape `{n, d}`

  ## Returns

  - Nx tensor of shape `{n, n}` containing pairwise cosine distances

  ## Examples

      iex> points = Nx.tensor([[1.0, 0.0], [0.0, 1.0], [1.0, 1.0]])
      iex> dists = ExTopology.Distance.cosine_matrix(points)
      iex> Nx.to_number(dists[0][1]) |> Float.round(4)
      1.0
      iex> Nx.to_number(dists[0][2]) |> Float.round(4)
      0.2929

  ## Notes

  - Returns NaN for zero vectors (undefined direction)
  - For unit vectors (normalized), cosine distance = 1 - dot product
  """
  @spec cosine_matrix(Nx.Tensor.t()) :: Nx.Tensor.t()
  defn cosine_matrix(points) do
    # Compute norms
    norms = Nx.sqrt(Nx.sum(points * points, axes: [1], keep_axes: true))

    # Normalize points
    normalized = points / norms

    # Cosine similarity = normalized dot product
    similarity = Nx.dot(normalized, [1], normalized, [1])

    # Cosine distance = 1 - similarity
    1.0 - similarity
  end

  @doc """
  Computes pairwise Manhattan (L1) distance matrix.

  The Manhattan distance between points x and y is:

      d(x, y) = Σᵢ|xᵢ - yᵢ|

  Also known as taxicab distance or city-block distance.

  ## Parameters

  - `points` - Nx tensor of shape `{n, d}`

  ## Returns

  - Nx tensor of shape `{n, n}` containing pairwise Manhattan distances

  ## Examples

      iex> points = Nx.tensor([[0.0, 0.0], [3.0, 4.0]])
      iex> ExTopology.Distance.manhattan_matrix(points)
      #Nx.Tensor<
        f32[2][2]
        [
          [0.0, 7.0],
          [7.0, 0.0]
        ]
      >
  """
  @spec manhattan_matrix(Nx.Tensor.t()) :: Nx.Tensor.t()
  defn manhattan_matrix(points) do
    points_i = Nx.new_axis(points, 1)
    points_j = Nx.new_axis(points, 0)
    diff = points_i - points_j

    Nx.sum(Nx.abs(diff), axes: [-1])
  end

  @doc """
  Computes pairwise Chebyshev (L∞) distance matrix.

  The Chebyshev distance between points x and y is:

      d(x, y) = maxᵢ|xᵢ - yᵢ|

  Also known as maximum metric or chessboard distance.

  ## Parameters

  - `points` - Nx tensor of shape `{n, d}`

  ## Returns

  - Nx tensor of shape `{n, n}` containing pairwise Chebyshev distances

  ## Examples

      iex> points = Nx.tensor([[0.0, 0.0], [3.0, 4.0]])
      iex> ExTopology.Distance.chebyshev_matrix(points)
      #Nx.Tensor<
        f32[2][2]
        [
          [0.0, 4.0],
          [4.0, 0.0]
        ]
      >
  """
  @spec chebyshev_matrix(Nx.Tensor.t()) :: Nx.Tensor.t()
  defn chebyshev_matrix(points) do
    points_i = Nx.new_axis(points, 1)
    points_j = Nx.new_axis(points, 0)
    diff = points_i - points_j

    Nx.reduce_max(Nx.abs(diff), axes: [-1])
  end

  @doc """
  Computes pairwise Minkowski (Lp) distance matrix.

  The Minkowski distance between points x and y is:

      d(x, y) = (Σᵢ|xᵢ - yᵢ|ᵖ)^(1/p)

  Special cases:
  - p = 1: Manhattan distance
  - p = 2: Euclidean distance
  - p → ∞: Chebyshev distance

  ## Parameters

  - `points` - Nx tensor of shape `{n, d}`
  - `p` - The order of the norm (must be >= 1)

  ## Returns

  - Nx tensor of shape `{n, n}` containing pairwise Minkowski distances

  ## Examples

      iex> points = Nx.tensor([[0.0, 0.0], [3.0, 4.0]])
      iex> ExTopology.Distance.minkowski_matrix(points, 2)
      #Nx.Tensor<
        f32[2][2]
        [
          [0.0, 5.0],
          [5.0, 0.0]
        ]
      >

      iex> points = Nx.tensor([[0.0, 0.0], [3.0, 4.0]])
      iex> ExTopology.Distance.minkowski_matrix(points, 1)
      #Nx.Tensor<
        f32[2][2]
        [
          [0.0, 7.0],
          [7.0, 0.0]
        ]
      >
  """
  @spec minkowski_matrix(Nx.Tensor.t(), number()) :: Nx.Tensor.t()
  defn minkowski_matrix(points, p) do
    points_i = Nx.new_axis(points, 1)
    points_j = Nx.new_axis(points, 0)
    diff = points_i - points_j

    Nx.pow(Nx.sum(Nx.pow(Nx.abs(diff), p), axes: [-1]), 1.0 / p)
  end

  @doc """
  Computes pairwise squared Euclidean distance matrix.

  Squared Euclidean avoids the square root, making it faster when
  only relative distances matter (e.g., nearest neighbor queries).

      d²(x, y) = Σᵢ(xᵢ - yᵢ)²

  ## Parameters

  - `points` - Nx tensor of shape `{n, d}`

  ## Returns

  - Nx tensor of shape `{n, n}` containing pairwise squared distances

  ## Examples

      iex> points = Nx.tensor([[0.0, 0.0], [3.0, 4.0]])
      iex> ExTopology.Distance.squared_euclidean_matrix(points)
      #Nx.Tensor<
        f32[2][2]
        [
          [0.0, 25.0],
          [25.0, 0.0]
        ]
      >
  """
  @spec squared_euclidean_matrix(Nx.Tensor.t()) :: Nx.Tensor.t()
  defn squared_euclidean_matrix(points) do
    points_i = Nx.new_axis(points, 1)
    points_j = Nx.new_axis(points, 0)
    diff = points_i - points_j

    Nx.sum(diff * diff, axes: [-1])
  end

  @doc """
  Computes distance between two individual points.

  ## Parameters

  - `point_a` - Nx tensor of shape `{d}`
  - `point_b` - Nx tensor of shape `{d}`
  - `opts` - Keyword list:
    - `:metric` - Distance metric (default: `:euclidean`)
      Options: `:euclidean`, `:cosine`, `:manhattan`, `:chebyshev`

  ## Returns

  - Scalar Nx tensor with the distance

  ## Examples

      iex> a = Nx.tensor([0.0, 0.0])
      iex> b = Nx.tensor([3.0, 4.0])
      iex> ExTopology.Distance.distance(a, b) |> Nx.to_number()
      5.0

      iex> a = Nx.tensor([0.0, 0.0])
      iex> b = Nx.tensor([3.0, 4.0])
      iex> ExTopology.Distance.distance(a, b, metric: :manhattan) |> Nx.to_number()
      7.0
  """
  @spec distance(Nx.Tensor.t(), Nx.Tensor.t(), keyword()) :: Nx.Tensor.t()
  def distance(point_a, point_b, opts \\ []) do
    metric = Keyword.get(opts, :metric, :euclidean)

    case metric do
      :euclidean -> euclidean_distance(point_a, point_b)
      :cosine -> cosine_distance(point_a, point_b)
      :manhattan -> manhattan_distance(point_a, point_b)
      :chebyshev -> chebyshev_distance(point_a, point_b)
      other -> raise ArgumentError, "Unknown metric: #{inspect(other)}"
    end
  end

  @doc """
  Computes pairwise distance matrix with configurable metric.

  ## Parameters

  - `points` - Nx tensor of shape `{n, d}`
  - `opts` - Keyword list:
    - `:metric` - Distance metric (default: `:euclidean`)

  ## Returns

  - Nx tensor of shape `{n, n}` containing pairwise distances

  ## Examples

      iex> points = Nx.tensor([[0.0, 0.0], [3.0, 4.0]])
      iex> ExTopology.Distance.pairwise(points, metric: :manhattan)
      #Nx.Tensor<
        f32[2][2]
        [
          [0.0, 7.0],
          [7.0, 0.0]
        ]
      >
  """
  @spec pairwise(Nx.Tensor.t(), keyword()) :: Nx.Tensor.t()
  def pairwise(points, opts \\ []) do
    metric = Keyword.get(opts, :metric, :euclidean)

    case metric do
      :euclidean -> euclidean_matrix(points)
      :squared_euclidean -> squared_euclidean_matrix(points)
      :cosine -> cosine_matrix(points)
      :manhattan -> manhattan_matrix(points)
      :chebyshev -> chebyshev_matrix(points)
      {:minkowski, p} -> minkowski_matrix(points, p)
      other -> raise ArgumentError, "Unknown metric: #{inspect(other)}"
    end
  end

  # Private distance functions for individual points

  defnp euclidean_distance(a, b) do
    diff = a - b
    Nx.sqrt(Nx.sum(diff * diff))
  end

  defnp cosine_distance(a, b) do
    norm_a = Nx.sqrt(Nx.sum(a * a))
    norm_b = Nx.sqrt(Nx.sum(b * b))
    dot = Nx.sum(a * b)
    1.0 - dot / (norm_a * norm_b)
  end

  defnp manhattan_distance(a, b) do
    Nx.sum(Nx.abs(a - b))
  end

  defnp chebyshev_distance(a, b) do
    Nx.reduce_max(Nx.abs(a - b))
  end
end
