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
- freehand brush strokes while dragging, with a soft pressure-sensitive brush
- an on-demand debug panel toggled with `d`
- mouse-wheel zoom centered on the cursor
- `shift`+drag panning for the viewport
- tool shortcuts for `u` undo, `c` clear, `e` eraser, and `1`/`2`/`3` brush sizes
- `save-canvas!` and `load-canvas!` helpers for round-tripping the current canvas
  state to `build/cluck-draw-state.edn` by default
- viewport shortcuts for the infinite canvas:
  - `]`, `+`, `=` zoom in
  - `[`, `-` zoom out
  - `h`, `j`, `k`, `l` pan left, down, up, and right
  - `0` reset the viewport
- focus loss cancels the active stroke instead of leaving the canvas in a half-drawn state
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
6. use the mouse wheel to zoom, hold `shift` and drag to pan, and drag with the mouse or pen to paint strokes; press `d` to toggle the debug panel
7. use `restart-dev!` if the session gets wedged; it now resets the draw state as part of recovery
8. add byte-buffer and texture work as needed
9. when you are working on keyboard toggles or other input routing, run `csi -q -s test/run-draw-toggle.scm` for a fast focused probe
10. when you are working on draw tools and state mutations, run `csi -q -s test/run-draw-tools.scm` for a fast focused probe
11. when you are working on save/load round-trips, run `SDL_VIDEODRIVER=dummy csi -q -s test/run-draw-save-load.scm` for a fast focused probe
12. when you are working on viewport transforms or world-space drawing, run `SDL_VIDEODRIVER=dummy csi -q -s test/run-draw-view.scm` for a fast focused probe
13. when you are working on pen pressure, focus handling, or other input-state routing, run `SDL_VIDEODRIVER=dummy csi -q -s test/run-draw-input.scm` for a fast focused probe
14. when you are working on the canvas cache or render-target path, run `SDL_VIDEODRIVER=dummy csi -q -s test/run-draw-cache.scm` for a fast focused probe
15. when you are working on the running lifecycle, restart, or hang recovery path, run `SDL_VIDEODRIVER=dummy csi -q -s test/run-draw-lifecycle.scm` for a fast focused probe
16. when you are working on input replay or performance inspection, run `SDL_VIDEODRIVER=dummy csi -q -s test/run-draw-replay.scm` for a fast focused probe; pass a round count like `SDL_VIDEODRIVER=dummy csi -q -s test/run-draw-replay.scm 1000` when you want a longer sustained stress run
17. when you want to exercise the real live window with scripted input, run `SDL_VIDEODRIVER=dummy csi -q -s test/run-draw-live-replay.scm` or omit the dummy video driver for an actual windowed session; this goes through `draw-replay-live!`
18. when you want to exercise the brush-change and undo path specifically, run `csi -q -s test/run-draw-brush-undo.scm` for a fast focused probe or `SDL_VIDEODRIVER=dummy csi -q -s test/run-draw-live-brush-undo.scm` for the live-window replay

If you are editing the draw files in `cluck-mode`, `C-c C-z` jumps to the
ordinary Cluck REPL. It does not load SDL automatically. When you want to
bring up the window, first evaluate `(load-file "examples/cluck/draw/dev.clk")`
in the REPL. After that, you can evaluate the explicit startup forms in the
comment block at the end of `main.clk`, or run the buffer with `C-c C-k`.
Until the draw support code is loaded, evaluating the buffer directly will
stop at the SDL FFI boundary. If the draw thread crashes, `restart-dev!`
closes the old window, resets the draw state, clears the recorded error, and
starts a fresh one from the current REPL state.

While the window is live:
- press `d` to toggle the debug panel
- press `u` to undo the last action, including clear or brush changes
- press `c` to clear the canvas, which is undoable
- press `e` to toggle eraser mode
- press `1`, `2`, or `3` to switch brush sizes
- use the mouse wheel to zoom around the cursor
- hold `shift` and drag to pan the viewport
- call `(save-canvas!)` and `(load-canvas!)` from the REPL to round-trip the canvas state
- draw session logging now writes to `build/cluck-draw.log`
- crashes now write a snapshot to `build/cluck-draw-crash.edn`
- the draw loop now writes heartbeats to `build/cluck-draw-heartbeat.edn`
- if the loop stalls, the external watchdog writes `build/cluck-draw-stall.edn` and, on macOS, a `build/cluck-draw-stall.sample` process sample
- pen pressure now scales the brush while drawing on tablets that expose it
- if the window loses focus, the active stroke is canceled so recovery is cleaner
- the debug panel lists the current bindings and REPL helpers in-window
- from the REPL, use `draw-simulate-input!`, `draw-replay-events!`, `draw-replay-live!`, `draw-replay-benchmark!`, or `draw-replay-live-benchmark!` to drive and time synthetic mouse, wheel, keyboard, and pen input
- use `(draw-log-tail 20)` to inspect the last log entries, `(draw-clear-log!)` to reset the trace, and `(dump-current-state!)` to write the current full state to disk while the app is still running
- use `(draw-watchdog-status)` to inspect the watchdog configuration; `draw-enable-watchdog!` and `draw-disable-watchdog!` control the external stall watcher
- if you are chasing brush-change or undo issues, use `draw-replay-live!` with `draw-brush-undo-script` or the dedicated `test/run-draw-brush-undo.scm` / `test/run-draw-live-brush-undo.scm` runners

The launcher vendors a static SDL3 build under `build/vendor/`, so the
resulting binary is self-contained rather than linked to a Homebrew SDL3
dylib. On macOS it still links against the system frameworks that SDL uses,
which is the normal platform baseline rather than a separately managed runtime
dependency.
