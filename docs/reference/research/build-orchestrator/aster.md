# Aster Profile

> Sources: https://github.com/ArchAstro/aster, https://api.github.com/repos/ArchAstro/aster, https://crates.io/api/v1/crates/aster, https://github.com/ArchAstro/aster/blob/main/README.md, https://github.com/ArchAstro/aster/blob/main/Cargo.toml, https://github.com/ArchAstro/aster/blob/main/GETTING_STARTED.MD, https://github.com/ArchAstro/aster/blob/main/CONTRIBUTING.md, https://github.com/ArchAstro/aster/blob/main/GOVERNANCE.md, https://github.com/ArchAstro/aster/blob/main/docs/OPEN_SOURCE_READINESS.md, https://github.com/ArchAstro/aster/tree/main/src/plugins, https://github.com/ArchAstro/aster/blob/main/src/plugins/mod.rs, https://github.com/ArchAstro/aster/blob/main/src/cli/commands.rs, https://github.com/ArchAstro/aster/blob/main/src/cli/skills.md, https://github.com/ArchAstro/aster/blob/main/src/lib.rs, https://github.com/ArchAstro/aster/releases. Researched 2026-09-18.
> Not a derived document: facts here are externally sourced.

## 1. Product Profile

Aster is a build orchestrator for polyglot monorepos. It discovers projects across
several language ecosystems, connects their local dependencies into one graph, and
runs targets in dependency order while independent targets run in parallel (source:
https://github.com/ArchAstro/aster/blob/main/README.md, 2026-09-18). The repository is
public, written in Rust, and licensed MIT. It was created on 2026-01-23 and last
received a push on 2026-09-15 (source: https://api.github.com/repos/ArchAstro/aster,
2026-09-18). The GitHub description reads "A simple mono-repo build tool." while the
README opens with "Aster is a build orchestrator for polyglot monorepos." (source:
https://api.github.com/repos/ArchAstro/aster and
https://github.com/ArchAstro/aster/blob/main/README.md, 2026-09-18).

| Field | Value | Source (2026-09-18) |
|---|---|---|
| Repository | `github.com/ArchAstro/aster` | https://api.github.com/repos/ArchAstro/aster |
| Current version | v0.14.1 (published 2026-08-28) | https://github.com/ArchAstro/aster/releases |
| Version in tree | `0.14.1` | https://github.com/ArchAstro/aster/blob/main/Cargo.toml |
| License | MIT | https://api.github.com/repos/ArchAstro/aster/license |
| Implementation | Rust, edition 2021, MSRV 1.88 | https://github.com/ArchAstro/aster/blob/main/Cargo.toml |
| Config | `aster.toml` (workspace root and per project) | https://github.com/ArchAstro/aster/blob/main/README.md |

In one line: a local, single-binary, language-ecosystem task runner with a dependency
graph, a local execution cache, Git-diff affected selection, file watching, and an
unusually rich local development-services supervisor (source:
https://github.com/ArchAstro/aster/blob/main/README.md, 2026-09-18).

## 2. Technical Characteristics

### Overall Architecture

The crate exposes a library (`src/lib.rs`) plus a binary (`src/main.rs`), partitioned
into purpose-named modules (source:
https://github.com/ArchAstro/aster/blob/main/src/lib.rs, 2026-09-18):

| Module | Responsibility |
|---|---|
| `address` | Parses workspace-relative project and target addresses |
| `config`, `discovery` | Loads `aster.toml`; scans for language markers into `DiscoveredProject` |
| `plugins` | One language plugin per ecosystem plus a `PluginRegistry` |
| `graph`, `targets` | Builds the project/target graph, detects cycles, resolves a plan |
| `executor` | Runs the plan and records execution results |
| `cache` | Content-aware local memoization (`hasher`, `matcher`, `store`) |
| `git` | `AffectedDetector` for merge-base based change selection |
| `watch`, `dev`, `ui` | Filesystem watching, service supervision, terminal rendering |

The data flow is: discover projects, parse each project's native config through its
language plugin, resolve local dependency edges into a graph, resolve a target
selection into an ordered plan, then execute with parallelism and caching (source:
https://github.com/ArchAstro/aster/blob/main/src/lib.rs and
https://github.com/ArchAstro/aster/blob/main/src/cli/skills.md, 2026-09-18).

### Key Capabilities

- One dependency graph spanning Rust, Node.js, Go, Python, Elixir, Java, Kotlin, and
  Ruby projects, while each ecosystem keeps using its native tooling (source:
  https://github.com/ArchAstro/aster/blob/main/README.md, 2026-09-18).
- Dependency-ordered execution with parallel independent work, and downstream targets
  stopped when a prerequisite fails (source:
  https://github.com/ArchAstro/aster/blob/main/docs/OPEN_SOURCE_READINESS.md,
  2026-09-18).
- Local content-aware caching with per-target opt-in and declared outputs, plus Git
  affected selection over the merge base and uncommitted changes (source:
  https://github.com/ArchAstro/aster/blob/main/README.md and
  https://github.com/ArchAstro/aster/blob/main/src/cli/skills.md, 2026-09-18).
- Watch mode that observes a target's transitive dependency closure; stream targets
  stay running and restart on change (source:
  https://github.com/ArchAstro/aster/blob/main/README.md, 2026-09-18).

### Tech Stack

Direct dependencies of note include `clap`, `petgraph`, `ignore`, `globset`, `serde`,
`toml`, `git2`, `notify`, `crossbeam-channel`, `sha2`, `ratatui`, `crossterm`,
`shell-words`, `fs2`, and `tokio`, `hyper`, `rustls` for the daemon and TLS edge
(source: https://github.com/ArchAstro/aster/blob/main/Cargo.toml, 2026-09-18). There
is no dependency on Xmake, CMake, Meson, Colcon, Pixi, vcpkg, or Conan (source:
https://github.com/ArchAstro/aster/blob/main/Cargo.toml, 2026-09-18).

## 3. Feature Overview

### Core Modules

Discovery is marker-based. The README lists the marker for each supported language:
`Cargo.toml`, `package.json`, `go.mod`, `pyproject.toml`, `mix.exs`, Gradle or Maven
plus `.java`/`.kt`, and `Gemfile` or `*.gemspec` (source:
https://github.com/ArchAstro/aster/blob/main/README.md, 2026-09-18). The plugin
directory holds one module per ecosystem (`rust.rs`, `nodejs.rs`, `go.rs`,
`python.rs`, `elixir.rs`, `gradle.rs`, `maven.rs`, `ruby.rs`) plus a shared `jvm.rs`
and the `registry.rs` (source:
https://github.com/ArchAstro/aster/tree/main/src/plugins, 2026-09-18).

Targets come from native tooling or from `aster.toml`; detected names include `deps`,
`build`, `test`, `lint`, `format`, `typecheck`, `dev`, and `clean`, depending on the
tools present (source: https://github.com/ArchAstro/aster/blob/main/src/cli/skills.md, 2026-09-18).

### Notable Features

**Project addressing.** Addresses are workspace-relative: `//services/api` is a
project, `//services/api:test` is one target, `//self:test` refers to the current
project's target, `//...` is the whole workspace, `./...` is below the current
directory, and `-//vendor/...` excludes a subtree. An `aster target <name>` escape
hatch exists for target names that collide with built-in commands (source:
https://github.com/ArchAstro/aster/blob/main/src/cli/skills.md and
https://github.com/ArchAstro/aster/blob/main/src/cli/commands.rs, 2026-09-18).

**Build system versus language identity.** Java and Kotlin are detected independently
from Gradle and Maven, and one Gradle or Maven project may report either or both
languages (source:
https://github.com/ArchAstro/aster/blob/main/README.md, 2026-09-18). The plugin trait
exposes `languages()` (defaulting to the plugin name) and `build_system()`, so a
build-system plugin can detect source languages separately from the backend that
executes targets (source:
https://github.com/ArchAstro/aster/blob/main/src/plugins/mod.rs, 2026-09-18).

**Marker-conflict arbitration.** Maven takes precedence over Gradle in one directory,
a colocated `package.json` keeps the existing Node.js project rather than creating a
conflicting Gradle address, and pure aggregator roots and embedded integration-test
fixtures are not exposed as standalone projects (source:
https://github.com/ArchAstro/aster/blob/main/README.md, 2026-09-18).

**Command execution semantics.** Target commands are parsed like a shell command line
for quoting, escaping, and leading `NAME=value` assignments, but are executed
directly: pipes, redirects, `&&`, substitutions, and glob expansion are not
interpreted unless a shell is invoked explicitly. Captured targets receive a closed
stdin so prompting tools fail instead of hanging behind the progress UI; streaming
targets inherit the terminal (source:
https://github.com/ArchAstro/aster/blob/main/README.md, 2026-09-18).

**Cache semantics.** The local cache memoizes successful target executions and does
not restore artifacts. Default cacheable names are `deps`, `build`, `test`, `lint`,
`format`, `typecheck`, and `check`; other targets opt in with `cache.enabled = true`.
`include`, `exclude`, and `env` extend detected inputs, and declared `outputs` must
still exist for a cached success to be reused (source:
https://github.com/ArchAstro/aster/blob/main/README.md, 2026-09-18).

**Affected selection.** `aster affected <target> --base=<ref>` compares `HEAD` with
the merge base of `HEAD` and `--base`, then includes uncommitted changes. Flags
include `--head`, `--dependents`, `--lane` (a configured named subset), `--dry-run`,
`--only-affected-files`, and `--warnings-as-errors`; a root `[affected] ignore` list
excludes paths (source:
https://github.com/ArchAstro/aster/blob/main/src/cli/commands.rs, 2026-09-18).

**Development services.** `aster services up` supervises long-lived `stream = true`
targets in one dashboard. Named ports are static or dynamically allocated; a dynamic
root leases a collision-free bundle per supervisor, and a worktree-scoped manifest
lets `services kill-ports` recover orphaned listeners after a crash. Services can be
grouped, given per-group control ports, proxied, persisted to
`.aster/logs/<worktree>/<service>/logs.txt` with a 10 MiB cap, and optionally placed
behind a local mkcert-based HTTPS edge (source:
https://github.com/ArchAstro/aster/blob/main/README.md, 2026-09-18).

### Extensibility / Plugin Mechanism

Extensibility is compile-time. A `LanguagePlugin` trait defines `name()`,
`marker_files()`, `matches_marker()`, `should_skip()`, `parse_project()`,
`parse_dependencies()`, `detect_targets()`, `with_files_list()`,
`with_warnings_as_errors()`, `cache_inputs()`, and `clean_target()` (source:
https://github.com/ArchAstro/aster/blob/main/src/plugins/mod.rs, 2026-09-18). The
concrete plugins are declared in `plugins/mod.rs` and registered through
`PluginRegistry`; there is no dynamic loading and no third-party plugin ABI (source:
https://github.com/ArchAstro/aster/blob/main/src/plugins/mod.rs, 2026-09-18).

A `Target` carries `command`, `depends_on`, `capabilities`, `files_glob`, `stream`,
`cache`, `invalidates_cache`, `working_dir`, and `exclusive_resources`. The
`TargetCapability` enum defines `FilesList` and `WarningsAsErrors` (source:
https://github.com/ArchAstro/aster/blob/main/src/plugins/mod.rs, 2026-09-18). The
README states that only the `files_list` capability is accepted in configuration
(source: https://github.com/ArchAstro/aster/blob/main/README.md, 2026-09-18), while
the CLI documents `--warnings-as-errors` for targets that support it (source:
https://github.com/ArchAstro/aster/blob/main/src/cli/skills.md, 2026-09-18).
Per-target config also supports aliases (`check = { alias = "test" }`), `depends_on`
edges including `//self:target`, cache inputs and outputs, and named exclusive
resources (source: https://github.com/ArchAstro/aster/blob/main/README.md, 2026-09-18).

## 4. Status & Ecosystem

Aster is public, active, and pre-1.0. The latest release is v0.14.1 (2026-08-28); the
seven releases from v0.10.2 (2026-08-10) to v0.14.1 span eighteen days, five of them
minor bumps (source: https://github.com/ArchAstro/aster/releases, 2026-09-18). Assets
for v0.14.1 include Linux x64, macOS x64, macOS arm64, Debian, RPM, and Arch packages,
an archive keyring, and a `SHA256SUMS` file (source: https://github.com/ArchAstro/aster/releases, 2026-09-18).

Installation is through a Homebrew tap (`brew install ArchAstro/tools/aster`) or
`cargo install --git`. The crates.io name `aster` is occupied by an unrelated crate
(`serde-rs/aster`, "A libsyntax ast builder", last updated 2017-01-27), and Aster
does not appear to be published there under its own name (source:
https://github.com/ArchAstro/aster/blob/main/README.md and
https://crates.io/api/v1/crates/aster, 2026-09-18).

Community size is small. As of 2026-09-18 the repository has 66 stars, 1 fork, 3 open
issues, 0 watchers, and GitHub Discussions enabled (source:
https://api.github.com/repos/ArchAstro/aster, 2026-09-18). The contributors endpoint
lists six entries including the Dependabot bot and one anonymous entry; the named
accounts are `cgrunewald`, `calvin-archastro`, `bruno-archastro`, and `ark-archastro`
(source: https://api.github.com/repos/ArchAstro/aster/contributors, 2026-09-18).

Project hygiene is deliberate: the repository ships `CONTRIBUTING.md`,
`CODE_OF_CONDUCT.md`, `SECURITY.md`, `SUPPORT.md`, `GOVERNANCE.md`, issue forms, and a
pull-request template, and CI runs `cargo fmt --check`, `cargo clippy -D warnings`,
`cargo doc` with warnings denied, the test suite, and `cargo audit` (source:
https://github.com/ArchAstro/aster/blob/main/CONTRIBUTING.md, 2026-09-18). Governance
reserves final decisions to the ArchAstro maintainers when consensus fails (source:
https://github.com/ArchAstro/aster/blob/main/GOVERNANCE.md, 2026-09-18). A readiness
checklist records completed items (advisory updates, duplicate-address rejection,
downstream stop-on-failure, cache defaults, release gating, restricted workflow
permissions, secret scan, checksums and build provenance, Dependabot, code scanning)
with two open: required reviews, and private vulnerability reporting (source:
https://github.com/ArchAstro/aster/blob/main/docs/OPEN_SOURCE_READINESS.md,
2026-09-18). Windows is not built or tested despite `windows-sys` dependencies and a
`windows_process` module (source: https://github.com/ArchAstro/aster/blob/main/README.md,
2026-09-18).

## 5. Market Positioning

Aster occupies the same category that the PolyOrch whitepaper names for itself: a
build orchestrator for polyglot monorepos. Its concrete competitor set in that
category is moon, Pants, Bazel, and Buck2 (all listed in the PolyOrch reference
index), and its distinguishing bet is breadth of application-language coverage with
native tooling retained per ecosystem (source:
https://github.com/ArchAstro/aster/blob/main/README.md, 2026-09-18).

Two boundaries separate Aster from the C/C++ oriented orchestrator space that PolyOrch
targets:

1. Aster has no C or C++ build-system plugin. The supported-marker table covers Rust,
   Node.js, Go, Python, Elixir, Java, Kotlin, and Ruby, and the plugin directory
   contains no CMake, Meson, Xmake, or Colcon module (source:
   https://github.com/ArchAstro/aster/blob/main/README.md and
   https://github.com/ArchAstro/aster/tree/main/src/plugins, 2026-09-18).
2. Aster has no environment manager and no C/C++ dependency manager integration.
   There is no Pixi, conda, vcpkg, or Conan dependency in `Cargo.toml`, and no
   configuration surface for them (source:
   https://github.com/ArchAstro/aster/blob/main/Cargo.toml and
   https://github.com/ArchAstro/aster/blob/main/README.md, 2026-09-18).

The product also spans local development ergonomics (services supervisor, dynamic port
leasing, TLS edges, terminal dashboard) beyond build orchestration (source:
https://github.com/ArchAstro/aster/blob/main/README.md, 2026-09-18).

## 6. Product Highlights

1. **Project address grammar.** A compact, uniform scheme for projects and targets,
   with ancestry (`//...`), relative (`./...`), self (`//self:`), and exclusion
   (`-//...`) forms, shared by every command (source:
   https://github.com/ArchAstro/aster/blob/main/src/cli/skills.md, 2026-09-18).
2. **Build system decoupled from language.** The plugin trait models `languages()` and
   `build_system()` separately, so identity and execution backend need not coincide
   (source: https://github.com/ArchAstro/aster/blob/main/src/plugins/mod.rs,
   2026-09-18).
3. **Explainability triad.** `list`, `graph`, and `why` answer what was found, in what
   order it runs, and why a target will run, with `--json` for tooling (source:
   https://github.com/ArchAstro/aster/blob/main/src/cli/skills.md, 2026-09-18).
4. **Agent-facing usage guide.** `aster --skills` prints a workspace-independent
   Markdown reference from the installed binary, intended to be supplied directly to
   an LLM, and states explicitly that it does not define policy for a human or an LLM
   (source: https://github.com/ArchAstro/aster/blob/main/src/cli/commands.rs and
   https://github.com/ArchAstro/aster/blob/main/src/cli/skills.md, 2026-09-18).
5. **Affected selection with lanes.** Merge-base diffing plus `--dependents`,
   `--only-affected-files`, and a `--lane` named subset make CI selection a first-class
   concept (source:
   https://github.com/ArchAstro/aster/blob/main/src/cli/commands.rs, 2026-09-18).
6. **Collision-free dynamic port bundles.** Dynamic named ports are leased as one
   atomic bundle per supervisor, with a worktree manifest enabling orphan recovery
   (source: https://github.com/ArchAstro/aster/blob/main/README.md, 2026-09-18).

## 7. Value to PolyOrch

Aster is the closest project in this reference set to PolyOrch, so the useful output
here is the delta. Aster has already solved orchestration mechanics that PolyOrch
currently only describes: a stable project/target address grammar, a graph plus
explainers, affected selection, watch mode, a local cache with per-target inputs and
outputs, and a target capability model. PolyOrch's uncontested ground is the opposite
end of the spectrum: native C/C++ build systems (CMake, Xmake, Meson, Colcon), an
environment manager (Pixi), and C/C++ dependency managers (vcpkg, Conan). Aster has
none of those (source:
https://github.com/ArchAstro/aster/tree/main/src/plugins and
https://github.com/ArchAstro/aster/blob/main/Cargo.toml, 2026-09-18).

| Dimension | Aster | PolyOrch (per whitepaper and derived docs) |
|---|---|---|
| Core integration model | Compile-time language plugins, statically registered | Adapter-based integration of build systems |
| Build engines | Ecosystem CLIs (cargo, npm, go, mix, Gradle, Maven, Bundler) | CMake, Xmake, Meson, Colcon through adapters; Xmake as native engine |
| Environments | None | Pixi |
| C/C++ dependencies | None | vcpkg, Conan, Xrepo via Xmake namespaces |
| Cache | Local memoization, no artifact restore | TBD (opportunity, see [Adapt]) |
| Config | `aster.toml` (root and per project) | `polyorch.toml`, `xmake.lua` |

### [Adopt] Directly reusable

- **Adopt the address grammar verbatim.** PolyOrch should define `//path/to/project`,
  `//path/to/project:target`, `//self:target`, `//...`, `./...`, and `-//excluded/...`
  as its canonical selection syntax, shared by every `polyorch` command and by
  `polyorch.toml` dependency edges. Aster demonstrates that one grammar can serve
  `list`, `graph`, `why`, `run`, `affected`, `watch`, and bare target commands without
  per-command variants (source:
  https://github.com/ArchAstro/aster/blob/main/src/cli/skills.md, 2026-09-18). This is
  cheap to specify and removes a class of per-adapter ambiguity.
- **Adopt the `list` / `graph` / `why` explainability triad, with `--json`.** PolyOrch
  adapters will fail in opaque ways (a CMake preset not found, a Meson subproject
  unresolved, a Conan profile missing). A `polyorch list` reporting the detected build
  system per project, a `polyorch graph` printing the resolved order, and a
  `polyorch why A B` printing the dependency path are the adapter debugging contract.
  Aster ships exactly these three with structured `--json` output (source:
  https://github.com/ArchAstro/aster/blob/main/src/cli/commands.rs, 2026-09-18).
- **Adopt the `aster target <name>` escape hatch pattern.** Reserve a
  `polyorch target <name> <selectors>` form so adapter-provided target names never
  collide with built-in subcommands (source:
  https://github.com/ArchAstro/aster/blob/main/src/cli/commands.rs, 2026-09-18).
- **Adopt strict config validation.** Treat unknown fields, unknown capability names,
  unknown dependency addresses, and invalid globs as hard errors, in adapter manifests
  and `polyorch.toml` alike. Aster documents and enforces this (source:
  https://github.com/ArchAstro/aster/blob/main/README.md, 2026-09-18).
- **Adopt explicit command-execution semantics.** State whether a PolyOrch target
  command is parsed and executed directly (no implicit shell) or handed to a shell,
  and close stdin for captured targets so a prompt cannot hang a build. Aster's rules
  are precise and documented in both the README and the skills guide (source:
  https://github.com/ArchAstro/aster/blob/main/README.md, 2026-09-18).
- **Adopt the affected-selection flag set.** `--base`, `--head`, `--dependents`,
  `--dry-run`, and a root-level path ignore list are a complete, minimal CI contract.
  Add `--only-affected-files` only for adapters that can meaningfully consume a file
  list (source: https://github.com/ArchAstro/aster/blob/main/src/cli/commands.rs,
  2026-09-18).
- **Adopt an agent-facing usage guide emitted by the binary.** PolyOrch is an
  agent-first, docs-first project; a `polyorch --skills` style Markdown reference
  printed by the installed version, workspace-independent, is directly useful and is
  already proven by Aster (source:
  https://github.com/ArchAstro/aster/blob/main/src/cli/commands.rs, 2026-09-18).
- **Adopt per-target cache inputs and outputs as configuration fields.** Let an
  adapter declare source globs, config files, environment variables, and declared
  outputs, and let users extend them per target. This is Aster's shape (source:
  https://github.com/ArchAstro/aster/blob/main/README.md, 2026-09-18) and maps cleanly
  onto Xmake and CMake inputs.
- **Adopt named exclusive resources.** Aster serializes targets that share an
  `exclusive_resources` name while leaving non-contending targets parallel (source:
  https://github.com/ArchAstro/aster/blob/main/src/plugins/mod.rs, 2026-09-18).
  PolyOrch's concrete use: serialize builds that mutate a shared Pixi environment or a
  shared vcpkg/Conan cache, without serializing the whole graph.
- **Adopt the release-hygiene baseline.** Checksums, build provenance, Dependabot,
  advisory auditing in CI, and pinned third-party actions are all listed as completed
  in Aster's readiness checklist (source:
  https://github.com/ArchAstro/aster/blob/main/docs/OPEN_SOURCE_READINESS.md,
  2026-09-18). PolyOrch, which has zero commits today, can bake these in from the first
  release instead of retrofitting them.

### [Adapt] Reusable with modification

- **Adapt the plugin trait into an external adapter contract.** Copy the trait's
  responsibilities (`marker_files`, `parse_project`, `parse_dependencies`,
  `detect_targets`, `cache_inputs`, `clean_target`, plus command-rewriting hooks) but
  do not copy its compile-time registration. Aster wires plugins in `plugins/mod.rs`
  with no dynamic loading and no third-party ABI (source:
  https://github.com/ArchAstro/aster/blob/main/src/plugins/mod.rs, 2026-09-18).
  PolyOrch's CMake, Xmake, Meson, and Colcon adapters must be independently
  versionable, so the same responsibilities should become a declared adapter protocol
  (manifest plus a documented invocation contract), not a Rust trait a contributor
  must link against. Adopt the trait shape; avoid the linkage model.
- **Adapt the `languages()` versus `build_system()` split to adapters.** Aster
  separates source language from execution backend so one Gradle or Maven project can
  report Java, Kotlin, or both (source:
  https://github.com/ArchAstro/aster/blob/main/src/plugins/mod.rs, 2026-09-18).
  PolyOrch needs the same split for the harder case: one project may be buildable by
  more than one engine (a tree with both `CMakeLists.txt` and `xmake.lua`, or a CMake
  project built through Xmake). The adapter layer should model language set and
  selected build engine as distinct, with a documented precedence rule.
- **Adapt Aster's marker-conflict arbitration into a PolyOrch engine-selection rule.**
  Aster documents precedence for coexisting markers (Maven over Gradle, a colocated
  `package.json` keeping the Node.js project, aggregator roots excluded) (source:
  https://github.com/ArchAstro/aster/blob/main/README.md, 2026-09-18). PolyOrch should
  publish the equivalent rules for `CMakeLists.txt` versus `meson.build` versus
  `xmake.lua` versus `package.xml`, and for CMake projects Xmake can also build. This
  is a specification decision PolyOrch has not made.
- **Adapt the cache as inputs and keys, not as a non-restoring store.** Aster's cache
  memoizes successful execution and explicitly does not restore artifacts; declared
  outputs must still exist for reuse (source:
  https://github.com/ArchAstro/aster/blob/main/README.md, 2026-09-18). PolyOrch should
  reuse the input model (source globs, config files, environment variables, declared
  outputs) but decide separately whether to restore artifacts, because C/C++ workflows
  (object files, Xmake build directories, vcpkg/Conan packages) benefit from artifact
  reuse in a way the application-language targets Aster optimizes for do not require.
- **Adapt the executor around build-engine invocations rather than shell commands.**
  Aster's executor runs a target `command` as a direct subprocess with dependency
  ordering, parallelism, resource mutexes, and failure propagation (source:
  https://github.com/ArchAstro/aster/blob/main/src/plugins/mod.rs and
  https://github.com/ArchAstro/aster/blob/main/README.md, 2026-09-18). PolyOrch should
  keep the DAG scheduler and the resource-serialization primitive, but make the node
  payload an adapter invocation. The orchestration layer should never need to know
  whether the underlying step is `xmake build`, `cmake --build`, `meson compile`, or
  `colcon build`.
- **Adapt the target-alias mechanism into adapter verb mapping.** Aster supports named
  aliases such as `check = { alias = "test" }` (source:
  https://github.com/ArchAstro/aster/blob/main/README.md, 2026-09-18). PolyOrch should
  map its canonical verbs (`build`, `test`, `clean`, `configure`) onto
  adapter-specific target names, so the same command means the right thing whether the
  engine is Xmake, CMake, or Meson.
- **Adapt watch mode to adapter inputs, not only source globs.** Aster watches a
  target's transitive closure, applies a debounce, and supports `suppress_paths` for
  generated feedback loops (source:
  https://github.com/ArchAstro/aster/blob/main/README.md, 2026-09-18). PolyOrch should
  additionally treat `CMakePresets.json`, `xmake.lua`, `meson.build`, `meson.options`,
  `pixi.toml`, `vcpkg.json`, and `conanfile.py` as first-class watch inputs, since
  changing a build definition must trigger a re-plan, not just a re-run.
- **Adapt dynamic resource leasing into build-resource leasing.** Aster leases
  collision-free port bundles per supervisor and records a worktree manifest for
  orphan recovery (source:
  https://github.com/ArchAstro/aster/blob/main/README.md, 2026-09-18). The
  generalization PolyOrch wants is not ports but exclusive build resources: a single
  Xmake build directory, a pinned Pixi environment, or a Conan local cache. Reuse the
  lease-plus-manifest idea; drop the port and dashboard machinery.
- **Adapt the affected `--lane` concept to PolyOrch CI tiers.** Aster's `--lane`
  selects a configured named subset of affected projects (source:
  https://github.com/ArchAstro/aster/blob/main/src/cli/commands.rs, 2026-09-18).
  PolyOrch can use the same idea to expose tiered CI (fast changed-subtree checks
  versus full native rebuilds) without inventing a second selection language.
- **Adapt the docs-versus-policy boundary in agent-facing output.** Aster's generated
  skills guide states plainly that it does not define policy for a human or an LLM
  (source: https://github.com/ArchAstro/aster/blob/main/src/cli/skills.md,
  2026-09-18). PolyOrch, which sits inside an agent toolchain, should keep that
  boundary: the emitted guide documents mechanics, while project policy lives in the
  repository's own rule files.

### [Avoid] Known pitfalls / not applicable

- **Avoid converging on Aster's ecosystem-only coverage.** Aster's supported markers
  and plugin set contain no C/C++ build system and no CMake, Meson, Xmake, or Colcon
  module (source: https://github.com/ArchAstro/aster/blob/main/README.md and
  https://github.com/ArchAstro/aster/tree/main/src/plugins, 2026-09-18). PolyOrch's
  reason to exist is the adapter layer for exactly those engines plus Pixi and
  vcpkg/Conan. Do not let the orchestration feature list (services, watch, cache)
  crowd out the differentiating integration work in early milestones.
- **Avoid a cache whose semantics are ambiguous.** Aster's documentation has to repeat
  that its cache does not restore artifacts and that declared outputs must still exist,
  in the README, the getting-started guide, and the skills guide (source:
  https://github.com/ArchAstro/aster/blob/main/README.md and
  https://github.com/ArchAstro/aster/blob/main/src/cli/skills.md, 2026-09-18). If
  PolyOrch ships a cache, define memoize versus restore in one place and make the
  behavior observable, rather than documenting around the confusion.
- **Avoid importing the development-services surface.** The services supervisor,
  terminal dashboard, dynamic port leasing, per-user daemon, control socket, proxy
  sidecars, and mkcert-based TLS edge are a large subsystem, and the TLS path depends
  on external tools (`mkcert`, `dnsmasq`) and host trust-store changes (source:
  https://github.com/ArchAstro/aster/blob/main/README.md, 2026-09-18). PolyOrch is a
  build orchestrator; this is scope PolyOrch has not committed to and should not
  absorb by default (YAGNI). If a dev-services story is ever needed, build it on the
  resource-lease primitive, not on a port-and-TLS stack.
- **Avoid a compile-time-only extension point.** Aster registers plugins statically
  and has no dynamic plugin loading or third-party ABI (source:
  https://github.com/ArchAstro/aster/blob/main/src/plugins/mod.rs, 2026-09-18).
  PolyOrch's adapter proposition fails if adding a CMake or Colcon adapter requires
  patching and recompiling the orchestrator. The adapter boundary must be a documented
  protocol from v1.
- **Avoid assuming a crates.io distribution path.** The crates.io name `aster` is
  owned by an unrelated, long-abandoned crate (`serde-rs/aster`, last updated
  2017-01-27), which is why Aster installs through a Homebrew tap or `cargo install
  --git` (source: https://crates.io/api/v1/crates/aster and
  https://github.com/ArchAstro/aster/blob/main/README.md, 2026-09-18). Before PolyOrch
  commits to a package or binary name, verify availability on the registries it
  intends to publish to, and do not plan a `cargo publish` release train that the name
  may not permit.
- **Avoid claiming platform support that CI does not exercise.** Aster carries
  `windows-sys` dependencies and a Windows process module, yet the README states
  Windows is not built or tested (source:
  https://github.com/ArchAstro/aster/blob/main/Cargo.toml and
  https://github.com/ArchAstro/aster/blob/main/README.md, 2026-09-18). PolyOrch, whose
  integration stack (Xmake, Pixi, vcpkg, Conan) is more platform-sensitive than a set
  of ecosystem CLIs, should gate any platform claim on a passing CI job for that
  platform.
- **Avoid single-vendor governance as a dependency risk.** Aster is maintained by the
  ArchAstro maintainers, with final decisions reserved to them when consensus fails,
  and the named contributors are ArchAstro accounts (source:
  https://github.com/ArchAstro/aster/blob/main/GOVERNANCE.md and
  https://api.github.com/repos/ArchAstro/aster/contributors, 2026-09-18). Do not build
  a PolyOrch requirement on Aster's roadmap; treat it as a design reference, and give
  PolyOrch an explicit governance document of its own.
- **Avoid re-implementing Aster's remote-execution gap.** Aster is a local
  orchestrator with a local cache and no remote execution or distributed scheduler
  surface (source: https://github.com/ArchAstro/aster/blob/main/README.md and
  https://github.com/ArchAstro/aster/blob/main/Cargo.toml, 2026-09-18). If PolyOrch
  pursues the scalability claim in its whitepaper, that capability must be designed
  deliberately; a local graph scheduler plus a local cache does not by itself deliver
  it, and neither Aster nor this profile supplies a proven design for it.

## Appendix: Source Map

- Behavior, config, cache, watch, services: https://github.com/ArchAstro/aster/blob/main/README.md
- Version, MSRV, dependencies: https://github.com/ArchAstro/aster/blob/main/Cargo.toml
- CLI, plugin trait, module layout: https://github.com/ArchAstro/aster/blob/main/src/cli/commands.rs, https://github.com/ArchAstro/aster/blob/main/src/plugins/mod.rs, https://github.com/ArchAstro/aster/blob/main/src/lib.rs
- Selection syntax, command execution: https://github.com/ArchAstro/aster/blob/main/src/cli/skills.md
- Plugin set: https://github.com/ArchAstro/aster/tree/main/src/plugins
- Workflow, CI, governance, readiness: https://github.com/ArchAstro/aster/blob/main/GETTING_STARTED.MD, https://github.com/ArchAstro/aster/blob/main/CONTRIBUTING.md, https://github.com/ArchAstro/aster/blob/main/GOVERNANCE.md, https://github.com/ArchAstro/aster/blob/main/docs/OPEN_SOURCE_READINESS.md
- Repo metadata and releases: https://api.github.com/repos/ArchAstro/aster, https://github.com/ArchAstro/aster/releases
- crates.io: https://crates.io/api/v1/crates/aster
