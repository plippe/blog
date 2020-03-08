---
layout: post
title: Strongly typed pancakes

tags: ["scala"]
---

Shrove Tuesday is over. After eating my weight in pancakes, I had a longer look at the recipe.

```
100g plain flour
2 eggs
300ml milk
1tbsp sunflower oil
pinch of salt
```

Recipes holds a lot of information: ingredients, quantities, and units of measure. Like [the mars climate orbiter](https://en.wikipedia.org/wiki/Mars_Climate_Orbiter), types would make cooking safer.

```scala
case class IngredientMeasurement(
  ingredient: String,
  amount: Double,
  unit: String) {

  def +(that: IngredientMeasurement) =
    this.copy(quantity = this.quantity + that.quantity)
}

val crepeRecipe = Iterable(
  new IngredientMeasurement("plain flour", 100, "gram"),
  new IngredientMeasurement("egg", 2, "whole"),
  new IngredientMeasurement("milk", 300, "milliliters"),
  new IngredientMeasurement("sunflower oil", 1, "tablespoon"),
  new IngredientMeasurement("salt", 1, "pinch")
)
```

`IngredientMeasurement` is a step in the right direction, but it doesn’t make it safe. Any ingredients can be combined with another. Type parameters are required to differentiate apples from oranges.

```scala
trait Ingredient
case object PlainFlour extends Ingredient
case object Egg extends Ingredient
case object Milk extends Ingredient
case object SunflowerOil extends Ingredient
case object Salt extends Ingredient

case class IngredientMeasurement[I <: Ingredient](
  ingredient: I,
  amount: Double,
  unit: String) {

  def +(that: IngredientMeasurement[I]) =
    this.copy(amount = this.amount + that.amount)

}

val crepeRecipe = Iterable(
  new IngredientMeasurement(PlainFlour, 100, "gram"),
  new IngredientMeasurement(Egg, 2, "whole"),
  new IngredientMeasurement(Milk, 300, "millilitre"),
  new IngredientMeasurement(SunflowerOil, 1, "tablespoon"),
  new IngredientMeasurement(Salt, 1, "pinch")
)
```

While this representation fixes the issue with ingredients, the units one remain.

Units are split in quantities like mass, and volume. Within the same quantity, converting one unit to another often only takes a multiplication. Cross quantity operations aren’t allowed.

```scala
trait Quantity
trait Mass extends Quantity
trait Volume extends Quantity
case class QuantityUnit[Q <: Quantity](
  value: Double,
  multiplier: Double) {

  def +(that: QuantityUnit[Q]) = {
    val thatValue = that.value * that.multiplier / this.multiplier
    this.copy(value = this.value + thatValue)
  }

}

object Mass {
  def gram(value: Double) = QuantityUnit[Mass](value, 1)
}

object Volume {
  def millilitre(value: Double) = QuantityUnit[Volume](value, 0.001)
  def tablespoon(value: Double) = QuantityUnit[Volume](value, 0.017)
  def pinch(value: Double) = QuantityUnit[Volume](value, 0.0074)
}
```

Writing a conversion library isn’t hard, but why reinvent the wheel. [Squants](http://www.squants.com/), and [Libra](https://to-ithaca.github.io/libra/) offer better solutions. Furthermore, this allows me to focus on my pancakes.

```scala
import squants._
import squants.mass._
import squants.space._

trait Ingredient
case object PlainFlour extends Ingredient
case object Egg extends Ingredient
case object Milk extends Ingredient
case object SunflowerOil extends Ingredient
case object Salt extends Ingredient

case class IngredientMeasurement[
  I <: Ingredient,
  Q <: Quantity[Q]](
    ingredient: I,
    amount: Q
) {
  def +(that: IngredientMeasurement[I, Q]) =
    this.copy(amount = this.amount + that.amount)
}

case class WholeQuantity(count: Int) extends
  Quantity[WholeQuantity] {

  def value: Double = count
  def dimension: Dimension[WholeQuantity] = ???
  def unit: UnitOfMeasure[WholeQuantity] = ???
}

object Pinch extends VolumeUnit {
  val conversionFactor = 0.0074
  val symbol = "pinch"
}

val crepeRecipe = Iterable(
  new IngredientMeasurement(PlainFlour, Grams(100)),
  new IngredientMeasurement(Egg, WholeQuantity(2)),
  new IngredientMeasurement(Milk, Millilitres(300)),
  new IngredientMeasurement(SunflowerOil, Tablespoons(1)),
  new IngredientMeasurement(Salt, Pinch(1))
)
```

My recipe is now type safe. It doesn’t make my crepes any healthier, but it should help keep them tasty.

Cooking aside. The main selling point of statically typed languages is their pre-runtime checks. Having specific types, instead of generic ones, increase the effectiveness of those tests. Instead of using strings everywhere, don’t be afraid of creating your own types.
