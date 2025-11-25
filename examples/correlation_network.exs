# examples/correlation_network.exs
#
# Scenario:
#   Gene expression (or any multivariate data) with 4 variables.
#   We will:
#     * compute a correlation matrix
#     * convert correlation to a distance
#     * build a graph where edges connect highly correlated variables
#     * examine topological invariants of that network.

alias ExTopology.{Neighborhood, Statistics}
alias ExTopology.Graph, as: Topo

IO.puts("\n=== Correlation network example ===")

variables = [:gene_A, :gene_B, :gene_C, :gene_D]

# 6 samples × 4 genes
data =
  Nx.tensor([
    #   A     B      C      D
    [0.5, 1.0, 0.20, 3.4],
    [1.0, 2.1, 0.25, 3.5],
    [1.5, 3.0, 0.30, 3.6],
    [2.0, 3.9, 0.35, 3.5],
    [2.5, 4.9, 0.40, 3.3],
    [3.0, 5.9, 0.45, 3.4]
  ])

corr = Statistics.correlation_matrix(data)

IO.puts("\nPearson correlation matrix (rows/cols = variables in order):")

for i <- 0..(length(variables) - 1) do
  row =
    for j <- 0..(length(variables) - 1) do
      r = Nx.to_number(corr[i][j])
      Float.round(r, 3)
    end

  IO.puts(Enum.join(row, "\t"))
end

IO.puts("\nStrongest absolute correlations (off-diagonal):")

pairs =
  for i <- 0..(length(variables) - 2),
      j <- (i + 1)..(length(variables) - 1) do
    r = Nx.to_number(corr[i][j])
    {{Enum.at(variables, i), Enum.at(variables, j)}, r}
  end

pairs
|> Enum.sort_by(fn {_vars, r} -> -abs(r) end)
|> Enum.each(fn {{v1, v2}, r} ->
  IO.puts("  #{v1} – #{v2}: r = #{Float.round(r, 3)}")
end)

# Convert correlation to a distance: d = 1 - |r|
corr_abs = Nx.abs(corr)
dist = Nx.subtract(1.0, corr_abs)

# Build ε-graph: connect variables with distance <= 0.3 (|r| >= 0.7)
g = Neighborhood.from_distance_matrix(dist, epsilon: 0.3)
inv = Topo.invariants(g)

IO.puts("\nCorrelation network with ε = 0.3 on distance d = 1 - |r|")
IO.puts("  vertices: #{inv.vertices}")
IO.puts("  edges:    #{inv.edges}")
IO.puts("  components (β₀): #{inv.beta_zero}")
IO.puts("  cycles     (β₁): #{inv.beta_one}")

IO.puts("\nEdges in the correlation network (variables with |r| ≥ 0.7):")

for e <- Graph.edges(g) do
  v1 = Enum.at(variables, e.v1)
  v2 = Enum.at(variables, e.v2)
  IO.puts("  #{v1} — #{v2}")
end
