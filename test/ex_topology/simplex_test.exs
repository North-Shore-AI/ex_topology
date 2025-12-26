defmodule ExTopology.SimplexTest do
  use ExUnit.Case, async: true
  doctest ExTopology.Simplex

  alias ExTopology.Simplex

  describe "dimension/1" do
    test "returns -1 for empty simplex" do
      assert Simplex.dimension([]) == -1
    end

    test "returns 0 for point" do
      assert Simplex.dimension([0]) == 0
    end

    test "returns 1 for edge" do
      assert Simplex.dimension([0, 1]) == 1
    end

    test "returns 2 for triangle" do
      assert Simplex.dimension([0, 1, 2]) == 2
    end

    test "returns 3 for tetrahedron" do
      assert Simplex.dimension([0, 1, 2, 3]) == 3
    end
  end

  describe "normalize/1" do
    test "sorts vertices" do
      assert Simplex.normalize([2, 0, 1]) == [0, 1, 2]
    end

    test "removes duplicates" do
      assert Simplex.normalize([1, 2, 1, 3]) == [1, 2, 3]
    end

    test "handles already normalized simplex" do
      assert Simplex.normalize([0, 1, 2]) == [0, 1, 2]
    end
  end

  describe "faces/1" do
    test "returns empty list for empty simplex" do
      assert Simplex.faces([]) == []
    end

    test "returns single face for edge" do
      faces = Simplex.faces([0, 1])
      assert length(faces) == 2
      assert [1] in faces
      assert [0] in faces
    end

    test "returns three faces for triangle" do
      faces = Simplex.faces([0, 1, 2])
      assert length(faces) == 3
      assert [1, 2] in faces
      assert [0, 2] in faces
      assert [0, 1] in faces
    end

    test "returns four faces for tetrahedron" do
      faces = Simplex.faces([0, 1, 2, 3])
      assert length(faces) == 4
      assert [1, 2, 3] in faces
      assert [0, 2, 3] in faces
      assert [0, 1, 3] in faces
      assert [0, 1, 2] in faces
    end
  end

  describe "k_faces/2" do
    test "returns 0-faces (vertices) of triangle" do
      faces = Simplex.k_faces([0, 1, 2], 0)
      assert length(faces) == 3
      assert [0] in faces
      assert [1] in faces
      assert [2] in faces
    end

    test "returns 1-faces (edges) of triangle" do
      faces = Simplex.k_faces([0, 1, 2], 1)
      assert length(faces) == 3
      assert [0, 1] in faces
      assert [0, 2] in faces
      assert [1, 2] in faces
    end

    test "returns 1-faces of tetrahedron" do
      faces = Simplex.k_faces([0, 1, 2, 3], 1)
      assert length(faces) == 6
      assert [0, 1] in faces
      assert [2, 3] in faces
    end
  end

  describe "boundary/1" do
    test "returns empty for empty simplex" do
      assert Simplex.boundary([]) == []
    end

    test "returns signed faces for edge" do
      boundary = Simplex.boundary([0, 1])
      assert length(boundary) == 2
      assert {1, [1]} in boundary
      assert {-1, [0]} in boundary
    end

    test "returns signed faces for triangle with alternating signs" do
      boundary = Simplex.boundary([0, 1, 2])
      assert length(boundary) == 3
      assert {1, [1, 2]} in boundary
      assert {-1, [0, 2]} in boundary
      assert {1, [0, 1]} in boundary
    end

    test "boundary signs alternate correctly" do
      boundary = Simplex.boundary([0, 1, 2, 3])
      signs = Enum.map(boundary, fn {sign, _} -> sign end)
      assert signs == [1, -1, 1, -1]
    end
  end

  describe "face?/2" do
    test "edge is face of triangle" do
      assert Simplex.face?([0, 1], [0, 1, 2])
    end

    test "vertex is face of edge" do
      assert Simplex.face?([0], [0, 1])
    end

    test "non-face returns false" do
      refute Simplex.face?([0, 3], [0, 1, 2])
    end

    test "simplex is face of itself" do
      assert Simplex.face?([0, 1, 2], [0, 1, 2])
    end
  end

  describe "clique_complex/2" do
    test "builds complex from triangle graph" do
      g = Graph.new() |> Graph.add_edges([{0, 1}, {1, 2}, {2, 0}])
      complex = Simplex.clique_complex(g, max_dimension: 2)

      # Should have 3 vertices
      assert length(complex[0]) == 3

      # Should have 3 edges
      assert length(complex[1]) == 3

      # Should have 1 triangle
      assert length(complex[2]) == 1
      assert [0, 1, 2] in complex[2]
    end

    test "builds complex from path graph" do
      g = Graph.new() |> Graph.add_edges([{0, 1}, {1, 2}])
      complex = Simplex.clique_complex(g, max_dimension: 2)

      # Should have 3 vertices
      assert length(complex[0]) == 3

      # Should have 2 edges
      assert length(complex[1]) == 2

      # Should have no triangles
      assert Map.get(complex, 2, []) == []
    end

    test "respects max_dimension" do
      g = Graph.new() |> Graph.add_edges([{0, 1}, {1, 2}, {2, 0}])
      complex = Simplex.clique_complex(g, max_dimension: 1)

      # Should not have dimension 2
      refute Map.has_key?(complex, 2)
    end
  end

  describe "all_simplices/2" do
    test "returns all simplices in complex" do
      complex = %{0 => [[0], [1]], 1 => [[0, 1]]}
      simplices = Simplex.all_simplices(complex)

      assert length(simplices) == 3
      assert [0] in simplices
      assert [1] in simplices
      assert [0, 1] in simplices
    end

    test "respects max_dim parameter" do
      complex = %{0 => [[0]], 1 => [[0, 1]], 2 => [[0, 1, 2]]}
      simplices = Simplex.all_simplices(complex, 1)

      assert length(simplices) == 2
      assert [0] in simplices
      assert [0, 1] in simplices
      refute [0, 1, 2] in simplices
    end
  end

  describe "skeleton/2" do
    test "extracts 1-skeleton" do
      complex = %{0 => [[0]], 1 => [[0, 1]], 2 => [[0, 1, 2]]}
      skeleton = Simplex.skeleton(complex, 1)

      assert Map.keys(skeleton) |> Enum.sort() == [0, 1]
      assert skeleton[0] == [[0]]
      assert skeleton[1] == [[0, 1]]
    end

    test "extracts 0-skeleton (vertices only)" do
      complex = %{0 => [[0], [1]], 1 => [[0, 1]]}
      skeleton = Simplex.skeleton(complex, 0)

      assert Map.keys(skeleton) == [0]
      assert skeleton[0] == [[0], [1]]
    end
  end

  describe "property: boundary of boundary is zero" do
    test "∂∂ = 0 for all simplices up to dimension 3" do
      test_cases = [
        [0, 1],
        [0, 1, 2],
        [0, 1, 2, 3]
      ]

      for simplex <- test_cases do
        # Get boundary
        boundary = Simplex.boundary(simplex)

        # Get boundary of each face
        second_boundary =
          Enum.flat_map(boundary, fn {sign, face} ->
            face_boundary = Simplex.boundary(face)
            Enum.map(face_boundary, fn {face_sign, vertex} -> {sign * face_sign, vertex} end)
          end)

        # Group by vertex and sum signs
        vertex_sums =
          second_boundary
          |> Enum.group_by(fn {_sign, vertex} -> vertex end, fn {sign, _vertex} -> sign end)
          |> Enum.map(fn {_vertex, signs} -> Enum.sum(signs) end)

        # All sums should be zero (∂∂ = 0)
        assert Enum.all?(vertex_sums, fn sum -> sum == 0 end),
               "∂∂ ≠ 0 for simplex #{inspect(simplex)}"
      end
    end
  end
end
