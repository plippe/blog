---
tags: ["rust"]
---

Rust's standard library is small. It was designed to be. This is why some functionalities appear to be missing and some snippets feel long. Let's see how extension methods can help.

## Extension methods
[Wikipedia](https://en.wikipedia.org/wiki/Extension_method) defines an extension method as "a method added to an object after the original object was compiled". In other words, it allows new methods to be implemented for existing structs and enums.

In Rust, it is done with a trait.

```rust
use core::fmt::Debug;

pub trait DebugExt: Debug {
    fn debug(&self) {
        println!("{:?}", self)
    }
}

impl<A: Debug> DebugExt for A {}
```

This silly example adds a `debug()` method to all types that implement `Debug`.

```rust
pub trait PrintlnExt {
    fn println(&self);
}

impl PrintlnExt for &str {
    fn println(&self) {
        println!("{}", self)
    }
}
```

Similarly, this one adds a `println()` method, but only for `&str`.

Both examples aren't particularly useful, but they show the idea. Below are a few more that are actually helpful.


## Into
[Cats](https://typelevel.org/cats/) is a Scala library [I covered a few times before]({{ "/hashtags/cats.html" | absolute_url}}). Unrelated to the functional programming aspect, it contains a few general-purpose extension methods. Those shave a few characters, but, more importantly, allow to read the code from left to right.

The first, [OptionIdOps](https://typelevel.org/cats/api/cats/syntax/OptionIdOps.html), is to create `Option` values.

```rust
pub trait OptionIdExt {
    fn as_some(&self) -> Option<&Self> {
        Option::Some(self)
    }

    fn into_some(self) -> Option<Self> where Self: Sized {
        Option::Some(self)
    }
}

impl<A> OptionIdExt for A {}

let _: Option<u8> = 0.into_some();
```

The second, [EitherIdOps](https://typelevel.org/cats/api/cats/syntax/EitherIdOps.html), written for Scala's `Either`, can be adapted for Rust's `Result`.

```rust
pub trait ResultIdExt {
    fn as_ok<E>(&self) -> Result<&Self, E> {
        Result::Ok(self)
    }

    fn into_ok<E>(self) -> Result<Self, E> where Self: Sized {
        Result::Ok(self)
    }

    fn as_err<T>(&self) -> Result<T, &Self> {
        Result::Err(self)
    }

    fn into_err<T>(self) -> Result<T, Self> where Self: Sized {
        Result::Err(self)
    }
}

impl<A> ResultIdExt for A {}

let _: Result<u8, &str> = 0.into_ok();
```

All these methods don't offer anything new. Their benefit comes from the extra readability. There is no longer any need to wrap a variable, a statement, or many statements in a constructor.

There is another solution to reduce nested statements.

## Pipe
The [pipe operator](https://en.wikipedia.org/wiki/Pipeline_(Unix)) is a way of listing statements instead of nesting them. The first statement runs ... first. Its output is the input of the next statement. This repeats until all statements have run.

This concept can sound complicated, but it makes code much easier to read. For example, the following bash script calls [Steam](https://store.steampowered.com/)'s API, sorts all characters, removes duplicates, and counts those that remain.

```bash
curl -s https://api.steampowered.com/ISteamApps/GetAppList/v2 |
  grep -o . |
  sort |
  uniq |
  wc -l
```

While there is no value in this script, it shows the readability of the pipe operator.

```rust
pub trait PipeIdExt {
    fn pipe<A, F>(self, f: F) -> A
    where
        Self: Sized,
        F: FnOnce(Self) -> A,
    {
        f(self)
    }
}

impl<A> PipeIdExt for A {}

"Hello, world!".pipe(|s| println!("{}", s));
```

Those few examples should allow you to implement your own extension methods.

---

As a closing note, I would like to add few words of caution. Extension methods have drawbacks. While they improve readability, they impact onboarding and maintainability. Beware of writing a DSL that needs to be taught and spaghetti code that increase coupling.

I found extension methods work best when they link an existing object to an existing method, but to each their own.
