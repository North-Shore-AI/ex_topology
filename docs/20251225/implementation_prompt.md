# Implementation Prompt: ExTopology.Stage

**Date**: 2025-12-25
**Task**: Implement a Crucible.Stage wrapper for ExTopology TDA metrics

## Objective

Create `ExTopology.Stage` module that implements the `Crucible.Stage` behaviour, allowing ExTopology's TDA metrics to be used directly in Crucible experiment pipelines.

---

## Required Reading

Before implementing, read these files thoroughly:

### Core Interface (MUST READ)

1. **Crucible.Stage behaviour**:
   `/home/home/p/g/North-Shore-AI/crucible_framework/lib/crucible/stage.ex`
   - Lines 1-18: Full behaviour definition
   - Callbacks: `run/2`, `describe/1` (optional)

2. **Crucible.Context**:
   `/home/home/p/g/North-Shore-AI/crucible_framework/lib/crucible/context.ex`
   - Lines 68-101: Struct definition
   - Lines 107-165: Metrics helpers (`put_metric`, `merge_metrics`)
   - Lines 274-293: Assigns helpers (`assign`)

3. **Example Stage Implementation**:
   `/home/home/p/g/North-Shore-AI/crucible_framework/lib/crucible/stage/analysis/tda_validation.ex`
   - Lines 1-59: Complete TDA stage example using adapter pattern

### ExTopology Modules (MUST READ)

4. **ExTopology.Graph** (Betti numbers):
   `/home/home/p/g/North-Shore-AI/ex_topology/lib/ex_topology/graph.ex`
   - Lines 77-82: `beta_zero/1`
   - Lines 134-143: `beta_one/1`
   - Lines 190-193: `euler_characteristic/1`
   - Lines 376-397: `invariants/1`

5. **ExTopology.Filtration**:
   `/home/home/p/g/North-Shore-AI/ex_topology/lib/ex_topology/filtration.ex`
   - Lines 65-80: `vietoris_rips/2`

6. **ExTopology.Persistence**:
   `/home/home/p/g/North-Shore-AI/ex_topology/lib/ex_topology/persistence.ex`
   - Lines 71-84: `compute/2`
   - Lines 112-126: `betti_numbers/3`

7. **ExTopology.Diagram**:
   `/home/home/p/g/North-Shore-AI/ex_topology/lib/ex_topology/diagram.ex`
   - Lines 87-93: `total_persistence/1`
   - Lines 246-271: `entropy/1`
   - Lines 298-317: `summary_statistics/1`

8. **ExTopology.Fragility**:
   `/home/home/p/g/North-Shore-AI/ex_topology/lib/ex_topology/fragility.ex`
   - Lines 66-94: `point_removal_sensitivity/2`
   - Lines 441-457: `robustness_score/2`

9. **ExTopology.Embedding**:
   `/home/home/p/g/North-Shore-AI/ex_topology/lib/ex_topology/embedding.ex`
   - Lines 70-93: `knn_variance/2`
   - Lines 281-302: `statistics/2`

10. **ExTopology.Neighborhood**:
    `/home/home/p/g/North-Shore-AI/ex_topology/lib/ex_topology/neighborhood.ex`
    - Lines 81-105: `knn_graph/2`

### Test References

11. **Existing Stage Tests**:
    `/home/home/p/g/North-Shore-AI/crucible_framework/test/crucible/stage/bench_test.exs`
    - Example test structure

12. **Fragility Tests**:
    `/home/home/p/g/North-Shore-AI/ex_topology/test/ex_topology/fragility_test.exs`
    - Lines 1-240: Test patterns for fragility

---

## Implementation Specification

### File Location

Create: `/home/home/p/g/North-Shore-AI/ex_topology/lib/ex_topology/stage.ex`

### Module Structure

```elixir
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
  """

  @behaviour Crucible.Stage

  alias Crucible.Context
  alias ExTopology.{Graph, Neighborhood, Filtration, Persistence, Diagram, Fragility, Embedding}

  @default_opts %{
    data_key: :embeddings,
    compute: [:betti, :embedding],
    k: 10,
    max_dimension: 1
  }

  @impl true
  def run(%Context{} = ctx, opts) do
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

  @impl true
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

  # Private implementation functions...
end
```

### Key Functions to Implement

#### 1. `normalize_opts/1`

```elixir
defp normalize_opts(nil), do: @default_opts
defp normalize_opts(opts) when is_list(opts), do: Map.merge(@default_opts, Map.new(opts))
defp normalize_opts(opts) when is_map(opts), do: Map.merge(@default_opts, opts)
```

