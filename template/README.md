# Cluck Project Template

This directory is a copyable starter layout for a new Cluck application.

## Layout

```text
template/
  bootstrap.scm
  run.scm
  repl.scm
  src/
    app/
      main.clk
```

## What to do with it

- Copy `template/` into a new project directory.
- Put the Cluck runtime somewhere discoverable:
  - set `CLUCK_HOME` to a Cluck checkout, or
  - copy the Cluck repo into `vendor/cluck/` under the new project.
- Edit `src/app/main.clk`.
- Run the app with `csi -q -s run.scm`.
- Start an interactive REPL with `csi -q -s repl.scm`.

This template is source/bootstrap first. If you want a self-contained native
binary, use the standalone packaging pattern from the weather example as a
later step.

Binary policy: in Cluck docs, "native binary" means self-contained. A launcher
that source-loads the app is only a development artifact.

## How bootstrapping works

- `bootstrap.scm` walks upward from the executable location until it finds `src/app/main.clk`.
- It finds the Cluck runtime from `CLUCK_HOME`, `vendor/cluck/`, `cluck/`, or the project root.
- It loads `src/cluck.scm`.
- It keeps the runtime root on Cluck's module search path while loading the app, so `cluck.*` namespaces resolve correctly even when Cluck is vendored.

## REPL setup

The starter REPL entrypoint is [`repl.scm`](./repl.scm).

Run it with:

```bash
csi -q -s repl.scm
```

This loads the Cluck runtime from `CLUCK_HOME`, `vendor/cluck/`, or `cluck/`,
loads `src/app/main.clk`, and then drops into a Cluck REPL with the app
namespace already available.

If you want a native REPL launcher, compile the same file:

```bash
csc -k -v -O2 -strip -o build/repl repl.scm
```

For an interactive editor workflow, use the `cluck-mode` package from the main
Cluck repo, specifically `settings/setup-cluck-mode.el` and
`settings/setup-cluck-repl.el`, or copy that setup into your Emacs config. It
gives you the same Cluck-specific eval and doc commands described in the main
README.

## Building binaries

The template supports two useful source-backed development launchers:

```bash
csc -k -v -O2 -strip -o build/app run.scm
csc -k -v -O2 -strip -o build/repl repl.scm
```

These are native CHICKEN launchers, but they still load the Cluck source files
at startup. They are convenient development front-ends, not fully embedded
single-binary images. They still expect the Cluck runtime to be discoverable at
runtime, and because the bootstrap walks upward to find the project root, you
can keep the compiled launcher under `build/` and still run it from inside the
project tree.

For a self-contained single binary, use the standalone packaging pattern from
the weather example in the main Cluck repo. That path is a separate build
story from the template starter.

For a no-eggs example app, see [`examples/cluck/text-report/main.clk`](../examples/cluck/text-report/main.clk)
in the main repository. It shows how to keep application logic in Cluck while
leaving file/stdin handling in the bootstrap.

## Notes

- The template intentionally keeps app logic in `.clk` files.
- Use `ns` and `:require` with prefixed imports for any CHICKEN eggs you pull in.
- If you want a smaller self-contained binary later, reduce the dependency set first; flags only shave a little.
