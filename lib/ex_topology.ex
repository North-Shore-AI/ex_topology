defmodule ExTopology do
  @moduledoc """
  Generic Topological Data Analysis for Elixir.

  ExTopology provides foundational topology and TDA algorithms for the Elixir
  ecosystem. It extracts generic mathematical operations from domain-specific
  implementations, making them reusable across applications.

  ## Architecture

  ```
  Domain Layer (NOT in ex_topology)
  ├── CNS (Fragility, SNO, Chirality)
  ├── CodeAnalysis (TechDebt, Coupling)
  └── ... other domains

  ex_topology (GENERIC)
  ├── Layer 2: Algorithms (Graph, Embedding, Statistics)
  └── Layer 1: Structures (Neighborhood, Distance)

  Foundation (External)
  ├── libgraph, Nx / Scholar, Erlang stdlib
  ```

  ## Quick Start

      # Graph topology
      graph = Graph.new() |> Graph.add_edges([{1, 2}, {2, 3}, {3, 1}])
      ExTopology.Graph.beta_one(graph)
      #=> 1

      # Distance matrices
      points = Nx.tensor([[0.0, 0.0], [3.0, 4.0], [1.0, 1.0]])
      ExTopology.Distance.euclidean_matrix(points)

      # Neighborhood graphs
      ExTopology.Neighborhood.knn_graph(points, k: 2)

  ## Modules

  - `ExTopology.Graph` - Graph-theoretic topology (β₀, β₁, χ)
  - `ExTopology.Distance` - Distance matrix computation
  - `ExTopology.Neighborhood` - Neighborhood graph construction
  - `ExTopology.Embedding` - Embedding analysis metrics
  - `ExTopology.Statistics` - Statistical measures
  """

  @doc """
  Returns the library version.

  ## Examples

      iex> ExTopology.version()
      "0.1.0"
  """
  @spec version() :: String.t()
  def version, do: "0.1.0"
end
