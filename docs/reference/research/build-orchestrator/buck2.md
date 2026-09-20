# Buck2 Profile

> Sources: https://github.com/facebook/buck2, https://buck2.build/, https://buck2.build/docs/, https://github.com/facebook/buck2/releases, https://github.com/facebook/buck2/tree/main/prelude, https://github.com/facebook/buck2/tree/main/dice, https://github.com/facebook/buck2/tree/main/starlark-rust, https://github.com/facebook/buck (archived Buck1), researched 2026-09-18
> Not a derived document: facts here are externally sourced.

## 1. Product Profile

Buck2 is a fast, hermetic, multi-language build system and a direct successor to the original
Buck build system, both designed by Meta (source: https://github.com/facebook/buck2, 2026-09-18).
It is open source, written primarily in Rust, and configured through Starlark build files and a
root `.buckconfig` (source: https://github.com/facebook/buck2, 2026-09-18).

**Generation disambiguation (critical).** Buck2 is not the first-generation Buck. The original
`facebook/buck`, now retroactively called "Buck1", was a Java-based build system. Its repository
is archived, and the Buck2 documentation states Buck1 "had significant limitations and has been
entirely phased out at Meta today" (source: https://buck2.build/docs/about/why/, 2026-09-18)
(source: https://github.com/facebook/buck, 2026-09-18). Every claim in this profile below refers
to Buck2 unless the text explicitly says Buck1. A reader must not transfer Buck1's Java stack,
status, or scope onto Buck2, nor treat Buck2's Rust core as a mere version bump of Buck1.

| Field | Value |
|---|---|
| Project | Buck2 |
| Repository | `github.com/facebook/buck2` |
| Origin | Meta (Facebook) |
| First generation | Buck1, `facebook/buck`, Java, archived |
| Version scheme | Date-based tags, for example `2026-09-15` |
| Latest release observed | `2026-09-15` (published 2026-09-15) |
| License | MIT OR Apache-2.0 (dual) |
| Core implementation language | Rust |
| Configuration | Starlark `BUCK` files, `.buckconfig` |
| Homepage | `https://buck2.build/` |

Version and license evidence: the releases list shows date tags with `2026-09-15` as the most
recent (source: https://github.com/facebook/buck2/releases, 2026-09-18). The README carries a
`license-MIT OR Apache-2.0` badge, and the repository states Buck2 "is licensed under both the
MIT license and Apache-2.0 license", with `LICENSE-MIT` and `LICENSE-APACHE` files (source:
https://raw.githubusercontent.com/facebook/buck2/main/README.md, 2026-09-18) (source:
https://github.com/facebook/buck2, 2026-09-18). The GitHub license detector reports the repo as
Apache-2.0 because it selects a single identifier from a dual license (source:
https://github.com/facebook/buck2, 2026-09-18).

The README labels the release channel "unstable, Developer Edition" (source:
https://raw.githubusercontent.com/facebook/buck2/main/README.md, 2026-09-18). Buck2 is available
as open source from 2023 and is used internally at Meta (source:
https://buck2.build/docs/about/why/, 2026-09-18).

## 2. Technical Characteristics

### Overall Architecture

Buck2's core is written in Rust, and Starlark, described in the official docs as "a
deterministic, immutable version of Python", is used to extend the system and keep it
language-agnostic (source: https://buck2.build/docs/concepts/architecture/, 2026-09-18). The
core knows nothing about specific languages: even C/C++ support is written as a library, and all
rules are written in Starlark (source: https://github.com/facebook/buck2, 2026-09-18). The same
run of `buck2` therefore behaves as a general graph and action engine, with language knowledge
supplied by rules rather than compiled into the binary.

The execution model is a staged pipeline. Phase A evaluates build files and constructs an
unconfigured target graph: Buck2 performs directory listings to discover packages, evaluates the
build files, expands macros into underlying rules, and converts rule attributes from Starlark to
Rust types (source: https://buck2.build/docs/concepts/architecture/, 2026-09-18). Later phases
resolve configurations and then perform analysis, where the rule receives a context object and
returns providers and declares actions (source:
https://buck2.build/docs/concepts/architecture/, 2026-09-18).

A daemon, `buckd`, is started on the first command for a project and reused on subsequent
commands; it shares cache between Buck2 invocations and monitors the project filesystem for
changes (source: https://buck2.build/docs/concepts/daemon/, 2026-09-18). There is one daemon per
project root by default, and an isolation directory can run several daemons in one project
(source: https://buck2.build/docs/concepts/daemon/, 2026-09-18).

### Key Capabilities

- **Incremental computation engine.** The repository contains a `dice/` directory. Its README
  describes DICE as "a dynamic incremental computation engine" that "supports parallel
  computation" (source: https://github.com/facebook/buck2/tree/main/dice, 2026-09-18). The docs
  publish an introduction to "Modern DICE" covering demand-driven computation, dependency
  tracking, invalidation, and early cutoff (source:
  https://buck2.build/docs/insights_and_knowledge/modern_dice/, 2026-09-18). DICE is itself dual
  MIT and Apache-2.0 licensed (source: https://github.com/facebook/buck2/tree/main/dice,
  2026-09-18).
- **Custom Starlark implementation.** Buck2 depends on `starlark-rust`, a Rust implementation of
  the Starlark language maintained at the canonical repository `facebook/starlark-rust`. The
  in-tree copy documents components including an evaluator, standard library, debugger, and LSP
  (source: https://github.com/facebook/buck2/tree/main/starlark-rust, 2026-09-18).
- **Hermetic actions.** The homepage states that "Buck2 rules are hermetic by default. Missing
  dependencies are errors", and that this applies to user-written `BUCK` files and language rules
  alike (source: https://buck2.build/, 2026-09-18).
- **Remote execution.** Buck2 consumes services that expose Bazel's Remote Execution API
  (REAPI) to run actions remotely, and has been tested against EngFlow, BuildBarn, and BuildBuddy
  (source: https://buck2.build/docs/users/remote_execution/, 2026-09-18). The README additionally
  names NativeLink and BuildBuddy as working remote execution solutions (source:
  https://raw.githubusercontent.com/facebook/buck2/main/README.md, 2026-09-18).
- **Graph introspection (BXL).** The Buck2 Extension Language is a Starlark-based script that
  lets integrators query, analyze, and build on the Buck2 graph, at the unconfigured, configured,
  provider, and action stages (source: https://buck2.build/docs/bxl/, 2026-09-18).
- **Repository scale features.** Support for ultra-large repositories using filesystem
  virtualization and filesystem watching is listed as a headline design criterion (source:
  https://raw.githubusercontent.com/facebook/buck2/main/README.md, 2026-09-18).

### Tech Stack

| Layer | Choice | Source |
|---|---|---|
| Core engine | Rust | https://buck2.build/docs/concepts/architecture/ (2026-09-18) |
| Extension language | Starlark (deterministic Python subset) | https://buck2.build/docs/concepts/architecture/ (2026-09-18) |
| Starlark runtime | `starlark-rust`, in-tree | https://github.com/facebook/buck2/tree/main/starlark-rust (2026-09-18) |
| Incremental engine | DICE, in-tree | https://github.com/facebook/buck2/tree/main/dice (2026-09-18) |
| Config format | `.buckconfig`, INI format | https://buck2.build/docs/concepts/buckconfig/ (2026-09-18) |
| Build files | Starlark `BUCK` files | https://buck2.build/docs/concepts/glossary/ (2026-09-18) |
| Remote execution | Bazel REAPI over gRPC-compatible services | https://buck2.build/docs/users/remote_execution/ (2026-09-18) |
| Daemon | `buckd`, one per project root | https://buck2.build/docs/concepts/daemon/ (2026-09-18) |

## 3. Feature Overview

### Core Modules

- **App and CLI.** The repository top level contains an `app` directory, alongside action error
  handling, dependency graph rules, and the prelude (source: https://github.com/facebook/buck2,
  2026-09-18).
- **`prelude/`.** The built-in rules live in `prelude/`. The glossary defines the prelude as
  "a unique `.bzl` file located at `prelude//prelude.bzl`" whose symbols Buck2 "implicitly loads"
  whenever it loads a `BUCK` file (source: https://buck2.build/docs/concepts/glossary/,
  2026-09-18). A Buck2 project created with `buck2 init --git` contains the same prelude used
  internally at Meta (source: https://buck2.build/docs/concepts/glossary/, 2026-09-18). The
  directory holds language rule families including `cxx`, `python`, `rust`, `java`, `kotlin`,
  `go`, `haskell`, `ocaml`, `erlang`, `js`, `julia`, `lua`, and `matlab`, plus `toolchains`,
  `platforms`, `configurations`, and `decls` (source:
  https://github.com/facebook/buck2/tree/main/prelude, 2026-09-18).
- **`dice/`.** The incremental computation engine, with subcomponents including `dice_core`,
  `dice_error`, `dice_examples`, `dice_futures`, `dice_tests`, and `fuzzy_dice` (source:
  https://github.com/facebook/buck2/tree/main/dice, 2026-09-18).
- **`starlark-rust/`.** The Starlark implementation, with components `starlark_derive`,
  `starlark_map`, `starlark_syntax`, `starlark` (evaluator and standard library), `starlark_lsp`,
  and `starlark_bin` (source:
  https://github.com/facebook/buck2/tree/main/starlark-rust, 2026-09-18).
- **Other top-level modules.** `remote_execution`, `superconsole`, `shed`, `shim`, `tests`,
  `tools`, and `website` are present at the repository root (source:
  https://github.com/facebook/buck2, 2026-09-18).

### Notable Features

- **Cells and projects.** A project is defined by the `.buckconfig` in the invoked directory or
  its nearest ancestor, and the `.buckconfig` `[cells]` section lists the cells that make up the
  build, with aliases mapped to paths (source:
  https://buck2.build/docs/concepts/key_concepts/, 2026-09-18) (source:
  https://buck2.build/docs/concepts/buckconfig/, 2026-09-18).
- **Layered configuration.** Buck2 reads `.buckconfig` and `.buckconfig.local` in the project
  root, a project-root `.buckconfig.d` directory, configuration in the user's home directory, and
  configuration under `/etc/` (source: https://buck2.build/docs/concepts/buckconfig/, 2026-09-18).
- **Rules, providers, actions.** Rules use attributes to declare actions that produce artifacts,
  and providers are the only way information flows from a rule to its dependents; every rule must
  return at least `DefaultInfo`, and executables commonly also return `RunInfo` (source:
  https://buck2.build/docs/rule_authors/writing_rules/, 2026-09-18).
- **Implicit prelude load, explicit for everything else.** Symbols defined outside the prelude
  are imported with `load()`, which executes a `.bzl` file and imports named symbols into the
  current namespace (source: https://buck2.build/docs/rule_authors/load/, 2026-09-18).
- **Bi-monthly releases plus a rolling `latest`.** The install docs describe "bi-monthly
  release" artifacts, with a dotslash file per release suitable for committing to a repository so
  every user and every commit gets a consistent version (source:
  https://buck2.build/docs/getting_started/install/, 2026-09-18). Separately, the `latest` tag is
  updated on every push to the repository (source: https://raw.githubusercontent.com/facebook/buck2/main/README.md,
  2026-09-18).

### Extensibility / Plugin Mechanism

Extensibility is rule-level, not plugin-level. All rules are written in Starlark, and users can
define their own rules as first-class citizens (source: https://buck2.build/, 2026-09-18). The
rule authoring guide prefers new rules to live outside the prelude, and notes that the only
advantage of putting a rule in the prelude is that it can be used without a corresponding
`load()`, which the same page calls "generally considered a misfeature" (source:
https://buck2.build/docs/rule_authors/writing_rules/, 2026-09-18). Beyond rules, BXL provides a
scripting surface for graph queries and tooling integration, and is described as "mostly stable"
(source: https://buck2.build/docs/bxl/, 2026-09-18).

## 4. Status & Ecosystem

Buck2 is under active development. As of the research date the repository has not been archived,
was last pushed on 2026-09-18, shows roughly 4.4k stars and 397 forks, and has on the order of
299 open issues and 101 open pull requests (source: https://github.com/facebook/buck2,
2026-09-18).

Releases follow date-based tags at a roughly twice-monthly cadence. Observed tags include
`2026-09-15`, `2026-09-01`, `2026-08-22`, `2026-08-01`, `2026-07-15`, `2026-07-01`, `2026-06-15`,
`2026-06-01`, `2026-05-18`, `2026-05-01`, and `2026-04-15` (source:
https://github.com/facebook/buck2/releases, 2026-09-18). A separate `latest` tag tracks recent
commits (source: https://raw.githubusercontent.com/facebook/buck2/main/README.md, 2026-09-18).
There is no long-term-support line and no stable major version; the README itself labels the
release channel "unstable, Developer Edition" (source:
https://raw.githubusercontent.com/facebook/buck2/main/README.md, 2026-09-18).

Language coverage is uneven and the project documents that openly. The language support page has
columns for "Prelude Available", "Usability", "Documented", and "Maintainers". C/C++ is marked
Prelude Available and "Complex Setup" and not documented; Python, Rust, Go, Erlang, Haskell, and
OCaml are "Easy Setup"; Java, Kotlin, and Java/Kotlin Mobile are "Complex Setup"; C#,
Objective-C, and Swift are "Unavailable" (source:
https://buck2.build/docs/about/language_support/, 2026-09-18).

The open-source and internal builds differ. The docs state that Meta uses an internal remote
execution binding with builds always hooked to remote execution, so the open-source binding may
be "less polished"; file watching defaults to `inotify` in open source and Watchman internally;
the prelude is the same but toolchains are not open-sourced, so custom toolchains may not work as
well; and there is not yet a mechanism to build in release mode (source:
https://buck2.build/docs/about/why/, 2026-09-18).

The generation boundary matters for ecosystem claims. Buck1, the archived `facebook/buck`
repository, is Java (source: https://github.com/facebook/buck, 2026-09-18). Buck1 is not a
supported upgrade path for Buck2 users: the docs state Buck1 was entirely phased out at Meta
(source: https://buck2.build/docs/about/why/, 2026-09-18). Buck2, by contrast, is Rust and
actively released (source: https://github.com/facebook/buck2, 2026-09-18).

## 5. Market Positioning

Buck2 targets very large, multi-language monorepos. The docs motivate the project with Meta's
monorepo, which spans C++, Python, Rust, Kotlin, Swift, Objective-C, Haskell, OCaml, and more,
and argue those repositories are beyond the capabilities of traditional build systems like
`make` (source: https://buck2.build/docs/about/why/, 2026-09-18).

The project positions itself against both its own ancestor and Bazel. Buck2 keeps a high degree
of target compatibility with Buck1 while borrowing from Bazel, Pants, Shake, and Tup (source:
https://buck2.build/docs/about/why/, 2026-09-18). Its self-declared differentiators are a
language-agnostic core with a small API, BXL introspection for tooling such as LSPs and
compilation databases, distributed compilation over Bazel's REAPI, and a design grounded in
incremental computation theory (source: https://raw.githubusercontent.com/facebook/buck2/main/README.md,
2026-09-18).

The performance claims are explicitly scoped to Buck1, not to Bazel. The comparison page reports
"nothing to do" builds dropping from 23 seconds in Buck1 to 0.1 seconds in Buck2, and real-work
benchmarks ranging from about 5% to about 42% faster than Buck1 (source:
https://buck2.build/docs/about/benefits/compared_to_buck1/, 2026-09-18). The README footnote
warns that appropriate comparisons against systems like Bazel have yet to be performed and that
Buck1 is the baseline simply because it is what existed (source:
https://raw.githubusercontent.com/facebook/buck2/main/README.md, 2026-09-18). Any buyer
comparing Buck2 to Bazel on performance is therefore comparing against a number Buck2 itself does
not claim.

Buck2 sits at the heavyweight end of the orchestrator market: a target graph, a custom
configuration language, a daemon, and optional remote execution. Its natural peers in this
research series are Bazel and Pants, not lightweight task runners.

## 6. Product Highlights

- **Language-agnostic core.** No language knowledge is compiled into the core; even C/C++ is a
  library, so the engine's surface area is small and stable across languages (source:
  https://github.com/facebook/buck2, 2026-09-18) (source: https://buck2.build/, 2026-09-18).
- **DICE incremental engine.** A dedicated, parallel, demand-driven computation engine
  underneath the build graph, with early-cutoff optimization documented publicly (source:
  https://github.com/facebook/buck2/tree/main/dice, 2026-09-18) (source:
  https://buck2.build/docs/insights_and_knowledge/modern_dice/, 2026-09-18).
- **Hermetic-by-default actions with errors on missing dependencies** (source:
  https://buck2.build/, 2026-09-18). The README footnote qualifies this: local-only build steps
  are not sandboxed, while remote execution is always hermetic by design (source:
  https://raw.githubusercontent.com/facebook/buck2/main/README.md, 2026-09-18).
- **REAPI compatibility instead of a bespoke protocol,** so existing remote execution vendors
  work without Buck2-specific servers (source:
  https://buck2.build/docs/users/remote_execution/, 2026-09-18).
- **BXL introspection API** for tooling that needs the graph, such as LSPs and compilation
  databases (source: https://buck2.build/docs/bxl/, 2026-09-18).
- **Overridable rule set.** The prelude ships in-tree and in the user's project, so rules are
  readable and forkable rather than opaque (source:
  https://buck2.build/docs/concepts/glossary/, 2026-09-18).
- **Transparent support matrix.** The language support page states usability and maintainer
  status per language rather than implying uniform support (source:
  https://buck2.build/docs/about/language_support/, 2026-09-18).

## 7. Value to PolyOrch

PolyOrch is a scalable build orchestrator for polyglot monorepos. It dispatches CMake, Xmake,
Meson, and Colcon through adapters, uses Xmake as its native build engine, Pixi for environments,
and reaches vcpkg and Conan through Xmake's `vcpkg::` and `conan::` namespaces. The points below
are written against that design.

### [Adopt] Directly reusable

- **Keep the orchestrator core language-agnostic.** Buck2 keeps all language knowledge in
  Starlark rules and even ships C/C++ support as a library (source:
  https://github.com/facebook/buck2, 2026-09-18). PolyOrch should adopt the same discipline: the
  core must know only targets, dependencies, actions, and results, and every CMake, Xmake, Meson,
  or Colcon specific should live inside its adapter. Concretely, adding a Meson feature should
  never require a core change, and the core should expose a stable adapter trait rather than
  conditionals on adapter name.
- **Fail on missing dependencies instead of ignoring them.** Buck2's stated contract is that
  "Missing dependencies are errors" (source: https://buck2.build/, 2026-09-18). PolyOrch should
  audit each adapter's declared dependencies against the Pixi environment and Xmake package
  namespaces, and error loudly when an adapter declares a requirement (a vcpkg port, a Conan
  recipe, a CMake package) that the environment cannot supply. This turns a silent misconfiguration
  into a build-time error.
- **Cache by content, invalidate by dependency.** DICE is a dynamic incremental computation
  engine with dependency-tracked invalidation and early cutoff (source:
  https://github.com/facebook/buck2/tree/main/dice, 2026-09-18) (source:
  https://buck2.build/docs/insights_and_knowledge/modern_dice/, 2026-09-18). PolyOrch should key
  adapter invocations on hashed inputs (source tree, `polyorch.toml`, Pixi lockfile, adapter
  version) so an unchanged configure step for CMake or Meson is skipped, and so a change in one
  sub-project does not force a full re-plan.
- **One root config with layered, deterministic precedence.** Buck2 reads `.buckconfig`,
  `.buckconfig.local`, a `.buckconfig.d` directory, a user-level file, and an `/etc/` file, with
  documented precedence (source: https://buck2.build/docs/concepts/buckconfig/, 2026-09-18).
  PolyOrch should define the same layered model for `polyorch.toml`: repository root, a local
  untracked override, a user-level default, with a documented precedence order. Adopt the model,
  keep the syntax TOML.
- **Ship a committed tool descriptor for reproducible versions.** Buck2 publishes a dotslash
  file per release so a repository can pin the exact orchestrator version and platform (source:
  https://buck2.build/docs/getting_started/install/, 2026-09-18). PolyOrch should commit a
  version-pinning descriptor (for example a `polyorch` entry that Pixi resolves, or a dotslash
  file if Pixi does not cover it) so every commit builds with one known orchestrator version
  regardless of the developer's machine.
- **Expose a first-class introspection surface.** BXL lets external tools inspect the graph and
  run actions programmatically (source: https://buck2.build/docs/bxl/, 2026-09-18). PolyOrch
  needs the same for IDE and CI integration: a documented command that emits the resolved target
  graph and per-adapter action plan as JSON, so a compilation database generator or an editor
  plugin does not have to parse human-readable logs.
- **Run a daemon per workspace to keep state hot.** `buckd` shares cache across invocations and
  watches the filesystem for changes (source: https://buck2.build/docs/concepts/daemon/,
  2026-09-18). PolyOrch should keep a per-workspace resident process that holds the dependency
  graph, the resolved Pixi environment, and adapter discovery results, so `polyorch build` does
  not redo environment resolution on every invocation.

### [Adapt] Reusable with modification

- **The prelude pattern, but with explicit imports.** Buck2 ships a prelude of default rules that
  are implicitly loaded (source: https://buck2.build/docs/concepts/glossary/, 2026-09-18), yet
  its own rule authoring guide calls implicit loading a "misfeature" (source:
  https://buck2.build/docs/rule_authors/writing_rules/, 2026-09-18). Adapt the good half:
  PolyOrch should ship default adapter definitions and rule presets that a repository can
  override, but overrides should be explicit in `polyorch.toml`, not implicit magic.
- **Cells as the nesting model.** Buck2 cells are aliased paths to sub-projects, each able to
  carry its own configuration (source: https://buck2.build/docs/concepts/buckconfig/, 2026-09-18).
  Adapt this to let a PolyOrch workspace contain nested sub-repositories that each carry a
  `polyorch.toml`, while Xmake remains the engine that actually executes builds inside each.
- **Providers as the only inter-module channel.** In Buck2, providers are the only way a rule
  exposes data to its dependents (source: https://buck2.build/docs/rule_authors/writing_rules/,
  2026-09-18). Adapt this as a typed contract between PolyOrch adapters (target metadata,
  artifact paths, environment requirements) so adapter-to-adapter communication is data, not
  shared mutable state.
- **The staged pipeline, mapped to PolyOrch's own phases.** Buck2 runs evaluation, then
  configuration, then analysis, then execution (source:
  https://buck2.build/docs/concepts/architecture/, 2026-09-18). Adapt the staging: parse and
  validate `polyorch.toml`, resolve the Pixi environment, compute the adapter action plan, then
  execute. Keeping these as distinct phases makes failures attributable and cacheable.
- **REAPI for optional distribution, never required.** Buck2 uses Bazel's REAPI so existing
  remote executors work unchanged (source: https://buck2.build/docs/users/remote_execution/,
  2026-09-18). Adapt this if and when PolyOrch adds distributed execution: reuse REAPI rather
  than inventing a protocol, but keep local execution fully functional and the default.
- **Date-based releases without semver overpromising.** Buck2 ships date tags and an explicit
  "unstable" label (source: https://github.com/facebook/buck2/releases, 2026-09-18) (source:
  https://raw.githubusercontent.com/facebook/buck2/main/README.md, 2026-09-18). Adapt the
  cadence and the honesty, but not the instability: PolyOrch should commit to a stable CLI and
  config contract even while shipping frequently.
- **A transparency table for adapter support.** Buck2 publishes a per-language support matrix
  with usability and maintainer columns (source:
  https://buck2.build/docs/about/language_support/, 2026-09-18). Adapt this into a PolyOrch
  adapter matrix that states, per adapter (CMake, Xmake, Meson, Colcon), what is supported, what
  is experimental, and who maintains it, rather than implying uniform maturity.
- **BXL-style scripting only after a real consumer exists.** Buck2 invested in a Starlark
  introspection language (source: https://buck2.build/docs/bxl/, 2026-09-18). Adapt the need,
  not the mechanism: start with a documented JSON query interface, and only add a scripting
  layer if a concrete tool cannot be served by that interface.

### [Avoid] Known pitfalls / not applicable

- **Do not conflate Buck2 with Buck1.** Buck1 is the archived Java `facebook/buck` repository;
  Buck2 is Rust and actively released (source: https://github.com/facebook/buck, 2026-09-18)
  (source: https://github.com/facebook/buck2, 2026-09-18). PolyOrch documentation, comparison
  tables, and benchmark notes must label the generation explicitly, or readers will attribute
  Buck1's dead status or Java stack to Buck2, or vice versa.
- **Do not adopt Starlark as PolyOrch's config or extension language.** Buck2 maintains a custom
  Starlark evaluator as an in-tree dependency (source:
  https://github.com/facebook/buck2/tree/main/starlark-rust, 2026-09-18). That is a large,
  permanent maintenance burden. PolyOrch already has `polyorch.toml` for declarative config and
  Xmake's Lua for scripted builds; adding a third language duplicates both and forces PolyOrch to
  own a language runtime it does not need.
- **Do not copy implicit rule loading.** The prelude is implicitly loaded, and Buck2's own docs
  call that a misfeature (source: https://buck2.build/docs/concepts/glossary/, 2026-09-18)
  (source: https://buck2.build/docs/rule_authors/writing_rules/, 2026-09-18). PolyOrch should
  require explicit adapter selection and explicit preset imports in `polyorch.toml`. Implicit
  defaults hide which adapter is actually running.
- **Do not re-model the inner build graphs of CMake, Xmake, Meson, or Colcon.** Buck2 builds its
  own target graph because it owns the whole build (source:
  https://buck2.build/docs/concepts/architecture/, 2026-09-18). PolyOrch's adapters delegate to
  tools that already have rich internal graphs. PolyOrch should model only the cross-adapter
  composition, dependency ordering, and artifact handoff, and let each engine own its internals.
  Reimplementing Xmake's or CMake's graph would be duplicated, drifting work.
- **Do not claim hermetic local builds.** Buck2's own README footnote states that local-only
  build steps are not sandboxed and that only remote execution is always hermetic by design
  (source: https://raw.githubusercontent.com/facebook/buck2/main/README.md, 2026-09-18). PolyOrch
  with Pixi-provided toolchains and network-fetched vcpkg or Conan packages is in the same
  position. Claim strict reproducibility only where PolyOrch can enforce it (for example a fully
  locked Pixi environment plus a pinned package registry), and label the rest as best-effort.
- **Do not require remote execution or a specific provider.** Buck2 works locally without it, and
  the open-source binding is described as less polished than Meta's internal one (source:
  https://buck2.build/docs/about/why/, 2026-09-18). PolyOrch must keep a fully local path as the
  default and treat remote execution as an optional accelerator, or every user without a build
  farm is blocked.
- **Do not institutionalize "Developer Edition" positioning.** Buck2's README advertises an
  unstable developer preview (source: https://raw.githubusercontent.com/facebook/buck2/main/README.md,
  2026-09-18). That is acceptable as a transient state, not as a product identity. PolyOrch's
  target users need a stable configuration contract and predictable CLI behavior.
- **Do not import Meta-scale machinery by default.** Filesystem virtualization and Watchman-class
  watching are justified for Meta's monorepo (source:
  https://raw.githubusercontent.com/facebook/buck2/main/README.md, 2026-09-18) (source:
  https://buck2.build/docs/about/why/, 2026-09-18), but they are heavy for a typical PolyOrch
  user. Make large-repo acceleration opt-in, and keep the default path simple enough that a
  mid-sized polyglot monorepo gets correct behavior without configuring virtualization.

## Appendix: Fact Check Notes

- **Version.** Latest observed release tag is `2026-09-15`, matching the verified anchor, and
  release tags are date strings, for example `2026-09-01` and `2026-08-22` (source:
  https://github.com/facebook/buck2/releases, 2026-09-18).
- **License.** Dual MIT OR Apache-2.0. The README badge and repository text both say so, and the
  in-tree DICE README repeats the dual license for the incremental engine (source:
  https://raw.githubusercontent.com/facebook/buck2/main/README.md, 2026-09-18) (source:
  https://github.com/facebook/buck2/tree/main/dice, 2026-09-18).
- **Config.** Starlark `BUCK` files plus `.buckconfig` in INI format, confirmed against the
  concept and glossary pages (source: https://buck2.build/docs/concepts/buckconfig/, 2026-09-18)
  (source: https://buck2.build/docs/concepts/glossary/, 2026-09-18).
- **DICE is in-tree.** The `dice/` directory and its README were confirmed directly, not
  inferred from a blog post (source: https://github.com/facebook/buck2/tree/main/dice,
  2026-09-18).
- **Starlark evaluator is in-tree.** The `starlark-rust/` directory and its README were
  confirmed directly; Buck2 depends on that library (source:
  https://github.com/facebook/buck2/tree/main/starlark-rust, 2026-09-18).
- **Hermetic caveat.** The homepage's unqualified "hermetic by default" claim is qualified by the
  README footnote limiting full hermeticity to remote execution; both are cited so the profile
  does not overstate (source: https://buck2.build/, 2026-09-18) (source:
  https://raw.githubusercontent.com/facebook/buck2/main/README.md, 2026-09-18).
- **Unverified items are omitted.** No benchmark against Bazel is stated as fact, because Buck2's
  own README says such comparisons have not been performed. No contributor count, no roadmap
  dates, and no future feature commitments are asserted.
