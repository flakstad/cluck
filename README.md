# Cluck

`Cluck` is a Clojure-flavored language layer for CHICKEN Scheme.

It is experimental and focused on small native tools, a REPL-driven workflow, and a practical core library.

Binary policy: when this README says "native binary", it means a
self-contained artifact that can be handed to someone else and run without the
source tree or a separately managed runtime install. That also means no
third-party dynamic library dependency in the deliverable. Source-backed
launchers are useful development helpers, but they are not counted as
distributable binary deliverables.

The goal is not to reimplement Clojure on the JVM. The goal is to get the parts of the Clojure experience that matter most for small native tools:

- EDN-like reader syntax
- Clojure-style data literals
- `comment` and `#_` for scratchpad-friendly source editing
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
- core helpers such as `def`, `defn`, `fn`, `let`, `if`, `when`, `cond` with `:else`, `case`, `cond->`, `cond->>`, `some->`, `some->>`, `and`, `or`, `->`, and `->>`
- common sequence helpers like `seq`, `first`, `rest`, `take`, `drop`, `take-nth`, `partition`, `partition-by`, `frequencies`, `concat`, `interleave`, `flatten`, `last`, `butlast`, `distinct`, `dedupe`, `split-with`, `reductions`, `group-by`, `count`, `map`, `filter`, and `reduce`
- mutable maps and sets by default, with an opt-in `cluck.persistent` namespace for persistent collections and `cluck.mutable` for host hash tables and sets
- a REPL and printing experience that feels closer to Clojure than raw Scheme
- `.clk` is the preferred source extension for cluck code; `.scm` stays for Scheme glue and bootstrap files

This is intentionally a language layer, not just a normal library.

## Current status

The current implementation supports:

- `:keywords`
- `[1 2 3]` vectors
- `{:a 1 :b 2}` maps
- `#{1 2 3}` sets
- keywords can be used as lookup functions, e.g. `(:a {:a 1})`
- `type` for runtime type hints and `vec` for turning collections into vectors
- `slurp`, `spit`, `take`, `drop`, `take-nth`, `partition`, `partition-by`, `frequencies`, `concat`, `interleave`, `flatten`, `last`, `butlast`, `distinct`, `dedupe`, `split-with`, `reductions`, and `group-by` in `cluck.core`, plus `cluck.io` for lower-level ports and string/stream helpers
- `cluck.edn/read-string`
- the separate top-level `hiccup/` library tree for Hiccup 2-style HTML
  rendering helpers, with `hiccup.core` as the single API
- the separate top-level `ring/` library tree for Ring-style request/response/middleware helpers, including signed-cookie sessions, params, request IDs, exception handling, JSON body/response helpers, CORS, static resources, HEAD handling, content length, conditional GET, trusted proxy/host handling for redirects, and `ring.adapter.spiffy` for the Spiffy bridge
- `atom`, `atom?`, `deref`, `reset!`, `swap!`, and `compare-and-set!`
- `cluck.mutable` for explicit mutable map/set helpers and host interop
- `cluck.persistent` for opt-in persistent/immutable map and set helpers
- `cluck.examples.outline`
- `cluck.examples.datastar-clock`
- `pr-str`, `str`, `format`, `println`, and `prn`
- mutable `assoc`, `dissoc`, `conj`, `get`, `contains?`, `seq`, `map`, `mapv`, `filter`, `filterv`, `keep`, `map-indexed`, `empty?`, and `reduce` in the core layer, plus a separate opt-in persistent collection namespace
- `let`, `fn`, and `defn` destructuring for vectors and maps
- `ns`, `in-ns`, `current-ns`, `find-ns`, `all-ns`, `ns-publics`, and `ns-resolve`
- `require` plus `ns`-time `:require` directives for loading namespace files
- Clojure-style special forms and threading macros, including `case`, `cond->`, `cond->>`, `some->`, and `some->>`
- `def` and `defn` intern into the active namespace, return the defined value when evaluated, and support docstrings via `doc`
- core runtime vars like `map`, `get`, `assoc`, `reduce`, and `seq` carry docstrings that surface through `doc` and `C-c C-d`
- the public namespace layout is mirrored through `cluck.core`, `cluck.string`, `cluck.io`, `cluck.set`, `cluck.mutable`, `cluck.persistent`, and `cluck.edn`, plus the separate top-level `ring.request`, `ring.response`, `ring.middleware`, and `ring.adapter.spiffy` libraries, with `cluck.core` installed at bootstrap time

Notes:

- vectors are still ordinary CHICKEN vectors, so the host REPL prints them as `#(...)`
- keywords, maps, and sets use custom record types so the host REPL can print them in Clojure-style form
- the collection layer is mutable by default; persistent collections live in `cluck.persistent`
- the namespace layer is intentionally lightweight and uses separate public/import tables; it is not full Clojure namespace resolution yet
- `seq` is intentionally cheap and unsorted; stable ordering is handled by `pr-str` instead of traversal

