---
tags: ["rust", "continuous integration", "continuous deployment"]
---

Based on [Are we web yet?](https://www.arewewebyet.org/), Rust is ready for web development. There are a lot of frameworks available. Most are to build backend services, but some are to develop frontends. That is right, you can write your next single-page application in Rust.

Bellow, I describe the steps needed to build, test, and deploy a Rust Wasm application on GitHub. When I say test and deploy, I do mean that GitHub will do the heavy lifting. It won't just host the source code.

Let's start with the Rust application.

# Hello, World!
I personally use [Yew](https://yew.rs/). This framework has good documentation, great examples, and is actively maintained. Their [getting started](https://yew.rs/getting-started/build-a-sample-app) is also easy to follow. I simplified it, a tiny bit, as I want to focus on Yew in another post.

Before we start, make sure you have all the required tools installed. This refers to Rust and Cargo, of course, but also the following:
```sh
cargo install trunk wasm-bindgen-cli
rustup target add wasm32-unknown-unknown
```

With that out of the way, let's create a Rust application.
```sh
cargo new rust-wasm-github
```

Then, add Yew as a dependency in `Cargo.toml`.
```toml
[dependencies]
yew = "0.18"
```

Next, replace `src/main.rs` with the following code.
```rust
use yew::prelude::*;

struct Index;
impl Component for Index {
    type Message = ();
    type Properties = ();

    fn create(_: Self::Properties, _: ComponentLink<Self>) -> Self {
        Self
    }

    fn update(&mut self, _: Self::Message) -> ShouldRender {
        false
    }

    fn change(&mut self, _: Self::Properties) -> ShouldRender {
        false
    }

    fn view(&self) -> Html {
        html! {
            <div>
                { "Hello, World!" }
            </div>
        }
    }
}

fn main() {
    yew::start_app::<Index>();
}
```

And finally, create an `index.html` file at the root of the project.
```html
<!DOCTYPE html>
<html>
    <head>
        <meta charset="utf-8" />
        <title>Hello, World!</title>
    </head>
</html>
```

All this should allow you to start your server and see the unavoidable hello world.
```sh
trunk serve
```

With a working application, let's move on to continuous integration.

# Continuous Integration
Rust is a safe language, but bugs can still sneak in. CI helps to catch those issues before they break anything. [GitHub Actions](https://github.com/features/actions) can easily do that.

There are three simple things to check with Rust code. The first is obviously tests, the second is the format, and the third is code smells with Clippy. All those can run in parallel to speed up the process.

```yaml
# in .github/workflows/continuous_integration.yml
name: Continuous integration
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v2
    - run: cargo test --all

  format:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v2
    - run: cargo fmt --all -- --check

  clippy:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v2
    - run: cargo clippy --all -- -D warnings
```

To wrap up CI, don't forget to add [branch protection rules](https://docs.github.com/en/github/administering-a-repository/defining-the-mergeability-of-pull-requests/managing-a-branch-protection-rule). Those will force pull requests to pass the checks. They help keep the main branch clean.

With that out of the way, we can look at continuous deployment.

# Continuous Deployment
Releasing updates can get in the way of actually writing code. Keeping the deployment simple helps, but automating it is even better. CD releases the latest commits straight to production, after CI of course.

Wasm applications are just a set of static files. There is no need for Docker or anything complex. [GitHub Pages](https://pages.github.com/) and Actions is all we need. The former to host the files and the latter to deploy them. This is quite easy, especially with the awesome work done by [actions-rs](https://github.com/actions-rs), [Jet Li](https://github.com/jetli), and [Shohei Ueda](https://github.com/peaceiris).

```yaml
# in .github/workflows/continuous_deployment.yml
name: Continuous deployment
on:
  workflow_run:
    branches: [main]
    workflows: [Continuous integration]
    types: [completed]

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions-rs/toolchain@v1
        with:
          toolchain: stable
          target: wasm32-unknown-unknown

      - uses: jetli/trunk-action@v0.1.0
      - uses: jetli/wasm-bindgen-action@v0.1.0

      - uses: actions/checkout@v2

      - run: trunk build --release

      - uses: peaceiris/actions-gh-pages@v3
        if: github.ref == 'refs/heads/main'
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./dist
```

The last remaining step is to [enable GitHub Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site). That will make the application available on `[GITHUB_USER_NAME].github.io/[GITHUB_REPOSITORY_NAME]`.

---

There you have it, these are all the steps required to build, test, and deploy a Rust Wasm application on GitHub. While I used Yew, you can build a similar pipeline with [Seed](https://seed-rs.org/) or any other framework.

To finish, if I was too quick or if you don’t want to implement the pipeline yourself, have a look at the [source code](https://github.com/plippe/rust-wasm-github/).
