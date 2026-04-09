# Cluck Ro CLI FC/IS

This document records the intended architecture for the `examples/cluck/ro`
spike.

The goal is to recreate the Ro CLI in Cluck, not to reproduce the server /
client split from the Clojure project. The Odin Ro codebase is the better shape
reference for this example: a direct CLI front door with separate read and write
paths.

## Boundary

- The functional core should own command meaning, normalization, and planning.
- The imperative shell should own argv parsing, environment handling, database
  open/close, filesystem access, subprocess calls, and formatting stdout/stderr.
- The shell should not decide domain behavior.
- The core should not perform IO.

## Planned module shape

The exact namespaces can evolve, but the responsibilities should stay split:

- core namespaces: pure command planners, read-model derivation, validation, and
  output envelope shaping
- shell namespaces: entrypoint, CLI parsing, JSON/EDN printing, and IO effect
  execution

## Effect contract

Planned command planners should return ordered effects instead of performing IO
directly.

A simple shape is enough:

```clojure
{:effects [[:store/write {:kind :item/create
                          :payload {...}}]
           [:io/print {:stream :stdout
                       :value {...}}]]}
```

Rules:

- effects are ordered
- core planning must be deterministic
- shell code executes effects in order
- output shaping should happen in core where possible, not in the shell

## Test seams

The testing plan should cover three layers:

1. Unit tests for pure helpers and planners.
2. Integration tests that run the Cluck CLI under development and compare it to
   the Odin `ro` binary on `PATH`.
3. Fixture/golden tests for the important contracts: help text, `docs`, status,
   list/show commands, and JSON or EDN envelopes.

The integration tests are important because they let us check parity quickly
while the CLI is still being rebuilt command by command.

## Non-goals

- No web/server layer in this spike.
- No TUI work until the CLI surface is in good shape.
- No attempt to copy the Clojure Ro transport boundary.
