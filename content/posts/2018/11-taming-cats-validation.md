---
title: "Taming cats - Validation"
date: 2018-11-01

series: "taming cats"
tags: ["scala", "cats"]
---

> *Cats is a library which provides abstractions for functional programming in the [Scala programming language](https://scala-lang.org/). The name is a playful shortening of the word category.*

There are a few ways of informing users about errors. The simplest way is to raise a `Throwable`, but that can be dangerous. A better way is to bubble up errors.

Scala has a few types to represent distinct possibilities. The most obvious one is `Option`. `Option` represent optional values, who would have guessed. They are great for binary type of processes, but lack flexibility.

```scala
def validatePhoneNumber(value: String)
  : Option[String] = None

def validateLandLine(value: String)
  : Option[String] = None

def validateCountry(value: String, country: String)
  : Option[String] = None

val phoneNumber: String = "000 000 0000"
val validIrishLandLinePhoneNumber: Option[String] =
  validatePhoneNumber(phoneNumber)
    .flatMap(validateLandLine)
    .flatMap(validatePhoneNumberCountry(_, "IE"))
```

An empty `validIrishLandLinePhoneNumber` wouldn’t inform the user of the issue. Is the number valid ? Is it a land line number ? Or, is it an Irish number ?

`Either` offers a more flexible alternative. With a `Left`, and a `Right`, it can hold an explanation for the failed process.

```scala
sealed trait PhoneNumberValidation extends Throwable
case object NotValidNumber extends PhoneNumberValidation
case object NotLandLine extends PhoneNumberValidation
case object NotFromCountry extends PhoneNumberValidation

type Validated[T] = Either[PhoneNumberValidation, T]

def validatePhoneNumber(value: String)
  : Validated[String] = Left(NotValidNumber)

def validateLandLine(value: String)
  : Validated[String] = Left(NotLandLine)

def validateCountry(value: String, country: String)
  : Validated[String] = Left(NotFromCountry)

val phoneNumber: String = "000 000 0000"
val validIrishLandLinePhoneNumber:
  Either[PhoneNumberValidation, String] =
    validatePhoneNumber(phoneNumber)
      .flatMap(validateLandLine)
      .flatMap(validatePhoneNumberCountry(_, "IE"))
```

`Either` is like a simplified `Try`, or `Future`. It doesn’t offer any fancy error catching, nor multi threading, but offers a clear distinction between success, and failure.

The results of the validation methods are currently composed sequentially. In other words, the validation stops at the first error, and returns it. This can create a very painful user experience. No one wants to submit a form over, and over again without knowing when the process will succeed.

```
phone number isn't valid

...

phone number isn't for a land line

...

phone number isn't for an Irish number

...

(╯°□°）╯︵ ┻━┻
```

Parallel composition allow many validations to run independently. Their errors are centralised in a type that can contain one, or more element. A simple solution is `List`, but a more precise one is [NonEmptyList]({{< ref "posts/2018/10-taming-cats-nonempty.md" >}}). If there is a reason to return `Left`, there should always be an error with it.

```scala
type ValidatedNonEmptyList[T] = Either[NonEmptyList[Throwable], T]

def validatePhoneNumber(value: String)
  : ValidatedNonEmptyList[String] =
    Left(NonEmptyList.fromList(List(NotValidNumber))

def validateLandLine(value: String)
  : ValidatedNonEmptyList[String] =
    Left(NonEmptyList.fromList(List(NotLandLine))

def validateCountry(value: String, country: String)
  : ValidatedNonEmptyList[String] =
    Left(NonEmptyList.fromList(List(NotFromCountry))
```

Once validated, `Either`s should be composed. The result should contain all the values in `Right`, or at least one error in `Left`.

```scala
def tuple3[A, B, C](
  va: ValidatedNonEmptyList[A],
  vb: ValidatedNonEmptyList[B],
  vc: ValidatedNonEmptyList[C],
): ValidatedNonEmptyList[(A, B, C)] = {
  (va, vb, vc) match {
    case (Right(a), Right(b), Right(c)) => Right((a, b, c))
    case (Left(a) , Left(b) , Left(c) ) => Left(a ++ b ++ c)
    case (Left(a) , Left(b) , _       ) => Left(a ++ b     )
    case (Left(a) , _       , Left(c) ) => Left(a ++      c)
    case (Left(a) , _       , _       ) => Left(a          )
    case (_       , Left(b) , Left(c) ) => Left(     b ++ c)
    case (_       , Left(b) , _       ) => Left(     b     )
    case (_       , _       , Left(c) ) => Left(          c)
  }
}
```

`tuple3` is a simple function with a pattern match. It has N power of two case statements, meaning that at most, `tuple22`, has 484 possibilities. Writing, or generating, all the statements isn’t a proper solution.

Once again, Cats offers a better alternative. [`Validated`](https://typelevel.org/cats/datatypes/validated.html) is a trait with a `Valid`, and `Invalid` implementation. It is like `Either`. The `ValidatedNel` is a variant to handle non empty lists of errors. It also offers two types of composition, `andThen` for sequential, and `tupled` for parallel. Use that instead of building your own solution.

```scala
import cats._
import cats.data._
import cats.implicits._

def validatePhoneNumber(value: String)
  : ValidatedNel[Throwable, String] =
    Validated.invalidNel(NotValidNumber)

def validateLandLine(value: String)
  : ValidatedNel[Throwable, String] =
    Validated.invalidNel(NotLandLine)

def validateCountry(value: String, country: String)
  : ValidatedNel[Throwable, String] =
    Validated.invalidNel(NotFromCountry)

val phoneNumber: String = "000 000 0000"
val validIrishLandLinePhoneNumber
  : ValidatedNel[Throwable, (String, String, String)] =
    (
      validatePhoneNumber(phoneNumber),
      validateLandLine(phoneNumber),
      validateCountry(phoneNumber, "IE")
    ).tupled
```
