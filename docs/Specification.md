# mu Language Formal Specification

This document provides a detailed, normative definition of the mu programming language as implemented in the stage‑0 system.  It is intended as a reference for implementers and users, describing the lexical, syntactic and semantic rules, the runtime behaviour and built‑in functions.

---

## 1. Lexical Structure

### 1.1 Characters and Encoding

Source files are sequences of Unicode code points encoded as UTF‑8.  Implementations must process input as UTF‑8; bytes that do not form valid UTF‑8 sequences should be rejected.

### 1.2 White Space and Comments

Whitespace characters (spaces, tabs, carriage returns and newlines) separate tokens and are otherwise ignored.  Single‑line comments begin with `//` and extend to the end of the current line.  Block comments begin with `/*` and end with `*/`, and may span multiple lines.  A shebang line starting with `#!` is permitted only at the beginning of a source file and is treated as a comment.  Comments are treated as whitespace.

Docstrings are extracted from comments when they appear at the top of a module (before any other statements) or immediately above a top‑level function declaration.  These docstrings are surfaced by the VM-only `help()` builtin for modules and functions.

### 1.3 Tokens

The lexical scanner produces the following token categories:

| Category        | Examples             |
|-----------------|----------------------|
| **Identifiers** | `foo`, `bar_1`, `_x` |
| **Keywords**    | `fn`, `import`, `if`, `else`, `while`, `continue`, `break`, `return`, `true`, `false`, `nil` |
| **Literals**    | Integers, strings, booleans, nil |
| **Operators**   | `+`, `-`, `*`, `/`, `%`, `**`, `==`, `!=`, `<`, `<=`, `>`, `>=`, `&&`, `||`, `!` |
| **Delimiters**  | `(`, `)`, `{`, `}`, `[`, `]`, `,`, `:`, `;` |
| **Assignment**  | `:=` (declaration), `=` (assignment), `+=`, `-=`, `++`, `--` (updates) |

### 1.4 Identifiers

Identifiers begin with a letter (Unicode category `Lu` or `Ll`) or underscore `_`, followed by zero or more letters, digits or underscores.  Identifiers are case‑sensitive.  Identifiers cannot be keywords.

### 1.5 Literals

* **Integer literals** represent 64‑bit signed integers.  Only decimal notation is supported.
* **String literals** are enclosed in double quotes `"` and may contain the escape sequences `\n`, `\t`, `\\` and `\"`.  Strings are UTF‑8.
* **Boolean literals** are the keywords `true` and `false`.
* **Nil literal** is the keyword `nil`, representing the absence of a value.

---

## 2. Syntax

mu uses a context‑free grammar described in detail in `Grammar.md`.  The top‑level structure is a sequence of statements and function declarations.  Blocks are enclosed in braces `{}` and introduce new lexical scopes.  Semicolons are optional as long as newlines or closing delimiters separate statements, but they can also be used to place multiple statements on a single line.

---

## 3. Semantics

### 3.1 Execution Model

Execution proceeds in the following phases:

1. **Parsing** – The source is lexed and parsed into an abstract syntax tree.  If parsing fails, the program is rejected and no further phases occur.
2. **Compilation** – The AST is traversed to produce bytecode.  Variables are resolved to specific slots in local or global storage.  Function literals are compiled into standalone instruction sequences with captured free variables.
3. **Evaluation** – The bytecode is executed by a virtual machine.  A fixed‑size stack holds intermediate values.  A global store holds top‑level variables.  A frame stack stores function call contexts.

### 3.2 Types and Values

mu values are dynamically typed.  Operations at runtime check operand types and either compute results or raise errors.

