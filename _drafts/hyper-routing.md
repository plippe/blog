# Hyper routing
Disclaimer: The solution bellow works, but there are many cut corners. This is because I am learning Rust. Don't hesitate to improve my solution in the comments.

Hyper is a simplistic  Rust web framework. I used it to create an API for Swagger's pet store example. This forced me to implement a few features that were missing. 

In this post, I will be building a router for Hyper. I will start by looking at other frameworks. This will help me identify  common functionalities. Next, I will implement them with my limited Rust knowledge. By the end, I will have a generic routing mechanism for my future Hyper projects.

## Web framework routers
Most web frameworks share common features to route incoming requests. Bellow are some of those that I found.

### Path matching
The request's path is used to identify the function to handle the request. The path can be matched to a string, a regular expression, or a simplified templating language. 
```python
# Django
from django.urls import path
urlpatterns = [
  path('users', ...),
  path('users/<int:id>', ...),
  re_path(r'^users/(?P<id>\d+)/$', ...),
  ...
]
```

Highlighted sub strings can also be extracted. Their value might need to be cast to the appropriate type.

```rust
// Rocket
#[get("/hello/<name>")]
fn hello(name: &RawStr) -> String {
    format!("Hello, {}!", name.as_str())
}
```

### HTTP method matching
The request's HTTP method can also be used to identify the handler function. Helpers allow to match a single method, multiple, or all.

```php
// Laravel
Route::get('/users', function() {});
Route::post('/users', function() {});
Route::match(['put', 'patch'], '/users/{id}', function() {});
Route::any('/', function() {});
```

### Query argument matching
The framework can extract query arguments. Those are then available in the handler similarly to path arguments. 

```scala
// http4s
import org.http4s.dsl.impl.{
  QueryParamDecoderMatcher => QPDM,
}

object Limit extends QPDM[Ing]("limit")
object Offset extends QPDM[Ing]("offset")
HttpRoutes.of[IO] {
  case GET -> Root / "users" => ???
  case GET -> Root / "users" :? Limit(l) :+ Offset(o) => ???
}
```

Those features, and the many others that I have skipped, can be split into 3 categories detailed below.

## Matcher
There is an obvious need to match an incoming request with a function that should handle it. 
The examples above use one or more simple elements of the request to find the appropriate handler. Helpers can assist with obvious candidates, like method, path, and headers. Obscure requirement require a more generic approach.

```rust
struct Matcher(Box<dyn Fn(&u8) -> bool>);
impl Matcher {
  // Composition
  fn all(ms: Vec<Self>) -> Self {
    Self(Box::new(move |req| ms.iter().all(|m| m.0(req)) ))
  }
  fn and(m0: Self, m1: Self) -> Self {
    Self::all(vec!(m0, m1))
  }
  fn any(ms: Vec<Self>) -> Self {
    Self(Box::new(move |req| ms.iter().any(|m| m.0(req)) ))
  }
  fn or(m0: Self, m1: Self) -> Self {
    Self::any(vec!(m0, m1))
  }
  // Helpers - path
  fn path(path: str)
  fn path_matches(path: Regex)
  // Helpers - method
  fn get() -> Self
  fn post() -> Self
  // Helpers - other
  fn has_query_argument(name: str)
  fn has_header(name: str)
  fn has_cookie(name: str)
}
```

Given a list of Routes, the first match handle the request. If no route is matched, the server should return a  404.

## Extracter
Requests contain a certain amount of useful information. Extracting it is necessary to properly handle those requests.

Instead of writing this logic in the handler, it can be on it's own. This helps keep the handler logic free of a lot of boilerplate.

Once again helpers can reduce the amount of lines, but only a generic approach can support all edge cases. 

```rust
trait Extractor<A>(req)-> Result<A>
```

The distinction between Matcher, and Extractor is important. It allows to differentiate missing endpoints from unprocessable requests. This results in a 422 versus a 404.

## Ease of use

## Putting it together

List of routes
Find based on constraints or 404
Extract arguments or 422
Call handler or 500
