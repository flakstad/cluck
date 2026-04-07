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
- REPL launch and switching commands
- inline eval overlays
- doc lookup with `C-c C-d`
- definition jumping with `M-.`
- namespace-aware completion for aliases like `str/`, invoked explicitly with `TAB`

The setup intentionally stays light and does not depend on CIDER or LSP for
Cluck buffers.
