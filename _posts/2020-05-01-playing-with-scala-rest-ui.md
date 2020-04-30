---
title: Playing With Scala - ReST UI
tags: ["scala", "play framework"]
---

Building a single page application is a luxury not everyone can afford. If you are short on time, don't learn [Vue.js](https://vuejs.org/), [React](https://reactjs.org/), or the other flavor of the month. Use Play Framework's built-in templating engine, [Twirl](https://www.playframework.com/documentation/2.8.x/ScalaTemplates). It isn't perfect but gets the job done.

This post will help you build a blog application like the [Ruby on Rails Guide - Getting Up and Running](https://guides.rubyonrails.org/getting_started.html#getting-up-and-running). If you only care about the code, you can head straight to [GitHub](https://github.com/plippe/playing-with-scala-rest-ui) for the working application.

Let's jump right in with the models.


## Models
A blog application needs to represent articles. We aren't building the next [Medium](https://medium.com/), a handful of attributes should do the trick.

```scala
// In /app/models/Article.scala
package models

import java.time.LocalDateTime
import java.util.UUID

case class Article(
  id: UUID,
  title: String,
  text: String,
  createdAt: LocalDateTime,
  updatedAt: LocalDateTime,
)
```

`Option`s are an easy way to ignore fields that users shouldn't submit. An alternative is to create a completely different class.

```scala
// In /app/models/ArticleForm.scala
package models

case class ArticleForm(
  title: String,
  text: String
)
```

To centralize the conversion logic closer to the classes, we can add a few factory methods.

```scala
// In /app/models/Article.scala
object Article {
  def fromForm(form: ArticleForm): Article =
    Article(
      id = UUID.randomUUID,
      title = form.title,
      text = form.text,
      createdAt = LocalDateTime.now(),
      updatedAt = LocalDateTime.now(),
    )

  def updated(self: Article)(form: ArticleForm): Article =
    self.copy(
      title = form.title,
      text = form.text,
      updatedAt = LocalDateTime.now(),
    )
}
```

```scala
// In /app/models/ArticleForm.scala
object ArticleForm {
  def fromModel(model: Article): ArticleForm =
    ArticleForm(
      title = model.title,
      text = model.text,
    )
}
```

This is all great for us, but we need to inform Play about those types.


## Form
Play uses the [`Form`](https://www.playframework.com/documentation/2.8.x/api/scala/play/api/data/Form.html) class to handle form submissions. At its core, it attempts to convert a request to a specific type. This is perfect to build an `ArticleForm`.

```scala
// In /app/models/ArticleForm.scala
import play.api.data.Form
import play.api.data.Forms.{mapping, of}
import play.api.data.format.Formats._

// In ArticleForm object
val playForm: Form[ArticleForm] = Form(mapping(
  "title" -> of[String],
  "text" -> of[String],
)(ArticleForm.apply)(ArticleForm.unapply))
```

This mapping can also include [constraints](https://www.playframework.com/documentation/2.8.x/ScalaForms#Defining-constraints-on-the-form) to validate the submitted values.

```scala
// In /app/models/ArticleForm.scala
import play.api.data.Form
import play.api.data.Forms.{mapping, of}
import play.api.data.format.Formats._
import play.api.data.validation.Constraints._

// In ArticleForm object
val playForm: Form[ArticleForm] = Form(mapping(
  "title" -> of[String].verifying(minLength(5)),
  "text" -> of[String],
)(ArticleForm.apply)(ArticleForm.unapply))
```

Missing fields and unfulfilled constraints generate error messages. Those are useful to inform users.

```scala
Action { implicit request =>
  models.ArticleForm.playForm
    .bindFromRequest
    .fold(
      { formWithErrors => BadRequest("Bad") },
      { form => Ok("Good") }
    )
}
```

More on this bellow, but first we need to define how users send us information.


## Endpoints
ReST imposes strict conventions that are easy to follow.

```
# In /conf/routes
POST   /articles     controllers.ArticlesController.createArticle
GET    /articles     controllers.ArticlesController.listArticles
GET    /articles/:id controllers.ArticlesController.showArticle(id: java.util.UUID)
PUT    /articles/:id controllers.ArticlesController.updateArticle(id: java.util.UUID)
PATCH  /articles/:id controllers.ArticlesController.updateArticle(id: java.util.UUID)
DELETE /articles/:id controllers.ArticlesController.deleteArticle(id: java.util.UUID)
```

Those endpoints are perfect for an API but limiting for a UI. Adding two more endpoints removes the need to shoehorn forms on the other views.

```
# In /conf/routes
GET    /articles/new      controllers.ArticlesController.newArticle
GET    /articles/:id/edit controllers.ArticlesController.editArticle(id: java.util.UUID)
```

Beware, Play uses the first route that matches a URL. `/articles/new` must be above all `/articles/:id` routes to avoid unwanted surprises.

```
# In /conf/routes
GET    /articles/new      controllers.ArticlesController.newArticle
GET    /articles/:id/edit controllers.ArticlesController.editArticle(id: java.util.UUID)

POST   /articles          controllers.ArticlesController.createArticle
GET    /articles          controllers.ArticlesController.listArticles
GET    /articles/:id      controllers.ArticlesController.showArticle(id: java.util.UUID)
PUT    /articles/:id      controllers.ArticlesController.updateArticle(id: java.util.UUID)
PATCH  /articles/:id      controllers.ArticlesController.updateArticle(id: java.util.UUID)
DELETE /articles/:id      controllers.ArticlesController.deleteArticle(id: java.util.UUID)
```

Each of these methods needs to be defined.

```scala
// In /app/controllers/ArticlesController.scala
package controllers

import java.util.UUID
import javax.inject._
import play.api.mvc._

@Singleton
class ArticlesController @Inject()(
  val controllerComponents: ControllerComponents
) extends BaseController {

  def newArticle = Action(Ok("newArticle"))
  def editArticle(id: UUID) = Action(Ok(s"editArticle - ${id}"))

  def createArticle = Action(Ok("createArticle"))
  def listArticles = Action(Ok("listArticles"))
  def showArticle(id: UUID) = Action(Ok("showArticle - ${id}"))
  def updateArticle(id: UUID) = Action(Ok(s"updateArticle - ${id}"))
  def deleteArticle(id: UUID) = Action(Ok(s"deleteArticle - ${id}"))

}
```

Half of those methods are very like those in the [ReSTful API post]({{ site.baseurl }}{% post_url 2020-04-01-playing-with-scala-rest-api %}).

```scala
// In /app/controllers/ArticlesController.scala
// In ArticlesController class

val store = collection.mutable.Map.empty[UUID, models.Article]

def listArticles = Action {
  Ok(views.html.articles.listArticles(store.values))
}

def showArticle(id: UUID) = Action {
  store.get(id)
    .fold(Redirect(routes.ArticlesController.listArticles)) { article =>
      Ok(views.html.articles.showArticle(article))
    }
}

def deleteArticle(id: UUID) = Action {
  store.remove(id)
  Redirect(routes.ArticlesController.listArticles)
}
```

The first difference is the use of `Redirect` instead of other status codes. The second is the use of `views.html.articles...`. This will display views found in the `/app/views/articles` folder. Before diving into those views, we will implement the remaining methods.

The `newArticle` and `editArticle` display HTML forms. The first has empty placeholders while the second should contain pre-populated ones.

```scala
// In /app/controllers/ArticlesController.scala
// In ArticlesController class

def newArticle = Action { implicit request =>
  val playform = models.ArticleForm.playForm
  Ok(views.html.articles.newArticle(playform))
}

def editArticle(id: UUID) = Action { implicit request =>
  store.get(id)
    .fold(Redirect(routes.ArticlesController.listArticles)) { article =>
      val form = models.ArticleForm.fromModel(article)
      val playform = models.ArticleForm.playForm.fill(form)
      Ok(views.html.articles.editArticle(article, playform))
    }
}
```

Where the previous two show a form, the next two processes it. Once again, using `Form` simplifies the task.

```scala
// In /app/controllers/ArticlesController.scala
// In ArticlesController class

def createArticle = Action { implicit request =>
  models.ArticleForm.playForm
    .bindFromRequest
    .fold({ formWithErrors =>
      BadRequest(views.html.articles.newArticle(formWithErrors))
    }, { form =>
      val model = models.Article.fromForm(form)
      store.update(model.id, model)
      Redirect(routes.ArticlesController.showArticle(model.id))
    })
}

def updateArticle(id: UUID) = Action { implicit request =>
  store.get(id)
    .fold(Redirect(routes.ArticlesController.listArticles)) { article =>
      models.ArticleForm.playForm
        .bindFromRequest
        .fold({ formWithErrors =>
          BadRequest(views.html.articles.editArticle(article, formWithErrors))
        }, { form =>
          val model = models.Article.updated(article)(form)
          store.update(model.id, model)
          Redirect(routes.ArticlesController.showArticle(model.id))
        })
    }
```

This leaves the views.

## Views
Twirl's views start with their input.

```html
@* In /app/views/articles/showArticle.scala.html *@
@(article: Article)

<h1>Article</h1>

<p><strong>Id:</strong> @article.id</p>
<p><strong>Title:</strong> @article.title</p>
<p><strong>Text:</strong> @article.text</p>
<p><strong>Created At:</strong> @article.createdAt</p>
<p><strong>Updated At:</strong> @article.updatedAt</p>

<a href="@routes.ArticlesController.editArticle(article.id)">Edit</a>
<a href="@routes.ArticlesController.listArticles">Back</a>
```

`@` is Twirl's ["magic character"](https://www.playframework.com/documentation/2.8.x/ScalaTemplates#Syntax:-the-magic-%E2%80%98@%E2%80%99-character). It defines the input, accesses them, calls methods, loops through lists, and much more.

```html
@* In /app/views/articles/listArticles.scala.html *@
@(articles: Iterable[Article])

<h1>Articles</h1>

<table>
  @for(article <- articles) {
    <tr>
      <td>@article.id</td>
      <td>@article.title</td>
      <td>@article.text</td>
      <td>@article.createdAt</td>
      <td>@article.updatedAt</td>

      <td><a href="@routes.ArticlesController.showArticle(article.id)">Show</a></td>
      <td><a href="@routes.ArticlesController.editArticle(article.id)">Edit</a></td>
    </tr>
  }
</table>

<a href="@routes.ArticlesController.newArticle">New Article</a>
```

Play has a few opinionated [Twirl helpers](https://github.com/playframework/playframework/tree/master/core/play/src/main/scala/views/helper). They make creating an HTML form with Play a breeze, but needs a bit of upfront work.

Most of the helpers display information to users like labels or errors. Play localizes those messages. This is a nice feature to have, but we can't turn it off. This requires us to provide a [`MessagesProvider`](https://www.playframework.com/documentation/2.8.x/api/scala/play/api/i18n/MessagesProvider.html) to use those helpers. It is available in the `MessagesBaseController` instead of `BaseController`.

```scala
// In /app/controllers/ArticlesController.scala
@Singleton
class ArticlesController @Inject()(
  val controllerComponents: MessagesControllerComponents
) extends MessagesBaseController {

  ...

}
```

Also, don't forget to add the request as a view input.

```html
@* in /app/views/articles/newArticle.scala.html *@
@(articleForm: Form[ArticleForm])(implicit request: MessagesRequestHeader)

<h1>New Article</h1>

@helper.form(routes.ArticlesController.createArticle) {
  @helper.CSRF.formField

  @helper.inputText(articleForm("title"))
  @helper.textarea(articleForm("text"))

  <input type="submit" />
}

<a href="@routes.ArticlesController.listArticles">Back</a>
```

The `editArticle` view is the last to write. It should allow users to send `PUT`, `PATCH`, or `DELETE` requests. The only issue is that browsers can't submit forms with these methods.


## Brower Limitations
> **method**
>
> The HTTP method to submit the form with. Possible values:
> - `post`: The POST method; form data sent as the request body.
> - `get`: The GET method; form data appended to the `action` URL with a `?` separator. Use this method when the form has no side-effects.
> - `dialog`: When the form is inside a `<dialog>`, closes the dialog on submission.
>
> [developer.mozilla.org](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/form#attr-method)

Browsers can't properly interact with ReSTful APIs. We could change the routes to `POST`s. We could send the request with JavaScript. But following what other frameworks do seems smarter.

[Rails `POST` a form with a hidden `_method` input](https://guides.rubyonrails.org/form_helpers.html#how-do-forms-with-patch-put-or-delete-methods-work-questionmark). Many frameworks do the same. Unfortunately, Play doesn't support this, but there is a library that does.

[play-form](https://github.com/plippe/play-form) is a small library. It contains two parts. A view that `POST`s a form with an extra query string argument and a [`RequestHandler`](https://www.playframework.com/documentation/2.8.x/ScalaHttpRequestHandlers) that extracts it. This allows browser requests to be ReSTful before they reach the router.

First, add the library as a dependency.

```scala
// In /build.sbt
libraryDependencies += "com.github.plippe" %% "play-form" % "2.8.1"
```

Next, inform Play of the new request handler.

```hocon
# In /conf/application.conf
play.http.requestHandler = "com.github.plippe.play.form.DefaultHttpRequestHandler"
```

Finally, use the included form instead of the helper one.

```html
@* in /app/views/articles/editArticle.scala.html *@
@(article: Article, articleForm: Form[ArticleForm])(implicit request: MessagesRequestHeader)

@import com.github.plippe.play.form.form

<h1>Edit Article</h1>

@form(routes.ArticlesController.updateArticle(article.id)) {
  @helper.CSRF.formField

  @helper.inputText(articleForm(models.ArticleForm.TitleField))
  @helper.textarea(articleForm(models.ArticleForm.TextField))

  <input type="submit" />
}

@form(routes.ArticlesController.deleteArticle(article.id)) {
  @helper.CSRF.formField
  <input type="submit" value="Delete"/>
}

<a href="@routes.ArticlesController.showArticle(article.id)">Show</a>
<a href="@routes.ArticlesController.listArticles">Back</a>
```

And there we have it, a Twirl frontend that interacts with a ReSTful backend.

---

There are a lot of pieces required to build applications users can interact with. Explaining each of them took a lot of words. Nothing complicated, but it was still long. Imagine how long it would have been if we had to cover a frontend framework too.

Hopefully, you can see the time saved by building a proof of concept using Twirl.
