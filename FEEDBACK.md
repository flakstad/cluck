- 2026-04-09: Ro standalone bundles need explicit include order and alias
  bridges when the source `.clk` file uses slash-qualified names. `cluck.string`
  must be marked loaded before `cluck.fs`, `cluck.fs` before `cluck.io`, and the
  launcher needs `json/json-write` -> `json:json-write` plus `json/json-read`
  -> `json:json-read` aliases or the binary falls back to runtime loading and
  trips over `ns`.
- 2026-04-09: Bare `ro completion` should print the help text but still exit 1.
  The app helper should return the help output, while the launcher owns the
  special-case exit code so direct unit tests stay simple.
- 2026-04-09: `compact-json-step` must toggle string state on the opening quote,
  not only on the closing one, or JSON strings with spaces lose their
  whitespace. `workspace current` also showed that ordered JSON envelopes should
  use explicit vectors of pairs when key order matters instead of relying on
  hash-map iteration order.
- 2026-04-09: `ro status` counts all non-archived items, including cancelled
  ones. Its worklog total is not a raw row count; it only includes entries
  visible to the current actor's write identity, which means agent actors fold
  back to their human owner for visibility.
- 2026-04-09: `ro identity list` orders actors with the human first, then
  agents by kind/name/id. `ro identity whoami` should return the active actor
  envelope directly, while `ro identity` and `ro identity --help` print the
  usage surface without changing exit status.
- 2026-04-09: `proc/exec` merges stderr into `:out`, so tests that need stream
  separation have to use a different helper. `ro status` is volatile in the
  shared workspace, so it is better checked with direct live parity than a
  static golden snapshot.
