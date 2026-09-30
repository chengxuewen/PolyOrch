# PolyOrch Tutorials

> Hands-on learning path for the PolyOrch CMake helper surface. Every command
> below is proven by the repository's own examples and test suites; the
> canonical commands block in `.agents/memorys/conventions.md` is the runner
> source of truth for gates.

> **A scalable build orchestrator for polyglot monorepos.**
>
> *Adapter-based integration for heterogeneous build systems, environments, and package managers.*

---

## Who this is for

- **New users**: follow [Getting Started](#1-getting-started) top to bottom —
  no Rust, no pixi needed for the first configure.
- **Rust developers embedding PolyOrch**: jump to
  [Your First Rust Build](#2-your-first-rust-build), then pick your binding
  story from the [Bindings track](#3-bindings-track-one-crate-many-languages).
- **Monorepo owners**: [Embedding into a host project](#5-embedding-into-a-host-project)
  covers the namespace grammar, prefix overrides, and the debug surface.

---

## 1. Getting Started

### 1.1 What you need

| Requirement | When |
|---|---|
| CMake >= 3.22 | always |
| A C/C++ toolchain | for the C/C++ halves of the examples |
| cargo/rustc on PATH | rust examples (system route) |
| pixi | only the pixi-route examples (`-DPolyOrch_EXAMPLE_ROUTE=pixi`); everything else is offline-capable |

### 1.2 Configure the examples tree

```bash
# from the repository root
cmake -S examples -B build-examples -DPolyOrch_BUILD_RUST_EXAMPLES=ON
```

What happens:

- the fused rust examples register their real verb targets in the tree
  (namespace `polyorch-<directory>-...`, D28);
- a rust example whose toolchain is unreachable degrades to a STATUS note and
  registers nothing — no hard failure, no partial configure;
- with `-DPolyOrch_BUILD_PIXI_EXAMPLES=ON` the pixi buttons join (they may
  reach the network on first click).

### 1.3 Build and run the first target

```bash
cmake --build build-examples --target polyorch-rust-basic-greet-build
cmake --build build-examples --target polyorch-rust-basic-greet-run
# → hello, world!
```

The `-run` wrapper is a real CMake target: it builds its mediator first
(`polyorch-rust-basic-greet-build`) and then executes the artifact. In an IDE
target picker everything sits under `FOLDER` groups (`examples/rust-basic`,
...), so the list stays navigable at 50+ targets.

### 1.4 One command for the whole family

Every fused example has an aggregate:

```bash
cmake --build build-examples --target polyorch-rust-basic-all
```

---

## 2. Your First Rust Build

The minimal user-side CMake is three calls:

```cmake
cmake_minimum_required(VERSION 3.22)
project(demo LANGUAGES CXX)

list(APPEND CMAKE_MODULE_PATH "/path/to/PolyOrch/cmake")
include(PolyOrchRustHelpers.cmake)
include(PolyOrchFindRust.cmake)

polyorch_rust_setup()          # locate the toolchain (system PATH by default)
polyorch_rust_build(
    TARGET  greet              # the CMake target name you will build
    PACKAGE greet-cli          # the [[package]] name in Cargo.toml
    CRATE   greet-cli
    BINARY                     # export the binary as an imported target
    MANIFEST "${CMAKE_SOURCE_DIR}/Cargo.toml")
```

```bash
cmake -S . -B build && cmake --build build --target greet
```

Key facts:

- `polyorch_rust_setup()` has two routes: **system** (default — cargo from
  PATH, `~/.cargo/bin` included) and **pixi** (`FROM pixi ...` — the
  toolchain is delivered by a pixi environment; see §6).
- `polyorch_rust_build` exports `greet` as an IMPORTED target whose location
  is generator-expression driven; link it from C/C++ with
  `target_link_libraries(myapp PRIVATE greet)`.
- Verb wrappers: `polyorch_rust_test` (`cargo test` as a non-default
  target), `polyorch_rust_run` (`-run` wrapper: build + execute),
  `polyorch_rust_clean` (artifact scrub), `polyorch_rust_import` (existing
  workspace import), `polyorch_rust_install` (+`EXPORT`), and the
  `polyorch_rust_set_features` / `set_env_vars` / `add_rustflags` /
  `add_cargo_flags` steering set.

### 2.1 Steering one package

`examples/rust-profile-features` exercises all five knobs on ONE package:

```cmake
polyorch_rust_build(TARGET demo PROFILE RELEASE ...)       # or DEBUG (default)
polyorch_rust_set_features(TARGET demo ENABLE foo DISABLE bar)
polyorch_rust_set_env_vars(TARGET demo VALUES "APP_EPOCH=42")
polyorch_rust_add_rustflags(TARGET demo "$<$<CONFIG:Debug>:-Cpanic=abort>")
polyorch_rust_add_cargo_flags(TARGET demo --timings)
```

A compile-time `env!` bake means a handle missing its env var fails to
compile — the env contract is enforced by the compiler, not by review.

### 2.2 Cross-compiling in one graph

```bash
rustup target add x86_64-unknown-linux-musl
cmake -S examples/rust-cross -B build \
    -DPolyOrch_RUST_CARGO_TARGET=x86_64-unknown-linux-musl
```

Every handle routes through `--target` (artifacts nest under
`.cargo-target/<triple>/`); `polyorch_rust_set_hostbuild` opts one handle
back out to the host layer — device binary + build-machine binary in one
configure.

---

## 3. Bindings Track: One Crate, Many Languages

PolyOrch's binding examples share one `spine` crate shape and differ in the
foreign surface. Read order: basic → mixed → flagship → language triangle.

### 3.1 C, both directions — `rust-link-c`

```bash
cmake -S examples/rust-link-c -B build
cmake --build build --target cli-user-tool-build
```

Direction 1: a C executable links a Rust C-ABI staticlib (the toolchain's
system libs attach automatically via the native-static-libs probe).
Direction 2: a Rust binary links a C staticlib through
`polyorch_rust_link_libraries` (the -L/-l conversion).

### 3.2 The flagship — `rust-bindings` (cxx + cbindgen)

```bash
cmake -S examples/rust-bindings -B build
cmake --build build --target polyorch-rust-bindings-app       # C++ calls Rust, Rust calls back
cmake --build build --target polyorch-rust-bindings-consumer  # install(EXPORT) → find_package consumer
```

One crate, two foreign surfaces:

- a `#[cxx::bridge]` C++ surface (both directions), consumed by a real C++
  executable;
- a `#[no_mangle] extern "C"` surface documented by cbindgen, installed via
  `polyorch_rust_install(... EXPORT spine-demo PUBLIC_HEADER ...)` and
  consumed by a separate `find_package(spine-demo CONFIG REQUIRED)` project.

The example is also the only one exercising `polyorch_rust_clean` and
`polyorch_rust_package_version`.

Four cxx hard rules (learned the hard way, PIT-32; also commented in the
examples):

1. extern "Rust" implementations live in the SAME FILE as the bridge
   declaration;
2. `Box<C++ type>` is unsupported — factories belong on the C++ side, values
   cross as `UniquePtr`;
3. keep hand-written shims free of `rust::` types on version-skewed
   registries (the generated cxx.h and the crate may disagree on
   `rust::deleter_if`);
4. `#[cxx::bridge(namespace = "...")]` makes the generated trampoline resolve
   `::`-qualified symbols — the wrapper class sits in the global namespace,
   the wrapped library keeps its own.

### 3.3 The language triangle

| Example | Language | Shape |
|---|---|---|
| `rust-pyext` | Python (PyO3) | abi3-py38 cdylib (no interpreter headers, no libpython); demo runs through the resolved interpreter; `LANGUAGE_PRODUCT python` renames the artifact to its import name |
| `rust-nodejs` | Node.js (napi-rs) | N-API stable ABI = a plain cargo cdylib (no node headers, no node link); `LANGUAGE_PRODUCT node` → `spine-node.node`; demo `require()`s it (system node, or a pixi env's via `-DPolyOrchRustNodeExe=`) |
| `rust-wasm` | Web (wasm-pack) | standard `pkg/` npm deliverable in two flavors: `pkg-web/` (bundler, the web/vite deliverable) and `pkg-node/` (the local demo). On restricted egress: `--dev --mode no-install` plus a pixi binaryen env for wasm-opt |

Each language example degrades to STATUS notes when its runtime (python /
node / wasm toolchain) is missing — the artifact legs still configure.

---

## 3.5 The Node/Frontend Bridge (npm · pnpm workspaces)

```bash
cmake -S examples/node-web -B build          # standalone (REQUIRED: node+pm needed)
# fused: -DPolyOrch_BUILD_RUST_EXAMPLES=ON pulls node-web into the host graph
cmake --build build --target scope-hello-js-run-hello   # a one-shot script verb
```

`polyorch_node_import` reads a root `package.json`'s `workspaces` globs and
registers one `-build` mediator per member — the `workspace:*` dependency
between `@scope/hello-js` and `hello-ts` becomes a real CMake dependency
edge (building hello-ts builds hello-js first). Design boundaries (D29,
eight user-adjudicated rulings):

- **corepack abstraction**: the project's own `packageManager` field picks
  npm/pnpm; PolyOrch never pins. Command shapes differ by PM (`npm run build
  -w <pkg>` vs `pnpm --filter <pkg> run build`) — dispatched internally.
- **dist/ convention**: artifacts live in `<pkg>/dist/` (OUTPUT_DIR
  overrides); entry file resolved main → module → exports["."].
- **one-shot verbs only**: a long-lived dev server is not the build graph's
  job. `polyorch_node_run(TARGET x SCRIPT <name>)` runs `npm run <script>`.
- **scripts dispatch only**: PolyOrch never invokes tsc/vite — the
  package's own scripts ARE the build (the whitepaper's "does not compile
  code itself" clause).
- **three-tier discovery**: `-DPolyOrchNodeExe=` > PATH > pixi env glob,
  then STATUS degradation (nvm users: `nvm use` before configuring).
- **naming**: npm scopes sanitize to CMake-safe handles
  (`@scope/hello-js` → `scope-hello-js`; add_custom_target rejects
  '@'-headed names — measured). Fused trees namespace everything
  `polyorch-node-web-...` via `PolyOrch_NODE_TARGET_PREFIX` (the node
  face's own knob — the name says NODE and means NODE).

---

## 4. pixi Environments

pixi is the environment manager face: declare the environment in CMake,
materialize it, and run its tools.

### 4.1 Cold start (no pixi installed)

```bash
cmake -P examples/pixi-bootstrap/bootstrap.cmake          # may reach the network
# domestic network: add -DPIXI_PIN=<version> -DPolyOrch_PIXI_MIRROR=cn
```

Three phases: locate/install the pixi binary (`polyorch_pixi_tool_ensure`),
solve + install the environment with lock-drift recovery, smoke-run a task.

### 4.2 Read-only consumption and workspaces

```bash
cmake -S examples/pixi-configure -B build    # find + setup(REPORT) during configure
cmake -S examples/pixi-workspace -B build    # the workspace declared in CMake itself
```

`polyorch_pixi_init` declares name/version/channels/platforms in CMake — no
external `pixi.toml` needed; env storage redirects via `ENVIRONMENTS_DIR`;
activation scripts install beside `.pixi/`.

### 4.3 Any tool through an environment

`pixi-env-run` materializes an env carrying ANY tool (the demo uses `cmake`
itself) and runs env tools from configure and build targets via
`polyorch_pixi_env_paths`. First run solves; later runs are stamped no-ops.

---

## 5. Embedding into a Host Project

### 5.1 add_subdirectory

```cmake
# host CMakeLists.txt
set(PolyOrch_BUILD_RUST_EXAMPLES ON)              # pull the examples into the host graph
if(NOT TARGET PolyOrch::PolyOrch)                 # embed sentinel (D27)
    add_subdirectory(PolyOrch)
endif()
```

Fused targets register under `polyorch-<directory>-...` so the host namespace
never carries bare crate-ish names.

### 5.2 Multiple checkouts / nested embeddings

Each embedding project names its own instance — set the key **in the
embedding scope, before add_subdirectory**:

```cmake
# project B embedding its own PolyOrch copy:
set(B_POLYORCH_TARGET_PREFIX "po-b")              # B's fused targets: po-b-...
add_subdirectory(vendor/PolyOrch)
```

A nested PolyOrch copy flips `project(PolyOrch)` inside its own scope and
reads its own keys, so the outer host's value cannot hijack it (verified by
the nested-anti-hijack smoke, 2026-09-30). Empty string disables the prefix.

### 5.3 Debugging in VSCode

```bash
cmake -S examples -B build-examples -DPolyOrch_BUILD_RUST_EXAMPLES=ON \
    -DPolyOrch_RUST_VSCODE_DEBUG=ON
```

`<workspace root>/.vscode/` gains a managed block in `launch.json` +
`tasks.json`: one CodeLLDB launch per `polyorch_rust_run` target, F5 =
incremental build of the real orchestrated artifact, then debug. Managed
regions regenerate in place; your own configs are preserved byte-for-byte.
Wrong workspace root: pass `PolyOrch_RUST_VSCODE_DIR=<root>/.vscode`. CLion /
Qt Creator manual setup: see `examples/README.md` §"Other IDEs".

---

## 6. Route Matrix: system vs pixi

Every rust example carries BOTH routes: the default configure is the system
route; adding `-DPolyOrch_EXAMPLE_ROUTE=pixi` (+`-DPolyOrch_PIXI_MIRROR=cn`
on a domestic network) re-runs the SAME example with the toolchain delivered
by a pixi env. The pixi-route buttons (`polyorch-rust-import-pixi`,
`polyorch-rust-link-c-pixi`) encode this.

## 7. Running the Test Suites

```bash
bash tests/run.sh                                  # offline suite
POLYORCH_TEST_E2E=1 bash tests/run.sh              # + e2e legs (system toolchain)
bash tests/matrix.sh                               # generator × config matrix
bash scripts/ctest.sh                              # ctest entry (indirect configure)
bash scripts/gate.sh                               # the full gate: C1-C6 + suites
```

Capability-gated cases print `SKIP` with a reason (missing pixi / node /
wasm toolchain); the offline suite is green on a bare toolchain host.

## 8. Where to Go Next

| Want | Read |
|---|---|
| The module contract (what functions promise) | [docs/modules/01-contract.md](./modules/01-contract.md) |
| Error model & degradation philosophy | [docs/modules/03-error-model.md](./modules/03-error-model.md) |
| Architecture baseline | [docs/architecture.md](./architecture.md) |
| Per-example details | `examples/README.md` (the authoritative example table) |
| Testing strategy | [docs/modules/04-testing-strategy.md](./modules/04-testing-strategy.md) |
| Internals reference | [docs/modules/00-overview.md](./modules/00-overview.md) |
