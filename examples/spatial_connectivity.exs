# examples/spatial_connectivity.exs
#
# Scenario:
#   2D coordinates of sampling locations (e.g. wells or sensors).
#   We will:
#     * compute pairwise distances
#     * build ε-neighborhood graphs at several scales
#     * inspect β₀ (components) and β₁ (cycles)
#     * flag spatial outliers using local density.

alias ExTopology.{Distance, Embedding, Neighborhood, Statistics}
alias ExTopology.Graph, as: Topo

points =
  Nx.tensor([
    # Cluster 1 (e.g. instruments in lab A)
    [0.0, 0.0],
    [0.1, 0.1],
    [-0.1, 0.0],
    [0.0, -0.1],
    [0.2, -0.1],
    # Cluster 2 (lab B)
    [5.0, 5.0],
    [5.1, 4.9],
    [4.9, 5.2],
    # Isolated site
    [10.0, -2.0]
  ])

{n_points, _} = Nx.shape(points)
IO.puts("\n=== Spatial connectivity example ===")
IO.puts("Number of sampling locations: #{n_points}")

# 1) Pairwise Euclidean distances and simple summary
dists = Distance.euclidean_matrix(points)
distance_values = Nx.to_flat_list(dists)
dist_summary = Statistics.summary(distance_values)

IO.puts("\nPairwise Euclidean distances summary (all point pairs):")
IO.inspect(dist_summary)

# 2) ε-neighborhood graphs at different spatial scales
defmodule SpatialConnectivityHelper do
  alias ExTopology.{Neighborhood}
  alias ExTopology.Graph, as: Topo

  def build_and_print_epsilon_graph(points, epsilon) do
    g = Neighborhood.epsilon_graph(points, epsilon: epsilon)
    inv = Topo.invariants(g)

    IO.puts("\nε-neighborhood graph with ε = #{epsilon}")
    IO.puts("  vertices: #{inv.vertices}")
    IO.puts("  edges:    #{inv.edges}")
    IO.puts("  components (β₀): #{inv.beta_zero}")
    IO.puts("  cycles     (β₁): #{inv.beta_one}")
    IO.puts("  Euler characteristic χ = #{inv.euler_characteristic}")

    g
  end
end

_g_small = SpatialConnectivityHelper.build_and_print_epsilon_graph(points, 0.3)
_g_medium = SpatialConnectivityHelper.build_and_print_epsilon_graph(points, 1.0)
# Large enough to merge clusters
_g_large = SpatialConnectivityHelper.build_and_print_epsilon_graph(points, 8.0)

# 3) Local densities and spatial outliers (from the embedding utilities)
densities = Embedding.local_density(points, k: 3)
mean_knn = Embedding.mean_knn_distance(points, k: 3)

IO.puts("\nLocal density and mean distance to 3 nearest neighbors:")

densities_list = Nx.to_flat_list(densities)
mean_knn_list = Nx.to_flat_list(mean_knn)

densities_list
|> Enum.zip(mean_knn_list)
|> Enum.with_index()
|> Enum.each(fn {{density, mean_d}, idx} ->
  IO.puts(
    "  point #{idx}: density = #{Float.round(density, 3)}, " <>
      "mean d₍₃₎ = #{Float.round(mean_d, 3)}"
  )
end)

# 4) Flag sparsest points as candidate spatial outliers
sparse_indices = Embedding.sparse_points(points, k: 3, percentile: 20)

IO.puts("\n20% sparsest points (candidate spatial outliers):")
IO.inspect(sparse_indices)
