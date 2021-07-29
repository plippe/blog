---
title: Playing With Scala - Akka
tags: ["scala", "play framework"]
---

Users have come to expect fast websites. In many cases, this can easily be achieved by optimizing a few queries, but some requests just take time. They could create thumbnails, export data, or just be plain slow. This post will show how to run these time consuming processes in the bacgrkound with [Akka](https://akka.io/).

We will be building a website to store and share [Magic: The Gathering](https://magic.wizards.com/en) decks. If those words seem foreign, don't worry the idea is quite easy to grasp. Magic is a card game. Players build decks to compete between one another. With thousands of cards available, creating a good deck is the hardest, and [the most expensive](https://www.polygon.com/2018/7/28/17625830/magic-the-gathering-black-lotus-auction-sold), part of the game. This is where a repository of pre built decks has value.

A user would upload the list of card identifier, the set the card belongs and it's number. The full details of those cards is then fetched from a 3rd party APIs. This will happen in the background to avoid keeping the user waiting. This will impact responses that might be missing information at first, but won't keep users waiting.

We will start by building a simple API.

## API
The API is similar to those written before. Instead of being for [pets]({{ site.baseurl }}{% post_url 2020/2020-04-01-playing-with-scala-rest-api %}), [articles]({{ site.baseurl }}{% post_url 2020/2020-05-01-playing-with-scala-rest-ui %}), or [recipes]({{ site.baseurl }}{% post_url 2020/2020-06-01-playing-with-scala-slick %}), it is for decks of card identifiers.

```scala
// In /app/models/Deck.scala
package models

import java.util.UUID

case class CardIdentifier(
  card: String,
  set: String,
)

case class DeckOfCardIdentifier(
  id: UUID,
  cards: List[CardIdentifier],
)

case class DeckOfCardIdentifierForm(
  cards: List[CardIdentifier],
)
```

The DAO and controller don't need anything fancy. A `Map` can be used for the first and a ReSTful interface for the second. The only real need is to create, store, and return a deck of identifiers.

```sh
-> curl localhost:9000/decks -d '[{"card": "a", "set": "b"}, {"card": "c", "set": "d"}]'
{"id":"a56624f0-2641-4e7d-acb3-80cc0d937fab","cards":[{"card": "a", "set": "b"}, {"card": "c", "set": "d"}]}

-> curl localhost:9000/decks/a56624f0-2641-4e7d-acb3-80cc0d937fab
{"id":"a56624f0-2641-4e7d-acb3-80cc0d937fab","cards":[{"card": "a", "set": "b"}, {"card": "c", "set": "d"}]}
```

Returning the decks without cards details greatly increase the amount of work on the frontend. This is where a 3rd party API can assist.

## 3rd Party API
[Scryfall](https://scryfall.com/) has an easy to use API. There are a few endpoints to fetch card details by identifiers. The [bulk endpoint](https://scryfall.com/docs/api/cards/collection) seems to be the most appropriete. It returns all the information needed while keeping the amount of calls to a minimum.

```sh
-> curl https://api.scryfall.com/cards/collection \
  -H 'Content-Type: application/json' \
  -d '{"identifiers":[{"set": "m20","collector_number": "126"}]}'
{"object":"list","not_found":[],"data":[...]}
```

The request and response can be represented with case classes.

```scala
// In app/scryfall/CardsCollection.scala
package scryfall

import play.api.libs.json._
import play.api.libs.ws.WSClient
import scala.concurrent.{ExecutionContext, Future}

case class CardsCollectionRequestIdentifier(
  set: String,
  collectorNumber: String,
)

object CardsCollectionRequestIdentifier {
  implicit val config = JsonConfiguration(JsonNaming.SnakeCase)
  implicit def scryfallCardsCollectionRequestIdentifierJsonFormat = Json.format[CardsCollectionRequestIdentifier]
}

case class CardsCollectionRequest(
  identifiers: List[CardsCollectionRequestIdentifier],
)

object CardsCollectionRequest {
  val url = "https://api.scryfall.com/cards/collection"
  implicit def scryfallCardsCollectionRequestIdentifierJsonFormat = Json.format[CardsCollectionRequest]
}

case class CardsCollectionResponseCard(
  set: String,
  setName: String,
  collectorNumber: String,
  name: String,
)

object CardsCollectionResponseCard {
  implicit val config = JsonConfiguration(JsonNaming.SnakeCase)
  implicit def scryfallCardsCollectionResponseCardJsonFormat = Json.format[CardsCollectionResponseCard]
}

case class CardsCollectionResponse(
  notFound: List[CardsCollectionRequestIdentifier],
  data: List[CardsCollectionResponseCard],
)

object CardsCollectionResponse {
  implicit val config = JsonConfiguration(JsonNaming.SnakeCase)
  implicit def scryfallCardsCollectionResponseJsonFormat = Json.format[CardsCollectionResponse]
}

```

Scryfall uses snake case while Scala prefers camel case. The configuration converts the names back and forth to avoid reading or writting the wrong field.

With a writeable request and readable response, Play's [web service library](https://www.playframework.com/documentation/2.8.x/ScalaWS) can handle the HTTP calls.

```sbt
// In build.sbt
libraryDependencies += ws
```

A thin Scryfall client, that uses the `WSClient`, helps keep the code clean.

```scala
// In app/scryfall/Client.scala
package scryfall

import javax.inject.Inject
import play.api.libs.json.Json
import play.api.libs.ws.WSClient
import scala.concurrent.{ExecutionContext, Future}

class Client @Inject()(wsClient: WSClient) {
  def cardsCollection(req: CardsCollectionRequest)(implicit ec: ExecutionContext): Future[CardsCollectionResponse] =
    wsClient.url(CardsCollectionRequest.url)
      .post(Json.toJson(req))
      .map(_.json.as[CardsCollectionResponse])
}
```

While Guice could inject the client in controllers, the calls to Scryfall would impact response times. Instead, these calls should happen in the background.

## Actor


---

Done

{  "identifiers": [{"id": "683a5707-cddb-494d-9b41-51b4584ded69"},{"name": "Ancient Tomb"},{"set": "mrd","collector_number": "150" }  ]}