## Scheme Interop

`.clk` files are still Scheme source files with cluck syntax layered on top. You can use ordinary Scheme forms, procedures, and host interop freely alongside cluck forms.

The main caveat is that cluck repurposes a few core binding and threading forms, so the surface is not identical to raw Scheme:

- `let`
- `fn`
- `defn`
- `if`
- `cond` with `:else`, `case`, `cond->`, `cond->>`, `some->`, and `some->>`
- `when`
- `->`
- `->>`

If you need exact Scheme semantics in a `.clk` file, keep that code in a `.scm` helper or drop to the core forms such as `##core#let`.

When a `.clk` file reaches out to CHICKEN eggs, keep that work explicit by using `ns` `:require` with prefixed imports so the host interop stays visible and does not leak names into the Cluck surface.

If you need mutable escape hatches, use `cluck.mutable` for host hash tables and sets, or keep the raw Scheme interop in `.scm` helpers; the ordinary Cluck collection API stays mutable by default. If you want persistent maps and sets, require `cluck.persistent` explicitly. `set!` remains Scheme binding mutation, not a collection mutator.

For EDN parsing, prefer `cluck.edn/read-string` in app code. The interactive `src/cluck-init.scm` and `src/cluck-cli.scm` loaders also install a convenience top-level `read-string` alias for the REPL and command-line workflow, but the namespaced form is the stable one for libraries and standalone binaries.

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

```bash
chicken-install hash-trie
```

That installs the optional persistent collection backend used by `cluck.persistent`. You only need this if you plan to use the opt-in persistent namespace.

Then load the language layer:

```scheme
(load "src/cluck-init.scm")
```

That loads the language layer and installs the reader syntax, but does not start a nested REPL.

To load a `.clk` file with Cluck namespace resolution rooted at that file's project directory, use:

```scheme
(load-file "examples/cluck/weather/main.clk")
```

That is the path-aware loader used by the command-line helper scripts and by `C-c C-l` in `cluck-mode`.

For a standalone terminal REPL:

```scheme
(load "src/cluck-repl.scm")
```

That file intentionally drops into the `cluck` REPL, so it will appear to keep running until you exit the nested prompt.

For a more convenient command-line entrypoint, use the launcher source:

```scheme
(load "src/cluck-cli.scm")
```

It starts a REPL by default, but also accepts a few simple flags:

```bash
csi -q -s src/cluck-cli.scm
csi -q -s src/cluck-cli.scm -e '(+ 1 2)'
csi -q -s src/cluck-cli.scm -l examples/cluck/demo/main.clk
```

To build a source-backed development launcher:

```bash
csc -k -v -O2 -strip -o build/cluck src/cluck-cli.scm
```

That produces `build/cluck` plus the generated C wrapper in `build/cluck.c`. The launcher still loads the cluck source files at startup, so it is a convenient development front-end rather than a self-contained binary.

## Editor Support

The repo includes a copyable Emacs setup under [`emacs/`](./emacs/):

- `emacs/setup-cluck-mode.el`
- `emacs/setup-cluck-repl.el`

Add that directory to your `load-path`, require those setup files, and you get
the same Cluck editing workflow used in my own config. See
[`emacs/README.md`](./emacs/README.md) for the install snippet.

In Emacs, `cluck-mode` is a derived `clojure-mode` variant for indentation, paredit, folding, and syntax coloring.

It also includes interactive eval helpers:

- `C-x C-e` and `C-c C-e` evaluate the sexp before point and show an inline result overlay
- `C-c C-c` evaluates the current top-level form with an inline result overlay
- `C-c C-p` evaluates the sexp before point and opens the result in a popup buffer
- popup result buffers preserve multiline output and wrap long lines instead of truncating them
- `C-c C-d` shows the docstring for the symbol at point in a dedicated buffer
- inline overlays clear on the next command, so they behave more like transient feedback than permanent annotations
- `C-c C-r` reports in the echo area for a selected region
- `C-c C-b` and `C-c C-k` evaluate the whole buffer through a temporary file so syntax errors are caught on repeated runs
- `C-c C-l` reloads the current file from disk using the path-aware `load-file` helper so nested `ns :require` lookups resolve relative to the loaded file
- completion is explicit: press `TAB` after a namespace prefix like `str/`, `uri/`, `cluck.string/`, or `cluck.core/`; ordinary typing does not trigger completion
- `M-.` jumps to the definition of the symbol at point, and `M-,` returns to the previous location

It is intentionally not wired to CIDER or LSP for Cluck buffers by default. Instead, the workflow is:

