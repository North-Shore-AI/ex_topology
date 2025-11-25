defmodule ExTopology.StatisticsTest do
  use ExUnit.Case, async: true
  doctest ExTopology.Statistics

  alias ExTopology.Statistics

  describe "pearson/2" do
    test "perfect positive correlation" do
      x = Nx.tensor([1.0, 2.0, 3.0, 4.0, 5.0])
      y = Nx.tensor([2.0, 4.0, 6.0, 8.0, 10.0])

      r = Statistics.pearson(x, y) |> Nx.to_number()
      assert_in_delta(r, 1.0, 0.0001)
    end

    test "perfect negative correlation" do
      x = Nx.tensor([1.0, 2.0, 3.0, 4.0, 5.0])
      y = Nx.tensor([5.0, 4.0, 3.0, 2.0, 1.0])

      r = Statistics.pearson(x, y) |> Nx.to_number()
      assert_in_delta(r, -1.0, 0.0001)
    end

    test "no correlation" do
      x = Nx.tensor([1.0, 2.0, 3.0, 4.0, 5.0])
      y = Nx.tensor([3.0, 3.0, 3.0, 3.0, 3.0])

      r = Statistics.pearson(x, y) |> Nx.to_number()
      # Constant y has std=0, so correlation is undefined/0
      assert is_number(r)
    end

    test "accepts list input" do
      x = [1.0, 2.0, 3.0, 4.0, 5.0]
      y = [2.0, 4.0, 6.0, 8.0, 10.0]

      r = Statistics.pearson(x, y) |> Nx.to_number()
      assert_in_delta(r, 1.0, 0.0001)
    end
  end

  describe "spearman/2" do
    test "perfect monotonic relationship" do
      x = [1, 2, 3, 4, 5]
      y = [1, 4, 9, 16, 25]

      r = Statistics.spearman(x, y) |> Nx.to_number()
      assert_in_delta(r, 1.0, 0.0001)
    end

    test "perfect negative monotonic relationship" do
      x = [1, 2, 3, 4, 5]
      y = [5, 4, 3, 2, 1]

      r = Statistics.spearman(x, y) |> Nx.to_number()
      assert_in_delta(r, -1.0, 0.0001)
    end

    test "handles ties correctly" do
      x = [1, 2, 2, 4, 5]
      y = [1, 2, 3, 4, 5]

      r = Statistics.spearman(x, y) |> Nx.to_number()
      # Should still be close to 1 despite tie
      assert r > 0.9
    end
  end

  describe "correlation/3" do
    test "defaults to pearson" do
      x = Nx.tensor([1.0, 2.0, 3.0])
      y = Nx.tensor([2.0, 4.0, 6.0])

      default = Statistics.correlation(x, y) |> Nx.to_number()
      pearson = Statistics.correlation(x, y, method: :pearson) |> Nx.to_number()

      assert_in_delta(default, pearson, 0.0001)
    end

    test "spearman method" do
      x = [1, 2, 3, 4, 5]
      y = [1, 4, 9, 16, 25]

      r = Statistics.correlation(x, y, method: :spearman) |> Nx.to_number()
      assert_in_delta(r, 1.0, 0.0001)
    end
  end

  describe "correlation_matrix/1" do
    test "creates square correlation matrix" do
      # 4 observations, 3 variables
      data =
        Nx.tensor([
          [1.0, 2.0, 3.0],
          [2.0, 4.0, 6.0],
          [3.0, 6.0, 9.0],
          [4.0, 8.0, 12.0]
        ])

      corr = Statistics.correlation_matrix(data)

      assert Nx.shape(corr) == {3, 3}
    end

    test "diagonal is 1" do
      data =
        Nx.tensor([
          [1.0, 2.0],
          [2.0, 4.0],
          [3.0, 6.0]
        ])

      corr = Statistics.correlation_matrix(data)

      assert_in_delta(Nx.to_number(corr[0][0]), 1.0, 0.0001)
      assert_in_delta(Nx.to_number(corr[1][1]), 1.0, 0.0001)
    end

    test "matrix is symmetric" do
      data =
        Nx.tensor([
          [1.0, 2.0, 3.0],
          [2.0, 5.0, 4.0],
          [3.0, 3.0, 5.0],
          [4.0, 7.0, 6.0]
        ])

      corr = Statistics.correlation_matrix(data)

      for i <- 0..2, j <- 0..2 do
        assert_in_delta(Nx.to_number(corr[i][j]), Nx.to_number(corr[j][i]), 0.0001)
      end
    end
  end

  describe "cohens_d/2" do
    test "identical groups have d = 0" do
      g1 = Nx.tensor([1.0, 2.0, 3.0, 4.0, 5.0])
      g2 = Nx.tensor([1.0, 2.0, 3.0, 4.0, 5.0])

      d = Statistics.cohens_d(g1, g2) |> Nx.to_number()
      assert_in_delta(d, 0.0, 0.0001)
    end

    test "group1 > group2 gives positive d" do
      g1 = Nx.tensor([5.0, 6.0, 7.0, 8.0, 9.0])
      g2 = Nx.tensor([1.0, 2.0, 3.0, 4.0, 5.0])

      d = Statistics.cohens_d(g1, g2) |> Nx.to_number()
      assert d > 0
    end

    test "group1 < group2 gives negative d" do
      g1 = Nx.tensor([1.0, 2.0, 3.0, 4.0, 5.0])
      g2 = Nx.tensor([5.0, 6.0, 7.0, 8.0, 9.0])

      d = Statistics.cohens_d(g1, g2) |> Nx.to_number()
      assert d < 0
    end

    test "large effect size" do
      g1 = Nx.tensor([10.0, 11.0, 12.0, 13.0, 14.0])
      g2 = Nx.tensor([1.0, 2.0, 3.0, 4.0, 5.0])

      d = Statistics.cohens_d(g1, g2) |> Nx.to_number()
      # Large effect: |d| >= 0.8
      assert abs(d) >= 0.8
    end
  end

  describe "coefficient_of_variation/2" do
    test "returns positive value for positive data" do
      x = Nx.tensor([10.0, 12.0, 11.0, 13.0, 9.0])
      cv = Statistics.coefficient_of_variation(x) |> Nx.to_number()

      assert cv > 0
    end

    test "as_percent option" do
      x = Nx.tensor([10.0, 12.0, 11.0, 13.0, 9.0])
      cv_ratio = Statistics.coefficient_of_variation(x) |> Nx.to_number()
      cv_percent = Statistics.coefficient_of_variation(x, as_percent: true) |> Nx.to_number()

      assert_in_delta(cv_percent, cv_ratio * 100, 0.01)
    end

    test "constant values have cv = 0" do
      x = Nx.tensor([5.0, 5.0, 5.0, 5.0, 5.0])
      cv = Statistics.coefficient_of_variation(x) |> Nx.to_number()

      assert_in_delta(cv, 0.0, 0.0001)
    end
  end

  describe "z_scores/1" do
    test "z-scores have mean 0" do
      x = Nx.tensor([1.0, 2.0, 3.0, 4.0, 5.0])
      z = Statistics.z_scores(x)

      mean = Nx.mean(z) |> Nx.to_number()
      assert_in_delta(mean, 0.0, 0.0001)
    end

    test "z-scores have std 1" do
      x = Nx.tensor([1.0, 2.0, 3.0, 4.0, 5.0])
      z = Statistics.z_scores(x)

      std = Nx.standard_deviation(z) |> Nx.to_number()
      assert_in_delta(std, 1.0, 0.0001)
    end

    test "preserves shape" do
      x = Nx.tensor([1.0, 2.0, 3.0, 4.0, 5.0])
      z = Statistics.z_scores(x)

      assert Nx.shape(z) == Nx.shape(x)
    end
  end

  describe "iqr/1" do
    test "computes interquartile range" do
      x = Nx.tensor([1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0])
      iqr = Statistics.iqr(x) |> Nx.to_number()

      # Q3 - Q1 for 1-10 is approximately 7.5 - 2.5 = 5
      # (depends on percentile calculation method)
      assert iqr > 0
    end

    test "accepts list input" do
      x = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
      iqr = Statistics.iqr(x) |> Nx.to_number()

      assert iqr > 0
    end
  end

  describe "summary/1" do
    test "returns all statistics" do
      x = [1, 2, 3, 4, 5]
      stats = Statistics.summary(x)

      assert stats.count == 5
      assert stats.min == 1
      assert stats.max == 5
      assert stats.median == 3
      assert_in_delta(stats.mean, 3.0, 0.0001)
      assert Map.has_key?(stats, :std)
      assert Map.has_key?(stats, :q1)
      assert Map.has_key?(stats, :q3)
    end

    test "handles tensor input" do
      x = Nx.tensor([1.0, 2.0, 3.0, 4.0, 5.0])
      stats = Statistics.summary(x)

      assert stats.count == 5
    end
  end
end
