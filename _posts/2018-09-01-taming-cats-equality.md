---
title: Taming Cats - Equality
tags: ["scala", "cats"]
---

> *Cats is a library which provides abstractions for functional programming in the [Scala programming language](https://scala-lang.org/). The name is a playful shortening of the word category.*

[Cats](https://typelevel.org/cats/) is a huge library that offers a lot of value. Instead of listing all its features, I will look into Scala’s shortcomings, and see how Cats can help. Hopefully, you will learn a few things along the way, and maybe include Cats in your next projects.

This time, I will look at equality.

Scala is a strongly typed language. In short, the compiler, `scalac`, checks the code for errors. The compilation will fail if any issue is found.

A common compilation error is a `type mismatch`.

```scala
scala> val foo: Int = "1"
<console>:11: error: type mismatch;
 found   : String("1")
 required: Int
       val foo: Int = "1"
```

The compiler highlights a variable assignment that can’t work. It requires a particular type, `Int` in our example, but finds another, `String`. The error message guides us to solve the issue.

The compiler enforces type safety in most places, but equality isn’t one. If we compare an `Int` to a `String`, the compiler will allow it, and return `false`. A warning is sometimes displayed.

```scala
scala> 1 == "1"
<console>:12: warning: comparing values of types Int and String using `==' will always yield false
       1 == "1"
         ^

scala> "1" == 1
res0: Boolean = false
```

The code is valid as `==` is defined in the `Any` class. It compares one `Any` to another. It compiles, but I doubt anyone would intentionally want a comparator that always return `false`.

A more restrictive equality statement would help avoid errors.

```scala
scala> def ===[T](a: T, b: T): Boolean = a == b
$eq$eq$eq: [T](a: T, b: T)Boolean

scala> ===[Int](1, 1)
res0: Boolean = true

scala> ===[Int](1, "1")
<console>:13: error: type mismatch;
 found   : String("1")
 required: Int
       ===[Int](1, "1")
```

Our `===` method only compares variables of type `T`. The compilation fails if the types don’t match. This version requires an explicit value for `T` otherwise type inference will use `Any`.

```scala
scala> ===(1, "1")
res2: Boolean = false
```

No one wants to specify `T`, and omitting it doesn’t solve the issue. A proper solution must infer `T` only from one of the variables.

```scala
scala> class Eq[T](a: T) {
     |   def ===(b: T) = a == b
     | }
defined class Eq

scala> new Eq(1) === 1
res0: Boolean = true

scala> new Eq(1) === "1"
<console>:13: error: type mismatch;
 found   : String("1")
 required: Int
       new Eq(1) === "1"
```

Our `Eq` class works without the need to specify `T`, but you must create an instance. Scala’s [implicit conversion](https://docs.scala-lang.org/tour/implicit-conversions.html) can do that for us.

```scala
scala> implicit class Eq[T](a: T) {
     |   def ===(b: T) = a == b
     | }
defined class Eq

scala> 1 === 1
res0: Boolean = true

scala> 1 === "1"
<console>:13: error: type mismatch;
 found   : String("1")
 required: Int
       1 === "1"
```

The above works great in the Scala REPL, but requires a bit more work to be used in a Scala project. The implicit class must be defined in an object, and imported before `===` can be used.

```scala
// src/main/scala/Main.scala
object EqSyntax {
  implicit class Eq[T](a: T) {
    def ===(b: T) = a == b
  }
}

import EqSyntax._

object Main extends App {
  1 === 1
}
```

All it takes is 5 lines of code, and an import statement to safely compare two variables. It solves the unsafe `==`, but using it in production requires more work, tests, releases, ...

Instead of building, and maintaining a full blow project, use [Cats’ `Eq`](https://typelevel.org/cats/typeclasses/eq.html). It offers a much more flexible API, and greatly reduces the risk of always false equality statements.

```scala
import cats.implicits._
assert(1 === 1)
```
