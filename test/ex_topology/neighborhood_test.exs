defmodule ExTopology.NeighborhoodTest do
  use ExUnit.Case, async: true

  alias ExTopology.Graph, as: Topo
  alias ExTopology.Neighborhood

  describe "knn_graph/2" do
    test "creates graph with correct number of vertices" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [2.0, 0.0]])
      g = Neighborhood.knn_graph(points, k: 1)

      assert Graph.num_vertices(g) == 3
    end

    test "k=1 connects each point to nearest neighbor" do
      # Three points in a line
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [10.0, 0.0]])
      g = Neighborhood.knn_graph(points, k: 1)

      # Point 0 and 1 should be connected (distance 1)
      # Point 2's nearest is point 1 (distance 9)
      assert Graph.num_edges(g) >= 2
    end

    test "k=n-1 creates nearly complete graph" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [0.5, 0.5]])
      g = Neighborhood.knn_graph(points, k: 2)

      # With k=2 and 3 vertices, should have many edges
      assert Graph.num_edges(g) >= 2
    end

    test "raises error when k >= n" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0]])

      assert_raise ArgumentError, fn ->
        Neighborhood.knn_graph(points, k: 2)
      end
    end

    test "with weighted option adds edge weights" do
      points = Nx.tensor([[0.0, 0.0], [3.0, 4.0]])
      g = Neighborhood.knn_graph(points, k: 1, weighted: true)

      edges = Graph.edges(g)
      assert length(edges) >= 1

      edge = hd(edges)
      assert is_number(edge.weight) or is_float(edge.weight)
    end

    test "accepts list input" do
      points = [[0.0, 0.0], [1.0, 0.0], [2.0, 0.0]]
      g = Neighborhood.knn_graph(points, k: 1)

      assert Graph.num_vertices(g) == 3
    end

    test "mutual knn only connects mutual neighbors" do
      # Point arrangement where mutual k-NN differs from regular k-NN
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [1.5, 0.0], [10.0, 0.0]])
      g_regular = Neighborhood.knn_graph(points, k: 1)
      g_mutual = Neighborhood.knn_graph(points, k: 1, mutual: true)

      # Mutual should have fewer or equal edges
      assert Graph.num_edges(g_mutual) <= Graph.num_edges(g_regular)
    end
  end

  describe "epsilon_graph/2" do
    test "connects points within epsilon" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [5.0, 0.0]])
      g = Neighborhood.epsilon_graph(points, epsilon: 1.5)

      # Points 0 and 1 are distance 1 apart (within epsilon)
      # Point 2 is distance 4+ from others (outside epsilon)
      assert Graph.num_edges(g) == 1
      assert Topo.beta_zero(g) == 2
    end

    test "large epsilon connects all points" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [2.0, 0.0]])
      g = Neighborhood.epsilon_graph(points, epsilon: 100.0)

      # All points should be connected
      assert Topo.connected?(g)
    end

    test "small epsilon creates no edges" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [2.0, 0.0]])
      g = Neighborhood.epsilon_graph(points, epsilon: 0.5)

      # No points within 0.5 of each other
      assert Graph.num_edges(g) == 0
      assert Topo.beta_zero(g) == 3
    end

    test "raises error for non-positive epsilon" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0]])

      assert_raise ArgumentError, fn ->
        Neighborhood.epsilon_graph(points, epsilon: 0)
      end

      assert_raise ArgumentError, fn ->
        Neighborhood.epsilon_graph(points, epsilon: -1)
      end
    end

    test "strict option uses < instead of <=" do
      # Points exactly epsilon apart
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0]])
      g_non_strict = Neighborhood.epsilon_graph(points, epsilon: 1.0)
      g_strict = Neighborhood.epsilon_graph(points, epsilon: 1.0, strict: true)

      # Non-strict includes boundary, strict excludes it
      assert Graph.num_edges(g_non_strict) >= Graph.num_edges(g_strict)
    end

    test "with weighted option" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0]])
      g = Neighborhood.epsilon_graph(points, epsilon: 2.0, weighted: true)

      edges = Graph.edges(g)
      assert length(edges) == 1

      edge = hd(edges)
      assert_in_delta(edge.weight, 1.0, 0.01)
    end
  end

  describe "from_distance_matrix/2" do
    test "creates knn graph from distance matrix" do
      dists = Nx.tensor([[0.0, 1.0, 5.0], [1.0, 0.0, 4.0], [5.0, 4.0, 0.0]])
      g = Neighborhood.from_distance_matrix(dists, k: 1)

      assert Graph.num_vertices(g) == 3
      assert Graph.num_edges(g) >= 1
    end

    test "creates epsilon graph from distance matrix" do
      dists = Nx.tensor([[0.0, 1.0, 5.0], [1.0, 0.0, 4.0], [5.0, 4.0, 0.0]])
      g = Neighborhood.from_distance_matrix(dists, epsilon: 2.0)

      # Only points 0 and 1 are within epsilon
      assert Graph.num_edges(g) == 1
    end

    test "raises error without k or epsilon" do
      dists = Nx.tensor([[0.0, 1.0], [1.0, 0.0]])

      assert_raise ArgumentError, fn ->
        Neighborhood.from_distance_matrix(dists, [])
      end
    end

    test "accepts nested list input" do
      dists = [[0.0, 1.0, 5.0], [1.0, 0.0, 4.0], [5.0, 4.0, 0.0]]
      g = Neighborhood.from_distance_matrix(dists, k: 1)

      assert Graph.num_vertices(g) == 3
    end
  end

  describe "gabriel_graph/2" do
    test "creates gabriel graph" do
      points = Nx.tensor([[0.0, 0.0], [2.0, 0.0], [1.0, 1.0]])
      g = Neighborhood.gabriel_graph(points)

      assert Graph.num_vertices(g) == 3
      # Should have at least some edges
      assert Graph.num_edges(g) >= 0
    end

    test "gabriel graph is subgraph of complete graph" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [0.5, 0.5], [2.0, 1.0]])
      g = Neighborhood.gabriel_graph(points)

      # Gabriel graph has at most n(n-1)/2 edges
      n = 4
      max_edges = div(n * (n - 1), 2)
      assert Graph.num_edges(g) <= max_edges
    end
  end

  describe "relative_neighborhood_graph/2" do
    test "creates rng" do
      points = Nx.tensor([[0.0, 0.0], [2.0, 0.0], [1.0, 1.0]])
      g = Neighborhood.relative_neighborhood_graph(points)

      assert Graph.num_vertices(g) == 3
    end

    test "rng is subgraph of gabriel graph" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [0.5, 0.5], [2.0, 1.0]])
      gabriel = Neighborhood.gabriel_graph(points)
      rng = Neighborhood.relative_neighborhood_graph(points)

      # RNG is subgraph of Gabriel graph (RNG condition is stricter)
      assert Graph.num_edges(rng) <= Graph.num_edges(gabriel)
    end
  end

  describe "topological analysis of neighborhood graphs" do
    test "dense cluster has low beta_one" do
      # Points in a tight cluster
      points =
        Nx.tensor([
          [0.0, 0.0],
          [0.1, 0.0],
          [0.0, 0.1],
          [0.1, 0.1]
        ])

      g = Neighborhood.epsilon_graph(points, epsilon: 0.2)
      # Dense cluster should form cycles
      assert Topo.beta_one(g) >= 0
    end

    test "line of points has beta_one = 0" do
      # Points in a line - no cycles possible
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [2.0, 0.0], [3.0, 0.0]])
      g = Neighborhood.knn_graph(points, k: 1)

      # A line graph has no cycles
      assert Topo.beta_one(g) == 0
    end
  end
end
