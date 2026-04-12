# Cluck Repo Guidance

Cluck is a Clojure-flavored language layer for CHICKEN Scheme.
This repository contains the language runtime plus example apps and experiments.

Current active work:
- `examples/cluck/ro` is the Ro recreation spike.
- The spike is CLI-first and test-driven.
- Compare behavior against the Odin `ro` binary on `PATH`.
- Treat `examples/cluck/ro/docs/FCIS.md` as the local architectural contract
  for that spike, and mirror the `ro-clj` FC/IS pattern for mutations and
  planner output.
- This FC/IS/effect-vector guidance is specific to the Ro example app and
  should not be generalized to other example apps.
- Keep TUI work out of the path until the CLI surface is stable.
- `examples/cluck/draw` is a drawing app for thinking

Code style:
- Prefer Clojure-style source in `.clk` files: `ns`, `defn`, `let`, `cond`,
  data literals, threading macros, and small pure helpers.
- Prefer namespaced modules and data-first APIs.
- Keep app code easy to read as Clojure, not as Scheme with different syntax.
- Only drop to Scheme in `.scm` files or when CHICKEN interop/bootstrap makes
  it necessary.
- Do not reach for Scheme forms in `.clk` files when an ordinary Cluck form or
  small helper is enough.
- For Ro CLI planners, return inline effect vectors in the FC/IS style used by
  the Clojure Ro codebase. Write the `{:ok? true :effects [[:some/effect {}]]}`
  map literally in the planner body so the return shape is obvious at a glance.
  Do not hide planner effects behind constructor helpers, ad hoc planner tags,
  or shell-decided mutation branching when a command can be expressed as pure
  effects.
- When a `.clk` file still needs bootstrap interop, keep that Scheme confined
  to the narrow edge and document why it cannot be expressed as Cluck forms.

Semantics caveat:
- Cluck is currently experimenting with mutable-by-default collections.
- Treat that as provisional language behavior, not a final promise.
- There is a persistent map implementation available via `hash-map ,,`.
- Inline data structures like `{:a 1}` are mutable, and functions that operate
  on them, such as `assoc`, can mutate those values.
- Do not assume Clojure persistent-data semantics unless the code is explicitly
  using the persistent map implementation.

Testing and implementation:
- Build command surfaces in small slices with tests first.
- Favor pure unit tests for parsing and planning logic.
- Add integration tests for the real CLI when command behavior needs parity
  checks.
- Document architectural decisions in the relevant example project docs.

Feedback loop:
- `FEEDBACK.md` is for Cluck language/runtime notes only.
- If you discover a task-specific issue while working, file it as a Ro item
  first, ideally as a child item of the task you are currently on.
- Use `FEEDBACK.md` for short, searchable notes about missing Clojure forms or
  functions, Cluck bugs, mutation surprises, or reasons you had to drop to
  Scheme.
- Keep entries short and append-only so the file stays useful as language
  feedback, not as task tracking.
