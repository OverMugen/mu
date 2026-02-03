#!/usr/bin/env mu
// Recursive Fibonacci example that highlights nested calls and basic conditionals.

fn fib(n) {
    if n < 2 {
        return n
    }
    fib(n - 1) + fib(n - 2)
}

fn main() {
  n := 35

  if len(args()) == 2 {
    n = int(args()[1])
  }

  println(fib(n))
}

main()