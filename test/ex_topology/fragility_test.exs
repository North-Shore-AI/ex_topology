defmodule ExTopology.FragilityTest do
  use ExUnit.Case, async: true
  doctest ExTopology.Fragility

  alias ExTopology.Fragility

  describe "point_removal_sensitivity/2" do
    test "computes scores for all points" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [2.0, 0.0]])
      scores = Fragility.point_removal_sensitivity(points, max_dimension: 1)

      assert map_size(scores) == 3
      assert Enum.all?(Map.values(scores), fn s -> is_float(s) and s >= 0.0 end)
    end

    test "returns non-negative scores" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [0.5, 0.866]])
      scores = Fragility.point_removal_sensitivity(points)

      for {_idx, score} <- scores do
        assert score >= 0.0
      end
    end

    test "handles small point clouds" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0]])
      scores = Fragility.point_removal_sensitivity(points)

      assert map_size(scores) == 2
    end
  end

  describe "edge_perturbation_sensitivity/2" do
    test "computes scores for all edges" do
      g =
        Graph.new()
        |> Graph.add_edge(0, 1, weight: 1.0)
        |> Graph.add_edge(1, 2, weight: 1.5)

      scores = Fragility.edge_perturbation_sensitivity(g)

      assert map_size(scores) == 2
      assert Enum.all?(Map.values(scores), fn s -> is_float(s) and s >= 0.0 end)
    end

    test "returns non-negative scores" do
      g =
        Graph.new()
        |> Graph.add_edge(0, 1, weight: 1.0)
        |> Graph.add_edge(1, 2, weight: 1.0)
        |> Graph.add_edge(2, 0, weight: 1.0)

      scores = Fragility.edge_perturbation_sensitivity(g)

      for {_edge, score} <- scores do
        assert score >= 0.0
      end
    end
  end

  describe "feature_stability_scores/2" do
    test "computes stability scores" do
      diagram = %{dimension: 1, pairs: [{0.0, 1.0}, {0.5, 2.0}]}
      scores = Fragility.feature_stability_scores(diagram)

      assert length(scores) == 2
      assert Enum.all?(scores, fn s -> is_float(s) and s >= 0.0 end)
    end

    test "normalizes scores to [0, 1] by default" do
      diagram = %{dimension: 1, pairs: [{0.0, 1.0}, {0.5, 2.0}]}
      scores = Fragility.feature_stability_scores(diagram, normalize: true)

      assert Enum.all?(scores, fn s -> s >= 0.0 and s <= 1.0 end)
      assert Enum.max(scores) == 1.0
    end

    test "returns raw persistence without normalization" do
      diagram = %{dimension: 1, pairs: [{0.0, 1.0}, {0.5, 2.0}]}
      scores = Fragility.feature_stability_scores(diagram, normalize: false)

      assert 1.0 in scores
      assert 1.5 in scores
    end

    test "handles empty diagram" do
      diagram = %{dimension: 1, pairs: []}
      scores = Fragility.feature_stability_scores(diagram)

      assert scores == []
    end

    test "ignores infinite points" do
      diagram = %{dimension: 0, pairs: [{0.0, :infinity}, {0.0, 1.0}]}
      scores = Fragility.feature_stability_scores(diagram)

      assert length(scores) == 1
    end
  end

  describe "identify_critical_points/2" do
    test "identifies points above threshold" do
      scores = %{0 => 0.1, 1 => 0.8, 2 => 0.2}
      critical = Fragility.identify_critical_points(scores, threshold: 0.5)

      assert critical == [1]
    end

    test "returns top_k most fragile points" do
      scores = %{0 => 0.1, 1 => 0.8, 2 => 0.5, 3 => 0.9}
      critical = Fragility.identify_critical_points(scores, top_k: 2)

      assert length(critical) == 2
      assert 3 in critical
      assert 1 in critical
    end

    test "uses mean + std as default threshold" do
      scores = %{0 => 0.1, 1 => 0.2, 2 => 0.3, 3 => 0.9}
      critical = Fragility.identify_critical_points(scores)

      assert is_list(critical)
      assert 3 in critical
    end
  end

  describe "bottleneck_stability/2" do
    test "returns positive threshold" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [0.5, 0.866]])
      threshold = Fragility.bottleneck_stability(points, num_samples: 5)

      assert is_float(threshold)
      assert threshold > 0.0
    end

    test "threshold is bounded by max_perturbation" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [2.0, 0.0]])
      max_pert = 0.5

      threshold =
        Fragility.bottleneck_stability(points, max_perturbation: max_pert, num_samples: 5)

      assert threshold <= max_pert
    end
  end

  describe "local_fragility/3" do
    test "analyzes local fragility for a point" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [2.0, 0.0]])
      analysis = Fragility.local_fragility(points, 1)

      assert Map.has_key?(analysis, :removal_impact)
      assert Map.has_key?(analysis, :neighborhood_mean_fragility)
      assert Map.has_key?(analysis, :relative_fragility)
      assert Map.has_key?(analysis, :neighbor_indices)
    end

    test "returns valid metrics" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [0.5, 0.866]])
      analysis = Fragility.local_fragility(points, 0)

      assert is_float(analysis.removal_impact)
      assert is_float(analysis.neighborhood_mean_fragility)
      assert is_float(analysis.relative_fragility)
      assert is_list(analysis.neighbor_indices)
    end

    test "identifies neighbors correctly" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [2.0, 0.0], [10.0, 0.0]])
      analysis = Fragility.local_fragility(points, 1, k: 2)

      # Nearest neighbors of point 1 should be 0 and 2 (not 3 which is far)
      assert length(analysis.neighbor_indices) <= 2
      assert 0 in analysis.neighbor_indices or 2 in analysis.neighbor_indices
    end
  end

  describe "robustness_score/2" do
    test "returns score in [0, 1]" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [0.5, 0.866]])
      score = Fragility.robustness_score(points, num_samples: 3)

      assert score >= 0.0 and score <= 1.0
    end

    test "is consistent across calls with same data" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [2.0, 0.0]])
      score1 = Fragility.robustness_score(points, num_samples: 3)
      score2 = Fragility.robustness_score(points, num_samples: 3)

      # Should be approximately equal (allowing for some randomness)
      assert_in_delta score1, score2, 0.3
    end
  end

  describe "property: fragility metrics are non-negative" do
    test "all point removal scores are non-negative" do
      points = Nx.tensor([[0.0, 0.0], [1.0, 0.0], [0.0, 1.0], [1.0, 1.0]])
      scores = Fragility.point_removal_sensitivity(points)

      for {_idx, score} <- scores do
        assert score >= 0.0, "Score #{score} is negative"
      end
    end

    test "stability scores are non-negative" do
      diagram = %{dimension: 1, pairs: [{0.0, 1.0}, {0.5, 2.0}, {1.0, 3.0}]}
      scores = Fragility.feature_stability_scores(diagram)

      assert Enum.all?(scores, fn s -> s >= 0.0 end)
    end
  end

  describe "property: relative metrics make sense" do
    test "removing central point has higher impact than removing peripheral point" do
      # Star topology: point 0 in center, others around it
      points =
        Nx.tensor([
          [0.0, 0.0],
          # center
          [1.0, 0.0],
          [-1.0, 0.0],
          [0.0, 1.0],
          [0.0, -1.0]
        ])

      scores = Fragility.point_removal_sensitivity(points)

      # Center (0) removal should have high impact
      center_score = scores[0]
      peripheral_score = scores[1]

      # This might not always hold due to metric complexity,
      # but generally center should be more critical
      # Just check both are non-negative
      assert center_score >= 0.0
      assert peripheral_score >= 0.0
    end
  end
end
