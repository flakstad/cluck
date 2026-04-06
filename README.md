# Cluck

A Clojure-flavored language layer for CHICKEN Scheme.

`Cluck` is an experimental Clojure-flavored language layer on top of CHICKEN Scheme.

Some source files and build artifacts still use the historical `scm-clj` prefix.

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

For Geiser or any other REPL where you want to return to the host prompt:

```scheme
(load "/Users/andreas/Projects/scm-clj/scm-clj-init.scm")
```

That loads the language layer and installs the reader syntax, but does not start a nested REPL.

For a standalone terminal REPL:

```scheme
(load "/Users/andreas/Projects/scm-clj/scm-clj-repl.scm")
```

That file intentionally drops into the Cluck REPL, so it will appear to keep running until you exit the nested prompt.

## Demo program

There is a small demo program in:

- [`demo.clj.scm`](./demo.clj.scm)

It is loaded by:

- [`run-demo.scm`](./run-demo.scm)

Run it with CHICKEN's interpreter after checking out the repo:

```scheme
(load "/Users/andreas/Projects/scm-clj/run-demo.scm")
```

Or from the command line:

```bash
csi -q -s /Users/andreas/Projects/scm-clj/run-demo.scm
```

The demo prints a small report over a vector of maps and shows the syntax in action.

## Smoke tests

There is also a small smoke-test harness in:

- [`smoke.clj.scm`](./smoke.clj.scm)

It is loaded by:

- [`run-smoke-tests.scm`](./run-smoke-tests.scm)

Run it with:

```bash
csi -q -s /Users/andreas/Projects/scm-clj/run-smoke-tests.scm
```

The smoke tests check the reader, printer, function macros, threading forms, and a few core collection helpers.

## Namespaces

`Cluck` now has a small namespace registry so you can start organizing code by namespace instead of one flat global soup.

- `ns` sets the active namespace
- `in-ns` switches the active namespace
- `current-ns` returns the active namespace symbol
- `find-ns` returns the registry entry for a namespace
- `all-ns` lists known namespaces
- `ns-publics` returns a map of public vars in a namespace
- `ns-resolve` looks up a var by namespace and symbol

This is enough to structure source files and inspect exports. Full Clojure-style resolution and `require` semantics are still future work.

## Native Build

There is now a trivial CLI benchmark in:

- [`bench.clj.scm`](./bench.clj.scm)

It is loaded by:

- [`run-bench.scm`](./run-bench.scm)

The benchmark builds a synthetic backlog, filters it, and prints a summary using the `Cluck` runtime and namespace support.

Build the translated C and native binary with:

```bash
csc -k -v -O2 -strip -o build/scm-clj-bench run-bench.scm
```

That leaves:

- `build/scm-clj-bench.c`
- `build/scm-clj-bench`

On this machine, the kept artifacts are about:

- `build/scm-clj-bench.c`: `7.6K`
- `build/scm-clj-bench`: `50K`

Important caveat:

- the current native build compiles the `run-bench.scm` wrapper
- that wrapper still `load-relative`s `scm-clj-init.scm` and `bench.clj.scm` at startup
- so these timings are a measure of the current hosted language layer and runtime loader path, not yet a fully self-contained AOT image

A 100000-item run on this machine produced:

- interpreted `csi -q -s run-bench.scm 100000`: `13.35s` real, `12.83s` user
- native `./build/scm-clj-bench 100000`: `13.53s` real, `12.82s` user

The workload is allocation-heavy, so the native binary is not dramatically faster yet. The useful result here is that we have a small native artifact and a clear baseline for future runtime work.

## Example

```scheme
(def x (read-string "{:a [1 2] :b #{3}}"))
(println "Parsed:" x)
(println "A:" (get x :a))
(println "B:" (get x :b))
```

## Development notes

- Load `scm-clj-init.scm` in a fresh process when testing changes to reader syntax or macros.
- Reloading the same source files into the same live REPL can be awkward because this project deliberately redefines core syntax forms.
- The codebase is still early and intentionally narrow. The next likely steps are namespace support, destructuring, and eventually immutable collections.