- edit `.clk` files in `cluck-mode`
- start a Cluck REPL with `./build/cluck` or `src/cluck-repl.scm`
- send the current form, region, buffer, or file from `cluck-mode`
- use `C-x C-e` or `C-c C-e` for the previous sexp, `C-c C-c` for the current top-level form, `C-c C-p` for a popup result buffer, `C-c C-r` for a selected region, `C-c C-b` or `C-c C-k` for the buffer, `C-c C-d` for docstrings, and `C-c C-l` to reload the file
- use `M-.` to jump to definitions and `M-,` to jump back
- use `C-c C-z` to switch to the REPL buffer

That keeps the editing experience light and avoids Clojure-specific REPL assumptions that do not fit Cluck yet.

## Demo program

There is a small demo program in:

- [`examples/cluck/demo/main.clk`](./examples/cluck/demo/main.clk)

It is loaded by:

- [`examples/cluck/demo/run.scm`](./examples/cluck/demo/run.scm)

Run it with CHICKEN's interpreter after checking out the repo:

```scheme
(load "examples/cluck/demo/run.scm")
```

Or from the command line:

```bash
csi -q -s examples/cluck/demo/run.scm
```

The demo prints a small report over a vector of maps and shows the syntax in action.

## SDL3 drawing scaffold

The SDL3 example is a minimal drawing app scaffold that now opens a window,
 tracks mouse, pen, and recent keyboard input, and supports a basic sketchpad
 workflow with a soft pressure-sensitive brush:

- [`examples/cluck/draw/main.clk`](./examples/cluck/draw/main.clk)
- [`src/cluck/sdl3.clk`](./src/cluck/sdl3.clk)
- [`examples/cluck/draw/run.scm`](./examples/cluck/draw/run.scm)

It uses direct C interop through `cluck.sdl3`, but the application logic stays
in Cluck. The release launcher vendors a static SDL3 build into `build/vendor/`
and compiles a self-contained native binary:

```bash
csi -q -s examples/cluck/draw/run.scm
./build/draw
```

For REPL-driven work, start a normal Cluck REPL and evaluate the explicit
startup forms in the comment block at the end of
[`examples/cluck/draw/main.clk`](./examples/cluck/draw/main.clk). That loads
`examples/cluck/draw/dev.clk`, compiles the SDL3 support library on demand, and
defines the draw app. Call `(start-dev!)` explicitly when you want to open the
window. In the current draw setup, that starts a supervised child draw process
by default so the SDL window can be restarted independently of the REPL. From
there you can call functions
like `set-title!`, `set-background!`, `set-render-fn!`, `render-now!`,
`mouse-position`, `input-summary`, `save-canvas!`, `load-canvas!`, and `stop!`
while the window stays open. Use the mouse wheel to zoom around the cursor,
hold `shift` while dragging to pan, and drag with the mouse or pen to paint
strokes. Press `d` to toggle the debug panel on demand. The current tool
shortcuts are:

- `u` undo the last action
- `c` clear the canvas
- `e` eraser
- `1`/`2`/`3` brush sizes
- `]`/`+`/`=` zoom in
- `[`/`-` zoom out
- `h`/`j`/`k`/`l` pan left/down/up/right
- `0` reset the viewport
- wheel zooms around the cursor
- `shift`+drag pans the viewport
- `save-canvas!` / `load-canvas!` round-trip the current canvas to
  `build/cluck-draw-state.edn` by default
- draw session logging writes to `build/cluck-draw.log`
- crashes write a snapshot to `build/cluck-draw-crash.edn`
- `draw-supervisor-status` reports the current child/supervisor state
State changes redraw the live window immediately, and the resulting release
binary is self-contained and does not depend on a separately installed SDL3
dylib.

In `cluck-mode`, `C-c C-z` switches to the ordinary Cluck REPL buffer. The REPL
starts with no window and does not load SDL automatically. When you want the
draw app, evaluate the explicit startup forms in the comment block at the end
of `examples/cluck/draw/main.clk`, or evaluate
`(load-file "examples/cluck/draw/dev.clk")` yourself and then call
`(start-dev!)`. If you need the older same-process loop for a focused repro or
test, call `(draw-disable-supervision!)` before `(start-dev!)`.

The current goal is to keep the SDL3 boundary isolated while extending the
interactive drawing loop one step at a time.

## Ncurses TUI Todos

Another egg-backed example lives in:

- [`examples/cluck/tui-todos/main.clk`](./examples/cluck/tui-todos/main.clk)
- [`examples/cluck/tui-todos/run.scm`](./examples/cluck/tui-todos/run.scm)
- [`examples/cluck/tui-todos/run-standalone.scm`](./examples/cluck/tui-todos/run-standalone.scm)

It uses `ncurses` and `sqlite3` to build a split-pane terminal app with list
navigation, a detail pane, search, kind filtering, add/edit/delete actions,
status toggles, priority changes, and on-disk persistence in
`build/tui-todos.sqlite3`.

Install the eggs once:

```bash
chicken-install ncurses sqlite3
```

Run it from source with:

```bash
csi -q -s examples/cluck/tui-todos/run.scm
```

