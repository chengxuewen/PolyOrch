# moon Profile

> Sources: https://github.com/moonrepo/moon, https://moonrepo.dev/docs, https://moonrepo.dev/blog/moon-v2.0, researched 2026-09-18
> Not a derived document: facts here are externally sourced.

## 1. Product Profile

moon is a repository management tool for the JavaScript and wider web ecosystem, written in Rust.
Its own README expands the name as a repository **m**anagement, **o**rganization, **o**rchestration,
and **n**otification tool, and states that many of its concepts are heavily inspired by Bazel and
other popular build systems (source: https://github.com/moonrepo/moon, 2026-09-18).

Key identity facts:

- Repository: `github.com/moonrepo/moon` (source: https://github.com/moonrepo/moon, 2026-09-18)
- Latest release at research time: v2.5.5, released 2026-09-15 (source: https://github.com/moonrepo/moon/releases, 2026-09-18)
- License: MIT License, Copyright (c) 2021 moonrepo, Inc. (source: https://github.com/moonrepo/moon/blob/master/LICENSE, 2026-09-18)
- Implementation language: Rust (source: https://github.com/moonrepo/moon, 2026-09-18)
- Configuration files: `moon.yml` (also `moon.*` in other formats), `.moon/workspace.*`,
  `.moon/toolchains.*`, `.moon/tasks.*`, `.moon/extensions.*`
  (source: https://moonrepo.dev/docs/config/workspace, 2026-09-18)
- It ships as a single binary and is installed through proto, shell scripts on Linux/macOS/WSL,
  PowerShell on Windows, the `@moonrepo/cli` npm package, or Nix
  (source: https://moonrepo.dev/docs/install, 2026-09-18)

moon is one component of the moonrepo developer productivity platform, alongside proto, a stand-alone
multi-language version manager that moon uses for toolchain management
(source: https://moonrepo.dev/docs/concepts/toolchain, 2026-09-18).

Positioning precision matters for PolyOrch. moon itself does not call itself a general build system.
The primary source describes it as a repository management, organization, orchestration, and
notification tool (source: https://github.com/moonrepo/moon, 2026-09-18). It orchestrates the
commands and package managers of a repository rather than defining a build rule language of its own.
Internally it compiles a task and action graph, but those actions wrap existing toolchains and
package managers rather than compiling source directly.

moon is JavaScript-first. Its README opens by naming the web ecosystem as the target, and its
languages page states that although moon is currently focusing on the JavaScript ecosystem, the
long-term vision is to be a multi-language task runner and monorepo management tool
(source: https://moonrepo.dev/docs/how-it-works/languages, 2026-09-18).

## 2. Technical Characteristics

### Overall Architecture

moon is a Cargo workspace. Its manifest declares `members = ["crates/*"]` and
`default-members = ["crates/cli"]`, so the entire product is assembled from many small crates
(source: https://github.com/moonrepo/moon/blob/master/Cargo.toml, 2026-09-18). The `crates/`
directory holds over 70 crates at research time (source: https://api.github.com/repos/moonrepo/moon/contents/crates, 2026-09-18).
The major architectural slices are:

- **Domain and graph layer.** Crates such as `workspace`, `workspace-graph`, `project`,
  `project-graph`, `project-builder`, `project-expander`, `task`, `task-graph`, `task-builder`,
  `task-expander`, and `target` model workspaces, projects, tasks, and their identifiers
  (source: https://api.github.com/repos/moonrepo/moon/contents/crates, 2026-09-18).
- **Execution layer.** `action`, `actions`, `action-context`, `action-graph`, `action-pipeline`,
  `exec-plan`, `task-runner`, and `process` model and execute the action graph
  (source: https://api.github.com/repos/moonrepo/moon/contents/crates, 2026-09-18).
- **Hashing and cache layer.** `hash`, `task-hasher`, `affected`, `cache`, `cache-item`,
  `cache-local`, `cache-remote`, `cache-storage`, `cas`, and `blob`
  (source: https://api.github.com/repos/moonrepo/moon/contents/crates, 2026-09-18).
- **Toolchain and plugin layer.** `toolchain`, `toolchain-plugin`, `plugin`, `extension-plugin`,
  `pdk`, `pdk-api`, and `pdk-test-utils` (source: https://api.github.com/repos/moonrepo/moon/contents/crates, 2026-09-18).
- **Daemon layer.** `daemon`, `daemon-client`, `daemon-server`, `daemon-proto`, `daemon-utils`,
  and `file-watcher` (source: https://api.github.com/repos/moonrepo/moon/contents/crates, 2026-09-18).
- **Supporting layer.** `config`, `config-loader`, `config-schema`, `manifest`, `vcs`, `vcs-hooks`,
  `docker`, `codegen`, `codeowners`, `query`, `env`, `env-var`, `notifier`, `mcp`, `console`, and
  `cli` (source: https://api.github.com/repos/moonrepo/moon/contents/crates, 2026-09-18).

The runtime model is a layered graph. Projects depend on other projects to form a project graph,
tasks depend on other tasks to form a task graph, and moon derives an action graph from those for
execution (source: https://moonrepo.dev/docs/concepts/project, 2026-09-18). The action graph is the
execution plan: it runs tasks in parallel, in the correct order, using a thread pool and the
dependency graph (source: https://github.com/moonrepo/moon, 2026-09-18).

Actions are typed phases, not just process spawns. The documented action kinds are Sync workspace,
Setup toolchain, Setup environment, Setup proto, Install dependencies, Sync project, Run task, Run
interactive task, and Run persistent task
(source: https://moonrepo.dev/docs/how-it-works/action-graph, 2026-09-18). Their order is
configurable through `pipeline.syncWorkspace` and `pipeline.syncProjects`, both of which default to
enabled (source: https://moonrepo.dev/docs/config/workspace, 2026-09-18).

A background daemon is part of the architecture. It runs a file watcher over the workspace and
invalidates caches, executes heavy operations, and takes exclusive ownership of its workspace
through an advisory file lock, with metadata recorded in a `daemon.json` state file
(source: https://github.com/moonrepo/moon/blob/master/CHANGELOG.md, 2026-09-18).

### Key Capabilities

- **Task running.** Tasks are commands run in the context of a project, defined either as a
  `command` or a `script` (source: https://moonrepo.dev/docs/concepts/task, 2026-09-18). Only
  `script` tasks run multiple commands, because they execute inside a shell
  (source: https://moonrepo.dev/docs/faq, 2026-09-18).
- **Targets.** A target pairs a scope to a task as `scope:task`. Scopes include a project, tag
  scopes prefixed with `#`, and special scopes such as dependency and dependent selectors
  (source: https://moonrepo.dev/docs/concepts/target, 2026-09-18). The `...` token is an alias for
  `**/*`, described as similar to how Bazel targets work
  (source: https://github.com/moonrepo/moon/blob/master/CHANGELOG.md, 2026-09-18).
- **Smart hashing and incremental builds.** moon collects inputs from multiple sources to make
  builds deterministic and reproducible, so only changed projects rebuild
  (source: https://github.com/moonrepo/moon, 2026-09-18). A native file hashing experiment replaces
  the Git-based file hashing mechanism and is claimed to improve performance by 10 to 50 percent
  (source: https://github.com/moonrepo/moon/blob/master/CHANGELOG.md, 2026-09-18).
- **Affected detection.** moon tracks changed files against the project graph to select affected
  work, with an asynchronous tracker that defaults to enabled in v2.5 and later
  (source: https://moonrepo.dev/docs/config/workspace, 2026-09-18).
- **Caching.** Local cache plus remote cache that persists builds, hashes, and caches between
  teammates and CI (source: https://github.com/moonrepo/moon, 2026-09-18). A local
  content-addressable storage experiment reuses the same format as the remote cache
  (source: https://github.com/moonrepo/moon/blob/master/CHANGELOG.md, 2026-09-18).
- **Remote cache protocol.** The remote cache speaks the Bazel Remote Execution API, pulled in
  through the `bazel-remote-apis` crate, with a default cache instance name of `moon-outputs`
  (source: https://github.com/moonrepo/moon/blob/master/Cargo.toml, 2026-09-18 and
  https://moonrepo.dev/docs/config/workspace, 2026-09-18).
- **Integrated toolchain.** moon downloads and installs explicit versions of tools for consistency
  across the workspace or per project, by piggybacking on proto's toolchain found at `~/.proto`
  (source: https://moonrepo.dev/docs/concepts/toolchain, 2026-09-18).
- **Task inheritance.** Global task definitions under `.moon/tasks/**/*` are inherited by projects,
  controlled by an `inheritedBy` setting with conditions such as files, languages, layers, stacks,
  tags, and toolchains (source: https://moonrepo.dev/blog/moon-v2.0, 2026-09-18).
- **Code generation.** moon scaffolds applications, libraries, and tooling from templates, with a
  Tera templating engine dependency in the manifest
  (source: https://github.com/moonrepo/moon, 2026-09-18).
- **Docker integration.** moon manages Docker flows for pruning and scaffolding, with a dedicated
  `docker` crate and `moon docker` commands (source: https://moonrepo.dev/docs/config/workspace, 2026-09-18).
- **Code ownership and VCS hooks.** moon generates CODEOWNERS and manages Git hooks
  (source: https://github.com/moonrepo/moon, 2026-09-18).
- **Notifications and flakiness detection.** webhook events per pipeline event, terminal
  notifications, and automatic retries for flaky builds
  (source: https://github.com/moonrepo/moon, 2026-09-18).
- **MCP server.** moon ships an MCP crate and tools such as `get_template` so AI coding assistants
  can discover templates and inspect their variable schemas
  (source: https://github.com/moonrepo/moon/blob/master/CHANGELOG.md, 2026-09-18).

### Tech Stack

From the workspace manifest (source: https://github.com/moonrepo/moon/blob/master/Cargo.toml, 2026-09-18):

- Async runtime: `tokio` with `rt-multi-thread`, process, signal, sync, and time features.
- gRPC and networking: `tonic`, `tonic-prost`, `tower`, and `reqwest` with rustls.
- CLI and diagnostics: `clap`, `miette`, and the `starbase` family (`starbase_console`,
  `starbase_shell`, `starbase_utils`, `starbase_styles`, and others).
- Graphs: `daggy` and `petgraph`.
- Hashing: `blake3`, `sha2`, and `md5`.
- Serialization and config: `serde`, `serde_json`, and `schematic` for schema generation.
- Templating: `tera`.
- WASM plugins: `extism` pinned at `=1.30.0`, plus `extism-pdk`, `warpgate`, `warpgate_api`, and
  `warpgate_pdk`.
- Toolchain integration: `proto_core`, `proto_pdk_api`, `proto_pdk_test_utils`, and `proto_shim`.
- Remote cache protocol: `bazel-remote-apis`.
- Terminal UI: `iocraft`.
- Platform support: Linux, macOS, and Windows, with `windows-sys` for the Windows path
  (source: https://github.com/moonrepo/moon, 2026-09-18).

## 3. Feature Overview

### Core Modules

The crate layout maps closely to product capabilities, so the module story is the architecture
story:

| Concern | Representative crates |
|---|---|
| Workspace and project model | `workspace`, `workspace-graph`, `project`, `project-graph`, `project-builder`, `project-expander`, `project-constraints` |
| Task model and graphs | `task`, `task-graph`, `task-builder`, `task-expander`, `task-hasher`, `target`, `token`, `file-group` |
| Execution | `action`, `actions`, `action-context`, `action-graph`, `action-pipeline`, `exec-plan`, `task-runner`, `process`, `process-augment` |
| Caching and affected | `cache`, `cache-item`, `cache-local`, `cache-remote`, `cache-storage`, `cas`, `blob`, `hash`, `affected` |
| Toolchains and plugins | `toolchain`, `toolchain-plugin`, `plugin`, `extension-plugin`, `pdk`, `pdk-api` |
| Daemon | `daemon`, `daemon-client`, `daemon-server`, `daemon-proto`, `file-watcher` |
| Integrations | `docker`, `vcs`, `vcs-hooks`, `codegen`, `codeowners`, `notifier`, `mcp`, `api` |
| Foundation | `config`, `config-loader`, `config-schema`, `manifest`, `env`, `console`, `cli`, `common` |

(All rows source: https://api.github.com/repos/moonrepo/moon/contents/crates, 2026-09-18)

### Notable Features

- **Remote caching via an open protocol.** Because moon uses the Bazel Remote Execution API, its
  remote cache is not a closed moon-only service. Any REAPI-compatible cache backend can serve it.
  This is the single most important interoperability decision in the product for a tool like
  PolyOrch (source: https://github.com/moonrepo/moon/blob/master/Cargo.toml, 2026-09-18).
- **Cache invalidation strategy per dependency.** A `cacheStrategy` field on task dependencies
  controls whether a dependency invalidates the task by `hash`, is `ignored`, or mixes the
  dependency's `outputs`. When omitted, the default is `hash` for dependencies with outputs and
  `ignored` for those without (source: https://github.com/moonrepo/moon/blob/master/CHANGELOG.md, 2026-09-18).
- **Configuration based task inheritance.** The v2 `inheritedBy` conditions replace the older file
  naming convention approach, letting one tasks file target projects by language, stack, layer,
  tags, files, or toolchain (source: https://moonrepo.dev/blog/moon-v2.0, 2026-09-18).
- **Project discovery by glob.** Projects can be declared explicitly, discovered through globs such
  as `apps/*` or `crates/*/Cargo.toml`, or mixed. Matching files instead of folders became possible
  in moon v2.5, and a `globFormat` setting controls generated project IDs
  (source: https://moonrepo.dev/docs/config/workspace, 2026-09-18).
- **Implicit dependency inference.** Beyond explicit `dependsOn`, moon discovers implicit
  dependencies when scanning, based on the project's `language` setting
  (source: https://moonrepo.dev/docs/concepts/project, 2026-09-18).
- **Docker pruning and scaffolding.** The `docker` crate and `moon docker` commands integrate
  workspace aware Dockerfiles (source: https://moonrepo.dev/docs/config/workspace, 2026-09-18).
- **Code generation from templates.** The `codegen` crate implements scaffolding, exposed through
  `moon generate` (source: https://api.github.com/repos/moonrepo/moon/contents/crates, 2026-09-18).
- **MCP tools for AI assistants.** The dedicated `mcp` crate exposes moon capabilities over the
  Model Context Protocol (source: https://api.github.com/repos/moonrepo/moon/contents/crates, 2026-09-18).
- **Optional action distribution.** The README claims action distribution across multiple machines
  to increase throughput (source: https://github.com/moonrepo/moon, 2026-09-18). Treat this as a
  feature claim from the primary repo rather than as an independently benchmarked capability.

### Extensibility / Plugin Mechanism

Extensibility is a first class concern, and it is WASM based:

- **Toolchains are WASM plugins.** The languages page states that languages (toolchains) are
  implemented as WASM plugins, where their functionality is implemented in isolation and is
  opt-in (source: https://moonrepo.dev/docs/how-it-works/languages, 2026-09-18). The v2 release
  replaced the legacy hard-coded platform system with this plugin based toolchain system
  (source: https://moonrepo.dev/blog/moon-v2.0, 2026-09-18).
- **Extensions are WASM plugins.** An extension is a WASM plugin that adds functionality, configured
  under `.moon/extensions.*` (source: https://moonrepo.dev/docs/guides/extensions, 2026-09-18).
- **Built-in extensions.** Documented built-ins include `download`, `migrate-nx`,
  `migrate-turborepo`, and `unpack`. The two migration extensions convert Nx and Turborepo
  repositories to moon (source: https://moonrepo.dev/docs/guides/extensions, 2026-09-18).
- **Plugin Development Kit.** Plugins are authored in Rust against moon's PDK (`moon_pdk`), exposed
  in the `pdk` and `pdk-api` crates, with a `define_extension_config` style API for typed
  configuration (source: https://moonrepo.dev/docs/guides/extensions, 2026-09-18).
- **Plugin runtime.** The runtime is Extism, pinned to an exact version in the workspace manifest
  (source: https://github.com/moonrepo/moon/blob/master/Cargo.toml, 2026-09-18). Toolchain plugins
  can extend the project graph, extend task commands before execution, hook into task hashing,
  parse manifests and lockfiles, set up environments, and manage tool installs
  (source: https://moonrepo.dev/blog/moon-v2.0, 2026-09-18).
- **Example plugins.** moon points developers at the `moonrepo/plugins` repository for in-depth
  examples (source: https://moonrepo.dev/docs/guides/extensions, 2026-09-18).

## 4. Status & Ecosystem

- **Release cadence.** v2.5.5 is the latest release at research time, published 2026-09-15
  (source: https://github.com/moonrepo/moon/releases, 2026-09-18). The changelog shows a dense
  cadence of patch releases with substantial update sections, for example toolchain fixes, cache
  experiments, and daemon refactors (source: https://github.com/moonrepo/moon/blob/master/CHANGELOG.md, 2026-09-18).
- **Major version.** v2.0 is codenamed "Phobos" and is described as the project's biggest release,
  with the WASM plugin based toolchain system as its largest change
  (source: https://moonrepo.dev/blog/moon-v2.0, 2026-09-18).
- **Documentation state.** The live documentation targets moon v2 and the latest proto, while v1
  documentation is frozen and hosted separately (source: https://moonrepo.dev/docs/concepts/workspace, 2026-09-18).
- **Language coverage.** The `language` setting documents `bash`, `batch`, `go`, `javascript`,
  `php`, `python`, `ruby`, `rust`, `typescript`, `unknown`, and arbitrary custom values
  (source: https://moonrepo.dev/docs/config/project, 2026-09-18). The FAQ lists the web ecosystem
  focus as Node.js, Rust, Go, PHP, Python, and similar, and says moon was designed to be language
  agnostic and pluggable (source: https://moonrepo.dev/docs/faq, 2026-09-18).
- **Toolchain maturity tiers.** Support is graded Tier 0 (unsupported, runs through the system
  toolchain), Tier 1 (language), Tier 2 (ecosystem), and Tier 3 (toolchain via proto), with Tier 3
  being the final tier that installs and executes tools
  (source: https://moonrepo.dev/docs/how-it-works/languages, 2026-09-18).
- **Recent additions.** Ruby toolchain support and Poetry package manager support were added as
  unstable features, MCP tools and task tags arrived in recent releases, and a content-addressable
  storage cache experiment landed (source: https://github.com/moonrepo/moon/blob/master/CHANGELOG.md, 2026-09-18).
- **Unstable surfaces.** The daemon and several experiments (native file hashing, CAS outputs
  cache, async affected tracking) are recent and marked as experiments
  (source: https://github.com/moonrepo/moon/blob/master/CHANGELOG.md, 2026-09-18).
- **Ecosystem.** moon sits alongside proto (version manager) and warpgate in the same vendor
  toolchain, publishes the `@moonrepo/cli` npm package, maintains a plugins repository, and ships
  editor integration such as a VS Code extension
  (source: https://moonrepo.dev/docs/install, 2026-09-18).
- **Licensing and ownership.** MIT, held by moonrepo, Inc., which indicates a company-backed
  project rather than a single maintainer (source: https://github.com/moonrepo/moon/blob/master/LICENSE, 2026-09-18).

## 5. Market Positioning

moon competes primarily in the JavaScript and TypeScript monorepo tooling market. The strongest
evidence is not a marketing statement but the shipped migration extensions: `migrate-nx` and
`migrate-turborepo` exist specifically to convert Nx and Turborepo repositories to moon
(source: https://moonrepo.dev/docs/guides/extensions, 2026-09-18). Nx and Turborepo are the
incumbent JS monorepo task runners.

Its differentiation rests on four claims from primary sources:

1. **Rust foundation for speed and low memory.** The README frames Rust as the reason for robust
   speeds, high performance, and low memory usage
   (source: https://github.com/moonrepo/moon, 2026-09-18).
2. **Bazel-inspired hashing and caching.** Smart hashing, incremental builds, and a remote cache
   modeled on the Bazel Remote Execution API bring concepts from hermetic build systems into a
   JavaScript-friendly wrapper (source: https://github.com/moonrepo/moon, 2026-09-18).
3. **Incremental adoption.** The README explicitly rejects all-at-once adoption in favor of
   migrating project by project or task by task
   (source: https://github.com/moonrepo/moon, 2026-09-18).
4. **Integrated toolchain and package manager awareness.** moon installs tool versions through proto
   and understands package manager workspaces, rather than treating a monorepo as a bag of shell
   commands (source: https://moonrepo.dev/docs/concepts/toolchain, 2026-09-18).

Where it does not compete: moon is not a general purpose build system with a rule language, and it
does not define compilation. It wraps the ecosystem's existing commands. Versioning and publishing
of packages are explicitly out of scope, with the documentation recommending Yarn releases,
Changesets, or Lerna instead (source: https://moonrepo.dev/docs/faq, 2026-09-18).

For PolyOrch's competitive table, the critical correction is this: the whitepaper groups moon with
polyglot orchestrators, but moon's own primary sources describe a web-ecosystem-first tool whose
multi-language support is a long-term vision implemented through opt-in WASM toolchains
(source: https://moonrepo.dev/docs/how-it-works/languages, 2026-09-18). moon has real Rust, Go,
Python, PHP, and Ruby toolchains, but its center of gravity, migration tooling, and documentation
all point at JavaScript and TypeScript. It also has no native CMake, Xmake, Meson, or Colcon
dispatch: native C and C++ projects are handled either through language toolchains such as Rust or
through `system` toolchain shell commands, not through first-class build engine adapters
(source: https://moonrepo.dev/docs/how-it-works/languages, 2026-09-18).

## 6. Product Highlights

- **Conceptual separation of graphs.** Project graph, task graph, and action graph are distinct
  artifacts, and the action graph is a typed execution plan rather than a flat command list
  (source: https://moonrepo.dev/docs/how-it-works/action-graph, 2026-09-18).
- **Open remote cache protocol.** REAPI compatibility means moon interoperates with the existing
  remote cache ecosystem instead of inventing a private one
  (source: https://github.com/moonrepo/moon/blob/master/Cargo.toml, 2026-09-18).
- **Cache tuning per dependency edge.** `cacheStrategy` lets a task decide how an upstream
  dependency's changes should invalidate it, which is a more precise model than blanket
  hash-everything invalidation (source: https://github.com/moonrepo/moon/blob/master/CHANGELOG.md, 2026-09-18).
- **Configuration based inheritance.** `inheritedBy` makes task sharing declarative and condition
  driven instead of dependent on filename conventions
  (source: https://moonrepo.dev/blog/moon-v2.0, 2026-09-18).
- **Toolchain as a plugin boundary.** Making languages WASM plugins is a strong extensibility
  precedent for any orchestrator that expects new backends over time
  (source: https://moonrepo.dev/docs/how-it-works/languages, 2026-09-18).
- **Toolchain version pinning through proto.** Per workspace or per project tool versions reduce
  environment drift (source: https://moonrepo.dev/docs/concepts/toolchain, 2026-09-18).
- **Batteries included infrastructure.** Code generation, CODEOWNERS, Docker flows, VCS hooks,
  webhooks, notifications, and flakiness retries are all in the core product
  (source: https://github.com/moonrepo/moon, 2026-09-18).
- **Daemon with file watching.** Background cache invalidation on file change is a meaningful
  developer-experience and correctness feature
  (source: https://github.com/moonrepo/moon/blob/master/CHANGELOG.md, 2026-09-18).
- **AI assistant integration.** An MCP crate exposes moon to coding assistants
  (source: https://api.github.com/repos/moonrepo/moon/contents/crates, 2026-09-18).

## 7. Value to PolyOrch

### [Adopt] Directly reusable

- **[Adopt] Split the graph into project graph, task graph, and action graph.** PolyOrch should
  define a project graph (monorepo packages), a task graph (user intent, for example `build` or
  `test`), and an action graph (engine-specific invocations: a CMake configure step, an Xmake
  build, a Colcon build). moon proves this separation is workable at scale and makes affected
  selection and cache invalidation tractable
  (source: https://moonrepo.dev/docs/how-it-works/action-graph, 2026-09-18).
- **[Adopt] A typed action pipeline with named phases.** Model explicit phases analogous to
  sync-workspace, setup-toolchain, setup-environment, install-dependencies, sync-project, and
  run-task. For PolyOrch these map to environment activation (Pixi), dependency resolution
  (vcpkg and Conan through Xmake namespaces), configure, and build. Named phases give PolyOrch
  stable extension points and observable progress
  (source: https://moonrepo.dev/docs/how-it-works/action-graph, 2026-09-18).
- **[Adopt] Content-addressable cache with an open remote protocol.** PolyOrch deals in expensive
  native artifacts, so a CAS plus an REAPI-compatible remote cache lets it reuse existing cache
  servers rather than shipping its own. moon's choice of `bazel-remote-apis` is the precedent to
  copy (source: https://github.com/moonrepo/moon/blob/master/Cargo.toml, 2026-09-18).
- **[Adopt] Per-dependency cache invalidation strategy.** PolyOrch should support a `cacheStrategy`
  concept so that a downstream native build is invalidated by upstream outputs when appropriate and
  by upstream inputs only when necessary. This directly reduces rebuild cost in C and C++ graphs
  (source: https://github.com/moonrepo/moon/blob/master/CHANGELOG.md, 2026-09-18).
- **[Adopt] Smart hashing that aggregates inputs from multiple sources.** Inputs should include
  source files, environment and tool versions, engine configuration, and dependency state, not just
  file contents. This is the stated goal of moon's hashing model and is directly applicable to
  native builds where toolchain version materially changes output
  (source: https://github.com/moonrepo/moon, 2026-09-18).
- **[Adopt] Configuration based task inheritance with explicit conditions.** PolyOrch should let a
  shared task definition declare the projects it applies to by language, engine, layer, or tag,
  rather than relying on directory naming conventions. Adopt the `inheritedBy` pattern
  (source: https://moonrepo.dev/blog/moon-v2.0, 2026-09-18).
- **[Adopt] Project discovery by glob plus explicit mapping.** Support both glob discovery of
  project roots and an explicit map, with collision detection that warns and skips rather than
  producing an invalid graph. moon documents exactly this behavior
  (source: https://moonrepo.dev/docs/config/workspace, 2026-09-18).
- **[Adopt] A background daemon with file watching and cache invalidation.** For long-lived
  developer sessions, a daemon that watches the workspace and invalidates cached state removes a
  whole class of stale-cache bugs. Adopt the concept, and adopt moon's operational safeguards:
  advisory file lock ownership and version-checking on connect
  (source: https://github.com/moonrepo/moon/blob/master/CHANGELOG.md, 2026-09-18).
- **[Adopt] Toolchain version pinning as a first-class concept.** PolyOrch should pin compiler and
  tool versions per workspace or per project. The mechanism in PolyOrch is Pixi, and the discipline
  to copy is moon's explicit per-project version configuration
  (source: https://moonrepo.dev/docs/concepts/toolchain, 2026-09-18).
- **[Adopt] Schema generated configuration.** moon uses `schematic` to generate configuration
  schemas. PolyOrch should generate a schema for `polyorch.toml` so editors and validators catch
  errors before a build starts (source: https://github.com/moonrepo/moon/blob/master/Cargo.toml, 2026-09-18).
- **[Adopt] Expose an MCP surface.** A machine-readable interface for AI assistants is cheap to add
  and increasingly expected. moon ships an `mcp` crate; PolyOrch should expose graph queries and
  dispatch status over MCP
  (source: https://api.github.com/repos/moonrepo/moon/contents/crates, 2026-09-18).
- **[Adopt] Target identifiers of the form `scope:task`.** A stable, greppable compound identifier
  for targets is a small design decision with outsized usability benefit, and it is compatible with
  a CLI that must address both projects and build tasks
  (source: https://moonrepo.dev/docs/concepts/target, 2026-09-18).

### [Adapt] Reusable with modification

- **[Adapt] Toolchain plugins as the extension model: use native Rust adapter traits first, WASM
  later.** moon implements every language as an isolated WASM plugin, which buys sandboxing and
  third-party extensibility at the cost of a serialization boundary. PolyOrch adapters for CMake,
  Xmake, Meson, and Colcon need deep, possibly synchronous access to engine state, configure and
  build graphs, and error streams. Define a native `Adapter` trait in Rust as the primary contract,
  and layer an optional WASM plugin path behind it only if third-party adapters become a
  requirement. Take moon's isolation goal and its typed configuration API (`define_extension_config`)
  without taking the WASM boundary as the mandatory first step
  (source: https://moonrepo.dev/docs/guides/extensions, 2026-09-18).
- **[Adapt] Tiered support levels as adapter maturity levels.** moon grades language support from
  Tier 0 to Tier 3. PolyOrch should publish an equivalent maturity ladder for each build engine
  adapter, for example dispatch only, dependency inference, incremental build, and full cache
  integration. Adopting the tier vocabulary sets honest expectations without copying moon's
  specifics (source: https://moonrepo.dev/docs/how-it-works/languages, 2026-09-18).
- **[Adapt] A `system` escape hatch.** moon provides an always-enabled `system` toolchain for
  arbitrary commands. PolyOrch should offer a comparable escape hatch for projects that do not yet
  have an adapter, while keeping it clearly labeled as the lowest maturity level so users know they
  lose caching and graph awareness (source: https://moonrepo.dev/docs/how-it-works/languages, 2026-09-18).
- **[Adapt] Task inheritance keyed to engines, not just languages.** moon inherits by language,
  stack, layer, tags, and files. PolyOrch's projects may share a language but use different build
  engines, so the condition set should include engine or adapter identity as a first-class key
  (source: https://moonrepo.dev/blog/moon-v2.0, 2026-09-18).
- **[Adapt] Remote cache configuration shape.** Copy the idea of a named cache instance so one
  server can host multiple repositories, but keep PolyOrch's remote cache an optional backend, not
  a required service, so local-only workflows stay first class
  (source: https://moonrepo.dev/docs/config/workspace, 2026-09-18).
- **[Adapt] Docker integration to a Pixi-based environment model.** moon's Docker flow prunes and
  scaffolds workspace aware images. PolyOrch should implement the analogous flow around Pixi
  environments and lockfiles rather than around node_modules
  (source: https://moonrepo.dev/docs/config/workspace, 2026-09-18).
- **[Adapt] Affected detection to native build semantics.** moon selects affected projects from VCS
  changes. PolyOrch must extend the same idea to engine level granularity, because a changed header
  can affect many targets inside one project. Adopt the affected-selection pipeline, adapt the unit
  of selection downward to targets where an engine can report it
  (source: https://moonrepo.dev/docs/config/workspace, 2026-09-18).
- **[Adapt] Action distribution cautiously.** moon claims action distribution across machines. For
  PolyOrch, distributing native compilers and environments is far harder than distributing a Node
  task, so treat this as a long-term adapt item gated on reproducible Pixi environments and cacheable
  artifacts, not as an early feature
  (source: https://github.com/moonrepo/moon, 2026-09-18).
- **[Adapt] Configuration file split.** moon spreads configuration across `.moon/workspace.*`,
  `.moon/toolchains.*`, `.moon/tasks.*`, and `.moon/extensions.*`. PolyOrch's stated shape is
  `polyorch.toml` plus `xmake.lua`. Keep that smaller surface, but borrow the separation of concerns
  by allowing referenced task files rather than one monolithic file
  (source: https://moonrepo.dev/docs/config/workspace, 2026-09-18).

### [Avoid] Known pitfalls / not applicable

- **[Avoid] Do not treat moon as evidence that JS-first orchestration transfers to polyglot native
  builds.** moon's own documentation states a JavaScript-ecosystem focus and a long-term
  multi-language vision. Its multi-language support works by wrapping each language's package
  manager and tool, and it has no first-class CMake, Xmake, Meson, or Colcon adapter. PolyOrch must
  not model its core value proposition on moon's task-wrapper model, because dispatching real build
  engines with correct configure and build graphs is a different problem
  (source: https://moonrepo.dev/docs/how-it-works/languages, 2026-09-18).
- **[Avoid] Do not adopt a task model that merely spawns shell commands.** moon tasks are commands
  or shell scripts, and piping between tasks is not possible inside its pipeline. If PolyOrch
  copied this, it would lose the ability to map engine level targets and to reason about
  compilation units, which is precisely where its cache and affected logic must operate
  (source: https://moonrepo.dev/docs/faq, 2026-09-18).
- **[Avoid] Do not claim or design hermetic sandboxing like Bazel.** moon is inspired by Bazel but
  does not sandbox actions or define a rule language. PolyOrch should avoid implying hermeticity it
  does not implement, and should scope its cache correctness claims to what hashing actually
  covers (source: https://github.com/moonrepo/moon, 2026-09-18).
- **[Avoid] Do not let a WASM plugin boundary define the adapter contract.** moon's toolchain
  plugins must cross an Extism serialization boundary. For adapters that need to stream compiler
  output, inspect engine graphs, or expose callbacks, this boundary is a ceiling. Avoid making WASM
  the required adapter mechanism in PolyOrch v1
  (source: https://github.com/moonrepo/moon/blob/master/Cargo.toml, 2026-09-18).
- **[Avoid] Do not make remote cache mandatory or vendor specific.** moon defaults its remote cache
  instance name to `moon-outputs` and uses a specific protocol. PolyOrch should keep local cache as
  the default path and remote cache as an opt-in backend, so a repository without cache
  infrastructure still works (source: https://moonrepo.dev/docs/config/workspace, 2026-09-18).
- **[Avoid] Do not rely on unstable features for core guarantees.** moon marks its daemon and
  several performance experiments as unstable or experimental. Any PolyOrch design that depends on
  equivalent mechanisms must define its own stability policy and not assume experiment status is
  permanent (source: https://github.com/moonrepo/moon/blob/master/CHANGELOG.md, 2026-09-18).
- **[Avoid] Do not copy filename based task inheritance.** moon moved away from inheritance based on
  file naming conventions toward explicit `inheritedBy` configuration. PolyOrch should start from
  the explicit configuration model and skip the legacy convention entirely
  (source: https://moonrepo.dev/blog/moon-v2.0, 2026-09-18).
- **[Avoid] Do not expand scope into package versioning and publishing.** moon explicitly does not
  version or publish packages and defers to external tools. PolyOrch should keep the same boundary
  and stay a build orchestrator, not a release manager
  (source: https://moonrepo.dev/docs/faq, 2026-09-18).
- **[Avoid] Do not scatter configuration across many dot directories.** moon's config surface is
  large, with toolchain, extension, workspace, and task files. PolyOrch's documented surface is one
  `polyorch.toml` plus `xmake.lua`. Avoid mirroring moon's directory sprawl; add files only when a
  concrete concern cannot fit (source: https://moonrepo.dev/docs/config/workspace, 2026-09-18).
- **[Avoid] Do not reuse moon's acronym framing or naming.** moon's name expansion and graph
  vocabulary are specific to its brand. PolyOrch should borrow mechanisms, not terminology, to keep
  its own naming consistent with the whitepaper's canonical strings
  (source: https://github.com/moonrepo/moon, 2026-09-18).

## Appendix

### Quick facts

| Field | Value | Source (researched 2026-09-18) |
|---|---|---|
| Repository | `github.com/moonrepo/moon` | https://github.com/moonrepo/moon |
| Latest version | v2.5.5 (2026-09-15) | https://github.com/moonrepo/moon/releases |
| License | MIT, Copyright (c) 2021 moonrepo, Inc. | https://github.com/moonrepo/moon/blob/master/LICENSE |
| Implementation | Rust, Cargo workspace, over 70 crates | https://github.com/moonrepo/moon/blob/master/Cargo.toml |
| Config files | `moon.yml`, `.moon/workspace.*`, `.moon/toolchains.*`, `.moon/tasks.*`, `.moon/extensions.*` | https://moonrepo.dev/docs/config/workspace |
| Self description | Repository management, organization, orchestration, and notification tool for the web ecosystem | https://github.com/moonrepo/moon |
| Extension model | WASM plugins via Extism and a Rust PDK | https://moonrepo.dev/docs/guides/extensions |
| Remote cache | Bazel Remote Execution API (`bazel-remote-apis`) | https://github.com/moonrepo/moon/blob/master/Cargo.toml |
| Languages (documented) | bash, batch, go, javascript, php, python, ruby, rust, typescript, custom | https://moonrepo.dev/docs/config/project |
| Native build engines | None first-class (CMake, Meson, Ninja, Colcon absent) | https://moonrepo.dev/docs/how-it-works/languages |
| Platforms | Linux, macOS, Windows | https://github.com/moonrepo/moon |