#### 2. `get_points/2`

Extract Nx tensor from context:

```elixir
defp get_points(%Context{assigns: assigns}, opts) do
  case Map.get(assigns, opts.data_key) do
    nil -> {:error, "No data found at key #{inspect(opts.data_key)}"}
    %Nx.Tensor{} = tensor -> {:ok, tensor}
    data when is_list(data) -> {:ok, Nx.tensor(data)}
    other -> {:error, "Invalid data type: #{inspect(other)}"}
  end
end
```

#### 3. `compute_metrics/2`

Main computation logic:

```elixir
defp compute_metrics(points, opts) do
  compute_flags = opts.compute

  # Build neighborhood graph for Betti numbers
  graph = if :betti in compute_flags or :fragility in compute_flags do
    Neighborhood.knn_graph(points, k: opts.k)
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
```

#### 4. `compute_betti/1`

```elixir
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
```

#### 5. `compute_persistence/2`

```elixir
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

  %{
    diagrams: diagrams,
    summaries: summaries,
    total_persistence: Enum.map(diagrams, &Diagram.total_persistence/1) |> Enum.sum(),
    max_persistence: diagrams
      |> Enum.flat_map(fn d -> Diagram.persistences(d) end)
      |> Enum.reject(&(&1 == :infinity))
      |> Enum.max(fn -> 0.0 end)
  }
end
```

#### 6. `compute_fragility/2`

```elixir
defp compute_fragility(points, opts) do
  robustness = Fragility.robustness_score(points, k: opts.k, num_samples: 5)
  sensitivities = Fragility.point_removal_sensitivity(points, max_dimension: 1)
  critical = Fragility.identify_critical_points(sensitivities, top_k: 5)

  %{
    robustness_score: robustness,
    point_sensitivities: sensitivities,
    critical_points: critical,
    mean_sensitivity: sensitivities |> Map.values() |> Enum.sum() |> Kernel./(map_size(sensitivities))
  }
end
```

#### 7. `compute_embedding/2`

```elixir
defp compute_embedding(points, opts) do
  stats = Embedding.statistics(points, k: opts.k)
  variance = Embedding.knn_variance(points, k: opts.k) |> Nx.to_number()

  Map.merge(stats, %{knn_variance: variance})
end
```

#### 8. `merge_results/3`

```elixir
defp merge_results(ctx, results, _opts) do
  # Build summary metrics for ctx.metrics[:tda]
  summary = build_summary(results)

  # Store detailed results in assigns
  ctx
  |> Context.merge_metrics(%{tda: summary})
  |> maybe_assign(:tda_diagrams, get_in(results, [:persistence, :diagrams]))
  |> maybe_assign(:tda_fragility, results[:fragility])
end

defp build_summary(results) do
  summary = %{}

  summary = if betti = results[:betti] do
    Map.merge(summary, %{
      beta_zero: betti.beta_zero,
      beta_one: betti.beta_one,
      euler_characteristic: betti.euler_characteristic
    })
  else
    summary
  end

  summary = if persistence = results[:persistence] do
    Map.merge(summary, %{
      total_persistence: persistence.total_persistence,
      max_persistence: persistence.max_persistence
    })
  else
    summary
  end

  summary = if fragility = results[:fragility] do
    Map.merge(summary, %{
      robustness_score: fragility.robustness_score,
      mean_sensitivity: fragility.mean_sensitivity
    })
  else
    summary
  end

  summary = if embedding = results[:embedding] do
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

defp maybe_assign(ctx, _key, nil), do: ctx
defp maybe_assign(ctx, key, value), do: Context.assign(ctx, key, value)
```

---

## Test Specification

Create: `/home/home/p/g/North-Shore-AI/ex_topology/test/ex_topology/stage_test.exs`

### Test Structure (TDD Approach)

