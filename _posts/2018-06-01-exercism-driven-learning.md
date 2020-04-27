---
tags: ["exercism", "rust"]
---

I often get distracted by new things to study. Some are rather old, Erlang, Haskell, and others are fairly new, PureScript, Rust. I am not looking to master these skills, but at least understand how to use them.

I always find mountains of theoretical resources like books and videos. These allow me to hit the floor running, but I rarely remember most of it. I need a more hands-on approach to actually learn things.

I used to build clones of well know services. This was useful to learn architectures and frameworks, but I am passed this now. My new approach is [Exercism](https://exercism.io/) driven learning.

Exercism is a service that hosts programming exercises and test cases. There are many alternatives, like [CodinGame](https://www.codingame.com/), and [HackerRank](https://www.hackerrank.com/). I picked Exercism, but any other would work.

To get started with Exercism you need to [create an account](https://exercism.io/login). Next, you should install their [command-line tool](https://exercism.io/getting-started), and [configure it](https://exercism.io/account/key). This will allow you to fetch the exercises, and submit your solutions. If you prefer, all their exercises are available on [GitHub](https://github.com/exercism).

Let's use Exercism, and solve their first Rust exercise.

```sh
$ exercism fetch rust

Not Submitted:     1 problem
rust (Hello World) /Users/pvinchon/exercism/rust/hello-world

New:               1 problem
rust (Hello World) /Users/pvinchon/exercism/rust/hello-world

unchanged: 0, updated: 0, new: 1
```

Let's have a look at what was just downloaded.

``` sh
$ cd /Users/pvinchon/exercism/rust/hello-world
$ ls -l
total 24
-rw-r--r--  1 pvinchon  staff    49 16 May 23:37 Cargo.toml
-rw-r--r--  1 pvinchon  staff  2166 16 May 23:37 GETTING_STARTED.md
-rw-r--r--  1 pvinchon  staff  2238 16 May 23:37 README.md
drwxr-xr-x  3 pvinchon  staff    96 16 May 23:37 src
drwxr-xr-x  3 pvinchon  staff    96 16 May 23:37 tests
```

This problem, like all other Exercism Rust problems, is a [Cargo](https://doc.rust-lang.org/stable/cargo/) project. It follows [clear conventions](https://github.com/exercism/rust#contributing-a-new-exercise), allowing you to focus on your solution, and not on how to run the tests.

```sh
$ cargo test
Compiling hello-world v1.1.0 (file:///Users/pvinchon/exercism/rus...
 Finished dev [unoptimized + debuginfo] target(s) in 0.79 secs
  Running target/debug/deps/hello_world-4625680145752437
running 0 tests
test result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 0 fil...
    Running target/debug/deps/hello_world-a78f9d761c0415c2
running 1 test
test test_hello_world ... FAILED
failures:
---- test_hello_world stdout ----
        thread 'test_hello_world' panicked at 'assertion failed: ...
  left: `"Hello, World!"`,
 right: `"Goodbye, World!"`', tests/hello-world.rs:5:5
note: Run with `RUST_BACKTRACE=1` for a backtrace.
failures:
    test_hello_world
test result: FAILED. 0 passed; 1 failed; 0 ignored; 0 measured; 0...
error: test failed, to rerun pass '--test hello-world'
```

A test is currently failing. The goal is to make sure all tests pass. In this scenario, the solution isn’t hard to find.

```rust
// In src/lib.rs
// The &'static here means the return type has a static lifetime.
// This is a Rust feature that you don't need to worry about now.
pub fn hello() -> &'static str {
    // Replace "Goodbye" by "Hello"
    "Hello, World!"
}
```

Once `src/lib.rs` has been updated, we can run the tests again.

```sh
$ cargo test
Compiling hello-world v1.1.0 (file:///Users/pvinchon/exercism/rus...
 Finished dev [unoptimized + debuginfo] target(s) in 0.0 secs
  Running target/debug/deps/hello_world-4625680145752437
running 0 tests
test result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 0 fil...
     Running target/debug/deps/hello_world-a78f9d761c0415c2
running 1 test
test test_hello_world ... ok
test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 0 fil...
     Doc-tests hello-world
running 0 tests
test result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 0 fil...
```

One test has passed, and none have failed or been ignored. Tests are ignored if they have the `#[ignore]` attribute. To run ignored tests, manually remove the attribute, or run `cargo test -- --ignored`.

To fetch the next exercise, we must first submit our solution.

```sh
$ exercism submit src/lib.rs
Your rust solution for hello-world has been submitted.

Programmers generally spend far more time reading code than writing it. To benefit the most from this exercise, find 3 or more submissions that you can learn something from, have questions about, or have suggestions for. Post your thoughts and questions in the comments, and start a discussion. Consider revising your solution to incorporate what you learn.

Yours and others' solutions to this problem:
http://exercism.io/tracks/rust/exercises/hello-world

$ exercism fetch

Not Submitted:        1 problem
rust (Gigasecond) /Users/pvinchon/exercism/rust/gigasecond

New:                  1 problem
rust (Gigasecond) /Users/pvinchon/exercism/rust/gigasecond

unchanged: 0, updated: 0, new: 1
```

There are currently [82 problems for Rust](https://exercism.io/tracks/rust/exercises), enough to keep you occupied for days. [Other languages](https://exercism.io/tracks) are available too if you prefer.

Overall Exercism is a great tool to learn new languages or improve your skills. I hope you will find use for it.
