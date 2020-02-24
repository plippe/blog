---
title: "Cross compiling Rust with Docker"
date: 2018-05-01

tags: ["rust", "docker"]
---

I haven’t played with embedded systems since college. My group, and I built a wonderful little vehicle. It could follow a line, traverse an obstacle course, and pick up balls along the way. Pretty standard for a college project, but still quite fun to build.

I am giving embedded systems another go with a side project of mine. The device has a single purpose. It captures network packets, and forwards them to a server. It is easily achieved with [LIBpcap](https://github.com/the-tcpdump-group/libpcap), but the device makes it interesting.

![GL-AR150](/images/2018/gl-ar150.jpeg)

The [GL-AR150](https://www.gl-inet.com/products/gl-ar150/) sells as a mini smart router. The limited storage makes it hard to install language interpreters, or virtual machines. This pushed me to look into standalone executables, and how to compile them for other devices.

I picked rust looking to learn a thing, or two. As I am still learning, I will limit the amount of code, and focus on building the executable.

Cargo, rust’s package manager, can create new projects.
```sh
mkdir hello-world && cd hello-world
cargo init --name hello-word
cargo run
```

The build command generates the executable. It should be compatible with all devices that share the architecture, vendor, operating system, and application binary interface. This information is called a triple.

Rust can build executables for many triples. Output the full list of targets with `rustc —-print target-list`.

The build step requires two things: the rust standard library, and a linker. Obtaining the standard library is easy with the `rustup` tool.

```sh
rustup target add TRIPLE
rustup target add mips-unknown-linux-musl # GL-AR150 triple
```

On the other hand, installing a linker can take a bit more effort.

In short, a linker bundles all dependencies for a specific device. Think of how each target must define their own `println`.

A compatible linker for the GL-AR150 is in the [OpenWrt’s SDK](https://archive.openwrt.org/chaos_calmer/15.05.1/ar71xx/generic/). The file is in the `staging_dir/toolchain-*/bin` directory. Sadly, only the linux SDK is available. If you need another version, you will have to build it from source.

Once a compatible linker is in your possession, configure cargo to use it. Create the `.cargo/config` file, and add the appropriate settings.

```sh
# .cargo/config
[target.TARGET_TRIPLE]
linker = "LINKER_PATH"
[target.mips-unknown-linux-musl]
linker = "mips-openwrt-linux-gcc"
```

If you haven’t missed a step, build should create the proper executable.

```sh
cargo build --release --target=mips-unknown-linux-musl
```

Repeating these steps on each machine, for each target, isn’t practical. But this is where docker shines.

[My docker image](https://github.com/plippe/rust-build-target) is a first step towards splitting the coding process from the building one. This allows me to focus on my application, and not on my environment. Once ready, I build the executable within a container. I no longer need to install dependencies locally.

```sh
docker run \
  --rm \
  --interactive \
  --tty \
  --volume ${PWD}:/opt/volume \
  --workdir /opt/volume \
  plippe/rust-build-target:gl-ar150 \
    cargo build --release --target=mips-unknown-linux-musl
```

GL-AR150 is my current objectives, but it could be interesting to see the idea pushed further. Who knows, future SDKs might just be docker images ?