The app seeds a few starter entries on first launch and keeps its data under
`build/` so it stays local to the checkout.

Build a native binary for the same app with:

```bash
csc -static -deployed -k -v -O2 -strip -o build/tui-todos-standalone examples/cluck/tui-todos/run-standalone.scm -L -lncurses -L -lsqlite3
```

The extra `-L` flags pass the native `ncurses` and `sqlite3` libraries through
to the linker for this egg-backed example.

Then run it with either the default database path or an explicit file:

```bash
./build/tui-todos-standalone
./build/tui-todos-standalone build/my-tui-todos.sqlite3
```

The standalone launcher uses the same TUI and creates `build/` in the current
working directory on first launch when you keep the default database path.

## Smoke tests

There is also a small smoke-test harness in:

- [`test/smoke.clk`](./test/smoke.clk)

It is loaded by:

- [`test/run.scm`](./test/run.scm)
- [`test/run-draw-toggle.scm`](./test/run-draw-toggle.scm)
- [`test/run-draw-tools.scm`](./test/run-draw-tools.scm)
- [`test/run-draw-save-load.scm`](./test/run-draw-save-load.scm)
- [`test/run-draw-view.scm`](./test/run-draw-view.scm)
- [`test/run-draw-input.scm`](./test/run-draw-input.scm)
- [`test/run-draw-cache.scm`](./test/run-draw-cache.scm)
- [`test/run-draw-lifecycle.scm`](./test/run-draw-lifecycle.scm)
- [`test/run-tui-todos.scm`](./test/run-tui-todos.scm)
- [`test/run-draw-replay.scm`](./test/run-draw-replay.scm)
- [`test/run-draw-live-replay.scm`](./test/run-draw-live-replay.scm)
- [`test/run-draw-brush-undo.scm`](./test/run-draw-brush-undo.scm)
- [`test/run-draw-live-brush-undo.scm`](./test/run-draw-live-brush-undo.scm)

Run it with:

```bash
csi -q -s test/run.scm
csi -q -s test/run-draw-toggle.scm
csi -q -s test/run-draw-tools.scm
SDL_VIDEODRIVER=dummy csi -q -s test/run-draw-save-load.scm
SDL_VIDEODRIVER=dummy csi -q -s test/run-draw-view.scm
SDL_VIDEODRIVER=dummy csi -q -s test/run-draw-input.scm
SDL_VIDEODRIVER=dummy csi -q -s test/run-draw-cache.scm
SDL_VIDEODRIVER=dummy csi -q -s test/run-draw-lifecycle.scm
csi -q -s test/run-tui-todos.scm
SDL_VIDEODRIVER=dummy csi -q -s test/run-draw-replay.scm
SDL_VIDEODRIVER=dummy csi -q -s test/run-draw-live-replay.scm
SDL_VIDEODRIVER=dummy csi -q -s test/run-draw-replay.scm 1000
csi -q -s test/run-draw-brush-undo.scm
SDL_VIDEODRIVER=dummy csi -q -s test/run-draw-live-brush-undo.scm
```

The smoke tests check the reader, printer, function macros, threading forms, and a few core collection helpers.
The focused draw probes cover the keyboard toggle path, the mutable draw state path, the SDL input/pressure/focus path, the SDL canvas cache path, the running draw lifecycle path, and the brush-change/undo path.
The draw replay probes cover the scripted replay path, the live replay mode, and the dedicated brush/undo replay mode.
The TUI Todos probe covers the SQLite-backed example helpers, seed data, and a few formatting helpers without opening the TUI.

## Weather CLI Example

The canonical weather/forecast example is fully written in Cluck in:

- [`examples/cluck/weather/main.clk`](./examples/cluck/weather/main.clk)

It uses `ns :require` to pull in the CHICKEN eggs with prefixed imports:

- `http-client` as `http/`
- `json` as `json/`
- `uri-common` as `uri/`
- `cluck.string` as `str`

Imported eggs use slash-qualified call syntax in source, so the weather
example reads like:

- `http/with-input-from-request`
- `json/json-read`
- `uri/uri-reference`

The app file itself stays Cluck-only; the host-specific pieces live at the
namespace boundary.

Install the eggs once in your CHICKEN environment:

```bash
chicken-install http-client json uri-common
```

Run the weather CLI from source with:

```bash
csi -q -s examples/cluck/weather/run.scm Oslo
csi -q -s examples/cluck/weather/run.scm "San Francisco"
```

Build a self-contained native binary with:

```bash
csc -static -deployed -k -v -O2 -strip -o build/cluck-weather-standalone examples/cluck/weather/run-standalone.scm
```

On this machine, the resulting binary is about `7.3 MB` and runs without the
source tree present. It links only against `libSystem` on macOS.

Size notes:

- `-d0 -no-trace` shaved a small amount off the binary size
- `-O0` did not help; it actually made the binary larger on this build
- the main size cost is the statically linked CHICKEN runtime plus the transitive egg objects pulled in by `http-client`, `json`, and `uri-common`
- there is no automatic function-level tree-shaking pass in the build; the practical granularity is module/object-file level

