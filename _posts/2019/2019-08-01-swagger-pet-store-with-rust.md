---
tags: ["rust", "hyper", "swagger"]
---

> **Disclaimer:** The solution bellow works, but there are many cut corners. This is because I am learning Rust. Don’t hesitate to improve my solution in the comments, or [on GitHub](https://github.com/plippe/swagger-pet-store-rust).

Rust has been on my radar for a year, or two. I even wrote about it three times. The first post was about [cross compiling Rust code on docker]({{ site.baseurl }}{% post_url 2018/2018-05-01-cross-compiling-rust-with-docker %}). The other two were about [learning Rust with Exercism.io]({{ site.baseurl }}{% post_url 2018/2018-06-01-exercism-driven-learning %}).

Since then, I found many excuses that kept me from progressing, but this ends now. Say hello to my fourth Rust post.

To start, I will introduce Swagger, and its Pet Store example. Next, I will have a quick look at Rust’s web frameworks. Finally, I will create a web service that fulfills the Pet Store specification.

## Pet Store
[Swagger](https://swagger.io/) aims to reduce friction in building, and consuming APIs. Given an [OpenAPI specification](https://swagger.io/specification/), their tools can [generate code](https://swagger.io/tools/swagger-codegen/), [display documentation](https://swagger.io/tools/swagger-ui/), and [more](https://swagger.io/tools/).

Swagger offers a few examples to get started. Their most popular one is the [pet store](https://github.com/OAI/OpenAPI-Specification/blob/master/examples/v3.0/petstore.yaml). This version describes a way to create new pets, list them, or show a single one.

```sh
curl .../pets -d '{"id": 1, "name": "foo", "tag": "bar"}'
curl .../pets?limit=25
curl .../pets/1
```

My first Rust project could be a hello world, a todo application, or an original idea. Instead, I will jump in the deep end, and build this pet store.

## Web servers
[Are we web yet?](https://www.arewewebyet.org/) lists two groups of Rust web frameworks.

The first contains [Hyper](https://hyper.rs/), and [tiny_http](https://crates.io/crates/tiny_http). They are low-level frameworks that handle connections, requests, and responses. All other functionalities are missing.

The second has higher-level frameworks: [Actix-web](https://actix.rs/), [Rocket](https://rocket.rs/), and [many more](https://www.arewewebyet.org/topics/frameworks/). Often built on top of the previous group, they centralize common features in a need package.

The pet store is quite a simple project. The biggest hurdles are the routing, and JSON handling. This makes neither group attractive. The first would need extra work, but the second would make it too easy.

As I am here to learn, and I like the name, I chose Hyper.

## Hello world
The first step is to create a new Rust application. The simplest way to do so is with [Cargo](https://doc.rust-lang.org/stable/cargo/). The `init` command creates a new Cargo package in an existing directory, while `new` creates the directory too.

```sh
# Uncomment one of the following
# cargo new <path>
# cargo init
```

The command should create at least two new files: `Cargo.toml`, and `src/main.rs`. The first is the manifest, and the second is a simple hello world. `cargo run` will execute it.

```sh
cargo run
   Compiling <name> v0.1.0 (<path>)
    Finished dev [unoptimized + debuginfo] target(s) in 0.33s
     Running `target/debug/<name>`
Hello, world!
```

`Hyper` has a good [getting started guide](https://hyper.rs/guides/server/hello-world/). In short, there is a new dependency in `Cargo.toml`.

```toml
# In Cargo.toml
[dependencies]
hyper = "0.12.33"
```

And, `src/mains.rs` has more content.

```rust
# In src/mains.rs
extern crate hyper;

use hyper::rt::Future;
use hyper::service::service_fn_ok;
use hyper::{Body, Request, Response, Server};

fn hello_world(_req: Request<Body>) -> Response<Body> {
    Response::new(Body::from("Hello, world!"))
}

fn main() {
    let addr = ([127, 0, 0, 1], 3000).into();
    let new_svc = || service_fn_ok(hello_world);
    let server = Server::bind(&addr)
        .serve(new_svc)
        .map_err(|e| eprintln!("server error: {}", e));
    println!("Listening on http://{}", addr);
    hyper::rt::run(server);
}
```

`cargo run` will start the server on the port 3000.

```sh
curl localhost:3000
Hello, world!
```

## Router
Hyper doesn’t come with a built-in routing logic. [The echo example](https://hyper.rs/guides/server/echo/) suggests to pattern match the request’s method and path.

```rust
match (req.method(), req.uri().path()) {
  (&Method::GET, "/") => {
    *response.body_mut() = Body::from("Try POSTing data to /echo");
  },
  (&Method::POST, "/echo") => {
    // we'll be back
  },
  _ => {
    *response.status_mut() = StatusCode::NOT_FOUND;
  },
};
```

Pattern matching strings only work for static URLs. Those containing variables, like `/pets/{petId}`, need a bit more logic. Splitting the string on the slash character, `/`, returns matchable segments, and extractable variables.

```rust
fn get_method<A>(req: &Request<A>) -> &Method {
  req.method()
}

fn get_path_segments<A>(req: &Request<A>) -> Vec<&str> {
  req.uri().path().trim_matches('/').split('/').collect()
}

match (get_method(&req), get_path_segments(&req).as_slice()) {
  (&Method::GET, ["pets"]) => {
    let body = "GET /pets";
    Response::builder().body(Body::from(body))
  }
  (&Method::POST, ["pets"]) => {
    let body = "POST /pets";
    Response::builder().body(Body::from(body))
  }
  (&Method::GET, ["pets", pet_id]) => {
    let body = format!("GET /pets/{}", pet_id);
    Response::builder().body(Body::from(body))
  }
  _ => Response::builder()
    .status(StatusCode::NOT_FOUND)
    .body(Body::empty()),
}
```

The specification requires `pet_id` to be a `String`. Other types would need more code, but not in this example.

The last missing router pieces are the query arguments. `listPets` has a `limit` parameter, and another to paginate results. The latter isn’t in the specification but will be available in the `x-next` header.

```rust
use std::str::FromStr;

fn get_query_parameter<A, B: FromStr>(
  req: &Request<A>,
  parameter_name: &str,
) -> Option<B> {
  req.uri()
    .query()
    .unwrap_or("")
    .split('&')
    .map(|name_value| name_value.split('=').collect())
    .flat_map(|name_value: Vec<&str>| match name_value.as_slice() {
      [name, value] => vec![(name.to_string(), value.to_string())],
      [name] => vec![(name.to_string(), "true".to_string())],
      _ => vec![],
    })
    .find(|(name, _)| name == parameter_name)
    .and_then(|(_, value)| value.parse::<B>().ok())
}

match (get_method(&req), get_path_segments(&req).as_slice()) {
  (&Method::GET, ["pets"]) => {
    let limit = get_query_parameter(&req, "limit")
      .unwrap_or(25);
    let offset = get_query_parameter(&req, "offset")
      .unwrap_or(0);
    let x_next = format!(
      "/pets?limit={}&offset={}",
      limit,
      limit + offset,
    );
    let body = "GET /pets";
    Response::builder()
      .header("x-next", x_next)
      .body(Body::from(body))
  }
  (&Method::POST, ["pets"]) => {
    let body = "POST /pets";
    Response::builder().body(Body::from(body))
  }
  (&Method::GET, ["pets", pet_id]) => {
    let body = format!("GET /pets/{}", pet_id);
    Response::builder().body(Body::from(body))
  }
  _ => Response::builder()
    .status(StatusCode::NOT_FOUND)
    .body(Body::empty()),
}
```

With the routing in place, I can look at returning proper responses, and reading incoming ones.

## JSON
Before even looking at JSON, I can create structures to represent the models.

```rust
struct Pet {
  id: u64,
  name: String,
  tag: Option<String>,
}

struct Pets {
  items: Option<Vec<Pet>>,
}

struct Error {
  code: u32,
  message: String,
}
```

Writing my serializer is a bad move. I shouldn’t reinvent the wheel. Hyper might not ship with JSON support, but that isn’t an issue with [Serde](https://serde.rs/) around.

```rust
use hyper::http::header::CONTENT_TYPE;
use serde::Serialize;

#[derive(Serialize)]
struct Pet {
  id: u64,
  name: String,
  tag: Option<String>,
}

let json = serde_json::to_string(&pet).unwrap();
Response::builder()
  .header(CONTENT_TYPE, "application/json")
  .body(Body::from(json))
```

With the output returning valid JSON, the next part is about the input.

Hyper represents payloads as a stream of bytes. It reads them asynchronously making their content available in `Future`s. This affects return types. It forces `Box<Future<... Response<A> ...>` instead of `Result<Response<A>>`.

```rust
use futures::{Future, Stream};

type FutureResponse<A> =
  Box<dyn Future<Item = Response<A>, Error = hyper::Error> + Send>;

let res: FutureResponse = Box::new(req.into_body()
  .concat2()
  .map(|body| {
    Response::builder()
      .status(StatusCode::OK)
      .body(Body::from(body))
      .unwrap()
  }));
```

With the `body` available, Serde can deserialize it.

```rust
use serde::{Deserialize, Serialize};

#[derive(Deserialize, Serialize)]
struct Pet {
  id: u64,
  name: String,
  tag: Option<String>,
}

let res = req
  .into_body()
  .concat2()
  .map(|body| serde_json::from_slice::<Pet>(&body).unwrap())
  .map(|pet| {
    let json = serde_json::to_string(&pet).unwrap();
    Response::builder()
      .header(CONTENT_TYPE, "application/json")
      .body(Body::from(json))
      .unwrap()
  });

Box::new(res)
```

With all the bricks defined, the Swagger specification is no longer hard to implement.

---

And this concludes my first real Rust project. The full code is available on [GitHub](https://github.com/plippe/swagger-pet-store-rust), but I wouldn’t recommend it. It is quite unsafe, with `unwrap` in many places. The variable ownership and references are probably wrong. It also lacks basic functionalities, like database interactions.

I seem to have plenty more to learn, and that is exciting. I look forward to improving this project as I get better.
