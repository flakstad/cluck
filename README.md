# Cluck

`Cluck` is a Clojure-flavored language layer for CHICKEN Scheme.

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

## What `Cluck` is trying to do

The project is exploring a Clojure-like surface on top of CHICKEN Scheme:

- keywords, maps, sets, and vectors with EDN-style syntax
- core helpers such as `def`, `defn`, `fn`, `let`, `if`, `when`, `cond`, `->`, and `->>`
- common sequence helpers like `seq`, `first`, `rest`, `count`, `map`, `filter`, and `reduce`
- mutable maps and sets for now, with immutable collections deferred until later
- a REPL and printing experience that feels closer to Clojure than raw Scheme

This is intentionally a language layer, not just a normal library.

## Current status

The current implementation supports:

- `:keywords`
- `[1 2 3]` vectors
- `{:a 1 :b 2}` maps
- `#{1 2 3}` sets
- `read-string`
- `pr-str`, `str`, `println`, and `prn`
- mutable `assoc`, `dissoc`, `conj`, `get`, `contains?`, `seq`, `map`, `mapv`, `filter`, `filterv`, and `reduce`
- `ns`, `in-ns`, `current-ns`, `find-ns`, `all-ns`, `ns-publics`, and `ns-resolve`
- `require` plus `ns`-time `:require` directives for loading namespace files
- Clojure-style special forms and threading macros
- `def` and `defn` intern into the active namespace

Notes:

- vectors are still ordinary CHICKEN vectors, so the host REPL prints them as `#(...)`
- keywords, maps, and sets use custom record types so the host REPL can print them in Clojure-style form
- the collection layer is mutable for now
- the namespace layer is intentionally lightweight and registry-based; it is not full Clojure namespace resolution yet
- `seq` is intentionally cheap and unsorted; stable ordering is handled by `pr-str` instead of traversal

## Performance Direction

`Cluck` is aiming for an eager, direct Clojure-flavored language, not a lazy one.

- `map` and `filter` stay eager and return lists
- `mapv` and `filterv` are the vector-oriented fast paths
- `seq` should be a cheap adapter, not a place where we sort or realize expensive views
- `pr-str` can stay slower and stable because printing is not the hot path
- control-flow macros should expand directly and avoid runtime helper calls when possible
- Scheme tail recursion is enough for iterative code, so plain recursive helpers are fine where they stay tail-recursive

The practical goal is to keep the syntax familiar while making the runtime feel closer to direct Scheme than to lazy Clojure.

## Loading it

From the repository root, in Geiser or any other REPL where you want to return to the host prompt:

```scheme
(load "Cluck-init.scm")
```

That loads the language layer and installs the reader syntax, but does not start a nested REPL.

For a standalone terminal REPL:

```scheme
(load "Cluck-repl.scm")
```

That file intentionally drops into the `Cluck` REPL, so it will appear to keep running until you exit the nested prompt.

## Demo program

There is a small demo program in:

- [`demo.clj.scm`](./demo.clj.scm)

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

- [`smoke.clj.scm`](./smoke.clj.scm)

It is loaded by:

- [`run-smoke-tests.scm`](./run-smoke-tests.scm)

Run it with:

```bash
csi -q -s run-smoke-tests.scm
```

The smoke tests check the reader, printer, function macros, threading forms, and a few core collection helpers.

## Namespaces

`Cluck` now has a small namespace registry so you can start organizing code by namespace instead of one flat global soup.

- `ns` sets the active namespace
- `require` loads namespace files and returns to the caller's namespace afterwards
- `in-ns` switches the active namespace
- `current-ns` returns the active namespace symbol
- `find-ns` returns the registry entry for a namespace
- `all-ns` lists known namespaces
- `ns-publics` returns a map of public vars in a namespace
- `ns-resolve` looks up a var by namespace and symbol

`ns` supports a small subset of `:require` directives:

- `[foo.bar :refer [x y]]` copies selected public vars into the current namespace registry
- `[foo.bar :refer :all]` copies all public vars into the current namespace registry
- `[foo.bar :as fb]` registers an alias that `ns-resolve` can use

Namespace source files are located by namespace path, starting with:

