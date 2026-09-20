# Pants Profile

> Sources: https://github.com/pantsbuild/pants, https://www.pantsbuild.org/stable/docs/, https://github.com/pantsbuild/scie-pants, GitHub Releases API, researched 2026-09-18
> Not a derived document: facts here are externally sourced.

## 1. Product Profile

Pants is an open-source build system for monorepos, maintained by the `pantsbuild`
organization. Its README states: "Pants is a scalable build system for _monorepos_: codebases
containing multiple projects, often using multiple programming languages and frameworks, in a
single unified code repository." The docs landing page adds that it is "a fast, scalable,
user-friendly build and developer workflow system for codebases of all sizes."
(source: https://github.com/pantsbuild/pants/blob/main/README.md, 2026-09-18; source: https://www.pantsbuild.org/stable/docs/introduction/welcome-to-pants, 2026-09-18)

| Field | Value | Source |
|---|---|---|
| Repository | `github.com/pantsbuild/pants` | GitHub API, 2026-09-18 |
| License | Apache License 2.0 (SPDX `Apache-2.0`) | GitHub API, 2026-09-18 |
| Primary language (GitHub) | Python | GitHub API, 2026-09-18 |
| Latest stable release | `release_2.33.1`, published 2026-08-27 | GitHub Releases API, 2026-09-18 |
| Current development line | `2.34.0.dev3`, published 2026-08-18 | GitHub Releases API, 2026-09-18 |
| Docs version string | "Version: 2.33" on the stable docs site | pantsbuild.org/stable, 2026-09-18 |
| Default branch | `main` | GitHub API, 2026-09-18 |
| Repository created | 2012-12-17 | GitHub API, 2026-09-18 |
| Last push at research time | 2026-09-16 | GitHub API, 2026-09-18 |
| Stars / forks / open issues | 3829 / 723 / 1092 | GitHub API, 2026-09-18 |

The configuration surface is a single repository-level `pants.toml` file plus per-directory
`BUILD` files that declare targets. The repository root also carries `pants.ci.toml` and
`pants.remote-execution.toml` as separate configuration overlays for its own development.
(source: https://github.com/pantsbuild/pants, top-level tree, 2026-09-18)

Pants is distributed through an installer script that places a `pants` launcher binary on
the machine. The launcher is the `scie-pants` project, described in its own README as "the
next-generation `./pants` script" and "the recommended way to install Pants."
(source: https://www.pantsbuild.org/stable/docs/getting-started/installing-pants, 2026-09-18;
source: https://github.com/pantsbuild/scie-pants/blob/main/README.md, 2026-09-18)

The project is a first-generation-to-second-generation rewrite story. The docs describe the
current system as the "v2" engine, "completely new technology, built from the ground up,
based on lessons learned from working on the previous, 'v1', technology."
(source: https://www.pantsbuild.org/stable/docs/introduction/how-does-pants-work, 2026-09-18)

## 2. Technical Characteristics

### Overall Architecture

Pants is a two-language system with a hard split between an execution engine and a rule
layer: "The core of Pants is its execution engine, which sequences and coordinates all the
underlying work. The engine is written in Rust, for performance. The underlying work is
performed by executing _rules_, which are typed Python 3 async coroutines for familiarity
and simplicity." The split is deliberate, absorbing concerns that are expensive per rule:
"The engine is designed so that fine-grained invalidation, concurrency, hermeticity, caching,
and remote execution happen naturally, without rule authors needing to think about it."
Concurrency sits on Tokio: "The engine can take full advantage of all the cores on your
machine because relevant portions are implemented in Rust atop the Tokio framework."
(source: https://www.pantsbuild.org/stable/docs/introduction/how-does-pants-work, 2026-09-18)

The Rust engine is a single crate compiled as a native extension loaded by the Python
process. Its manifest declares `name = "engine"`, `edition = "2024"`, and
`crate-type = ["cdylib"]`. The binding layer is PyO3, and the engine README documents an
`extension-module` Cargo feature used to build `libengine.so`. Recent release notes list
"upgrade to PyO3 v0.29.2", and a dev-line entry reads "Run pants under free threaded python."
(source: https://github.com/pantsbuild/pants/blob/main/src/rust/engine/Cargo.toml, 2026-09-18; source: https://github.com/pantsbuild/pants/blob/main/src/rust/engine/README.md, 2026-09-18; source: https://github.com/pantsbuild/pants/releases/tag/release_2.34.0.dev3, 2026-08-18)

The Rust engine source is decomposed by scheduler concern rather than by language backend:
`interning.rs`, `scheduler.rs`, `session.rs`, `tasks.rs`, `types.rs`, `python.rs`,
`context.rs`, `downloads.rs`, plus the `externs/`, `intrinsics/`, and `nodes/` directories.
(source: https://github.com/pantsbuild/pants/tree/main/src/rust/engine/src, 2026-09-18)

The Python side mirrors that structure with graph-level primitives: `addresses.py`,
`collection.py`, `process.py`, `target.py`, `goal.py`, `environment.py`, `rules.py`,
`unions.py`, `fs.py`, `platform.py`, and `internals/`.
(source: https://github.com/pantsbuild/pants/tree/main/src/python/pants/engine, 2026-09-18)

Two runtime services sit outside the engine: `pantsd`, the daemon that "uses an in-memory
cache to speed up subsequent runs" and is tunable via `pantsd_max_memory_usage`; and the
self-bootstrapping launcher binary, which sources a repository-level `.pants.bootstrap` file
before any goal.
(source: https://www.pantsbuild.org/stable/docs/using-pants/using-pants-in-ci, 2026-09-18; source: https://www.pantsbuild.org/stable/docs/using-pants/key-concepts/options, 2026-09-18)

### Key Capabilities

The README enumerates the capability set: explicit dependency modeling, fine-grained
invalidation, shared result caching, concurrent execution, remote execution, a unified
interface for multiple tools and languages, and extensibility through a plugin API.
(source: https://github.com/pantsbuild/pants/blob/main/README.md, 2026-09-18)

The welcome page adds two items to that list: "Dependency modeling using static analysis
instead of handwritten metadata" and "Support for dependency lockfiles to prevent supply
chain attacks", plus "Code introspection features."
(source: https://www.pantsbuild.org/stable/docs/introduction/welcome-to-pants, 2026-09-18)

Dependency inference is the flagship differentiator. Pants "analyzes your code's import
statements to determine files' dependencies automatically," so a BUILD file can omit
`dependencies` entirely. The same page contrasts this with a Bazel-style `deps` list that
must be hand-maintained.
(source: https://www.pantsbuild.org/stable/docs/introduction/how-does-pants-work, 2026-09-18)

Hermeticity is the enforcement mechanism behind inference: "Dependency information is
required for precise change detection and cache invalidation, but inference means that you
don't need to declare dependencies manually (and hermetic execution guarantees that they
are always accurate)."
(source: https://www.pantsbuild.org/stable/docs/introduction/how-does-pants-work, 2026-09-18)

### Tech Stack

| Layer | Technology | Source |
|---|---|---|
| Engine | Rust, edition 2024, compiled as `cdylib` | `src/rust/engine/Cargo.toml`, 2026-09-18 |
| Concurrency | Tokio | how-does-pants-work, 2026-09-18 |
| Rule/plugin language | Typed Python 3 (async coroutines) | how-does-pants-work, 2026-09-18 |
| Rust/Python bridge | PyO3 (`extension-module` feature) | engine README + release notes, 2026-09-18 |
| Configuration | `pants.toml`, `BUILD` files, `.pants.bootstrap` | options and targets docs, 2026-09-18 |
| Launcher | `scie-pants` binary | scie-pants README, 2026-09-18 |
| Remote protocol | REAPI-compatible cache and execution server | remote-caching docs, 2026-09-18 |
| Runtime prerequisite | Linux x86_64/ARM64, macOS 10.15+, Windows 10 via WSL 2 | prerequisites, 2026-09-18 |

Pants bootstraps itself: "Internet access (so that Pants can fully bootstrap itself)" is
listed as a prerequisite, and a restricted-internet-access guide exists for air-gapped use.
(source: https://www.pantsbuild.org/stable/docs/getting-started/prerequisites, 2026-09-18)

## 3. Feature Overview

### Core Modules

The Rust engine modules are the scheduler core: `scheduler.rs` owns graph scheduling,
`nodes/` holds the graph node implementations, `intrinsics/` holds engine-native operations,
`interning.rs` deduplicates values, and `python.rs` bridges to the embedded interpreter.
(source: https://github.com/pantsbuild/pants/tree/main/src/rust/engine/src, 2026-09-18)

The Python `engine/` package is the rule-authoring surface: graph and target primitives
(`addresses.py`, `target.py`, `rules.py`, `unions.py`), process execution (`process.py`,
`composite_process.py`), environment modeling (`environment.py`, `platform.py`, `env_vars.py`),
and goal plumbing (`goal.py`).
(source: https://github.com/pantsbuild/pants/tree/main/src/python/pants/engine, 2026-09-18)

Language and tooling support lives under `src/python/pants/backend/`, whose tree contains
`python`, `go`, `java`, `scala`, `kotlin`, `shell`, `cc`, `docker`, `helm`, `k8s`,
`terraform`, `javascript`, `typescript`, `rust`, `codegen`, `build_files`, `awslambda`,
`google_cloud_function`, and `experimental`. Docker, Helm, Kubernetes, Terraform, C/C++,
JavaScript, TypeScript, and Scala sit behind experimental backends; the shipped-stable
language list is Python, Go, Java, Scala, Kotlin, and Shell.
(source: https://github.com/pantsbuild/pants/tree/main/src/python/pants/backend, 2026-09-18; source: https://www.pantsbuild.org/stable/docs/introduction/welcome-to-pants, 2026-09-18)

### Notable Features

- **Targets and BUILD files.** Targets are declared in files named `BUILD`, each target
  type has typed fields, and every target has a unique `name` within its directory.
  (source: targets-and-build-files, 2026-09-18)
- **Addresses.** Targets are addressed as `path/to/dir:name`, with relative `:name` allowed
  inside the same BUILD file, and `@` suffixes for parametrized targets.
  (source: targets-and-build-files, 2026-09-18)
- **`__defaults__`.** A BUILD file symbol that sets default field values for the subtree
  beneath it, with `extend=True` and `all` variants.
  (source: targets-and-build-files, 2026-09-18)
- **`parametrize`.** Generates one target per parametrized field value, with a Cartesian
  product across multiple fields, using `@` in the address.
  (source: targets-and-build-files, 2026-09-18)
- **Dependency suppression.** Inferred edges can be removed with `!` and `!!` prefixes on
  the `dependencies` field.
  (source: targets-and-build-files, 2026-09-18)
- **`adhoc_tool`.** "The `adhoc_tool` target allows you to execute 'runnable' targets inside
  the Pants sandbox." This is the documented escape hatch for integrating a new tool without
  writing a plugin.
  (source: https://www.pantsbuild.org/stable/docs/ad-hoc-tools/integrating-new-tools-without-plugins, 2026-09-18)
- **Goals.** Pants commands are called goals (`test`, `lint`, `fmt`, `fix`, `package`), and
  the active set grows as backends are enabled. Discovery is via `pants help goals`.
  (source: https://www.pantsbuild.org/stable/docs/using-pants/key-concepts/goals, 2026-09-18)
- **Outputs.** Pants can produce standalone binaries, Docker images, AWS Lambda zip files,
  and GCP Cloud Functions.
  (source: https://www.pantsbuild.org/stable/docs/introduction/welcome-to-pants, 2026-09-18)
- **Build Server Protocol.** `pants.backend.experimental.bsp` "Enables core Build Server
  Protocol ('BSP') support", listed as experimental.
  (source: https://www.pantsbuild.org/stable/docs/using-pants/key-concepts/backends, 2026-09-18)

### Extensibility / Plugin Mechanism

Pants states that extensibility is not a bolt-on: "In fact, all of Pants's built-in
functionality uses the same API!"
(source: https://www.pantsbuild.org/stable/docs/writing-plugins/overview, 2026-09-18)

The plugin API has exactly two interfaces:

1. **The Target API**: "a declarative interface for creating new target types and extending
   existing targets."
2. **The Rules API**: "where you define your logic and model each step of your build."

Both are written in typed Python 3, and the plugin runs inside the Rust engine: "You write
your logic in Python, and then Pants will run your plugin in the Rust engine."
(source: https://www.pantsbuild.org/stable/docs/writing-plugins/overview, 2026-09-18)

A backend is a Python package that implements hooks. A plugin contains one or more backends,
each with hooks defined in a `register.py` file. The documented hooks include `rules()` and
`target_types()`, and activation is by adding the backend package name to
`[GLOBAL].backend_packages` in `pants.toml`.
(source: https://www.pantsbuild.org/stable/docs/writing-plugins/overview, 2026-09-18)

In-repo plugins are loaded by putting their directory on `[GLOBAL].pythonpath`. The Pants
repository itself uses this pattern: `pythonpath = ["%(buildroot)s/pants-plugins"]` followed
by a `backend_packages.add` list containing `internal_plugins.releases` and
`internal_plugins.test_lockfile_fixtures`.
(source: https://github.com/pantsbuild/pants/blob/main/pants.toml, 2026-09-18)

Custom rules inherit the engine's guarantees: "your custom rules will run with the same
concurrency, caching, and remoting semantics as the core rules."
(source: https://www.pantsbuild.org/stable/docs/introduction/how-does-pants-work, 2026-09-18)

Plugin API stability is explicitly qualified. The docs say the API "is now considered
largely stable" but that it "is not officially subject to that policy yet." They recommend
conditional imports keyed on `PANTS_SEMVER` to support multiple Pants versions from one
plugin.
(source: https://www.pantsbuild.org/stable/docs/writing-plugins/overview, 2026-09-18)

## 4. Status & Ecosystem

**Release cadence.** The releases API at research time shows a steady line: `2.32.1`
(2026-06-27), `2.33.0` (2026-08-01), `2.33.1` (2026-08-27), plus a parallel dev line
`2.34.0.dev0` through `2.34.0.dev3` running from July through August 2026. Stable minor
releases and a nightly-style dev line coexist.
(source: GitHub Releases API, 2026-09-18)

**Repository activity.** Last push 2026-09-16, 3829 stars, 723 forks, 1092 open issues, no
archive flag. Recent commits touch JVM protobuf codegen resolution, Python interpreter
constraint inference from `pyproject.toml`, S3 URL signing, process-group management, and a
12-entry addition to the Python default module mapping.
(source: GitHub API and commit listing, 2026-09-18)

**Contribution norms and docs.** Commits carry explicit LLM assistance notices under a
published policy at `https://www.pantsbuild.org/dev/docs/contributions#llm-assistance-notice`.
The docs site is versioned, with a stable namespace at
`https://www.pantsbuild.org/stable/docs/` and separate `dev` docs; pages used here render
"Version: 2.33".
(source: commit 9d33d95ce5e83f2be3115772e777eedaa17aab73, 2026-09-14; source: pantsbuild.org, 2026-09-18)

**Backends.** Stable backends include BUILD file formatters (`black`, `buildifier`, `ruff`,
`yapf`), `pants.backend.awslambda.python`, `pants.backend.codegen.protobuf.python`,
`pants.backend.codegen.protobuf.lint.buf`, `pants.backend.codegen.thrift.apache.python`,
`pants.backend.docker`, and `pants.backend.docker.lint.hadolint`.
(source: https://www.pantsbuild.org/stable/docs/using-pants/key-concepts/backends, 2026-09-18)

Experimental backends include `pants.backend.experimental.bsp`, `.cc`,
`.cc.lint.clangformat`, `.codegen.protobuf.go`, `.codegen.protobuf.java`,
`.codegen.protobuf.scala`, `.codegen.avro.java`, `.codegen.thrift.apache.java`,
`.codegen.thrift.scrooge.java`, `.codegen.thrift.scrooge.scala`, `.cue`, and `.adhoc`.
(source: https://www.pantsbuild.org/stable/docs/using-pants/key-concepts/backends, 2026-09-18)

**Remote integration.** Remote caching is a stable, documented workflow: "Remote caching
allows Pants to store and retrieve the results of process execution to and from a remote
server, rather than only using your machine's local Pants cache." It speaks the Remote
Execution API, and a server compatibility guide exists.
(source: https://www.pantsbuild.org/stable/docs/using-pants/remote-caching-and-execution/remote-caching, 2026-09-18)

Remote execution carries a prominent warning: "Remote execution support is still
experimental. Remote execution support in Pants comes with several limitations. For example,
Pants requires that the server's operating system match the client's operating system."
(source: https://www.pantsbuild.org/stable/docs/using-pants/remote-caching-and-execution/remote-execution, 2026-09-18)

**Platform support.** Linux x86_64 and ARM64, macOS Intel and Apple Silicon (10.15 Catalina
or newer), and Windows 10 with WSL 2. Alpine Linux is explicitly not supported because Pants
for Linux ships as a manylinux wheel and Alpine uses MUSL libc.
(source: https://www.pantsbuild.org/stable/docs/getting-started/prerequisites, 2026-09-18)

**CI integration.** The docs publish a CI guide with recommended commands, target sharding,
and resource tuning options (`rule_threads_core`, `rule_threads_max`, `pantsd`,
`pantsd_max_memory_usage`), plus a runner resource table for GitHub Actions and other
providers.
(source: https://www.pantsbuild.org/stable/docs/using-pants/using-pants-in-ci, 2026-09-18)

## 5. Market Positioning

Pants positions itself as the low-ceremony monorepo build system with a scalability story
that does not require hand-written dependency metadata. The README claim is scalability for
monorepos; the welcome page claim is speed, scalability, and user-friendliness for
"codebases of all sizes."
(source: README and welcome page, 2026-09-18)

Its clearest stated contrast is against Bazel-style explicit dependency lists. The docs show
a Bazel `python_library` target with eight hand-written `deps`, then the Pants 2 equivalent:
`python_sources(name="lib")` and `python_tests(name="tests")`.
(source: https://www.pantsbuild.org/stable/docs/introduction/how-does-pants-work, 2026-09-18)

The audience is language-heterogeneous monorepos, but the shipped language list is
Python-forward: Python, Go, Java, Scala, Kotlin, and Shell. That list does not include
C or C++, and it does not include CMake, Meson, or Colcon as first-class build paths.
(source: https://www.pantsbuild.org/stable/docs/introduction/welcome-to-pants, 2026-09-18)

For C and C++ the repository ships only `pants.backend.experimental.cc`, with
`pants.backend.experimental.cc.lint.clangformat` for formatting. Both are in the
experimental backend list.
(source: https://www.pantsbuild.org/stable/docs/using-pants/key-concepts/backends, 2026-09-18)

Its differentiators against generic task runners are the engine properties that are hard to
retrofit: fine-grained invalidation, hermetic sandboxed process execution, shared local and
remote result caching, and rule-level parity between core and custom plugins.
(source: how-does-pants-work and plugins overview, 2026-09-18)

Its adoption cost is the metadata model: teams must write `BUILD` files, enable backends in
`pants.toml`, and accept that most functionality is opt-in through `[GLOBAL].backend_packages`.
The remote story is a two-tier offer: caching is stable and REAPI-compatible, execution is
experimental and constrained by an OS-match requirement.
(source: https://www.pantsbuild.org/stable/docs/using-pants/key-concepts/backends, 2026-09-18; source: remote-caching and remote-execution docs, 2026-09-18)

## 6. Product Highlights

1. **A native engine under a high-level rule language.** Rust owns scheduling, interning,
   nodes, and the Tokio concurrency pool; typed Python 3 owns the build logic. Rule authors
   get caching, concurrency, hermeticity, and remoting without writing for them.
   (source: how-does-pants-work, 2026-09-18)
2. **Dependency inference instead of dependency bookkeeping.** Import statements are
   analyzed to manufacture graph edges, and hermetic execution keeps those inferred edges
   honest. (source: how-does-pants-work, 2026-09-18)
3. **One plugin API for everything.** Built-in backends and third-party plugins use the same
   Target API and Rules API, so a custom backend inherits the engine's guarantees.
   (source: plugins overview, 2026-09-18)
4. **Fine-grained invalidation and shared caching.** Invalidation is a first-class engine
   property, and the cache can be local or a REAPI-compatible remote server.
   (source: how-does-pants-work and remote-caching, 2026-09-18)
5. **An escape hatch for unadapted tools.** `adhoc_tool` runs arbitrary runnable targets in
   the sandbox, which lets a team add a tool without a plugin.
   (source: ad-hoc-tools, 2026-09-18)
6. **Lockfiles and a maturity split.** The welcome page lists "Support for dependency
   lockfiles to prevent supply chain attacks"; the backends page publishes separate stable
   and experimental lists, so a C++ or BSP adopter knows the maturity level before enabling.
   (source: welcome-to-pants and backends page, 2026-09-18)

## 7. Value to PolyOrch

### [Adopt] Directly reusable

- **Two-layer engine split as an architectural blueprint.** Pants keeps the
  performance-critical scheduler in a native core and expresses build logic in a typed rule
  layer that runs on top of it. PolyOrch should mirror the separation, which its decided stack
  (Lua, see `decisions.md` D3) supports: keep graph scheduling, invalidation, and caching in
  the core, and express CMake / Xmake / Meson / Colcon adapter logic as declarations over
  that core rather than as ad-hoc scripts.
  (source: how-does-pants-work, 2026-09-18)
- **Process execution as the cache unit.** Pants caches the results of process execution and
  can store them remotely over REAPI. PolyOrch should model every adapter invocation
  (configure, build, test, package) as a hermetic process with declared inputs, environment,
  and outputs, so that "configure this CMake tree" or "xmake build this target" becomes a
  cacheable key rather than an opaque shell step.
  (source: remote-caching, 2026-09-18)
- **Hermetic sandboxing of every external tool call.** Pants runs rules in sandboxes and
  treats hermeticity as the guarantee that makes inference trustworthy. PolyOrch's adapters
  should run every external tool (xmake, cmake, meson, colcon, vcpkg, conan) in a declared
  sandbox so results are reproducible and cache keys are sound.
  (source: how-does-pants-work, 2026-09-18)
- **A registration hook for adapters, not a hard-coded registry.** Pants backends declare
  themselves through a `register.py`-style entry surface returning rules and target types,
  and enablement is a config list entry. PolyOrch adapters should register through one stable
  entry surface (`polyorch.toml` `adapters = [...]` or equivalent) instead of being branched
  on by name inside the core.
  (source: plugins overview, 2026-09-18)
- **An `adhoc_tool`-style escape hatch.** Pants ships a documented way to run an arbitrary
  runnable tool in the sandbox without writing a plugin. PolyOrch should offer the same for
  tools that do not yet have a first-class adapter, so adapter-less projects can still be
  orchestrated.
  (source: ad-hoc-tools, 2026-09-18)
- **Goal verbs as the CLI surface.** Pants exposes a uniform verb set (`test`, `lint`,
  `fmt`, `fix`, `package`) across languages and makes the set self-describing. PolyOrch
  should expose a single verb set across adapters so a user does not learn one command shape
  for Xmake and another for CMake.
  (source: goals, 2026-09-18)
- **Option precedence rules.** Pants resolves options as command-line flag, then environment
  variable, then config file, then default. PolyOrch should adopt the same precedence for
  `polyorch.toml` so CI overrides and local overrides behave predictably.
  (source: options, 2026-09-18)
- **Lockfile discipline for environments and dependencies.** Pants advertises lockfiles as a
  supply-chain control. PolyOrch already has `pixi.lock` and Xmake-managed `vcpkg` / `conan`
  dependency resolution; it should treat all of those lock artifacts as first-class, cache
  key inputs and expose a goal that verifies them.
  (source: welcome-to-pants, 2026-09-18)
- **Explicit stable-versus-experimental labeling.** Pants maintains two published backend
  lists instead of blurring maturity. PolyOrch should label each adapter (`cmake`, `xmake`,
  `meson`, `colcon`) with the same kind of maturity marker from the start.
  (source: backends, 2026-09-18)
- **Versioned documentation with a stable URL namespace.** Pants serves `/stable/` and
  `/dev/` docs from one project. PolyOrch should version its adapter documentation the same
  way so a spec change does not invalidate every external link.
  (source: pantsbuild.org, 2026-09-18)

### [Adapt] Reusable with modification

- **The PyO3-style embedded interpreter is too heavy by default.** Pants pays for its
  Python rule layer with a compiled `cdylib` native extension and an embedded CPython, which
  also constrains supported Python versions. PolyOrch's implementation language is **Lua**, shipped as an
  Xmake addon (see `decisions.md` D3), so an embedded CPython is not a risk here; adapt the
  "native core, expressive rule layer" idea, but choose the embedding mechanism deliberately.
  (source: engine Cargo.toml and plugins overview, 2026-09-18)
- **Per-directory BUILD files versus a single `polyorch.toml`.** Pants distributes metadata
  across per-directory `BUILD` files, which scales but is a second configuration language
  (Python-syntax target declarations). PolyOrch's stated config shape is `polyorch.toml` plus
  `xmake.lua`. Adapt the target-and-field model into config sections, or offer BUILD-like
  per-package manifests as an optional layer, but do not ship two mandatory metadata
  languages in v1.
  (source: targets-and-build-files, 2026-09-18; PolyOrch README, 2026-09-18)
- **Dependency inference belongs to the driven engine, not to PolyOrch.** Pants infers
  edges from import statements because it owns compilation. PolyOrch dispatches to Xmake,
  CMake, Meson, and Colcon, each of which already models its own dependency graph. Adapt the
  goal (precise change detection) by consuming each engine's own graph output, rather than
  reimplementing per-language import scanners.
  (source: how-does-pants-work, 2026-09-18)
- **Backend package naming should be re-shaped for adapters.** Pants uses
  `pants.backend.<domain>.<tool>`. PolyOrch should use an adapter-oriented namespace
  (`polyorch.adapter.cmake`, and so on) so the naming mirrors what the component actually
  does, rather than importing Pants's language-backend taxonomy wholesale.
  (source: backends, 2026-09-18)
- **Cache first, remote execution later.** Pants ships remote caching as the stable remote
  feature and marks remote execution experimental with an OS-match constraint. PolyOrch
  should adapt the two-tier rollout: adopt a content-addressed local and remote cache in v1,
  and treat distributed execution as a later, separately gated capability.
  (source: remote-caching and remote-execution docs, 2026-09-18)
- **The `pantsd` daemon is an optimization with real lifecycle cost.** Pants runs a
  long-lived daemon backed by an in-memory cache and exposes memory-tuning options for it.
  PolyOrch should adapt the idea only if profiling shows process startup dominates, and
  should prefer a filesystem cache plus explicit invalidation until then.
  (source: using-pants-in-ci, 2026-09-18)
- **Plugin version gating should become an adapter compatibility shim.** Pants recommends
  conditional imports keyed on `PANTS_SEMVER` so one plugin supports several versions.
  PolyOrch should provide an equivalent adapter API version contract, so an adapter written
  against v1 continues to load after the core advances.
  (source: plugins overview, 2026-09-18)
- **BSP-style IDE integration is worth adapting, not copying.** Pants ships experimental BSP
  support for editor and IDE integration. PolyOrch should consider an equivalent
  language-server or protocol bridge for adapter-driven projects, but should not block v1 on
  it.
  (source: backends, 2026-09-18)

### [Avoid] Known pitfalls / not applicable

- **Do not adopt Python as a mandatory plugin language by reflex.** Pants's model couples
  the rule layer to CPython through PyO3, which adds a large runtime dependency, a build-time
  native-compilation step, and a supported-Python-version constraint. Since PolyOrch's own
  language is `TBD`, committing to Python for adapters would import those costs before that
  decision is made.
  (source: engine README, Cargo.toml, and plugins overview, 2026-09-18)
- **Do not treat C/C++ as a Pants strength to emulate.** Pants's C and C++ support is
  `pants.backend.experimental.cc`, with only a clang-format linter companion. There is no
  CMake, Xmake, Meson, or Colcon backend in the repository backend tree. This is precisely
  the gap PolyOrch targets, so Pants is a model for engine mechanics, not for C/C++ build
  coverage.
  (source: backends page and backend tree listing, 2026-09-18)
- **Do not make remote execution a v1 dependency.** Pants states remote execution is
  experimental and requires the server operating system to match the client. Building
  PolyOrch's first release around distributed execution would inherit an unstable contract.
  (source: remote-execution, 2026-09-18)
- **Do not inherit the glibc-only platform assumption.** Pants for Linux ships as a
  manylinux wheel and Alpine/MUSL is explicitly unsupported. PolyOrch runs alongside Pixi,
  so the libc and platform matrix should be decided explicitly rather than copied from
  Pants's distribution choices.
  (source: prerequisites, 2026-09-18)
- **Do not ship an adapter API outside a deprecation policy.** Pants states its Plugin API is
  "largely stable" but "not officially subject to that policy yet." If PolyOrch publishes an
  adapter API, it should place it under a real compatibility and deprecation policy from the
  first release, so third-party adapters do not churn.
  (source: plugins overview, 2026-09-18)
- **Do not mirror the whole language matrix.** Pants ships Python, Go, Java, Scala, Kotlin,
  and Shell, with Docker, Helm, Kubernetes, Terraform, JavaScript, TypeScript, C/C++, and
  Scala sitting behind experimental backends. PolyOrch's core is C/C++-family orchestration
  through Xmake; cloning Pants's breadth would dilute the adapter model for no gain.
  (source: welcome-to-pants and backends pages, 2026-09-18)
- **Do not assume the launcher model transfers.** Pants depends on a self-bootstrapping
  launcher binary that needs internet access on first run and sources `.pants.bootstrap`
  before every goal. PolyOrch's distribution story, presumably tied to Pixi environments,
  should be designed on its own terms.
  (source: prerequisites, installing-pants, and options docs, 2026-09-18)

## Appendix: Anchor Confirmation

| Anchor field | README claim | Verified value | Source |
|---|---|---|---|
| Repository | `github.com/pantsbuild/pants` | Confirmed | GitHub API, 2026-09-18 |
| Version | 2.33.1 (2026-08-27) | Confirmed, tag `release_2.33.1`, published 2026-08-27 | GitHub Releases API, 2026-09-18 |
| License | Apache-2.0 | Confirmed, SPDX `Apache-2.0` | GitHub API, 2026-09-18 |
| Impl language | Python plus a Rust engine | Confirmed; GitHub primary language Python, Rust engine crate at `src/rust/engine` | GitHub API and engine tree, 2026-09-18 |
| Config | `pants.toml`, `BUILD` files | Confirmed in docs and repository root | targets, options, repo tree, 2026-09-18 |

No anchor claim was contradicted. Full primary source URLs appear inline in the sections above.

### Unverified or Out of Scope

- User-base size and adoption benchmarks are not stated in the primary sources reviewed and are omitted.
- Internal performance numbers (cache hit rates, build-time speedups) are not published as stable, citable figures in the sources reviewed and are omitted.
- Commercial support or hosted offerings are not described in the primary sources reviewed and are omitted.
