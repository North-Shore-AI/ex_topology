# ADR-0008: Testing and Correctness Validation Strategy

## Status

Accepted

## Context

ex_topology implements mathematical algorithms where correctness is non-negotiable. A wrong Betti number isn't a minor bug—it's a fundamentally broken library.

### Testing Challenges

1. **Mathematical invariants**: Properties like ∂∂ = 0 must hold unconditionally
2. **Edge cases**: Empty graphs, disconnected components, degenerate inputs
3. **Numerical precision**: Floating-point comparisons in distance calculations
4. **Reference validation**: How do we know our β₁ matches "ground truth"?

### What Can Go Wrong

| Bug Type | Example | Detection Method |
|----------|---------|------------------|
| Off-by-one | β₁ = E - V + C vs E - V + 2C | Property tests |
| Edge direction | Counting directed edges as undirected | Unit tests |
| Numerical instability | Distance matrix asymmetry from float errors | Property tests |
| API misuse | Graph.edges returns directed pairs | Integration tests |
| Algorithm correctness | Wrong reduction order in boundary matrices | Cross-validation |

## Decision

**Use three-tier testing: unit tests, property-based tests for invariants, and cross-validation against reference implementations.**

### Tier 1: Unit Tests

Standard ExUnit tests for API contracts and known examples:

```elixir
defmodule ExTopology.GraphTest do
  use ExUnit.Case, async: true

  describe "beta_zero/1" do
    test "single vertex has β₀ = 1" do
      g = Graph.new() |> Graph.add_vertex(:a)
      assert ExTopology.Graph.beta_zero(g) == 1
    end

    test "disconnected vertices have β₀ = vertex count" do
      g = Graph.new() |> Graph.add_vertices([:a, :b, :c])
      assert ExTopology.Graph.beta_zero(g) == 3
    end

    test "connected graph has β₀ = 1" do
      g = Graph.new() |> Graph.add_edges([{:a, :b}, {:b, :c}])
      assert ExTopology.Graph.beta_zero(g) == 1
    end

    test "empty graph has β₀ = 0" do
      assert ExTopology.Graph.beta_zero(Graph.new()) == 0
    end
  end

  describe "beta_one/1" do
    test "tree has β₁ = 0" do
      tree = Graph.new() |> Graph.add_edges([{1, 2}, {1, 3}, {2, 4}])
      assert ExTopology.Graph.beta_one(tree) == 0
    end

    test "triangle has β₁ = 1" do
      triangle = Graph.new() |> Graph.add_edges([{1, 2}, {2, 3}, {3, 1}])
      assert ExTopology.Graph.beta_one(triangle) == 1
    end

    test "two disjoint triangles have β₁ = 2" do
      g = Graph.new() 
          |> Graph.add_edges([{1, 2}, {2, 3}, {3, 1}])
          |> Graph.add_edges([{4, 5}, {5, 6}, {6, 4}])
      assert ExTopology.Graph.beta_one(g) == 2
    end

    test "complete graph K4 has β₁ = 3" do
      # K4: 4 vertices, 6 edges, 1 component
      # β₁ = 6 - 4 + 1 = 3
      k4 = Graph.new() |> Graph.add_edges([
        {1, 2}, {1, 3}, {1, 4}, {2, 3}, {2, 4}, {3, 4}
      ])
      assert ExTopology.Graph.beta_one(k4) == 3
    end
  end
end
```

### Tier 2: Property-Based Tests

Use StreamData for invariant testing:

