# Cluck Draw Scaffold

This is the starting point for the SDL3 drawing app.

What is in place:
- a Cluck-only `main.clk`
- a thin example-scoped `cluck.examples.draw.sdl3` direct-interop layer
- extracted draw helper namespaces under `src/cluck/examples/draw/`, including state, history, view, panel, geometry, selection, edit, and input
- a compiled runner entrypoint in `run.scm`
- the shared example bootstrap from `examples/cluck/bootstrap.scm`
- a first SDL3 window-open loop that clears the screen until quit
- a REPL-first development bootstrap in `dev.clk` that you load explicitly from the normal Cluck REPL before calling `(start-dev!)`
- a supervised child-process dev loop by default, so the SDL window can be restarted independently of the REPL
- live mouse, pen, and keyboard-event overlays in the window
- freehand brush strokes while dragging, with a soft pressure-sensitive brush
- mixed canvas elements, so ink and objects can coexist on the same canvas
- a first structured object tool: `r` drag-to-create rectangles (`b` still works as a legacy alias)
- a first selection tool: `v` to select existing elements, `shift`+click to add to the selection, and drag them
- selection bounds for the active selection, plus rectangle corner resize handles and a top rotation handle for a single selected rectangle
- a first connector tool: `a` drag-to-create arrows
- a first text tool: `t` click to place text elements
- an on-demand debug panel toggled with `d`
- a toggleable in-window tool panel with clickable buttons and selection-aware action hints, toggled with `tab`
- mouse-wheel zoom centered on the cursor
- `space`+drag panning for the viewport
- tool-aware cursors: crosshair for draw tools and rectangle rotation, move for selection drag/pan, resize on rectangle corner handles, text cursor for the text tool, pointer over clickable tool-panel buttons
- tool shortcuts for `i` ink, `t` text, `r` rectangle, `u` undo, `c` clear, `e` eraser, and `1`/`2`/`3` brush sizes
- `save-canvas!` and `load-canvas!` helpers for round-tripping the current canvas
  state to `build/cluck-draw-state.edn` by default, plus `ctrl+s` / `ctrl+o` shortcuts
  - the default file format is EDN
- viewport shortcuts for the infinite canvas:
  - `ctrl` + `+` / `=` zoom in at the pointer
  - `ctrl` + `-` zoom out at the pointer
  - `h`, `j`, `k`, `l` pan left, down, up, and right
  - `0` reset the viewport
  - the current viewport bounds are intentionally very large, with deep zoom-out and deep zoom-in ranges for a stronger infinite-canvas feel
- focus loss cancels the active stroke instead of leaving the canvas in a half-drawn state
- REPL state changes redraw the window immediately once the app is live

What is not here yet:
- advanced selection like lasso and grouping
- real text editing, resizing, and typography controls
- input handling beyond quit events
- textures, byte buffers, or asset loading

Run it from the repo root with:

```bash
csi -q -s examples/cluck/draw/run.scm
./build/draw
```

The intent is to build this interactively in small steps:
1. keep the SDL3 boundary isolated in `cluck.examples.draw.sdl3`
2. start a normal Cluck REPL, then evaluate `(load-file "examples/cluck/draw/dev.clk")` to load the SDL3 support code
3. once that is loaded, evaluate the draw buffer or the explicit startup forms in the comment block at the end of `main.clk`
4. call `(start-dev!)` when you want to open the window and experiment live; this now starts a supervised child draw process by default
5. if the draw child crashes or stalls, call `(restart-dev!)` to restart it without killing the REPL
6. use the mouse wheel to zoom, hold `space` and drag to pan, use `ctrl` + `+` / `-` for keyboard zoom, drag with the mouse or pen to paint ink, press `t` to place text, press `r` to switch into drag-to-create rectangle mode (`b` still works as a legacy alias), press `a` for drag-to-create arrows, and press `v` to switch into selection mode for moving existing elements; press `d` to toggle the debug panel and `tab` to toggle the tool panel
7. use `restart-dev!` if the session gets wedged; it now resets the draw state as part of recovery
8. add byte-buffer and texture work as needed
9. when you are working on keyboard toggles or other input routing, run `csi -q -s test/run-draw-toggle.scm` for a fast focused probe
10. when you are working on draw tools and state mutations, run `csi -q -s test/run-draw-tools.scm` for a fast focused probe
11. when you are working on save/load round-trips, run `SDL_VIDEODRIVER=dummy csi -q -s test/run-draw-save-load.scm` for a fast focused probe
12. when you are working on viewport transforms or world-space drawing, run `SDL_VIDEODRIVER=dummy csi -q -s test/run-draw-view.scm` for a fast focused probe
13. when you are working on pen pressure, focus handling, or other input-state routing, run `SDL_VIDEODRIVER=dummy csi -q -s test/run-draw-input.scm` for a fast focused probe
14. when you are working on the canvas cache or render-target path, run `SDL_VIDEODRIVER=dummy csi -q -s test/run-draw-cache.scm` for a fast focused probe
15. when you are working on the running lifecycle, restart, or hang recovery path, run `SDL_VIDEODRIVER=dummy csi -q -s test/run-draw-lifecycle.scm` for a fast focused probe
16. when you are working on the child-process supervision path itself, run `SDL_VIDEODRIVER=dummy csi -q -s test/run-draw-supervisor.scm`
17. when you are working on input replay or performance inspection, run `SDL_VIDEODRIVER=dummy csi -q -s test/run-draw-replay.scm` for a fast focused probe; pass a round count like `SDL_VIDEODRIVER=dummy csi -q -s test/run-draw-replay.scm 1000` when you want a longer sustained stress run
18. when you want to exercise the real live window with scripted input, run `SDL_VIDEODRIVER=dummy csi -q -s test/run-draw-live-replay.scm` or omit the dummy video driver for an actual windowed session; this goes through `draw-replay-live!`
19. when you want to exercise the brush-change and undo path specifically, run `csi -q -s test/run-draw-brush-undo.scm` for a fast focused probe or `SDL_VIDEODRIVER=dummy csi -q -s test/run-draw-live-brush-undo.scm` for the live-window replay

