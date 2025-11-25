# examples/outlier_detection.exs
#
# Scenario:
#   Low-dimensional embedding of samples (e.g. PCA or UMAP of cells).
#   We will:
#     * summarise k-NN structure
#     * compute isolation scores
#     * mark sparse points as outliers
#     * summarise mean k-NN distances.

alias ExTopology.{Distance, Embedding, Statistics}

# Build a simple 2D embedding:
#   - 40 samples following a smooth curve
#   - 2 strong outliers far away
main_points =
  Enum.map(0..39, fn i ->
    x = i / 10.0
    y = :math.sin(x) / 5.0
    [x, y]
  end)

points_list = main_points ++ [[10.0, 10.0], [-5.0, -6.0]]

points = Nx.tensor(points_list)
{n_points, _} = Nx.shape(points)

IO.puts("\n=== Outlier detection in embedding space ===")
IO.puts("Number of samples: #{n_points}")

k = 5

# 1) k-NN summary statistics
stats = Embedding.statistics(points, k: k)

IO.puts("\nEmbedding statistics (k = #{k}):")
IO.inspect(stats)

# 2) Isolation scores
scores = Embedding.isolation_scores(points, k: k)
score_list = Nx.to_flat_list(scores)

IO.puts("\nTop 5 most isolated points:")

score_list
|> Enum.with_index()
|> Enum.sort_by(fn {score, _idx} -> -score end)
|> Enum.take(5)
|> Enum.each(fn {score, idx} ->
  IO.puts("  sample #{idx}: isolation score #{Float.round(score, 3)}")
end)

# 3) Mark sparse points using percentile threshold
sparse = Embedding.sparse_points(points, k: k, percentile: 10)
IO.puts("\n10% sparsest points (indices): #{inspect(sparse)}")

# 4) Distribution of mean k-NN distance
mean_knn = Embedding.mean_knn_distance(points, k: k)
mean_knn_list = Nx.to_flat_list(mean_knn)
mean_knn_stats = Statistics.summary(mean_knn_list)

IO.puts("\nSummary of mean distance to #{k} nearest neighbors:")
IO.inspect(mean_knn_stats)

# 5) (Optional) look at full pairwise distance matrix
pairwise = Distance.pairwise(points, metric: :euclidean)
IO.puts("\nPairwise distance matrix shape: #{inspect(Nx.shape(pairwise))}")
