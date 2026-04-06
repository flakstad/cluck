# cluck

`cluck` is a Clojure-flavored language layer for CHICKEN Scheme.

It is experimental and focused on small native tools, a REPL-driven workflow, and a practical core library.

The goal is not to reimplement Clojure on the JVM. The goal is to get the parts of the Clojure experience that matter most for small native tools:

- EDN-like reader syntax
- Clojure-style data literals
- a REPL-driven workflow
- a small, practical core library
- native deployment through CHICKEN's C toolchain

## Why CHICKEN

CHICKEN is a good fit for this project because it sits in a useful middle ground:

- it is compact and fast enough for small native programs
- it compiles Scheme to C, which makes packaging and deployment straightforward
- it has a real interactive REPL
- it has practical C interop
- it is comfortable for local tools, scripts, and small services

That makes it a strong host for an exploratory Lisp layer that wants to feel lighter than Clojure JVM, but still behave like a proper Lisp at the terminal.

## What `cluck` is trying to do

The project is exploring a Clojure-like surface on top of CHICKEN Scheme:

- keywords, maps, sets, and vectors with EDN-style syntax
- core helpers such as `def`, `defn`, `fn`, `let`, `if`, `when`, `cond`, `->`, and `->>`
- common sequence helpers like `seq`, `first`, `rest`, `count`, `map`, `filter`, and `reduce`
- mutable maps and sets for now, with immutable collections deferred until later
- a REPL and printing experience that feels closer to Clojure than raw Scheme
- `.clk` is the preferred source extension for cluck code; `.scm` stays for Scheme glue and bootstrap files

This is intentionally a language layer, not just a normal library.

## Current status

The current implementation supports:

- `:keywords`
- `[1 2 3]` vectors
- `{:a 1 :b 2}` maps
- `#{1 2 3}` sets
- `read-string`
- `pr-str`, `str`, `println`, and `prn`
- mutable `assoc`, `dissoc`, `conj`, `get`, `contains?`, `seq`, `map`, `mapv`, `filter`, `filterv`, `keep`, `map-indexed`, `empty?`, and `reduce`
- `let`, `fn`, and `defn` destructuring for vectors and maps
- `ns`, `in-ns`, `current-ns`, `find-ns`, `all-ns`, `ns-publics`, and `ns-resolve`
- `require` plus `ns`-time `:require` directives for loading namespace files
- Clojure-style special forms and threading macros
- `def` and `defn` intern into the active namespace, return the defined value when evaluated, and support docstrings via `doc`
- core runtime vars like `map`, `get`, `assoc`, `reduce`, and `seq` carry docstrings that surface through `doc` and `C-c C-d`
- the public namespace layout is now mirrored through `cluck.core`, `cluck.string`, `cluck.set`, and `cluck.edn`, with `cluck.core` installed at bootstrap time

Notes:

- vectors are still ordinary CHICKEN vectors, so the host REPL prints them as `#(...)`
- keywords, maps, and sets use custom record types so the host REPL can print them in Clojure-style form
- the collection layer is mutable for now
- the namespace layer is intentionally lightweight and uses separate public/import tables; it is not full Clojure namespace resolution yet
- `seq` is intentionally cheap and unsorted; stable ordering is handled by `pr-str` instead of traversal

## Scheme Interop

`.clk` files are still Scheme source files with cluck syntax layered on top. You can use ordinary Scheme forms, procedures, and host interop freely alongside cluck forms.

The main caveat is that cluck repurposes a few core binding and threading forms, so the surface is not identical to raw Scheme:

- `let`
- `fn`
- `defn`
- `if`
- `cond`
- `when`
- `->`
- `->>`

If you need exact Scheme semantics in a `.clk` file, keep that code in a `.scm` helper or drop to the core forms such as `##core#let`.

## Performance Direction

`cluck` is aiming for an eager, direct Clojure-flavored language, not a lazy one.

- `map` and `filter` stay eager and return lists
- `keep` and `map-indexed` are eager too, with vector-specialized fast paths
- `mapv` and `filterv` are the vector-oriented fast paths
- `empty?` should stay constant-time on the common collection shapes
- `seq` should be a cheap adapter, not a place where we sort or realize expensive views
- `pr-str` can stay slower and stable because printing is not the hot path
- control-flow macros should expand directly and avoid runtime helper calls when possible
- Scheme tail recursion is enough for iterative code, so plain recursive helpers are fine where they stay tail-recursive

The practical goal is to keep the syntax familiar while making the runtime feel closer to direct Scheme than to lazy Clojure.

## Loading it

From the repository root, in Geiser or any other REPL where you want to return to the host prompt:

```scheme
(load "cluck-init.scm")
```

That loads the language layer and installs the reader syntax, but does not start a nested REPL.

For a standalone terminal REPL:

```scheme
(load "cluck-repl.scm")
```

That file intentionally drops into the `cluck` REPL, so it will appear to keep running until you exit the nested prompt.

For a more convenient command-line entrypoint, use the launcher source:

```scheme
(load "cluck-cli.scm")
```

