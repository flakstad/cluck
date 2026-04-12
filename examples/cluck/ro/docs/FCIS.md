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

- core namespaces: pure command planners, read-model derivation, validation,
  and output envelope shaping
- shell namespaces: entrypoint, CLI parsing, JSON/EDN printing, and IO effect
  execution

The first concrete split in this spike lives under
`cluck.examples.ro.core.*`:
- `cluck.examples.ro.core.commands` for the top-level command registry that
  feeds help, routing, and completion
- `cluck.examples.ro.core.help` for help text, completion scripts, and static
  CLI metadata
- `cluck.examples.ro.core.docs` for built-in docs topics and markdown envelope
  shaping
- `cluck.examples.ro.core.json` for pure JSON shaping helpers
- `cluck.examples.ro.core.workspace` for workspace/init/status/identity
  planners and registry formatters
- `cluck.examples.ro.core.worklog` for the first inline-effect planner slice
  in the CLI contract
- `cluck.examples.ro.core.events` for event record parsing, ordering, and
  materialization helpers
- `cluck.examples.ro.core.doctor` for doctor issue parsing, summaries, and
  dedupe planning helpers
- `cluck.examples.ro.core.projects` for project-surface planning, inline-effect
  tuples, and project JSON envelopes
- `cluck.examples.ro.core.sync` for pure git-status parsing helpers
- `cluck.examples.ro.core.reindex` for the reindex recognized-event-type table
- `cluck.examples.ro.core.route` for the pure top-level CLI router

The current inline-effect planner slices are `cluck.examples.ro.core.worklog`
and `cluck.examples.ro.core.projects`.

`cluck.examples.ro.app` remains the shell entrypoint and command executor for
now.

## Effect contract

Planned command planners should return ordered effects instead of performing IO
directly.

A simple shape is enough:

```clojure
{:ok? true
 :effects [[:worklog/list {:item-id "item-1"
                           :limit 20
                           :offset 0}]
           [:worklog/help {}]]}
```

Rules:

- effects are ordered
- core planning must be deterministic
- shell code executes effects in order
- output shaping should happen in core where possible, not in the shell
- write the effect tuple inline in the planner body; do not hide it behind
  builder helpers or extra planner layers

## Test seams

The testing plan should cover three layers:

1. Unit tests for pure helpers and planners.
2. Integration tests that run the built standalone Cluck CLI
   (`build/ro-standalone`) and compare it to the Odin `ro` binary on `PATH`.
3. Fixture/golden tests for the stable contracts: help text, `docs`,
   shell completion scripts, and static JSON or EDN envelopes.
4. Live parity tests for shared-state commands like `events list`,
   `workspace current/list`, `status`, and `identity list/whoami`, using the
   compiled CLI artifact rather than the interpreter. Workspace init/add/use
   are covered by isolated-config contract tests because the Odin bootstrap
   path is flaky on this machine.

The first slices in the spike are the root help surface plus `docs`,
`completion`, `events`, `workspace`, `status`, `identity`, `doctor`,
`reindex`, `projects`, and `sync` status/remotes/reindex, with fixture-backed
parity against Odin in place for the stable paths and live parity for the
shared-state paths. `core.commands`, `docs`, `projects`, `sync`, and
`reindex` now each have a small pure core namespace for the parsing and table
logic that can be tested without touching git or the workspace database.
`workspace` now also has pure planner coverage for `init`, `add`, and `use`
before the shell touches the registry or workspace files, and the registry
listing path pretty-prints the full workspace registry envelope.

The integration tests are important because they let us check parity quickly
while the CLI is still being rebuilt command by command. Using the compiled
standalone binary for live parity keeps the test seam aligned with the actual
delivered artifact and avoids interpreter-only performance cliffs.

## Non-goals

- No web/server layer in this spike.
- No TUI work until the CLI surface is in good shape.
- No attempt to copy the Clojure Ro transport boundary.
