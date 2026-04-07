# Cluck Draw Scaffold

This is the starting point for the SDL3 drawing app.

What is in place:
- a Cluck-only `main.clk`
- a source runner in `run.scm`
- the shared example bootstrap from `examples/cluck/bootstrap.scm`

What is not here yet:
- SDL3 bindings
- a window
- the event loop
- rendering

Run it from the repo root with:

```bash
csi -q -s examples/cluck/draw/run.scm
```

The intent is to build this interactively in small steps:
1. add the SDL3 bootstrap boundary
2. open a window and clear it
3. handle input and draw
4. add byte-buffer and texture work as needed