* **Integers** – Support arithmetic (`+`, `-`, `*`, `/`, `%`, `**`), bitwise (`&`, `|`, `^`, `~`, `<<`, `>>`), comparisons and equality.  Division is truncating, shifts operate on signed 64-bit integers and division by zero raises an error.
* **Booleans** – Support logical operators `&&`, `||`, `!`.  Any value may be used in boolean context with truthiness rules.
* **Strings** – May be concatenated with `+`.  Other arithmetic yields an error.  Equality compares contents, and relational operators (`<`, `<=`, `>`, `>=`) perform lexicographic comparisons over UTF-8 code points so ordering matches string contents.
* **Buffers** – Mutable byte ranges created by the `buf(size)` builtin.  `len(buffer)` reports the allocated size, buffers are falsey when empty, and `str(buffer)` converts their contents to a string (terminating at the first null byte) so they can feed raw host syscalls. Buffers support list-like indexing: `buffer[i]` yields an integer byte (or `nil` when out of bounds), `buffer[i] = n` updates a byte, and list-style helpers (`append`, `insert`, `pop`, `del`) operate on buffers using integer byte values (0–255).
* **Lists** – Ordered collections of values.  Indexing uses zero‑based integers.  Index out of bounds returns `nil`.  `len(list)` returns the number of elements.  `append(list, value)` adds to the end and returns the list.
* **Maps** – Unordered collections mapping string keys to values.  Indexing by a string key returns the value or `nil` if absent.  `len(map)` returns the number of key/value pairs.  `append` is not valid on maps.
* **Functions** – Functions are closures capturing their surrounding environment.  Functions cannot be compared for equality.
* **Libraries** – Opaque dynamic library handles returned by `dlopen`.  `type` reports `"LIB"`.
* **Pointers** – Opaque foreign pointers returned by `dlsym` or `dlcall` when the signature returns `ptr`.  `type` reports `"PTR"`.
 * **nil** – A unique value representing the absence of a value.  It is the default value of uninitialised variables and return values.
* **Truthiness** – See `internal/vm/vm.go:isTruthy`: `false`, `nil`, the integer `0`, the empty string, empty lists/maps, and empty buffers are falsey; everything else is truthy, so `&&` and `||` short-circuit accordingly.

### 3.3 Scoping and Variables

Variables are bound to values via declarations and assignments.  Lexical scoping rules determine where a variable can be referenced.

* **Declaration** – `x := expr` evaluates `expr` and binds it to `x` in the current scope.  If `x` already exists in an outer scope, it is shadowed.
* **Assignment** – `x = expr` evaluates `expr` and updates the nearest existing `x` in the lexical chain.  If `x` does not exist, a compile‑time error is produced.  Assignments to builtin names are compile errors. Assignments to captured variables update the closure's captured slot.
* **Update assignment** – `x += expr`, `x -= expr`, `x++`, and `x--` are shorthand for reading the current value and writing back the updated result. `x++` increments by one, `x--` decrements by one, and `x += expr`/`x -= expr` add or subtract the right-hand expression.

### 3.4 Control Flow

* **If expressions** evaluate their condition.  If true, the consequence block is executed and its last value is the result.  Otherwise the alternative block (if present) executes.  If no alternative executes, the result is `nil`.
* **While statements** repeatedly evaluate the condition and execute the body while the condition is truthy.  `continue` jumps to the next iteration (re-evaluating the condition), and `break` exits the nearest enclosing loop.  Using `break` or `continue` outside a loop is a compile-time error.  `while` yields no value.
* **Return statements** exit the current function immediately.  A return in top-level code is illegal.  If no expression follows `return`, it returns `nil`.

### 3.5 Functions and Closures

Functions are created either by declarations or by function literals.  When a function is created, it captures its lexical environment, including any free variables.  Each invocation of a function creates a new local scope for parameters and local variables.

Calling a user-defined function with the wrong number of arguments returns an error value describing the expected versus provided counts (and the function name when available).  Variadic functions declare their final parameter with `...` and may be called with extra arguments; the trailing parameter receives a list of those extra arguments (or an empty list if none are provided).  Builtins enforce their own arity, returning an error value on misuse.

#### Forward Declarations

Function declarations may be referenced before their definition appears in the source text.  During parsing, each top-level `fn` declaration registers its name (and parameter list) in the symbol table so later references can resolve to it even if the body is parsed afterwards.  This enables mutual recursion at the top level and eases the implementation of a self-hosted parser or compiler written in mu itself.

