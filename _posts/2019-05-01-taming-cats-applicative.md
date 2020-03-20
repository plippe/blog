---
layout: post
title: Taming cats - Applicative

tags: ["scala", "cats", "typeclass"]
---

Continuing with scary names, Applicative is next.

## Applicative

Cats define the [Applicative typeclass with 250 lines of code](https://github.com/typelevel/cats/blob/master/core/src/main/scala/cats/Applicative.scala). Those, for learning purposes, can be shrunk to the following 4.

```scala
trait Applicative[F[_]] extends cats.Functor[F] {
  def pure[A](x: A): F[A]
  def ap[A, B](ff: F[A => B])(fa: F[A]): F[B]
}
```

The first piece of information is about the type. Applicatives are higher-kinded types. They wrap around another type like`Option[_]`, or `List[_]`.

Next, Applicatives extend [Functors]({{ post_url 2019-04-01-taming-cats-functor }}). This gives them the `map` function, but forces them to obey the identity, and composition laws.

Finally, Applicatives have two abstract functions. The first, `pure`, is the easiest of the two. Similar to a constructor, it wraps a value of type `A` in a new `F[A]`. The second, `ap`, executes code within the context of `F[_]`. This allows to build functions like the following.

```scala
def tuple2[A, B](fa: F[A], fb: F[B]): F[(A, B)] =
  ap(map(fa)(a => (b: B) => (a, b)))(fb)
```

`tuple2`, also called `product`, combines the content of two `F[_]` into a `tuple`. `tuple3`, `tuple4`, up to `tuple22`, allow to combine more.

## Laws
On top of the Functor laws, Applicatives have two they must obey.

### Homomorphism
The result of a function should always be the same whether it is obtained inside, or outside of the `F[_]` context.

```scala
val f = (a: Int) => a + 1

assert(Option(f).ap(Option(1)) == Option(f(1)))
assert(List(f).ap(List(1)) == List(f(1)))
```

### Interchange
Like for multiplication, the order of the arguments shouldn’t affect the results.

```scala
val f = (a: Int) => a + 1

assert(
  Option(f).ap(Option(1)) ==
  Option((f: Int => Int) => f(1)).ap(Option(f)))

assert(
  List(f).ap(List(1)) ==
  List((f: Int => Int) => f(1)).ap(List(f)))
```

## Example
Leaving the theoretical behind, the following example should highlight the benefits of Applicatives.

Invoices are documents given with purchases of goods, and services. They contain user details, a billing address, and information on the purchased items.

```scala
import cats.data.NonEmptyList
import java.util.UUID

type Quantity = Int
type Price = BigDecimal

case class User(id: UUID)
case class Address(id: UUID)
case class Item(id: UUID)
case class Invoice(
  id: UUID,
  user: User,
  billing: Address,
  items: NonEmptyList[(Item, Quantity, Price)])
```

To limit duplication, a factory creates invoices out of identifiers.

```scala
object InvoiceFactory {
  def fromIdentifiers(
    id: UUID,
    userId: UUID,
    billingId: UUID,
    itemIds: NonEmptyList[(UUID, Quantity, Price)]
  ): Invoice = ???
}
```

Without dependency injection, this constructor becomes very rigid. A better approach is to give it readers.

```scala
trait UsersReader {
  def fromIdentifier(id: UUID): User
}

trait AddressesReader {
  def fromIdentifier(id: UUID): Address
}

trait ItemsReader {
  def fromIdentifier(id: UUID): Item
}

class InvoiceFactory(
  usersReader: UsersReader,
  billingsReader: BillingsReader,
  itemsReader: ItemsReader) {
  def fromIdentifiers(
    id: UUID,
    userId: UUID,
    billingId: UUID,
    itemIds: NonEmptyList[(UUID, Quantity, Price)]
  ): Invoice = ???
}
```

Those readers can access the information from a variety of sources. Some would be pure, while others could throw errors. To represent this, results are wrapped in a type.

Enforcing a particular effect, like `Option`, `Either`, or `Future`, would be limiting. A higher-kinded type is the perfect solution.

```scala
trait UsersReader[F[_]] {
  def fromIdentifier(id: UUID): F[User]
}

trait AddressesReader[F[_]] {
  def fromIdentifier(id: UUID): F[Address]
}

trait ItemsReader[F[_]] {
  def fromIdentifier(id: UUID): F[Item]
}

class InvoiceFactory[F[_]](
  usersReader: UsersReader[F],
  billingsReader: BillingsReader[F],
  itemsReader: ItemsReader[F]) {
  def fromIdentifiers(
    id: UUID,
    userId: UUID,
    billingId: UUID,
    itemIds: NonEmptyList[(UUID, Quantity, Price)]
  ): F[Invoice] = ???
}
```

Without specifying more information about `F[_]`, it is impossible to define `fromIdentifiers`. An `F[Invoice]` can’t be constructed with `F[User]`, `F[Address]`, and `List[F[Item]]`.

This is where Applicatives come into play.

```scala
import cats.Applicative
import cats.implicits._

class InvoiceFactory[F[_]: Applicative](
  usersReader: UsersReader[F],
  addressesReader: AddressesReader[F],
  itemsReader: ItemsReader[F]) {
def fromIdentifiers(
    id: UUID,
    userId: UUID,
    billingId: UUID,
    itemIds: NonEmptyList[(UUID, Quantity, Price)]
  ): F[Invoice] = {
    val fUser = usersReader.fromIdentifier(userId)
    val fBilling = addressesReader.fromIdentifier(billingId)
    val fItems = itemIds.traverse { case (id, q, p) =>
      itemsReader.fromIdentifier(id).map((_, q, p))
    }
    (fUser, fBilling, fItems).mapN(Invoice(id, _, _, _))
  }
}
```

Applicative solved our problem with `.traverse`, and `.mapN`.

`.traverse` executes, for elements in a [`Traversable`](https://typelevel.org/cats/api/cats/Traverse.html), a function that returns an Applicative. Instead of returning `Traversable[F[_]]`, like `.map`, it returns `F[Traversable[_]]`.

```scala
scala> import cats.implicits._
import cats.implicits._

scala> List(1, 2, 3).traverse(i => i.some)
res0: Option[List[Int]] = Some(List(1, 2, 3))
```

Beware, `.traverse` stops at the first “error”.

```scala
scala> List(1, 2, 3).traverse { i => println(i); none[Int] }
1
res1: Option[List[Int]] = None
```

`.mapN` is a helper for `tupled`, and then `map`. It composes Applicatives into an tuple, and maps over it.

```scala
scala> (1.some, 2.some, 3.some).mapN {
|   case (a, b, c) => a + b + c
| }
res2: Option[Int] = Some(6)
```

Again, `.mapN` will return the first “error” it encounters.

```scala
scala> (1.some, 2.some, none[Int]).mapN {
|   case (a, b, c) => a + b + c
| }
res3: Option[Int] = None
```

With the generic `InvoiceFactory` defined the readers would be next. For them to be compatible, they would have to return an Applicative. This would allow test instances to return [`Id`](https://typelevel.org/cats/api/cats/index.html#Id[A]=A), and production ones `Future`, or similar.

---

Applicatives are great abstractions. They permitted me to define a flexible factory that returns only successful results. Nothing to be scared about.
