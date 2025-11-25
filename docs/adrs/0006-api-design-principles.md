# ADR-0006: API Design Principles

## Status

Accepted

## Context

ex_topology will be used by:

1. **Domain experts** (ML engineers, researchers) who know topology but not Elixir idioms
2. **Elixir developers** building applications who need topology primitives
3. **CNS/Crucible users** who need high-level integration
4. **Contributors** extending the library

The API must balance mathematical precision with Elixir ergonomics.

## Decision

**Follow these API design principles:**

### 1. Mathematical Naming with Elixir Conventions

Use mathematical terminology but follow Elixir naming patterns:

```elixir
# Good: Mathematical names, Elixir snake_case
ExTopology.TDA.Betti.compute(complex)           # Not: computeBetti
ExTopology.TDA.Betti.beta_one(graph)            # β₁ as beta_one
ExTopology.Foundation.Distance.euclidean(a, b)   # Not: l2_norm

# Document with mathematical notation
@doc """
Compute the k-th Betti number βₖ of a simplicial complex.

βₖ = dim(ker(∂ₖ)) - dim(im(∂ₖ₊₁))
"""
def beta(complex, k), do: ...
```

### 2. Data-First Function Signatures

Primary data as first argument for pipeline compatibility:

```elixir
# Good: Data first, pipeable
points
|> ExTopology.Structure.NeighborhoodGraph.knn_graph(k: 10)
|> ExTopology.TDA.Betti.beta_one()

# Avoid: Options first
knn_graph(k: 10, points: points)  # Bad
```

### 3. Explicit Over Implicit

Make behavior clear through explicit parameters:

```elixir
# Good: Explicit parameters
def vietoris_rips(points, epsilon, max_dimension: 2)

# Good: Explicit return types
{:ok, %{beta_0: 1, beta_1: 3, beta_2: 0}}
{:error, :insufficient_points}

# Avoid: Hidden defaults that affect correctness
def vietoris_rips(points)  # What epsilon? What dimension?
```

### 4. Consistent Options Pattern

Use keyword lists for optional parameters:

```elixir
defmodule ExTopology.TDA.Betti do
  @default_opts [
    algorithm: :standard,    # :standard | :incremental
    max_dimension: 2,
    sparse: :auto           # :auto | true | false
  ]

  def compute(complex, opts \\ []) do
    opts = Keyword.merge(@default_opts, opts)
    # ...
  end
end
```

### 5. Structs for Complex Data

Use structs with enforced keys for complex types:

```elixir
defmodule ExTopology.Structure.SimplicialComplex do
  @enforce_keys [:vertices]
  defstruct [
    :vertices,
    simplices: %{},
    dimension: 0
  ]

  @type t :: %__MODULE__{
    vertices: MapSet.t(vertex()),
    simplices: %{non_neg_integer() => MapSet.t(simplex())},
    dimension: non_neg_integer()
  }
end

defmodule ExTopology.TDA.PersistenceDiagram do
  @enforce_keys [:dimension, :pairs]
  defstruct [:dimension, :pairs]

  @type t :: %__MODULE__{
    dimension: non_neg_integer(),
    pairs: [{birth :: float(), death :: float()}]
  }
end
```

### 6. Error Handling

Use tagged tuples for operations that can fail:

```elixir
# Operations that can fail return {:ok, result} | {:error, reason}
def persistent_homology(filtration) do
  case validate_filtration(filtration) do
    :ok -> {:ok, compute_persistence(filtration)}
    {:error, reason} -> {:error, reason}
  end
end

# Bang variants for when failure is unexpected
def persistent_homology!(filtration) do
  case persistent_homology(filtration) do
    {:ok, result} -> result
    {:error, reason} -> raise ArgumentError, "Persistence failed: #{reason}"
  end
end
```

### 7. Documentation Standards

Every public function must have:

```elixir
@doc """
Brief one-line description.

Extended description with mathematical context where appropriate.

## Parameters

  * `complex` - A simplicial complex
  * `opts` - Keyword list of options:
    * `:max_dimension` - Maximum homology dimension (default: 2)

## Returns

  * `{:ok, %{beta_0: integer(), beta_1: integer(), ...}}` on success
  * `{:error, reason}` on failure

## Examples

    iex> complex = SimplicialComplex.triangle()
    iex> Betti.compute(complex)
    {:ok, %{beta_0: 1, beta_1: 0}}

## Mathematical Background

The Betti numbers βₖ count k-dimensional holes:
- β₀ = connected components
- β₁ = loops/tunnels
- β₂ = voids/cavities
"""
@spec compute(SimplicialComplex.t(), keyword()) ::
        {:ok, %{atom() => non_neg_integer()}} | {:error, term()}
def compute(complex, opts \\ [])
```

### 8. Test-Driven Examples

Use doctests as executable documentation:

```elixir
@doc """
Compute Euclidean distance between two points.

## Examples

    iex> Distance.euclidean(Nx.tensor([0, 0]), Nx.tensor([3, 4]))
    #Nx.Tensor<
      f32
      5.0
    >

    iex> Distance.euclidean(Nx.tensor([1, 1]), Nx.tensor([1, 1]))
    #Nx.Tensor<
      f32
      0.0
    >
"""
```

## Consequences

### Positive

1. **Discoverable**: Mathematical names help domain experts find functions
2. **Pipeable**: Data-first enables functional composition
3. **Safe**: Explicit parameters prevent subtle bugs
4. **Documented**: Rich docs serve as learning resource
5. **Type-safe**: Specs enable Dialyzer checking

### Negative

1. **Verbosity**: More explicit code is longer
2. **Learning curve**: Elixir newcomers must learn idioms

## References

- [Elixir Library Guidelines](https://hexdocs.pm/elixir/library-guidelines.html)
- [Nx API Design](https://hexdocs.pm/nx)
- [Scholar API Patterns](https://hexdocs.pm/scholar)
