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
- 2026-04-10: Example namespace extraction can still trip over same-named
  helpers across `.clk` files. A local helper like `draw-with-preview!` in one
  namespace resolved to the entrypoint wrapper with the same name at runtime,
  so example-scoped modules should currently prefer distinctive helper names
  rather than relying on namespace-local resolution for duplicated symbols.
- 2026-04-10: `cluck.examples.<example>.*` namespaces now need to resolve under
  `examples/cluck/<example>/src/` as well as the older flat example paths, or
  extracted example modules fall back to pretending they belong under core
  `src/`.