The weather app is intentionally small, but it is important because it proves
the current Cluck shape works for a real networked tool while keeping the egg
boundary explicit in the namespace form.

## Web Server Example

A small web server example lives in:

- [`examples/cluck/web-server/main.clk`](./examples/cluck/web-server/main.clk)
- [`examples/cluck/web-server/README.md`](./examples/cluck/web-server/README.md)

It keeps the request routing in pure Cluck, uses the separate top-level
`ring.*` libraries for request/response/middleware helpers, and uses the
`spiffy` egg only through `ring.adapter.spiffy` for the server loop and
transport adapter.

The Ring library tree is documented in [`ring/README.md`](./ring/README.md).
The demo routes now include `/cookie`, `/visit`, and `/params`, and the
handler stack demonstrates cookie serialization, signed sessions, params
parsing, HEAD handling, and conditional GET with `ETag` support.

Install the eggs once in your CHICKEN environment:

```bash
chicken-install spiffy hmac sha2 message-digest message-digest-utils
```

If you want stable signed sessions across restarts, set
`CLUCK_WEB_SESSION_SECRET` before starting the server. The Ring library itself
expects an explicit secret; the example app generates a fresh random
per-process secret when that env var is unset so the demo still works without
extra configuration.

Run the server from source with:

```bash
csi -q -s examples/cluck/web-server/run.scm 8081
```

Try these requests while it is running:

```bash
curl -i http://127.0.0.1:8081/
curl -i http://127.0.0.1:8081/health
curl -i http://127.0.0.1:8081/echo/cluck
curl -i -c /tmp/cluck.cookies -b /tmp/cluck.cookies http://127.0.0.1:8081/cookie
curl -i -c /tmp/cluck.cookies -b /tmp/cluck.cookies http://127.0.0.1:8081/visit
curl -i -b /tmp/cluck.cookies http://127.0.0.1:8081/visit
curl -i 'http://127.0.0.1:8081/params?name=cluck&name=egg'
curl -i -X POST -H 'Content-Type: application/x-www-form-urlencoded' --data 'name=cluck&theme=dark' http://127.0.0.1:8081/params
curl -I http://127.0.0.1:8081/health
curl -i -H 'If-None-Match: "cluck-health-v1"' http://127.0.0.1:8081/health
curl -i http://127.0.0.1:8081/missing
```

## Datastar Clock Example

A small Datastar-style clock example lives in:

- [`examples/cluck/datastar-clock/main.clk`](./examples/cluck/datastar-clock/main.clk)
- [`examples/cluck/datastar-clock/README.md`](./examples/cluck/datastar-clock/README.md)

It keeps the page logic in pure Cluck, uses the existing `ring.adapter.spiffy`
transport boundary, and serves a vendored copy of the official Datastar client
bundle from [`examples/cluck/datastar-clock/datastar.js`](./examples/cluck/datastar-clock/datastar.js),
embedded into the self-contained native launcher via
[`examples/cluck/datastar-clock/assets.clk`](./examples/cluck/datastar-clock/assets.clk).

The example ships both a source launcher and a native-build launcher:

- [`examples/cluck/datastar-clock/run.scm`](./examples/cluck/datastar-clock/run.scm)
- [`examples/cluck/datastar-clock/run-standalone.scm`](./examples/cluck/datastar-clock/run-standalone.scm)

The example is intentionally minimal: it renders an HTML shell, opens an SSE
stream on load, and patches the clock text once per second with a
`datastar-patch-elements` event.

Run it from source with:

```bash
csi -q -s examples/cluck/datastar-clock/run.scm 8082
```

Or build and run the native launcher:

```bash
csc -static -deployed -k -v -O2 -strip -o build/datastar-clock-standalone \
  examples/cluck/datastar-clock/run-standalone.scm
./build/datastar-clock-standalone 8082
```

The native launcher is self-contained. Build it from the repo root, then you
can run or copy the resulting binary anywhere without the source tree.

On this machine, the resulting binary is about `7.9 MB` and links only
against `libSystem` on macOS.

Try these requests while it is running:

```bash
curl -i http://127.0.0.1:8082/
curl -i http://127.0.0.1:8082/datastar.js
curl -N http://127.0.0.1:8082/clock-stream
```

The colocated example tests live in
[`examples/cluck/datastar-clock/test.clk`](./examples/cluck/datastar-clock/test.clk)
and are loaded by [`test/smoke.clk`](./test/smoke.clk). Run the repo-wide smoke
suite with `csi -q -s test/run.scm`. The full ADR-backed Datastar follow-up is
tracked in `item-2hz`.

## TODO Scanner Utility

A second no-eggs example lives in:

- [`examples/cluck/todo/main.clk`](./examples/cluck/todo/main.clk)

