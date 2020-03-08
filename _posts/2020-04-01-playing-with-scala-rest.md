---
layout: post
title: Playing with Scala - ReST
image: /assets/images/play.jpeg

series: "playing with scala"
tags: ["scala", "play framework"]
---

Play Framework is a simple way to get started with Scala. My first post was a traditional "Hello, World!". This one will show how to build a ReSTful API for songs. 

Why songs? It beats building another to-do application.

The first step is to start a new Play project. [The official giter8](https://github.com/playframework/play-scala-seed.g8) template makes that step easy. Next, read endpoints can be implemented.

## Reads
The API's consumers need a way to retrieve information. Two endpoints are required. The first would list songs and the second return a single one. The easiest way to start is by implementing the routes.

```
# In /conf/routes
GET /songs     controllers.SongsController.get
GET /songs/:id controllers.SongsController.getById(id: String)
```

The first line is straight forward. It has a static URI and a method without arguments. The second is a bit more complex. The placeholder `:id` will extract the URI segment and use it as an argument.

The compiler will now request a `SongsController` class with the two methods.

```scala
// In /app/controllers/SongsController.scala
package controllers

import javax.inject.Inject
import play.api.mvc.{BaseController, ControllerComponents}

class SongsController @Inject()(
  val controllerComponents: ControllerComponents
) extends BaseController {
  def get = Action(Ok("get"))
  def getById(id: String) = Action(Ok(s"getById(${id})"))
}
```

Extending Play's `BaseController` helps keep the controllers more concise. The trait requires a `controllerComponents` defined but offers a lot in return. The simplest way to provide the variable is with dependency injection. By default, Play handles that with [Guice](https://www.playframework.com/documentation/2.8.x/ScalaDependencyInjection). 

The methods currently return some text with a 200 status code, `Ok()`. To properly defined them, the songs need to be accessible from a data source. To keep this post short, and leave room for another post, a Map will be used instead of a proper database.

```scala
// In /app/controllers/SongsController.scala
// In SongsController class
val store = Map.empty[String, models.Song]
```

This would be a good time to define the Song class.

```scala
// In /app/models/Song.scala
package models

case class Song(
  id: String,
  title: String,
  lyrics: String,
)
```

An implementation of [Play JSON Writes](https://www.playframework.com/documentation/2.8.x/ScalaJsonCombinators#Writes) is required for the server to write the class in the JSON format.

```scala
// In /app/models/Song.scala
import play.api.libs.json.Json

object Song {
  implicit def songPlayJsonWrites = Json.writes[Song]
}
```

With everything defined, the methods can properly be implemented.

```scala
// In /app/controllers/SongsController.scala
// In SongsController class
def get = Action {
  val models = store.values
  val json = Json.toJson(models)

  Ok(json)
}

def getById(id: String) = Action {
  store.get(id)
    .map(Json.toJson[models.Song])
    .fold(NotFound(s"Song not found: ${id}"))(Ok(_))
}
```

The next step is to implement upsert operations.

## Upserts
Two upsert methods exist. The first is to insert new songs and the second is to update existing ones. Once again, the implementation process is easiest by starting with the routes.

```
# In /conf/routes
POST /songs     controllers.SongsController.post
PUT  /songs/:id controllers.SongsController.putById(id: String)
```

The endpoints don't state the expected payload. This will be handled at a later stage.

The payload can't be a `Song`. This type would require an `id` during creates. Furthermore, updates would receive two. A new type would solve those issues.

```scala
// In /app/models/SongForm.scala
package models

case class SongForm(
  title: String,
  lyrics: String,
)
```

An implementation of [Play JSON Reads](https://www.playframework.com/documentation/2.8.x/ScalaJsonCombinators#Reads) is required for the server to read the class in the JSON format.

```scala
// In /app/models/SongForm.scala
import play.api.libs.json.Json

object SongForm {
  implicit def songFormPlayJsonReads = Json.reads[SongForm]
}
```

The requests' body are parsed with `BodyParser`s. Those are explicit during the `Action` creation.

```scala
// In /app/controllers/SongsController.scala
// In SongsController class
def post = Action(parse.json[models.SongForm]) { req =>
  Ok(s"post - ${req.body}")
}

def putById(id: String) = Action(parse.json[models.SongForm]) { req =>
  Ok(s"putById(${id}) - ${req.body}")
}
```

The final hurdle is related to the Map. The current immutable value makes it impossible to insert or update songs. The store must be set to a mutable type.

```scala
// In /app/controllers/SongsController.scala
// In SongsController class
val store = collection.mutable.Map.empty[String, models.Song]
```

This allows the methods to be defined.

```scala
// In /app/controllers/SongsController.scala
// In SongsController class
def post = Action(parse.json[models.SongForm]) { req =>
  val id = java.util.UUID.randomUUID().toString
  val model = models.Song(id, req.body.title, req.body.lyrics)
  store.update(id, model)

  val json = Json.toJson(model)
  Created(json)
}

def putById(id: String) = Action(parse.json[models.SongForm]) { req =>
  store.get(id)
    .fold(NotFound(s"Song not found: ${id}")) { _ =>
      val model = models.Song(id, req.body.title, req.body.lyrics)
      store.update(id, model)

      NoContent
    }
}
```

The final step is to implement the delete operation.

## Delete
One last time, starting with the routes.

```
DELETE  /songs/:id controllers.SongsController.deleteById(id: String)
```

Action

```scala
// In /app/controllers/SongsController.scala
// In SongsController class
def deleteById(id: String) = Action {
  store.get(id)
    .fold(NotFound(s"Song not found: ${id}")) { _ =>
      store.remove(id)

      NoContent
    }
}
```

---

conclusion