```elixir
defmodule ExTopology.StageTest do
  use ExUnit.Case, async: true

  alias ExTopology.Stage
  alias Crucible.Context

  # Helper to create minimal context
  defp create_context(assigns \\ %{}) do
    %Context{
      experiment_id: "test-exp",
      run_id: "test-run",
      experiment: %CrucibleIR.Experiment{
        id: "test-exp",
        backend: %CrucibleIR.BackendRef{id: :mock}
      },
      assigns: assigns,
      metrics: %{}
    }
  end

  describe "run/2 with valid points" do
    test "computes betti numbers by default" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [0.5, 0.866]])
      ctx = create_context(%{embeddings: points})

      {:ok, result_ctx} = Stage.run(ctx, %{compute: [:betti]})

      assert result_ctx.metrics[:tda][:beta_zero] >= 1
      assert is_integer(result_ctx.metrics[:tda][:beta_one])
    end

    test "computes persistence diagrams" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [0.5, 0.866]])
      ctx = create_context(%{embeddings: points})

      {:ok, result_ctx} = Stage.run(ctx, %{compute: [:persistence]})

      assert is_number(result_ctx.metrics[:tda][:total_persistence])
      assert Map.has_key?(result_ctx.assigns, :tda_diagrams)
    end

    test "computes fragility metrics" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [2.0, 0.0], [3.0, 0.0]])
      ctx = create_context(%{embeddings: points})

      {:ok, result_ctx} = Stage.run(ctx, %{compute: [:fragility]})

      assert result_ctx.metrics[:tda][:robustness_score] >= 0.0
      assert result_ctx.metrics[:tda][:robustness_score] <= 1.0
    end

    test "computes embedding metrics" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [2.0, 0.0], [3.0, 0.0]])
      ctx = create_context(%{embeddings: points})

      {:ok, result_ctx} = Stage.run(ctx, %{compute: [:embedding], k: 2})

      assert is_number(result_ctx.metrics[:tda][:knn_variance])
      assert is_number(result_ctx.metrics[:tda][:mean_knn_distance])
    end

    test "computes all metrics when requested" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [0.5, 0.866], [0.5, 0.3]])
      ctx = create_context(%{embeddings: points})

      {:ok, result_ctx} = Stage.run(ctx, %{
        compute: [:betti, :persistence, :fragility, :embedding],
        k: 2
      })

      tda_metrics = result_ctx.metrics[:tda]
      assert Map.has_key?(tda_metrics, :beta_zero)
      assert Map.has_key?(tda_metrics, :total_persistence)
      assert Map.has_key?(tda_metrics, :robustness_score)
      assert Map.has_key?(tda_metrics, :knn_variance)
    end
  end

  describe "run/2 with custom data_key" do
    test "reads from custom assigns key" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0]])
      ctx = create_context(%{my_points: points})

      {:ok, result_ctx} = Stage.run(ctx, %{data_key: :my_points, compute: [:betti]})

      assert Map.has_key?(result_ctx.metrics, :tda)
    end
  end

  describe "run/2 error handling" do
    test "returns error when data key not found" do
      ctx = create_context(%{})

      {:error, {:tda_stage_failed, reason}} = Stage.run(ctx, %{})

      assert reason =~ "No data found"
    end

    test "returns error for invalid data type" do
      ctx = create_context(%{embeddings: "not a tensor"})

      {:error, {:tda_stage_failed, reason}} = Stage.run(ctx, %{})

      assert reason =~ "Invalid data type"
    end
  end

  describe "describe/1" do
    test "returns stage metadata" do
      description = Stage.describe(%{compute: [:betti], k: 5})

      assert description.stage == "ExTopology.Stage"
      assert description.compute == [:betti]
      assert description.k == 5
    end

    test "uses defaults when opts empty" do
      description = Stage.describe(%{})

      assert description.compute == [:betti, :embedding]
      assert description.k == 10
    end
  end

  describe "options normalization" do
    test "accepts keyword list options" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0]])
      ctx = create_context(%{embeddings: points})

      {:ok, _} = Stage.run(ctx, [compute: [:betti], k: 5])
    end

    test "accepts nil options (uses defaults)" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [2.0, 0.0]])
      ctx = create_context(%{embeddings: points})

      {:ok, result_ctx} = Stage.run(ctx, nil)

      assert Map.has_key?(result_ctx.metrics, :tda)
    end
  end

  describe "integration: pipeline usage" do
    test "can be used after other stages modify context" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [0.5, 0.866]])
      ctx = create_context(%{embeddings: points})
      ctx = %{ctx | metrics: %{accuracy: 0.95, loss: 0.05}}

      {:ok, result_ctx} = Stage.run(ctx, %{compute: [:betti]})

      # Original metrics preserved
      assert result_ctx.metrics[:accuracy] == 0.95
      assert result_ctx.metrics[:loss] == 0.05
      # TDA metrics added
      assert Map.has_key?(result_ctx.metrics, :tda)
    end
  end
end
```

---

## Implementation Steps (TDD)

### Step 1: Create Test File

1. Create `/home/home/p/g/North-Shore-AI/ex_topology/test/ex_topology/stage_test.exs`
2. Add the test structure above
3. Run `mix test test/ex_topology/stage_test.exs` - all tests should fail

