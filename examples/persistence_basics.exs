# examples/persistence_basics.exs
#
# Persistent Homology Basics
#
# This example demonstrates the core persistent homology workflow:
#   1. Build a filtration from point cloud data
#   2. Compute persistence diagrams
#   3. Analyze birth/death of topological features
#   4. Interpret the results

alias ExTopology.{Filtration, Persistence, Diagram}

IO.puts("\n=== Persistent Homology Basics ===")

# Create a simple point cloud: an equilateral triangle
# This will have β₀ = 1 component and β₁ = 1 cycle at certain scales
triangle_points =
  Nx.tensor([
    # Bottom-left
    [0.0, 0.0],
    # Bottom-right
    [1.0, 0.0],
    # Top (roughly equilateral)
    [0.5, 0.866]
  ])

IO.puts("\n1. Point Cloud: Equilateral Triangle")
IO.puts("   3 points in 2D forming a triangle")

# Build Vietoris-Rips filtration
# As epsilon increases, edges form when points are within distance epsilon
IO.puts("\n2. Building Vietoris-Rips Filtration...")

filtration =
  Filtration.vietoris_rips(triangle_points,
    max_epsilon: 2.0,
    max_dimension: 2
  )

IO.puts("   Filtration has #{length(filtration)} simplices")
IO.puts("   Critical values (birth times):")

Filtration.critical_values(filtration)
|> Enum.take(10)
|> Enum.each(fn val ->
  IO.puts("     ε = #{Float.round(val, 3)}")
end)

# Compute persistent homology
IO.puts("\n3. Computing Persistent Homology...")
diagrams = Persistence.compute(filtration, max_dimension: 2)

IO.puts("\n4. Persistence Diagrams by Dimension:")

Enum.each(diagrams, fn diagram ->
  IO.puts("\n   H#{diagram.dimension} (dimension #{diagram.dimension}):")

  if Enum.empty?(diagram.pairs) do
    IO.puts("     No features")
  else
    Enum.each(diagram.pairs, fn {birth, death} ->
      death_str = if death == :infinity, do: "∞", else: Float.round(death, 3)
      persistence = if death == :infinity, do: "∞", else: Float.round(death - birth, 3)
      IO.puts("     (#{Float.round(birth, 3)}, #{death_str}) - persistence: #{persistence}")
    end)
  end
end)

# Analyze the H0 (components) diagram
IO.puts("\n5. Interpreting Results:")

h0_diagram = Enum.find(diagrams, fn d -> d.dimension == 0 end)
h1_diagram = Enum.find(diagrams, fn d -> d.dimension == 1 end)

IO.puts("\n   H₀ (Connected Components):")
h0_stats = Diagram.summary_statistics(h0_diagram)
IO.puts("     Total features: #{h0_stats.count}")
IO.puts("     Infinite features: #{h0_stats.infinite_count} (persistent components)")
IO.puts("     Finite features: #{h0_stats.finite_count} (merged components)")

IO.puts("\n   H₁ (Loops/Cycles):")
h1_stats = Diagram.summary_statistics(h1_diagram)
IO.puts("     Total features: #{h1_stats.count}")
IO.puts("     Total persistence: #{Float.round(h1_stats.total_persistence, 3)}")
IO.puts("     Max persistence: #{Float.round(h1_stats.max_persistence, 3)}")

# Compute Betti numbers at different scales
IO.puts("\n6. Betti Numbers at Different Scales:")

scales = [0.0, 0.5, 1.0, 1.5, 2.0]

Enum.each(scales, fn epsilon ->
  betti = Persistence.betti_numbers(filtration, epsilon, max_dimension: 2)
  IO.puts("   ε = #{epsilon}: β₀ = #{betti[0]}, β₁ = #{betti[1]}, β₂ = #{betti[2]}")
end)

IO.puts("\n7. Understanding the Topology Evolution:")

IO.puts("""
   - At ε = 0: All points isolated (β₀ = 3, β₁ = 0)
   - As ε increases: Edges form, components merge (β₀ decreases)
   - At ε ≈ 1.0: Triangle forms (all edges connected, β₁ = 1 cycle)
   - Larger ε: Triangle filled in (β₁ = 0 as 2-simplex kills the cycle)
""")

# Example 2: Points with clear topology
IO.puts("=== Example 2: Circle with Noise ===")

# Generate points roughly on a circle
defmodule CircleGenerator do
  def generate_circle_points(n, radius, noise_level) do
    angles = Enum.map(0..(n - 1), fn i -> 2 * :math.pi() * i / n end)

    points =
      Enum.map(angles, fn theta ->
        noise_x = (0.5 - :rand.uniform()) * 2 * noise_level
        noise_y = (0.5 - :rand.uniform()) * 2 * noise_level
        [radius * :math.cos(theta) + noise_x, radius * :math.sin(theta) + noise_y]
      end)

    Nx.tensor(points)
  end
end

circle_points = CircleGenerator.generate_circle_points(12, 1.0, 0.1)
{n_circle, _} = Nx.shape(circle_points)
IO.puts("\nGenerated #{n_circle} points on a noisy circle")

circle_filtration =
  Filtration.vietoris_rips(circle_points,
    max_epsilon: 3.0,
    max_dimension: 2
  )

circle_diagrams = Persistence.compute(circle_filtration, max_dimension: 2)

IO.puts("\nPersistence Diagrams for Circle:")
h1_circle = Enum.find(circle_diagrams, fn d -> d.dimension == 1 end)

if h1_circle && length(h1_circle.pairs) > 0 do
  IO.puts("\n   H₁ features (loops):")

  h1_circle.pairs
  |> Enum.reject(fn {_, d} -> d == :infinity end)
  |> Enum.sort_by(fn {b, d} -> -(d - b) end)
  |> Enum.take(5)
  |> Enum.each(fn {birth, death} ->
    pers = Float.round(death - birth, 3)
    IO.puts("     (#{Float.round(birth, 3)}, #{Float.round(death, 3)}) - persistence: #{pers}")
  end)

  # The most persistent H1 feature should correspond to the main circle
  most_persistent =
    h1_circle.pairs
    |> Enum.reject(fn {_, d} -> d == :infinity end)
    |> Enum.max_by(fn {b, d} -> d - b end, fn -> nil end)

  if most_persistent do
    {b, d} = most_persistent
    IO.puts("\n   Most persistent cycle: (#{Float.round(b, 3)}, #{Float.round(d, 3)})")
    IO.puts("   This represents the main circular structure in the data!")
  end
else
  IO.puts("   No H₁ features detected")
end

IO.puts("\n=== Summary ===")

IO.puts("""
Key Concepts:
- Filtration: Sequence of simplicial complexes at increasing scale
- Birth: Scale at which a feature first appears
- Death: Scale at which a feature disappears
- Persistence: death - birth (significance of feature)
- H₀: Connected components
- H₁: Loops/cycles
- H₂: Voids/cavities

Features far from the diagonal (high persistence) are significant.
Features near the diagonal (low persistence) are likely noise.
""")
