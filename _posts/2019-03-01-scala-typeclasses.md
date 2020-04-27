---
tags: ["scala", "typeclass"]
---

Scala supports supertypes, and typeclasses. Those allowed me to write a generic `maxOption` function, in a [previous article]({{ site.baseurl }}{% post_url 2019-02-01-scala-generics-and-typeclasses %}). With the overview out of the way, I will show in more details how typeclasses can add real value to your project.

I am going to code a comma separated value writer. CSV is a very common format. I am not creating anything new, nor better, but I will definitely make it interesting.

In case you might not know, there is an [RFC for the CSV format](https://tools.ietf.org/html/rfc4180). As the starts highlights, this isn’t a standard, but I will follow it anyways. This give me constraints to focus on my goal instead of solving every possible scenario.

The RFC requirements can be shrunk down to the following bullet points:
- One record per line
- Optional header line
- One, or more fields per line
- Same amount of fields on each line
- Fields separated by commas
- Fields optionally wrapped in double quotes
- Fields with special characters wrapped in double quotes
- Double quotes escape double quotes

I will start with a simple implementation that ticks all the boxes.

```scala
val specialChars = List(',', '"', '\n')

def formatField(field: String): String = {
  // escape double quotes
  val escapedField = field.replaceAll("\"", "\"\"")

  // wrap in quotes if needed
  if(escapedField.intersect(specialChars).isEmpty) escapedField
  else s""""${escapedField}\""""
}

def writeFields(fields: List[String]): String =
  fields
    .map(formatField)
    .mkString(",")

def writeRows(rows: List[List[String]]): Either[String, String] = {
  val emptyRow = rows.exists(_.isEmpty)

  val sameRowLength = rows
    .map(_.length)
    .distinct
    .length > 1

  if(emptyRow) Left("Rows can't be empty")
  else if(sameRowLength) Left("Rows must have the same size")
  else Right(rows.map(writeFields).mkString("\n"))
}
```

This version is quite small, and perfectly handles `String`s. The issue is that other types exists.

I will focus on the `formatField` function. The others aren’t perfect, but limiting the formatting to `String`s is an obvious issue. The function should be able to format any argument.

`Any` does offer a `toString` method. It works wonders for debugging, but I wouldn’t use it for anything else. Another option is supertypes, but built in types, like `Int`, and `List`, couldn’t extend it. The easiest solution is a typeclass.

A typeclass is defined by a trait with a type argument. It can have one, or more functions to implement.

```scala
trait Show[A] {
  def show(value: A): String
}
```

Implementations should be written in the companion object. They are defined as `implicits` to remove the need of explicitly calling them.

```scala
object Show {
  implicit val stringToShow = new Show[String] {
    def show(value: String) = value
  }

  implicit val intToShow = new Show[Int] {
    def show(value: Int) = value.toString
  }
}
```

Types with type arguments are defined as functions. This avoids the need to implement all possible combinations of types.

```scala
object Show {

  ...

  implicit def optionToShow[A: Show] = new Show[Option[A]] {
    def show(value: Option[A]) = value.fold("None") { a =>
      val showA = implicitly[Show[A]]
      s"Some ${showA.show(a)}"
    }
  }

  implicit def listToShow[A: Show] = new Show[List[A]] {
    def show(value: List[A]) = {
      val showA = implicitly[Show[A]]
      value.map(showA.show).mkString(", ")
    }
  }

  ...

}
```

If you dislike the use of `implicitly`, you can avoid it by using an implicit parameter instead of a type bound. The former is just syntactic sugar for the latter.

```scala
def optionToShow[A](implicit showA: Show[A]) = ???
```

With the typeclass defined, and a few implementations too, I can go back to the example.

As I said before, I will focus on `formatField`. It shouldn’t be limited to `String`s, but any type with a `Show` implementation.

```scala
def formatField[A: Show](a: A): String = {
  val field = implicitly[Show[A]].show(a)

  val escapedField = field.replaceAll("\"", "\"\"")

  if(escapedField.intersect(specialChars).isEmpty) escapedField
  else s""""${escapedField}\""""
}
```

This new version is a step in the right direction, but it’s still quite rough around the edges. Some simple additions can improve the use of the typeclase. A helper can hide the use of `implicitly`, and an implicit conversion can improve the syntax.

```scala
object Show {

  ...

  def apply[A: Show] = implicitly[Show[A]]
  // OR
  // def apply[A](implicit showA: Show[A]) = showA

  implicit class ShowOps[A: Show](a: A) {
    def show = Show[A].show(a)
  }

  ...

}

def formatField[A: Show](field: A): String = {
  val escapedField = field.show.replaceAll("\"", "\"\"")

  if(escapedField.intersect(specialChars).isEmpty) escapedField
  else s""""${escapedField}\""""
}
```

This final version of `formatField` is a clear improvement over the first. It creates valid CSV fields for any given `Show`. Some boilerplate could still be removed, but the heavy lifting is done.

We reach the end with a few pieces of our CSV writer. They don’t align perfectly, `Show` wasn’t really meant for this, but the journey was still worth it. We wrote a typeclass, a few implementations, and some helpers. This will greatly help us understand commonly used typeclasses in cats.