### 3.6 Errors and Exceptions

mu does not have an exception mechanism.  There are two categories of errors:

* **Error values** are ordinary values returned by `error(message)` or by host-level builtins on misuse.  They have type `"ERROR"` and can be handled explicitly:

  ```mu
  value := do_work()
  if type(value) == "ERROR" {
      println("failed:", value)
  }
  ```

  `inspect` and `println` render error values as their message.

  Recoverable mistakes such as indexing a list, map, or string with the wrong type, attempting to assign beyond a list’s bounds, or calling a function with the wrong number of arguments now return error values rather than halting the VM.  File and descriptor helpers—`read`, `open`, `write`, `close`, `readln`, and their helpers inside `lib/sys.mu`—propagate the underlying OS failure information through error values so scripts can detect missing files, permission problems, or invalid descriptors.

* **Runtime errors** halt program execution.  Common errors include:

* Using an undefined variable.
* Assigning to an undefined variable or a builtin.
* Calling a non-function or non-closure value.
* Performing invalid operations (e.g. adding a string and an integer).

In the REPL, errors are printed but do not exit the session; they simply discard the current computation.

### 3.6 Builtin layers

mu exposes three distinct helper layers:

1. **Stage-0 host builtins** – implemented in Go and always available everywhere via their names.  These live in `internal/builtins` and include `len`, `append`, `error`, `ord`, `chr`, `args`, `env`, `pop`, `del`, `insert`, `keys`, `values`, `has`, `type`, `inspect`, `read`, `syscall`, `platform`, `buf`, `int`, `str`, `bool`, `dlopen`, `dlsym`, `dlcall`, `help`, and the test harness helpers `__mu_test_register`/`__mu_test_signal_failure`.  `help` is implemented only in the bytecode VM; native builds treat it as a no-op.
2. **Global stdlib builtins** – pure-µ helpers defined by the injected `prelude`.  The prelude imports just the minimal modules it needs (e.g., `sys` for I/O) and exposes a curated set of helpers such as `println`, `panic`, and `test`.  Because they are defined in µ, they can be redefined in user modules or disabled with `MU_PRELUDE_DISABLED=1`.
3. **Namespaced stdlib modules** – the larger library in `lib/` (`sys`, `strings`, `assert`, `array`, `math`, `decimal`, `encoding`, `ffi`, `fp`, `json`, `path`, `process`, `sqlite`, `test`, `text`, `time`, etc.) that must be imported explicitly and accessed via their namespace (e.g., `strings.split`, `math.max`).  Module imports never pollute the global scope; every module symbol lives behind a dot so the namespace is always explicit.

### 3.7 Modules and Imports

mu programs load additional helpers via the top-level `import` statement described in `Grammar.md`.  Each `import` must appear in the outermost statement list (blocks and functions cannot contain `import`).  The syntax is:

```mu
import "path/to/module" [as alias] ;
import identifier.name [as alias] ;
```

Paths may be quoted strings or bare identifiers.  The optional `.mu` suffix is stripped, and any `/`, `.` or `..` segments are normalized (without escaping the embedded tree).  When the `as alias` clause is omitted, the alias defaults to the final segment of the normalized path.

#### 3.7.1 Resolution order and normalization

When the compiler processes `import "name"` it normalizes the path by replacing backslashes with `/`, trimming trailing `/`, stripping a final `.mu`, and collapsing `.` segments.  `..` segments are honored so long as they do not escape the embedding root; attempts to walk above the root produce `stdlib import escapes root` or `import path resolves to empty path`.  Absolute imports are those that either start with `/` or satisfy `filepath.IsAbs` on the current platform.

The compiler resolves modules in the following order:

