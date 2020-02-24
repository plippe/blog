---
title: "Taming cats - State"
date: 2019-01-01

series: "taming cats"
tags: ["scala", "cats"]
---

> *Cats is a library which provides abstractions for functional programming in the [Scala programming language](https://scala-lang.org/). The name is a playful shortening of the word category.*

When you google functional programming, you can find many definitions. Most have different nuances, but purity is always present.

> *Functional programming is a way of writing software applications using only pure functions and immutable values.*
>
> *- [Alvin Alexander](https://alvinalexander.com/scala/fp-book/what-is-functional-programming)*

This is often described in relations to inputs, outputs, mutability, and outside world. In short, a pure function’s output should only depend on its input. Furthermore, the function shouldn’t affect, or be affected by the outside world.

```scala
def sum(a: Int, b: Int): Int = a + b

assert(sum(1, 2) == 3)
assert(sum(1, 2) == 3)
...
```

Based on our definition, the following function isn’t pure.

```scala
def randomInt(): Int = {
  scala.util.Random.nextInt()
}
```

`randomInt` takes no inputs. It should always return the same value. The unpredictable output makes it hard to reproduce behaviour, e.g. tests, debugging.

To make the function pure, it must take an input that will determine the output.

```scala
def randomInt(seed: Long): Int = {
  val rnd = new scala.util.Random(seed)
  rnd.nextInt()
}
```

By initializing `Random` with a seed value, the result is reproducible. This makes testing this function very easy.

```scala
assert(randomInt(123L) == randomInt(123L))
assert(randomInt(123L) != randomInt(456L))
```

To build a bigger application, the function must be composable.

```scala
val seed = 123L

val a = randomInt(seed)
val b = randomInt(seed)
val c = randomInt(seed)
```

Because using the same seed always return the same value, it must change after use. To avoid mutability, and impure functions, `randomInt` must return the next seed with its result.

```scala
def randomInt(seed: Long): (Long, Int) = {
  val rnd = new scala.util.Random(seed)
  (rnd.nextLong(), rnd.nextInt())
}

val seed = 123L
val (seedA, a) = randomInt(seed)
val (seedB, b) = randomInt(seedA)
val (seedC, c) = randomInt(seedB)
```

A type alias can standardize the concept.

```scala
type State[A,B] = A => (A, B)
val randomInt: State[Long, Int] = { seed =>
  val rnd = new scala.util.Random(seed)
  (rnd.nextLong(), rnd.nextInt())
}

val randomBoolean: State[Long, Boolean] = ???
val randomChar: State[Long, Char] = ???
def randomString(length: Int): State[Long, String] = ???
```

This standard can be safer using a proper type.

```scala
case class State[A,B](run: A => (A, B)) {
  def map[C](f: B => C): State[A, C] =
    State({ a =>
      val (a1, b) = run(a)
      (a1, f(b))
    })

  def flatMap[C](f: B => State[A, C]): State[A, C] =
    State({ a =>
      val (a1, b) = run(a)
      f(b).run(a1)
    })
}

val randomInt: State[Long, Int] = State({ seed =>
  val rnd = new scala.util.Random(seed)
  (rnd.nextLong(), rnd.nextInt())
})
```

`map`, and `flatMap` allows `State` to be used in for comprehensions. This hides the management of the seed, and removes the risk of reusing an old value.

```scala
val abc = for {
  a <- randomInt
  b <- randomInt
  c <- randomInt
} yield (a, b, c)

val seed = 123L
val (nextSeed, (a, b, c)) = abc.run(seed)
```

Random numbers are great, but they don’t help to highlight real world uses cases for `State`. Before jumping to the obvious “cats has it”, here is a more relatable examples.

![Tic-tac-toe](/images/2019/tic-tac-toe.png)

Tic-tac-toe, noughts and crosses, or Xs and Os, is a game that shouldn’t need an introduction. If your childhood was deprived of this masterpiece, or if you need a refresher, have a look at the [wikipedia page](https://en.wikipedia.org/wiki/Tic-tac-toe).

The following information represent the game.

```scala
sealed trait Player
case object X extends Player
case object O extends Player

sealed trait Cell
case object AA extends Cell
case object AB extends Cell
case object AC extends Cell
case object BA extends Cell
case object BB extends Cell
case object BC extends Cell
case object CA extends Cell
case object CB extends Cell
case object CC extends Cell

sealed trait Outcome
case object Draw extends Outcome
case class Win(player: Player) extends Outcome
```

An object must record the game’s state after each turn. It can track whos turn it is, which player marked a cell, and other game related information.

```scala
case class GameState(
  player: Option[Player],
  cells: Map[Cell, Player],
  start: DateTime,
  end: Option[DateTime],
  ...
)
```

A handful of functions must interact with the `GameState`. It could be a global variable, or stored in a database. This would need impure interactions. A better solution is to pass latest `GameState` as input, and expect the updated one as output. This looks a lot like `State`.

```scala
// Please ignore the IO, it is hard to build an example without it
def drawCells: State[GameState, Unit]
def readCell: State[GameState, Cell]
def markCell(c: Cell): State[GameState, Unit]
def computeOutcome: State[GameState, Option[Outcome]]
```

A for comprehension will compose the functions. That will remove the risk of reusing an old `GameState` by hiding intermediate values.

```scala
def turn: State[GameState, Outcome] =
  for {
    _       <- drawCells
    cell    <- readCell
    _       <- markCell(cell)
    outcome <- computeOutcome.flatMap {
                 case None          => turn
                 case Some(outcome) => State((_, outcome))
               }
  } yield outcome
```

The application starts by calling turn with a new `GameState`. The function calls itself until it finds an outcome. `State` allows the whole flow to be pure, except for some silly user interaction.

As mentioned before, [`State` is available in cats](https://typelevel.org/cats/datatypes/state.html). It comes with many bells, and whistles, but works very similarly to the one implemented above.

```scala
import cats.data.State
val randomInt: State[Long, Int] = State({ seed =>
  val rnd = new scala.util.Random(seed)
  (rnd.nextLong(), rnd.nextInt())
})

randomInt.run(123L).value
```

If you are encumbered with mutable variables, give `State` a try. It will make your code cleaner, and safer.
