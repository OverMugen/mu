# Standard Library Guidelines

These rules help keep the mu standard library focused, small, and easy to navigate.

## Function names

- Keep helpers short and descriptive.
- Use `snake_case` for every exported function instead of camelCase.
- Drop redundant type manglings (e.g., prefer `abs()` or `insertion_sort()` over `absInt()`/`insertionSortInts()` when mu only has integers).
- Imported modules expose helper functions via their namespace (e.g., `strings.split`, `math.max`); only the small prelude-provided helpers (`println`, `panic`, `test`) exist as globals.

## Module boundaries

- `lib/strings.mu` implements the primitive string/list helpers (whitespace tables, slicing, joins, splits, trimming, etc.).
- `lib/text.mu` builds on `strings` and exposes the AoC-style parsing helpers (`trim_spaces`, `parse_int_from`, `split_lines`, …) without reimplementing the primitives.
- `lib/decimal.mu` focuses on fixed-point formatting helpers and reuses the same naming conventions and shared helpers (`to_string`, `build_fraction_digits`, …).
- `lib/fp.mu` gathers functional utilities (`range`, `reduce`, `scan`, `zip`, `chunk`, `partition`, `find`, `uniq`, `group_by`, etc.) so higher-order pipelines stay in one place and other modules can import them if needed.
- Avoid copying similar logic between modules; if two helpers share the same job, consolidate them into the more general module and have the other module reuse them.

Following these guidelines keeps the stdlib consistent, makes the helper names easier to remember, and makes it easier to grow the lib/ tree in future mu programs.

## Module maintenance checklist

- Define each module's public surface and keep it narrow; helpers that do not belong to the domain move into shared modules (for example `math`, `text`, `encoding`, or `strings`).
- Split helpers so module-specific files only keep the low-level primitives that module needs (buffers, syscall wrappers, calendar math, etc.).
- Avoid wrappers that simply mirror shared helpers unless you are intentionally marking a dependency boundary; if you do re-export, do it once with a clear docstring.
- Import only the modules required per function and call shared helpers directly rather than routing through extra indirection.
- Every exported helper needs a short docstring describing behavior, arguments, and guarantees.
- Ensure each module has a focused `lib/<module>_test.mu` covering exported helpers; run `mu -test ./lib/<module>.mu` (or `mu -test ./lib`) to validate stdlib behavior after cleanup.
- Update the README/docs module lists whenever you add or split modules so the public surface stays discoverable.

## Future module candidates

As mu grows beyond the bootstrapped runtime, the next standard-library phase should focus on a handful of small, orthogonal modules. Stage-0 already ships namespaced modules; treat these candidates as patterns for future additions rather than as a separate module system.

### `sys` (file descriptors and process I/O)
* `open(path, mode) -> fd | error`
* `read_all(fd) -> string | error`
* `write(path|fd, data) -> nil | error`
* `close(fd) -> nil | error`
* `readln() -> string | error`

File helpers should always return a result plus an error so callers can check `type(v) == "ERROR"` rather than panicking, and large reads may later acquire streaming APIs if needed. The `read(path)` host builtin is retained for convenience and small scripts.

### `strings` (string helpers)
* `split(s, sep) -> list`
* `join(list, sep) -> string`
* `replace(s, old, new, n) -> string`
* `upper(s) -> string`
* `lower(s) -> string`
* `trim(s) -> string`

String helpers stay non-mutating and eagerly return new strings; advanced pattern matching or regex support can wait for a future stage.

### `math` (integer helpers)
* `abs(x) -> int`
* `pow(x, y) -> int`
* `sqrt(x) -> int | float`
* `rand() -> int`

Keep the math helpers limited to integers for now; introduce `seed(n)` when randomness needs deterministic control and defer full float support until the type system is ready.

### `time` (clock helpers)
* `now() -> int` (Unix seconds)
* `format(ts, layout) -> string` (Go-like layouts)
* `sleep(seconds) -> nil`

Implementations may busy-wait or rely on the host runtime; just document blocking behavior and the impact on any future concurrency model.

### `json` (serialization helpers)
* `encode(value) -> string, error`
* `decode(string) -> value, error`

JSON helpers must guard against code execution, normalize object field ordering for reproducibility, and map mu lists/maps to JSON arrays/objects.

## Naming and imports

The module system makes imported helpers explicit: every module lives under its own namespace, and modules do **not** inject their definitions into the global scope.  Import modules at the top level, optionally renaming them with `as alias`, and invoke their functions behind the namespace (`strings.split`, `sys.open`, etc.).  Keep the curated global helpers in the prelude small, and only promote a helper to that layer when it is universally useful and cannot reasonably live behind a module namespace.

## Growth guardrails

Any addition to the stdlib must:
1. Diagnose clear, repeatable demand.
2. Keep signatures small and composable.
3. Return explicit errors instead of panicking.
4. Prefer small helpers that can be composed into richer workflows rather than monolithic APIs.

When the language eventually supports a small package manager, reuse these guidelines so third-party modules follow the same minimalism.

## Other rules

- No stdlib function should ever panic on user input.
