# Getting Started with µ (Mu) in 5 Minutes

This guide walks you through µ’s core ideas by example.
By the end, you’ll understand how µ code is structured, how modules work, and how to write and run a small program.

No prior knowledge of µ is required.

---

## 1. Hello, World

Create a file called `hello.mu`:

```mu
println("Hello, µ!")
```

Run it:

```sh
mu hello.mu
```

That’s it.
`println` is part of µ’s **global standard library**, written in µ itself and always available.

---

## 2. Imports and Modules (Explicit by Design)

µ requires **explicit, namespaced access** to imported modules.

```mu
import "sys"

fd := sys.open("hello.mu", "r")
if type(fd) == "ERROR" {
    println(fd)
} else {
    data := sys.read_all(fd)
    println(data)
    closed := sys.close(fd)
    if type(closed) == "ERROR" {
        println(closed)
    }
}
```

Key points:

* `import "sys"` binds a **module namespace** called `sys`
* Module functions are accessed via `sys.*`
* Imports never pollute the global namespace
* Core helpers like `println`, `len`, and `read` are global; most utilities live in modules

---

## 3. Variables and Control Flow

µ is dynamically typed and expression-oriented.

```mu
x := 10

if x > 5 {
    println("x is big")
} else {
    println("x is small")
}
```

* `:=` declares a variable
* `=` assigns to an existing variable
* `if` is an expression (it yields a value, though you don’t have to use it)

Loops use a single construct:

```mu
i := 0
while i < 3 {
    println(i)
    i = i + 1
}
```

---

## 4. Comments

µ supports both single-line and multi-line (block) comments. A shebang line
starting with `#!` is allowed only as the very first line in a source file and
is treated as a comment.

Single-line comments start with `//` and run to the end of the line:

```mu
// this is a full-line comment
x := 10 // this is an end-of-line comment
println(x)
```

Multi-line comments are written with `/*` and `*/` and can span lines:

```mu
/*
   block comments can span
   multiple lines
*/
println("comments are ignored")
```

---

## 5. Functions and Closures

Functions are first-class values.

```mu
fn add(a, b) {
    return a + b
}

println(add(2, 3))
```

Closures work as you’d expect. Captured variables are mutable in stage-0,
so simple counters can update their captured state directly:

```mu
fn make_counter() {
    n := 0
    return fn() {
        n = n + 1
        return n
    }
}

counter := make_counter()
println(counter()) // 1
println(counter()) // 2
```

---

## 6. Errors Are Values

µ does **not** use exceptions.

Errors are ordinary values that you can inspect and handle.

```mu
data := read("missing.txt")
if type(data) == "ERROR" {
    println("failed to read file:", data)
}
```

This makes error handling:

* explicit
* composable
* predictable

---

## 7. Lists and Maps

µ has two built-in collection types.

### Lists

```mu
xs := [1, 2, 3]
println(xs[0])    // 1
println(len(xs))  // 3
```

### Maps

```mu
user := {
    "name": "alice",
    "age":  42,
}

println(user["name"])
```

Dot access is supported as sugar for maps:

```mu
println(user.name)
```

---

## 8. Objects Are Just Maps + Functions

µ doesn’t have classes.

Instead, you compose data and behavior directly:

```mu
rect := {
    "w": 10,
    "h": 5,
    "area": fn(self) {
        return self.w * self.h
    },
}

println(rect.area())
```

Simple, explicit, and flexible.

---

## 9. Bytecode VM or Native Code

µ supports **bytecode VM** and **native compilation**. The default is bytecode VM, which is fast and easy to debug.

You've been running the example program in the VM. You can switch to native compilation by adding the `-B` and `-o` flags to the command line to build a native executable (use `-p os/arch` to cross-compile):

```shell
$ mu -B -o hello hello.mu
$ mu -B -p linux/amd64 -o hello hello.mu
$ ./hello
Hello, µ!
```

## 11. Cooperative Concurrency

mu provides **cooperative tasks** and **channels** for concurrent workflows. Tasks yield only at blocking operations, keeping execution deterministic.

```mu
fn worker(out, n) {
    i := 1
    total := 0
    while i <= n {
        total = total + i
        i = i + 1
    }
    send(out, total)
}

ch := chan()
task(worker, ch, 10)
println(recv(ch)) // 55
```

Use `poll(ch)` and `push(ch, value)` for non-blocking operations. See `docs/Specification.md` for full semantics.

µ can run code in two ways:

* **Bytecode VM** (default): fast startup, easy debugging
* **Native compilation**: better performance, easy deployment

Typical workflow:

* develop on the VM
* compile to native when you care about speed

Same language. Same semantics.

---

## 12. What to Explore Next

* Browse the `examples/` directory
* Read the standard library modules (`lib/`)
* Try `mu -fmt` to format code (prints to stdout; add `-w` to rewrite files)
* Try `mu -test` to run tests
* Read the language specification if you’re curious about internals

---

## Final Thoughts

µ is small on purpose.

If you enjoy languages that are:

* explicit
* predictable
* dynamic but disciplined
* small enough to understand end-to-end

…then you’re in the right place.

Happy hacking.
