#!./bin/mu

// Demonstrate a variadic parameter and how the extra arguments are iterated.
// Describe how to declare a variadic parameter and inspect the values that arrive.
fn describeExtras(action, rest...) {
    println(action, "received", len(rest), "extra argument(s)")
    if len(rest) == 0 {
        println("  (no extras)")
        return
    }

    i := 0
    while i < len(rest) {
        println("  extra[", i, "] =", rest[i])
        i = i + 1
    }
}

describeExtras("collect numbers", 1, 2, 3, 5)
describeExtras("still collecting")