- `foo.bar` -> `foo/bar.clj.scm`
- fallback lookups also check `foo/bar.scm`, `foo/bar.clj`, and root-level `bar.*`
- `src/` is searched as a secondary prefix

This is enough to structure source files, inspect exports, and load small module trees. Full Clojure-style symbol qualification is still future work.

## Module Demo

There is a small require/ns demo in:

- [`Cluck/math.clj.scm`](./Cluck/math.clj.scm)
- [`Cluck/app.clj.scm`](./Cluck/app.clj.scm)

It is loaded by:

- [`run-require-demo.scm`](./run-require-demo.scm)

Run it with:

```bash
csi -q -s run-require-demo.scm
```

The smoke tests also load `Cluck.math` through `require` to verify namespace restoration and alias lookup.

## Native Build

There is now a trivial CLI benchmark in:

- [`bench.clj.scm`](./bench.clj.scm)

It is loaded by:

- [`run-bench.scm`](./run-bench.scm)

The benchmark builds a synthetic backlog, filters it, and prints a summary using the `Cluck` runtime and namespace support.

Build the translated C and native binary with:

```bash
csc -k -v -O2 -strip -o build/Cluck-bench run-bench.scm
```

That leaves:

- `build/Cluck-bench.c`
- `build/Cluck-bench`

On this machine, the kept artifacts are about:

- `build/Cluck-bench.c`: `7.6K`
- `build/Cluck-bench`: `50K`

Important caveat:

- the current native build compiles the `run-bench.scm` wrapper
- that wrapper still `load-relative`s `Cluck-init.scm` and `bench.clj.scm` at startup
- so these timings are a measure of the current hosted language layer and runtime loader path, not yet a fully self-contained AOT image

A 100000-item run on this machine produced:

- interpreted `csi -q -s run-bench.scm 100000`: `13.35s` real, `12.83s` user
- native `./build/Cluck-bench 100000`: `13.53s` real, `12.82s` user

The workload is allocation-heavy, so the native binary is not dramatically faster yet. The useful result here is that we have a small native artifact and a clear baseline for future runtime work.

## Collections Benchmark

There is also a smaller benchmark focused on the collection primitives we care about most in the language layer:

- [`collections-bench.clj.scm`](./collections-bench.clj.scm)
- [`run-collections-bench.scm`](./run-collections-bench.scm)

This suite compares:

- `map` vs `mapv`
- `filter` vs `filterv`
- list inputs vs vector inputs

Run it with:

```bash
csi -q -s run-collections-bench.scm 5000 100
```

Or build a native binary:

```bash
csc -k -v -O2 -strip -o build/Cluck-collections-bench run-collections-bench.scm
```

The benchmark prints per-case timings using CHICKEN's process timer, while external `time -l` is still the best way to inspect wall-clock, CPU, and memory behavior from the shell on macOS.

On this machine with `5000` items and `100` rounds:

- interpreted `csi -q -s run-collections-bench.scm 5000 100`: `2.53s` real, `2.49s` user, about `27.5MB` RSS
- native `./build/Cluck-collections-bench 5000 100`: `2.68s` real, `2.48s` user, about `26.7MB` RSS
- `build/Cluck-collections-bench.c`: `7.2K`
- `build/Cluck-collections-bench`: `50K`

Per-case timings from the benchmark run:

- `map on list`: `239ms`
- `mapv on list`: `239ms`
- `map on vector`: `262ms`
- `mapv on vector`: `185ms`
- `filter on list`: `213ms`
- `filterv on list`: `214ms`
- `filter on vector`: `225ms`
- `filterv on vector`: `178ms`
- `count on list`: `86ms`
- `count on vector`: `0ms`
- `reduce on list`: `182ms`
- `reduce on vector`: `125ms`
- `into vector from list`: `142ms`
- `into vector from vector`: `165ms`

The main takeaways are:

- `mapv` is consistently the better choice for vector-oriented work
- the one-pass `filterv` path now beats the generic vector `filter`
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

 - Load `Cluck-init.scm` in a fresh process when testing changes to reader syntax or macros.
- Reloading the same source files into the same live REPL can be awkward because this project deliberately redefines core syntax forms.
- The codebase is still early and intentionally narrow. The next likely steps are namespace support, destructuring, and eventually immutable collections.
