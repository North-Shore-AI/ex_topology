# examples/persistence_landscapes.exs
#
# Persistence Diagrams and Landscapes
#
# This example demonstrates:
#   1. Analyzing persistence diagrams
#   2. Computing diagram statistics
#   3. Comparing diagrams (bottleneck/Wasserstein distance)
#   4. Persistence landscapes for statistical analysis
#   5. Filtering features by persistence

alias ExTopology.{Filtration, Persistence, Diagram}

IO.puts("\n=== Persistence Diagrams and Landscapes ===")

# Part 1: Create two point clouds with different topology
IO.puts("\n1. Creating Two Point Clouds")

# Point cloud 1: A clear circle
defmodule PointGenerator do
  def circle(n, radius) do
    angles = Enum.map(0..(n - 1), fn i -> 2 * :math.pi() * i / n end)

    points =
      Enum.map(angles, fn theta ->
        [radius * :math.cos(theta), radius * :math.sin(theta)]
      end)

    Nx.tensor(points)
  end

  def two_clusters(n_per_cluster, separation) do
    cluster1 =
      Enum.map(1..n_per_cluster, fn _ ->
        [0.5 - :rand.uniform(), 0.5 - :rand.uniform()]
      end)

    cluster2 =
      Enum.map(1..n_per_cluster, fn _ ->
        [separation + 0.5 - :rand.uniform(), 0.5 - :rand.uniform()]
      end)

    Nx.tensor(cluster1 ++ cluster2)
  end
end

circle_points = PointGenerator.circle(12, 1.0)
cluster_points = PointGenerator.two_clusters(6, 3.0)

IO.puts("   Circle: 12 points on a circle (has 1 loop)")
IO.puts("   Clusters: 12 points in 2 clusters (has 2 components initially)")

# Part 2: Compute persistence diagrams
IO.puts("\n2. Computing Persistence Diagrams")

circle_filt = Filtration.vietoris_rips(circle_points, max_dimension: 2)
cluster_filt = Filtration.vietoris_rips(cluster_points, max_dimension: 2)

circle_diagrams = Persistence.compute(circle_filt, max_dimension: 2)
cluster_diagrams = Persistence.compute(cluster_filt, max_dimension: 2)

# Part 3: Diagram Statistics
IO.puts("\n3. Diagram Statistics")

IO.puts("\n   Circle H₁ (loops):")
circle_h1 = Enum.find(circle_diagrams, fn d -> d.dimension == 1 end)
circle_h1_stats = Diagram.summary_statistics(circle_h1)
IO.puts("     Features: #{circle_h1_stats.count}")
IO.puts("     Finite features: #{circle_h1_stats.finite_count}")
IO.puts("     Total persistence: #{Float.round(circle_h1_stats.total_persistence, 3)}")
IO.puts("     Max persistence: #{Float.round(circle_h1_stats.max_persistence, 3)}")
IO.puts("     Mean persistence: #{Float.round(circle_h1_stats.mean_persistence, 3)}")
IO.puts("     Entropy: #{Float.round(circle_h1_stats.entropy, 3)}")

IO.puts("\n   Clusters H₀ (components):")
cluster_h0 = Enum.find(cluster_diagrams, fn d -> d.dimension == 0 end)
cluster_h0_stats = Diagram.summary_statistics(cluster_h0)
IO.puts("     Features: #{cluster_h0_stats.count}")
IO.puts("     Infinite features: #{cluster_h0_stats.infinite_count} (persistent components)")
IO.puts("     Total persistence: #{Float.round(cluster_h0_stats.total_persistence, 3)}")
IO.puts("     Max persistence: #{Float.round(cluster_h0_stats.max_persistence, 3)}")

# Part 4: Persistence Values
IO.puts("\n4. Individual Persistences")

IO.puts("\n   Circle H₁ persistences:")
circle_h1_pers = Diagram.persistences(circle_h1)

circle_h1_pers
|> Enum.reject(&(&1 == :infinity))
|> Enum.sort(:desc)
|> Enum.take(5)
|> Enum.with_index(1)
|> Enum.each(fn {p, i} ->
  IO.puts("     #{i}. #{Float.round(p, 3)}")
end)

IO.puts("\n   The largest persistence corresponds to the main circular structure")

# Part 5: Filtering by Persistence
IO.puts("\n5. Filtering Features by Persistence")

IO.puts("\n   Circle H₁ before filtering: #{length(circle_h1.pairs)} features")

# Filter to significant features only
filtered_h1 = Diagram.filter_by_persistence(circle_h1, min: 0.5)
IO.puts("   After filtering (min persistence 0.5): #{length(filtered_h1.pairs)} features")

# Part 6: Comparing Diagrams
IO.puts("\n6. Comparing Persistence Diagrams")

# Create a slightly perturbed circle
perturbed_circle = Nx.add(circle_points, Nx.broadcast(0.1, Nx.shape(circle_points)))
perturbed_filt = Filtration.vietoris_rips(perturbed_circle, max_dimension: 2)
perturbed_diagrams = Persistence.compute(perturbed_filt, max_dimension: 2)
perturbed_h1 = Enum.find(perturbed_diagrams, fn d -> d.dimension == 1 end)

