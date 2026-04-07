# Cluck Project Template

This directory is a copyable starter layout for a new Cluck application.

## Layout

```text
template/
  bootstrap.scm
  run.scm
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

This template is source/bootstrap first. If you want a self-contained native
binary, use the standalone packaging pattern from the weather example as a
later step.

## How bootstrapping works

- `bootstrap.scm` locates the project root from the executable location.
- It finds the Cluck runtime from `CLUCK_HOME`, `vendor/cluck/`, `cluck/`, or the project root.
- It loads `cluck.scm`.
- It keeps the runtime root on Cluck's module search path while loading the app, so `cluck.*` namespaces resolve correctly even when Cluck is vendored.

## Notes

- The template intentionally keeps app logic in `.clk` files.
- Use `ns` and `:require` with prefixed imports for any CHICKEN eggs you pull in.
- If you want a smaller self-contained binary later, reduce the dependency set first; flags only shave a little.