It scans files for TODO/FIXME/XXX markers and stays Cluck-only by using
`cluck.fs` for file handling and `cluck.string` for text processing. The
source runner expands directories before calling the app, while the
self-contained binary accepts file paths directly.

Run it from source with:

```bash
csi -q -s examples/cluck/todo/run.scm README.md
```

Or point it at a directory:

```bash
csi -q -s examples/cluck/todo/run.scm .
```

The self-contained binary is built from the same app and is intended to take
file paths directly:

```bash
./build/todo-standalone README.md examples/cluck/todo/main.clk
```

To build a self-contained native binary:

```bash
csc -static -deployed -k -v -O2 -strip -o build/todo-standalone examples/cluck/todo/run-standalone.scm
```

On this machine, the resulting binary is in the same small self-contained
range as the other no-eggs utilities.

## Git Changelog Summarizer

Another no-eggs example lives in:

- [`examples/cluck/changelog/main.clk`](./examples/cluck/changelog/main.clk)

It runs `git log`, groups commit subjects into a few conventional categories,
and prints a compact summary. The app stays Cluck-only and uses the process
helpers for the Git invocation.

Run it from source with:

```bash
csi -q -s examples/cluck/changelog/run.scm
```

Or pass a range:

```bash
csi -q -s examples/cluck/changelog/run.scm HEAD~10..HEAD
```

The self-contained binary is built from the same app and uses the current
repository as its data source:

```bash
./build/changelog-standalone
```

To build a self-contained native binary:

```bash
csc -static -deployed -k -v -O2 -strip -o build/changelog-standalone examples/cluck/changelog/run-standalone.scm
```

On this machine, the resulting binary should stay in the same self-contained
size neighborhood as the other no-eggs utilities.

## Markdown Link Checker

Another no-eggs example lives in:

- [`examples/cluck/link-check/main.clk`](./examples/cluck/link-check/main.clk)

It scans Markdown files for broken local links. The source runner expands
directories before calling the app, while the self-contained binary accepts
file paths directly.

Run it from source with:

```bash
csi -q -s examples/cluck/link-check/run.scm README.md
```

Or point it at a directory:

```bash
csi -q -s examples/cluck/link-check/run.scm .
```

The self-contained binary is built from the same app and is intended to take
file paths directly:

```bash
./build/link-check-standalone README.md examples/cluck/link-check/main.clk
```

To build a self-contained native binary:

```bash
csc -static -deployed -k -v -O2 -strip -o build/link-check-standalone examples/cluck/link-check/run-standalone.scm
```

On this machine, the resulting binary should stay in the same self-contained
size neighborhood as the other no-eggs utilities.

## Markdown Outline Utility

Another no-eggs example lives in:

- [`examples/cluck/outline/main.clk`](./examples/cluck/outline/main.clk)

It stays Cluck-only and uses the existing `cluck.fs` and `cluck.string`
helpers for file and text handling.

Run it from source with:

```bash
csi -q -s examples/cluck/outline/run.scm README.md
```

Or pipe text on stdin:

```bash
cat README.md | csi -q -s examples/cluck/outline/run.scm
```

It prints a simple Markdown heading outline and is a good fit for the
self-contained binary path.

To build a self-contained native binary:

```bash
csc -static -deployed -k -v -O2 -strip -o build/outline-standalone examples/cluck/outline/run-standalone.scm
```

On this machine, the resulting binary is about `4.2 MB` and links only
against `libSystem` on macOS.

The reusable bootstrap pattern for the bundled example apps lives in
[`examples/cluck/bootstrap.scm`](./examples/cluck/bootstrap.scm). It is intentionally generic:

- it discovers the project root from the executable location
- it walks upward from the executable location until it finds `src/cluck.scm` or `src/cluck-cli.scm`
- it loads `src/cluck.scm`
- it loads a project source file with `load-file`

The shared [`src/cluck-bootstrap.scm`](./src/cluck-bootstrap.scm) remains as a
compatibility helper for the template and for new-project bootstrapping.

For a new project, copy the helper that best matches your layout and point it
at your own entrypoint file. That gives you a clean Scheme-side bootstrap
without mixing app logic into the launcher.

## Project Template

A small copyable starter lives in [`template/`](./template/).

- `template/bootstrap.scm` is the reusable bootstrap helper for a new project
- `template/run.scm` loads the Cluck runtime and the starter app
- `template/repl.scm` loads the Cluck runtime, starter app, and then starts a REPL
- `template/src/app/main.clk` is a minimal Cluck entrypoint

For a new project, either:

- set `CLUCK_HOME` to a local Cluck checkout, or
- copy the Cluck repo into `vendor/cluck/` under the new project

Then run or compile `template/run.scm` as the entrypoint. The bootstrap keeps
the Cluck runtime root on the module search path while loading your app, so
`cluck.*` namespaces resolve even when Cluck is vendored instead of installed
as an egg.