### Step 2: Add Dependency (if needed)

If ex_topology needs crucible_framework as a dependency:

```elixir
# In mix.exs deps
{:crucible_framework, path: "../crucible_framework", only: [:dev, :test]}
```

Or make it optional:

```elixir
{:crucible_framework, path: "../crucible_framework", optional: true}
```

**Alternative**: Define the Stage behaviour locally to avoid circular dependency.

### Step 3: Implement Basic Structure

1. Create `/home/home/p/g/North-Shore-AI/ex_topology/lib/ex_topology/stage.ex`
2. Implement module with `@behaviour Crucible.Stage`
3. Implement `run/2` returning `{:error, :not_implemented}`
4. Run tests - should see "not_implemented" errors

### Step 4: Implement Core Functions

Implement in order:
1. `normalize_opts/1`
2. `get_points/2` - run tests, error handling tests should pass
3. `compute_betti/1` - run tests, betti tests should pass
4. `compute_embedding/2` - run tests, embedding tests should pass
5. `compute_persistence/2` - run tests, persistence tests should pass
6. `compute_fragility/2` - run tests, fragility tests should pass
7. `merge_results/3` - all tests should pass

### Step 5: Run Full Test Suite

```bash
cd /home/home/p/g/North-Shore-AI/ex_topology
mix test
```

Ensure no regressions.

### Step 6: Quality Checks

```bash
mix format
mix credo --strict
mix dialyzer
```

All must pass with no warnings.

### Step 7: Update README.md

Add section to README about Stage usage:

```markdown
## Crucible Integration

ExTopology can be used as a stage in Crucible experiment pipelines:

\`\`\`elixir
pipeline = [
  {Crucible.Stage.DataLoad, %{dataset: "embeddings"}},
  {ExTopology.Stage, %{
    data_key: :embeddings,
    compute: [:betti, :persistence, :fragility, :embedding],
    k: 10,
    max_dimension: 1
  }}
]
\`\`\`

The stage computes TDA metrics and stores them in `ctx.metrics[:tda]`.
\`\`\`
```

---

## Quality Requirements

### No Warnings

```bash
mix compile --warnings-as-errors
```

### Dialyzer Clean

```bash
mix dialyzer
```

All specs must be correct and no unknown functions called.

### Credo Strict

```bash
mix credo --strict
```

No issues allowed.

### All Tests Passing

```bash
mix test
```

All 371+ tests must pass.

### Documentation

- All public functions have `@doc`
- All public functions have `@spec`
- Module has `@moduledoc`
- Examples in docs are accurate

---

## Optional Enhancements

After core implementation:

### 1. Add Typespec for Options

```elixir
@type opts :: %{
  optional(:data_key) => atom(),
  optional(:compute) => [:betti | :persistence | :fragility | :embedding],
  optional(:k) => pos_integer(),
  optional(:max_dimension) => pos_integer(),
  optional(:epsilon) => float()
}
```

### 2. Add Telemetry Events

```elixir
defp compute_metrics(points, opts) do
  :telemetry.span(
    [:ex_topology, :stage, :compute],
    %{opts: opts},
    fn ->
      result = do_compute_metrics(points, opts)
      {result, %{metrics: Map.keys(result)}}
    end
  )
end
```

### 3. Add Progress Logging

```elixir
require Logger

defp compute_betti(graph) do
  Logger.debug("Computing Betti numbers...")
  # ...
end
```

---

## Checklist

Before marking complete:

- [ ] Tests written first (TDD)
- [ ] All tests passing
- [ ] `mix format` applied
- [ ] `mix credo --strict` passes
- [ ] `mix dialyzer` passes
- [ ] No compiler warnings
- [ ] Module has `@moduledoc`
- [ ] All public functions have `@doc`
- [ ] All public functions have `@spec`
- [ ] README.md updated with Stage usage
- [ ] Example usage works

---

## File Summary

Files to create:
1. `/home/home/p/g/North-Shore-AI/ex_topology/lib/ex_topology/stage.ex`
2. `/home/home/p/g/North-Shore-AI/ex_topology/test/ex_topology/stage_test.exs`

Files to update:
1. `/home/home/p/g/North-Shore-AI/ex_topology/README.md` - Add Crucible integration section
2. `/home/home/p/g/North-Shore-AI/ex_topology/lib/ex_topology.ex` - Fix version to "0.1.1"
3. `/home/home/p/g/North-Shore-AI/ex_topology/mix.exs` - Add optional crucible_framework dep (if needed)
