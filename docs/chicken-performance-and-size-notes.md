# CHICKEN Performance And Binary Size Notes For Cluck

These notes summarize the old CHICKEN performance and small-binary guidance,
but translate it into Cluck terms. The CHICKEN advice is still broadly right:

- smaller binaries come from pulling in fewer runtime/library units
- faster binaries come from giving the compiler a more closed world
- `-O3`/`-O4`/`-O5`, `-d0`, block mode, and numeric specialization matter
- `-explicit-use` helps when a program does not need the evaluator and other
  extra units

For Cluck, the important question is not only "what flags should we pass?", but
"what parts of the current language layer prevent CHICKEN from optimizing?"

## Quick answer: how to obtain smaller executables

For Cluck apps today:

- prefer the standalone packaging pattern that `include`s only the namespaces
  you actually need
- do not use `src/cluck-cli.scm` or `src/cluck-init.scm` when you want the
  smallest deployable binary; those are convenience entrypoints for source mode
- keep REPL support, runtime source loading, and dev helpers out of deployed
  launchers unless they are required
- avoid eggs unless the feature justifies the size cost
- measure with a minimal app first, then add namespaces one by one

For tiny raw CHICKEN programs, the old `-explicit-use` advice still points in
the right direction. For Cluck specifically, the historical
`(declare (uses library))` snippet should be treated as a minimal-CHICKEN
pattern, not a current Cluck pattern. Cluck's runtime uses `eval`,
`interaction-environment`, dynamic namespace loading, reader customization, and
mutable global registries, so it is much larger than "library only".

## Quick answer: how to obtain faster executables

For Cluck code today:

- compile hot paths with at least `-O3`; use `-d0` or `-d1` when debugging
  traces are not needed
- use exact integer/fixnum-friendly loops in hot code where possible
- keep hot functions in the same compilation unit if we want inlining
- avoid generic "late bound" namespace lookups in tight loops
- do not rely on runtime `eval` or dynamic `require` in the deployed path
- benchmark collection code separately from printing and startup

## What is troublesome in the current Cluck implementation

### 1. Runtime `eval` and source loading block closed-world optimization

The main runtime evaluates rewritten forms through `eval` in the interaction
environment and loads source files form-by-form at runtime. That is a direct
fit for REPL development, but it works against CHICKEN's best optimization and
small-binary story.

Current pressure points:

- `src/cluck.scm`: `cluck-eval-source-form`, `cluck-load-source-file!`,
  `cluck-load-namespace-file!`
- `src/cluck-cli.scm`: CLI `-e` and file loading are built around runtime eval
- `src/cluck-init.scm`: source-mode loader path

Implication:

- great for interactive workflow
- expensive for deployed binaries
- makes `-explicit-use` and "library only" thinking a bad match for the main
  Cluck runtime

Recommendation:

- keep two modes explicit:
  - dev/runtime mode: current REPL-friendly loader path
  - deployed mode: ahead-of-time bundled or generated entrypoints with no
    runtime eval, no source search, and no filesystem module discovery

### 2. The deployed path still bundles a lot of runtime that apps may not need

Standalone launchers avoid source loading by `include`ing Cluck files directly,
which is good, but they still pull in the full `src/cluck.scm` runtime. That
runtime contains REPL support, docs support, namespace loaders, source
rewriters, and other features that deployed binaries may not need.

Current examples:

- `examples/cluck/weather/run-standalone.scm`
- `examples/cluck/ro/run-standalone.scm`

Implication:

- standalone binaries are self-contained, but not minimal
- binary size scales with broad runtime inclusion, not just app logic

Recommendation:

- split `src/cluck.scm` into smaller compile-time/runtime slices:
  - reader + syntax layer
  - core runtime and collections
  - namespace loader
  - REPL/doc tooling
  - standalone/deployed support
- let deployed apps include only the slices they need

### 3. Namespace aliasing currently adds runtime indirection

Qualified imports are installed with runtime-generated wrappers. That gives a
nice dynamic namespace story, but it means calls can go through extra lookup
and wrapper layers instead of a direct binding.

Current pressure point:

- `src/cluck.scm`: `cluck-import-qualified!`

Recommendation:

- for standalone builds, generate direct alias bindings at compile time
- keep the dynamic wrapper path only for REPL/source mode where hot performance
  matters less

