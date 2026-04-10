# Ro CLI Surface Inventory

This document tracks the command surface we are recreating in the
`examples/cluck/ro` spike.

Source references:
- Odin `ro` binary on `PATH`
- `ro-clj/docs/CLI_API_PARITY.md`
- `ro-clj/docs/FCIS.md`
- `ro-clj/docs/RO_FCIS_PATTERNS.md`

## Current contract

The existing Odin binary exposes a scriptable CLI with:
- plain-text help at the top level
- a shortcut for `ro <item-id>` -> `ro items show <item-id>`
- JSON/EDN-style output envelopes for most commands
- `_hints` for follow-up navigation
- global workspace and output flags

The Cluck spike is CLI-only. TUI work is intentionally out of scope until the
command surface is in shape.

For now, bare `ro` in Cluck prints the CLI help surface instead of opening the
Odin-style TUI entrypoint.

The first pure-helper split for the spike now lives in
`cluck.examples.ro.core.*`:
- `core.commands` owns the top-level command registry that feeds root help,
  routing, and completion
- `core.help` owns the help surface and completion scripts
- `core.docs` owns the built-in docs topics and docs topic envelope shaping
- `core.json` owns JSON envelope shaping
- `core.workspace` owns workspace/current/status/identity formatting

## Top-level commands

- `ro`
- `ro help`
- `ro <item-id>`
- `ro docs [topic]`
- `ro completion <bash|zsh|fish>`
- `ro init`
- `ro identity ...`
- `ro doctor [--fail]`
- `ro reindex`
- `ro events list [--limit N]`
- `ro agent start <item-id>`
- `ro status`
- `ro sync status`
- `ro sync remotes`
- `ro sync setup [--remote-url <url>] [--remote-name <name>] [--commit] [--push] [--message <msg>]`
- `ro sync pull`
- `ro sync reindex`
- `ro sync push [--message <msg>] [--pull=false]`
- `ro sync resolve`
- `ro workspace current`
- `ro workspace list`
- `ro workspace init <name> [--dir <path>] [--use]` bootstraps a workspace root and writes the registry if needed
- `ro workspace add <name> --dir <path> [--kind git] [--use]` registers an existing workspace
- `ro workspace use <name>`
- `ro projects create --name <name> [--use]`
- `ro projects list`
- `ro projects archive <project-id> [--unarchive]`
- `ro projects use <project-id>`
- `ro projects current`
- `ro outlines create --project <project-id> --name <name>`
- `ro outlines list [--project <project-id>]`
- `ro outlines show <outline-id>`
- `ro outlines archive <outline-id> [--unarchive]`
- `ro outlines status ...`
- `ro items create --title <title> [--parent <item-id> | --outline <outline-id> | --project <project-id>]`
- `ro items copy <item-id> [--project <project-id>] [--outline <outline-id>] [--parent <item-id>|none]`
- `ro items show <item-id>`
- `ro items list [--project <project-id>] [--outline <outline-id>] [--status <status>]`
- `ro items set-status <item-id> --status <status> [--note "..."]`
- `ro items set-assign <item-id> [--actor <actor-id> | --clear]`
- `ro items claim <item-id> [--take-assigned]`
- `ro items events <item-id> [--limit N]`
- `ro items archive <item-id>`
- `ro items ready`
- `ro tasks`
- `ro capture [--hotkey] [--no-output] [--exit-0-on-cancel]`
- `ro comments list <item-id> [--limit N] [--offset N]`
- `ro comments add <item-id> --body "..." [--reply-to <comment-id>] [--discuss]`
- `ro discuss list <item-id> [--state open|resolved|all] [--limit N] [--offset N]`
- `ro discuss show <discussion-id>`
- `ro discuss start <item-id> (--body "..." | --comment <comment-id>)`
- `ro discuss promote <item-id> --comment <comment-id>`
- `ro discuss resolve <discussion-id> [--body "..."]`
- `ro discuss reopen <discussion-id> [--body "..."]`
- `ro deps add <item-id> --blocks <item-id> | --related <item-id>`
- `ro deps list [<item-id>]`
- `ro deps tree <item-id>`
- `ro deps cycles`
- `ro attachments add <entity-id> <path> [--kind item|comment] [--title "..."] [--alt "..."] [--max-mb N] [--link|--copy]`
- `ro attachments list <entity-id>`
- `ro attachments open <attachment-id> [--print-path]`
- `ro attachments export <attachment-id> <dest-path>`
- `ro worklog list <item-id> [--limit N] [--offset N]`
- `ro worklog add <item-id> --body "..."`
- `ro clock status`
- `ro clock in <item-id>`
- `ro clock out [--body "..."]`
- `ro agenda`

## Global flags

The current Ro contract uses these global flags:
- `--dir`
- `--workspace`
- `--actor`
- `--addr`
- `--port`
- `--format`
- `--pretty`
- `--no-open`

The current top-level help text surfaces `--workspace` and `--pretty`.
The full command surface also uses the wider global set above.

## Output contract

Most commands should follow the Ro envelope style:
- `data` for the main payload
- `meta` for extra context when needed
- `_hints` for follow-up commands

The CLI spike will keep this in mind as each command family is rebuilt.

## Current implementation slice

Implemented now:
- bare `ro` help output for the CLI-first spike
- `help` and `--help` aliases
- the first test harness for help parity
- the top-level command registry is single-sourced in `core.commands`
- `ro docs` returns the JSON topics envelope
- `ro docs <topic>` returns a topic/markdown envelope
- `ro docs <topic> --raw` prints the markdown topic text directly
- `ro docs --help` and `ro docs -h` print the docs help text
- `ro completion` prints the completion help and exits with status 1
- `ro completion <bash|zsh|fish>` prints shell completion scripts
- `ro events` prints the events help surface
- `ro events list [--limit N]` returns the events envelope
- `ro init` bootstraps the default workspace in the current directory
- `ro doctor` returns the event-log report envelope
- `ro doctor summary [--fail]` and `ro doctor dedupe [--write --force] [--fail]` are wired
- `ro reindex` returns the reindex counts envelope
- `ro workspace` prints the workspace help surface
- `ro workspace init <name> [--dir <path>] [--use]` bootstraps a workspace root and writes the registry if needed
- `ro workspace add <name> --dir <path> [--kind git] [--use]` registers an existing workspace
- `ro workspace use <name>` switches the current workspace
- `ro workspace current` returns the current workspace envelope
- `ro workspace list` returns the pretty workspace registry envelope
- `ro status` returns the workspace status envelope and hints
- `ro sync status`, `ro sync remotes`, and `ro sync reindex` return live parity envelopes
- `ro identity` prints the usage surface
- `ro identity list` returns the current actor list envelope
- `ro identity whoami` returns the active actor envelope
- fixture-backed parity tests now cover help and docs help
- fixture-backed parity tests now cover completion and workspace help/scripts
- fixture-backed parity tests now cover events help
- fixture-backed parity tests now cover doctor and reindex help
- fixture-backed parity tests now cover sync help output
- live parity tests now cover events list, workspace current/list, status,
  identity, doctor, reindex, and sync status/remotes/reindex; workspace
  init/add/use are covered by isolated-config contract tests against the
  standalone Cluck binary

Next slices:
- implement the remaining read-only commands
- implement mutating domain commands
- add parity tests for each command family as it lands