For interactive work, `template/repl.scm` is the starter REPL entrypoint. It
loads the same app namespace and drops into a Cluck REPL after startup.

To build native launchers, compile `run.scm` or `repl.scm` with `csc -k -v
-O2 -strip ...`. These are native front-ends, but they still source-load the
app at startup. The template bootstrap walks upward from the launcher
location, so keeping the binary under `build/` still works as long as it stays
inside the project tree. For a fully self-contained binary, use the standalone
weather packaging pattern described above.

## No-Eggs Example

A small example app that does not use external CHICKEN eggs lives in:

- [`examples/cluck/text-report/main.clk`](./examples/cluck/text-report/main.clk)

Run it with:

```bash
csi -q -s examples/cluck/text-report/run.scm README.md
```

Or pipe text on stdin:

```bash
cat README.md | csi -q -s examples/cluck/text-report/run.scm
```

It prints a simple line/blank-line/character summary and demonstrates how to
keep the application logic in Cluck while leaving file I/O in the bootstrap.

To build a self-contained native binary for the same example:

```bash
csc -static -deployed -k -v -O2 -strip -o build/text-report-standalone examples/cluck/text-report/run-standalone.scm
```

On this machine, the resulting binary is about `3.7 MB` and runs without the
source tree present. It links only against `libSystem` on macOS.

## Namespaces

`cluck` now has a small namespace registry plus a separate import table per namespace, so public vars and imported refs stay distinct.

The public namespace layout mirrors Clojure's shape:

- `cluck.core`
- `cluck.string`
- `cluck.fs`
- `cluck.io` for lower-level ports and string/stream helpers
- `cluck.process`
- `cluck.set`
- `cluck.mutable`
- `cluck.persistent`
- `cluck.edn`
- `cluck.walk`
- `cluck.math`
- basic type helpers like `parse-long`, `parse-double`, `type`, and `vec`
- `format` for `%s`, `%d`, `%%`, and `%.Nf` string interpolation

These namespaces are the intended public surface for user-facing code. `cluck.math` and `cluck.walk` are convenience namespaces; `cluck.examples.app` remains a sample/demo namespace.

Numeric values use CHICKEN's Scheme numeric tower underneath, which means Cluck can lean on the host for exact integers, rationals, and inexact reals. The user-facing helpers should still stay Clojure-shaped, so text parsing goes through `parse-long` / `parse-double`, while rendering uses `str`, `pr-str`, or `format`.

- `ns` sets the active namespace
- `require` loads namespace files and returns to the caller's namespace afterwards
- `in-ns` switches the active namespace
- `current-ns` returns the active namespace symbol
- `find-ns` returns the registry entry for a namespace
- `all-ns` lists known namespaces
- `ns-publics` returns a map of public vars in a namespace
- `ns-resolve` looks up a var by namespace and symbol

`ns` supports a focused subset of `:require` directives. In Cluck source,
`:as` aliases are the preferred style; `:refer` is still supported for
compatibility and small tests, but user code should generally stay namespace-qualified:

- `[foo.bar :as fb]` registers an alias that `ns-resolve` can use
- `[foo.bar :refer [x y]]` imports selected public vars into the current namespace
- `[foo.bar :refer :all]` imports all public vars into the current namespace
- `[foo.bar :exclude [x y]]` skips selected vars when using `:refer :all`
- `[http-client :as http]` imports a CHICKEN egg into a prefixed namespace when no Cluck source file exists for the target symbol
- `(:refer-clojure :exclude [...])` excludes selected core vars from the default core import set

Namespace source files are located by namespace path, starting with:

- `foo.bar` -> `foo/bar.clk`
- fallback lookups also check `foo/bar.clj.scm`, `foo/bar.scm`, and root-level `bar.*`
- `src/` is searched as a secondary prefix

- The mirrored namespace files currently live at:

- [`src/cluck/core.clk`](./src/cluck/core.clk)
- [`src/cluck/string.clk`](./src/cluck/string.clk)
- [`src/cluck/set.clk`](./src/cluck/set.clk)
- [`src/cluck/mutable.clk`](./src/cluck/mutable.clk)
- [`src/cluck/edn.clk`](./src/cluck/edn.clk)
- [`src/cluck/walk.clk`](./src/cluck/walk.clk)
- [`src/cluck/math.clk`](./src/cluck/math.clk)
- [`examples/cluck/todo/main.clk`](./examples/cluck/todo/main.clk)

This is enough to structure source files, inspect exports, and load small module trees. Full Clojure-style namespace qualification is still future work, but the current split between public vars and imports keeps `ns-publics` and `ns-resolve` usable.

`cluck.string` already covers the everyday helpers most small apps reach for:

- `blank?`, `trim`, `triml`, `trimr`
- `lower-case`, `upper-case`, `capitalize`
- `includes?`, `split`, `join`, `split-lines`
- `starts-with?`, `ends-with?`

