---
title: Playing With Scala - Slick
tags: ["scala", "play framework"]
---

Applications that interact with databases have a few moving pieces to keep in mind. Between the connection, the setup, and the queries, there is enough to find it overwhelming. This post will cover all those pieces in a Play application.

To avoid repeating myself, I will start with a working CRUD application. A simple ReST API that uses a `Map` instead of a database. It is like the [Pet Store we built]({{ site.baseurl }}{% post_url 2020/2020-04-01-playing-with-scala-rest-api %}), but for recipes.

If at any point you want to jump ahead, the application is available on [GitHub](https://github.com/plippe/playing-with-scala-slick). It has a few improvements, but nothing major.

Before starting, we need a PostgreSQL server running. If you do not wish to install one, Docker is a great alternative.

```sh
docker run \
  --env POSTGRES_DB=db \
  --env POSTGRES_USER=user \
  --env POSTGRES_PASSWORD=password \
  --publish 5432:5432 \
  --rm \
  --interactive \
  --tty \
  postgres
```

With our recipes API and a database running, let's jump right in.


## Data Access Object
The controller currently holds a `Map` to store recipes.

```scala
// In /app/controllers/RecipesController.scala
// In RecipesController class

val store = collection.mutable.Map.empty[UUID, models.Recipe]
```

This is an easy way to cut corners for a proof of concept but it isn't good code. One issue is around the separation of concerns. The controller and the data access object should be in distinct classes. Injecting a DAO also offers more flexibility like swapping one for another.

```scala
// In /app/daos/RecipesDao.scala
package daos

import java.util.UUID

trait RecipesDao {
  def findAll(): Seq[models.Recipe]
  def findById(id: UUID): Option[models.Recipe]
  def insert(recipe: models.Recipe): Unit
  def update(recipe: models.Recipe): Unit
  def delete(recipe: models.Recipe): Unit
}
```

For a simple transition, `Map` needs an implementation.

```scala
// In /app/daos/RecipesDao.scala

import javax.inject.Singleton

@Singleton
class RecipesDaoMap extends RecipesDao {
  val map = collection.mutable.Map.empty[UUID, models.Recipe]

  def findAll(): Future[Seq[models.Recipe]] = map.values.toSeq
  def findById(id: UUID): Future[Option[models.Recipe]] = map.get(id)
  def insert(recipe: models.Recipe): Future[Unit] = map.update(recipe.id, recipe)
  def update(recipe: models.Recipe): Future[Unit] = map.update(recipe.id, recipe)
  def delete(recipe: models.Recipe): Future[Unit] = map.remove(recipe.id)
}
```

This DAO requires `@Singleton`. It guarantees that only a single instance can exist and thus a single `Map`. It is like Scala's `object` but for Java's dependency injection.

Adding the `RecipesDao` to the `RecipesController` allows the `dao` variable to replace the `store` one.

```scala
// In /app/controllers/RecipesController.scala

class RecipesController @Inject()(
  dao: daos.RecipesDao,
  val controllerComponents: ControllerComponents
)(implicit ec: ExecutionContext) extends BaseController {
  ...
}
```

`RecipesDao` is a trait. The desired implementation must be specified. [Guice](https://github.com/google/guice) offers `@ImplementedBy` as a solution.


```scala
// In /app/daos/RecipesDao.scala

import com.google.inject.ImplementedBy

@ImplementedBy[RecipesDaoMap]
trait RecipesDao {
  ...
}
```

I prefer Play's `Module`. It removes the explicit dependency on Guice. It allows to define all bindings together. Furthermore, it can bind implementations to traits from different libraries.

```scala
// In /app/Module.scala

import com.google.inject.AbstractModule

class Module extends AbstractModule {
  override def configure() =
    bind(classOf[daos.RecipesDao]).to(classOf[daos.RecipesDaoMap])
}
```

This is all quite simple, but Slick can't conform to this interface. It returns `Future`s.

## Future
`Future`s are a way of running code asynchronously. A job is given to an execution context. The result is available when the job completes. Instead of waiting patiently, the application keeps working on other available jobs.

With Slick returning `Future`s, the `RecipesDao` and its implementations must return them too.

```scala
// In /app/daos/RecipesDao.scala

import scala.concurrent.Future

trait RecipesDao {
  def findAll(): Future[Seq[models.Recipe]]
  def findById(id: UUID): Future[Option[models.Recipe]]
  def insert(recipe: models.Recipe): Future[Unit]
  def update(recipe: models.Recipe): Future[Unit]
  def delete(recipe: models.Recipe): Future[Unit]
}

@Singleton
class RecipesDaoMap extends RecipesDao {
  val map = collection.mutable.Map.empty[UUID, models.Recipe]

  def findAll(): Future[Seq[models.Recipe]] = Future.successful(map.values.toSeq)
  def findById(id: UUID): Future[Option[models.Recipe]] = Future.successful(map.get(id))
  def insert(recipe: models.Recipe): Future[Unit] = Future.successful(map.update(recipe.id, recipe))
  def update(recipe: models.Recipe): Future[Unit] = Future.successful(map.update(recipe.id, recipe))
  def delete(recipe: models.Recipe): Future[Unit] = Future.successful(map.remove(recipe.id))
}
```

These changes affect the `RecipesController`.

- Replace `Action`s by `Action.async`s
- Inject and `implicit` `ExecutionContext`
- Use `.map` to alter a `Future`'s result
- Use `.flatMap` when chaining `Future`s
- ...

The new controller can be found on [GitHub](https://github.com/plippe/playing-with-scala-slick/blob/master/app/controllers/RecipesController.scala).

We could creating a Slick `RecipesDao`, but let's create the SQL table first.


## Evolutions
Play uses [Evolution](https://www.playframework.com/documentation/2.8.x/Evolutions) to apply database migrations. This is a great way of synchronizing database updates. It also gives a way of rolling back bad changes.

Add the library, and the relevant dependencies, to the `build.sbt` file.

```sbt
// In /build.sbt

libraryDependencies ++= Seq(
  "org.postgresql" % "postgresql" % "42.2.12",
  "com.typesafe.play" %% "play-slick" % "5.0.0",
  "com.typesafe.play" %% "play-slick-evolutions" % "5.0.0",
)
```

These allow Play to communicate with PostgreSQL, but it needs to connect first. The configuration file, `/conf/application.conf` holds the necessary settings.

```hocon
# In /conf/application.conf

slick.dbs.default.profile="slick.jdbc.PostgresProfile$"
slick.dbs.default.db.url="jdbc:postgresql://localhost:5432/db"
slick.dbs.default.db.username="user"
slick.dbs.default.db.password="password"
```

The migration scripts to apply are found in the `/conf/evolutions/default/` folder. The first file is `1.sql`, the second is `2.sql`, and so on.

```sql
-- In /conf/evolutions/default/1.sql
-- !Ups

create table recipes (
  id uuid primary key,
  name text not null,
  description text not null,
  created_at timestamp not null,
  updated_at timestamp not null
);

-- !Downs

drop table recipes;
```

When Play starts, it checks that all migration scripts have been applied.

![Source configuration]({{ "/assets/images/posts/playing-with-scala-slick-evolution.png" | absolute_url }})

To avoid having to click a button, Slick can apply migrations automatically.

```hocon
# In /conf/application.conf

play.evolutions.autoApply=true
```

After starting a database management systems, connecting to it, and setting it up, we can finally create a `RecipesDaoSlick`.


## Slick
An empty `RecipesDaoSlick` only needs to extend `RecipesDao`.

```scala
// In /app/daos/RecipesDao.scala

class RecipesDaoSlick extends RecipesDao {
  def findAll(): Future[Seq[models.Recipe]] = ???
  def findById(id: UUID): Future[Option[models.Recipe]] = ???
  def insert(recipe: models.Recipe): Future[Unit] = ???
  def update(recipe: models.Recipe): Future[Unit] = ???
  def delete(recipe: models.Recipe): Future[Unit] = ???
}
```

Slick is compatible with many database management system. The differences are available via a profile. This project uses PostgreSQL but there is no need to hard code the `slick.jdbc.PostgresProfile`. Slick can use the `/conf/application.conf` to inject the appropriete one.

```scala
// In /app/daos/RecipesDao.scala

import play.api.db.slick._
import slick.jdbc.JdbcProfile
import javax.inject.Inject

class RecipesDaoSlick @Inject()(protected val dbConfigProvider: DatabaseConfigProvider)
    extends RecipesDao
    with HasDatabaseConfigProvider[JdbcProfile] {
  import profile.api._

  ...
}
```

Slick is unable to cast a Scala case class to SQL table by itself. The mapping must be explicit.

```scala
// In /app/daos/RecipesDao.scala
// In RecipesDaoSlick class

private class RecipesTable(tag: Tag) extends Table[models.Recipe](tag, "recipes") {
  def id = column[UUID]("id", O.PrimaryKey)
  def name = column[String]("name")
  def description = column[String]("description")
  def createdAt = column[LocalDateTime]("created_at")
  def updatedAt = column[LocalDateTime]("updated_at")

  def * = (id, name, description, createdAt, updatedAt).mapTo[models.Recipe]
}
```

The code above requires a `tupled` method on the `Recipe` object. It is like apply, but takes all arguments as a tuple.

```scala
// In /app/models/Recipe.scala
// In Recipe object

def tupled(tuple: ((UUID, String, String, LocalDateTime, LocalDateTime))): Recipe =
  (apply _).tupled(tuple)
```

Slick has a query builder to avoid writing SQL. It uses `+=` for inserts, `filter` for where clauses, and much more.

```scala
// In /app/daos/RecipesDao.scala
// In RecipesDaoSlick class

private val table = TableQuery[RecipesTable]

def findAll(): Future[Seq[models.Recipe]] = db.run(table.result)

def findById(id: UUID): Future[Option[models.Recipe]] = db.run {
  table.filter(_.id === id)
    .result
    .headOption
}

def insert(recipe: models.Recipe): Future[Unit] = db.run {
  (table += recipe)
    .andThen(DBIOAction.successful(())) // Return Unit instead of Int
}

def update(recipe: models.Recipe): Future[Unit] = db.run {
  table.filter(_.id === recipe.id)
    .update(recipe)
    .andThen(DBIOAction.successful(())) // Return Unit instead of Int
}

def delete(recipe: models.Recipe): Future[Unit] = db.run {
  table.filter(_.id === recipe.id)
    .delete
    .andThen(DBIOAction.successful(()))  // Return Unit instead of Int
}
```

Slick's query builder is a controversial way to write safe SQL, but there is an alternative. We can write queries directly.


## Slick Plain SQL
Slick has many string interpolations methods to write SQL. Two are described below.

The first is `sql`. It returns a result set. The `.as` method casts the record into a specific Scala type.

```scala
def findAll(): Future[Seq[models.Recipe]] = db.run {
  sql"""
    select id, name, description, created_at, updated_at
    from recipes
  """.as[models.Recipe]
}
```

The query can also contain a where clause with variables. The string interpolation will protect against [SQL injections](https://en.wikipedia.org/wiki/SQL_injection).

```scala
def findById(id: UUID): Future[Option[models.Recipe]] = db.run {
  sql"""
    select id, name, description, created_at, updated_at
    from recipes
    where id = ${id}
  """.as[models.Recipe].headOption
}
```

The second string interpolation is `sqlu`. It returns the number of records affected by the query.

```scala
def insert(recipe: models.Recipe): Future[Unit] = db.run {
  sqlu"""
    insert into recipes(id, name, description, created_at, updated_at)
    values (${recipe.id}, ${recipe.name}, ${recipe.description}, ${recipe.createdAt}, ${recipe.updatedAt})
  """.andThen(DBIOAction.successful(()))
}
```

Slick's uses implicit `SetParameter`s to build queries and `GetResult`s to parse records. Many types are plug and play, but `UUID`, `LocalDateTime`, and `Recipe` aren't.

```scala
import java.sql.{Timestamp, Types}
import slick.jdbc.{GetResult, SetParameter}

implicit final def helpersSlickGetResultLocalDateTime: GetResult[LocalDateTime] =
  GetResult(r => r.nextTimestamp.toLocalDateTime)

implicit final def helpersSlickSetParameterLocalDateTime: SetParameter[LocalDateTime] =
  SetParameter { case (v, pp) => pp.setTimestamp(Timestamp.valueOf(v)) }

implicit final def helpersSlickGetResultUUID: GetResult[UUID] =
  GetResult(r => r.nextObject.asInstanceOf[UUID])

implicit final def helpersSlickSetParameterUUID: SetParameter[UUID] =
  SetParameter { case (v, pp) => pp.setObject(v, Types.OTHER) }

implicit val getRecipeResult: GetResult[models.Recipe] = GetResult(r => models.Recipe(r.<<, r.<<, r.<<, r.<<, r.<<))
```

Composing all those parts make a `RecipesDaoSlickPlainSql` data access object.

```scala
// In /app/daos/RecipesDao.scala

import java.sql.{Timestamp, Types}
import slick.jdbc.{GetResult, SetParameter}

object jdbc {
  implicit final def helpersSlickGetResultLocalDateTime: GetResult[LocalDateTime] =
    GetResult(r => r.nextTimestamp.toLocalDateTime)

  implicit final def helpersSlickSetParameterLocalDateTime: SetParameter[LocalDateTime] =
    SetParameter { case (v, pp) => pp.setTimestamp(Timestamp.valueOf(v)) }

  implicit final def helpersSlickGetResultUUID: GetResult[UUID] =
    GetResult(r => r.nextObject.asInstanceOf[UUID])

  implicit final def helpersSlickSetParameterUUID: SetParameter[UUID] =
    SetParameter { case (v, pp) => pp.setObject(v, Types.OTHER) }
}

class RecipesDaoSlickPlainSql @Inject()(protected val dbConfigProvider: DatabaseConfigProvider) extends RecipesDao with HasDatabaseConfigProvider[JdbcProfile] {
  import profile.api._
  import jdbc._

  implicit val getRecipeResult: GetResult[models.Recipe] = GetResult(r => models.Recipe(r.<<, r.<<, r.<<, r.<<, r.<<))

  def findAll(): Future[Seq[models.Recipe]] = db.run(sql"""
    select id, name, description, created_at, updated_at
    from recipes
  """.as[models.Recipe])

  def findById(id: UUID): Future[Option[models.Recipe]] = db.run(sql"""
    select id, name, description, created_at, updated_at
    from recipes
    where id = ${id}
  """.as[models.Recipe].headOption)

  def insert(recipe: models.Recipe): Future[Unit] = db.run(sqlu"""
    insert into recipes(id, name, description, created_at, updated_at)
    values (${recipe.id}, ${recipe.name}, ${recipe.description}, ${recipe.createdAt}, ${recipe.updatedAt})
  """.andThen(DBIOAction.successful(()))

  def update(recipe: models.Recipe): Future[Unit] = db.run(sqlu"""
    update recipes
    set name = ${recipe.name},
      description = ${recipe.description},
      created_at = ${recipe.createdAt},
      updated_at = ${recipe.updatedAt}
    where id = ${recipe.id}
  """.andThen(DBIOAction.successful(()))

  def delete(recipe: models.Recipe): Future[Unit] = db.run(sqlu"""
    delete from recipes
    where id = ${recipe.id}
  """.andThen(DBIOAction.successful(()))
}
```

The application should now have three different `RecipesDao`s. Two of those read from and write to a PostgreSQL database. You just need to bind the one you prefer in the `/app/Module.scala`.

---

That was a lot to cover: Dependency Injection, Future, Evolution, Slick, Slick Plain SQL. I could have definitely broken this into many parts, but we got here in the end.

We have a Play application that setups and queries a database, but does it work. Next time, we will make sure it behaves correctly by writing tests.
