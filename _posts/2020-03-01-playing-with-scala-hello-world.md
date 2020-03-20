---
layout: post
title: Playing with Scala - Hello, World!
image: /assets/images/play.jpeg

tags: ["scala", "play framework"]
---

Scala is a language stuck between two worlds. The FP world attracts many talents, but the OOP one is often where people start. [My "taming cats" posts](/series/taming-cats.html) covered [cats](https://typelevel.org/cats/) for the first group. Bellow is the start of a few posts on the [Play Framework](http://playframework.com/) for the second.

## Play Framework
The Play Framework is one of the simplest ways to create web applications in Scala. The MVC framework contains [routing](https://www.playframework.com/documentation/2.8.x/ScalaRouting), [JSON formatting](https://www.playframework.com/documentation/2.8.x/ScalaJson), [forms and validation](https://www.playframework.com/documentation/2.8.x/ScalaForms), [sessions](https://www.playframework.com/documentation/2.8.x/ScalaSessionFlash), database interactions ([Anorm](https://www.playframework.com/documentation/2.8.x/Anorm), [Evolutions](https://www.playframework.com/documentation/2.8.x/Evolutions)), [templating](https://www.playframework.com/documentation/2.8.x/ScalaTemplates), [dependency injection](https://www.playframework.com/documentation/2.8.x/ScalaDependencyInjection) and much more.

Furthermore, the Scala knowledge to write controllers is low. At most, understanding `Future` is helpful, but not required.

Let's prove that with a simple example.

## Giter8
Play Framework has a [giter8](http://www.foundweekends.org/giter8/) template to get started.

```sh
> sbt new playframework/play-scala-seed.g8
[info] Loading global plugins from [HOME]/.sbt/1.0/plugins
[info] Set current project to code (in build file:[PWD])
[info] Set current project to code (in build file:[PWD])

This template generates a Play Scala project

name [play-scala-seed]:
organization [com.example]:

Template applied in [PWD]/./play-scala-seed

> cd play-scala-seed
```

The template contains a working application with a route, a controller, a view, and tests for all those.

```sh
sbt run
```

Once the server has started, [localhost:9000](http://localhost:9000/) should display Play's welcome message. From here, implementing "Hello, World!" is easy.

## Hello, World!
The first step is to add a new route in the `/conf/routes` file. The line starts with an HTTP verb, a URI, and the method to call. 

```
GET /hello-world controllers.HomeController.helloWorld
```

The new endpoint will throw an error. 

```
value helloWorld is not a member of controllers.HomeController
```

Implementing the missing method will fix the issue. The `HomeController` is in the `/app/controllers/HomeController.scala` file. The following `helloWorld` definition will do the trick.

```
def helloWorld = Action(Ok("Hello, World!"))
```

Opening [localhost:9000/hello-world](http://localhost:9000/hello-world) should now display "Hello, World!".

---

Play Framework has a great template. It simplifies the getting started process like the "Hello, World!" endpoint above. It isn't impressive but gives a stable foundation to build on. 

With tradition out of the way, the next post will be on ReST.
