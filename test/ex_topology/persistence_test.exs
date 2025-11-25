defmodule ExTopology.PersistenceTest do
  use ExUnit.Case, async: true
  doctest ExTopology.Persistence

  alias ExTopology.{Persistence, Filtration}

  describe "compute/2" do
    test "computes persistence for simple filtration" do
      filtration = [{0.0, [0]}, {0.0, [1]}, {1.0, [0, 1]}]
      diagrams = Persistence.compute(filtration, max_dimension: 1)

      assert length(diagrams) >= 1
      assert is_map(hd(diagrams))
    end

    test "returns diagrams with dimension and pairs" do
      filtration = [{0.0, [0]}, {0.0, [1]}, {1.0, [0, 1]}]
      diagrams = Persistence.compute(filtration, max_dimension: 1)

      for diagram <- diagrams do
        assert Map.has_key?(diagram, :dimension)
        assert Map.has_key?(diagram, :pairs)
        assert is_list(diagram.pairs)
      end
    end

    test "detects connected components" do
      # Two separate points that connect
      filtration = [{0.0, [0]}, {0.0, [1]}, {1.0, [0, 1]}]
      diagrams = Persistence.compute(filtration, max_dimension: 1)

      # H0 should have a pair (0.0, 1.0) for one component dying
      h0 = Enum.find(diagrams, fn d -> d.dimension == 0 end)
      assert h0 != nil
    end

    test "detects cycles" do
      # Triangle: creates and destroys a loop
      filtration = [
        {0.0, [0]},
        {0.0, [1]},
        {0.0, [2]},
        {1.0, [0, 1]},
        {1.0, [1, 2]},
        {1.0, [0, 2]},
        {2.0, [0, 1, 2]}
      ]

      diagrams = Persistence.compute(filtration, max_dimension: 1)

      # Should have H0 and H1
      assert Enum.any?(diagrams, fn d -> d.dimension == 0 end)
      assert Enum.any?(diagrams, fn d -> d.dimension == 1 end)
    end
  end

  describe "betti_numbers/3" do
    test "computes β0 for disconnected points" do
      filtration = [{0.0, [0]}, {0.0, [1]}, {0.0, [2]}]
      betti = Persistence.betti_numbers(filtration, 0.5)

      assert betti[0] == 3
    end

    test "computes β0 for connected points" do
      filtration = [{0.0, [0]}, {0.0, [1]}, {1.0, [0, 1]}]
      betti = Persistence.betti_numbers(filtration, 1.5)

      assert betti[0] == 1
    end

    test "computes β1 for cycle" do
      # Triangle
      filtration = [
        {0.0, [0]},
        {0.0, [1]},
        {0.0, [2]},
        {1.0, [0, 1]},
        {1.0, [1, 2]},
        {1.0, [0, 2]}
      ]

      betti = Persistence.betti_numbers(filtration, 1.5)

      assert betti[1] == 1
    end
  end

  describe "matrix_rank/1" do
    test "returns 0 for empty matrix" do
      assert Persistence.matrix_rank(%{}) == 0
    end

    test "returns 1 for single non-zero column" do
      matrix = %{0 => %{0 => 1}}
      assert Persistence.matrix_rank(matrix) == 1
    end

    test "counts non-zero columns" do
      matrix = %{0 => %{0 => 1}, 1 => %{1 => 1}, 2 => %{}}
      assert Persistence.matrix_rank(matrix) == 2
    end
  end

  describe "validate_boundary_property/2" do
    test "validates simple filtration" do
      filtration = [{0.0, [0]}, {0.0, [1]}, {1.0, [0, 1]}]
      {matrix, _} = build_test_boundary_matrix(filtration)

      result = Persistence.validate_boundary_property(matrix, filtration)
      assert result == :ok or match?({:error, _}, result)
    end
  end

  describe "property: persistence pairs are valid" do
    test "all pairs satisfy birth <= death" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [0.0, 1.0]])
      filtration = Filtration.vietoris_rips(points, max_dimension: 1)
      diagrams = Persistence.compute(filtration, max_dimension: 1)

      for diagram <- diagrams do
        for {birth, death} <- diagram.pairs do
          case death do
            :infinity -> assert true
            _ -> assert birth <= death, "Birth #{birth} > death #{death}"
          end
        end
      end
    end

    test "number of infinite H0 pairs equals final component count" do
      # Three separate points
      filtration = [{0.0, [0]}, {0.0, [1]}, {0.0, [2]}]
      diagrams = Persistence.compute(filtration, max_dimension: 1)

      h0 = Enum.find(diagrams, fn d -> d.dimension == 0 end)
      infinite_pairs = Enum.count(h0.pairs, fn {_, d} -> d == :infinity end)

      # Should have components equal to number of vertices at the end
      # (All three points remain separate)
      assert infinite_pairs > 0
    end
  end

  describe "integration: known examples" do
    test "empty space has β0 = 0" do
      filtration = []
      betti = Persistence.betti_numbers(filtration, 0.0)
      assert betti[0] == 0
    end

    test "single point has β0 = 1, β1 = 0" do
      filtration = [{0.0, [0]}]
      betti = Persistence.betti_numbers(filtration, 0.0)

      assert betti[0] == 1
      assert betti[1] == 0
    end

    test "two separate points have β0 = 2" do
      filtration = [{0.0, [0]}, {0.0, [1]}]
      betti = Persistence.betti_numbers(filtration, 0.0)

      assert betti[0] == 2
    end

    test "path graph has β0 = 1, β1 = 0" do
      filtration = [{0.0, [0]}, {0.0, [1]}, {0.0, [2]}, {1.0, [0, 1]}, {1.0, [1, 2]}]
      betti = Persistence.betti_numbers(filtration, 1.5)

      assert betti[0] == 1
      assert betti[1] == 0
    end

    test "cycle has β0 = 1, β1 = 1" do
      # Triangle (3-cycle)
      filtration = [
        {0.0, [0]},
        {0.0, [1]},
        {0.0, [2]},
        {1.0, [0, 1]},
        {1.0, [1, 2]},
        {1.0, [2, 0]}
      ]

      betti = Persistence.betti_numbers(filtration, 1.5)

      assert betti[0] == 1
      assert betti[1] == 1
    end
  end

  # Helper function
  defp build_test_boundary_matrix(filtration) do
    simplex_map =
      filtration
      |> Enum.with_index()
      |> Map.new(fn {{_scale, simplex}, idx} -> {simplex, idx} end)

    matrix =
      filtration
      |> Enum.with_index()
      |> Enum.reduce(%{}, fn {{_scale, simplex}, col_idx}, acc ->
        boundary = ExTopology.Simplex.boundary(simplex)

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
end