`cluck.walk` provides a small tree-walking toolkit:

- `walk`, `prewalk`, `postwalk`
- `keywordize-keys`, `stringify-keys`

`cluck.math` gathers common numeric helpers:

- `abs`, `pow`, `sqrt`, `floor`, `ceil`, `ceiling`, `round`, `truncate`
- `mod`, `rem`, `quotient`, `remainder`
- `sin`, `cos`, `tan`, `asin`, `acos`, `atan`
- `exp`, `log`, `log10`
- `exact?`, `inexact?`, `exact-integer?`

## Direction

The next phase is about making Cluck prove itself on a real small program, not just adding syntax.

- keep the runtime eager, direct, and mutable by default
- continue the namespace split toward `cluck.core`, `cluck.string`, `cluck.io`, `cluck.set`, `cluck.mutable`, and a separate opt-in `cluck.persistent` namespace for persistent / immutable collections
- expand the core library with practical helpers such as `get-in`, `assoc-in`, `update`, `merge`, `merge-with`, `keys`, `vals`, `select-keys`, `zipmap`, `remove`, `mapcat`, `apply`, `partial`, and `comp`
- use one real dogfood app to drive the next round of API and namespace decisions
- prefer small native CLI or local data tools first; TODO scanning, link checking, and CSV/TSV summarization are all good candidates before larger app work
- leave more ambitious graphics work, such as SDL3 drawing, for a later phase

## Module Demo

There is a small require/ns demo in:

- [`src/cluck/walk.clk`](./src/cluck/walk.clk)
- [`src/cluck/math.clk`](./src/cluck/math.clk)
- [`examples/cluck/app/main.clk`](./examples/cluck/app/main.clk)

It is loaded by:

- [`examples/cluck/app/run.scm`](./examples/cluck/app/run.scm)

Run it with:

```bash
csi -q -s examples/cluck/app/run.scm
```

The smoke tests also load `cluck.walk` and `cluck.math` through `require` to verify namespace restoration and alias lookup.

## Native Build

There is now a trivial CLI benchmark in:

- [`bench/main.clk`](./bench/main.clk)

It is loaded by:

- [`bench/run.scm`](./bench/run.scm)

The benchmark builds a synthetic backlog, filters it, and prints a summary using the `cluck` runtime and namespace support.

Build the translated C and native binary with:

```bash
csc -k -v -O2 -strip -o build/cluck-bench bench/run.scm
```

That leaves:

- `build/cluck-bench.c`
- `build/cluck-bench`

On this machine, the kept artifacts are about:

- `build/cluck-bench.c`: `7.6K`
- `build/cluck-bench`: `50K`

Important caveat:

- the current native build compiles the `bench/run.scm` wrapper
- that wrapper still loads `src/cluck-init.scm` and `bench/main.clk` at startup
- so these timings are a measure of the current hosted language layer and runtime loader path, not yet a fully self-contained AOT image

A 100000-item run on this machine produced:

- interpreted `csi -q -s bench/run.scm 100000`: `13.35s` real, `12.83s` user
- native `./build/cluck-bench 100000`: `13.53s` real, `12.82s` user

The workload is allocation-heavy, so the native binary is not dramatically faster yet. The useful result here is that we have a small native artifact and a clear baseline for future runtime work.

## Collections Benchmark

There is also a smaller benchmark focused on the collection primitives we care about most in the language layer:

- [`bench/collections.clk`](./bench/collections.clk)
- [`bench/collections-run.scm`](./bench/collections-run.scm)

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
csi -q -s bench/collections-run.scm 5000 100
```

Or build a native binary:

```bash
csc -k -v -O2 -strip -o build/cluck-collections-bench bench/collections-run.scm
```

The benchmark prints per-case timings using CHICKEN's process timer, while external `time -l` is still the best way to inspect wall-clock, CPU, and memory behavior from the shell on macOS.

On this machine with `5000` items and `100` rounds:

- interpreted `csi -q -s bench/collections-run.scm 5000 100`: `3.53s` real, `3.49s` user, about `45MB` RSS
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
(require [cluck.edn :as edn])
(def x (edn/read-string "{:a [1 2] :b #{3}}"))
(println "Parsed:" x)
(println "A:" (get x :a))
(println "B:" (get x :b))
```

## Development notes

- Load `src/cluck-init.scm` in a fresh process when testing changes to reader syntax or macros.
- Reloading the same source files into the same live REPL can be awkward because this project deliberately redefines core syntax forms.
- The codebase is still early and intentionally narrow. The next likely steps are namespace polish and deeper packaging work.
- For a reusable native entrypoint in a new Cluck project, copy `src/cluck-bootstrap.scm` or start from `examples/cluck/bootstrap.scm` and point it at your project `.clk` file.
- The weather example now demonstrates a self-contained single-binary path; the example-local bootstrap is the stable bit to copy into an example tree today.
