# Hiccup

This directory contains a Cluck-native, Hiccup 2-style HTML rendering
library.

Public entry points:

- `hiccup.core` for the full API

The public surface follows the Hiccup 2 names we use in Cluck:

- `html`, `raw`, `raw-string`, `raw-string?`, and `escape-html`
- `html4`, `xhtml`, `html5`, `include-js`, and `include-css`
- `with-group` and the standard form field helpers
- `url` and the base-URL / encoding helpers

What is implemented now:

- element rendering from Hiccup vectors
- HTML escaping and raw render values
- HTML page helpers such as `html5`, `html4`, and `xhtml`
- the standard form helpers from Hiccup 2
- URL and base-URL helpers

The raw render value returned by `hiccup.core/html` behaves like Hiccup 2:
call `str` when you need a plain string.

What is intentionally not implemented yet:

- Hiccup 1 compatibility helpers such as `link-to`, `mail-to`,
  `unordered-list`, `ordered-list`, `image`, `javascript-tag`, or
  `wrap-base-url`
- browser-side or Datastar-specific behavior

The Datastar clock example uses this library for its HTML shell and SSE patch
markup.
