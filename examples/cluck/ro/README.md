# Cluck Ro Spike

This is the CLI-only Ro recreation spike for Cluck.

The first built slice is the root help surface and command inventory. The
example starts from the copied `tui-todos` scaffold, but the TUI pieces have
been stripped out of the path.

What is in place:
- `main.clk` as the thin entrypoint
- `src/app.clk` as the shell entrypoint and command dispatcher
- `core/*.clk` as the pure helper split for the command registry, help,
  routing, event parsing, JSON shaping, and workspace formatting
- `core/worklog.clk` as the first explicit inline-effect planner slice in the
  Ro FC/IS contract
- `core/projects.clk` as the second explicit inline-effect planner slice in the
  Ro FC/IS contract
- `run.scm` for source-mode runs
- `run-standalone.scm` for a compiled launcher
- `docs/FCIS.md` for the intended functional-core / imperative-shell split
- `docs/CLI_SURFACE.md` for the current command inventory and parity notes
- a pure core unit harness in `test/run-ro-core.scm`
- an integration parity harness in `test/run-ro-cli.scm`

Current implementation slice:
- `ro` prints the top-level help for this CLI-first spike
- `ro help` and `ro --help` print the same top-level help text
- `core.commands` owns the top-level command registry that feeds root help,
  routing, and completion
- `core/route.clk` owns the pure top-level route plan
- `core/docs.clk` owns the built-in docs topics and topic envelope shaping
- `core/events.clk` owns event-record parsing, ordering, and materialization
- `core/doctor.clk` owns doctor issue parsing, summaries, and dedupe planning
- `core/projects.clk` owns project-surface planning with inline effect tuples
  and project envelopes
- `core/worklog.clk` owns the first planner output that returns inline effect
  tuples directly
- `core/workspace.clk` owns workspace/init/status/identity planning and envelopes
- `core/sync.clk` owns pure git-status parsing helpers for sync
- `core/reindex.clk` owns the reindex recognized-event-type table
- `ro docs` returns the JSON topics envelope
- `ro docs <topic>` returns a topic/markdown JSON envelope
- `ro docs <topic> --raw` prints the raw markdown topic text
- `ro docs --help` and `ro docs -h` print the docs help text
- `ro completion` prints the completion help and exits with code 1
- `ro completion <bash|zsh|fish>` prints shell completion scripts
- `ro events` prints the events help surface
- `ro events list [--limit N]` returns the events envelope from the workspace
- `ro init` bootstraps the default workspace in the current directory
- `ro doctor` returns the event-log report envelope
- `ro doctor summary [--fail]` and `ro doctor dedupe [--write --force] [--fail]` are wired
- `ro reindex` returns the reindex counts envelope
- `ro sync status`, `ro sync remotes`, and `ro sync reindex` are live-parity slices
- `ro workspace` prints the workspace help surface
- `ro workspace init <name> [--dir <path>] [--use]` bootstraps a workspace root and writes the registry if needed
- `ro workspace add <name> --dir <path> [--kind git] [--use]` registers an existing workspace
- `ro workspace use <name>` switches the current workspace
- `ro workspace current` returns the current workspace envelope
- `ro workspace list` returns the pretty workspace registry envelope
- `ro status` returns the workspace status envelope and `_hints`
- `ro identity` prints the identity usage surface
- `ro identity list` returns the current actor list envelope
- `ro identity whoami` returns the active actor envelope
- `ro projects` routes through the inline-effect planner shape in
  `core.projects`
- `ro worklog` routes through the new inline-effect planner shape in
  `core.worklog`
- the top-level help/completion/router surface is driven from `core.commands`
- the help text mirrors the Odin `ro` binary on `PATH`
- unknown commands still fail explicitly; the rest of the surface will be built
  incrementally

The CLI slice itself currently uses the Cluck runtime plus `cluck.string`,
`cluck.fs`, and the JSON egg, but the standalone launcher keeps `json`,
`sqlite3`, and `ncurses` wired in so the next slices can start using them
without another bootstrap rewrite.

Run it from the repository root:

```bash
csi -q -s examples/cluck/ro/run.scm
csi -q -s examples/cluck/ro/run.scm help
```

Build a native binary from the same app:

```bash
csc -static -deployed -k -v -O2 -strip -o build/ro-standalone examples/cluck/ro/run-standalone.scm -L -lncurses -L -lsqlite3
```

Then run the compiled binary:

```bash
./build/ro-standalone
./build/ro-standalone help
```

Run the CLI parity test:

```bash
csi -q -s test/run-ro-core.scm
csi -q -s test/run-ro-cli.scm
```

## Architecture

The intended architecture for the Ro spike is FC/IS:
- the core should decide what command behavior means and what effects it emits
- the shell should handle argv parsing, environment, filesystem, database, and
  process IO
- the shell should execute effects in order and format stdout/stderr
- the example should stay CLI-only; there is no server/client split planned

See [`docs/FCIS.md`](./docs/FCIS.md) for the detailed contract.

## Testing

The testing plan is intentionally layered:
- unit tests for pure parsing and planning logic
- integration tests that run the compiled Cluck CLI and compare it to the Odin
  `ro` binary on `PATH`
- snapshot-style fixtures under `test/fixtures/ro/` for stable help text,
  shell completion scripts, and static JSON/EDN envelopes
- live parity checks for shared-state commands like `ro status`, `ro identity
  list`, `ro identity whoami`, workspace current/list, `ro doctor`, `ro reindex`,
  and `ro sync status/remotes/reindex`

The current test harness is split in two:
- `test/run-ro-core.scm` covers the pure `cluck.examples.ro.core.*` helpers
- `test/run-ro-cli.scm` covers CLI integration and live parity against Odin
  using the compiled `build/ro-standalone` artifact
- set `RO_CLI_SKIP_LIVE=1` when running `test/run-ro-cli.scm` to skip the
  slow live parity block during tight edit/test loops

The integration harness checks `docs` and `completion` with static fixtures,
checks `events` help with a fixture, and runs live parity checks for `events
list`, `workspace current/list`, `status`, `identity`, `projects`, `doctor`,
`reindex`, and `sync` because those depend on shared workspace or git state.
`workspace init/add/use` are covered by isolated-config contract tests against
the standalone Cluck binary because the Odin bootstrap path is flaky on this
machine. Pure parser helpers for `core.commands`, `projects`, `workspace`,
`sync`, and `reindex` have their own core namespace coverage in
`test/run-ro-core.scm`.

See [`docs/CLI_SURFACE.md`](./docs/CLI_SURFACE.md) for the current inventory.
