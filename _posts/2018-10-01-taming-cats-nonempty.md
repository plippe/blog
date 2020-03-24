---
layout: post
title: Taming cats - NonEmpty

tags: ["scala", "cats"]
---

> *Cats is a library which provides abstractions for functional programming in the [Scala programming language](https://scala-lang.org/). The name is a playful shortening of the word category.*

As [I said previously]({% post_url 2018-09-01-taming-cats-equality %}), Scala has a few issues, and [cats](https://typelevel.org/cats/) offer some solutions. To avoid being overwhelmed, I will only be looking at NonEmpty in this post.

Scala has a wonderful collection library, but some of its methods are partial functions. The `head` method, for example, will throw an error when it is called on an empty list.

```scala
scala> List.empty[Int].head
java.util.NoSuchElementException: head of empty list
  at scala.collection.immutable.Nil$.head(List.scala:428)
  at scala.collection.immutable.Nil$.head(List.scala:425)
  ... 28 elided
```

This is why you should always use `headOption`, but many methods don’t have safe alternatives.

```scala
scala> implicit class ListOps[T](value: List[T]) {
     |   def maxOption(implicit ord: Ordering[T]) = value match {
     |     case Nil => None
     |     case _ => Some(value.max)
     |   }
     | }

scala> List(1, 2, 3).maxOption
res0: Option[Int] = Some(3)

scala> List.empty[Int].maxOption
res1: Option[Int] = None
```

These total functions guaranty the code won’t throw errors. They help build better code, but it takes commitment to use them over the other. Furthermore, without proper warning, it is easy to use the partial function without knowing.

To avoid crashing the application unexpectedly, lists could be implemented similarly to `Option`. `List` would define an interface for `EmptyList`, and `NonEmptyList`.

```scala
trait OptList[T] {
  def headOption: Option[T]
}

class EmptyList[T] extends OptList[T] {
  def headOption = None
}

private class NonEmptyList[T](val toList: List[T])
    extends OptList[T] {
  def headOption = toList.headOption
  def head = toList.head
}
```

A helper must be used as the class’ constructor is private.

```scala
object NonEmptyList {
  def fromList(list: List[T]) = list match {
    case Nil => new EmptyList
    case list => new NonEmptyList(list)
  }
}
```

`NonEmptyList` adds safety, but also allow methods to require non empty lists.

```scala
def average(list: NonEmptyList[Int]) = {
  list.sum / list.length // divide by 0 impossible
}
```

This added type safety can be found in [cats](https://typelevel.org/cats/datatypes/nel.html). It has many implementations like `NonEmptyList`, and `NonEmptyVector`. If you can get used to the API, you will avoid a lot of silly runtime errors.

```scala
import cats.data.NonEmptyList

assert(NonEmptyList.fromList(List.empty).isEmpty)
assert(NonEmptyList.fromList(List(1, 2, 3)).nonEmpty)
```
