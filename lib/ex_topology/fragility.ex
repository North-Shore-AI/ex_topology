defmodule ExTopology.Fragility do
  @moduledoc """
  Topological fragility and stability analysis.

  Topological fragility measures how sensitive topological features are to
  perturbations in the data. A fragile structure changes dramatically with
  small perturbations, while robust structures persist.

  ## Fragility Metrics

  - **Point removal sensitivity**: How topology changes when points are removed
  - **Edge perturbation**: How topology changes when edge weights vary
  - **Feature stability**: Persistence-based stability scores
  - **Bottleneck stability**: Distance to nearest topological transition

  ## Use Cases

  - Detecting unreliable topological features
  - Identifying critical points/edges in networks
  - Validation of topological findings
  - Robustness testing for TDA pipelines

  ## Examples

      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [0.5, 0.866]])
      scores = ExTopology.Fragility.point_removal_sensitivity(points, k: 3)
      critical_points = ExTopology.Fragility.identify_critical_points(scores, threshold: 0.5)
  """

  alias ExTopology.{Distance, Filtration, Persistence, Diagram}

  @type point_cloud :: Nx.Tensor.t()
  @type fragility_scores :: %{non_neg_integer() => float()}

  @doc """
  Computes point removal sensitivity scores.

  For each point, measures how much the persistence diagram changes
  when that point is removed from the dataset.

  ## Parameters

  - `points` - Nx tensor of shape `{n, d}`
  - `opts` - Keyword list:
    - `:k` - Number of nearest neighbors to check (default: 5)
    - `:max_dimension` - Maximum homology dimension (default: 1)
    - `:metric` - Distance metric (default: :bottleneck)

  ## Returns

  - Map of point index to fragility score (higher = more fragile)

  ## Examples

      iex> points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [2.0, 0.0]])
      iex> scores = ExTopology.Fragility.point_removal_sensitivity(points)
      iex> is_map(scores)
      true

  ## Mathematical Background

  Fragility(i) = Σ_k d_B(H_k(X), H_k(X \\ {i}))

  where d_B is bottleneck distance and H_k is k-th homology.
  """
  @spec point_removal_sensitivity(point_cloud(), keyword()) :: fragility_scores()
  def point_removal_sensitivity(points, opts \\ []) do
    max_dim = Keyword.get(opts, :max_dimension, 1)
    metric = Keyword.get(opts, :metric, :bottleneck)

    n = Nx.axis_size(points, 0)

    # Compute baseline persistence diagrams
    baseline_filtration = Filtration.vietoris_rips(points, max_dimension: max_dim)
    baseline_diagrams = Persistence.compute(baseline_filtration, max_dimension: max_dim)

    # For each point, compute diagram without that point
    for i <- 0..(n - 1), into: %{} do
      # Remove point i
      points_without_i = remove_point(points, i)

      # Compute new diagrams
      if Nx.axis_size(points_without_i, 0) < 2 do
        {i, 0.0}
      else
        new_filtration = Filtration.vietoris_rips(points_without_i, max_dimension: max_dim)
        new_diagrams = Persistence.compute(new_filtration, max_dimension: max_dim)

        # Compute distance between diagrams
        score = diagram_distance(baseline_diagrams, new_diagrams, metric)
        {i, score}
      end
    end
  end

  @doc """
  Computes edge perturbation sensitivity for a weighted graph.

  Measures how topology changes when edge weights are perturbed.

  ## Parameters

  - `graph` - A libgraph Graph struct with weighted edges
  - `opts` - Keyword list:
    - `:perturbation` - Amount to perturb (default: 0.1)
    - `:max_dimension` - Maximum homology dimension (default: 1)

  ## Returns

  - Map of edge to fragility score

  ## Examples

      iex> g = Graph.new() |> Graph.add_edge(0, 1, weight: 1.0)
      iex> scores = ExTopology.Fragility.edge_perturbation_sensitivity(g)
      iex> is_map(scores)
      true
  """
  @spec edge_perturbation_sensitivity(Graph.t(), keyword()) :: %{
          {non_neg_integer(), non_neg_integer()} => float()
        }
  def edge_perturbation_sensitivity(graph, opts \\ []) do
    perturbation = Keyword.get(opts, :perturbation, 0.1)
    max_dim = Keyword.get(opts, :max_dimension, 1)

    # Baseline filtration
    baseline_filtration = Filtration.from_graph(graph, max_dimension: max_dim)
    baseline_diagrams = Persistence.compute(baseline_filtration, max_dimension: max_dim)

    # Test each edge
    edges = Graph.edges(graph)

    for edge <- edges, into: %{} do
      # Perturb edge weight
      perturbed_graph =
        Graph.update_edge(
          graph,
          edge.v1,
          edge.v2,
          weight: (edge.weight || 0.0) + perturbation
        )

      # Compute new diagrams
      new_filtration = Filtration.from_graph(perturbed_graph, max_dimension: max_dim)
      new_diagrams = Persistence.compute(new_filtration, max_dimension: max_dim)

      # Compute distance
      score = diagram_distance(baseline_diagrams, new_diagrams, :bottleneck)
      {{edge.v1, edge.v2}, score}
    end
  end

  @doc """
  Computes feature stability scores based on persistence.

  Features with high persistence are considered stable,
  while low persistence indicates fragility.

  ## Parameters

  - `diagram` - A persistence diagram
  - `opts` - Keyword list:
    - `:normalize` - Normalize scores to [0, 1] (default: true)

  ## Returns

  - List of stability scores (one per feature)

  ## Examples

      iex> diagram = %{dimension: 1, pairs: [{0.0, 1.0}, {0.5, 2.0}]}
      iex> scores = ExTopology.Fragility.feature_stability_scores(diagram)
      iex> length(scores) == 2
      true

  ## Mathematical Background

  Stability(f) = persistence(f) / max_persistence

  Normalized to [0, 1] where 1 = most stable feature.
  """
  @spec feature_stability_scores(Diagram.diagram(), keyword()) :: [float()]
  def feature_stability_scores(diagram, opts \\ []) do
    normalize = Keyword.get(opts, :normalize, true)

    persistences =
      diagram
      |> Diagram.persistences()
      |> Enum.reject(&(&1 == :infinity))

    if Enum.empty?(persistences) do
      []
    else
      if normalize do
        max_pers = Enum.max(persistences)

        if max_pers > 0 do
          Enum.map(persistences, fn p -> p / max_pers end)
        else
          Enum.map(persistences, fn _ -> 0.0 end)
        end
      else
        persistences
      end
    end
  end

  @doc """
  Identifies critical points based on fragility scores.

  ## Parameters

  - `scores` - Map of point index to fragility score
  - `opts` - Keyword list:
    - `:threshold` - Fragility threshold (default: mean + 1 std)
    - `:top_k` - Return top k most fragile points (default: nil)

  ## Returns

  - List of point indices identified as critical

  ## Examples

      iex> scores = %{0 => 0.1, 1 => 0.8, 2 => 0.2}
      iex> critical = ExTopology.Fragility.identify_critical_points(scores, threshold: 0.5)
      iex> critical
      [1]
  """
  @spec identify_critical_points(fragility_scores(), keyword()) :: [non_neg_integer()]
  def identify_critical_points(scores, opts \\ []) do
    values = Map.values(scores)

    threshold =
      Keyword.get_lazy(opts, :threshold, fn ->
        mean = Enum.sum(values) / length(values)
        std_dev = compute_std_dev(values, mean)
        mean + std_dev
      end)

    top_k = Keyword.get(opts, :top_k, nil)

    if top_k do
      # When top_k is specified, ignore threshold and just take top k
      scores
      |> Enum.sort_by(fn {_idx, score} -> score end, :desc)
      |> Enum.take(top_k)
      |> Enum.map(fn {idx, _} -> idx end)
    else
      # When top_k is not specified, filter by threshold
      scores
      |> Enum.filter(fn {_idx, score} -> score >= threshold end)
      |> Enum.sort_by(fn {_idx, score} -> score end, :desc)
      |> Enum.map(fn {idx, _} -> idx end)
    end
  end

  @doc """
  Computes bottleneck stability threshold.

  Finds the minimum perturbation size needed to change topology.

  ## Parameters

  - `points` - Nx tensor of shape `{n, d}`
  - `opts` - Keyword list:
    - `:num_samples` - Number of perturbations to test (default: 10)
    - `:max_perturbation` - Maximum perturbation magnitude (default: 1.0)

  ## Returns

  - Float threshold value

  ## Examples

      iex> points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [0.5, 0.866]])
      iex> threshold = ExTopology.Fragility.bottleneck_stability(points)
      iex> is_float(threshold)
      true
  """
  @spec bottleneck_stability(point_cloud(), keyword()) :: float()
  def bottleneck_stability(points, opts \\ []) do
    num_samples = Keyword.get(opts, :num_samples, 10)
    max_pert = Keyword.get(opts, :max_perturbation, 1.0)

    # Baseline diagrams
    baseline_filtration = Filtration.vietoris_rips(points, max_dimension: 1)
    baseline_diagrams = Persistence.compute(baseline_filtration, max_dimension: 1)

    # Test increasing perturbation levels
    perturbation_levels = Enum.map(1..num_samples, fn i -> i * max_pert / num_samples end)

    Enum.find(perturbation_levels, max_pert, fn pert ->
      # Add random noise
      noise = generate_noise(points, pert)
      perturbed_points = Nx.add(points, noise)

      # Compute diagrams
      new_filtration = Filtration.vietoris_rips(perturbed_points, max_dimension: 1)
      new_diagrams = Persistence.compute(new_filtration, max_dimension: 1)

      # Check if topology changed significantly
      distance = diagram_distance(baseline_diagrams, new_diagrams, :bottleneck)
      distance > 0.1
    end)
  end

  @doc """
  Analyzes local fragility around a specific point.

  ## Parameters

  - `points` - Nx tensor of shape `{n, d}`
  - `index` - Index of point to analyze
  - `opts` - Keyword list:
    - `:radius` - Neighborhood radius (default: auto-computed)

  ## Returns

  - Map with local fragility metrics

  ## Examples

      iex> points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [2.0, 0.0]])
      iex> analysis = ExTopology.Fragility.local_fragility(points, 1)
      iex> Map.has_key?(analysis, :removal_impact)
      true
  """
  @spec local_fragility(point_cloud(), non_neg_integer(), keyword()) :: map()
  def local_fragility(points, index, opts \\ []) do
    # Compute removal impact
    all_scores = point_removal_sensitivity(points, opts)
    removal_impact = Map.get(all_scores, index, 0.0)

    # Get nearest neighbors
    dist_matrix = Distance.euclidean_matrix(points)
    distances = Nx.slice_along_axis(dist_matrix, index, 1, axis: 0) |> Nx.squeeze()
    k = Keyword.get(opts, :k, 5)

    neighbor_indices =
      distances
      |> Nx.to_flat_list()
      |> Enum.with_index()
      |> Enum.reject(fn {_, i} -> i == index end)
      |> Enum.sort_by(fn {d, _} -> d end)
      |> Enum.take(k)
      |> Enum.map(fn {_, i} -> i end)

    # Compute neighborhood stability
    neighbor_scores = Enum.map(neighbor_indices, fn i -> Map.get(all_scores, i, 0.0) end)

    neighborhood_mean =
      if Enum.empty?(neighbor_scores),
        do: 0.0,
        else: Enum.sum(neighbor_scores) / length(neighbor_scores)

    %{
      removal_impact: removal_impact,
      neighborhood_mean_fragility: neighborhood_mean,
      relative_fragility:
        if(neighborhood_mean > 0, do: removal_impact / neighborhood_mean, else: 0.0),
      neighbor_indices: neighbor_indices
    }
  end

  # Private helper functions

  defp remove_point(points, index) do
    n = Nx.axis_size(points, 0)

    cond do
      n == 1 ->
        # Return empty tensor if only one point
        Nx.tensor([], type: Nx.type(points))

      index == 0 ->
        Nx.slice_along_axis(points, 1, n - 1, axis: 0)

      index == n - 1 ->
        Nx.slice_along_axis(points, 0, n - 1, axis: 0)

      true ->
        before = Nx.slice_along_axis(points, 0, index, axis: 0)
        after_slice = Nx.slice_along_axis(points, index + 1, n - index - 1, axis: 0)
        Nx.concatenate([before, after_slice], axis: 0)
    end
  end

  defp diagram_distance(diagrams1, diagrams2, metric) do
    # Sum distances across all dimensions
    Enum.zip(diagrams1, diagrams2)
    |> Enum.map(fn {d1, d2} ->
      case metric do
        :bottleneck -> Diagram.bottleneck_distance(d1, d2)
        :wasserstein -> Diagram.wasserstein_distance(d1, d2)
        _ -> Diagram.bottleneck_distance(d1, d2)
      end
    end)
    |> Enum.sum()
  end

  defp compute_std_dev(values, mean) do
    variance =
      values
      |> Enum.map(fn v -> :math.pow(v - mean, 2) end)
      |> Enum.sum()
      |> Kernel./(length(values))

    :math.sqrt(variance)
  end

  defp generate_noise(points, magnitude) do
    {n, d} = Nx.shape(points)
    # Generate random noise in [-magnitude, magnitude]
    # Using Nx.random_uniform with proper key
    key = Nx.Random.key(System.system_time(:nanosecond))
    {noise, _new_key} = Nx.Random.uniform(key, -magnitude, magnitude, shape: {n, d}, type: :f32)
    noise
  end

  @doc """
  Computes overall robustness score for a point cloud.

  Combines multiple fragility metrics into a single score.

  ## Parameters

  - `points` - Nx tensor of shape `{n, d}`
  - `opts` - Keyword list (passed to sub-methods)

  ## Returns

  - Float robustness score in [0, 1] (higher = more robust)

  ## Examples

      iex> points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [0.5, 0.866]])
      iex> score = ExTopology.Fragility.robustness_score(points)
      iex> score >= 0.0 and score <= 1.0
      true
  """
  @spec robustness_score(point_cloud(), keyword()) :: float()
  def robustness_score(points, opts \\ []) do
    # Compute various fragility metrics
    removal_scores = point_removal_sensitivity(points, opts)

    mean_fragility =
      Map.values(removal_scores) |> Enum.sum() |> Kernel./(map_size(removal_scores))

    stability_threshold = bottleneck_stability(points, opts)

    # Combine into robustness score (inverse of fragility)
    # Normalize to [0, 1]
    fragility_component = 1.0 / (1.0 + mean_fragility)
    stability_component = stability_threshold / (stability_threshold + 1.0)

    (fragility_component + stability_component) / 2.0
  end
end
