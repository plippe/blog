---
tags: ["rust"]
---

Let's talk about recursion and the options available in Rust.

# Recursion
What is recursion

```rust
fn fib_recursion(nth: u64) -> u64 {
    match nth {
        0 => 0,
        1 => 1,
        nth => fib_recursion(nth - 1) + fib_recursion(nth - 2)
    }
}
```

Recursion isn't required, but can lead to simpler solutions.

```rust
fn fib_iteration(nth: u64) -> u64 {
    if nth == 0 { 0 }
    else {
        let mut n = 1;
        let mut n_1 = 0;

        for _ in 1..nth {
            let old_n = n;

            n = n + n_1;
            n_1 = old_n;
        }

        n
    }
}
```

# Tail recursion
What is tail call recursion

Rust doesn't have tail call optimization, but has room to support it in the future, `become`

Bellow are a few solutions until then


# Trampolining
