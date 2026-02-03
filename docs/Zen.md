# Zen of mu

This note captures mu’s philosophy, the goals guiding its design, and the attitude we encourage contributors and users to adopt. The statements complement the more formal references (`docs/Specification.md`, `docs/Design.md`, `README.md`) by calling out why the project exists, what it values compared to other languages, and what “Zen” principles keep the language focused.

## Philosophy and goals

- **Minimal core.** mu’s stage-0 host implements a single-file interpreter/compiler/VM with a tiny collection of host-builtins (`internal/builtins`). Keeping the Go surface as small as possible makes the runtime easier to reason about, exposes fewer portability hazards, and lets the mu-implemented `lib/` tree sow the richer helpers over time.
- **Expressive ergonomics.** Syntax borrows from Go and Python but keeps keywords to the essentials (`fn`, `if`, `else`, `while`, `continue`, `break`, `return`, `true`, `false`, `nil`), encourages expression-style `if`, and provides lists/maps plus closures so users can write concise pipelines without ceremony.
- **Self-hosting momentum.** Every stage of the roadmap aims to consume more of itself (`selfhost/`) so the language can later bootstrap from mu code alone. That drives decisions like keeping the builtin table static, growing `lib/`, and ensuring parity between the VM runtime and native compiler plans.
- **Predictable semantics.** Types and truthiness rules are defined in `Specification.md`, ops produce predictable errors, and builtins have precise arity/contracts, making mu a trustworthy foundation for tooling despite being dynamically typed.
- **Composable stdlib.** Instead of embedding a massive standard library in the host, mu relies on the embedded `lib/` modules plus the prelude injection so that higher-level helpers (e.g., `println`, `panic`, `time()`, `assert`) live in mu code and can be extended by real mu modules as the language matures.

## How mu compares

- **Python:** Python gives you many batteries and a large builtin list plus modules in the standard library, but that can also mean hunting down `import` statements and remembering dozens of reserved words/functions. mu keeps both keywords and host-builtins minimal and pushes extra helpers into mu-written modules so its surface stays constrained even as the stdlib grows.
- **Go:** Go’s syntax and runtime influenced mu (keywords, braces, `:=`, etc.), but mu deliberately avoids Go’s compile-time commitments (static typing, goroutines, extensive `builtin`/`types`). Go programmers must master about 25 keywords and a handful of builtins; mu keeps the same feel with only 10 keywords and a focused host builtin table, letting mu programmers iterate faster while still being able to reason about the runtime.
- **Small languages (Lua, Scheme, etc.):** Like these, mu trades “once-you-learn-it” simplicity for a tiny core plus a culture of libraries. mu’s emphasis on clearing host builtins in favor of mu-backed modules mirrors Lua’s minimal C API and Scheme’s emphasis on lisp macros, while offering a more imperative syntax for newcomers.

## Zen of mu

1. **Keep the host very small.** Every builtin you add to Go increases the trusted surface. Prefer mu code in `lib/` unless a capability truly requires host support. The new `lib/sockets.mu` proves that TCP/UDP helpers can land purely in mu using `syscall` and `buf`, so the Go host only needed an expanded syscall table, not fresh builtins.
2. **Think in expressions first.** Favor expression-based constructs and let every value be nil-friendly; `if` should yield, loops should be obvious.
3. **Predeclare nothing but what every program always needs.** Reserve the builtin table for essential operations and inject additional helpers via the prelude/stdlib.
4. **Compose smaller pieces.** Build large behavior from lists, maps, closures, and mu stdlib modules rather than introducing new keywords or global state.
5. **Document intent.** When proposing new runtime helpers (builtins or modules), spell out the mental model, how mu compares to other languages, and how the stdlib/prelude layering keeps the runtime approachable.

These statements are intentionally aspirational; follow them to keep mu focused on minimalism, expressiveness, and a clear upgrade path toward full self-hosting.
