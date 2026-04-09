# Cluck Datastar Clock

This example shows a minimal Datastar-style clock app built on top of the
existing Cluck Ring layer and the Spiffy/intarweb HTTP stack.

What it does:

- serves an HTML shell at `/`
- serves the vendored official `datastar.js` client bundle from `/datastar.js`
  (pinned to Datastar `v1.0.0-RC.8`) from an embedded asset in the static
  binary
- opens an SSE stream at `/clock-stream` on page load
- updates the clock once per second using a Datastar `datastar-patch-elements`
  event

What it does not do yet:

- it does not implement the full Datastar ADR
- it does not add a reusable top-level Cluck library yet
- the SSE transport stays example-local for now
- the JavaScript client is vendored from the official Datastar release and is
  not handwritten in this repo

Run it from source:

```sh
csi -q -s examples/cluck/datastar-clock/run.scm 8082
```

Build a native binary:

```sh
csc -static -deployed -k -v -O2 -strip -o build/datastar-clock-standalone \
  examples/cluck/datastar-clock/run-standalone.scm
```

Run the native binary:

```sh
./build/datastar-clock-standalone 8082
```

The native launcher is self-contained. Build it from the repo root, then you
can run or copy the resulting binary anywhere without the source tree.

On this machine, the resulting binary is about `7.9 MB` and links only
against `libSystem` on macOS.

Then open `http://127.0.0.1:8082/` in a browser.

Manual checks:

- `curl -i http://127.0.0.1:8082/`
- `curl -i http://127.0.0.1:8082/datastar.js`
- `curl -N http://127.0.0.1:8082/clock-stream`
- `csi -q -s test/run.scm`

The browser page should keep updating the clock without a page refresh. The
full ADR-backed Datastar work is tracked in `item-2hz`.
