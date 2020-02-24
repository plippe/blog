---
title: "Taming cats - Functor"
date: 2019-04-01

series: "taming cats"
tags: ["scala", "cats", "typeclass"]
---

Computer science is great at finding off-putting vocabulary. It is able to hide simple concepts behind scary words, for example, Functors.

### Typeclasse
To use Cats’ Functors, it helps to understand typeclasses.

In short, a typeclass is an interface. An instance is created by extending a class, or with an anonymous class created via a function. The latter allows Scala built in types, or other 3rd party types, to be compatible with the interface.

If you are looking to learn more about typeclasses, I wrote two posts about them. The first [compares suppertypes with typeclasses]({{< ref "posts/2019/02-scala-generics-and-typeclasses" >}}), while the second shows [how to create your own typeclass to write CSVs]({{< ref "posts/2019/03-scala-typeclasses" >}}). They shouldn’t take you more than 10 minutes to understand.

### Functor

Cats defines [Functor in 150 lines of code](https://github.com/typelevel/cats/blob/master/core/src/main/scala/cats/Functor.scala), but it only takes 3 to understand their purpose.

```scala
trait Functor[F[_]] {
  def map[A, B](fa: F[A])(f: A => B): F[B]
}
```

In its simplest form, a Functor is a typeclass with an unimplemented `map` function. Its type argument, `F[_]`, is a higher-kinded type. In other words, it represents a type that holds another: `Option[_]`, `List[_]`, …

```scala
// [/core/src/main/scala/cats/instances/option.scala](https://github.com/typelevel/cats/blob/master/core/src/main/scala/cats/instances/option.scala)
implicit val catsStdInstancesForOption = new Functor[Option] {
  override def map[A, B](fa: Option[A])(f: A => B): Option[B] =
    fa.map(f)
}

// [/core/src/main/scala/cats/instances/list.scala](https://github.com/typelevel/cats/blob/master/core/src/main/scala/cats/instances/list.scala)
implicit val catsStdInstancesForList = new Functor[List] {
  override def map[A, B](fa: List[A])(f: A => B): List[B] =
    fa.map(f)
}
```

To guaranty that all Functors behaves the same, having a map function isn’t enough. The implementations must also obey two laws.

### Laws
#### Identity
The first law hints at the [identity function](https://www.scala-lang.org/api/2.12.6/scala/Predef$.html#identity[A](x:A):A). This function takes an argument, and returns an identical copy. Using it in a Functor’s `map` should always result in a Functor of same value.

```scala
assert(Option(1).map(identity) == Option(1))
assert(List(1, 2, 3).map(identity) == List(1, 2, 3))
```

#### Composition
The second law refers to function composition. Given two functions, `f` and `g`, calling `map` for `f`, and then `g`, should return the same value as calling map with `f` and `g` composed.

```scala
val f = (a: Int) => a * 2
val g = (a: Int) => a.toString
val fg = f.andThen(g)

assert(Option(1).map(f).map(g) == Option(1).map(fg))
assert(List(1, 2, 3).map(f).map(g) == List(1, 2, 3).map(fg))
```

Cats has Functor instances defined for their own data structures, and a few Scala built in types. You can also create a new ones, but make sure they obey the laws.

#### Example
Typeclasses are about abstraction. Functors aren’t different. The example below uses `map` to change a data store’s response.

```scala
trait Store[F[_], A, B] {
  def get(a: A): F[B]
}
```

Data can be computed, or read from files or volatile memory. To retrieve it, you might need network calls, API calls, or custom logic. Abstraction gives the application flexibility.

```scala
import scala.concurrent.Future

case class User(id: Int, firstName: String, lastName: String)

trait UsersStore[F[_]] extends Store[F, Int, User]
object UsersStore {
  def remote = new UsersStore[Future] {
    def get(id: Int): Future[User] = ???
  }

  def local = new UsersStore[Option] {
    def get(id: Int): Option[User] = ???
  }
}
```

Building on top of abstraction can be tricky. Before typeclasses, the solution was to pass a function that understood the abstraction.

```scala
def getJsonUser[F[_]](
  store: UsersStore[F],
  toJson: F[User] => F[String]
): F[String] = {
  val fa = store.get(123)
  toJson(fa)
}
```

This removes flexibility, and requires a lot of single purpose code. A Functor can solve that problem.

```scala
import cats.Functor
import cats.implicits._

def getJsonUser[F[_]: Functor](
  store: UsersStore[F],
  toJson: User => String
): F[String] =
  store.get(123).map(toJson)
```

---

As you saw, Functors aren’t hard. The typeclass offers a very simple function to write abstract code. By itself, it can be hard to see if the added complexity is worth it, but hopefully, my next posts will help you decide.