It starts a REPL by default, but also accepts a few simple flags:

```bash
csi -q -s cluck-cli.scm
csi -q -s cluck-cli.scm -e '(+ 1 2)'
csi -q -s cluck-cli.scm -l demo.clk
```

To build a native launcher binary:

```bash
csc -k -v -O2 -strip -o build/cluck cluck-cli.scm
```

That produces `build/cluck` plus the generated C wrapper in `build/cluck.c`. The launcher still loads the cluck source files at startup, so it is a convenient distribution front-end rather than a fully embedded image.

## Editor Support

In Emacs, `cluck-mode` is a derived `clojure-mode` variant for indentation, paredit, folding, and syntax coloring.

It also includes interactive eval helpers:

- `C-x C-e` and `C-c C-e` evaluate the sexp before point and show an inline result overlay
- `C-c C-c` evaluates the current top-level form with an inline result overlay
- `C-c C-d` shows the docstring for the symbol at point in a dedicated buffer
- inline overlays clear on the next command, so they behave more like transient feedback than permanent annotations
- `C-c C-r`, `C-c C-b`, `C-c C-k`, and `C-c C-l` report in the echo area for larger evaluations and file loads
- `M-.` jumps to the definition of the symbol at point, and `M-,` returns to the previous location

It is intentionally not wired to CIDER or LSP for Cluck buffers by default. Instead, the workflow is:

- edit `.clk` files in `cluck-mode`
- start a Cluck REPL with `./build/cluck` or `cluck-repl.scm`
- send the current form, region, buffer, or file from `cluck-mode`
- use `C-x C-e` or `C-c C-e` for the previous sexp, `C-c C-c` for the current top-level form, `C-c C-r` for a selected region, `C-c C-b` or `C-c C-k` for the buffer, `C-c C-d` for docstrings, and `C-c C-l` to reload the file
- use `M-.` to jump to definitions and `M-,` to jump back
- use `C-c C-z` to switch to the REPL buffer

That keeps the editing experience light and avoids Clojure-specific REPL assumptions that do not fit Cluck yet.

## Demo program

There is a small demo program in:

- [`demo.clk`](./demo.clk)

It is loaded by:

- [`run-demo.scm`](./run-demo.scm)

Run it with CHICKEN's interpreter after checking out the repo:

```scheme
(load "run-demo.scm")
```

Or from the command line:

```bash
csi -q -s run-demo.scm
```

The demo prints a small report over a vector of maps and shows the syntax in action.

## Smoke tests

There is also a small smoke-test harness in:

- [`smoke.clk`](./smoke.clk)

It is loaded by:

- [`run-smoke-tests.scm`](./run-smoke-tests.scm)

Run it with:

```bash
csi -q -s run-smoke-tests.scm
```

The smoke tests check the reader, printer, function macros, threading forms, and a few core collection helpers.

## Namespaces

`cluck` now has a small namespace registry plus a separate import table per namespace, so public vars and imported refs stay distinct.

The public namespace layout mirrors Clojure's shape:

- `cluck.core`
- `cluck.string`
- `cluck.set`
- `cluck.edn`

These namespaces are the intended public surface for user-facing code. The older `cluck.math` and `cluck.app` files remain as sample/demo namespaces.

- `ns` sets the active namespace
- `require` loads namespace files and returns to the caller's namespace afterwards
- `in-ns` switches the active namespace
- `current-ns` returns the active namespace symbol
- `find-ns` returns the registry entry for a namespace
- `all-ns` lists known namespaces
- `ns-publics` returns a map of public vars in a namespace
- `ns-resolve` looks up a var by namespace and symbol

`ns` supports a focused subset of `:require` directives:

- `[foo.bar :refer [x y]]` imports selected public vars into the current namespace
- `[foo.bar :refer :all]` imports all public vars into the current namespace
- `[foo.bar :as fb]` registers an alias that `ns-resolve` can use
- `[foo.bar :exclude [x y]]` skips selected vars when using `:refer :all`
- `(:refer-clojure :exclude [...])` excludes selected core vars from the default core import set

Namespace source files are located by namespace path, starting with:

- `foo.bar` -> `foo/bar.clk`
- fallback lookups also check `foo/bar.clj.scm`, `foo/bar.scm`, and root-level `bar.*`
- `src/` is searched as a secondary prefix

The mirrored namespace files currently live at:

- [`cluck/core.clk`](./cluck/core.clk)
- [`cluck/string.clk`](./cluck/string.clk)
- [`cluck/set.clk`](./cluck/set.clk)
- [`cluck/edn.clk`](./cluck/edn.clk)

This is enough to structure source files, inspect exports, and load small module trees. Full Clojure-style namespace qualification is still future work, but the current split between public vars and imports keeps `ns-publics` and `ns-resolve` usable.

## Direction

The next phase is about making Cluck prove itself on a real small program, not just adding syntax.

