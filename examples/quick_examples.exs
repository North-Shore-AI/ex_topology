# ExTopology Quick Examples
#
# Run with: mix run examples/quick_examples.exs
#
# These examples demonstrate core functionality for common scientific tasks.

defmodule QuickExamplesHelper do
  def interpret_cohens_d(d) when abs(d) < 0.2, do: "Negligible effect"
  def interpret_cohens_d(d) when abs(d) < 0.5, do: "Small effect"
  def interpret_cohens_d(d) when abs(d) < 0.8, do: "Medium effect"
  def interpret_cohens_d(_d), do: "Large effect"
end

alias ExTopology.{Distance, Neighborhood, Embedding, Statistics}
alias ExTopology.Graph, as: Topo

IO.puts("""
╔══════════════════════════════════════════════════════════════╗
║              ExTopology Quick Examples                       ║
╚══════════════════════════════════════════════════════════════╝
""")

# =============================================================================
# PART 1: Distance Matrices
# =============================================================================

IO.puts("━━━ 1. Distance Matrices ━━━\n")

# 2D points for demonstration
points =
  Nx.tensor([
    # Origin
    [0.0, 0.0],
    # 3-4-5 right triangle
    [3.0, 4.0],
    # Unit along x
    [1.0, 0.0],
    # Unit along y
    [0.0, 1.0]
  ])

IO.puts("Points:")
IO.inspect(points, label: "  ")

euclidean = Distance.euclidean_matrix(points)
IO.puts("\nEuclidean distances:")
IO.puts("  Origin to (3,4): #{Nx.to_number(euclidean[0][1])} (expect 5.0)")

manhattan = Distance.manhattan_matrix(points)
IO.puts("  Manhattan from origin to (3,4): #{Nx.to_number(manhattan[0][1])} (expect 7.0)")

# Cosine distance for embedding-like data
embeddings =
  Nx.tensor([
    # Unit x
    [1.0, 0.0, 0.0],
    # Unit y (orthogonal to x)
    [0.0, 1.0, 0.0],
    # 45° between x and y
    [0.707, 0.707, 0.0]
  ])

cosine = Distance.cosine_matrix(embeddings)
IO.puts("\nCosine distances (embedding similarity):")
IO.puts("  Orthogonal vectors: #{Nx.to_number(cosine[0][1]) |> Float.round(3)} (expect 1.0)")
IO.puts("  45° apart: #{Nx.to_number(cosine[0][2]) |> Float.round(3)} (expect ~0.29)")

# =============================================================================
# PART 2: Graph Topology (Betti Numbers)
# =============================================================================

IO.puts("\n━━━ 2. Graph Topology ━━━\n")

# Triangle - simplest cycle
triangle = Graph.new() |> Graph.add_edges([{:a, :b}, {:b, :c}, {:c, :a}])

IO.puts("Triangle graph:")
IO.puts("  β₀ (components): #{Topo.beta_zero(triangle)} — one connected piece")
IO.puts("  β₁ (cycles): #{Topo.beta_one(triangle)} — one independent cycle")
IO.puts("  χ (Euler char): #{Topo.euler_characteristic(triangle)}")

# Tree - no cycles
tree = Graph.new() |> Graph.add_edges([{1, 2}, {1, 3}, {2, 4}, {2, 5}])

IO.puts("\nTree graph (hierarchical, no cycles):")
IO.puts("  β₀: #{Topo.beta_zero(tree)}")
IO.puts("  β₁: #{Topo.beta_one(tree)} — trees have no cycles")
IO.puts("  Is tree?: #{Topo.tree?(tree)}")

# Complete graph K5 - many cycles
k5_edges = for i <- 1..5, j <- 1..5, i < j, do: {i, j}
k5 = Graph.new() |> Graph.add_edges(k5_edges)

IO.puts("\nComplete graph K5 (fully connected):")
inv = Topo.invariants(k5)
IO.puts("  Vertices: #{inv.vertices}, Edges: #{inv.edges}")
IO.puts("  β₁: #{inv.beta_one} — many alternative paths create cycles")

# =============================================================================
# PART 3: Neighborhood Graphs
# =============================================================================

IO.puts("\n━━━ 3. Neighborhood Graphs ━━━\n")

