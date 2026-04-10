## Language Layer Notes

- 2026-04-09: Ro standalone bundles need explicit include order and alias
  bridges when the source `.clk` file uses slash-qualified names. `cluck.string`
  must be marked loaded before `cluck.fs`, `cluck.fs` before `cluck.io`, and the
  launcher needs `json/json-write` -> `json:json-write` plus `json/json-read`
  -> `json:json-read` aliases or the binary falls back to runtime loading and
  trips over `ns`.
- 2026-04-09: `compact-json-step` must toggle string state on the opening quote,
  not only on the closing one, or JSON strings with spaces lose their
  whitespace. Ordered JSON envelopes should use explicit vectors of pairs when
  key order matters instead of relying on hash-map iteration order.
- 2026-04-09: `proc/exec` merges stderr into `:out`, so tests that need stream
  separation have to use a different helper.
- 2026-04-09: `json-find-entry` needs to normalize vectors explicitly; `seq`
  alone was not enough in this runtime when looking up keys on vector-backed
  rows.
- 2026-04-09: Standalone Chicken bundles can be picky about namespaces imported
  from other namespaces in the same compiled unit. Keeping `core.route`
  self-contained avoided an import failure when bundling the CLI.
- 2026-04-10: The same standalone import restriction also applies to
  `core.projects`; it must stay self-contained in the bundled build instead of
  importing `core.help` directly.
- 2026-04-09: `second` and `third` are not available as reusable list helpers in
  this Cluck runtime shape. When porting list walkers from Clojure, spell out
  the `first`/`rest` chain directly or define explicit helper aliases in core.
- 2026-04-10: The JSON egg writes JSON null when a value is `void`/unspecified.
  The symbol `null` serializes as the string `"null"`, so null-shaped outputs
  need the runtime sentinel rather than a literal symbol.
2026-04-10: Cluck `fn` requires vector arglists like `[x]`; `(fn (x) ...)`
expands with `fn expects an argument vector or arity clauses`. This is easy to
trip over when replacing Scheme `lambda` forms with Cluck-style callbacks.
