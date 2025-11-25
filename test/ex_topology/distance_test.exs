defmodule ExTopology.DistanceTest do
  use ExUnit.Case, async: true
  doctest ExTopology.Distance

  alias ExTopology.Distance

  describe "euclidean_matrix/1" do
    test "computes correct distances for 2D points" do
      points = Nx.tensor([[0.0, 0.0], [3.0, 4.0]])
      dists = Distance.euclidean_matrix(points)

      assert Nx.shape(dists) == {2, 2}
      assert_close(dists[0][0], 0.0)
      assert_close(dists[0][1], 5.0)
      assert_close(dists[1][0], 5.0)
      assert_close(dists[1][1], 0.0)
    end

    test "computes correct distances for 1D points" do
      points = Nx.tensor([[0.0], [1.0], [3.0]])
      dists = Distance.euclidean_matrix(points)

      assert Nx.shape(dists) == {3, 3}
      assert_close(dists[0][1], 1.0)
      assert_close(dists[0][2], 3.0)
      assert_close(dists[1][2], 2.0)
    end

    test "diagonal is zero" do
      points = Nx.tensor([[1.0, 2.0], [3.0, 4.0], [5.0, 6.0]])
      dists = Distance.euclidean_matrix(points)

      for i <- 0..2 do
        assert_close(dists[i][i], 0.0)
      end
    end

    test "matrix is symmetric" do
      points = Nx.tensor([[1.0, 2.0], [3.0, 4.0], [5.0, 6.0]])
      dists = Distance.euclidean_matrix(points)

      for i <- 0..2, j <- 0..2 do
        assert_close(dists[i][j], dists[j][i])
      end
    end
  end

  describe "cosine_matrix/1" do
    test "identical vectors have distance 0" do
      points = Nx.tensor([[1.0, 0.0], [2.0, 0.0]])
      dists = Distance.cosine_matrix(points)

      assert_close(dists[0][1], 0.0)
    end

    test "orthogonal vectors have distance 1" do
      points = Nx.tensor([[1.0, 0.0], [0.0, 1.0]])
      dists = Distance.cosine_matrix(points)

      assert_close(dists[0][1], 1.0)
    end

    test "opposite vectors have distance 2" do
      points = Nx.tensor([[1.0, 0.0], [-1.0, 0.0]])
      dists = Distance.cosine_matrix(points)

      assert_close(dists[0][1], 2.0)
    end

    test "diagonal is zero" do
      points = Nx.tensor([[1.0, 2.0], [3.0, 4.0]])
      dists = Distance.cosine_matrix(points)

      assert_close(dists[0][0], 0.0)
      assert_close(dists[1][1], 0.0)
    end
  end

  describe "manhattan_matrix/1" do
    test "computes correct L1 distances" do
      points = Nx.tensor([[0.0, 0.0], [3.0, 4.0]])
      dists = Distance.manhattan_matrix(points)

      # L1 distance: |3-0| + |4-0| = 7
      assert_close(dists[0][1], 7.0)
    end

    test "diagonal is zero" do
      points = Nx.tensor([[1.0, 2.0], [3.0, 4.0]])
      dists = Distance.manhattan_matrix(points)

      assert_close(dists[0][0], 0.0)
      assert_close(dists[1][1], 0.0)
    end
  end

  describe "chebyshev_matrix/1" do
    test "computes correct L-infinity distances" do
      points = Nx.tensor([[0.0, 0.0], [3.0, 4.0]])
      dists = Distance.chebyshev_matrix(points)

      # L-inf distance: max(|3-0|, |4-0|) = 4
      assert_close(dists[0][1], 4.0)
    end

    test "diagonal is zero" do
      points = Nx.tensor([[1.0, 2.0], [3.0, 4.0]])
      dists = Distance.chebyshev_matrix(points)

      assert_close(dists[0][0], 0.0)
    end
  end

  describe "minkowski_matrix/2" do
    test "p=2 equals euclidean" do
      points = Nx.tensor([[0.0, 0.0], [3.0, 4.0]])
      minkowski = Distance.minkowski_matrix(points, 2)
      euclidean = Distance.euclidean_matrix(points)

      assert_close(minkowski[0][1], euclidean[0][1])
    end

    test "p=1 equals manhattan" do
      points = Nx.tensor([[0.0, 0.0], [3.0, 4.0]])
      minkowski = Distance.minkowski_matrix(points, 1)
      manhattan = Distance.manhattan_matrix(points)

      assert_close(minkowski[0][1], manhattan[0][1])
    end
  end

  describe "squared_euclidean_matrix/1" do
    test "is square of euclidean distance" do
      points = Nx.tensor([[0.0, 0.0], [3.0, 4.0]])
      squared = Distance.squared_euclidean_matrix(points)

      # 5^2 = 25
      assert_close(squared[0][1], 25.0)
    end
  end

  describe "distance/3" do
    test "euclidean distance between two points" do
      a = Nx.tensor([0.0, 0.0])
      b = Nx.tensor([3.0, 4.0])

      assert_close(Distance.distance(a, b), 5.0)
    end

    test "manhattan distance between two points" do
      a = Nx.tensor([0.0, 0.0])
      b = Nx.tensor([3.0, 4.0])

      assert_close(Distance.distance(a, b, metric: :manhattan), 7.0)
    end

    test "chebyshev distance between two points" do
      a = Nx.tensor([0.0, 0.0])
      b = Nx.tensor([3.0, 4.0])

      assert_close(Distance.distance(a, b, metric: :chebyshev), 4.0)
    end
  end

  describe "pairwise/2" do
    test "with euclidean metric" do
      points = Nx.tensor([[0.0, 0.0], [3.0, 4.0]])
      dists = Distance.pairwise(points, metric: :euclidean)

      assert_close(dists[0][1], 5.0)
    end

    test "with manhattan metric" do
      points = Nx.tensor([[0.0, 0.0], [3.0, 4.0]])
      dists = Distance.pairwise(points, metric: :manhattan)

      assert_close(dists[0][1], 7.0)
    end

    test "with squared_euclidean metric" do
      points = Nx.tensor([[0.0, 0.0], [3.0, 4.0]])
      dists = Distance.pairwise(points, metric: :squared_euclidean)

      assert_close(dists[0][1], 25.0)
    end

    test "with minkowski metric" do
      points = Nx.tensor([[0.0, 0.0], [3.0, 4.0]])
      dists = Distance.pairwise(points, metric: {:minkowski, 2})

      assert_close(dists[0][1], 5.0)
    end
  end

  # Helper to assert tensor values are close
  defp assert_close(tensor, expected, tolerance \\ 1.0e-5) do
    actual = Nx.to_number(tensor)
    expected_num = if is_struct(expected, Nx.Tensor), do: Nx.to_number(expected), else: expected
    assert abs(actual - expected_num) < tolerance, "Expected #{expected_num}, got #{actual}"
  end
end
