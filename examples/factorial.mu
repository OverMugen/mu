// Compute factorial iteratively to illustrate loops, assertions, and mutable bindings.

fn fact(n) {
    assert(n >= 0, "factorial expects a non-negative integer")

    acc := 1
    i := 2
    while i <= n {
        acc = acc * i
        i = i + 1
    }

    return acc
}

println("5! =", fact(5))
println("0! =", fact(0))