1. If the `MULIB` environment variable is set, the compiler first checks the cleaned absolute directory it points to.  It looks for `<MULIB>/<normalized>.mu`, allowing custom implementations to replace embedded modules.
2. Next, the embedded `lib/` tree is consulted using the normalized path as a key (e.g., `lib/sys.mu` is `sys`, `lib/decimal.mu` is `decimal`).  The tree is embedded via `lib/embed.go`.
3. Finally, if the importer’s base directory is outside the embedded tree (the compiler tracks each module’s directory when recursing) or if the import path is absolute, the compiler resolves the filesystem path by appending `.mu` if necessary and joining it with the current base directory.  Visits from standard-library modules do not re-enter the filesystem via relative imports.

If none of these steps produce a module, the compile phase fails with `module <path> not found`.  Parse failures inside the module bubble up as `failed to parse module <path>: <details>`.

#### 3.7.2 Namespace semantics

Each `import` binds exactly one identifier in the global symbol table (`alias`, or the inferred name) and leaves every exported helper behind a dot on the module namespace object.  After `import "strings"` the name `strings` refers to the module namespace, and the helper is invoked as `strings.split(...)`.  Bare identifiers that refer to module exports without a namespace now fail unless a builtin or global symbol with that name already exists.

Module namespace objects behave like immutable maps: you can read `module["helper"]` or use dot sugar, but assignments to `module.helper`/`module["helper"]` produce runtime errors.  The module alias is not user-constructible.  Modules always share the same lifecycle as the prelude injection: the compiler initializes the requested module before executing the rest of the program, caches it across imports, and binds the namespace to the alias without exporting its internal globals.

#### 3.7.3 Prelude behavior

Before expanding user statements, the compiler injects the `prelude` module unless `MU_PRELUDE_DISABLED=1`.  The prelude imports `sys` and exposes a slender global layer (`println`, `panic`, `test`).  Prelude helpers call their module namespaces explicitly, so the surrounding program still needs to import modules to use their other helpers.  Disable the prelude when you want to run without these globals (useful for parity testing) or point `MULIB=/path/to/lib` to override individual modules before falling back to the embedded tree.

#### 3.7.4 Standard library

Standard-library modules live in the embedded `lib/` tree (`sys`, `strings`, `assert`, `array`, `math`, `decimal`, `encoding`, `ffi`, `fp`, `json`, `path`, `process`, `sqlite`, `test`, `text`, `time`, etc.).  Each module is referenced by its path relative to `lib/` without the `.mu` suffix.  Setting `MULIB` overrides only the modules that exist under the override directory; missing modules fall back to the embedded versions.

---

## 4. Virtual Machine

The mu compiler outputs instructions defined in `code/code.go`.  Each opcode has a fixed operand width (0, 1 or 2 bytes).  The VM executes instructions sequentially, manipulating a stack of objects.  Jumps modify the instruction pointer.  Function calls push a new frame with its own local variables and base pointer.

### 4.1 Stack and Frames

* The **stack** is an array of objects.  It grows by pushing and shrinks by popping.  Arithmetic and logical operations pop operands and push results.
* **Frames** represent function calls.  Each frame stores the currently executing closure, the instruction pointer and the base pointer in the stack where its locals start.  On function return, the frame is popped and the stack pointer is reset.

### 4.2 Globals and Constants

* The **global store** is a fixed‑size array of values accessible by index.  Top‑level variables are mapped to indices in the global array by the compiler.
* The **constant pool** stores all literal values and compiled functions referenced in the program.  `OpConstant` loads constants by index.

### 4.3 Built‑ins and Closures

Built‑in functions are stored in a reserved table.  `OpGetBuiltin` pushes a builtin onto the stack.  `OpCall` dispatches to either a closure or a builtin; closures push new frames, while builtins are executed directly.

Closures consist of a compiled function and a slice of free variables captured from the enclosing environment.  `OpClosure` packages a function and its free variables into a closure object.

### 4.4 Concurrency model

mu’s concurrency is **cooperative**: a single task executes bytecode at a time, and tasks yield only at documented blocking builtins (including `wait`, `send`, `recv`, `sleep`, and blocking I/O).  The scheduler is deterministic given a deterministic sequence of blocking operations: runnable tasks are resumed in FIFO order, and channel waiter queues are FIFO.

