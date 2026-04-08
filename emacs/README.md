# Cluck Emacs Support

This directory contains the Emacs Lisp setup that powers `cluck-mode` and the
Cluck REPL helpers.

## Install

Add this directory to your `load-path` and require the two setup files:

```elisp
(add-to-list 'load-path "/path/to/cluck/emacs")
(require 'setup-cluck-mode)
(require 'setup-cluck-repl)
```

If you prefer copy/install over a direct path, copy the two `setup-cluck*.el`
files into a directory already on your `load-path`.

## What it gives you

- `cluck-mode` for editing `*.clk` files
- REPL launch and switching commands with `C-c C-z` opening the ordinary
  Cluck REPL buffer. For the draw example, the first eval in a draw buffer
  loads `examples/cluck/draw/dev.clk` automatically, so `C-c C-k` works
  against the live draw session after you explicitly call `(start-dev!)` in
  the REPL. The REPL itself still starts with no window and does not load SDL
  automatically.
- inline eval overlays
- doc lookup with `C-c C-d`
- definition jumping with `M-.`
- namespace-aware completion for prefixes like `str/`, `uri/`, `cluck.string/`, or `cluck.core/`, invoked explicitly with `TAB`
- source launcher discovery looks for `src/cluck-cli.scm` and `src/cluck.scm`

The setup intentionally stays light and does not depend on CIDER or LSP for
Cluck buffers.
