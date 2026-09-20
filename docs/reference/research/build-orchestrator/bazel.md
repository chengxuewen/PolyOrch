# Bazel Profile

> Sources: https://github.com/bazelbuild/bazel, https://github.com/bazelbuild/bazel/releases,
> https://bazel.build/about/intro, https://bazel.build/about/faq, https://bazel.build/reference/glossary,
> https://bazel.build/concepts/build-ref, https://bazel.build/concepts/dependencies,
> https://bazel.build/run/build, https://bazel.build/run/bazelrc, https://bazel.build/remote/rbe,
> https://bazel.build/remote/caching, https://bazel.build/external/module, https://bazel.build/external/registry,
> https://bazel.build/external/migration, https://bazel.build/extending/concepts, https://bazel.build/extending/rules,
> https://bazel.build/rules/language, https://bazel.build/release/versioning,
> https://github.com/bazelbuild/remote-apis. Researched 2026-09-18.
> Not a derived document: facts here are externally sourced.

---

## 1. Product Profile

Bazel is an open-source build and test tool from Google, positioned by its own documentation as similar in
category to Make, Maven, and Gradle (source: https://bazel.build/about/intro, 2026-09-18). Its repository
describes it as "a fast, scalable, multi-language and extensible build system"
(source: https://github.com/bazelbuild/bazel, 2026-09-18). It was designed to fit the way software is
developed at Google, and is the open counterpart of an internal system that targets one large
mono-repository with many languages (source: https://bazel.build/about/faq, 2026-09-18).

| Field | Value | Source |
|---|---|---|
| Repository | `github.com/bazelbuild/bazel` | (source: https://github.com/bazelbuild/bazel, 2026-09-18) |
| Latest stable | 9.2.0, released 2026-07-13 | (source: https://github.com/bazelbuild/bazel/releases, 2026-09-18) |
| LTS maintenance line | 8.8.0, released 2026-08-31 | (source: https://github.com/bazelbuild/bazel/releases, 2026-09-18) |
| License | Apache-2.0 | (source: https://raw.githubusercontent.com/bazelbuild/bazel/master/LICENSE, 2026-09-18) |
| Implementation language | Java and C++ | Verified anchor, `docs/reference/README.md` (2026-09-18) |
| Configuration | Starlark `BUILD` files, `MODULE.bazel` | Verified anchor, `docs/reference/README.md` (2026-09-18) |
| Supported hosts | Ubuntu Linux, macOS, Windows | (source: https://bazel.build/about/intro, 2026-09-18) |

Bazel originated inside Google as an internal build system. The official glossary defines its predecessor
directly: "Blaze: The Google-internal version of Bazel. Google's main build system for its mono-repository."
(source: https://bazel.build/reference/glossary, 2026-09-18). Bazel is that system released as open source,
and the public documentation is explicit that parts of the codebase are still refactored against internal
extensions, which limits how much development happens in the open
(source: https://bazel.build/about/faq, 2026-09-18).

The product's core promise is large-scale, multi-language, multi-platform builds with correct incremental
rebuilds. The FAQ frames it as multi-language support, a high-level build language, and multi-platform
support in one tool (source: https://bazel.build/about/faq, 2026-09-18). The intro page adds that it
supports large codebases across multiple repositories and large numbers of users
(source: https://bazel.build/about/intro, 2026-09-18).

Two attributes drive everything else in this profile:

1. **One build language for the whole repository.** Projects describe themselves in `BUILD` files written
   in Starlark (source: https://bazel.build/about/faq, 2026-09-18).
2. **Correct incremental work through hermetic, content-addressed actions.** Bazel caches all previously
   done work and tracks changes to both file content and build commands
   (source: https://bazel.build/about/intro, 2026-09-18).

---

## 2. Technical Characteristics

### Overall Architecture

A Bazel build proceeds through three phases, as defined in the official glossary: the **loading phase**
executes `BUILD` files to create packages, the **analysis phase** has rule targets exchange information
and register actions, and the **execution phase** runs those actions
(source: https://bazel.build/reference/glossary, 2026-09-18). Loading and analysis are described as
interleaved while the target graph is built up (source: https://bazel.build/reference/glossary, 2026-09-18).

The central runtime artifact is the **action graph**: an in-memory graph of actions and the artifacts
they read and generate, produced during analysis and consumed during execution
(source: https://bazel.build/reference/glossary, 2026-09-18). Because Bazel tracks both file content and
action definitions, it can decide what must be rebuilt and rebuild only that
(source: https://bazel.build/about/intro, 2026-09-18).

The source tree is organized as **repositories** inside a **workspace**. A repository is a directory tree
with a boundary marker at its root (`MODULE.bazel`, `REPO.bazel`, or, in legacy contexts, `WORKSPACE` or
`WORKSPACE.bazel`); the repository where the command runs is the **main repo**, and other repositories are
defined by **repo rules** (source: https://bazel.build/concepts/build-ref, 2026-09-18). Within a repository,
directories containing a `BUILD` file are **packages**, and a package contributes targets to the build
(source: https://bazel.build/concepts/build-ref, 2026-09-18).

Bazel runs as a persistent server process. The command list shows `bazel dump` reporting "the internal state
of the Bazel server process", `bazel info` reporting "runtime info about the bazel server", and `bazel clean`
optionally stopping the server (source: https://bazel.build/run/build, 2026-09-18). This separates client
invocations from the long-lived analysis state.

Hermeticity is the architectural invariant. The build documentation defines it as the property that an
action "only uses its declared input files and no other files in the filesystem, and it only produces its
declared output files" (source: https://bazel.build/run/build, 2026-09-18). Sandboxing to enforce this is
enabled by default for local execution, and currently works on Linux 3.12 or newer with `CONFIG_USER_NS`
enabled, and on macOS 10.11 or newer (source: https://bazel.build/run/build, 2026-09-18). Bazel prints a
warning when the host cannot sandbox, because builds are then not guaranteed hermetic
(source: https://bazel.build/run/build, 2026-09-18).

External dependencies are resolved through **Bzlmod**, the module system. A module is a Bazel project with
multiple versions and its own `MODULE.bazel` manifest, analogous to a Maven artifact, an npm package, a Go
module, or a Cargo crate; Bazel reads the root module, resolves dependencies transitively, and selects one
version per module (source: https://bazel.build/external/module, 2026-09-18).

### Key Capabilities

| Capability | Detail | Source |
|---|---|---|
| Multi-language builds | Java, C++, Go, Android, iOS, and many other languages and platforms | (source: https://bazel.build/about/intro, 2026-09-18) |
| Multi-platform builds | Bazel runs on Windows, macOS, and Linux, and builds for multiple target platforms | (source: https://bazel.build/about/intro, 2026-09-18) |
| Correct incrementality | Caches prior work, tracks file content and command changes, rebuilds only what changed | (source: https://bazel.build/about/intro, 2026-09-18) |
| Hermetic local execution | Sandboxed actions by default with declared inputs and outputs | (source: https://bazel.build/run/build, 2026-09-18) |
| Action caching | On-disk mapping from executed actions to outputs, keyed by the action key, surviving server restarts | (source: https://bazel.build/reference/glossary, 2026-09-18) |
| Repository caching | Content-addressable cache of downloaded files, shareable across workspaces, SHA-256 verified | (source: https://bazel.build/reference/glossary, 2026-09-18) |
| Remote caching and execution | Distributes actions across machines and shares outputs across a team over gRPC | (source: https://bazel.build/remote/rbe, 2026-09-18) |
| Graph queries | `aquery` for the post-analysis action graph, `cquery` for the post-analysis dependency graph | (source: https://bazel.build/run/build, 2026-09-18) |
| Extensible rules | New languages and environments via `.bzl` rules, macros, aspects, and repo rules | (source: https://bazel.build/extending/concepts, 2026-09-18) |

### Tech Stack

Bazel is implemented in Java and C++ (verified anchor, `docs/reference/README.md`, 2026-09-18). Its build
and configuration language is **Starlark**, a language with syntax inspired by Python3, used in both `BUILD`
files and `.bzl` extensions; Starlark was formerly known as Skylark, and `BUILD` files use a restricted
subset without `def` function definitions (source: https://bazel.build/rules/language, 2026-09-18 and
https://bazel.build/reference/glossary, 2026-09-18).

Configuration is layered through **`.bazelrc`** files. Bazel reads optional rc files from multiple
locations (system-wide, workspace, user, custom), interprets them in order so later files override earlier
ones, and a given rc file may import settings from other rc files
(source: https://bazel.build/run/bazelrc, 2026-09-18). rc files also support conditional imports keyed on the
running Bazel version, with operators for exact, greater-than, less-than, and tilde ranges
(source: https://bazel.build/run/bazelrc, 2026-09-18).

Execution strategy is selectable per invocation. The glossary lists `sandboxed`, `docker` (command runs in
a local Docker sandbox), `remote` (executed remotely), and persistent worker execution, noting that the
chosen strategy affects hermeticity and speed while outputs remain the same
(source: https://bazel.build/reference/glossary, 2026-09-18).

Remote execution and caching both use an open-source gRPC protocol, hosted at
`github.com/bazelbuild/remote-apis` (source: https://bazel.build/remote/rbe, 2026-09-18). That repository
describes itself as "An API for caching and execution of actions on a remote system"
(source: https://github.com/bazelbuild/remote-apis, 2026-09-18).

---

## 3. Feature Overview

### Core Modules

| Concept | Role | Source |
|---|---|---|
| Repository | Directory tree with a boundary marker (`MODULE.bazel`, `REPO.bazel`, legacy `WORKSPACE`) | (source: https://bazel.build/concepts/build-ref, 2026-09-18) |
| Workspace | The main repo plus all defined external repos, shared by commands from that main repo | (source: https://bazel.build/concepts/build-ref, 2026-09-18) |
| Package | The set of targets defined by one `BUILD` file in a directory | (source: https://bazel.build/reference/glossary, 2026-09-18) |
| Target | A buildable unit declared by a rule in a package | (source: https://bazel.build/reference/glossary, 2026-09-18) |
| Rule | Schema defining rule targets, for example `cc_library`; rules are the primary extension point | (source: https://bazel.build/reference/glossary, 2026-09-18) |
| Macro | Starlark callable composing several rule target declarations; symbolic macros since Bazel 8, plus legacy macros | (source: https://bazel.build/reference/glossary, 2026-09-18) |
| Provider | The mechanism by which rule targets pass information to downstream dependencies in analysis | (source: https://bazel.build/reference/glossary, 2026-09-18) |
| Repo rule | Schema that materializes an external repository, commonly `http_archive` | (source: https://bazel.build/reference/glossary, 2026-09-18) |
| Module | Versioned project with `MODULE.bazel`, the unit of the Bzlmod dependency graph | (source: https://bazel.build/external/module, 2026-09-18) |
| Module extension | Starlark mechanism for a module to define extra repos and resolve dependency conflicts | (source: https://bazel.build/external/migration, 2026-09-18) |
| Registry | A database of modules; Bazel supports index registries only | (source: https://bazel.build/external/registry, 2026-09-18) |

### Notable Features

- **Hermetic sandboxed execution by default.** Local actions run in sandboxes containing only the minimal
  files the tool needs, which is how declared-input/declared-output hermeticity is enforced
  (source: https://bazel.build/run/build, 2026-09-18).
- **Action cache.** An on-disk cache mapping executed actions to the outputs they created, keyed by the
  action key, described as a core component of Bazel's incrementality model that survives server restarts
  (source: https://bazel.build/reference/glossary, 2026-09-18).
- **Repository cache.** A content-addressable cache of downloaded files, shareable across workspaces,
  enabling offline builds after the initial download; files are cached only when a SHA-256 checksum is
  specified (source: https://bazel.build/reference/glossary, 2026-09-18).
- **Disk cache with garbage collection.** `--disk_cache` chooses a disk cache location or defaults under
  the output user root; from Bazel 7.4, size and age limits plus an idle delay control automatic GC
  (source: https://bazel.build/remote/caching, 2026-09-18).
- **Remote caching and remote execution.** Remote execution distributes build and test actions across many
  machines, gives a consistent execution environment, and lets a team reuse outputs; the default remains
  local execution (source: https://bazel.build/remote/rbe, 2026-09-18).
- **Graph queries.** `aquery` runs a query on the post-analysis action graph and `cquery` runs a
  post-analysis dependency graph query (source: https://bazel.build/run/build, 2026-09-18).
- **Stamping.** Bazel can embed source control, build time, and workspace or environment information into
  built artifacts, enabled through `--workspace_status_command` and stamp-aware rules
  (source: https://bazel.build/reference/glossary, 2026-09-18).
- **Version-conditional configuration.** rc files support conditional imports based on the Bazel version,
  which is aimed at projects that must work across several Bazel versions
  (source: https://bazel.build/run/bazelrc, 2026-09-18).
- **Registry overrides and yanking.** `MODULE.bazel` may pin or replace dependency versions through
  overrides, and a registry can mark versions yanked so Bazel refuses to select them unless explicitly
  allowed (source: https://bazel.build/external/module, 2026-09-18).
- **Lockfile discipline.** Bzlmod produces a `MODULE.bazel.lock`; module extensions can bump a
  `facts_version` parameter to invalidate persisted facts in that lockfile
  (source: https://github.com/bazelbuild/bazel/releases, 2026-09-18).

### Extensibility / Plugin Mechanism

Bazel has no separate plugin binary interface. Extension is expressed in **Starlark** files ending in `.bzl`,
imported with a `load` statement (source: https://bazel.build/extending/concepts, 2026-09-18). The extension
surface consists of:

- **Macros**: a function that instantiates rules, useful when a `BUILD` file becomes repetitive. Bazel 8
  introduced **symbolic macros**, which behave more predictably than **legacy macros**
  (source: https://bazel.build/extending/concepts, 2026-09-18).
- **Rules**: schemas that define rule targets and register the actions that produce outputs. Rules are
  described as the primary way to extend Bazel to support new programming languages and environments
  (source: https://bazel.build/reference/glossary, 2026-09-18 and
  https://bazel.build/extending/rules, 2026-09-18).
- **Aspects**, which let extension authors traverse and augment the target graph
  (source: https://bazel.build/extending/concepts, 2026-09-18).
- **Repository rules**, which materialize external repositories and may perform network or file I/O
  (source: https://bazel.build/extending/concepts, 2026-09-18).

The official tooling around this surface includes Buildifier for formatting and linting, a `.bzl` style
guide, rule testing support, and documentation generation (source: https://bazel.build/extending/concepts,
2026-09-18). Language support is delivered as rule sets, and the FAQ points users to the build encyclopedia
and the community list rather than a single bundled plugin system
(source: https://bazel.build/about/faq, 2026-09-18).

---

## 4. Status & Ecosystem

Bazel maintains two release tracks. Bazel 4.0 and higher provide rolling releases and long term support
(LTS) releases (source: https://bazel.build/release/versioning, 2026-09-18). The published support matrix
at research time is:

| Line | Stage | Latest | End of support | Source |
|---|---|---|---|---|
| Bazel 10 | Rolling | rolling release page | not applicable | (source: https://bazel.build/release/versioning, 2026-09-18) |
| Bazel 9 | Active | 9.2.0 | Dec 2028 | (source: https://bazel.build/release/versioning, 2026-09-18) |
| Bazel 8 | Maintenance | 8.8.0 | Dec 2027 | (source: https://bazel.build/release/versioning, 2026-09-18) |
| Bazel 7 | Maintenance | 7.7.1 | Dec 2026 | (source: https://bazel.build/release/versioning, 2026-09-18) |
| Bazel 6 | Deprecated | 6.6.0 | Dec 2025 | (source: https://bazel.build/release/versioning, 2026-09-18) |
| Bazel 5 | Deprecated | 5.4.1 | Jan 2025 | (source: https://bazel.build/release/versioning, 2026-09-18) |
| Bazel 4 | Deprecated | 4.2.4 | Jan 2024 | (source: https://bazel.build/release/versioning, 2026-09-18) |

The dependency system is mid-transition, and this is the single most important ecosystem fact. The official
migration guide states that the legacy `WORKSPACE` file is already disabled in Bazel 8 (late 2024) and will
be removed in Bazel 9 (late 2025), and that migration to Bzlmod is mandatory in Bazel 9
(source: https://bazel.build/external/migration, 2026-09-18). `WORKSPACE` and Bzlmod can coexist during a
gradual migration, with `WORKSPACE.bzlmod` taking effect when Bzlmod is enabled
(source: https://bazel.build/external/migration, 2026-09-18).

The default dependency registry is the **Bazel Central Registry (BCR)** at `https://bcr.bazel.build/`,
backed by `github.com/bazelbuild/bazel-central-registry` and browsable at `https://registry.bazel.build/`
(source: https://bazel.build/external/registry, 2026-09-18). The BCR is community maintained, and each
module version must include a `presubmit.yml` used by its CI to check interoperability
(source: https://bazel.build/external/registry, 2026-09-18). The BCR repository states that it is the
default registry for Bzlmod and also hosts metadata for projects that lack upstream Bazel support, most
commonly C/C++ projects (source: https://github.com/bazelbuild/bazel-central-registry, 2026-09-18).
Registries are selectable with the repeatable `--registry` flag, and specifying any registry suppresses
the implicit BCR until it is listed explicitly (source: https://bazel.build/external/registry, 2026-09-18).

Operationally, Bazel is used with Bazelisk, a launcher that can select Bazel versions and bisect
regressions across releases, per the versioning documentation
(source: https://bazel.build/release/versioning, 2026-09-18). The project follows a 90 day vulnerability
disclosure timeline (source: https://github.com/bazelbuild/bazel, 2026-09-18).

---

## 5. Market Positioning

Bazel occupies the top of the build-tool scale: large, multi-language, multi-repository codebases with many
engineers. Its FAQ places it beside Make, Ant, Gradle, Buck, Pants, and Maven, and then differentiates on
multi-language support, a high-level build language, and multi-platform support
(source: https://bazel.build/about/faq, 2026-09-18). It is the open-source descendant of Google's Blaze
(source: https://bazel.build/reference/glossary, 2026-09-18), and its design assumption is the very large
internal mono-repository (source: https://bazel.build/about/faq, 2026-09-18).

PolyOrch's own competitive analysis frames the contrast directly: unlike Bazel, which requires all projects
to use a unified `BUILD` file, PolyOrch bridges existing build systems through adapters, so CMake projects
keep using CMake and Colcon workspaces keep using Colcon while PolyOrch orchestrates
(`docs/derived/competitive-analysis.md`, derived from `docs/whitepaper.md`). The whitepaper's comparison table
records the same split: Bazel is a large-scale multi-language build system with hermetic builds and remote
execution, while PolyOrch is lighter and does not force a unified build language
(`docs/whitepaper.md` v1.0, derived positioning).

That positions Bazel less as a drop-in competitor and more as the reference design for the hard problems
(correctness, incrementality, caching, remote execution) that PolyOrch also has to solve, under a different
constraint: PolyOrch cannot mandate one build language.

---

## 6. Product Highlights

1. **Hermeticity as the correctness mechanism.** Declared inputs and declared outputs are enforced by
   default sandboxing, and the docs are explicit that unsandboxed hosts lose the guarantee
   (source: https://bazel.build/run/build, 2026-09-18).
2. **Incrementality built on content and commands, not timestamps.** Bazel tracks file content and build
   command changes to decide what to rebuild, and cites this as the reason CI need not clean first
   (source: https://bazel.build/about/intro, 2026-09-18 and https://bazel.build/about/faq, 2026-09-18).
3. **A single graph model spanning languages.** The action graph lets one tool reason about artifacts and
   actions across all supported languages (source: https://bazel.build/reference/glossary, 2026-09-18).
4. **Remote execution and remote caching behind one open protocol.** REAPI is used by Bazel for both, and
   the protocol repository is public and language-agnostic
   (source: https://bazel.build/remote/rbe, 2026-09-18 and https://github.com/bazelbuild/remote-apis,
   2026-09-18).
5. **Explicit dependency resolution with lockstate.** Bzlmod resolves a versioned dependency graph from
   registries, with overrides, yanking, and `MODULE.bazel.lock` persisted facts
   (source: https://bazel.build/external/module, 2026-09-18).
6. **A real extension language rather than a config DSL.** Starlark rules, macros, aspects, and repo rules
   let the community add languages and environments
   (source: https://bazel.build/extending/concepts, 2026-09-18).

---

## 7. Value to PolyOrch

PolyOrch dispatches CMake, Xmake, Meson, and Colcon through adapters, uses Xmake as its native build
engine, Pixi for environments, and vcpkg and Conan through Xmake's `vcpkg::` and `conan::` namespaces. Bazel
is the reference for correctness and scale in that space, and the decisive contrast is that Bazel requires
projects to adopt one build language while PolyOrch bridges existing ones. Each point below is tagged and
actionable.

### [Adopt] Directly reusable

- **[Adopt] Model every adapter dispatch as a hermetic action with declared inputs and declared outputs.**
  Bazel defines hermeticity as using only declared inputs and producing only declared outputs
  (source: https://bazel.build/run/build, 2026-09-18). PolyOrch can require each adapter to declare the
  files a CMake, Xmake, Meson, or Colcon step consumes and produces, even where the underlying tool is not
  hermetic. This gives PolyOrch a correct invalidation boundary per adapter instead of per tool.
- **[Adopt] Key the PolyOrch cache on the action, not just on source mtimes.** Bazel's action cache maps
  executed actions to outputs keyed by a computed action key, and it survives restarts
  (source: https://bazel.build/reference/glossary, 2026-09-18). PolyOrch should compute its own action key
  from the adapter identity, the resolved command line, environment, and input digests, and store the
  mapping durably. That is what makes a re-run reproducible across machines.
- **[Adopt] Use a content-addressable store for downloads, gated on checksums.** Bazel's repository cache
  is content-addressable, shareable across workspaces, and caches a download only when a SHA-256 checksum
  is given (source: https://bazel.build/reference/glossary, 2026-09-18). PolyOrch can adopt this for the
  artifacts it fetches while resolving vcpkg and Conan dependencies, refusing to cache anything without a
  digest.
- **[Adopt] Commit a lockfile for the resolved orchestration plan.** Bzlmod persists resolution facts in
  `MODULE.bazel.lock` (source: https://github.com/bazelbuild/bazel/releases, 2026-09-18). PolyOrch already
  inherits Pixi's lockfile; it should also lock the adapter plan (which adapter runs, with which resolved
  toolchain and dependency set), so that a checkout reproduces the same build graph.
- **[Adopt] Expose a graph query surface.** Bazel ships `aquery` for the action graph and `cquery` for the
  post-analysis dependency graph (source: https://bazel.build/run/build, 2026-09-18). PolyOrch should expose
  an equivalent `polyorch query` over its cross-adapter target and action graph, because debugging a
  polyglot build without a query surface is guesswork.
- **[Adopt] Pin and bootstrap the toolchain, do not float it.** Bazel users pin versions and can bisect with
  Bazelisk (source: https://bazel.build/release/versioning, 2026-09-18). PolyOrch should pin Xmake and Pixi
  versions in `polyorch.toml` and bootstrap them, so that "works on my machine" does not mean two different
  Xmake versions.
- **[Adopt] Separate loading, analysis, and execution in the orchestrator pipeline.** Bazel's three-phase
  model (loading, analysis, execution) keeps graph construction distinct from side effects
  (source: https://bazel.build/reference/glossary, 2026-09-18). PolyOrch's dispatch path should have the
  same separation, so planning can be validated and cached before any adapter process starts.

### [Adapt] Reusable with modification

- **[Adapt] Borrow the module and registry shape for a PolyOrch adapter registry, but not Bzlmod's full
  semantics.** Bazel modules declare dependencies in `MODULE.bazel` and resolve them from registries with
  overrides and yanked versions (source: https://bazel.build/external/module, 2026-09-18). PolyOrch can
  publish versioned adapters as modules resolved from a registry, with a registry flag mirroring
  `--registry` (source: https://bazel.build/external/registry, 2026-09-18), but should stop there: full
  version-selection semantics would duplicate what Xmake, vcpkg, and Conan already own.
- **[Adapt] Layer configuration system, user, then workspace, with conditional sections.** Bazel reads
  `.bazelrc` from multiple locations in a fixed precedence and supports conditional imports tied to the
  Bazel version (source: https://bazel.build/run/bazelrc, 2026-09-18). PolyOrch can apply the same layering
  to `polyorch.toml`, with conditions keyed on the detected adapter or tool version, which matters when a
  repository contains projects pinned to different CMake or Xmake releases.
- **[Adapt] Adopt cache garbage collection policy, not Bazel's implementation.** Bazel 7.4 added size and
  age limits plus an idle delay for disk cache GC (source: https://bazel.build/remote/caching, 2026-09-18).
  PolyOrch should define the same two knobs, maximum size and maximum age, for its own cache; the default
  idle-based collector can be replaced by a simpler explicit `polyorch cache gc`.
- **[Adapt] Treat remote execution as a later phase and target REAPI compatibility rather than a bespoke
  protocol.** Bazel uses the open gRPC REAPI for remote execution and caching
  (source: https://bazel.build/remote/rbe, 2026-09-18 and https://github.com/bazelbuild/remote-apis,
  2026-09-18). PolyOrch should not define its own remote protocol. If it adds remote caching, speaking REAPI
  lets it reuse existing servers; the same interface can be implemented by remote-capable adapters only.
- **[Adapt] Prefer pure, symbolic extension points over unrestricted ones.** Bazel 8 introduced symbolic
  macros because legacy macros can mutate arguments or fail on `select()` and ill-typed arguments
  (source: https://bazel.build/reference/glossary, 2026-09-18). Where PolyOrch exposes extension points
  (for example Lua hooks around Xmake), it should constrain them to pure functions over declared inputs,
  which prevents adapter plugins from creating hidden global state.
- **[Adapt] Learn from explicit platforms and toolchains, but do not replicate the model.** Bazel separates
  host and target machine types and models platforms and toolchains explicitly
  (source: https://bazel.build/reference/glossary, 2026-09-18). PolyOrch needs cross-compilation awareness
  for its polyglot matrix, but should express it as a small set of adapter-passed triples rather than a full
  platform and toolchain resolution system, which would be a second build language by another name.
- **[Adapt] Adopt graph queries for incremental target selection, mapped onto adapter concepts.** Bazel's
  `cquery` runs on the post-analysis dependency graph (source: https://bazel.build/run/build, 2026-09-18).
  PolyOrch can implement affected-target selection by mapping adapter-level project dependencies into one
  graph, but it must tolerate incomplete dependency information from Make-style builds instead of assuming
  every edge exists.

### [Avoid] Known pitfalls / not applicable

- **[Avoid] Do not require projects to adopt a single build language.** Bazel's model is that projects are
  described in `BUILD` files (source: https://bazel.build/about/faq, 2026-09-18), and that requirement is
  precisely what PolyOrch exists to avoid: CMake projects must keep their `CMakeLists.txt`, Xmake projects
  their `xmake.lua`, Colcon workspaces their `package.xml`. Any PolyOrch design that asks users to migrate
  to a PolyOrch DSL repeats Bazel's adoption cost and erases the product's differentiation.
- **[Avoid] Do not copy the legacy `WORKSPACE` dependency pattern.** The official guide says `WORKSPACE` is
  disabled in Bazel 8 and removed in Bazel 9, and that loading transitive `*_deps` macros caused version
  ambiguity resolved only by macro ordering
  (source: https://bazel.build/external/migration, 2026-09-18). PolyOrch adapter configuration must not
  resolve dependency versions through ordered side-effecting macros; it must resolve them declaratively and
  lock the result.
- **[Avoid] Do not build a general sandbox or remote execution stack early.** Bazel's hermeticity depends on
  OS facilities (Linux user namespaces, macOS sandboxing) that can be disabled by the host
  (source: https://bazel.build/run/build, 2026-09-18). PolyOrch cannot impose these on arbitrary CMake or
  Make invocations, and implementing them is a large subsystem with a narrow payoff. Defer remote
  execution until local caching is correct.
- **[Avoid] Do not make the BCR or any single registry a hard runtime dependency.** The BCR itself warns
  that Bzlmod users depend on its GitHub and Google Cloud infrastructure by default and that outages can
  cause build failures (source: https://github.com/bazelbuild/bazel-central-registry, 2026-09-18). PolyOrch
  should resolve from multiple registries and support mirroring, following Bazel's own `--registry`
  layering, so a registry outage cannot block builds.
- **[Avoid] Do not adopt Bazel's monolithic analysis model where adapters cannot satisfy it.** Bazel's
  correctness claim rests on complete, explicit dependency information in one graph
  (source: https://bazel.build/reference/glossary, 2026-09-18). CMake, Meson, and Colcon projects may have
  generated or implicit inputs, so PolyOrch must degrade gracefully (mark results as lower confidence, or
  fall back to conservative rebuilds) rather than assert a hermeticity guarantee it cannot keep.
- **[Avoid] Do not chase Bazel's release cadence or rolling track.** Bazel maintains rolling and LTS tracks
  with overlapping support windows and end-of-support dates
  (source: https://bazel.build/release/versioning, 2026-09-18). PolyOrch, which has no source tree yet,
  should follow the versions of the tools it integrates (Xmake, Pixi, CMake) rather than invent a parallel
  release policy that adds maintenance without user value.

---

## Appendix (optional deep dives)

### A1. REAPI in one paragraph

Bazel does not define its own remote protocol. Remote execution and remote caching both use an open-source
gRPC protocol whose repository is `github.com/bazelbuild/remote-apis`, described as an API for caching and
execution of actions on a remote system (source: https://bazel.build/remote/rbe, 2026-09-18 and
https://github.com/bazelbuild/remote-apis, 2026-09-18). Bazel's remote caching page documents a local disk
cache as the baseline and remote caching as the shared variant
(source: https://bazel.build/remote/caching, 2026-09-18). For PolyOrch, the practical implication is that
if remote caching is ever added, REAPI compatibility is the interoperability choice, because other
orchestrators and executors already implement it.

### A2. The three phases, mapped to a dispatch pipeline

| Bazel phase | What happens | Source | PolyOrch analogue |
|---|---|---|---|
| Loading | `BUILD` files execute, packages are created, macros and `glob()` evaluate | (source: https://bazel.build/reference/glossary, 2026-09-18) | Discover projects and adapters, parse native build files |
| Analysis | Rule targets exchange providers and register actions; the action graph is built | (source: https://bazel.build/reference/glossary, 2026-09-18) | Resolve the adapter plan, compute action keys, validate inputs and outputs |
| Execution | Registered actions run and produce artifacts | (source: https://bazel.build/reference/glossary, 2026-09-18) | Invoke CMake, Xmake, Meson, or Colcon, then record cache entries |

### A3. Core source list

- Repository: https://github.com/bazelbuild/bazel (2026-09-18)
- Releases: https://github.com/bazelbuild/bazel/releases (2026-09-18)
- License: https://raw.githubusercontent.com/bazelbuild/bazel/master/LICENSE (2026-09-18)
- Intro: https://bazel.build/about/intro (2026-09-18)
- FAQ: https://bazel.build/about/faq (2026-09-18)
- Glossary: https://bazel.build/reference/glossary (2026-09-18)
- Concepts: https://bazel.build/concepts/build-ref, https://bazel.build/concepts/dependencies (2026-09-18)
- Build and configuration: https://bazel.build/run/build, https://bazel.build/run/bazelrc (2026-09-18)
- Remote: https://bazel.build/remote/rbe, https://bazel.build/remote/caching, https://github.com/bazelbuild/remote-apis (2026-09-18)
- External dependencies: https://bazel.build/external/module, https://bazel.build/external/registry,
  https://bazel.build/external/migration, https://github.com/bazelbuild/bazel-central-registry (2026-09-18)
- Extending: https://bazel.build/extending/concepts, https://bazel.build/extending/rules,
  https://bazel.build/rules/language (2026-09-18)
- Release model: https://bazel.build/release/versioning, https://bazel.build/release/rolling (2026-09-18)
