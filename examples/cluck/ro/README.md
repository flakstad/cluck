# Cluck Ro Spike

This is the CLI-only Ro recreation spike for Cluck.

The first built slice is the root help surface and command inventory. The
example starts from the copied `tui-todos` scaffold, but the TUI pieces have
been stripped out of the path.

What is in place:
- `main.clk` as the thin entrypoint
- `src/app.clk` as the initial CLI surface registry and help printer
- `run.scm` for source-mode runs
- `run-standalone.scm` for a compiled launcher
- `docs/FCIS.md` for the intended functional-core / imperative-shell split
- `docs/CLI_SURFACE.md` for the current command inventory and parity notes
- a test-first help/parity harness in `test/run-ro-cli.scm`

Current implementation slice:
- `ro` prints the top-level help for this CLI-first spike
- `ro help` and `ro --help` print the same top-level help text
- `ro docs` returns the JSON topics envelope
- `ro docs --help` and `ro docs -h` print the docs help text
- `ro completion` prints the completion help and exits with code 1
- `ro completion <bash|zsh|fish>` prints shell completion scripts
- `ro workspace` prints the workspace help surface
- `ro workspace current` returns the current workspace envelope
- `ro workspace list` returns the workspace list envelope
- `ro status` returns the workspace status envelope and `_hints`
- `ro identity` prints the identity usage surface
- `ro identity list` returns the current actor list envelope
- `ro identity whoami` returns the active actor envelope
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
- integration tests that run the Cluck CLI under development and compare it to
  the Odin `ro` binary on `PATH`
- snapshot-style fixtures under `test/fixtures/ro/` for stable help text,
  shell completion scripts, and static JSON/EDN envelopes
- live parity checks for shared-state commands like `ro status`, `ro identity
  list`, `ro identity whoami`, and workspace current/list

The current test harness covers the root help path first, then will expand to
the rest of the command surface one slice at a time. It already checks `docs`
and `completion` with static fixtures, and runs live parity checks for
`workspace`, `status`, and `identity` because those depend on shared workspace
state.

See [`docs/CLI_SURFACE.md`](./docs/CLI_SURFACE.md) for the current inventory.
