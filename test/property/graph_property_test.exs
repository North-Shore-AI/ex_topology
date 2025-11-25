defmodule ExTopology.Property.GraphPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias ExTopology.Graph, as: Topo

  @moduletag :property

  describe "Euler characteristic invariant" do
    property "chi = beta_zero - beta_one for all graphs" do
      check all(graph <- graph_generator()) do
        chi = Topo.euler_characteristic(graph)
        beta_0 = Topo.beta_zero(graph)
        beta_1 = Topo.beta_one(graph)

        assert chi == beta_0 - beta_1,
               "Euler characteristic violated: chi=#{chi}, beta_0=#{beta_0}, beta_1=#{beta_1}"
      end
    end
  end

  describe "beta_zero properties" do
    property "beta_zero >= 0 for all graphs" do
      check all(graph <- graph_generator()) do
        assert Topo.beta_zero(graph) >= 0
      end
    end

    property "beta_zero >= 1 for non-empty graphs" do
      check all(graph <- non_empty_graph_generator()) do
        assert Topo.beta_zero(graph) >= 1
      end
    end

    property "beta_zero <= vertex count" do
      check all(graph <- graph_generator()) do
        assert Topo.beta_zero(graph) <= Graph.num_vertices(graph)
      end
    end

    property "adding an edge can only decrease beta_zero" do
      check all({graph, v1, v2} <- graph_with_new_edge()) do
        beta_0_before = Topo.beta_zero(graph)
        new_graph = Graph.add_edge(graph, v1, v2)
        beta_0_after = Topo.beta_zero(new_graph)

        assert beta_0_after <= beta_0_before,
               "Adding edge increased beta_0: #{beta_0_before} -> #{beta_0_after}"
      end
    end
  end

  describe "beta_one properties" do
    property "beta_one >= 0 for all graphs" do
      check all(graph <- graph_generator()) do
        assert Topo.beta_one(graph) >= 0
      end
    end

    property "adding an edge can only increase beta_one by at most 1" do
      check all({graph, v1, v2} <- graph_with_new_edge()) do
        beta_1_before = Topo.beta_one(graph)
        new_graph = Graph.add_edge(graph, v1, v2)
        beta_1_after = Topo.beta_one(new_graph)

        # Adding an edge increases beta_1 by at most 1
        # It increases by 1 if connecting within same component
        # It stays same if connecting different components
        assert beta_1_after >= beta_1_before

        assert beta_1_after <= beta_1_before + 1,
               "Adding edge increased beta_1 by more than 1: #{beta_1_before} -> #{beta_1_after}"
      end
    end

    property "tree has beta_one = 0" do
      check all(tree <- tree_generator()) do
        assert Topo.beta_one(tree) == 0,
               "Tree should have beta_1 = 0, got #{Topo.beta_one(tree)}"
      end
    end
  end

  describe "connected graph properties" do
    property "connected graphs have beta_zero = 1" do
      check all(graph <- connected_graph_generator()) do
        assert Topo.beta_zero(graph) == 1
        assert Topo.connected?(graph)
      end
    end
  end

  describe "forest properties" do
    property "forests have beta_one = 0" do
      check all(forest <- forest_generator()) do
        assert Topo.beta_one(forest) == 0
        assert Topo.forest?(forest)
      end
    end
  end

  describe "invariants consistency" do
    property "invariants map matches individual calculations" do
      check all(graph <- graph_generator()) do
        inv = Topo.invariants(graph)

        assert inv.vertices == Topo.num_vertices(graph)
        assert inv.edges == Topo.num_edges(graph)
        assert inv.beta_zero == Topo.beta_zero(graph)
        assert inv.beta_one == Topo.beta_one(graph)
        assert inv.euler_characteristic == Topo.euler_characteristic(graph)
        assert inv.components == inv.beta_zero
      end
    end
  end

  # Generators

  defp graph_generator do
    gen all(
          num_vertices <- integer(0..15),
          num_edges <- integer(0..min(30, div(num_vertices * (num_vertices - 1), 2))),
          edges <- edge_list_generator(num_vertices, num_edges)
        ) do
      if num_vertices == 0 do
        Graph.new()
      else
        Graph.new()
        |> Graph.add_vertices(Enum.to_list(0..(num_vertices - 1)))
        |> Graph.add_edges(edges)
      end
    end
  end

  defp non_empty_graph_generator do
    gen all(
          num_vertices <- integer(1..15),
          num_edges <- integer(0..min(30, div(num_vertices * (num_vertices - 1), 2))),
          edges <- edge_list_generator(num_vertices, num_edges)
        ) do
      Graph.new()
      |> Graph.add_vertices(Enum.to_list(0..(num_vertices - 1)))
      |> Graph.add_edges(edges)
    end
  end

  defp edge_list_generator(num_vertices, _num_edges) when num_vertices < 2 do
    constant([])
  end

  defp edge_list_generator(num_vertices, num_edges) do
    all_possible_edges =
      for i <- 0..(num_vertices - 2),
          j <- (i + 1)..(num_vertices - 1),
          do: {i, j}

    gen all(edges <- list_of(member_of(all_possible_edges), length: num_edges)) do
      Enum.uniq(edges)
    end
  end

  defp tree_generator do
    gen all(num_vertices <- integer(1..10)) do
      if num_vertices == 1 do
        Graph.new() |> Graph.add_vertex(0)
      else
        # Build a tree by connecting each new vertex to an existing one
        edges =
          1..(num_vertices - 1)
          |> Enum.map(fn v ->
            parent = :rand.uniform(v) - 1
            {parent, v}
          end)

        Graph.new()
        |> Graph.add_vertices(Enum.to_list(0..(num_vertices - 1)))
        |> Graph.add_edges(edges)
      end
    end
  end

  defp connected_graph_generator do
    gen all(
          tree <- tree_generator(),
          extra_edges <- integer(0..5)
        ) do
      vertices = Graph.vertices(tree)
      n = length(vertices)

      if n < 2 do
        tree
      else
        # Add some extra edges to the tree
        existing_edges = Graph.edges(tree) |> Enum.map(fn e -> {e.v1, e.v2} end) |> MapSet.new()

        possible_new_edges =
          for i <- vertices,
              j <- vertices,
              i < j,
              not MapSet.member?(existing_edges, {i, j}) and
                not MapSet.member?(existing_edges, {j, i}),
              do: {i, j}

        new_edges =
          Enum.take_random(possible_new_edges, min(extra_edges, length(possible_new_edges)))

        Graph.add_edges(tree, new_edges)
      end
    end
  end

  defp forest_generator do
    gen all(
          num_trees <- integer(1..5),
          tree_sizes <- list_of(integer(1..5), length: num_trees)
        ) do
      {graph, _} =
        Enum.reduce(tree_sizes, {Graph.new(), 0}, fn size, {g, offset} ->
          # Build a tree starting at vertex offset
          vertices = offset..(offset + size - 1) |> Enum.to_list()
          g_with_vertices = Graph.add_vertices(g, vertices)
          edges = build_tree_edges(size, offset)
          {Graph.add_edges(g_with_vertices, edges), offset + size}
        end)

      graph
    end
  end

  defp build_tree_edges(size, offset) when size > 1 do
    Enum.map(1..(size - 1), fn i ->
      parent = :rand.uniform(i) - 1
      {offset + parent, offset + i}
    end)
  end

  defp build_tree_edges(_size, _offset), do: []

  defp graph_with_new_edge do
    gen all(
          num_vertices <- integer(2..10),
          existing_edges <- integer(0..min(10, div(num_vertices * (num_vertices - 1), 2) - 1))
        ) do
      all_edges =
        for i <- 0..(num_vertices - 2),
            j <- (i + 1)..(num_vertices - 1),
            do: {i, j}

      selected_edges = Enum.take_random(all_edges, existing_edges)

      graph =
        Graph.new()
        |> Graph.add_vertices(Enum.to_list(0..(num_vertices - 1)))
        |> Graph.add_edges(selected_edges)

      remaining_edges = all_edges -- selected_edges

      if remaining_edges == [] do
        # Add a new vertex and connect to it
        new_v = num_vertices
        {Graph.add_vertex(graph, new_v), 0, new_v}
      else
        {v1, v2} = Enum.random(remaining_edges)
        {graph, v1, v2}
      end
    end
  end
end
