# Cluck Draw Scaffold

This is the starting point for the SDL3 drawing app.

What is in place:
- a Cluck-only `main.clk`
- a thin `cluck.sdl3` direct-interop layer
- a compiled runner entrypoint in `run.scm`
- the shared example bootstrap from `examples/cluck/bootstrap.scm`
- a first SDL3 window-open loop that clears the screen until quit
- a `--repl` development mode that starts the window and then drops into the Cluck REPL

What is not here yet:
- advanced drawing tools
- input handling beyond quit events
- textures, byte buffers, or asset loading

Run it from the repo root with:

```bash
csc -v -O2 -strip -I/opt/homebrew/include -L/opt/homebrew/lib -rpath /opt/homebrew/lib -L -lSDL3 -o build/draw examples/cluck/draw/run.scm
./build/draw
```

The intent is to build this interactively in small steps:
1. keep the SDL3 boundary isolated in `cluck.sdl3`
2. use `./build/draw --repl` to open the window and experiment live from the Cluck REPL
3. extend the window loop with input and drawing commands
4. add byte-buffer and texture work as needed