Tasks are lightweight fibers managed entirely by the runtime.  Creating a task does not imply parallel execution; the runtime may remain single‑threaded.  A task may return a value or terminate with a runtime error; `wait(task)` re‑raises any stored runtime error in the waiting task.  If a task errors and is never waited on, the runtime terminates at program end with an error status so unobserved failures are not silently dropped.

---

## 5. Built-in Functions

The stage-0 host registers a fixed table of builtins that are accessible from any scope via their names.  The list below mirrors `internal/builtins/builtins.go` and the VM entry points in `internal/vm/vm.go`.  These functions are the only ones implemented in Go and exposed unconditionally at runtime.  Builtins return error values on misuse rather than halting execution.

### General utilities

- `args()` – Returns the program arguments as a list of strings. When running a script via the `mu` interpreter, the interpreter path is omitted and `args()[0]` is the script path.
- `env(name?)` – Without arguments returns a map of all environment variables; passing a string key returns the variable’s value or `nil`.
- `type(value)` / `inspect(value)` – Return the runtime type name and debug string, respectively.
- `error(message)` – Returns an error value with the provided message.
- `int(value?)` – Convert the provided value to an integer; with no arguments it returns `0`, and it accepts integers, booleans, `nil`, or numeric strings (optional leading `+`/`-`).
- `str(value?)` – Convert the provided value to a string, defaulting to `""` when no arguments are supplied; buffers are read up to the first null byte and other values use their `inspect` representation.
- `bool(value?)` – Convert the provided value to a boolean via the VM truthiness rules, returning `false` when no arguments are given.

Common user helpers like `println` and `panic` are provided by mu code in the injected `prelude` module (built on top of `sys`) rather than by Go host builtins, while richer assertions live behind the `assert` module so they can be imported with an explicit namespace.

### Collections

- `len(value)` – Returns the length of strings, lists, buffers, or maps.
- `append(list_or_buffer, value)` – Appends to a list in place; when the target is a buffer, `value` must be an integer byte (0–255).
- `pop(list_or_buffer)` / `del(list_or_buffer, index)` / `insert(list_or_buffer, index, value)` – Helpers to pop, remove, or insert list elements; for buffers the `value` must be an integer byte (0–255). `del` returns the removed element.
- `keys(map)` / `values(map)` / `has(map, key)` / `del(map, key)` – Map helpers that return list views, boolean membership checks, or the removed value (`nil` if the key was absent).

### Concurrency

- `task(fn, args...)` – Start a new task that runs `fn(args...)` cooperatively. Returns a `task` handle. Misuse (non‑function) returns a runtime error value; argument arity errors surface inside the task when it runs.
- `wait(task)` – Block until the task completes. Returns the task’s result or re‑raises the task’s runtime error. Repeated calls are deterministic (same result or error).
- `chan(cap?)` – Create a channel. `cap` defaults to `0` (unbuffered). Negative `cap` is a runtime error.
- `send(ch, value)` – Blocking send. For unbuffered channels, waits for a receiver. For buffered channels, enqueues if space exists, otherwise blocks.
- `recv(ch)` – Blocking receive. For unbuffered channels, waits for a sender. For buffered channels, dequeues if available, otherwise blocks.
- `poll(ch)` – Non‑blocking receive. Returns `[true, value]` if a value is immediately available (including a waiting sender); otherwise returns `[false, nil]`.
- `push(ch, value)` – Non‑blocking send. Returns `true` if the value is delivered immediately (including a waiting receiver or available buffer slot); otherwise returns `false`.

Channels are untyped; any mu value can flow through them. Waiter queues and buffers are FIFO, and direct handoff to a waiting sender/receiver is preferred over buffering when possible.

### File and environment I/O

