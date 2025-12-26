defmodule ExTopology.MixProject do
  use Mix.Project

  @version "0.2.0"
  @source_url "https://github.com/North-Shore-AI/ex_topology"

  def project do
    [
      app: :ex_topology,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),

      # Hex
      description: "Generic Topological Data Analysis for Elixir",
      package: package(),

      # Docs
      name: "ExTopology",
      source_url: @source_url,
      homepage_url: @source_url,
      docs: docs(),

      # Testing
      preferred_cli_env: [
        "test.property": :test,
        "test.cross_validation": :test
      ],
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Core dependencies
      {:libgraph, "~> 0.16"},
      {:nx, "~> 0.7"},
      {:scholar, "~> 0.3"},

      # Development and testing
      {:stream_data, "~> 1.0", only: [:dev, :test]},
      {:benchee, "~> 1.0", only: :dev},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}

      # Optional backends (uncomment if needed):
      # {:exla, "~> 0.7", optional: true},
      # {:torchx, "~> 0.7", optional: true}
    ]
  end

  defp package do
    [
      maintainers: ["North-Shore-AI"],
      licenses: ["MIT"],
      files: [
        "lib",
        "mix.exs",
        "README.md",
        "LICENSE",
        "assets"
      ],
      links: %{
        "GitHub" => @source_url,
        "Docs" => "https://hexdocs.pm/ex_topology"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      name: "ExTopology",
      source_url: @source_url,
      source_ref: "v#{@version}",
      homepage_url: @source_url,
      assets: %{"assets" => "assets"},
      logo: "assets/ex_topology.svg",
      extras: [
        "README.md",
        "LICENSE"
      ],
      groups_for_modules: [
        "Graph Topology": [
          ExTopology.Graph
        ],
        "Data Structures": [
          ExTopology.Distance,
          ExTopology.Neighborhood,
          ExTopology.Simplex,
          ExTopology.Filtration
        ],
        "Persistent Homology": [
          ExTopology.Persistence,
          ExTopology.Diagram,
          ExTopology.Fragility
        ],
        "Embedding Analysis": [
          ExTopology.Embedding,
          ExTopology.Statistics
        ]
      ]
    ]
  end

  defp aliases do
    [
      "test.property": ["test --only property"],
      "test.cross_validation": ["test --only cross_validation"]
    ]
  end
end
