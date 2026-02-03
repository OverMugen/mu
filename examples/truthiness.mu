// Iterate through various values to show which ones are treated as truthy or falsy.

samples := [
    false,
    nil,
    0,
    "",
    [],
    {},
    1,
    "mu",
    [1, 2, 3],
    {"lang": "mu"},
    fn() { return "fn value" }
]

i := 0
while i < len(samples) {
    v := samples[i]
    status := if v { "truthy" } else { "falsey" }
    println("value:", inspect(v), "type:", type(v), "->", status)
    i = i + 1
}
