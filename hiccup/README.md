# Hiccup

This directory contains a Cluck-native HTML rendering library.

Public entry points:

- `hiccup.core` for the full API

What is implemented now:

- element rendering from Hiccup vectors
- HTML escaping and raw strings
- HTML page helpers such as `html5`, `html4`, and `xhtml`
- common element helpers such as `link-to`, `mail-to`, `image`, and list helpers
- basic form helpers
- a simple `wrap-base-url` middleware helper

What is intentionally not implemented yet:

- the full macro-heavy JVM Hiccup compiler layer
- alias-resolution machinery beyond an identity placeholder
- browser-side or Datastar-specific behavior

The Datastar clock example uses this library for its HTML shell and SSE patch
markup.
