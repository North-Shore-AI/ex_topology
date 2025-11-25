# ADR-0003: Build Topological Data Analysis from Scratch

## Status

Accepted

## Context

Topological Data Analysis (TDA) is a core requirement for ex_topology. Key TDA concepts include:

- **Simplicial Complexes**: Generalization of graphs to higher dimensions
- **Betti Numbers**: Counts of topological features (components, loops, voids)
- **Persistent Homology**: Tracking features across filtration scales
- **Filtrations**: Rips, Cech, Alpha complexes

We surveyed the Elixir ecosystem for existing TDA implementations:

### Finding: No Elixir TDA Libraries Exist

Extensive research found **zero** Elixir libraries for TDA. The Python ecosystem dominates:

- **GUDHI** (C++ with Python bindings)
- **Ripser** (C++ with Python bindings)
- **giotto-tda** (Python, scikit-learn compatible)
- **Dionysus** (C++ with Python bindings)

### Options Considered

**Option A: Build Native Elixir TDA**
- Pure Elixir implementation
- Leverage libgraph for graph operations
- Leverage Nx for linear algebra
- Full control, clean API

**Option B: NIFs to Existing C++ Libraries**
- Wrap GUDHI or Ripser via Rustler
- Maximum performance
- Complex build, maintenance burden
- Breaks OTP fault isolation

**Option C: Python Interop via Pythonx**
- Call GUDHI/giotto-tda from Elixir
- Immediate access to mature implementations
- Latency overhead, deployment complexity
- Python dependency

## Decision

**Build TDA from scratch in pure Elixir.**

Rationale:

1. **Foundational nature**: TDA is central to ex_topology's value proposition
2. **Control**: Custom implementations let us optimize for our use cases
3. **Dependencies**: Building on libgraph + Nx gives us solid foundations
4. **Simplicity**: Pure Elixir means no external dependencies or build complexity
5. **Educational**: Implementation deepens understanding for research use

### Implementation Approach

Start with essential algorithms, expand based on need:

```elixir
defmodule ExTopology.TDA.SimplicalComplex do
  @moduledoc """
  Simplicial complex data structure and operations.

  A simplicial complex K is a collection of simplices (vertices, edges,
  triangles, tetrahedra, ...) closed under taking faces.
  """

  defstruct [:vertices, :simplices, :dimension]

  @type t :: %__MODULE__{
    vertices: MapSet.t(vertex()),
    simplices: %{non_neg_integer() => MapSet.t(simplex())},
    dimension: non_neg_integer()
  }

  @doc "Build Vietoris-Rips complex from distance matrix at scale epsilon"
  def vietoris_rips(distance_matrix, epsilon, max_dim \\ 2) do
    # 1. Vertices are all points
    # 2. Add edge (i,j) if d(i,j) <= epsilon
    # 3. Add k-simplex if all pairwise distances <= epsilon
    ...
  end
end

defmodule ExTopology.TDA.Betti do
  @moduledoc """
  Betti number computation via boundary matrix reduction.
  """

  @doc """
  Compute Betti numbers of a simplicial complex.

  β₀ = number of connected components
  β₁ = number of 1-dimensional holes (loops)
  β₂ = number of 2-dimensional voids
  """
  def compute(complex) do
    # Build boundary matrices
    # Reduce via Smith normal form
    # Count pivot/non-pivot columns
    ...
  end
end

defmodule ExTopology.TDA.PersistentHomology do
  @moduledoc """
  Persistent homology via filtration.
  """

  @doc """
  Compute persistence diagram from a filtered complex.
  Returns birth-death pairs for each homology dimension.
  """
  def persistence(filtration) do
    # Standard algorithm: process simplices in filtration order
    # Track birth/death of homology classes
    ...
  end
end
```

## Consequences

### Positive

1. **No external dependencies**: Pure Elixir, works everywhere
2. **Full control**: Can optimize for specific use cases
3. **Clean API**: Design specifically for Elixir idioms
4. **Research foundation**: Deep understanding of algorithms
5. **Contribution**: First TDA library for Elixir ecosystem

### Negative

1. **Development effort**: Significant implementation work
2. **Performance**: May not match highly optimized C++ implementations
3. **Correctness risk**: Must carefully test mathematical properties

### Mitigations

- Start with well-documented reference implementations
- Extensive property-based testing for mathematical invariants
- Profile and optimize hot paths
- Consider optional NIF acceleration for proven bottlenecks later

## Implementation Phases

1. **Phase 1**: Simplicial complexes, Vietoris-Rips construction
2. **Phase 2**: Betti numbers via boundary matrix reduction
3. **Phase 3**: Persistent homology with filtrations
4. **Phase 4**: Visualization and export (persistence diagrams)
5. **Phase 5**: Performance optimization

## References

- Edelsbrunner & Harer, "Computational Topology"
- Carlsson, "Topology and Data" (2009)
- [GUDHI Documentation](https://gudhi.inria.fr/)
- CNS.Logic.Betti - Existing β₁ computation to generalize