- `read(path)` – Read the contents of a path into a string. On misuse or failure, this builtin returns an error value.
- `open(path, mode)` / `write(path|fd, data)` / `close(fd)` / `readln()` – mu implements these helpers inside `lib/sys.mu`. Missing files, permission errors, invalid descriptors, or malformed arguments return an error value (`"ERROR"`) so scripts can handle I/O failures without crashing the VM.
### Time, randomness, and character helper
- `ord(string)` / `chr(code)` – Convert between single-character strings and Unicode code points.
The `time()` helper is implemented in the `time` standard library module using OS syscalls rather than being a stage-0 builtin; import `time` to use it.

The stdlib helpers provide file-descriptor I/O: `open(path, mode)` returns an integer file descriptor, `write(path|fd, data)` writes to a path or descriptor, `close(fd)` closes a descriptor, and `readln()` reads a single line from stdin.

### Foreign function interface

- `dlopen(path)` – Open a shared library and return a `"LIB"` handle or an error value.
- `dlsym(lib, name)` – Resolve `name` in a `"LIB"` handle, returning a `"PTR"` or an error value.
- `dlcall(ptr, signature, args...)` – Invoke a foreign function pointer with a signature map containing `"ret"` and `"args"` keys.  The VM can resolve and invoke dynamic signatures; the native compiler only permits compile-time constants and rejects dynamic `dlcall` usage.
- The `ffi` module provides `ffi.sig(ret, args)` to build signature maps and `ffi.fn(lib_path, symbol, ret, args)` to return a callable closure that binds a constant library, symbol, and signature at compile time.
- `ptr` arguments accept pointer values, non-negative integers, `nil`, and buffers (passing the address of the buffer’s backing bytes).
- Supported signature types: `i8`, `i16`, `i32`, `i64`, `u8`, `u16`, `u32`, `u64`, `isize`, `usize`, `ptr`, `cstr` (arguments only), and `void` (return only).  Floats, structs, variadics, callbacks, and returning `cstr` are unsupported and produce errors.

### Low-level

- `syscall(number[, a, b, c, d, e, f])` – Invoke a host OS syscall by number with up to six integer arguments, returning the integer result or an error value on failure.
- `buf(size)` – Allocate a zeroed buffer of the requested length so host syscalls can read or write raw bytes; pass the buffer and `len(buffer)` when a syscall expects a writable pointer/length pair.

More builtins can be added by extending `internal/builtins` and updating the compiler/VM wiring.

### Result helper module

`lib/result.mu` exposes helpers that wrap successful values and failures in the same `{ok: <bool>, value: <any>, error: <ERROR>}` shape.  `result.ok(value)` produces a success map, while `result.err(messageOrError)` normalizes strings or error values into an `ERROR` object.  `result.match(result, on_ok, on_err)` dispatches between the two cases and returns whichever handler runs, and `result.unwrap_or(result, fallback)` returns the success payload or the provided fallback value.  Relying on this module makes it obvious when a helper can fail without repeatedly checking `type(x) == "ERROR"`; see `examples/result-type.mu` for a practical demonstration.

Helper functions such as `println`, `panic`, `readln`, `open`, `write`, `close`, `sleep`, `randint`, and the `time()` wrapper live in mu itself.  The embedded `lib/` tree contains modules (`sys`, `strings`, `assert`, `array`, `math`, `decimal`, `encoding`, `ffi`, `fp`, `json`, `path`, `process`, `sqlite`, `test`, `text`, `time`, etc.) that implement these helpers, and the compiler injects the `prelude` module (which imports `sys`) before every program runs, exposing the curated globals (`println`, `panic`, `test`).  The curated globals are always available even though they originate from mu code; other helpers still require explicit module imports.  Set `MU_PRELUDE_DISABLED=1` if you wish to run without the injected modules or point `MULIB=/path/to/lib` to override the embedded stdlib.

---

## 6. Future Extensions (Non‑Normative)

While out of scope for stage‑0, possible future enhancements include optional static types, concurrency primitives, standard library expansion, a package manager, and deeper self‑hosting.  See `Roadmap.md` for a staged plan.
