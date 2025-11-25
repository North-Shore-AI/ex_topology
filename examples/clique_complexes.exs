# examples/clique_complexes.exs
#
# Clique Complexes and Graph Filtrations
#
# This example demonstrates:
#   1. Building clique complexes from graphs
#   2. Graph-based filtrations
#   3. Persistent homology on networks
#   4. Comparing graph and point cloud approaches

alias ExTopology.{Simplex, Filtration, Persistence, Diagram}
alias ExTopology.Graph, as: Topo

IO.puts("\n=== Clique Complexes and Graph Filtrations ===")

# Part 1: Clique Complex Basics
IO.puts("\n1. Clique Complex Basics")
IO.puts("   A clique is a complete subgraph (all vertices connected)")
IO.puts("   The clique complex treats each k-clique as a (k-1)-simplex")

# Create a graph with interesting structure
social_network =
  Graph.new()
  |> Graph.add_edge(:alice, :bob)
  |> Graph.add_edge(:bob, :carol)
  # Triangle 1: Alice-Bob-Carol
  |> Graph.add_edge(:carol, :alice)
  |> Graph.add_edge(:alice, :dave)
  |> Graph.add_edge(:bob, :dave)
  # Adding Dave creates a tetrahedron!
  |> Graph.add_edge(:carol, :dave)
  # Separate pair Eve-Frank
  |> Graph.add_edge(:eve, :frank)
  # Isolated vertex (self-loop for presence)
  |> Graph.add_edge(:george, :george)

IO.puts("\n   Social network edges:")
IO.puts("   - Alice-Bob-Carol-Dave: fully connected (4-clique)")
IO.puts("   - Eve-Frank: connected pair")
IO.puts("   - George: isolated")

# Build clique complex
complex = Simplex.clique_complex(social_network, max_dimension: 3)

IO.puts("\n   Clique complex structure:")

for dim <- 0..3 do
  simplices = Map.get(complex, dim, [])
  IO.puts("     #{dim}-simplices: #{length(simplices)}")

  if length(simplices) <= 10 do
    IO.puts("       #{inspect(simplices)}")
  end
end

IO.puts("\n   Note: Alice-Bob-Carol-Dave form a tetrahedron (3-simplex)")
IO.puts("   because they're all mutually connected")

# Part 2: Graph Invariants
IO.puts("\n2. Graph Topological Invariants")

# Create a simpler graph for invariant demo
simple_graph =
  Graph.new()
  |> Graph.add_edge(0, 1)
  |> Graph.add_edge(1, 2)
  |> Graph.add_edge(2, 3)
  # Square: no diagonal
  |> Graph.add_edge(3, 0)
  # Separate edge
  |> Graph.add_edge(4, 5)

invariants = Topo.invariants(simple_graph)

IO.puts("\n   Graph: Square (0-1-2-3) + Edge (4-5)")
IO.puts("     Vertices: #{invariants.vertices}")
IO.puts("     Edges: #{invariants.edges}")
IO.puts("     β₀ (components): #{invariants.beta_zero}")
IO.puts("     β₁ (cycles): #{invariants.beta_one}")
IO.puts("     Euler χ = V - E: #{invariants.euler_characteristic}")

# Part 3: Weighted Graph Filtration
IO.puts("\n3. Weighted Graph Filtration")
IO.puts("   Edges appear at their weight (birth time)")

# Create weighted graph representing distances
weighted_graph =
  Graph.new()
  # Close neighbors
  |> Graph.add_edge(0, 1, weight: 1.0)
  |> Graph.add_edge(1, 2, weight: 1.5)
  # Forms triangle at t=1.5
  |> Graph.add_edge(2, 0, weight: 1.2)
  # Far vertex connects later
  |> Graph.add_edge(3, 0, weight: 3.0)
  |> Graph.add_edge(3, 1, weight: 3.5)
  # Forms tetrahedron at t=4.0
  |> Graph.add_edge(3, 2, weight: 4.0)

IO.puts("\n   Weighted edges:")

weighted_graph
|> Graph.edges()
|> Enum.sort_by(& &1.weight)
|> Enum.each(fn edge ->
  IO.puts("     #{edge.v1}-#{edge.v2}: weight #{edge.weight}")
end)

filtration = Filtration.from_graph(weighted_graph, max_dimension: 2)

IO.puts("\n   Filtration (sorted by appearance time):")

filtration
|> Enum.take(15)
|> Enum.each(fn {scale, simplex} ->
  IO.puts("     t=#{Float.round(scale, 2)}: #{inspect(simplex)}")
end)

# Part 4: Persistence on Graph Filtration
IO.puts("\n4. Persistent Homology from Graph")

diagrams = Persistence.compute(filtration, max_dimension: 2)

IO.puts("\n   Persistence diagrams:")

Enum.each(diagrams, fn diagram ->
  IO.puts("\n   H#{diagram.dimension}:")

  if Enum.empty?(diagram.pairs) do
    IO.puts("     No features")
  else
    Enum.each(diagram.pairs, fn {birth, death} ->
      death_str = if death == :infinity, do: "∞", else: Float.round(death, 2)
      IO.puts("     (#{Float.round(birth, 2)}, #{death_str})")
    end)
  end
end)

# Part 5: Critical Values
IO.puts("\n5. Critical Values in Filtration")

critical = Filtration.critical_values(filtration)
IO.puts("   Scale values where topology changes:")

