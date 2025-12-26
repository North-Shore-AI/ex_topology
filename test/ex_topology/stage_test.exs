defmodule ExTopology.StageTest do
  @moduledoc """
  Tests for ExTopology.Stage - Crucible.Stage implementation for TDA metrics.
  """
  use ExUnit.Case, async: true

  alias ExTopology.Stage

  # Define minimal context struct for testing without crucible_framework dependency
  defmodule TestContext do
    @moduledoc false
    defstruct [
      :experiment_id,
      :run_id,
      :experiment,
      assigns: %{},
      metrics: %{}
    ]
  end

  # Helper to create minimal context
  defp create_context(assigns) do
    %TestContext{
      experiment_id: "test-exp",
      run_id: "test-run",
      experiment: %{id: "test-exp", backend: %{id: :mock}},
      assigns: assigns,
      metrics: %{}
    }
  end

  describe "run/2 with valid points" do
    test "computes betti numbers when requested" do
      # Triangle - should have 1 component and 0 or 1 cycles depending on k
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [0.5, 0.866]])
      ctx = create_context(%{embeddings: points})

      {:ok, result_ctx} = Stage.run(ctx, %{compute: [:betti], k: 2})

      assert is_map(result_ctx.metrics[:tda])
      assert result_ctx.metrics[:tda][:beta_zero] >= 1
      assert is_integer(result_ctx.metrics[:tda][:beta_one])
      assert is_integer(result_ctx.metrics[:tda][:euler_characteristic])
    end

    test "computes persistence diagrams when requested" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [0.5, 0.866]])
      ctx = create_context(%{embeddings: points})

      {:ok, result_ctx} = Stage.run(ctx, %{compute: [:persistence]})

      assert is_number(result_ctx.metrics[:tda][:total_persistence])
      assert Map.has_key?(result_ctx.assigns, :tda_diagrams)
      assert is_list(result_ctx.assigns[:tda_diagrams])
    end

    test "computes fragility metrics when requested" do
      # Use more points for fragility analysis
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [2.0, 0.0], [3.0, 0.0]])
      ctx = create_context(%{embeddings: points})

      {:ok, result_ctx} = Stage.run(ctx, %{compute: [:fragility], k: 2})

      assert result_ctx.metrics[:tda][:robustness_score] >= 0.0
      assert result_ctx.metrics[:tda][:robustness_score] <= 1.0
      assert is_number(result_ctx.metrics[:tda][:mean_sensitivity])
      assert Map.has_key?(result_ctx.assigns, :tda_fragility)
    end

    test "computes embedding metrics when requested" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [2.0, 0.0], [3.0, 0.0]])
      ctx = create_context(%{embeddings: points})

      {:ok, result_ctx} = Stage.run(ctx, %{compute: [:embedding], k: 2})

      assert is_number(result_ctx.metrics[:tda][:knn_variance])
      assert is_number(result_ctx.metrics[:tda][:mean_knn_distance])
      assert is_number(result_ctx.metrics[:tda][:density_mean])
    end

    test "computes all metrics when requested" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [0.5, 0.866], [0.5, 0.3]])
      ctx = create_context(%{embeddings: points})

      {:ok, result_ctx} =
        Stage.run(ctx, %{
          compute: [:betti, :persistence, :fragility, :embedding],
          k: 2
        })

      tda_metrics = result_ctx.metrics[:tda]

      # Betti metrics
      assert Map.has_key?(tda_metrics, :beta_zero)
      assert Map.has_key?(tda_metrics, :beta_one)

      # Persistence metrics
      assert Map.has_key?(tda_metrics, :total_persistence)
      assert Map.has_key?(tda_metrics, :max_persistence)

      # Fragility metrics
      assert Map.has_key?(tda_metrics, :robustness_score)
      assert Map.has_key?(tda_metrics, :mean_sensitivity)

      # Embedding metrics
      assert Map.has_key?(tda_metrics, :knn_variance)
      assert Map.has_key?(tda_metrics, :mean_knn_distance)
      assert Map.has_key?(tda_metrics, :density_mean)
    end

    test "computes default metrics (betti and embedding) when no compute specified" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [2.0, 0.0]])
      ctx = create_context(%{embeddings: points})

      {:ok, result_ctx} = Stage.run(ctx, %{})

      tda_metrics = result_ctx.metrics[:tda]
      # Default: betti + embedding
      assert Map.has_key?(tda_metrics, :beta_zero)
      assert Map.has_key?(tda_metrics, :knn_variance)
    end
  end

  describe "run/2 with custom data_key" do
    test "reads from custom assigns key" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [2.0, 0.0]])
      ctx = create_context(%{my_points: points})

      {:ok, result_ctx} = Stage.run(ctx, %{data_key: :my_points, compute: [:betti], k: 1})

      assert Map.has_key?(result_ctx.metrics, :tda)
      assert is_integer(result_ctx.metrics[:tda][:beta_zero])
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

    test "returns error for insufficient points" do
      # Only 1 point - need at least 2
      ctx = create_context(%{embeddings: Nx.tensor([[0.0, 0.0]])})

      {:error, {:tda_stage_failed, reason}} = Stage.run(ctx, %{})

      assert reason =~ "at least 2 points"
    end
  end

  describe "describe/1" do
    test "returns stage metadata with specified options" do
      description = Stage.describe(%{compute: [:betti], k: 5})

      assert description.stage == "ExTopology.Stage"
      assert description.compute == [:betti]
      assert description.k == 5
      assert is_binary(description.description)
    end

    test "uses defaults when opts empty" do
      description = Stage.describe(%{})

      assert description.compute == [:betti, :embedding]
      assert description.k == 10
      assert description.max_dimension == 1
    end

    test "uses defaults when opts nil" do
      description = Stage.describe(nil)

      assert description.compute == [:betti, :embedding]
      assert description.k == 10
    end
  end

  describe "options normalization" do
    test "accepts keyword list options" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [2.0, 0.0]])
      ctx = create_context(%{embeddings: points})

      {:ok, _} = Stage.run(ctx, compute: [:betti], k: 2)
    end

    test "accepts nil options (uses defaults)" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [2.0, 0.0]])
      ctx = create_context(%{embeddings: points})

      {:ok, result_ctx} = Stage.run(ctx, nil)

      assert Map.has_key?(result_ctx.metrics, :tda)
    end

    test "accepts map options" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [2.0, 0.0]])
      ctx = create_context(%{embeddings: points})

      {:ok, result_ctx} = Stage.run(ctx, %{compute: [:betti], k: 2})

      assert Map.has_key?(result_ctx.metrics, :tda)
    end
  end

  describe "integration: pipeline usage" do
    test "preserves existing metrics when adding TDA metrics" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [0.5, 0.866]])
      ctx = create_context(%{embeddings: points})
      ctx = %{ctx | metrics: %{accuracy: 0.95, loss: 0.05}}

      {:ok, result_ctx} = Stage.run(ctx, %{compute: [:betti], k: 2})

      # Original metrics preserved
      assert result_ctx.metrics[:accuracy] == 0.95
      assert result_ctx.metrics[:loss] == 0.05
      # TDA metrics added
      assert Map.has_key?(result_ctx.metrics, :tda)
    end

    test "preserves existing assigns when adding TDA results" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [0.5, 0.866]])
      ctx = create_context(%{embeddings: points, other_data: "preserved"})

      {:ok, result_ctx} = Stage.run(ctx, %{compute: [:persistence]})

      assert result_ctx.assigns[:other_data] == "preserved"
      assert Map.has_key?(result_ctx.assigns, :tda_diagrams)
    end
  end

  describe "accepts list data" do
    test "converts list input to tensor and computes metrics" do
      points = [[0.0, 0.0], [1.0, 0.0], [2.0, 0.0]]
      ctx = create_context(%{embeddings: points})

      {:ok, result_ctx} = Stage.run(ctx, %{compute: [:betti], k: 1})

      assert Map.has_key?(result_ctx.metrics, :tda)
    end
  end
end
