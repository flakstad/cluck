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
- `ro docs` returns the JSON topics envelope
- `ro docs --help` and `ro docs -h` print the docs help text
- `ro completion` prints the completion help and exits with status 1
- `ro completion <bash|zsh|fish>` prints shell completion scripts
- `ro workspace` prints the workspace help surface
- `ro workspace current` returns the current workspace envelope
- `ro workspace list` returns the workspace list envelope
- `ro status` returns the workspace status envelope and hints
- `ro identity` prints the usage surface
- `ro identity list` returns the current actor list envelope
- `ro identity whoami` returns the active actor envelope
- fixture-backed parity tests now cover help and docs
- fixture-backed parity tests now cover completion and workspace help/scripts
- live parity tests now cover workspace current/list, status, and identity

Next slices:
- parse the root command registry
- implement the remaining read-only commands
- implement mutating domain commands
- add parity tests for each command family as it lands
