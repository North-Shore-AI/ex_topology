defmodule ExTopology.FiltrationTest do
  use ExUnit.Case, async: true
  doctest ExTopology.Filtration

  alias ExTopology.Filtration

  describe "vietoris_rips/2" do
    test "creates filtration for three points" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [0.0, 1.0]])
      filtration = Filtration.vietoris_rips(points, max_dimension: 1)

      # Should have vertices and edges
      assert length(filtration) > 0

      # Vertices should appear at time 0
      vertices =
        Enum.filter(filtration, fn {scale, simplex} -> scale == 0.0 and length(simplex) == 1 end)

      assert length(vertices) == 3
    end

    test "respects max_dimension" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [0.0, 1.0]])
      filtration = Filtration.vietoris_rips(points, max_dimension: 0)

      # Should only have 0-simplices
      assert Enum.all?(filtration, fn {_scale, simplex} -> length(simplex) == 1 end)
    end

    test "filtration is ordered by scale" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [2.0, 0.0]])
      filtration = Filtration.vietoris_rips(points, max_dimension: 1)

      scales = Enum.map(filtration, fn {scale, _} -> scale end)
      assert scales == Enum.sort(scales)
    end
  end

  describe "complex_at/2" do
    test "extracts complex at specific epsilon" do
      filtration = [{0.0, [0]}, {0.0, [1]}, {1.0, [0, 1]}]
      complex = Filtration.complex_at(filtration, 0.5)

      assert Map.keys(complex) == [0]
      assert length(complex[0]) == 2
    end

    test "includes all simplices up to epsilon" do
      filtration = [{0.0, [0]}, {0.0, [1]}, {1.0, [0, 1]}, {2.0, [0, 1, 2]}]
      complex = Filtration.complex_at(filtration, 1.5)

      assert Map.has_key?(complex, 0)
      assert Map.has_key?(complex, 1)
      assert length(complex[0]) == 2
      assert length(complex[1]) == 1
    end
  end

  describe "critical_values/1" do
    test "returns unique scale values" do
      filtration = [{0.0, [0]}, {1.0, [1]}, {1.0, [0, 1]}, {2.0, [0, 1, 2]}]
      values = Filtration.critical_values(filtration)

      assert values == [0.0, 1.0, 2.0]
    end

    test "returns sorted values" do
      filtration = [{2.0, [0]}, {0.0, [1]}, {1.0, [0, 1]}]
      values = Filtration.critical_values(filtration)

      assert values == [0.0, 1.0, 2.0]
    end
  end

  describe "from_graph/2" do
    test "builds filtration from weighted graph" do
      g =
        Graph.new()
        |> Graph.add_edge(0, 1, weight: 1.0)
        |> Graph.add_edge(1, 2, weight: 1.5)

      filtration = Filtration.from_graph(g, max_dimension: 1)

      # Should have vertices and edges
      vertices = Enum.filter(filtration, fn {_scale, s} -> length(s) == 1 end)
      edges = Enum.filter(filtration, fn {_scale, s} -> length(s) == 2 end)

      assert length(vertices) >= 2
      assert length(edges) >= 2
    end

    test "vertices appear at time 0" do
      g = Graph.new() |> Graph.add_edge(0, 1, weight: 1.0)
      filtration = Filtration.from_graph(g)

      vertices = Enum.filter(filtration, fn {scale, s} -> scale == 0.0 and length(s) == 1 end)
      assert length(vertices) >= 2
    end
  end

  describe "validate/1" do
    test "accepts valid filtration" do
      valid = [{0.0, [0]}, {0.0, [1]}, {1.0, [0, 1]}]
      assert Filtration.validate(valid) == :ok
    end

    test "rejects unordered filtration" do
      invalid = [{1.0, [0, 1]}, {0.0, [0]}]
      assert {:error, _} = Filtration.validate(invalid)
    end

    test "rejects filtration with missing faces" do
      # Edge appears before its vertices
      invalid = [{0.0, [0, 1]}, {1.0, [0]}]
      assert {:error, msg} = Filtration.validate(invalid)
      assert msg =~ "appears before its face"
    end

    test "accepts filtration where faces appear simultaneously" do
      valid = [{0.0, [0]}, {0.0, [1]}, {0.0, [0, 1]}]
      assert Filtration.validate(valid) == :ok
    end
  end

  describe "property: filtration ordering" do
    test "all simplices have faces that appear earlier or simultaneously" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [0.0, 1.0], [1.0, 1.0]])
      filtration = Filtration.vietoris_rips(points, max_dimension: 2)

      # Build map of simplex to birth time
      birth_times =
        filtration
        |> Enum.map(fn {scale, simplex} -> {simplex, scale} end)
        |> Map.new()

      # Check each simplex
      for {scale, simplex} <- filtration do
        faces = ExTopology.Simplex.faces(simplex)

        for face <- faces do
          face_birth = Map.get(birth_times, face)

          if face_birth do
            assert face_birth <= scale,
                   "Face #{inspect(face)} appears at #{face_birth} after simplex #{inspect(simplex)} at #{scale}"
          end
        end
      end
    end
  end
end
