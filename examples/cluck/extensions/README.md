# Cluck Project Report

This example shows two extension styles in one small app:

- `scheme-ext.scm` registers a hook that adds attention data and focus items to
  the report model.
- `cluck-ext.clk` overwrites the report renderer completely and changes the
  formatting.

The main app, `main.clk`, keeps a small Flakstad Software backlog in Cluck and
prints a useful project report from that data.

What is in place:
- `main.clk` with the report model and loader
- `scheme-ext.scm` as a data-transforming extension
- `cluck-ext.clk` as a full renderer override
- `run.scm` for source-mode runs
- `run-standalone.scm` for a compiled launcher

Run it from the repo root:

```bash
csi -q -s examples/cluck/extensions/run.scm
csi -q -s examples/cluck/extensions/run.scm examples/cluck/extensions/scheme-ext.scm
csi -q -s examples/cluck/extensions/run.scm examples/cluck/extensions/cluck-ext.clk
csi -q -s examples/cluck/extensions/run.scm examples/cluck/extensions/scheme-ext.scm examples/cluck/extensions/cluck-ext.clk
```

Expected source-mode output:

- No extensions:
  - a plain text report
  - summary, open items, and done items
- `scheme-ext.scm`:
  - the same plain text report
  - an `Attention:` line
  - a `Focus items:` line
- `cluck-ext.clk`:
  - the same report data
  - markdown-style bullet formatting
- Both files:
  - markdown-style bullet formatting
  - `Attention:` and `Focus items:` lines

Build a self-contained native binary:

```bash
csc -static -deployed -k -v -O2 -strip -o build/extensions-standalone examples/cluck/extensions/run-standalone.scm
```

Then run the compiled binary with the same four cases:

```bash
./build/extensions-standalone
./build/extensions-standalone examples/cluck/extensions/scheme-ext.scm
./build/extensions-standalone examples/cluck/extensions/cluck-ext.clk
./build/extensions-standalone examples/cluck/extensions/scheme-ext.scm examples/cluck/extensions/cluck-ext.clk
```

The standalone binary should match source mode:

- no args prints the plain text report
- `scheme-ext.scm` adds the attention and focus lines
- `cluck-ext.clk` switches the output to bullet formatting
- both files together keep the attention/focus data and the bullet formatting

For a full repo sanity check, also run:

```bash
csi -q -s test/run.scm
```