### 4. Many collection operations stay fully generic

Core helpers like `count`, `seq`, `map`, `filter`, `mapv`, `filterv`,
`map-indexed`, and `reduce` dispatch across strings, pairs, maps, sets,
vectors, and custom transient structures. That is good for language ergonomics,
but it limits specialization.

Current pressure points:

- `src/cluck.scm`: `count`, `seq`, `map`, `mapv`, `filter`, `filterv`,
  `map-indexed`, `reduce`
- benchmark coverage exists in `bench/collections.clk`, but the benchmarks are
  still exercising the generic public surface

Recommendation:

- keep the generic public API
- add lower-level internal helpers for hot paths with narrower expectations
- use those narrower helpers inside core libraries and example apps when the
  data shape is known
- consider typed or specialized variants for vector/list-heavy internal code

### 5. There is almost no compiler guidance in the codebase

The repo currently has no meaningful use of:

- `declare`
- type declarations
- compiler syntax
- specialization hooks
- emitted type files for cross-unit optimization

Implication:

- CHICKEN has little help specializing Cluck's hot functions
- the project is leaving optimization opportunities on the table

Recommendation:

- start small and local:
  - add `declare` blocks in hot Scheme runtime files
  - use `standard-bindings`, `extended-bindings`, and block-style assumptions
    where correct
  - try numeric declarations in obviously integer-only helpers
  - use `-emit-type-file` / `-types` for stable runtime slices once the module
    boundaries settle

### 6. Some current algorithms are simple but allocation-heavy or quadratic

Examples worth watching:

- insertion-sort style helpers for stable printed ordering in
  `src/cluck.scm` and `src/cluck/persistent.clk`
- recursive directory walkers that use `append` in loops in
  `src/cluck-bootstrap.scm`
- persistent hashing that falls back to `(core/pr-str x)` for non-specialized
  values in `src/cluck/persistent.clk`
- app code that builds vectors via repeated `append`, such as
  `examples/cluck/ro/src/app.clk`

These are acceptable on cold paths, but they should stay off hot paths.

Recommendation:

- mark "printing/order stability" as explicitly non-hot
- avoid `append` inside recursive accumulation loops
- avoid using printed representations as a hash basis in frequently touched
  structures
- prefer direct vector/list builders over repeated list concatenation

## Things to avoid in performance-sensitive Cluck code

- runtime `eval` in deployed code paths
- dynamic filesystem namespace discovery in deployed code paths
- repeated `append` in loops
- converting vectors to lists and back in tight loops unless unavoidable
- sorting by `pr-str` outside display/debug paths
- generic arithmetic where fixnum-only arithmetic is sufficient
- making hot helpers public and globally mutable when they can stay local

## Features that may deserve a redesign

### Separate dev and deploy runtimes

This is the biggest structural improvement available. The REPL/runtime-loader
path and the deployed/native-binary path should not be forced to share the same
runtime surface.

### Compile namespaces into direct bindings

If standalone Cluck builds can expand `ns`/`:require` into direct bindings
ahead of time, we remove a lot of runtime lookup machinery from deployed apps.

### Slim core runtime slices

`src/cluck.scm` is doing too many jobs. Breaking it apart should improve both
compile-time and runtime optimization opportunities.

### Add a "hot path subset" of internal collection helpers

Not a different user language, just a clearer internal library boundary for
known vector/list/map shapes.

## Suggested next work

1. Add a "deployed runtime" build target that excludes runtime eval, docs, and
   source loader support.
2. Break `src/cluck.scm` into smaller units so deployed examples can include
   only what they need.
3. Add a benchmark/build matrix:
   - `-O2`, `-O3`, `-O5`
   - `-d0` vs default debug settings
   - source mode vs standalone mode
   - binary size for `text-report`, `weather`, and `ro`
4. Replace obvious `append`-in-loop sites.
5. Add declarations and, where it pays off, simple type information to hot
   runtime helpers.

## Bottom line

The old CHICKEN advice is not obsolete, but Cluck only benefits from it when we
structure the language layer so the compiler can see a smaller, more static,
more specialized program. Right now the REPL-friendly architecture is doing
real work for development, but it is also the main reason deployed Cluck
binaries are larger and less optimizable than they could be.