Enum.each(critical, fn val ->
  # What appears at this scale
  appearing =
    Enum.filter(filtration, fn {s, _} -> s == val end)
    |> Enum.map(fn {_, simplex} -> simplex end)

  IO.puts("     t=#{Float.round(val, 2)}: #{inspect(appearing)}")
end)

# Part 6: Extracting Complex at Specific Scale
IO.puts("\n6. Complex at Specific Scales")

for epsilon <- [0.0, 1.5, 2.5, 4.5] do
  complex_at_eps = Filtration.complex_at(filtration, epsilon)

  total_simplices =
    complex_at_eps
    |> Map.values()
    |> List.flatten()
    |> length()

  IO.puts("\n   At ε = #{epsilon}:")
  IO.puts("     Total simplices: #{total_simplices}")

  for {dim, simps} <- Enum.sort(complex_at_eps) do
    IO.puts("       #{dim}-simplices: #{length(simps)}")
  end
end

# Part 7: Practical Application - Collaboration Network
IO.puts("\n7. Application: Research Collaboration Network")

# Model: researchers connected if they've co-authored
# Weight = 1 / (number of papers together)
collab_network =
  Graph.new()
  # 10 papers
  |> Graph.add_edge(:researcher_a, :researcher_b, weight: 0.1)
  # 5 papers
  |> Graph.add_edge(:researcher_b, :researcher_c, weight: 0.2)
  # 2 papers
  |> Graph.add_edge(:researcher_a, :researcher_c, weight: 0.5)
  # 1 paper
  |> Graph.add_edge(:researcher_c, :researcher_d, weight: 1.0)
  # Different group
  |> Graph.add_edge(:researcher_e, :researcher_f, weight: 0.3)

IO.puts("\n   Collaboration network:")
IO.puts("   - Researchers A, B, C: Core team (triangle)")
IO.puts("   - Researcher D: Peripheral collaborator with C")
IO.puts("   - Researchers E, F: Separate team")

collab_filt = Filtration.from_graph(collab_network, max_dimension: 2)
collab_diagrams = Persistence.compute(collab_filt, max_dimension: 2)

h0 = Enum.find(collab_diagrams, fn d -> d.dimension == 0 end)
h0_stats = Diagram.summary_statistics(h0)

IO.puts("\n   H₀ analysis (research groups):")
IO.puts("     Total groups formed: #{h0_stats.count}")
IO.puts("     Persistent groups: #{h0_stats.infinite_count}")

IO.puts("\n   Interpretation:")
IO.puts("   - Close collaborators (low weight) form groups early")
IO.puts("   - Weak ties (high weight) connect groups later")
IO.puts("   - The tetrahedron A-B-C forms when all three collaborate closely")

# Part 8: Comparing Point Cloud vs Graph Approaches
IO.puts("\n8. Point Cloud vs Graph Approach")

# Same data as points
points =
  Nx.tensor([
    # 0
    [0.0, 0.0],
    # 1
    [1.0, 0.0],
    # 2
    [0.5, 0.866],
    # 3 (center)
    [0.5, 0.3]
  ])

# As a graph with distance-based weights
point_graph =
  Graph.new()
  |> Graph.add_edge(0, 1, weight: 1.0)
  |> Graph.add_edge(1, 2, weight: 1.0)
  |> Graph.add_edge(0, 2, weight: 1.0)
  |> Graph.add_edge(0, 3, weight: 0.5)
  |> Graph.add_edge(1, 3, weight: 0.6)
  |> Graph.add_edge(2, 3, weight: 0.6)

IO.puts("\n   Same triangle+center as:")
IO.puts("   - Point cloud: Vietoris-Rips filtration")
IO.puts("   - Weighted graph: Graph filtration")

# Point cloud approach
vr_filt = Filtration.vietoris_rips(points, max_dimension: 2)
vr_diagrams = Persistence.compute(vr_filt, max_dimension: 2)

# Graph approach
graph_filt = Filtration.from_graph(point_graph, max_dimension: 2)
graph_diagrams = Persistence.compute(graph_filt, max_dimension: 2)

IO.puts("\n   H₁ comparison:")
vr_h1 = Enum.find(vr_diagrams, fn d -> d.dimension == 1 end)
graph_h1 = Enum.find(graph_diagrams, fn d -> d.dimension == 1 end)

IO.puts("     Point cloud H₁: #{length(vr_h1.pairs)} features")
IO.puts("     Graph H₁: #{length(graph_h1.pairs)} features")

IO.puts("\n   Note: Both capture the same topology but filtrations differ")
IO.puts("   - Point cloud: Uses actual distances between points")
IO.puts("   - Graph: Uses explicit edge weights (can encode other relationships)")

IO.puts("\n=== Summary ===")

IO.puts("""
Key Concepts:
- Clique: Complete subgraph (all vertices connected)
- Clique complex: k-clique becomes (k-1)-simplex
- Graph filtration: Edges appear at their weight
- Critical values: Scales where topology changes

When to use graph vs point cloud:
- Point cloud: Geometric data (positions, embeddings)
- Graph: Network data (social, citation, biological)
- Weighted graph: When relationships have natural "strength"

Applications:
- Social networks: Community structure, influence
- Citation networks: Research field topology
- Biological networks: Protein interaction clusters
- Infrastructure: Critical connections and redundancy
""")
