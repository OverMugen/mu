# Macro system

mu now ships with a compile-time macro system that executes before the compiler translates the AST into bytecode. The host keeps the runtime small by letting mu code define, inspect, and transform the parsed tree before anything runs.

## Defining macros

Import the helper module and call `macro.define` with a name and a handler function. The handler always receives the call expression as its first argument (a map with `"node": "CallExpression"`, `"function"`, and `"arguments"`) and then one entry per argument that the caller wrote.

```
import "macro"

macro.define("identity", fn(call, arg) {
  return arg
})
```

Handlers work with AST representations: literals come through as maps of the form `{"node": "IntegerLiteral", "value": 42}` and complex expressions expose their fields (`left`, `right`, `body`, …). The macro runtime converts the map back into `ast.Expression` nodes after the handler returns, so macros can build new fragments purely with mu maps and lists.

## Usage

Macros are invoked like ordinary calls. When `identity(123)` is parsed, the compiler first expands macros, so the AST seen by the rest of the pipeline becomes just the literal `123`. Macro handlers can read or rewrite the entire call, inspect helper modules, and hand back any expression or sequence of expressions that the compiler then expands recursively.

## How it works

- The compiler wires an `internal/macro.Expander` between parsing and bytecode generation.
- The builtin `__macro_define` registers mu closures with that expander.
- During expansion, the compiler wraps every call expression whose identifier matches a registered macro and substitutes the handler's result into the AST.
- Handlers run in their own mu environment (via the VM) and only see AST data (maps/lists), so the host still controls the runtime surface while macros remain expressible in mu itself.

See `lib/macro.mu` to boot up the helper module.

The support module `ast` exposes builders such as `identifier`, `callExpression`,
`functionLiteral`, `ifExpression`, and every other AST node. Use it to keep macro
definitions concise while still representing mu's syntax in a consistent map
structure; `examples/macro_demo.mu` shows how `ast` plus `macro.define`
turn into reusable helpers like `log`, `assert`, and `unless`.

For a hands-on, tutorial-style walkthrough that covers the basics, AST helpers,
and common caveats (including `ffi.fn` bindings), see `docs/MacroTutorial.md`.
