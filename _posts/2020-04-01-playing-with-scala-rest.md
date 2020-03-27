---
layout: post
title: Playing with Scala - ReST

tags: ["scala", "play framework"]
---

Play Framework is a simple way to get started with Scala. [My first post]({% post_url 2020-03-01-playing-with-scala-hello-world %}) was a traditional "Hello, World!". This one will show how to build a ReSTful API for a pet store. 

As this is the second post in the series, don't expect any advanced features. Shortcuts are taken to avoid `BodyParsers`, `Writeables`, and databases interactions. Those will be covered in later posts.

The first step is to start a new project. The [official giter8 template](https://github.com/playframework/play-scala-seed.g8) makes that step easy.

```sh
sbt new playframework/play-scala-seed.g8
```

The endpoints to read pets can be implemented next.

## Reads
The API's consumers need a way to retrieve information. Two endpoints are required. The first list all pets and the second a single one. 

The easiest way to start is by implementing the routes.

```
# In /conf/routes

GET /pets     controllers.PetsController.get
GET /pets/:id controllers.PetsController.getById(id: String)
```

The first line is straight forward. It has a static URI. The second is a bit more complex. The placeholder `:id` will extract the segment and use it as an argument.

The compiler will now expect a `PetsController` class with the two methods.

```scala
// In /app/controllers/PetsController.scala
package controllers

import javax.inject.Inject
import play.api.mvc.{BaseController, ControllerComponents}

class PetsController @Inject()(
  val controllerComponents: ControllerComponents
) extends BaseController {

  def get = Action(Ok("get"))
  def getById(id: String) = Action(Ok(s"getById(${id})"))

}
```

Extending Play's `BaseController` helps keep the controllers more concise. The trait requires a `controllerComponents` defined but offers a lot in return. The simplest way to provide the variable is with dependency injection. By default, Play handles that with [Guice](https://www.playframework.com/documentation/2.8.x/ScalaDependencyInjection).

The methods currently return some text with a 200 status code, `Ok()`. To properly defined them, the pets need to be accessible from a data source. 

To keep this post short, and leave room for other posts, a `Map` will be used instead of a proper database. Beware, compiling the application will remove all values from the `Map`.

```scala
// In /app/controllers/PetsController.scala
// In PetsController class

val store = Map.empty[String, models.Pet]
```

This would be a good time to define the `Pet` class.

```scala
// In /app/models/Pet.scala
package models

case class Pet(
  id: String,
  name: String,
  tag: Option[String],
)
```

An implementation of [Play JSON Writes](https://www.playframework.com/documentation/2.8.x/ScalaJsonCombinators#Writes) is required for the server to write the class in the JSON format.

```scala
// In /app/models/Pet.scala
import play.api.libs.json.Json

object Pet {
  implicit def petPlayJsonWrites = Json.writes[Pet]
}
```

With everything defined, the methods can properly be implemented.

```scala
// In /app/controllers/PetsController.scala
// In PetsController class
def get = Action {
  val models = store.values
  val json = Json.toJson(models)

  Ok(json)
}

def getById(id: String) = Action {
  store.get(id)
    .map(Json.toJson[models.Pet])
    .fold(NotFound(s"Pet not found: ${id}"))(Ok(_))
}
```

The next step is to add the upsert operations.

## Upserts
Two upsert methods exist. The first is to insert new pets and the second is to update an existing one. 

Once again, the implementation process is easiest by starting with the routes.

```
# In /conf/routes

POST /pets     controllers.PetsController.post
PUT  /pets/:id controllers.PetsController.putById(id: String)
```

The payloads can't be a `Pet`. This would require an identifier to create pets. Furthermore, updates would receive two, possibly different, values. A new type would solve those issues.

```scala
// In /app/models/PetForm.scala
package models

case class PetForm(
  name: String,
  tag: Option[String],
)
```

To mirror the JSON Writes for outputs, Play has [JSON Reads](https://www.playframework.com/documentation/2.8.x/ScalaJsonCombinators#Reads) for inputs.

```scala
// In /app/models/PetForm.scala
import play.api.libs.json.Json

object PetForm {
  implicit def petFormPlayJsonReads = Json.reads[PetForm]
}
```

The bodies are accessible straight from the request. First as JSON and then converted to the `PetForm` type. `Either` is a simple way to handle the errors. Failures are kept on the left and successes on the right. Those need to be merged at the end.

```scala
// In /app/controllers/PetsController.scala
// In PetsController class

val missingContentType = UnprocessableEntity("Expected 'Content-Type' set to 'application/json'")
val missingPetForm = UnprocessableEntity("Expected content to contain a pet form")

def post = Action { req =>
  req.body.asJson
    .toRight(missingContentType)
    .flatMap(_.asOpt[models.SongForm].toRight(missingPetForm))
    .map { form => Ok(s"post - ${form}") }
    .merge
}

def putById(id: String) = Action { req =>
  req.body.asJson
    .toRight(missingContentType)
    .flatMap(_.asOpt[models.SongForm].toRight(missingPetForm))
    .flatMap { form => Ok(s"putById(${id}) - ${form}") }
    .merge
}
```

The final hurdle is related to the `Map`. The current immutable value makes it impossible to insert or update pets. The store must be set to a mutable type.

```scala
// In /app/controllers/PetsController.scala
// In PetsController class

val store = collection.mutable.Map.empty[String, models.Pet]
```

This allows the methods to be properly defined.

```scala
// In /app/controllers/PetsController.scala
// In PetsController class

def post = Action { req =>
  req.body.asJson
    .toRight(missingContentType)
    .flatMap(_.asOpt[models.SongForm].toRight(missingPetForm))
    .map { form =>
      val id = UUID.randomUUID().toString
      val model = models.Song(id, form.title, form.lyrics)

      store.update(id, model)
      val json = Json.toJson(model)
      Created(json)
    }
    .merge
}

def putById(id: String) = Action { req =>
  req.body.asJson
    .toRight(missingContentType)
    .flatMap(_.asOpt[models.SongForm].toRight(missingPetForm))
    .flatMap { form =>
      store.get(id)
        .toRight(NotFound(s"Song not found: ${id}"))
        .map((_, form))
    }
    .map { case (found, form) =>
      val model = models.Song(found.id, form.title, form.lyrics)
      store.update(found.id, model)

      NoContent
    }
    .merge
}
```

The final step is to implement the delete operation.

## Delete
One last time, starting with the routes.

```
# In /conf/routes

DELETE /pets/:id controllers.PetsController.deleteById(id: String)
```

And finishing with the method.

```scala
// In /app/controllers/PetsController.scala
// In PetsController class

def deleteById(id: String) = Action {
  store.get(id)
    .fold(NotFound(s"Pet not found: ${id}")) { _ =>
      store.remove(id)

      NoContent
    }
}
```

With all endpoints implemented, the API can be used to keep track of pets.

```sh
# sbt run to start the server

# Add new pet
curl localhost:9000/pets \
  -H 'Content-Type: application/json' \
  -X POST \
  -d '{"name": "Snoopy"}'

# Show all pets
curl localhost:9000/pets

# Update existing pet, don't forget to change the ${ID}
curl localhost:9000/pets/${ID} \
  -H 'Content-Type: application/json' \
  -X PUT \
  -d '{"name": "Snoopy", "tag": "Peanuts"}'

# Show pet
curl localhost:9000/pets/${ID}

# Delete pet
curl localhost:9000/pets/${ID} \
  -X DELETE
```

---

The Play Framework made it simple to build a ReSTful API by handling the routing, the JSON conversion, and the HTTP statuses. The only thing missing is a proper UI.