# Points forming two clusters
cluster_points =
  Nx.tensor([
    # Cluster 1
    [0.0, 0.0],
    [0.5, 0.0],
    [0.0, 0.5],
    [0.5, 0.5],
    # Cluster 2 (far away)
    [10.0, 10.0],
    [10.5, 10.0],
    [10.0, 10.5],
    [10.5, 10.5]
  ])

# k-NN graph
knn = Neighborhood.knn_graph(cluster_points, k: 2)
IO.puts("k-NN graph (k=2):")
IO.puts("  Components: #{Topo.beta_zero(knn)} — detects 2 clusters")
IO.puts("  Edges: #{Topo.num_edges(knn)}")

# Epsilon-ball graph
eps_graph = Neighborhood.epsilon_graph(cluster_points, epsilon: 1.0)
IO.puts("\nε-ball graph (ε=1.0):")
IO.puts("  Components: #{Topo.beta_zero(eps_graph)} — also finds 2 clusters")

# Threshold that connects everything
connected_graph = Neighborhood.epsilon_graph(cluster_points, epsilon: 20.0)
IO.puts("\nε-ball graph (ε=20.0):")
IO.puts("  Connected?: #{Topo.connected?(connected_graph)}")

# =============================================================================
# PART 4: Embedding Analysis
# =============================================================================

IO.puts("\n━━━ 4. Embedding Analysis ━━━\n")

# Uniform distribution - consistent local density
key = Nx.Random.key(42)
# Returns [0, 1) by default
{uniform_points, _} = Nx.Random.uniform(key, shape: {50, 5})

# Clustered distribution - variable density
{noise1, _} = Nx.Random.normal(Nx.Random.key(1), shape: {25, 5})
{noise2, _} = Nx.Random.normal(Nx.Random.key(2), shape: {25, 5})
cluster1 = Nx.add(Nx.broadcast(0.0, {25, 5}), Nx.multiply(noise1, 0.1))
cluster2 = Nx.add(Nx.broadcast(5.0, {25, 5}), Nx.multiply(noise2, 0.1))
clustered_points = Nx.concatenate([cluster1, cluster2])

uniform_stats = Embedding.statistics(uniform_points, k: 5)
clustered_stats = Embedding.statistics(clustered_points, k: 5)

IO.puts("Embedding quality metrics:")
IO.puts("\n  Uniform distribution:")
IO.puts("    k-NN variance: #{Float.round(uniform_stats.knn_variance, 5)}")
IO.puts("    Density std: #{Float.round(uniform_stats.density_std, 3)}")

IO.puts("\n  Clustered distribution:")
IO.puts("    k-NN variance: #{Float.round(clustered_stats.knn_variance, 5)}")
IO.puts("    Density std: #{Float.round(clustered_stats.density_std, 3)}")

IO.puts("\n  → Higher variance/std indicates less uniform embedding")

# Outlier detection
data_with_outlier =
  Nx.concatenate([
    uniform_points,
    # Outlier
    Nx.tensor([[100.0, 100.0, 100.0, 100.0, 100.0]])
  ])

isolation = Embedding.isolation_scores(data_with_outlier, k: 5)
max_score_idx = Nx.argmax(isolation) |> Nx.to_number()

IO.puts("\nOutlier detection:")
IO.puts("  Highest isolation score at index: #{max_score_idx}")
IO.puts("  Score: #{Nx.to_number(isolation[max_score_idx]) |> Float.round(2)}")
IO.puts("  (Index 50 is our planted outlier)")

# =============================================================================
# PART 5: Statistical Analysis
# =============================================================================

IO.puts("\n━━━ 5. Statistical Analysis ━━━\n")

# Correlation
x = Nx.tensor([1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0])
# Perfect correlation
y_perfect = Nx.multiply(x, 2.0)

y_noisy =
  Nx.add(y_perfect, Nx.tensor([0.1, -0.2, 0.15, -0.1, 0.05, -0.15, 0.2, -0.05, 0.1, -0.1]))

y_uncorrelated = Nx.tensor([5.0, 3.0, 8.0, 2.0, 9.0, 1.0, 7.0, 4.0, 6.0, 10.0])

IO.puts("Correlation analysis:")

IO.puts(
  "  Perfect linear: #{Statistics.pearson(x, y_perfect) |> Nx.to_number() |> Float.round(3)}"
)

