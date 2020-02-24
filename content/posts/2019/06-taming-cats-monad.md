---
title: "Taming cats - Monad"
date: 2019-06-01

series: "taming cats"
tags: ["scala", "cats", "typeclass"]
---

Third one down the list is Monad.

### Monad
The following 3 lines summarize [cats’ definition of Monad](https://github.com/typelevel/cats/blob/master/core/src/main/scala/cats/Monad.scala).

```scala
trait Monad[F[_]] extends cats.Applicative[F] {
  def flatMap[A, B](fa: F[A])(f: A => F[B]): F[B]
}
```

The Monad typeclass extends [Applicative]({{< ref "posts/2019/05-taming-cats-applicative" >}}). This gives instances `map`, `pure`, and `ap` functions. Furthermore, Monads have `flatMap`.

`flatMap` is like `map`. It takes a function as argument, and executes it. Where `map` takes an `A => B`, `flatMap` requires an `A => F[B]`, but they both return an `F[B]`. `flatMap` allows to chain sequential effects.

### Laws
#### Associativity
The result from chaining calls to `flatMap` should be the same to nested ones. This is similar enough to [Functor’s composition law]({{< ref "posts/2019/04-taming-cats-functor#composition" >}}).

```scala
val f = (a: Int) => Option(a * 2)
val g = (a: Int) => Option(a.toString)

assert(
  Option(1).flatMap(f).flatMap(g) ==
  Option(1).flatMap(i => f(i).flatMap(g)))
```

#### Consistency
Parallel execution, `ap`, should return the same result to sequential execution, `flatMap`.

```scala
val f = (a: Int) => Option(a * 2)
assert(
  Option(f).ap(Some(1)) ==
  Option(f).flatMap(f => Some(1).map(f)))
```

### Example
A concrete example will make Monads easier to understand.

Loyalty programs encourage existing customers to come back. In exchange of discounts, users allow the store to record their purchase history.

A customer give their loyalty card, and their cart at the counter.

```scala
import java.util.UUID

object Counter {
  def purchaseWithLoyaltyCard(
    loyaltyCardId: UUID,
    itemIds: cats.data.NonEmptyList[UUID],
  ): Unit = ???
}
```

The first step is to identify the customer behind the card. This requires a user reader.

```scala
case class User(id: UUID)
trait UsersReader {
  def fromLoyaltyCard(loyaltyCardId: UUID): User
}

class Counter(usersReader: UsersReader) {
  def purchaseWithLoyaltyCard(
    loyaltyCardId: UUID,
    itemIds: cats.data.NonEmptyList[UUID],
  ): Unit = {
    val user = usersReader.fromLoyaltyCard(loyaltyCardId)
    ???
  }
}
```

Followed by updates to the user’s purchase history with a writer.

```scala
trait UserPurchasesWriter {
  def add(userId: UUID, itemIds: cats.data.NonEmptyList[UUID]): Unit
}

class Counter(
  usersReader: UsersReader,
  userPurchasesWriter: UserPurchasesWriter,
) {
  def purchaseWithLoyaltyCard(
    loyaltyCardId: UUID,
    itemIds: cats.data.NonEmptyList[UUID],
  ): Unit = {
    val user = usersReader.fromLoyaltyCard(loyaltyCardId)
    userPurchasesWriter.add(user.id, itemIds)
  }
}
```

This implementation doesn’t leave any room for effects. This would require the `UsersReader` to return a `User` even when none exist. Using `Option` would make more sense, but why limit it.

```scala
trait UsersReader[F[_]] {
  def fromLoyaltyCard(loyaltyCardId: UUID): F[User]
}

trait UserPurchasesWriter[F[_]] {
  def add(
    userId: UUID,
    itemIds: cats.data.NonEmptyList[UUID],
  ): F[Unit]
}

class Counter[F[_]](
  usersReader: UsersReader[F],
  userPurchasesWriter: UserPurchasesWriter[F],
) {
  def purchaseWithLoyaltyCard(
    loyaltyCardId: UUID,
    itemIds: cats.data.NonEmptyList[UUID]
  ): F[Unit] = {
    val fUser = usersReader.fromLoyaltyCard(loyaltyCardId)
    userPurchasesWriter.add(fUser.id, itemIds) // Compilation error
  }
}
```

`fUser.id` will now throw a compilation error.

The `id` attribute doesn’t exist for `F[User]`. Functor’s `map` would create an `F[F[Unit]]`. To avoid this russian doll effect, Monad’s `flatMap` is required.

```scala
import cats.implicits._

class Counter[F[_]: cats.Monad](
  usersReader: UsersReader[F],
  userPurchasesWriter: UserPurchasesWriter[F],
) {
  def purchaseWithLoyaltyCard(
    loyaltyCardId: UUID,
    itemIds: cats.data.NonEmptyList[UUID]
  ): F[Unit] = {
    val fUser = usersReader.fromLoyaltyCard(loyaltyCardId)
    fUser.flatMap { user =>
      userPurchasesWriter.add(user.id, itemIds)
    }
  }
}
```

Or, with a for comprehension

```scala
class Counter[F[_]: cats.Monad](
  usersReader: UsersReader[F],
  userPurchasesWriter: UserPurchasesWriter[F],
) {
  def purchaseWithLoyaltyCard(
    loyaltyCardId: UUID,
    itemIds: cats.data.NonEmptyList[UUID]
  ): F[Unit] = for {
    user <- usersReader.fromLoyaltyCard(loyaltyCardId)
    _ <- userPurchasesWriter.add(user.id, itemIds)
  } yield ()
}
```

`Counter` is now capable of tracking customer purchases. It executes effectful events sequentially stopping at the first error. All this using an abstract reader, and writer.

---

To wrap up, Monads are abstractions to chain effectul functions. That might sound scary, but it is nothing more than `flatMap`, and a few laws.
