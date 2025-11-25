# ADR-0007: NIF Escape Hatch Strategy

## Status

Accepted

## Context

Pure Elixir implementations have performance ceilings. For compute-intensive algorithms, Native Implemented Functions (NIFs) can provide 10-1000x speedups. However, NIFs have costs:

- **Scheduler blocking**: Long-running NIFs block BEAM schedulers
- **Crash propagation**: NIF crashes take down the VM
- **Build complexity**: Requires C/C++/Rust toolchain
- **Portability**: Platform-specific binaries
- **Maintenance**: Two codebases to maintain

We need a clear policy for when NIF acceleration is appropriate.

## Decision

**Define explicit performance thresholds that trigger NIF consideration. Never use NIFs for Phase 1-2 functionality.**

### Performance Thresholds

| Operation | Pure Elixir Target | NIF Trigger | Notes |
|-----------|-------------------|-------------|-------|
| β₀, β₁ (graph) | < 10ms for 10k vertices | Never | Too simple to benefit |
| k-NN graph construction | < 1s for 10k points | > 10s | Consider HNSWLib |
| Distance matrix (Nx) | < 1s for 5k points | > 10s | EXLA usually sufficient |
| Boundary matrix reduction | N/A (deferred) | If implemented | Primary NIF candidate |
| Persistent homology | N/A (deferred) | If implemented | Primary NIF candidate |

### NIF Decision Framework

```
┌─────────────────────────────────────────────────────────────┐
│                    Is NIF Needed?                            │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
              ┌────────────────────────┐
              │ Is operation in scope? │
              │ (Phase 1-2 only now)   │
              └────────────────────────┘
                      │           │
                     No          Yes
                      │           │
                      ▼           ▼
                ┌─────────┐  ┌─────────────────────┐
                │  STOP   │  │ Does Nx/EXLA solve  │
                │ (Defer) │  │ the perf problem?   │
                └─────────┘  └─────────────────────┘
                                  │           │
                                 Yes          No
                                  │           │
                                  ▼           ▼
                            ┌─────────┐  ┌─────────────────────┐
                            │ Use Nx  │  │ Is there a mature   │
                            │ + EXLA  │  │ NIF wrapper?        │
                            └─────────┘  └─────────────────────┘
                                              │           │
                                             Yes          No
                                              │           │
                                              ▼           ▼
                                        ┌─────────┐  ┌─────────────────┐
                                        │ Use it  │  │ Build our own?  │
                                        │ (eval)  │  │ Rarely yes.     │
                                        └─────────┘  └─────────────────┘
```

### Phase 1-2: No NIFs

Graph topology and embedding metrics do NOT need NIFs:

```elixir
# β₁ is O(V + E) via libgraph - microseconds for reasonable graphs
def beta_one(graph) do
  Graph.num_edges(graph) - Graph.num_vertices(graph) + 
    length(Graph.components(graph))
end

# Distance matrices use Nx with optional EXLA backend
# GPU acceleration is available without NIFs
defn euclidean_matrix(points) do
  diff = Nx.new_axis(points, 1) - Nx.new_axis(points, 0)
  Nx.sqrt(Nx.sum(diff * diff, axes: [-1]))
end
```

### Phase 3+: NIF Candidates

If persistent homology is implemented, these are NIF candidates:

| Algorithm | Pure Elixir | With NIF (Ripser) | Speedup |
|-----------|-------------|-------------------|---------|
| Vietoris-Rips PH | ~minutes | ~seconds | 10-100x |
| Boundary reduction | ~seconds | ~ms | 100-1000x |
| Bottleneck distance | ~seconds | ~ms | 10-100x |

### Approved NIF Wrappers (for future use)

If Phase 3+ proceeds, evaluate these existing wrappers:

1. **HNSWLib** (already Elixir wrapper exists)
   - Approximate k-NN
   - Use case: Large-scale neighborhood graphs
   - Maturity: Production-ready

2. **Ripser** (would need wrapper)
   - Persistent homology
   - Use case: Full TDA pipeline
   - Approach: Rustler wrapper around C++ library

3. **GUDHI** (would need wrapper)
   - Comprehensive TDA
   - Use case: Research applications
   - Approach: Pythonx interop or Rustler

### NIF Safety Requirements

Any NIF we use or build must:

1. **Yield to scheduler**: Use `enif_consume_timeslice` or dirty schedulers
2. **Handle errors gracefully**: Return error tuples, never crash
3. **Be optional**: Pure Elixir fallback must exist
4. **Have CI coverage**: Test on Linux, macOS, Windows

```elixir
# Example: Safe NIF wrapper pattern
defmodule ExTopology.Native.Ripser do
  @on_load :load_nif
  
  def load_nif do
    path = :code.priv_dir(:ex_topology) ++ ~c"/native/ripser"
    :erlang.load_nif(path, 0)
  end

  @doc """
  Compute persistent homology via Ripser.
  
  Falls back to pure Elixir if NIF unavailable.
  """
  def persistence(points, opts \\ []) do
    if nif_available?() do
      persistence_nif(points, opts)
    else
      ExTopology.TDA.PersistentHomology.compute(points, opts)
    end
  end

  # NIF stub - replaced by native code on load
  defp persistence_nif(_points, _opts) do
    :erlang.nif_error(:not_loaded)
  end

  defp nif_available? do
    function_exported?(__MODULE__, :persistence_nif, 2)
  end
end
```

## Consequences

### Positive

1. **Clear criteria**: Know exactly when NIFs are justified
2. **Pure Elixir first**: Maintain simplicity for Phase 1-2
3. **Escape hatch exists**: Path forward if performance matters
4. **Safety requirements**: NIFs won't destabilize system

### Negative

1. **Future work**: May need NIF development for Phase 3+
2. **Build complexity**: If NIFs added, CI becomes harder

### What This Decides

| Decision | Choice |
|----------|--------|
| NIFs for β₀, β₁ | No, never needed |
| NIFs for distance matrices | No, Nx/EXLA sufficient |
| NIFs for k-NN | Maybe, HNSWLib if scale demands |
| NIFs for persistent homology | Yes, if feature is built |
| Build vs wrap | Wrap existing (Ripser) over build |

### What This Defers

- Specific Ripser wrapper implementation
- GUDHI evaluation
- Dirty scheduler configuration

## Benchmarks to Establish

Before any NIF work, establish baselines:

```elixir
# benchmark/baseline.exs
Benchee.run(%{
  "beta_one_1k" => fn -> 
    ExTopology.Graph.beta_one(random_graph(1000, 0.01)) 
  end,
  "beta_one_10k" => fn -> 
    ExTopology.Graph.beta_one(random_graph(10_000, 0.001)) 
  end,
  "distances_1k" => fn ->
    ExTopology.Foundation.Distance.euclidean_matrix(random_points(1000, 50))
  end,
  "distances_5k" => fn ->
    ExTopology.Foundation.Distance.euclidean_matrix(random_points(5000, 50))
  end
})
```

## References

- [Rustler](https://github.com/rusterlium/rustler) - Rust NIF toolkit
- [Ripser](https://github.com/Ripser/ripser) - Fast persistent homology
- [HNSWLib Elixir](https://github.com/elixir-nx/hnswlib) - Existing ANN wrapper
- Erlang efficiency guide: NIFs and dirty schedulers
