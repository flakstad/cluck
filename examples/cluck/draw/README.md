# Cluck Draw Scaffold

This is the starting point for the SDL3 drawing app.

What is in place:
- a Cluck-only `main.clk`
- a thin `cluck.sdl3` direct-interop layer
- a compiled runner entrypoint in `run.scm`
- the shared example bootstrap from `examples/cluck/bootstrap.scm`
- a first SDL3 window-open loop that clears the screen until quit
- a REPL-first development bootstrap in `dev.clk` that loads SDL3 after the normal Cluck REPL starts and waits for an explicit `(start-dev!)` call
- live mouse position and keyboard-event overlays in the window

What is not here yet:
- advanced drawing tools
- input handling beyond quit events
- textures, byte buffers, or asset loading

Run it from the repo root with:

```bash
csi -q -s examples/cluck/draw/run.scm
./build/draw
```

The intent is to build this interactively in small steps:
1. keep the SDL3 boundary isolated in `cluck.sdl3`
2. start a normal Cluck REPL, then load `examples/cluck/draw/dev.clk` to load the draw definitions, then call `(start-dev!)` when you want to open the window and experiment live
3. extend the window loop with input and drawing commands
4. add byte-buffer and texture work as needed

If you are editing the draw files in `cluck-mode`, `C-c C-z` jumps to the Cluck
REPL and loads `examples/cluck/draw/dev.clk` into it. Call `(start-dev!)` in
that REPL when you want the window to open.

The launcher vendors a static SDL3 build under `build/vendor/`, so the
resulting binary is self-contained rather than linked to a Homebrew SDL3
dylib. On macOS it still links against the system frameworks that SDL uses,
which is the normal platform baseline rather than a separately managed runtime
dependency.
