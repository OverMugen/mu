# Roadmap

## North Star

mu remains:

* **Minimal**: small grammar, small core runtime, small builtin surface.
* **Self-hostable**: the compiler/tooling path must converge toward mu-on-mu.
* **Practical**: good enough for real scripts, AoC-style programs, and small services.
* **Predictable**: stable semantics across VM and native backends, with strong tests as the contract.

Non-goals:

* Chasing “mainstream language parity” (huge stdlib, heavy metaprogramming, complex type systems, etc.).
* Feature creep in core builtins unless it demonstrably reduces total system complexity.

---

## Guiding principles

1. **Language stays small; tooling grows around it.**
2. **One binary (`mu`) is fine. Prefer flags over subcommands.**
3. **Conformance > features.** Shared `testdata/` programs are the source of truth for behavior.
4. **No magic.** Prefer explicit, inspectable mechanisms (imports, resolution, errors).

---

## Phase 0 — Consolidate what exists

### Deliverables

* Update `docs/` so the spec matches reality (modules/imports, current builtins, sample program expectations).
* Make “what is stable” explicit:

  * core syntax
  * module semantics (search paths, caching, cycles, init order)
  * builtin signatures and error behavior
  * truthiness rules

### Acceptance criteria

* Spec does not mention modules as “future work” if they already exist.
* Every builtin is documented with:

  * signature
  * types
  * return values
  * runtime errors
* All examples in README/docs run under both VM and native (where applicable).

---

## Phase 1 — Tooling via flags (minimal UX, high impact)

Goal: keep a single binary, but enable day-to-day development workflows.

### Proposed CLI surface

* `mu <file.mu> [args...]` (current behavior)
* `mu -c <file.mu>`: compile (native or bytecode, depending on target)
* `mu -check <file.mu>`: parse + type/semantic checks only (no run)
* `mu -fmt <file.mu>`: format to stdout (or `-w` to write)
* `mu -test [path]`: discover and run tests (can be flag-gated; see below)

You can still keep the implementation internally structured as subcommands, but the user-facing surface can be “flags only”.

### Must-have behaviors

* All tooling flags must:

  * accept a file or directory
  * use the same module resolution as runtime
  * return non-zero exit codes for failure (`exit` builtin complements this)

### What “check” means (minimal)

* unused imports
* unused local bindings (optional)
* shadowing warnings (optional, but your `:=` vs `=` model already helps)
* unreachable code (basic)
* suspicious constructs (e.g., `=` to unknown binding should already be an error)

### What “fmt” means (minimal)

* canonical formatting
* no configuration
* stable output (formatting is part of the ecosystem contract)

### Acceptance criteria

* `mu -fmt` round-trips any `testdata/` program unchanged after 2 passes.
* `mu -check` is fast and produces good location info on errors.
* `mu -check` is useful but not noisy.

---

## Phase 2 — Diagnostics and developer experience

This is the next biggest multiplier after tooling flags.

### Deliverables

* Stack traces with file/line/function names.
* Source mapping for bytecode VM and native compiler.
* Runtime error messages become consistent and testable:

  * include location
  * include a short message
  * include a small source excerpt (optional but very valuable)

### Acceptance criteria

* A failing `testdata/` program yields a deterministic error string (or structured output) suitable for CI assertions.

---

## Phase 3 — Concurrency and sockets (as designed)

Deliverables (from the design docs you’ve already settled):

* Process builtins: `run/spawn/wait/kill/proc`
* Core concurrency builtins: `go/await/chan/send/recv/poll/offer`
* Socket builtins: `listen/accept/dial/recvfrom/sendto` + extend `read/write/close` for TCP `conn`

### Acceptance criteria

* Unit tests for argument validation and semantics.
* Integration tests:

  * shared `.mu` sources in `testdata/` used by both VM and native harnesses
  * non-trivial examples (worker pool, pipeline, tcp/udp echo)
  * low-level helpers such as `lib/sockets.mu` and `testdata/sockets.mu` run the TCP/UDP echo scenarios in both execution modes

---

## Phase 4 — Make the module system a hardened contract

Even if modules exist today, the rules must be locked down to avoid “works on my machine”.

### Deliverables

* Document and enforce:

  * module search roots (project root, `lib/`, std paths, etc.)
  * import path normalization
  * single-load caching rules
  * cyclic import detection and error shape
  * deterministic initialization order

### CLI support

* `mu -deps <file.mu>`: print import graph (optional, but very helpful for tooling)

### Acceptance criteria

* Identical import resolution in VM and native.
* Import graph is deterministic across platforms.

---

## Phase 5 — Self-hosting milestones

This phase is about credibility and long-term maintainability, not user-visible features.

### Deliverables

* A mu implementation of:

  * lexer
  * parser
  * (eventually) bytecode compiler
* Bootstrapping plan:

  * stage-0 (Go) builds stage-1 (mu) which can build itself

### Acceptance criteria

* A “bootstrap build” path that is documented and reproducible.
* Parity test suite runs against both stage-0 and stage-1 artifacts.

---

## Phase 6 — Optional, carefully-scoped additions

Only if real programs demand it.

### Candidates (not commitments)

* Unix sockets (schemes): `unix://`, `unixgram://`
* Deadline/timeouts for sockets/processes (prefer library patterns first)
* Small stdlib expansion written in mu (keep core builtins stable)
* Performance work:

  * compiler optimizations
  * VM speedups
  * memory model decisions (avoid surprises under concurrency)

### Anti-goals

* Large “batteries included” stdlib in core
* Complex type system
* Macro system
* Implicit async/await or promise-based concurrency

---

## Success criteria for “stronger position” (without chasing mainstream)

mu is “strong” when:

* It can comfortably solve:

  * AoC-level problems
  * real scripting tasks (files + processes + text)
  * small concurrent services (TCP/UDP)
* Tooling is good enough that contributors don’t dread changing code:

  * `mu -fmt`, `mu -check`, `mu -test`
* Behavior is stable and regressions are caught:

  * shared `testdata/` suite across VM + native + (later) self-hosted compiler
* Documentation matches reality.

---
