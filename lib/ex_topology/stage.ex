defmodule ExTopology.Stage do
  @moduledoc """
  Crucible.Stage implementation for Topological Data Analysis metrics.

  This stage extracts point cloud data from context, computes TDA metrics
  (Betti numbers, persistence diagrams, fragility scores), and merges
  results into context metrics.

  ## Usage in Pipeline

      pipeline = [
        {Crucible.Stage.DataLoad, %{dataset: "my_data"}},
        {Crucible.Stage.BackendCall, %{}},
        {ExTopology.Stage, %{
          data_key: :embeddings,
          compute: [:betti, :persistence, :fragility],
          k: 10,
          max_dimension: 1
        }}
      ]

  ## Options

  - `:data_key` - Key in `ctx.assigns` containing Nx tensor of points
    (default: `:embeddings`)
  - `:compute` - List of metrics to compute (default: `[:betti, :embedding]`)
    - `:betti` - Graph Betti numbers (beta_0, beta_1, euler_char)
    - `:persistence` - Persistence diagrams and summary
    - `:fragility` - Robustness score and point sensitivities
    - `:embedding` - k-NN variance and density statistics
  - `:k` - Number of neighbors for k-NN graph (default: 10)
  - `:max_dimension` - Max simplex dimension for persistence (default: 1)
  - `:epsilon` - Epsilon for epsilon-graph (optional, uses k-NN if not set)

  ## Output

  Results are stored in:
  - `ctx.metrics[:tda]` - Summary metrics map
  - `ctx.assigns[:tda_diagrams]` - Persistence diagrams (if computed)
  - `ctx.assigns[:tda_fragility]` - Fragility details (if computed)

  ## Example

      # In a Crucible experiment
      ctx = %Crucible.Context{
        assigns: %{embeddings: Nx.tensor([[0.0, 0.0], [1.0, 0.0], [0.5, 0.866]])}
      }

      {:ok, updated_ctx} = ExTopology.Stage.run(ctx, %{
        compute: [:betti, :persistence],
        k: 2
      })

      # Access results
      updated_ctx.metrics[:tda][:beta_zero]
      # => 1
  """

  # Note: This module implements a behaviour-like interface compatible with
  # Crucible.Stage but does not declare @behaviour to avoid the dependency.
  # When used with crucible_framework, it will work seamlessly.

  alias ExTopology.{Diagram, Embedding, Filtration, Fragility, Graph, Neighborhood, Persistence}

  @type compute_option :: :betti | :persistence | :fragility | :embedding

  @type opts :: %{
          optional(:data_key) => atom(),
          optional(:compute) => [compute_option()],
          optional(:k) => pos_integer(),
          optional(:max_dimension) => pos_integer(),
          optional(:epsilon) => float()
        }

  @default_opts %{
    data_key: :embeddings,
    compute: [:betti, :embedding],
    k: 10,
    max_dimension: 1
  }

  @doc """
  Runs the TDA stage, computing requested metrics on point cloud data.

  ## Parameters

  - `ctx` - A Crucible.Context struct (or any struct with `assigns` and `metrics` fields)
  - `opts` - Options map, keyword list, or nil

  ## Returns

  - `{:ok, updated_context}` on success
  - `{:error, {:tda_stage_failed, reason}}` on failure

  ## Examples

      iex> ctx = %{assigns: %{embeddings: Nx.tensor([[0, 0], [1, 0], [0.5, 0.866]])}, metrics: %{}}
      iex> {:ok, result} = ExTopology.Stage.run(ctx, %{compute: [:betti], k: 2})
      iex> is_integer(result.metrics[:tda][:beta_zero])
      true
  """
  @spec run(map(), opts() | keyword() | nil) :: {:ok, map()} | {:error, term()}
  def run(ctx, opts) do
    opts = normalize_opts(opts)

    case get_points(ctx, opts) do
      {:ok, points} ->
        results = compute_metrics(points, opts)
        updated_ctx = merge_results(ctx, results, opts)
        {:ok, updated_ctx}

      {:error, reason} ->
        {:error, {:tda_stage_failed, reason}}
    end
  end

  @doc """
  Returns a description of the stage and its configuration.

  ## Parameters

  - `opts` - Options map, keyword list, or nil

  ## Returns

  A map with stage metadata including:
  - `:stage` - Stage module name
  - `:description` - Human-readable description
  - `:data_key` - Key used for input data
  - `:compute` - List of metrics being computed
  - `:k` - Number of neighbors
  - `:max_dimension` - Maximum persistence dimension

  ## Examples

      iex> ExTopology.Stage.describe(%{compute: [:betti], k: 5})
      %{
        stage: "ExTopology.Stage",
        description: "Compute TDA metrics on point cloud data",
        data_key: :embeddings,
        compute: [:betti],
        k: 5,
        max_dimension: 1
      }
  """
  @spec describe(opts() | keyword() | nil) :: map()
  def describe(opts) do
    opts = normalize_opts(opts)

    %{
      stage: "ExTopology.Stage",
      description: "Compute TDA metrics on point cloud data",
      data_key: opts.data_key,
      compute: opts.compute,
      k: opts.k,
      max_dimension: opts.max_dimension
    }
  end

  # Private implementation functions

  @spec normalize_opts(opts() | keyword() | nil) :: map()
  defp normalize_opts(nil), do: @default_opts
  defp normalize_opts(opts) when is_list(opts), do: Map.merge(@default_opts, Map.new(opts))
  defp normalize_opts(opts) when is_map(opts), do: Map.merge(@default_opts, opts)

  @spec get_points(map(), map()) :: {:ok, Nx.Tensor.t()} | {:error, String.t()}
  defp get_points(ctx, opts) do
    assigns = Map.get(ctx, :assigns, %{})

    case Map.get(assigns, opts.data_key) do
      nil ->
        {:error, "No data found at key #{inspect(opts.data_key)}"}

      %Nx.Tensor{} = tensor ->
        validate_tensor(tensor)

      data when is_list(data) and data != [] ->
        tensor = Nx.tensor(data)
        validate_tensor(tensor)

      [] ->
        {:error, "Empty data at key #{inspect(opts.data_key)}"}

      other ->
        {:error, "Invalid data type: #{inspect(other)}"}
    end
  end

  @spec validate_tensor(Nx.Tensor.t()) :: {:ok, Nx.Tensor.t()} | {:error, String.t()}
  defp validate_tensor(tensor) do
    shape = Nx.shape(tensor)

    case shape do
      {} ->
        {:error, "Tensor must be 2D, got scalar"}

      {_} ->
        {:error, "Tensor must be 2D, got 1D"}

      {n, _d} when n >= 2 ->
        {:ok, tensor}

      {n, _d} ->
        {:error, "Need at least 2 points, got #{n}"}

      _ ->
        {:error, "Tensor must be 2D with shape {n, d}"}
    end
  end

  @spec compute_metrics(Nx.Tensor.t(), map()) :: map()
  defp compute_metrics(points, opts) do
    compute_flags = opts.compute

    # Build neighborhood graph if needed for betti or fragility
    graph =
      if :betti in compute_flags do
        {n, _d} = Nx.shape(points)
        k = min(opts.k, n - 1)
        Neighborhood.knn_graph(points, k: k)
      else
        nil
      end

    %{
      betti: if(:betti in compute_flags, do: compute_betti(graph)),
      persistence: if(:persistence in compute_flags, do: compute_persistence(points, opts)),
      fragility: if(:fragility in compute_flags, do: compute_fragility(points, opts)),
      embedding: if(:embedding in compute_flags, do: compute_embedding(points, opts))
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  @spec compute_betti(graph :: term()) :: map()
  defp compute_betti(graph) do
    %{
      beta_zero: Graph.beta_zero(graph),
      beta_one: Graph.beta_one(graph),
      euler_characteristic: Graph.euler_characteristic(graph),
      num_vertices: Graph.num_vertices(graph),
      num_edges: Graph.num_edges(graph),
      connected: Graph.connected?(graph)
    }
  end

  @spec compute_persistence(Nx.Tensor.t(), map()) :: map()
  defp compute_persistence(points, opts) do
    filtration = Filtration.vietoris_rips(points, max_dimension: opts.max_dimension)
    diagrams = Persistence.compute(filtration, max_dimension: opts.max_dimension)

    # Compute summary for each dimension
    summaries =
      diagrams
      |> Enum.map(fn d ->
        {d.dimension, Diagram.summary_statistics(d)}
      end)
      |> Map.new()

    total_persistence =
      diagrams
      |> Enum.map(&Diagram.total_persistence/1)
      |> Enum.sum()

    max_persistence =
      diagrams
      |> Enum.flat_map(fn d -> Diagram.persistences(d) end)
      |> Enum.reject(&(&1 == :infinity))
      |> case do
        [] -> 0.0
        persts -> Enum.max(persts)
      end

    %{
      diagrams: diagrams,
      summaries: summaries,
      total_persistence: total_persistence,
      max_persistence: max_persistence
    }
  end

  @spec compute_fragility(Nx.Tensor.t(), map()) :: map()
  defp compute_fragility(points, opts) do
    {n, _d} = Nx.shape(points)
    k = min(opts.k, n - 1)

    robustness = Fragility.robustness_score(points, k: k, num_samples: 5)
    sensitivities = Fragility.point_removal_sensitivity(points, max_dimension: 1)
    critical = Fragility.identify_critical_points(sensitivities, top_k: min(5, n))

    mean_sensitivity =
      case map_size(sensitivities) do
        0 -> 0.0
        size -> sensitivities |> Map.values() |> Enum.sum() |> Kernel./(size)
      end

    %{
      robustness_score: robustness,
      point_sensitivities: sensitivities,
      critical_points: critical,
      mean_sensitivity: mean_sensitivity
    }
  end

  @spec compute_embedding(Nx.Tensor.t(), map()) :: map()
  defp compute_embedding(points, opts) do
    {n, _d} = Nx.shape(points)
    k = min(opts.k, n - 1)

    stats = Embedding.statistics(points, k: k)
    variance = Embedding.knn_variance(points, k: k) |> Nx.to_number()

    Map.merge(stats, %{knn_variance: variance})
  end

  @spec merge_results(map(), map(), map()) :: map()
  defp merge_results(ctx, results, _opts) do
    # Build summary metrics for ctx.metrics[:tda]
    summary = build_summary(results)

    # Get existing metrics and assigns
    existing_metrics = Map.get(ctx, :metrics, %{})
    existing_assigns = Map.get(ctx, :assigns, %{})

    # Merge TDA summary into metrics
    new_metrics = Map.put(existing_metrics, :tda, summary)

    # Store detailed results in assigns
    new_assigns =
      existing_assigns
      |> maybe_put(:tda_diagrams, get_in(results, [:persistence, :diagrams]))
      |> maybe_put(:tda_fragility, results[:fragility])

    ctx
    |> Map.put(:metrics, new_metrics)
    |> Map.put(:assigns, new_assigns)
  end

  @spec build_summary(map()) :: map()
  defp build_summary(results) do
    summary = %{}

    summary =
      if betti = results[:betti] do
        Map.merge(summary, %{
          beta_zero: betti.beta_zero,
          beta_one: betti.beta_one,
          euler_characteristic: betti.euler_characteristic,
          num_vertices: betti.num_vertices,
          num_edges: betti.num_edges,
          connected: betti.connected
        })
      else
        summary
      end

    summary =
      if persistence = results[:persistence] do
        Map.merge(summary, %{
          total_persistence: persistence.total_persistence,
          max_persistence: persistence.max_persistence
        })
      else
        summary
      end

    summary =
      if fragility = results[:fragility] do
        Map.merge(summary, %{
          robustness_score: fragility.robustness_score,
          mean_sensitivity: fragility.mean_sensitivity
        })
      else
        summary
      end

    summary =
      if embedding = results[:embedding] do
        Map.merge(summary, %{
          knn_variance: embedding.knn_variance,
          mean_knn_distance: embedding.mean_knn_distance,
          density_mean: embedding.density_mean
        })
      else
        summary
      end

    summary
  end

  @spec maybe_put(map(), atom(), term()) :: map()
  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
