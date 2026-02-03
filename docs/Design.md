# mu Language Design Specification

## Overview

**mu** is a minimal, dynamic, imperative programming language with a clean, Go‑like surface syntax.  It is designed to be small, self‑hostable, readable and easy to implement.  The stage‑0 implementation includes a lexer, parser, abstract syntax tree (AST), bytecode compiler, virtual machine (VM), REPL and a small standard library.  The long‑term goal is a self‑hosting system where the mu compiler is written in mu itself.

## Language Goals

### Simplicity

The language deliberately limits its feature set to a small core of concepts:

* **Dynamic typing** – all values carry their type at runtime.  Type checks occur when values are used.
* **First‑class functions** – functions are values, can be passed around and returned, and support closures.
* **Lists and maps** – built‑in container types provide flexible, heterogeneous collections.
* **Lexical scoping** – variables live in the scope where they are defined; functions capture their defining environment.
* **Minimal control flow** – `if`/`else` and `while` loops cover all branching and iteration.

### Readability

mu’s syntax should be immediately familiar to anyone who has used Go or Python:

* Blocks are delimited with braces `{}`.
* Functions are declared with the keyword `fn`.
* Variable declarations use the `:=` shorthand; assignments use `=`.
* Expressions use infix operators for arithmetic, comparison and boolean logic.

### Self‑Hostability

By keeping the core small and avoiding unnecessary complexity, mu intends to bootstrap itself.  The stage‑0 compiler and VM are written in Go; stage‑1 will introduce a compiler written in mu that produces the same bytecode.  Future stages can evolve toward a native backend or JIT.

### Minimal Runtime

Only the essential opcodes and runtime constructs are implemented:

* **Constants** – loading literal values.
* **Arithmetic** – addition, subtraction, multiplication, division, modulo, bitwise (`&`, `|`, `^`, `~`, `<<`, `>>`).
* **Comparison** – equality, inequality, relational operators.
* **Boolean logic** – `&&`, `||`, `!`, short‑circuit semantics.
* **Variable load/store** – locals, globals, captured free variables.
* **Control flow** – conditional and unconditional jumps.
* **Function calls and closures** – support for nested functions and captured variables.
* **Data structures** – list and map creation, indexing and assignment.

This reduces the VM to a manageable size while still being expressive enough to implement more advanced features in the language itself.

## Execution Model

mu programs are processed in four stages:

1. **Lexing** – The source text is scanned into a stream of tokens representing identifiers, literals, operators and punctuation.
2. **Parsing** – A Pratt parser builds an abstract syntax tree from the token stream according to the grammar.
3. **Compilation** – The AST is compiled into a sequence of bytecode instructions.  A symbol table assigns each identifier to a scope (global, local, builtin or free) and indexes the compiled constants.
4. **Execution** – A stack‑based virtual machine interprets the bytecode.  Frames manage function calls and local variables; the global store holds persistent values across calls and REPL evaluations.

## Value Model

mu has seven runtime types:

| Type    | Description                                                  |
|---------|--------------------------------------------------------------|
| `int`   | 64‑bit signed integer                                       |
| `bool`  | Boolean (`true` or `false`)                                  |
| `string`| UTF‑8 string of arbitrary length                             |
| `list`  | Ordered, heterogenous collection indexed by integer          |
| `map`   | Mapping from strings to values                               |
| `fn`    | Function/closure capturing environment                       |
| `nil`   | Unique null value representing absence of a value            |

All values are first‑class – they can be stored in lists, maps or variables and passed to functions.  Lists and maps can hold mixed types.

## Memory Management (Native Backend)

For the toolchain-free native compiler, mu uses **reference counting (RC)** with **copy-on-write (COW)** for shared containers. This keeps the language dynamic while avoiding a tracing garbage collector.

Key rules:

- Heap objects (strings, lists, maps, closures, errors, files) carry a refcount.
- Assignments, argument passing, and returns retain/release values (compiler-inserted ARC ops).
- Mutating a list or map first checks the refcount; if shared, the container is cloned before the write (COW).
- Cycles are not collected; cyclic structures can leak unless explicitly broken.
- Optional `free(x)` may be provided to allow early release; it is a no-op for immediate values.

These rules do not change the surface grammar or syntax. The stage-0 Go VM continues to rely on Go's GC, but the native backend follows the RC+COW model.

### Truthiness

Conditions in `if` and `while` follow these truthiness rules:

* `false` and `nil` are falsey.
* Integers are falsey if zero, truthy otherwise.
* Strings are falsey if empty, truthy otherwise.
* Lists and maps are falsey if empty, truthy otherwise.
* Functions and builtins are always truthy.

## Scoping Rules

mu uses static lexical scoping with nested environments.

* A **global** scope is created for each program or REPL session.  Top‑level variables live here.
* **Local** scopes are created for each function call.  Parameters and variables declared with `:=` live in the current local scope.
* **Free variables** occur when an inner function references a variable from an outer function; these are captured in a closure.
* **Builtins** (the small host-implemented set like `error`, `len`, `append`, `syscall`, etc.) live in a reserved scope accessible from any context, and assignments to their names are compile-time errors.

