# Cluck No-Eggs Template

This directory is a starter layout for a Cluck utility that does not depend on
any external CHICKEN eggs.

## What it is for

Use this template when you want:

- a small native CLI
- pure Cluck app logic
- Scheme only for bootstrap, file I/O, and the launcher
- no `http-client`, `json`, or other external eggs

The included example app is a text report tool that counts lines, nonblank
lines, blank lines, characters, and longest line length.

## Layout

```text
template/no-eggs/
  bootstrap.scm
  run.scm
  repl.scm
  src/
    app/
      main.clk
```

## How to use it

- Copy `template/no-eggs/` into a new project directory.
- Put the Cluck runtime somewhere discoverable:
  - set `CLUCK_HOME` to a Cluck checkout, or
  - copy the Cluck repo into `vendor/cluck/` under the new project.
- Run `csi -q -s run.scm` with a file path or pipe text on stdin.
- Start an interactive REPL with `csi -q -s repl.scm`.

The launcher reads text with Scheme code in the bootstrap, then hands the
actual application work to Cluck code in `src/app/main.clk`.

## Build

Native launchers are still just CHICKEN front-ends around the Cluck source:

```bash
csc -k -v -O2 -strip -o build/run run.scm
csc -k -v -O2 -strip -o build/repl repl.scm
```

Because the bootstrap walks upward from the launcher location, the compiled
binary can live under `build/` and still find the template root when you run it
inside the project tree.

## Notes

- Keep the app source in `.clk` files.
- Keep any host-specific file or stdin handling in `bootstrap.scm`.
- If you want a bundled single binary later, use the standalone packaging
  pattern from the weather example in the main repo.
