defmodule ExTopology.GraphTest do
  use ExUnit.Case, async: true
  doctest ExTopology.Graph

  alias ExTopology.Graph, as: Topo

  describe "beta_zero/1" do
    test "empty graph has beta_zero = 0" do
      assert Topo.beta_zero(Graph.new()) == 0
    end

    test "single vertex has beta_zero = 1" do
      g = Graph.new() |> Graph.add_vertex(:a)
      assert Topo.beta_zero(g) == 1
    end

    test "disconnected vertices have beta_zero = vertex count" do
      g = Graph.new() |> Graph.add_vertices([:a, :b, :c])
      assert Topo.beta_zero(g) == 3
    end

    test "connected graph has beta_zero = 1" do
      g = Graph.new() |> Graph.add_edges([{:a, :b}, {:b, :c}])
      assert Topo.beta_zero(g) == 1
    end

    test "two disjoint components" do
      g =
        Graph.new()
        |> Graph.add_edges([{1, 2}, {2, 3}])
        |> Graph.add_edges([{4, 5}])

      assert Topo.beta_zero(g) == 2
    end

    test "three disjoint triangles" do
      g =
        Graph.new()
        |> Graph.add_edges([{1, 2}, {2, 3}, {3, 1}])
        |> Graph.add_edges([{4, 5}, {5, 6}, {6, 4}])
        |> Graph.add_edges([{7, 8}, {8, 9}, {9, 7}])

      assert Topo.beta_zero(g) == 3
    end
  end

  describe "beta_one/1" do
    test "empty graph has beta_one = 0" do
      assert Topo.beta_one(Graph.new()) == 0
    end

    test "single vertex has beta_one = 0" do
      g = Graph.new() |> Graph.add_vertex(:a)
      assert Topo.beta_one(g) == 0
    end

    test "tree has beta_one = 0" do
      tree = Graph.new() |> Graph.add_edges([{1, 2}, {1, 3}, {2, 4}])
      assert Topo.beta_one(tree) == 0
    end

    test "triangle has beta_one = 1" do
      triangle = Graph.new() |> Graph.add_edges([{1, 2}, {2, 3}, {3, 1}])
      assert Topo.beta_one(triangle) == 1
    end

    test "two disjoint triangles have beta_one = 2" do
      g =
        Graph.new()
        |> Graph.add_edges([{1, 2}, {2, 3}, {3, 1}])
        |> Graph.add_edges([{4, 5}, {5, 6}, {6, 4}])

      assert Topo.beta_one(g) == 2
    end

    test "square has beta_one = 1" do
      square = Graph.new() |> Graph.add_edges([{1, 2}, {2, 3}, {3, 4}, {4, 1}])
      assert Topo.beta_one(square) == 1
    end

    test "square with diagonal has beta_one = 2" do
      g = Graph.new() |> Graph.add_edges([{1, 2}, {2, 3}, {3, 4}, {4, 1}, {1, 3}])
      assert Topo.beta_one(g) == 2
    end

    test "complete graph K4 has beta_one = 3" do
      # K4: 4 vertices, 6 edges, 1 component
      # beta_one = 6 - 4 + 1 = 3
      k4 =
        Graph.new()
        |> Graph.add_edges([{1, 2}, {1, 3}, {1, 4}, {2, 3}, {2, 4}, {3, 4}])

      assert Topo.beta_one(k4) == 3
    end

    test "complete graph K5 has beta_one = 6" do
      # K5: 5 vertices, 10 edges, 1 component
      # beta_one = 10 - 5 + 1 = 6
      k5 =
        Graph.new()
        |> Graph.add_edges([
          {1, 2},
          {1, 3},
          {1, 4},
          {1, 5},
          {2, 3},
          {2, 4},
          {2, 5},
          {3, 4},
          {3, 5},
          {4, 5}
        ])

      assert Topo.beta_one(k5) == 6
    end

    test "path graph has beta_one = 0" do
      path = Graph.new() |> Graph.add_edges([{1, 2}, {2, 3}, {3, 4}, {4, 5}])
      assert Topo.beta_one(path) == 0
    end
  end

  describe "euler_characteristic/1" do
    test "empty graph has euler_characteristic = 0" do
      assert Topo.euler_characteristic(Graph.new()) == 0
    end

    test "single vertex has euler_characteristic = 1" do
      g = Graph.new() |> Graph.add_vertex(:a)
      assert Topo.euler_characteristic(g) == 1
    end

    test "triangle has euler_characteristic = 0" do
      triangle = Graph.new() |> Graph.add_edges([{1, 2}, {2, 3}, {3, 1}])
      # V - E = 3 - 3 = 0
      assert Topo.euler_characteristic(triangle) == 0
    end

    test "tree with 4 vertices has euler_characteristic = 1" do
      tree = Graph.new() |> Graph.add_edges([{1, 2}, {1, 3}, {1, 4}])
      # V - E = 4 - 3 = 1
      assert Topo.euler_characteristic(tree) == 1
    end

    test "K4 has euler_characteristic = -2" do
      k4 =
        Graph.new()
        |> Graph.add_edges([{1, 2}, {1, 3}, {1, 4}, {2, 3}, {2, 4}, {3, 4}])

      # V - E = 4 - 6 = -2
      assert Topo.euler_characteristic(k4) == -2
    end

    test "euler_characteristic = beta_zero - beta_one" do
      # For any graph, chi = beta_0 - beta_1
      graphs = [
        Graph.new() |> Graph.add_edges([{1, 2}, {2, 3}, {3, 1}]),
        Graph.new() |> Graph.add_edges([{1, 2}, {1, 3}, {2, 4}]),
        Graph.new()
        |> Graph.add_edges([{1, 2}, {2, 3}])
        |> Graph.add_edges([{4, 5}])
      ]

      for g <- graphs do
        chi = Topo.euler_characteristic(g)
        beta_0 = Topo.beta_zero(g)
        beta_1 = Topo.beta_one(g)
        assert chi == beta_0 - beta_1
      end
    end
  end

  describe "connected?/1" do
    test "empty graph is not connected" do
      refute Topo.connected?(Graph.new())
    end

    test "single vertex is connected" do
      g = Graph.new() |> Graph.add_vertex(:a)
      assert Topo.connected?(g)
    end

    test "connected graph is connected" do
      g = Graph.new() |> Graph.add_edges([{1, 2}, {2, 3}])
      assert Topo.connected?(g)
    end

    test "disconnected graph is not connected" do
      g =
        Graph.new()
        |> Graph.add_edges([{1, 2}])
        |> Graph.add_vertex(3)

      refute Topo.connected?(g)
    end
  end

  describe "tree?/1" do
    test "single vertex is a tree" do
      g = Graph.new() |> Graph.add_vertex(:a)
      assert Topo.tree?(g)
    end

    test "path is a tree" do
      path = Graph.new() |> Graph.add_edges([{1, 2}, {2, 3}, {3, 4}])
      assert Topo.tree?(path)
    end

    test "star is a tree" do
      star = Graph.new() |> Graph.add_edges([{0, 1}, {0, 2}, {0, 3}, {0, 4}])
      assert Topo.tree?(star)
    end

    test "cycle is not a tree" do
      cycle = Graph.new() |> Graph.add_edges([{1, 2}, {2, 3}, {3, 1}])
      refute Topo.tree?(cycle)
    end

    test "forest is not a tree" do
      forest = Graph.new() |> Graph.add_edges([{1, 2}, {3, 4}])
      refute Topo.tree?(forest)
    end

    test "empty graph is not a tree" do
      refute Topo.tree?(Graph.new())
    end
  end

  describe "forest?/1" do
    test "empty graph is a forest" do
      assert Topo.forest?(Graph.new())
    end

    test "tree is a forest" do
      tree = Graph.new() |> Graph.add_edges([{1, 2}, {2, 3}])
      assert Topo.forest?(tree)
    end

    test "disjoint trees form a forest" do
      forest = Graph.new() |> Graph.add_edges([{1, 2}, {3, 4}, {5, 6}])
      assert Topo.forest?(forest)
    end

    test "graph with cycle is not a forest" do
      cycle = Graph.new() |> Graph.add_edges([{1, 2}, {2, 3}, {3, 1}])
      refute Topo.forest?(cycle)
    end
  end

  describe "invariants/1" do
    test "returns all invariants for triangle" do
      triangle = Graph.new() |> Graph.add_edges([{1, 2}, {2, 3}, {3, 1}])
      inv = Topo.invariants(triangle)

      assert inv.vertices == 3
      assert inv.edges == 3
      assert inv.components == 1
      assert inv.beta_zero == 1
      assert inv.beta_one == 1
      assert inv.euler_characteristic == 0
    end

    test "returns all invariants for K4" do
      k4 =
        Graph.new()
        |> Graph.add_edges([{1, 2}, {1, 3}, {1, 4}, {2, 3}, {2, 4}, {3, 4}])

      inv = Topo.invariants(k4)

      assert inv.vertices == 4
      assert inv.edges == 6
      assert inv.components == 1
      assert inv.beta_zero == 1
      assert inv.beta_one == 3
      assert inv.euler_characteristic == -2
    end
  end

  describe "num_edges/1 and num_vertices/1" do
    test "empty graph" do
      g = Graph.new()
      assert Topo.num_edges(g) == 0
      assert Topo.num_vertices(g) == 0
    end

    test "graph with edges" do
      g = Graph.new() |> Graph.add_edges([{1, 2}, {2, 3}])
      assert Topo.num_edges(g) == 2
      assert Topo.num_vertices(g) == 3
    end
  end
end
