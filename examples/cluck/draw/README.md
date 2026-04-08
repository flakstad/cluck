# Cluck Draw Scaffold

This is the starting point for the SDL3 drawing app.

What is in place:
- a Cluck-only `main.clk`
- a thin `cluck.sdl3` direct-interop layer
- a compiled runner entrypoint in `run.scm`
- the shared example bootstrap from `examples/cluck/bootstrap.scm`
- a first SDL3 window-open loop that clears the screen until quit
- a REPL-first development bootstrap in `dev.clk` that you load explicitly from the normal Cluck REPL before calling `(start-dev!)`
- live mouse, pen, and keyboard-event overlays in the window
- freehand brush strokes while dragging
- an on-demand debug panel toggled with `d`
- REPL state changes redraw the window immediately once the app is live

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
2. start a normal Cluck REPL, then evaluate `(load-file "examples/cluck/draw/dev.clk")` to load the SDL3 support code
3. once that is loaded, evaluate the draw buffer or the explicit startup forms in the comment block at the end of `main.clk`
4. call `(start-dev!)` when you want to open the window and experiment live
5. if the draw thread crashes, call `(restart-dev!)` to close and reopen the window without killing the REPL
6. drag with the mouse or pen to paint strokes, and press `d` to toggle the debug panel
7. add byte-buffer and texture work as needed

If you are editing the draw files in `cluck-mode`, `C-c C-z` jumps to the
ordinary Cluck REPL. It does not load SDL automatically. When you want to
bring up the window, first evaluate `(load-file "examples/cluck/draw/dev.clk")`
in the REPL. After that, you can evaluate the explicit startup forms in the
comment block at the end of `main.clk`, or run the buffer with `C-c C-k`.
Until the draw support code is loaded, evaluating the buffer directly will
stop at the SDL FFI boundary. If the draw thread crashes, `restart-dev!`
closes the old window, clears the recorded error, and starts a fresh one from
the current REPL state.

The launcher vendors a static SDL3 build under `build/vendor/`, so the
resulting binary is self-contained rather than linked to a Homebrew SDL3
dylib. On macOS it still links against the system frameworks that SDL uses,
which is the normal platform baseline rather than a separately managed runtime
dependency.