If you are editing the draw files in `cluck-mode`, `C-c C-z` jumps to the
ordinary Cluck REPL. It does not load SDL automatically. When you want to
bring up the window, first evaluate `(load-file "examples/cluck/draw/dev.clk")`
in the REPL. After that, you can evaluate the explicit startup forms in the
comment block at the end of `main.clk`, or run the buffer with `C-c C-k`.
By default, `(start-dev!)` launches a supervised child draw process. If you
need the older same-process loop for a focused repro or test, call
`(draw-disable-supervision!)` before `(start-dev!)`.
Until the draw support code is loaded, evaluating the buffer directly will
stop at the SDL FFI boundary. If the draw thread crashes, `restart-dev!`
closes the old window, resets the draw state, clears the recorded error, and
starts a fresh one from the current REPL state.

While the window is live:
- press `d` to toggle the debug panel
- press `tab` to toggle the in-window tool panel
- press `i` for the ink tool
- press `t` for the text tool, then click to place a text element
- press `v` for the selection tool, then click or drag selected elements to move them
- drag empty space in selection mode to marquee-select elements
- hold `shift` while clicking in selection mode to add another element to the active selection
- hold `shift` while marquee-selecting to add the marquee hits to the current selection
- drag a rectangle corner handle in selection mode to resize a selected rectangle
- drag the top handle in selection mode to rotate a selected rectangle
- drag an arrow endpoint handle in selection mode to reshape a selected arrow
- use the tool panel buttons to switch tools, and watch the panel summary for the current selection
- press `r` for the rectangle tool, then drag to create a rectangle object (`b` still works as a legacy alias)
- press `a` for the arrow tool, then drag to create a connector
- press `u` to undo the last action, including clear or brush changes
- press `c` to clear the canvas, which is undoable
- press `e` to toggle eraser mode
- press `1`, `2`, or `3` to switch brush sizes
- use the mouse wheel to zoom around the cursor
- use `ctrl` + `+` / `-` to zoom around the cursor
- the viewport now supports a much larger bounded world and deeper zoom range, while keeping pointer-anchored zoom stable in the focused view tests
- press `ctrl+s` to save and `ctrl+o` to load from the default save path
- the tool panel now shows the default save filename and the EDN format directly in the window
- hold `space` and drag to pan the viewport
- zoomed drawing keeps brush width visually stable on screen, so zooming in lets you place finer world-space detail
- cursor shape now reflects the current interaction mode, including selection move/resize and tool-panel button hover
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
- use `(draw-supervisor-status)` to inspect the current child/supervisor status
- if you are chasing brush-change or undo issues, use `draw-replay-live!` with `draw-brush-undo-script` or the dedicated `test/run-draw-brush-undo.scm` / `test/run-draw-live-brush-undo.scm` runners

The launcher vendors a static SDL3 build under `build/vendor/`, so the
resulting binary is self-contained rather than linked to a Homebrew SDL3
dylib. On macOS it still links against the system frameworks that SDL uses,
which is the normal platform baseline rather than a separately managed runtime
dependency.
