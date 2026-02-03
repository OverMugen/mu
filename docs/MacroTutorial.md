# Macro tutorial

This is a short, hands-on guide to the compile-time macro system described in `docs/Macros.md`. Treat it as a tutorial: each section walks through the common steps for defining, using, and debugging macros plus the toolbox you get from the `ast` helper module.

## 1. What macros are for

Macros run before the compiler translates mu into bytecode. During the “macro expansion” phase the compiler:

1. Parses your source and builds an AST.
2. Registers any `macro.define("name", fn(...){…})` calls that appear in the same module.
3. Visits every call expression. If the callee is a registered macro, it executes the macro handler and replaces that call with the returned AST fragment.

Use macros when you need:

- Literals that depend on compile-time information (e.g., `ffi.fn` paths).
- Domain-specific syntax sugar that rewrites into core language constructs.
- Compile-time helpers such as logging, inline assertions, or constant folding.

Macros are *not* a general-purpose runtime feature—everything they do happens before the bytecode is generated.

## 2. Defining your first macro

Start with the `macro` helper:

```mu
import "macro"

macro.define("identity", fn(call, arg) {
  return arg
})

value := identity(42)  // compiler replaces the call with the literal 42
```

The handler always receives the original call expression as its first argument. The handler may also receive one entry per argument the caller supplied.

Remember:

- Only macros defined inside the same module can affect that module’s later code. Importing a module with macros does not automatically expand them there.
- Handlers must return a value that can be converted back into an `ast.Expression`—typically an AST map, list, literal, or a helper from the `ast` module.

## 3. Building AST nodes with `ast`

`lib/ast.mu` exposes helpers for constructing AST maps so you do not need to hand-write the node maps yourself. Common helpers include `ast.stringLiteral`, `ast.identifier`, `ast.callExpression`, `ast.listLiteral`, and `ast.blockStatement`.

Example: a naive `log` macro that wraps an expression in a function that prints a marker.

```mu
import "ast"
import "macro"

macro.define("log", fn(call, expr) {
  printlnCall := ast.callExpression(ast.identifier("println"), [
    ast.stringLiteral("[macro log]"),
    expr,
  ])

  body := ast.blockStatement([
    ast.expressionStatement(printlnCall),
    ast.expressionStatement(expr),
  ])

  fnLiteral := ast.functionLiteral([ast.identifier("__macro_value")], false, body)
  return ast.callExpression(fnLiteral, [expr])
})
```

The macro returns a new call to an anonymous function literal which prints before evaluating the original expression. Everything here lives in the AST layer; nothing runs until the compiled program executes.

## 4. Working with arguments

You can inspect the AST arguments directly; macros are not limited to literal inputs. Suppose you want to implement a helper that builds `Result` objects:

```mu
macro.define("ok", fn(call, value) {
  return ast.callExpression(ast.identifier("Result"), [
    ast.identifier("ok"),
    value,
  ])
})
```

Because macros operate on the parsed tree, you can inspect, modify, or reorder expressions before touching them. If a macro returns a node that contains more macro calls, the compiler expands them recursively.

## 5. Caveats and gotchas

- **Module-local definitions.** The compiler only registers `macro.define` calls that are in the same module’s source before the first non-function-level definition. This is why `lib/sqlite.mu` defines `sqlite_path` inline rather than in a helper module.
- **Constant-time binding.** `macro.define` runs before `ffi.fn`, so macros are the right place to emit compile-time bindings (paths, symbols, signatures). But once compiled, those literals cannot change; the macro runs on the build machine, so cross-compilation needs an override (e.g., `MU_SQLITE_PATH` in the `sqlite_path` macro).
- **No runtime side effects.** Macro handlers run in the compiler’s mu VM in a restricted environment; avoid relying on state that will not exist when the macro is expanded (e.g., open files, HTTP requests). It’s best to work purely in terms of AST.
- **Errors bubble up early.** If a macro returns `nil`, an invalid AST shape, or panics, the compiler aborts with a message like `macro foo returned nil`. Use that to catch problems before runtime.
- **Macros are hygienic only to the extent you design them.** Because macros emit AST nodes into the calling module, be careful not to unintentionally shadow existing identifiers.

## 6. Practical tips

- Keep macro helpers near the code they affect so they can run before the compiler sees the later expressions.
- Use helper functions in the module (like `sqliteCandidateList`) to keep the macro body short.
- When experimenting, expose debugging output using `println` inside the handler—the macro runs before the compiled program, so its output appears during compilation.
- If you need runtime flexibility, solve the problem with a regular function instead of forcing it into a macro.

## 7. Further reading

- `docs/Macros.md` for the canonical explanation of the macro runtime and builtin hooks.
- `examples/macro_demo.mu` to see helpers like `log`, `assert`, and `unless` implemented with `ast`.
- `lib/sqlite.mu` for a real-world example where macros generate compile-time constants that feed into `ffi.fn`.