IO.puts("  With noise: #{Statistics.pearson(x, y_noisy) |> Nx.to_number() |> Float.round(3)}")

IO.puts(
  "  Uncorrelated: #{Statistics.pearson(x, y_uncorrelated) |> Nx.to_number() |> Float.round(3)}"
)

# Effect size
control = Nx.tensor([4.2, 4.5, 4.1, 4.8, 4.3, 4.6, 4.4, 4.7])
treatment = Nx.tensor([5.1, 5.4, 4.9, 5.5, 5.2, 5.3, 5.0, 5.6])

cohens_d = Statistics.cohens_d(treatment, control) |> Nx.to_number()
IO.puts("\nEffect size (treatment vs control):")
IO.puts("  Cohen's d: #{Float.round(cohens_d, 2)}")
IO.puts("  Interpretation: #{QuickExamplesHelper.interpret_cohens_d(cohens_d)}")

# Summary statistics
data = [2.3, 4.5, 1.2, 5.6, 3.4, 4.1, 2.8, 5.2, 3.9, 4.7]
summary = Statistics.summary(data)

IO.puts("\nDescriptive statistics:")
IO.puts("  Mean: #{Float.round(summary.mean, 2)}")
IO.puts("  Std: #{Float.round(summary.std, 2)}")
IO.puts("  Median: #{summary.median}")
IO.puts("  IQR: #{summary.q3 - summary.q1}")

# =============================================================================
# PART 6: Putting It Together - Workflow Example
# =============================================================================

IO.puts("\n━━━ 6. Complete Workflow: Cluster Analysis ━━━\n")

# Generate data with 3 clusters
n_per_cluster = 20
key = Nx.Random.key(999)

# Generate standard normal, then shift by mean (scale = 1.0 is default)
{n1, key} = Nx.Random.normal(key, shape: {n_per_cluster, 10})
{n2, key} = Nx.Random.normal(key, shape: {n_per_cluster, 10})
{n3, _key} = Nx.Random.normal(key, shape: {n_per_cluster, 10})
# Cluster centered at 0
c1 = Nx.add(n1, 0.0)
# Cluster centered at 5
c2 = Nx.add(n2, 5.0)
# Cluster centered at 10
c3 = Nx.add(n3, 10.0)

data = Nx.concatenate([c1, c2, c3])
IO.puts("Generated 60 samples in 3 clusters (10D)")

# Step 1: Compute distances
IO.puts("\n1. Computing pairwise distances...")
dists = Distance.euclidean_matrix(data)
IO.puts("   Distance matrix: #{inspect(Nx.shape(dists))}")

# Step 2: Build neighborhood graph
IO.puts("\n2. Building ε-ball neighborhood graph...")
# Find good epsilon by examining distance distribution
median_dist =
  dists
  |> Nx.to_flat_list()
  |> Enum.filter(&(&1 > 0))
  |> Enum.sort()
  |> then(&Enum.at(&1, div(length(&1), 4)))

# Connect ~25% of pairs
epsilon = median_dist * 0.8

graph = Neighborhood.from_distance_matrix(dists, epsilon: epsilon)
IO.puts("   Epsilon: #{Float.round(epsilon, 2)}")
IO.puts("   Edges: #{Topo.num_edges(graph)}")

# Step 3: Analyze topology
IO.puts("\n3. Analyzing graph topology...")
inv = Topo.invariants(graph)
IO.puts("   Components (clusters): #{inv.beta_zero}")
IO.puts("   Cycles: #{inv.beta_one}")

# Step 4: Embedding quality
IO.puts("\n4. Assessing embedding quality...")
stats = Embedding.statistics(data, k: 5)
IO.puts("   k-NN variance: #{Float.round(stats.knn_variance, 4)}")
IO.puts("   Mean k-NN distance: #{Float.round(stats.mean_knn_distance, 2)}")

# Step 5: Find outliers
IO.puts("\n5. Detecting outliers...")
sparse = Embedding.sparse_points(data, k: 5, percentile: 10)
IO.puts("   Sparse points (bottom 10% density): #{inspect(sparse)}")

IO.puts("\n✓ Workflow complete!")
IO.puts("  Found #{inv.beta_zero} clusters in the data")
IO.puts("  Graph has #{inv.beta_one} cycles (redundant within-cluster connections)")
