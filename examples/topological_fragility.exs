# examples/topological_fragility.exs
#
# Topological Fragility and Stability Analysis
#
# This example demonstrates:
#   1. Point removal sensitivity analysis
#   2. Identifying critical points in data
#   3. Feature stability scoring
#   4. Robustness analysis
#   5. Local fragility around specific points

alias ExTopology.{Filtration, Persistence, Fragility}

IO.puts("\n=== Topological Fragility Analysis ===")

# Part 1: Create a point cloud with varying importance
IO.puts("\n1. Creating Test Point Cloud")

# Create a circle with one point that's critical for the topology
# and one outlier that shouldn't matter much
defmodule FragilityHelper do
  def create_test_data do
    # Main circle (8 points)
    n = 8

    circle =
      Enum.map(0..(n - 1), fn i ->
        theta = 2 * :math.pi() * i / n
        [:math.cos(theta), :math.sin(theta)]
      end)

    # Add a "bridge" point that might be critical
    # Center point
    bridge = [[0.0, 0.0]]

    # Add an outlier
    outlier = [[5.0, 5.0]]

    all_points = circle ++ bridge ++ outlier

    {Nx.tensor(all_points),
     %{
       circle_indices: Enum.to_list(0..(n - 1)),
       bridge_index: n,
       outlier_index: n + 1
     }}
  end
end

{points, indices} = FragilityHelper.create_test_data()
{n_points, _} = Nx.shape(points)

IO.puts("   Points: #{n_points} total")
IO.puts("   - Circle: indices #{inspect(indices.circle_indices)}")
IO.puts("   - Bridge point: index #{indices.bridge_index} (at origin)")
IO.puts("   - Outlier: index #{indices.outlier_index} (far away)")

# Part 2: Point Removal Sensitivity
IO.puts("\n2. Point Removal Sensitivity Analysis")
IO.puts("   Computing how topology changes when each point is removed...")

removal_scores = Fragility.point_removal_sensitivity(points, max_dimension: 1)

IO.puts("\n   Fragility scores (higher = more impact on topology):")

removal_scores
|> Enum.sort_by(fn {_idx, score} -> -score end)
|> Enum.each(fn {idx, score} ->
  label =
    cond do
      idx in indices.circle_indices -> "circle"
      idx == indices.bridge_index -> "bridge"
      idx == indices.outlier_index -> "outlier"
      true -> "unknown"
    end

  IO.puts("     Point #{idx} (#{label}): #{Float.round(score, 4)}")
end)

# Part 3: Identify Critical Points
IO.puts("\n3. Identifying Critical Points")

# Using threshold-based identification
critical_threshold = Fragility.identify_critical_points(removal_scores, threshold: 0.1)
IO.puts("   Critical points (score > 0.1): #{inspect(critical_threshold)}")

# Using top-k identification
critical_top3 = Fragility.identify_critical_points(removal_scores, top_k: 3)
IO.puts("   Top 3 most fragile points: #{inspect(critical_top3)}")

# Part 4: Feature Stability Scores
IO.puts("\n4. Feature Stability Scores")
IO.puts("   Based on persistence (higher = more stable)")

filtration = Filtration.vietoris_rips(points, max_dimension: 2)
diagrams = Persistence.compute(filtration, max_dimension: 2)

h1_diagram = Enum.find(diagrams, fn d -> d.dimension == 1 end)

if h1_diagram && length(h1_diagram.pairs) > 0 do
  stability_scores = Fragility.feature_stability_scores(h1_diagram)

  IO.puts("\n   H₁ feature stability (normalized to [0,1]):")

  stability_scores
  |> Enum.with_index()
  |> Enum.sort_by(fn {score, _} -> -score end)
  |> Enum.each(fn {score, idx} ->
    bar = String.duplicate("█", round(score * 20))
    IO.puts("     Feature #{idx}: #{bar} #{Float.round(score, 3)}")
  end)

  IO.puts("\n   Score 1.0 = most stable, lower = more fragile/noisy")
else
  IO.puts("   No H₁ features found")
end

# Part 5: Local Fragility Analysis
IO.puts("\n5. Local Fragility Analysis")
IO.puts("   Analyzing fragility around specific points...")