IO.puts("\n   Comparing circle H₁ to perturbed circle H₁:")
bottleneck = Diagram.bottleneck_distance(circle_h1, perturbed_h1)
wasserstein = Diagram.wasserstein_distance(circle_h1, perturbed_h1, p: 2)
IO.puts("     Bottleneck distance: #{Float.round(bottleneck, 4)}")
IO.puts("     Wasserstein distance (p=2): #{Float.round(wasserstein, 4)}")

IO.puts("\n   Comparing circle H₁ to clusters H₁ (very different topology):")
cluster_h1 = Enum.find(cluster_diagrams, fn d -> d.dimension == 1 end)
bottleneck_diff = Diagram.bottleneck_distance(circle_h1, cluster_h1)
wasserstein_diff = Diagram.wasserstein_distance(circle_h1, cluster_h1, p: 2)
IO.puts("     Bottleneck distance: #{Float.round(bottleneck_diff, 4)}")
IO.puts("     Wasserstein distance (p=2): #{Float.round(wasserstein_diff, 4)}")

IO.puts("\n   Note: Similar topologies have small distances, different ones have large distances")

# Part 7: Persistence Landscapes
IO.puts("\n7. Persistence Landscapes")
IO.puts("   Landscapes convert diagrams to functions for statistical analysis")

# Compute landscape at several t values
t_values = Enum.map(0..20, fn i -> i * 0.25 end)

IO.puts("\n   Circle H₁ Landscape (level 1):")
landscape_1 = Diagram.persistence_landscape(circle_h1, t_values, level: 1)

# Print a simple ASCII visualization
IO.puts("\n   t     λ₁(t)")

Enum.zip(t_values, landscape_1)
|> Enum.each(fn {t, val} ->
  bar = String.duplicate("█", round(val * 20))

  IO.puts(
    "   #{Float.round(t, 2) |> Float.to_string() |> String.pad_leading(4)} #{bar} #{Float.round(val, 3)}"
  )
end)

IO.puts("\n   The landscape peaks near the midpoint of the main loop's lifespan")

IO.puts("\n   Computing multiple landscape levels:")

for level <- 1..3 do
  landscape = Diagram.persistence_landscape(circle_h1, t_values, level: level)
  max_val = Enum.max(landscape)
  IO.puts("     Level #{level}: max = #{Float.round(max_val, 3)}")
end

# Part 8: Coordinate Transformations
IO.puts("\n8. Coordinate Transformations")

IO.puts("\n   Birth-Death coordinates (original):")

Enum.take(circle_h1.pairs, 3)
|> Enum.each(fn {b, d} ->
  d_str = if d == :infinity, do: "∞", else: Float.round(d, 3)
  IO.puts("     (birth=#{Float.round(b, 3)}, death=#{d_str})")
end)

IO.puts("\n   Persistence-Birth coordinates:")
pb_coords = Diagram.to_persistence_birth_coords(circle_h1)

Enum.take(pb_coords, 3)
|> Enum.each(fn {p, b} ->
  IO.puts("     (persistence=#{Float.round(p, 3)}, birth=#{Float.round(b, 3)})")
end)

IO.puts("\n   Persistence-Birth format is useful for certain visualizations")

# Part 9: Handling Infinite Features
IO.puts("\n9. Handling Infinite Features")

IO.puts(
  "\n   Circle H₀ has #{cluster_h0_stats.infinite_count} infinite features (persistent components)"
)

IO.puts("   For visualization, we can project to finite values:")

projected_h0 = Diagram.project_infinite(cluster_h0, 10.0)
IO.puts("\n   After projection (max_death=10.0):")

Enum.take(projected_h0.pairs, 3)
|> Enum.each(fn {b, d} ->
  IO.puts("     (#{Float.round(b, 3)}, #{Float.round(d, 3)})")
end)

# Part 10: Entropy Analysis
IO.puts("\n10. Persistence Entropy")
IO.puts("    Entropy measures the distribution of feature importances")

circles_of_varying_complexity = [
  {6, "Simple (6 points)"},
  {12, "Medium (12 points)"},
  {24, "Complex (24 points)"}
]

IO.puts("\n    Comparing circles of varying complexity:")

for {n, label} <- circles_of_varying_complexity do
  pts = PointGenerator.circle(n, 1.0)
  filt = Filtration.vietoris_rips(pts, max_dimension: 2)
  diags = Persistence.compute(filt, max_dimension: 2)
  h1 = Enum.find(diags, fn d -> d.dimension == 1 end)
  ent = Diagram.entropy(h1)
  IO.puts("      #{label}: entropy = #{Float.round(ent, 3)}")
end

IO.puts("\n=== Summary ===")

IO.puts("""
Key Concepts:
- Persistence = death - birth (feature significance)
- Total persistence: Sum of all finite persistences
- Entropy: Distribution of persistence values
- Bottleneck distance: Maximum matching cost (shape comparison)
- Wasserstein distance: Sum of matching costs (more sensitive)
- Persistence landscape: Functional representation for statistics

Applications:
- Feature selection: Filter by persistence threshold
- Shape comparison: Use bottleneck/Wasserstein distances
- Statistical analysis: Use landscapes as feature vectors
- Visualization: Transform to persistence-birth coordinates
""")
