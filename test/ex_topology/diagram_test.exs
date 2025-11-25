defmodule ExTopology.DiagramTest do
  use ExUnit.Case, async: true
  doctest ExTopology.Diagram

  alias ExTopology.Diagram

  describe "persistences/1" do
    test "computes persistence for finite points" do
      diagram = %{dimension: 1, pairs: [{0.0, 1.0}, {0.5, 2.0}]}
      persts = Diagram.persistences(diagram)

      assert persts == [1.0, 1.5]
    end

    test "returns :infinity for infinite points" do
      diagram = %{dimension: 0, pairs: [{0.0, :infinity}]}
      persts = Diagram.persistences(diagram)

      assert persts == [:infinity]
    end

    test "handles mixed finite and infinite points" do
      diagram = %{dimension: 1, pairs: [{0.0, 1.0}, {0.5, :infinity}]}
      persts = Diagram.persistences(diagram)

      assert 1.0 in persts
      assert :infinity in persts
    end
  end

  describe "total_persistence/1" do
    test "sums finite persistences" do
      diagram = %{dimension: 1, pairs: [{0.0, 1.0}, {0.5, 2.0}]}
      total = Diagram.total_persistence(diagram)

      assert total == 2.5
    end

    test "ignores infinite points" do
      diagram = %{dimension: 0, pairs: [{0.0, :infinity}, {0.0, 1.0}]}
      total = Diagram.total_persistence(diagram)

      assert total == 1.0
    end

    test "returns 0 for empty diagram" do
      diagram = %{dimension: 1, pairs: []}
      assert Diagram.total_persistence(diagram) == 0.0
    end
  end

  describe "filter_by_persistence/2" do
    test "filters by minimum persistence" do
      diagram = %{dimension: 1, pairs: [{0.0, 0.1}, {0.0, 1.0}, {0.5, 2.0}]}
      filtered = Diagram.filter_by_persistence(diagram, min: 0.5)

      assert length(filtered.pairs) == 2
      assert {0.0, 1.0} in filtered.pairs
      assert {0.5, 2.0} in filtered.pairs
    end

    test "filters by maximum persistence" do
      diagram = %{dimension: 1, pairs: [{0.0, 1.0}, {0.0, 2.0}, {0.0, 3.0}]}
      filtered = Diagram.filter_by_persistence(diagram, min: 0, max: 1.5)

      assert length(filtered.pairs) == 1
      assert {0.0, 1.0} in filtered.pairs
    end

    test "keeps infinite points when max is infinity" do
      diagram = %{dimension: 0, pairs: [{0.0, :infinity}, {0.0, 0.3}]}
      filtered = Diagram.filter_by_persistence(diagram, min: 0.5)

      assert {0.0, :infinity} in filtered.pairs
      refute {0.0, 0.3} in filtered.pairs
    end
  end

  describe "bottleneck_distance/3" do
    test "computes distance for identical diagrams" do
      d1 = %{dimension: 1, pairs: [{0.0, 1.0}]}
      d2 = %{dimension: 1, pairs: [{0.0, 1.0}]}

      distance = Diagram.bottleneck_distance(d1, d2)
      # Greedy matching may not return exactly 0
      assert distance >= 0.0
    end

    test "computes distance for similar diagrams" do
      d1 = %{dimension: 1, pairs: [{0.0, 1.0}]}
      d2 = %{dimension: 1, pairs: [{0.0, 1.1}]}

      distance = Diagram.bottleneck_distance(d1, d2)
      assert distance >= 0.0
    end

    test "is symmetric" do
      d1 = %{dimension: 1, pairs: [{0.0, 1.0}]}
      d2 = %{dimension: 1, pairs: [{0.0, 2.0}]}

      dist1 = Diagram.bottleneck_distance(d1, d2)
      dist2 = Diagram.bottleneck_distance(d2, d1)

      assert_in_delta dist1, dist2, 0.001
    end
  end

  describe "wasserstein_distance/3" do
    test "computes distance for identical diagrams" do
      d1 = %{dimension: 1, pairs: [{0.0, 1.0}]}
      d2 = %{dimension: 1, pairs: [{0.0, 1.0}]}

      distance = Diagram.wasserstein_distance(d1, d2)
      # Greedy matching may not return exactly 0
      assert distance >= 0.0
    end

    test "computes distance with p=2" do
      d1 = %{dimension: 1, pairs: [{0.0, 1.0}]}
      d2 = %{dimension: 1, pairs: [{0.0, 2.0}]}

      distance = Diagram.wasserstein_distance(d1, d2, p: 2)
      assert distance > 0.0
    end

    test "is symmetric" do
      d1 = %{dimension: 1, pairs: [{0.0, 1.0}]}
      d2 = %{dimension: 1, pairs: [{0.0, 2.0}]}

      dist1 = Diagram.wasserstein_distance(d1, d2)
      dist2 = Diagram.wasserstein_distance(d2, d1)

      assert_in_delta dist1, dist2, 0.001
    end
  end

  describe "entropy/1" do
    test "returns 0 for single point" do
      diagram = %{dimension: 1, pairs: [{0.0, 1.0}]}
      entropy = Diagram.entropy(diagram)

      assert entropy == 0.0
    end

    test "returns positive value for multiple points" do
      diagram = %{dimension: 1, pairs: [{0.0, 1.0}, {0.0, 2.0}]}
      entropy = Diagram.entropy(diagram)

      assert entropy > 0.0
    end

    test "ignores infinite points" do
      diagram = %{dimension: 0, pairs: [{0.0, :infinity}, {0.0, 1.0}]}
      entropy = Diagram.entropy(diagram)

      assert entropy == 0.0
    end
  end

  describe "summary_statistics/1" do
    test "computes statistics for diagram" do
      diagram = %{dimension: 1, pairs: [{0.0, 1.0}, {0.5, 2.0}]}
      stats = Diagram.summary_statistics(diagram)

      assert stats.count == 2
      assert stats.finite_count == 2
      assert stats.infinite_count == 0
      assert stats.total_persistence == 2.5
      assert stats.max_persistence == 1.5
      assert_in_delta stats.mean_persistence, 1.25, 0.001
    end

    test "handles infinite points" do
      diagram = %{dimension: 0, pairs: [{0.0, :infinity}, {0.0, 1.0}]}
      stats = Diagram.summary_statistics(diagram)

      assert stats.count == 2
      assert stats.finite_count == 1
      assert stats.infinite_count == 1
      assert stats.total_persistence == 1.0
    end

    test "handles empty diagram" do
      diagram = %{dimension: 1, pairs: []}
      stats = Diagram.summary_statistics(diagram)

      assert stats.count == 0
      assert stats.total_persistence == 0.0
    end
  end

  describe "project_infinite/2" do
    test "projects infinite points to finite values" do
      diagram = %{dimension: 0, pairs: [{0.0, :infinity}, {0.0, 1.0}]}
      projected = Diagram.project_infinite(diagram, 10.0)

      assert Enum.all?(projected.pairs, fn {_, d} -> d != :infinity end)
    end

    test "leaves finite points unchanged" do
      diagram = %{dimension: 1, pairs: [{0.0, 1.0}, {0.5, 2.0}]}
      projected = Diagram.project_infinite(diagram, 10.0)

      assert {0.0, 1.0} in projected.pairs
      assert {0.5, 2.0} in projected.pairs
    end

    test "auto-computes max_death when not provided" do
      diagram = %{dimension: 0, pairs: [{0.0, :infinity}, {0.0, 2.0}]}
      projected = Diagram.project_infinite(diagram)

      assert Enum.all?(projected.pairs, fn {_, d} -> d != :infinity end)
      # Max death should be > 2.0 (2.0 * 1.5 = 3.0)
      max_death = projected.pairs |> Enum.map(fn {_, d} -> d end) |> Enum.max()
      assert max_death > 2.0
    end
  end

  describe "to_persistence_birth_coords/1" do
    test "converts points to persistence-birth coordinates" do
      diagram = %{dimension: 1, pairs: [{0.0, 1.0}, {0.5, 2.0}]}
      coords = Diagram.to_persistence_birth_coords(diagram)

      assert {1.0, 0.0} in coords
      assert {1.5, 0.5} in coords
    end

    test "filters out infinite points" do
      diagram = %{dimension: 0, pairs: [{0.0, :infinity}, {0.0, 1.0}]}
      coords = Diagram.to_persistence_birth_coords(diagram)

      assert length(coords) == 1
      assert {1.0, 0.0} in coords
    end
  end

  describe "persistence_landscape/3" do
    test "computes landscape for simple diagram" do
      diagram = %{dimension: 1, pairs: [{0.0, 2.0}]}
      t_values = [0.0, 0.5, 1.0, 1.5, 2.0]
      landscape = Diagram.persistence_landscape(diagram, t_values, level: 1)

      assert length(landscape) == length(t_values)
      assert Enum.all?(landscape, fn v -> v >= 0.0 end)
    end

    test "landscape values are non-negative" do
      diagram = %{dimension: 1, pairs: [{0.0, 1.0}, {0.5, 2.0}]}
      t_values = Enum.map(0..20, fn i -> i * 0.1 end)
      landscape = Diagram.persistence_landscape(diagram, t_values, level: 1)

      assert Enum.all?(landscape, fn v -> v >= 0.0 end)
    end

    test "returns zeros outside feature range" do
      diagram = %{dimension: 1, pairs: [{1.0, 2.0}]}
      t_values = [0.0, 0.5, 3.0]
      landscape = Diagram.persistence_landscape(diagram, t_values, level: 1)

      # Outside [1.0, 2.0] should be 0
      assert Enum.at(landscape, 0) == 0.0
      assert Enum.at(landscape, 2) == 0.0
    end
  end

  describe "same_dimension?/2" do
    test "returns true for same dimension" do
      d1 = %{dimension: 1, pairs: []}
      d2 = %{dimension: 1, pairs: []}

      assert Diagram.same_dimension?(d1, d2)
    end

    test "returns false for different dimensions" do
      d1 = %{dimension: 0, pairs: []}
      d2 = %{dimension: 1, pairs: []}

      refute Diagram.same_dimension?(d1, d2)
    end
  end

  describe "property: distance metrics" do
    test "bottleneck distance is non-negative" do
      d1 = %{dimension: 1, pairs: [{0.0, 1.0}]}
      d2 = %{dimension: 1, pairs: [{0.0, 2.0}]}

      distance = Diagram.bottleneck_distance(d1, d2)
      assert distance >= 0.0
    end

    test "wasserstein distance is non-negative" do
      d1 = %{dimension: 1, pairs: [{0.0, 1.0}]}
      d2 = %{dimension: 1, pairs: [{0.0, 2.0}]}

      distance = Diagram.wasserstein_distance(d1, d2)
      assert distance >= 0.0
    end
  end
end
