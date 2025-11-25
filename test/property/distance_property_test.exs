defmodule ExTopology.Property.DistancePropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias ExTopology.Distance

  @moduletag :property

  describe "Distance matrix properties" do
    property "euclidean distance matrix is symmetric" do
      check all(points <- points_generator(2..20, 2..5)) do
        dists = Distance.euclidean_matrix(points)

        {n, _} = Nx.shape(points)

        for i <- 0..(n - 1), j <- 0..(n - 1) do
          d_ij = Nx.to_number(dists[i][j])
          d_ji = Nx.to_number(dists[j][i])
          assert_in_delta(d_ij, d_ji, 1.0e-5, "Matrix not symmetric at (#{i},#{j})")
        end
      end
    end

    property "euclidean distance diagonal is zero" do
      check all(points <- points_generator(2..10, 2..5)) do
        dists = Distance.euclidean_matrix(points)
        {n, _} = Nx.shape(points)

        for i <- 0..(n - 1) do
          d_ii = Nx.to_number(dists[i][i])
          assert abs(d_ii) < 1.0e-5, "Diagonal not zero at #{i}: #{d_ii}"
        end
      end
    end

    property "euclidean distances are non-negative" do
      check all(points <- points_generator(2..10, 2..5)) do
        dists = Distance.euclidean_matrix(points)
        min_dist = Nx.to_number(Nx.reduce_min(dists))
        assert min_dist >= -1.0e-5, "Found negative distance: #{min_dist}"
      end
    end

    property "triangle inequality holds for euclidean distance" do
      check all(points <- points_generator(3..8, 2..4)) do
        dists = Distance.euclidean_matrix(points)
        {n, _} = Nx.shape(points)

        # Check a sample of triangles
        for _ <- 1..min(20, n * n) do
          [i, j, k] = Enum.take_random(0..(n - 1), 3) |> Enum.uniq() |> Enum.take(3)

          if length([i, j, k] |> Enum.uniq()) == 3 do
            d_ij = Nx.to_number(dists[i][j])
            d_jk = Nx.to_number(dists[j][k])
            d_ik = Nx.to_number(dists[i][k])

            assert d_ik <= d_ij + d_jk + 1.0e-5,
                   "Triangle inequality violated: d(#{i},#{k})=#{d_ik} > d(#{i},#{j})+d(#{j},#{k})=#{d_ij + d_jk}"
          end
        end
      end
    end
  end

  describe "Manhattan distance properties" do
    property "manhattan distance matrix is symmetric" do
      check all(points <- points_generator(2..10, 2..4)) do
        dists = Distance.manhattan_matrix(points)
        {n, _} = Nx.shape(points)

        for i <- 0..(n - 1), j <- i..(n - 1) do
          d_ij = Nx.to_number(dists[i][j])
          d_ji = Nx.to_number(dists[j][i])
          assert_in_delta(d_ij, d_ji, 1.0e-5)
        end
      end
    end

    property "manhattan distance diagonal is zero" do
      check all(points <- points_generator(2..10, 2..4)) do
        dists = Distance.manhattan_matrix(points)
        diag = Nx.take_diagonal(dists)
        max_diag = Nx.to_number(Nx.reduce_max(Nx.abs(diag)))
        assert max_diag < 1.0e-5
      end
    end
  end

  describe "Cosine distance properties" do
    property "cosine distance is symmetric" do
      check all(points <- points_generator(2..10, 2..4)) do
        # Ensure no zero vectors
        points = Nx.add(points, 0.1)
        dists = Distance.cosine_matrix(points)
        {n, _} = Nx.shape(points)

        for i <- 0..(n - 1), j <- i..(n - 1) do
          d_ij = Nx.to_number(dists[i][j])
          d_ji = Nx.to_number(dists[j][i])
          assert_in_delta(d_ij, d_ji, 1.0e-4)
        end
      end
    end

    property "cosine distance is in [0, 2]" do
      check all(points <- points_generator(2..10, 2..4)) do
        # Ensure no zero vectors
        points = Nx.add(points, 0.1)
        dists = Distance.cosine_matrix(points)

        min_dist = Nx.to_number(Nx.reduce_min(dists))
        max_dist = Nx.to_number(Nx.reduce_max(dists))

        assert min_dist >= -1.0e-4, "Cosine distance below 0: #{min_dist}"
        assert max_dist <= 2.0 + 1.0e-4, "Cosine distance above 2: #{max_dist}"
      end
    end
  end

  describe "Squared euclidean properties" do
    property "squared euclidean equals euclidean squared" do
      check all(points <- points_generator(2..8, 2..4)) do
        euclidean = Distance.euclidean_matrix(points)
        squared = Distance.squared_euclidean_matrix(points)

        expected_squared = Nx.pow(euclidean, 2)

        max_diff =
          Nx.subtract(squared, expected_squared)
          |> Nx.abs()
          |> Nx.reduce_max()
          |> Nx.to_number()

        assert max_diff < 1.0e-3,
               "Squared euclidean doesn't match euclidean^2, max diff: #{max_diff}"
      end
    end
  end

  describe "Minkowski distance properties" do
    property "minkowski p=2 equals euclidean" do
      check all(points <- points_generator(2..8, 2..4)) do
        euclidean = Distance.euclidean_matrix(points)
        minkowski = Distance.minkowski_matrix(points, 2)

        max_diff =
          Nx.subtract(euclidean, minkowski)
          |> Nx.abs()
          |> Nx.reduce_max()
          |> Nx.to_number()

        assert max_diff < 1.0e-4,
               "Minkowski p=2 doesn't match euclidean, max diff: #{max_diff}"
      end
    end

    property "minkowski p=1 equals manhattan" do
      check all(points <- points_generator(2..8, 2..4)) do
        manhattan = Distance.manhattan_matrix(points)
        minkowski = Distance.minkowski_matrix(points, 1)

        max_diff =
          Nx.subtract(manhattan, minkowski)
          |> Nx.abs()
          |> Nx.reduce_max()
          |> Nx.to_number()

        assert max_diff < 1.0e-4,
               "Minkowski p=1 doesn't match manhattan, max diff: #{max_diff}"
      end
    end
  end

  # Generators

  defp points_generator(n_range, d_range) do
    gen all(
          n <- integer(n_range),
          d <- integer(d_range),
          values <- list_of(float(min: -10.0, max: 10.0), length: n * d)
        ) do
      Nx.tensor(values) |> Nx.reshape({n, d})
    end
  end
end
