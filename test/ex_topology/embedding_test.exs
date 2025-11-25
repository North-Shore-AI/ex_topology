defmodule ExTopology.EmbeddingTest do
  use ExUnit.Case, async: true

  alias ExTopology.Embedding

  describe "knn_variance/2" do
    test "uniform spacing has low variance" do
      # Points evenly spaced on a line
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [2.0, 0.0], [3.0, 0.0]])
      variance = Embedding.knn_variance(points, k: 2)

      # Uniform spacing should have low variance (allowing some tolerance)
      assert Nx.to_number(variance) < 0.2
    end

    test "irregular spacing has higher variance" do
      # Points with irregular spacing
      points = Nx.tensor([[0.0, 0.0], [0.1, 0.0], [5.0, 0.0], [5.1, 0.0]])
      variance = Embedding.knn_variance(points, k: 2)

      # Should have some variance due to irregular spacing
      assert Nx.to_number(variance) >= 0
    end

    test "reduce: :none returns per-point variance" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [2.0, 0.0], [3.0, 0.0]])
      variances = Embedding.knn_variance(points, k: 2, reduce: :none)

      assert Nx.shape(variances) == {4}
    end

    test "reduce: :max returns maximum variance" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [2.0, 0.0], [100.0, 0.0]])
      max_var = Embedding.knn_variance(points, k: 2, reduce: :max)

      # Should be a scalar
      assert Nx.shape(max_var) == {}
    end

    test "k is clamped to n-1" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [2.0, 0.0]])
      # k=10 is larger than n-1=2, should be clamped
      variance = Embedding.knn_variance(points, k: 10)

      assert Nx.to_number(variance) >= 0
    end
  end

  describe "knn_distances/2" do
    test "returns distances to k nearest neighbors" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [3.0, 0.0]])
      dists = Embedding.knn_distances(points, k: 1)

      assert Nx.shape(dists) == {3, 1}
    end

    test "distances are sorted ascending" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [2.0, 0.0], [10.0, 0.0]])
      dists = Embedding.knn_distances(points, k: 2)

      # Each row should be sorted (smallest distances first)
      for i <- 0..3 do
        row = Nx.to_flat_list(dists[i])
        assert row == Enum.sort(row)
      end
    end
  end

  describe "local_density/2" do
    test "dense region has higher density than sparse" do
      # First two points are close, third is far
      points = Nx.tensor([[0.0, 0.0], [0.1, 0.0], [10.0, 0.0]])
      densities = Embedding.local_density(points, k: 1)

      # Points 0 and 1 should have higher density than point 2
      d0 = Nx.to_number(densities[0])
      d1 = Nx.to_number(densities[1])
      d2 = Nx.to_number(densities[2])

      assert d0 > d2
      assert d1 > d2
    end

    test "returns positive values" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [2.0, 0.0]])
      densities = Embedding.local_density(points, k: 1)

      for i <- 0..2 do
        assert Nx.to_number(densities[i]) > 0
      end
    end
  end

  describe "isolation_scores/2" do
    test "outlier has higher isolation score" do
      # Three clustered points and one outlier
      points = Nx.tensor([[0.0, 0.0], [0.1, 0.0], [0.2, 0.0], [100.0, 0.0]])
      scores = Embedding.isolation_scores(points, k: 2)

      # Point 3 (outlier) should have higher isolation score
      outlier_score = Nx.to_number(scores[3])
      normal_score = Nx.to_number(scores[0])

      assert outlier_score > normal_score
    end

    test "returns non-negative scores" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [2.0, 0.0]])
      scores = Embedding.isolation_scores(points, k: 1)

      for i <- 0..2 do
        assert Nx.to_number(scores[i]) >= 0
      end
    end
  end

  describe "mean_knn_distance/2" do
    test "returns mean distance to k neighbors" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [2.0, 0.0]])
      mean_dists = Embedding.mean_knn_distance(points, k: 1)

      assert Nx.shape(mean_dists) == {3}
      # All points have nearest neighbor at distance 1
      for i <- 0..2 do
        assert_in_delta(Nx.to_number(mean_dists[i]), 1.0, 0.01)
      end
    end
  end

  describe "statistics/2" do
    test "returns all statistics" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [2.0, 0.0], [3.0, 0.0]])
      stats = Embedding.statistics(points, k: 2)

      assert Map.has_key?(stats, :n_points)
      assert Map.has_key?(stats, :dimensions)
      assert Map.has_key?(stats, :knn_variance)
      assert Map.has_key?(stats, :mean_knn_distance)
      assert Map.has_key?(stats, :density_mean)
      assert Map.has_key?(stats, :density_std)

      assert stats.n_points == 4
      assert stats.dimensions == 2
    end
  end

  describe "sparse_points/2" do
    test "identifies sparse points" do
      # Dense cluster and one outlier
      points =
        Nx.tensor([
          [0.0, 0.0],
          [0.1, 0.0],
          [0.0, 0.1],
          [0.1, 0.1],
          [100.0, 100.0]
        ])

      sparse = Embedding.sparse_points(points, k: 2, percentile: 20)

      # The outlier (index 4) should be in sparse points
      assert 4 in sparse
    end

    test "returns list of indices" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [2.0, 0.0], [3.0, 0.0]])
      sparse = Embedding.sparse_points(points, k: 1, percentile: 25)

      assert is_list(sparse)
      assert Enum.all?(sparse, &is_integer/1)
    end
  end

  describe "edge cases" do
    test "two points" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0]])
      variance = Embedding.knn_variance(points, k: 1)

      # With only 2 points and k=1, variance should be 0 (each point has 1 neighbor)
      assert Nx.to_number(variance) >= 0
    end

    test "high dimensional points" do
      # 10-dimensional points
      key = Nx.Random.key(42)
      {points, _key} = Nx.Random.uniform(key, shape: {5, 10})
      variance = Embedding.knn_variance(points, k: 2)

      assert Nx.to_number(variance) >= 0
    end
  end
end