Variables shadow names from outer scopes.  Assigning to a variable resolves to the nearest enclosing scope; assigning to a builtin or free variable results in a compile‑time error.

## Control Flow

Only two constructs are necessary to express all control flow:

### If / Else

```
if condition {
    // consequence
} else {
    // alternative (optional)
}
```

The condition is evaluated; if truthy, the consequence block executes.  Otherwise the alternative executes if present.  `if` is an expression in mu, so it yields a value (the last value of the executed block or `nil` if no block is executed).

### While

```
while condition {
    // body
}
```

The loop evaluates the condition; if truthy, executes the body and repeats.  When the condition is false, execution proceeds after the loop.  `while` is a statement and yields no value.

### Return

Functions can return early using `return expr`.  If omitted, the function returns `nil`.  At compile time, missing `return` statements at the end of a function are automatically generated as `return`.

## Functions

Functions are declared with `fn` at the top level or as anonymous function literals within expressions.

**Declaration:**
```
fn add(a, b) {
    return a + b
}
```

This produces a function value assigned to the identifier `add` in the current scope.  Functions can call themselves recursively.  The parameter list is a comma‑separated list of names; no types are declared.

**Literals:**
```
adder := fn(x) {
    return fn(y) {
        return x + y
    }
}
```

The outer function returns an inner function that captures `x`.  The inner function returns `y` plus `x`, demonstrating closures.

### Calls

To call a function or builtin, use the syntax:
```
f(arg1, arg2, ...)
```
The number of arguments must match the number of parameters for user functions; mismatches cause runtime errors.  Builtins may enforce their own arity.

### Forward Declarations

Top-level `var` declarations (both functions and other bindings) register their names in the global symbol table before any statements are compiled.  That pre-registration gives every global a stable slot so references can resolve even if the definition text appears later in the file.  Forward declarations make mutually recursive modules and self-hosting easier because helper functions or data can be used before their source code is reached.  When the initializer for a forward-declared global hasn’t run yet, the VM reports `undefined variable <name>` at runtime rather than failing to compile.  Section 2 of the specification codifies this two-pass registration strategy so self-hosted components can match the host’s ordering independence.

## Data Structures

### Lists

Lists are enclosed in square brackets:
```
nums := [1, 2, 3]
nums[1] // => 2
nums[1] = 42 // assignment
len(nums) // => 3
append(nums, 5) // nums becomes [1, 42, 3, 5]
```

Lists are zero‑indexed.  Indexing out of bounds returns `nil`; assignment out of bounds results in an error.

### Maps

Maps use curly braces and string keys:
```
ages := {"alice": 30, "bob": 25}
ages["alice"] // => 30
ages["bob"] = 26
len(ages) // => 2
```

If a key is absent, indexing returns `nil`.  Maps can only be indexed by strings; other types produce a runtime error.

## Object-like syntax (maps + dot sugar)

mu does not introduce a dedicated object type; instead, **objects are just maps** whose values store fields and methods, optionally using metadata keys such as `"__type"`, `"__doc"`, or `"__proto"` for conventions. Methods are ordinary functions stored inside the map whose first parameter conventionally serves as `self`, and privacy can be achieved by closing over local state.

To keep the surface syntax ergonomic, the parser accepts the `.` punctuation token and parses postfix expressions as a chain of member, index and call operators:

```
EXPR = ASSIGNMENT ;
ASSIGNMENT = POSTFIX ( ( ":=" | "=" ) EXPR )? ;
POSTFIX = ATOM { MEMBER | INDEX | CALL } ;
MEMBER = "." IDENTIFIER ;
INDEX = "[" EXPR "]" ;
CALL = "(" ARGUMENTS? ")" ;
```

The desugaring rules are straightforward:

* `obj.field` → `obj["field"]`
* `obj.method(args...)` → `obj["method"](tmp, args...)`

Method calls require evaluating the receiver exactly once, so the compiler generates an internal temporary local (`tmp`) whose scope is limited to the expression and is never visible to user code. This ensures side effects stay correct and lets existing index/call opcodes handle the work without adding new runtime types or instructions.

## Built‑in Functions

The host runtime keeps a Go-implemented table of builtin functions that are always available from any scope.  These names are the only ones backed by the stage-0 host rather than mu-written modules, and they are listed below.

- **General utilities:** `error`, `args`, `env`, `type`, `inspect`.
- **Conversions:** `int`, `str`, `bool`.
- **Collections:** `len`, `append`, `pop`, `del`, `insert`, `keys`, `values`, `has`.
- **File and environment I/O:** `read` operates on paths (string) and returns a string or error value.
- **Character helpers:** `ord`, `chr`.
- **Low-level + FFI:** `syscall`, `platform`, `buf`, `dlopen`, `dlsym`, `dlcall`.
- **Testing:** `__mu_test_register`, `__mu_test_signal_failure`.

