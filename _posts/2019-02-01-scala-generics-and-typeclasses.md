---
layout: post
title: Scala generics and typeclasses

tags: ["scala", "typeclass"]
---

After a few months of [writing about Cats](/series/taming-cats.html), it is great to take a small break. This pause isn’t to start anything new, but to build foundations for the upcoming posts. If you are looking to learn about those scary FP words, you will need to understand what is below.

Chances are, if you are looking to learn about cats, you will find the start quite easy. Hopefully, I can make the end easy too.

When you write code, it is a good idea to aim for generic logic. You never know when you might need to solve another very similar problem.

The simplest way to avoid duplication is by writing functions. They allow to execute many times the same logic. This logic should be based on input arguments, and return output ones.

```scala
def maxOption(elements: List[Int]): Option[Int] = {
  if(elements.isEmpty) None
  else Some(elements.max)
}
```

The above function is quite simple. It finds the largest element in a `List[Int]`, or returns `None`. It is a safe alternative to the built in one.

Our `maxOption` function is a great way to avoid redefining the if statement, but it isn’t very generic. It only works with `List[Int]`.

```scala
def maxOption(elements: Array[Float]): Option[Float] = ???
def maxOption(elements: Set[String]): Option[String] = ???
def maxOption(elements: Vector[Boolean]): Option[Boolean] = ???
...
```

It would be silly to define the function for every combination of types. This can be avoided with abstraction.

A supertype represent functionalities that are inherited by another type. This is often represented with animals, shapes, or vehicles.

```scala
// https://docs.oracle.com/javase/tutorial/java/IandI/subclasses.html

class Bicycle(
  cadence: Int,
  gear: Int,
  speed: Int,
)

class MountainBike(
  cadence: Int,
  gear: Int,
  speed: Int,
  seatHeight: Int,
) extends Bicycle(cadence, gear, speed)
```

`Array`, `List`, and `Set` have many supertypes in common. Picking the smallest common denominator would increase compatibility with other types.

The only need for `maxOption` is for the supertype to implement `isEmpty`, and `max`. Those can be found in the [`GenTraversableOnce`](https://www.scala-lang.org/api/2.12.6/scala/collection/GenTraversableOnce.html) trait.

```scala
import scala.collection.GenTraversableOnce

def maxOption(elements: GenTraversableOnce[Int]): Option[Int] = {
  if(elements.isEmpty) None
  else Some(elements.max)
}
```

`GenTraversableOnce` has over 350 subclasses. By using it instead of `List`, we increased compatibility, but `Int` is still very limiting.

`Int`, like `String`, `Boolean`, and many other types, only extend `Any`, and `AnyVal`. Those types can’t be compared to identify the maximum value.

```scala
def maxOption(elements: GenTraversableOnce[Any]): Option[Any] = ???
```

Instead of using a supertype, `Int` should be implemented as a generic. This allows the caller to specify any type, but it also means the function must handle all types.

```scala
def maxOption[A](elements: GenTraversableOnce[A]): Option[A] = ???
```

Once again this seems like the wrong approach, until you attempt to compile the code.

```scala
scala> import scala.collection.GenTraversableOnce
import scala.collection.GenTraversableOnce

scala> def maxOption[A](elements: GenTraversableOnce[A]) = {
|   if(elements.isEmpty) None
|   else Some(elements.max)
| }
<console>:14: error: No implicit Ordering defined for A.
         else Some(elements.max)
                            ^
```

The compiler raises an error. It doesn’t know how to identify a maximum `A`, but it could with an `implicit Ordering`, [`Ordering`](https://www.scala-lang.org/api/2.12.x/scala/math/Ordering.html) is a trait used to sort elements. It allows the compiler to identify the `max` value.

The function can take `Ordering` as an extra argument

```scala
def maxOption[A](elements: GenTraversableOnce[A])
    (implicit ord: Ordering[A]): Option[A] = {
  if(elements.isEmpty) None
  else Some(elements.max)
}
```

Or a type bound

```scala
def maxOption[A: Ordering](elements: GenTraversableOnce[A]) = {
  if(elements.isEmpty) None
  else Some(elements.max)
}
```

The second is just syntactic sugar for the first.

`Ordering` is a typeclass. Similarly to the supertype, it defines, and sometimes implement functionality. There is more to it, but I will keep that for the next post.

Lets see how `Ordering` could be used for `maxOption` if it was written for an auction company. It would need to return the highest `Bid`.

```scala
case class Bid(
  owner: String,
  amount: Float)
```

The wrong approach is to remove the generic, and replace it by `Bid`. This would work, but the function wouldn’t be generic anymore.

Instead, a new implementation of `Ordering` should be created.

```scala
implicit val bidOrdering = new Ordering[Bid] {
  def compare(x: Bid, y: Bid): Int = x.amount.compare(y.amount)
}
```

As long as the implicit is in scope, the function can be invoked with any `GenTraversableOnce[Bid]`.

Supertypes offer a simple hierarchy explanation that makes it easy for people to use. Typeclasses, with the implicits, aren’t as welcoming, but offer the same functionality, and more.

Next time, with the basics out of the way, I will focus on the more part.