for idx <- [0, indices.bridge_index, indices.outlier_index] do
  label =
    cond do
      idx in indices.circle_indices -> "circle point"
      idx == indices.bridge_index -> "bridge point"
      idx == indices.outlier_index -> "outlier"
      true -> "unknown"
    end

  analysis = Fragility.local_fragility(points, idx, k: 3)

  IO.puts("\n   Point #{idx} (#{label}):")
  IO.puts("     Removal impact: #{Float.round(analysis.removal_impact, 4)}")

  IO.puts(
    "     Neighborhood mean fragility: #{Float.round(analysis.neighborhood_mean_fragility, 4)}"
  )

  IO.puts("     Relative fragility: #{Float.round(analysis.relative_fragility, 4)}")
  IO.puts("     Nearest neighbors: #{inspect(analysis.neighbor_indices)}")
end

# Part 6: Bottleneck Stability
IO.puts("\n6. Bottleneck Stability Threshold")
IO.puts("   Finding minimum perturbation to change topology...")

stability_threshold =
  Fragility.bottleneck_stability(points,
    num_samples: 5,
    max_perturbation: 2.0
  )

IO.puts("   Stability threshold: #{Float.round(stability_threshold, 3)}")
IO.puts("   (Perturbations smaller than this preserve topology)")

# Part 7: Robustness Score
IO.puts("\n7. Overall Robustness Score")

robustness = Fragility.robustness_score(points)
IO.puts("   Robustness: #{Float.round(robustness, 3)} (0-1 scale, higher = more robust)")

interpretation =
  cond do
    robustness > 0.7 -> "Highly robust topology"
    robustness > 0.4 -> "Moderately robust topology"
    true -> "Fragile topology"
  end

IO.puts("   Interpretation: #{interpretation}")

# Part 8: Comparative Analysis
IO.puts("\n8. Comparing Different Structures")

# Create different structures and compare robustness
structures = [
  {Nx.tensor([[0.0, 0.0], [1.0, 0.0], [0.5, 0.866]]), "Triangle (3 points)"},
  {Nx.tensor([[0.0, 0.0], [1.0, 0.0], [2.0, 0.0]]), "Line (3 points)"},
  {Nx.tensor([[0.0, 0.0], [1.0, 0.0], [0.0, 1.0], [1.0, 1.0]]), "Square (4 points)"}
]

IO.puts("\n   Structure                 Robustness")
IO.puts("   " <> String.duplicate("-", 45))

for {pts, name} <- structures do
  rob = Fragility.robustness_score(pts)
  bar = String.duplicate("█", round(rob * 20))
  IO.puts("   #{String.pad_trailing(name, 25)} #{bar} #{Float.round(rob, 3)}")
end

# Part 9: Practical Application - Network Analysis
IO.puts("\n9. Practical Application: Network Node Importance")

# Create a small network as points (simulating node positions)
network_points =
  Nx.tensor([
    # Hub node (center)
    [0.0, 0.0],
    # Peripheral nodes
    [1.0, 0.0],
    [0.0, 1.0],
    [-1.0, 0.0],
    [0.0, -1.0],
    # Isolated node
    [2.0, 2.0]
  ])

IO.puts("\n   Analyzing network with hub topology:")
IO.puts("   - Node 0: Hub (center)")
IO.puts("   - Nodes 1-4: Periphery (connected to hub)")
IO.puts("   - Node 5: Isolated")

network_scores = Fragility.point_removal_sensitivity(network_points, max_dimension: 1)

IO.puts("\n   Node importance (by topological impact):")

network_scores
|> Enum.sort_by(fn {_, s} -> -s end)
|> Enum.each(fn {idx, score} ->
  role = if idx == 0, do: "hub", else: if(idx == 5, do: "isolated", else: "peripheral")
  IO.puts("     Node #{idx} (#{role}): #{Float.round(score, 4)}")
end)

IO.puts("\n   The hub typically has highest fragility (removing it breaks connections)")
IO.puts("   The isolated node has low fragility (already disconnected)")

IO.puts("\n=== Summary ===")

IO.puts("""
Key Concepts:
- Point Removal Sensitivity: How much topology changes when point removed
- Critical Points: Points with high topological impact
- Feature Stability: Persistence-based stability (high persistence = stable)
- Bottleneck Stability: Minimum perturbation to change topology
- Robustness Score: Combined measure of overall stability

Applications:
- Network analysis: Identify critical nodes/hubs
- Data quality: Find points that might be outliers or critical samples
- Validation: Test reliability of topological findings
- Feature selection: Focus on stable topological features
""")
