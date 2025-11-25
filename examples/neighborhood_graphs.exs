# examples/neighborhood_graphs.exs
#
# Scenario:
#   A small 2D point cloud (e.g. sensor grid).
#   We will build:
#     * k-NN graph (mutual)
#     * ε-graph
#     * Gabriel graph
#     * Relative neighborhood graph
#   and compare β₀ and β₁ for each.

alias ExTopology.{Neighborhood}
alias ExTopology.Graph, as: Topo

IO.puts("\n=== Neighborhood graph family comparison ===")

points_list =
  for x <- 0..4,
      y <- 0..1 do
    [x * 1.0, y * 1.0]
  end

points = Nx.tensor(points_list)

g_knn =
  Neighborhood.knn_graph(points,
    k: 2,
    mutual: true
  )

g_eps = Neighborhood.epsilon_graph(points, epsilon: 1.1)
g_gabriel = Neighborhood.gabriel_graph(points)
g_rng = Neighborhood.relative_neighborhood_graph(points)

graphs = [
  {"k-NN (k=2, mutual)", g_knn},
  {"ε-graph (ε=1.1)", g_eps},
  {"Gabriel graph", g_gabriel},
  {"Relative neighborhood graph", g_rng}
]

for {name, g} <- graphs do
  inv = Topo.invariants(g)

  IO.puts("\n#{name}")
  IO.puts("  vertices: #{inv.vertices}")
  IO.puts("  edges:    #{inv.edges}")
  IO.puts("  components (β₀): #{inv.beta_zero}")
  IO.puts("  cycles     (β₁): #{inv.beta_one}")
end
