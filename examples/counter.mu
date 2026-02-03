// Closure example showing how captured mutable state can power a simple counter generator.

fn makeCounter() {
    n := 0
    return fn() {
        n = n + 1
        return n
    }
}

c := makeCounter()
println(c())
println(c())
