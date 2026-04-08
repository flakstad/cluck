# Cluck TUI Todos

This is a small ncurses + SQLite example app for Cluck.

It provides a split-pane terminal UI with:
- a scrollable note list
- a detail pane for the selected entry
- keyboard navigation with `j`/`k`, arrows, and `g`/`G`
- add, edit, delete, pin, complete, priority, search, and kind filtering
- on-disk persistence in `build/tui-todos.sqlite3`
- a small seed dataset on first launch

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