- keep the runtime eager, direct, and mutable-first
- continue the namespace split toward `cluck.core`, `cluck.string`, `cluck.set`, and related modules
- expand the core library with practical helpers such as `get-in`, `assoc-in`, `update`, `merge`, `merge-with`, `keys`, `vals`, `select-keys`, `zipmap`, `remove`, `mapcat`, `apply`, `partial`, and `comp`
- use one real dogfood app to drive the next round of API and namespace decisions
- prefer a small native CLI or local data tool first; weather/forecast is a good candidate once HTTP support is in place
- leave more ambitious graphics work, such as SDL3 drawing, for a later phase

## Module Demo

There is a small require/ns demo in:

- [`cluck/math.clk`](./cluck/math.clk)
- [`cluck/app.clk`](./cluck/app.clk)

It is loaded by:

- [`run-require-demo.scm`](./run-require-demo.scm)

Run it with:

```bash
csi -q -s run-require-demo.scm
```

The smoke tests also load `cluck.math` through `require` to verify namespace restoration and alias lookup.

## Native Build

There is now a trivial CLI benchmark in:

- [`bench.clk`](./bench.clk)

It is loaded by:

- [`run-bench.scm`](./run-bench.scm)

The benchmark builds a synthetic backlog, filters it, and prints a summary using the `cluck` runtime and namespace support.

Build the translated C and native binary with:

```bash
csc -k -v -O2 -strip -o build/cluck-bench run-bench.scm
```

That leaves:

- `build/cluck-bench.c`
- `build/cluck-bench`

On this machine, the kept artifacts are about:

- `build/cluck-bench.c`: `7.6K`
- `build/cluck-bench`: `50K`

Important caveat:

- the current native build compiles the `run-bench.scm` wrapper
- that wrapper still `load-relative`s `cluck-init.scm` and `bench.clk` at startup
- so these timings are a measure of the current hosted language layer and runtime loader path, not yet a fully self-contained AOT image

A 100000-item run on this machine produced:

- interpreted `csi -q -s run-bench.scm 100000`: `13.35s` real, `12.83s` user
- native `./build/cluck-bench 100000`: `13.53s` real, `12.82s` user

The workload is allocation-heavy, so the native binary is not dramatically faster yet. The useful result here is that we have a small native artifact and a clear baseline for future runtime work.

## Collections Benchmark

There is also a smaller benchmark focused on the collection primitives we care about most in the language layer:

- [`collections-bench.clk`](./collections-bench.clk)
- [`run-collections-bench.scm`](./run-collections-bench.scm)

This suite compares:

- `map` vs `mapv`
- `filter` vs `filterv`
- `keep`
- `map-indexed`
- `empty?`
- `count`
- `reduce`
- `into`
- list inputs vs vector inputs

Run it with:

```bash
csi -q -s run-collections-bench.scm 5000 100
```

Or build a native binary:

```bash
csc -k -v -O2 -strip -o build/cluck-collections-bench run-collections-bench.scm
```

The benchmark prints per-case timings using CHICKEN's process timer, while external `time -l` is still the best way to inspect wall-clock, CPU, and memory behavior from the shell on macOS.

On this machine with `5000` items and `100` rounds:

- interpreted `csi -q -s run-collections-bench.scm 5000 100`: `3.53s` real, `3.49s` user, about `45MB` RSS
- native `./build/cluck-collections-bench 5000 100`: `3.58s` real, `3.54s` user, about `49MB` RSS
- `build/cluck-collections-bench.c`: `7.2K`
- `build/cluck-collections-bench`: `50K`

Per-case timings from the benchmark run:

- `map on list`: `234ms`
- `mapv on list`: `233ms`
- `map on vector`: `243ms`
- `mapv on vector`: `179ms`
- `filter on list`: `206ms`
- `filterv on list`: `208ms`
- `filter on vector`: `222ms`
- `filterv on vector`: `173ms`
- `keep on list`: `325ms`
- `keep on vector`: `267ms`
- `map-indexed on list`: `268ms`
- `map-indexed on vector`: `180ms`
- `count on list`: `85ms`
- `count on vector`: `0ms`
- `empty? on list`: `0ms`
- `empty? on vector`: `0ms`
- `reduce on list`: `177ms`
- `reduce on vector`: `122ms`
- `into vector from list`: `137ms`
- `into vector from vector`: `160ms`

The main takeaways are:

- `mapv` is consistently the better choice for vector-oriented work
- `keep` and `map-indexed` both benefit from direct vector paths when the input is a vector
- the one-pass `filterv` path now beats the generic vector `filter`
- `empty?` is now a direct shape check on the common collection types
- `reduce` on vectors benefits from the direct index-based fast path
- `count` on vectors is effectively free
- `into` is still a linear copy path, which is fine for now but is worth revisiting if it becomes a hot spot

## Example

```scheme
(def x (read-string "{:a [1 2] :b #{3}}"))
(println "Parsed:" x)
(println "A:" (get x :a))
(println "B:" (get x :b))
```

## Development notes

- Load `cluck-init.scm` in a fresh process when testing changes to reader syntax or macros.
- Reloading the same source files into the same live REPL can be awkward because this project deliberately redefines core syntax forms.
- The codebase is still early and intentionally narrow. The next likely steps are namespace polish and deeper packaging work.