User-facing helpers such as `println`, `assert`, `panic`, `readln`, `open`, `write`, `close`, `sleep`, and `randint` live inside the embedded `lib/` tree (e.g., `sys`, `strings`, `assert`, `time`).  mu loads these helpers via top-level `import` statements: the compiler normalizes `/`, `.` and `..` segments, strips an optional `.mu` suffix, and resolves the module by first consulting the path named by `MULIB` (if set), then the embedded `lib/` tree, and finally, when the importer’s directory is outside the embedded tree or the import path is absolute, the filesystem.  Each `import` binds a single module namespace (the inferred name or explicit alias), and module members are accessed via that namespace (e.g., `strings.split`).  Imports never pollute the global scope; repeated imports reuse the cached module definition rather than re-parsing the file.

The compiler automatically injects the `prelude` module before every program.  The prelude imports `sys` and exposes a curated set of globals (`println`, `panic`, `test`).  Other helpers remain behind module namespaces and still require explicit imports.  Set `MU_PRELUDE_DISABLED=1` to opt out when you want to exercise the builtin-only surface.

More builtins can be added by extending `internal/builtins` and updating the compiler/VM wiring, but the core philosophy is to keep the host table minimal while allowing mu-written libraries to layer additional helpers on top.

## Error Handling

Errors fall into two buckets:

* **Error values** returned by `error(message)` or by builtins on misuse.  They are ordinary values with type `"ERROR"` and can be handled explicitly.
* **Runtime errors** that halt program execution, such as:

* Using an undeclared variable.
* Assigning to a builtin or free variable.
* Indexing a non‑list/map or out of range.
* Calling a non‑function value.

When running in the REPL, errors are printed and the session continues.

The stdlib `panic(message)` helper raises a fatal runtime error with the provided message.

## Bytecode and Virtual Machine

The compiler emits a sequence of opcodes defined in `code/code.go`.  Each opcode may be followed by one or more operands.  Operands with width 2 are stored as big‑endian 16‑bit values; width 1 operands are 8‑bit.

Important opcodes include:

| Opcode              | Operands | Description                                                |
|---------------------|----------|------------------------------------------------------------|
| `OpConstant`        | index    | Pushes constant at index onto the stack                   |
| `OpAdd/Sub/Mul/Div` | –        | Pops two integers and pushes the result                   |
| `OpMod`             | –        | Pops two integers and pushes the remainder                |
| `OpTrue` / `OpFalse`| –        | Pushes boolean value                                      |
| `OpEqual/NotEqual`  | –        | Pops two values and pushes comparison result              |
| `OpLessThan`, etc.  | –        | Integer comparisons; also used for strings/lists/maps equality |
| `OpJump`            | offset   | Jumps unconditionally to offset                           |
| `OpJumpNotTruthy`   | offset   | Jumps if popped value is not truthy                       |
| `OpNull`            | –        | Pushes nil                                                |
| `OpGetGlobal/SetGlobal` | index| Gets or sets value in global array                        |
| `OpGetLocal/SetLocal`   | index| Gets or sets local variable                               |
| `OpGetBuiltin`      | index    | Pushes builtin function                                   |
| `OpClosure`         | fnIndex, numFree | Creates a closure capturing free variables         |
| `OpCall`            | numArgs  | Calls a closure or builtin                               |
| `OpReturnValue/Return`| –      | Returns from a function                                   |
| `OpArray`           | count    | Creates list from popped values                           |
| `OpHash`            | count    | Creates map from popped key/value pairs                   |
| `OpIndex`           | –        | Performs indexing                                         |
| `OpSetIndex`        | –        | Performs assignment to list/map index                     |
| `OpBang`            | –        | Logical NOT                                               |
| `OpMinus`           | –        | Unary negation                                            |

The VM maintains a fixed‑size stack and an array of frames representing function calls.  Each frame stores a base pointer into the stack, the instruction pointer and the closure being executed.

### REPL

The REPL loops over the following steps:

1. Prompt the user and read a line of input.
2. Lex and parse the line into a program AST.
3. Compile the AST to bytecode, preserving the global symbol table and constant pool.
4. Create a new VM instance with the updated bytecode and run it.  The VM shares the global store with previous iterations so that state persists.
5. After execution, pop and print the top value of the stack (if any) as the result.

The REPL can be exited with `Ctrl+C` or `Ctrl+D`.

## File Extension

Source files use the extension:

```
.mu
```

This ensures editors can associate the correct syntax highlighting and file type.

## Future Directions

Stage‑0 establishes a working baseline.  Potential future work includes:

* **Self‑hosting:** Write the mu compiler in mu and drop the Go compiler dependency.
* **Modules:** Add import/export for multi‑file programs.
* **Optional static typing:** Allow type annotations and optional compile‑time type checking.
* **Concurrency:** Explore lightweight concurrency primitives or a channel system similar to Go.
* **Improved error handling:** Introduce try/catch or result types.
* **Expanded standard library:** Provide IO, math, string utilities, file system access and higher‑level data structures.