```elixir
defmodule ExTopology.PropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  describe "Euler characteristic invariant" do
    property "χ = β₀ - β₁ for all graphs" do
      check all graph <- graph_generator() do
        chi = ExTopology.Graph.euler_characteristic(graph)
        beta_0 = ExTopology.Graph.beta_zero(graph)
        beta_1 = ExTopology.Graph.beta_one(graph)
        
        assert chi == beta_0 - beta_1,
          "Euler characteristic violated: χ=#{chi}, β₀=#{beta_0}, β₁=#{beta_1}"
      end
    end

    property "β₀ ≥ 1 for non-empty graphs" do
      check all graph <- non_empty_graph_generator() do
        assert ExTopology.Graph.beta_zero(graph) >= 1
      end
    end

    property "β₁ ≥ 0 always" do
      check all graph <- graph_generator() do
        assert ExTopology.Graph.beta_one(graph) >= 0
      end
    end

    property "β₀ ≤ vertex count" do
      check all graph <- graph_generator() do
        assert ExTopology.Graph.beta_zero(graph) <= Graph.num_vertices(graph)
      end
    end

    property "adding an edge decreases β₀ by at most 1" do
      check all graph <- graph_generator(min_vertices: 2),
                {v1, v2} <- edge_not_in_graph(graph) do
        beta_0_before = ExTopology.Graph.beta_zero(graph)
        new_graph = Graph.add_edge(graph, v1, v2)
        beta_0_after = ExTopology.Graph.beta_zero(new_graph)
        
        assert beta_0_after >= beta_0_before - 1
        assert beta_0_after <= beta_0_before
      end
    end
  end

  describe "Distance matrix properties" do
    property "distance matrix is symmetric" do
      check all points <- list_of(point_generator(), min_length: 2, max_length: 100) do
        tensor = points_to_tensor(points)
        dists = ExTopology.Foundation.Distance.euclidean_matrix(tensor)
        
        assert_tensors_equal(dists, Nx.transpose(dists), rtol: 1.0e-5)
      end
    end

    property "diagonal is zero" do
      check all points <- list_of(point_generator(), min_length: 1, max_length: 100) do
        tensor = points_to_tensor(points)
        dists = ExTopology.Foundation.Distance.euclidean_matrix(tensor)
        diag = Nx.take_diagonal(dists)
        
        assert Nx.all(Nx.less(Nx.abs(diag), 1.0e-10)) |> Nx.to_number() == 1
      end
    end

    property "triangle inequality holds" do
      check all points <- list_of(point_generator(), min_length: 3, max_length: 50) do
        tensor = points_to_tensor(points)
        dists = ExTopology.Foundation.Distance.euclidean_matrix(tensor)
        n = length(points)
        
        # Sample random triples to check
        for _ <- 1..min(100, n * n) do
          [i, j, k] = Enum.take_random(0..(n-1), 3)
          d_ij = Nx.to_number(dists[i][j])
          d_jk = Nx.to_number(dists[j][k])
          d_ik = Nx.to_number(dists[i][k])
          
          assert d_ik <= d_ij + d_jk + 1.0e-10,
            "Triangle inequality violated"
        end
      end
    end
  end

  # Generators
  defp graph_generator(opts \\ []) do
    min_v = opts[:min_vertices] || 0
    max_v = opts[:max_vertices] || 20
    
    gen all num_vertices <- integer(min_v..max_v),
            edges <- list_of(edge_generator(num_vertices), max_length: num_vertices * 2) do
      Graph.new()
      |> Graph.add_vertices(0..(num_vertices - 1))
      |> Graph.add_edges(edges)
    end
  end

  defp point_generator(dim \\ 3) do
    list_of(float(min: -100.0, max: 100.0), length: dim)
  end
end
```

### Tier 3: Cross-Validation

Validate against reference implementations:

```elixir
defmodule ExTopology.CrossValidationTest do
  use ExUnit.Case
  
  @moduletag :cross_validation
  @moduletag timeout: 60_000

  describe "validate against NetworkX" do
    @tag :external
    test "β₁ matches NetworkX cycle_basis length" do
      test_cases = [
        {[{0, 1}, {1, 2}, {2, 0}], 1},
        {[{0, 1}, {1, 2}, {2, 3}, {3, 0}, {0, 2}], 2},
        {[{0, 1}, {1, 2}], 0}
      ]

      for {edges, expected} <- test_cases do
        graph = Graph.new() |> Graph.add_edges(edges)
        actual = ExTopology.Graph.beta_one(graph)
        networkx_result = run_networkx_validation(edges)
        
        assert actual == expected
        assert actual == networkx_result
      end
    end
  end

  defp run_networkx_validation(edges) do
    script = """
    import networkx as nx
    import sys
    import json
    
    edges = json.loads(sys.argv[1])
    G = nx.Graph(edges)
    print(len(nx.cycle_basis(G)))
    """
    
    edges_json = Jason.encode!(Enum.map(edges, &Tuple.to_list/1))
    {output, 0} = System.cmd("python3", ["-c", script, edges_json])
    String.trim(output) |> String.to_integer()
  end
end
```

### Test Data: Known Results

```elixir
# test/fixtures/known_graphs.exs
[
  %{name: "empty", edges: [], beta_0: 0, beta_1: 0, euler: 0},
  %{name: "single_vertex", vertices: [1], edges: [], beta_0: 1, beta_1: 0, euler: 1},
  %{name: "triangle", edges: [{1, 2}, {2, 3}, {3, 1}], beta_0: 1, beta_1: 1, euler: 0},
  %{name: "petersen", edges: petersen_edges(), beta_0: 1, beta_1: 6, euler: -5},
  %{name: "complete_5", edges: complete_graph_edges(5), beta_0: 1, beta_1: 6, euler: -5}
]
```

## Consequences

### Positive

1. **Catches invariant violations**: Property tests find edge cases
2. **Documents mathematics**: Tests serve as executable specification
3. **Cross-validation**: External reference prevents systematic errors
4. **Regression protection**: Known-answer tests prevent breakage

### Negative

1. **Test maintenance**: Property generators need care
2. **External dependencies**: Cross-validation needs Python
3. **Slow tests**: Property tests and cross-validation are slow

### Test Organization

```
test/
├── ex_topology/
│   ├── graph_test.exs           # Unit tests
│   ├── distance_test.exs        # Unit tests
│   └── embedding_test.exs       # Unit tests
├── property/
│   ├── graph_property_test.exs  # Invariants
│   └── distance_property_test.exs
├── cross_validation/
│   └── networkx_test.exs        # External validation
└── fixtures/
    └── known_graphs.exs         # Test data
```

### Dependencies

```elixir
# mix.exs
defp deps do
  [
    {:stream_data, "~> 0.6", only: [:test, :dev]},
    {:benchee, "~> 1.0", only: :dev}
  ]
end
```

## References

- [StreamData](https://hexdocs.pm/stream_data) - Property-based testing
- [NetworkX](https://networkx.org/) - Reference graph library
- "QuickCheck Testing for Fun and Profit" - John Hughes
