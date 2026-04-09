# Cluck TUI Todos

This is a small ncurses + SQLite example app for Cluck.

It provides a split-pane terminal UI with:
- a scrollable note list
- a detail pane for the selected entry
- keyboard navigation with `j`/`k`, arrows, and `g`/`G`
- add, edit, delete, pin, complete, priority, search, and kind filtering
- on-disk persistence in `build/tui-todos.sqlite3`
- a small seed dataset on first launch

What is in place:
- `main.clk` with the TUI, prompts, and SQLite-backed note model
- `run.scm` for source-mode runs
- `run-standalone.scm` for a compiled launcher

The app uses these eggs:
- `ncurses`
- `sqlite3`

Install them once in your CHICKEN environment:

```bash
chicken-install ncurses sqlite3
```

Run it from the repository root:

```bash
csi -q -s examples/cluck/tui-todos/run.scm
```

Build a native binary from the same app:

```bash
csc -static -deployed -k -v -O2 -strip -o build/tui-todos-standalone examples/cluck/tui-todos/run-standalone.scm -L -lncurses -L -lsqlite3
```

The extra `-L` flags pass the native `ncurses` and `sqlite3` libraries through
to the linker for this egg-backed example.

Then run the compiled binary:

```bash
./build/tui-todos-standalone
./build/tui-todos-standalone build/my-tui-todos.sqlite3
```

The standalone binary behaves like source mode:
- with no args it opens `build/tui-todos.sqlite3`
- with one arg it uses that database path instead
- it creates `build/` in the current working directory on first launch when you use the default path

For a fast noninteractive regression check, run:

```bash
csi -q -s test/run-tui-todos.scm
```

Controls:
- `j` / `k` or up/down arrows move the selection
- `g` and `G` jump to the first and last entry
- `a` or `n` add a new note
- `e` edit the current note
- `space` toggle done/open
- `p` toggle pinned
- `/` search
- `c` cycle the kind filter
- `1` through `5` set the priority
- `d` or `x` delete the current note
- `r` reload from disk
- `q` quit

The database is created automatically the first time the app runs.
