# Xmake Profile

> Sources: https://github.com/xmake-io/xmake (repository, README, CHANGELOG, LICENSE), https://github.com/xmake-io/xmake-docs (official documentation), https://github.com/xmake-io/xmake/releases, https://github.com/xmake-io/xmake-repo. Researched 2026-09-18.
> Not a derived document: facts here are externally sourced.

## 1. Product Profile

| Field | Value |
|---|---|
| Name | Xmake |
| Repository | `github.com/xmake-io/xmake` |
| License | Apache-2.0 (source: https://github.com/xmake-io/xmake/blob/dev/LICENSE.md, 2026-09-18) |
| Latest release | v3.1.1, published 2026-08-27 (source: https://github.com/xmake-io/xmake/releases, 2026-09-18) |
| Implementation | C and C++ native core plus Lua for the build DSL and runtime layer (source: https://github.com/xmake-io/xmake, 2026-09-18) |
| Build configuration | `xmake.lua` (source: https://github.com/xmake-io/xmake/blob/dev/README.md, 2026-09-18) |
| Official package repository | `github.com/xmake-io/xmake-repo`, Apache-2.0 (source: https://github.com/xmake-io/xmake-repo, 2026-09-18) |
| Project age | Repository created 2015-04-23 (source: https://api.github.com/repos/xmake-io/xmake, 2026-09-18) |

Xmake describes itself as "a cross-platform build utility based on the Lua scripting language" that is
"very lightweight and has no dependencies outside of the standard library" (source:
https://github.com/xmake-io/xmake/blob/dev/README.md, 2026-09-18).

The README states the product identity explicitly:

```
Xmake = Build backend + Project Generator + Package Manager + [Remote|Distributed] Build + Cache
Xmake ≈ Make/Ninja + CMake/Meson + Vcpkg/Conan + distcc + ccache/sccache
```

(source: https://github.com/xmake-io/xmake/blob/dev/README.md, 2026-09-18)

Two facts matter for PolyOrch. First, Xmake is a **self-contained build utility with its own native build
engine**: it "can be used to directly build source code (like with Make or Ninja)" and invokes compilers
itself (source: https://github.com/xmake-io/xmake/blob/dev/README.md, 2026-09-18). It is **not a meta build
tool** and **not a wrapper**: it does not delegate compilation to an external build system. Second, it also
embeds a package manager (Xrepo) and a project generator, which makes it a bundle rather than a single-purpose
compiler driver.

## 2. Technical Characteristics

### Overall Architecture

Xmake is a two-layer system: a compiled native core that hosts a Lua interpreter and an embedded Lua
distribution that implements the build system logic.

- **Native core (C and C++).** The `core/` tree is built by Xmake itself. `core/xmake.lua` declares
  `set_xmakever("3.0.5")`, sets the project version to `3.1.1`, and pins the core language level to
  `set_languages("c99", "cxx11")` (source: https://github.com/xmake-io/xmake/blob/dev/core/xmake.lua,
  2026-09-18). Sub-components included by that file are `src/sv`, `src/lz4`, `src/xmake`, `src/cli`,
  `src/tbox`, optionally `src/lua-cjson`, the Lua runtime, and `src/pdcurses` on Windows (source:
  https://github.com/xmake-io/xmake/blob/dev/core/xmake.lua, 2026-09-18).
- **Bundled runtime.** The core embeds a Lua runtime. `core/xmake.lua` defines a `runtime` option whose
  default value is `lua` and whose alternative is `luajit`; the corresponding directories are
  `core/src/lua` and `core/src/luajit` (source: https://github.com/xmake-io/xmake/blob/dev/core/xmake.lua,
  2026-09-18). A `luac_json` option enables `lua-cjson` as the JSON parser by default (same source).
- **Bundled C foundation.** `core/src/tbox` is the C foundation library; `core/src/sv` provides semantic
  versioning and `core/src/lz4` is used for compressed transfer in distributed builds (source:
  https://github.com/xmake-io/xmake/blob/dev/core/xmake.lua, 2026-09-18; distributed transfer claim:
  https://github.com/xmake-io/xmake/blob/dev/README.md, 2026-09-18).
- **Script layer (`xmake/`).** The build system behaviour is implemented as Lua modules organized by
  domain: `actions`, `core`, `includes`, `languages`, `modules`, `platforms`, `plugins`, `repository`,
  `rules`, `scripts`, `templates`, `themes`, `toolchains` (source:
  https://github.com/xmake-io/xmake/tree/dev/xmake, 2026-09-18).
- **Bootstrap.** The native core builds itself with Xmake (`core/xmake.lua` is an Xmake project), so the
  toolchain is self-hosted (source: https://github.com/xmake-io/xmake/blob/dev/core/xmake.lua, 2026-09-18).

The practical pipeline is: describe targets in `xmake.lua`, run `xmake f` to configure
platform/architecture/mode/toolchain, then run `xmake` to build. The engine resolves the target graph,
scans headers for incremental rebuilds, drives each compiler invocation, and links (source:
https://github.com/xmake-io/xmake/blob/dev/README.md, 2026-09-18).

### Key Capabilities

- **Direct compilation, not delegation.** Xmake invokes the compiler and linker itself, like Make or Ninja
  (source: https://github.com/xmake-io/xmake/blob/dev/README.md, 2026-09-18). This is the property that
  distinguishes it from CMake and Meson, which generate files for another build tool.
- **Multi-language compilation including mixed-language projects.** The README lists C, C++,
  Objective-C, Objective-C++, Swift, Assembly, Go, Rust, D, Fortran, CUDA, Zig, Vala, Pascal, Nim,
  Verilog, FASM, NASM, YASM, MASM32, Cppfront, Kotlin, C#, and Ascend C as supported languages (source:
  https://github.com/xmake-io/xmake/blob/dev/README.md, 2026-09-18).
- **Broad platform and cross-compilation matrix.** Windows, macOS, Linux, FreeBSD, NetBSD, OpenBSD,
  DragonflyBSD, Solaris, Android, iOS, WatchOS, AppleTVOS, AppleXROS, MSYS, MinGW, Cygwin, Wasm, Haiku,
  Harmony, and generic cross toolchains are listed (source:
  https://github.com/xmake-io/xmake/blob/dev/README.md, 2026-09-18).
- **Toolchain management.** `xmake show -l toolchains` enumerates built-in toolchains including MSVC,
  Clang, GCC, MinGW, Android NDK, Rust, Swift, Go, D, CUDA, Zig, Fortran, and others (source:
  https://github.com/xmake-io/xmake/blob/dev/README.md, 2026-09-18).
- **Integrated package management through Xrepo.** Dependencies are declared in `xmake.lua` with
  `add_requires` and consumed with `add_packages` (source:
  https://github.com/xmake-io/xmake/blob/dev/README.md, 2026-09-18).
- **Project generation.** `xmake project -k` emits Makefile, Visual Studio, CMake, Ninja, Xcode, and
  `compile_commands.json` outputs (source: https://github.com/xmake-io/xmake/blob/dev/README.md,
  2026-09-18).
- **Acceleration features.** Incremental compilation with automatic header analysis, a built-in local
  build cache, a remote build cache, distributed compilation, and remote compilation (source:
  https://github.com/xmake-io/xmake/blob/dev/README.md, 2026-09-18).

### Tech Stack

| Layer | Technology | Source |
|---|---|---|
| Native core | C99 and C++11 | https://github.com/xmake-io/xmake/blob/dev/core/xmake.lua, 2026-09-18 |
| Build DSL and logic | Lua (default runtime); LuaJIT optional | https://github.com/xmake-io/xmake/blob/dev/core/xmake.lua, 2026-09-18 |
| C foundation | `tbox` (bundled) | https://github.com/xmake-io/xmake/blob/dev/core/xmake.lua, 2026-09-18 |
| Semver | `sv` (bundled) | https://github.com/xmake-io/xmake/blob/dev/core/xmake.lua, 2026-09-18 |
| JSON | `lua-cjson` (bundled, on by default) | https://github.com/xmake-io/xmake/blob/dev/core/xmake.lua, 2026-09-18 |
| Compression | `lz4` (bundled) | https://github.com/xmake-io/xmake/blob/dev/core/xmake.lua, 2026-09-18 |
| Curses UI | `pdcurses` on Windows | https://github.com/xmake-io/xmake/blob/dev/core/xmake.lua, 2026-09-18 |
| Self-build | Xmake (`set_xmakever("3.0.5")`) | https://github.com/xmake-io/xmake/blob/dev/core/xmake.lua, 2026-09-18 |
| Runtime dependencies | None outside the standard library | https://github.com/xmake-io/xmake/blob/dev/README.md, 2026-09-18 |

## 3. Feature Overview

### Core Modules

The Lua script tree is the functional map of the tool (source:
https://github.com/xmake-io/xmake/tree/dev/xmake, 2026-09-18):

| Directory | Responsibility |
|---|---|
| `actions/` | CLI commands (`build`, `config`, `run`, `package`, `install`, and so on) |
| `core/` | Project model, target graph, package model, toolchain abstraction, platform model |
| `includes/` | Shared configuration fragments, including built-in rules and package recipes |
| `languages/` | Per-language compiler integration (C/C++, Rust, Go, Swift, Zig, D, CUDA, and more) |
| `modules/` | Importable utilities (detection, build cache, distribution, IDE helpers) |
| `platforms/` | Per-platform logic (Windows, Linux, macOS, Android, iOS, Wasm, cross) |
| `plugins/` | Built-in plugins and the legacy plugin mechanism |
| `repository/` | Package repository handling for Xrepo |
| `rules/` | Built-in build rules (`mode.debug`, `mode.release`, C++ modules, Qt, WDK, and more) |
| `toolchains/` | Built-in toolchain definitions |
| `templates/` | Project templates used by `xmake create -t` |
| `scripts/` | Helper scripts (remote build, Xrepo hooks, IDE integration) |

### Notable Features

- **Targets and dependencies.** A build unit is a `target()` with a `set_kind` (binary, static, shared,
  and other kinds), source globs via `add_files`, and inter-target edges via `add_deps`. A minimal build
  file is four lines (source: https://github.com/xmake-io/xmake/blob/dev/README.md, 2026-09-18).
- **Namespace isolation.** `namespace("ns1", function() includes("foo") end)` lets two sub-projects keep
  identically named targets and options; the inner targets are reachable as `ns1::foo` (source:
  https://github.com/xmake-io/xmake-docs/blob/master/docs/guide/project-configuration/namespace-isolation.md,
  2026-09-18).
- **Tree-structured includes.** A sub-directory `xmake.lua` inherits the parent root-domain
  configuration, which gives monorepos a natural per-directory scoping model (source:
  https://github.com/xmake-io/xmake-docs/blob/master/docs/guide/project-configuration/multi-level-directories.md,
  2026-09-18).
- **Build cache.** Local caching is on by default and is toggled with `xmake f --ccache=n`; since 2.6.6
  the local cache is a built-in cross-platform implementation, and the flag controls the C/C++ build cache
  rather than the external `ccache` tool (source:
  https://github.com/xmake-io/xmake-docs/blob/master/docs/guide/extras/build-cache.md, 2026-09-18).
- **Remote cache and distributed build.** `xmake service --ccache` starts a remote cache service and
  `xmake service --distcc` starts a distributed compilation service; both use `~/.xmake/service/server.conf`
  and `~/.xmake/service/client.conf`, with token authentication (source:
  https://github.com/xmake-io/xmake-docs/blob/master/docs/guide/extras/build-cache.md and
  https://github.com/xmake-io/xmake-docs/blob/master/docs/guide/extras/distributed-compilation.md,
  2026-09-18).
- **Remote compilation.** Since 2.6.5, `xmake service` can compile on a remote host across platforms, for
  example compiling Windows programs on Linux (source:
  https://github.com/xmake-io/xmake-docs/blob/master/docs/guide/extras/remote-compilation.md, 2026-09-18).
- **Machine-readable output.** `xmake show --format=json` was added in v3.1.0 (source:
  https://github.com/xmake-io/xmake/blob/dev/CHANGELOG.md, 2026-09-18). `xrepo info --depgraph` emits an
  ASCII tree by default and supports `--format=json` and `--format=dot` since v3.0.9; the JSON shape has
  `root_packages` and a `packages` array with `name`, `version`, and `deps` (source:
  https://github.com/xmake-io/xmake-docs/blob/master/docs/guide/package-management/xrepo-cli.md,
  2026-09-18).
- **REPL.** `xmake l` runs Lua snippets and drops into an interactive REPL (source:
  https://github.com/xmake-io/xmake/blob/dev/README.md, 2026-09-18).
- **Test command.** `xmake test` runs the tests declared for targets (source:
  https://github.com/xmake-io/xmake/blob/dev/README.md, 2026-09-18).

### Extensibility / Plugin Mechanism

Xmake has three extension surfaces, and they are not equivalent.

**1. Packages (libraries for your program).** Declared with `add_requires` in `xmake.lua` or installed
with `xrepo install`. They live in `~/.xmake/packages` and extend the program being built (source:
https://github.com/xmake-io/xmake-docs/blob/master/docs/guide/extensions/addons/introduction.md,
2026-09-18).

**2. Legacy plugins (commands only).** A plugin is a `task()` with `on_run` and a menu, discovered from
built-in paths, `~/.xmake/plugins`, or a project-local `plugins` directory registered with
`add_plugindirs("plugins")` (source:
https://github.com/xmake-io/xmake-docs/blob/master/docs/guide/extensions/plugin-development.md,
2026-09-18). Since v3.1.0, `xmake plugin --install` installs plugins by name from a repository, from a git
URL, or from a local directory; plugins are packages of kind `plugin` and land in `~/.xmake/plugins/<name>`
(sources: https://github.com/xmake-io/xmake/blob/dev/CHANGELOG.md and
https://github.com/xmake-io/xmake-docs/blob/master/docs/guide/extensions/plugin-development.md,
2026-09-18).

**3. Addons (a superset of plugins).** Added in the v3.1.1 changelog, an addon extends Xmake itself and
can carry up to six payload kinds (source:
https://github.com/xmake-io/xmake/blob/dev/CHANGELOG.md, 2026-09-18):

| Payload | What it becomes | Reference form |
|---|---|---|
| `plugins/` | a new command | `xmake monitor` |
| `rules/` | a build rule | `add_rules("@addon/esp32-devel/app")` |
| `toolchains/` | a toolchain | `set_toolchains("@addon/esp32-devel/esp32")` |
| `templates/` | a project template | `xmake create -t esp32.blink` |
| `modules/` | importable Lua modules | `import("@addon.serial-tools.serial")` |
| `includes/` | includable configuration | `includes("@addon/esp32-devel/board")` |

(source: https://github.com/xmake-io/xmake-docs/blob/master/docs/guide/extensions/addons/introduction.md,
2026-09-18)

Key addon properties (same source): an addon is installed once per user in `~/.xmake/addons/<name>/<version>`
and registered in `~/.xmake/addons/addons.conf`; payloads are referenced through the `@addon/<name>/...`
namespace so two addons do not collide, with plugins and templates as the exception because command and
template ids are global; and an addon names itself in an `addon.lua` manifest, independent of the
repository that distributes it.

Installation and versioning are declarative. A project writes `add_addons("esp32-devel")` or
`add_addons("esp32-devel 1.0.x")`; Xmake auto-installs missing addons when the project is loaded and
records the resolved versions in `xmake-addons.lock` beside `xmake.lua`, which is meant to be committed
(source: https://github.com/xmake-io/xmake-docs/blob/master/docs/guide/extensions/addons/installation.md,
2026-09-18). Addons are distributed as packages of kind `addon` and live in `xmake-repo` under
`addons/<first-letter>/<name>/xmake.lua` (source:
https://github.com/xmake-io/xmake-docs/blob/master/docs/guide/extensions/addons/development.md,
2026-09-18). The addon documentation carries a note that addons "require xmake from the dev branch for
now" (source:
https://github.com/xmake-io/xmake-docs/blob/master/docs/guide/extensions/addons/introduction.md,
2026-09-18), so treat addon support as new and pin the tool version accordingly.

Beyond these, the build DSL itself is the extension surface: custom rules (`add_rules`, `on_build`),
custom toolchains (`set_toolchains`), custom `task()` commands, and `includes()` fragments are all written
in Lua inside the project.

## 4. Status & Ecosystem

- **Release cadence.** Releases are frequent and versioned `v3.x.y`: v3.1.1 on 2026-08-27, v3.1.0 on
  2026-08-08, v3.0.9 on 2026-05-19, v3.0.8 on 2026-03-23, v3.0.7 on 2026-02-10, v3.0.6 on 2026-01-04
  (source: https://github.com/xmake-io/xmake/releases, 2026-09-18).
- **Repository activity.** The `dev` branch is active, with merged pull requests dated 2026-09-18, the
  research date (source: https://github.com/xmake-io/xmake/commits/dev, 2026-09-18).
- **Adoption signal.** The repository had 12,221 stars and 935 on `xmake-repo` at research time (source:
  https://api.github.com/repos/xmake-io/xmake and https://api.github.com/repos/xmake-io/xmake-repo,
  2026-09-18). Star counts are a weak signal and are recorded here only as a status marker.
- **Package ecosystem.** The official `xmake-repo` provides C/C++ packages; the README describes the
  repository as providing "nearly 500+" packages with cross-platform support (source:
  https://github.com/xmake-io/xmake/blob/dev/README.md, 2026-09-18). Self-built and private repositories
  are supported via `xrepo add-repo` (source:
  https://github.com/xmake-io/xmake-docs/blob/master/docs/guide/package-management/xrepo-cli.md,
  2026-09-18).
- **Third-party package managers.** Confirmed real namespaces include `vcpkg::`, `conan::`, `conda::`,
  `nix::`, `brew::`, `pacman::`, `apt::`, `portage::`, `clib::`, `dub::`, `nimble::`, `cargo::`, and
  `nuget::` (source:
  https://github.com/xmake-io/xmake-docs/blob/master/docs/guide/package-management/using-third-party-packages.md,
  2026-09-18). Vcpkg manifest mode (with version selection such as `vcpkg::zlib 1.2.11`) is supported
  since v2.6.3, and `nix::` semantic versioning since v3.0.7 (same source).
- **Tooling integrations.** Official IDE plugins exist for VS Code, Sublime, IntelliJ, and Zed, an
  official GitHub Action (`xmake-io/github-action-setup-xmake`), and an Xmake Gradle plugin for JNI builds
  (source: https://github.com/xmake-io/xmake/blob/dev/README.md, 2026-09-18).
- **Community.** Reddit, Telegram, Discord, and QQ channels are listed; contact and homepage are
  `xmake.io` (source: https://github.com/xmake-io/xmake/blob/dev/README.md, 2026-09-18).
- **Governance.** The project is maintained by the Xmake Open Source Community; the LICENSE carries
  "Copyright 2015-present Xmake Open Source Community" (source:
  https://github.com/xmake-io/xmake/blob/dev/LICENSE.md, 2026-09-18).

## 5. Market Positioning

Xmake positions itself against four categories at once, by bundling what normally arrives as separate
tools (source: https://github.com/xmake-io/xmake/blob/dev/README.md, 2026-09-18):

| Category | Representative tools | Xmake's claim |
|---|---|---|
| Build backends | Make, Ninja | Direct compilation, comparable speed |
| Build system generators | CMake, Meson | Same role via `xmake project -k` |
| Package managers | vcpkg, Conan | Xrepo plus third-party namespaces |
| Acceleration | distcc, ccache/sccache | Built-in distributed build and cache |

The differentiators that are documented rather than asserted:

1. **Lua as the configuration language.** `xmake.lua` is executable Lua, which makes the DSL fully
   programmable (source: https://github.com/xmake-io/xmake/blob/dev/README.md, 2026-09-18).
2. **Bundled package manager.** Dependency declaration and installation are part of the same file and
   command surface, and third-party managers are consumed behind a uniform namespace (source:
   https://github.com/xmake-io/xmake-docs/blob/master/docs/guide/package-management/using-third-party-packages.md,
   2026-09-18).
3. **Multi-language and mixed-language builds in one engine.** The supported-language list is unusually
   broad for a C/C++-oriented tool (source:
   https://github.com/xmake-io/xmake/blob/dev/README.md, 2026-09-18).
4. **Zero external runtime dependencies.** A single self-contained executable, installed via a shell or
   PowerShell script or from a package manager (source:
   https://github.com/xmake-io/xmake/blob/dev/README.md, 2026-09-18).

The README also publishes build-speed comparisons against Ninja and CMake on two machines. Those numbers
are the project's own and are not independently verified here; they are deliberately not reproduced as
PolyOrch facts.

## 6. Product Highlights

- One tool covers build backend, generator, package manager, distributed build, and cache (source:
  https://github.com/xmake-io/xmake/blob/dev/README.md, 2026-09-18).
- Executable Lua configuration allows conditional, computed, and reusable build logic without a separate
  macro language.
- Built-in package manager with a uniform namespace over native, `vcpkg::`, `conan::`, `nix::`,
  `conda::`, `brew::`, and other ecosystems (source:
  https://github.com/xmake-io/xmake-docs/blob/master/docs/guide/package-management/using-third-party-packages.md,
  2026-09-18).
- Dependency version locking is a documented package-management feature, and addons get a committed lock
  file (sources: https://github.com/xmake-io/xmake/blob/dev/README.md and
  https://github.com/xmake-io/xmake-docs/blob/master/docs/guide/extensions/addons/installation.md,
  2026-09-18).
- Cross-compilation with automatic toolchain detection, plus remote toolchain fetching through
  `add_requires("llvm 10.x")` and `set_toolchains("llvm@llvm-10")` (source:
  https://github.com/xmake-io/xmake/blob/dev/README.md, 2026-09-18).
- Addons can ship an entire cross-development kit (toolchain, rules, flashing logic, template) as one
  installable unit (source:
  https://github.com/xmake-io/xmake-docs/blob/master/docs/guide/extensions/addons/introduction.md,
  2026-09-18).

## 7. Value to PolyOrch

PolyOrch's whitepaper-level integration stack names Xmake as the native build engine, while the adapter
layer dispatches CMake, Xmake, Meson, and Colcon. The profile below does not settle the open question of
whether Xmake is an adapter, the core engine, or both (that question is recorded in
`docs/architecture.md`); it lists what Xmake's own capabilities and integration surface offer either way.

### [Adopt] Directly reusable

- **Adopt Xmake as the native build engine for PolyOrch's own C/C++ targets and self-builds.** Xmake
  invokes compilers itself and has no runtime dependencies beyond the standard library, so a PolyOrch
  repository can build with one bootstrap path and no generator step (source:
  https://github.com/xmake-io/xmake/blob/dev/README.md, 2026-09-18).
- **Adopt `add_requires` plus Xrepo as the default dependency resolution path.** PolyOrch's environment
  layer can express a dependency once and let Xmake route it to the native repo, `vcpkg::`, `conan::`,
  `nix::`, or another backend (source:
  https://github.com/xmake-io/xmake-docs/blob/master/docs/guide/package-management/using-third-party-packages.md,
  2026-09-18). This directly matches the whitepaper's "unified dependency" goal.
- **Adopt the third-party namespaces as the integration contract for vcpkg and Conan.** The syntax is
  stable and documented: `add_requires("vcpkg::zlib", "vcpkg::pcre2")`, manifest-mode versioning such as
  `add_requires("vcpkg::zlib 1.2.11")`, and `add_requires("conan::openssl/1.1.1g", {alias = "openssl"})`
  (source:
  https://github.com/xmake-io/xmake-docs/blob/master/docs/guide/package-management/using-third-party-packages.md,
  2026-09-18).
- **Adopt dependency and addon lock files as reproducibility artifacts.** The addon system records
  resolved versions in `xmake-addons.lock`, which the docs instruct users to commit; the package manager
  documents dependency version locking (sources:
  https://github.com/xmake-io/xmake-docs/blob/master/docs/guide/extensions/addons/installation.md and
  https://github.com/xmake-io/xmake/blob/dev/README.md, 2026-09-18). PolyOrch should treat these lock
  files as first-class inputs to its own lock and cache keys.
- **Adopt the addon model to ship PolyOrch's Xmake-side integration.** One `polyorch` addon can register a
  command (`plugins/`), PolyOrch-specific build rules (`rules/`), toolchains (`toolchains/`), project
  templates (`templates/`), and Lua modules (`modules/`), all referenced through the collision-safe
  `@addon/<name>/...` namespace (source:
  https://github.com/xmake-io/xmake-docs/blob/master/docs/guide/extensions/addons/introduction.md,
  2026-09-18).
- **Adopt `add_addons("...")` for zero-touch project bootstrap.** A PolyOrch-generated `xmake.lua` can
  declare the PolyOrch addon and let Xmake auto-install it on project load, which removes a manual setup
  step from fresh clones and CI (source:
  https://github.com/xmake-io/xmake-docs/blob/master/docs/guide/extensions/addons/installation.md,
  2026-09-18).
- **Adopt machine-readable CLI output instead of log scraping.** Use `xmake show --format=json` (v3.1.0)
  and `xrepo info --depgraph --format=json` or `--format=dot` (v3.0.9) as the adapter's data feed; the
  JSON dependency graph has a documented `root_packages` plus `packages[{name,version,deps}]` shape
  (sources: https://github.com/xmake-io/xmake/blob/dev/CHANGELOG.md and
  https://github.com/xmake-io/xmake-docs/blob/master/docs/guide/package-management/xrepo-cli.md,
  2026-09-18).
- **Adopt `xmake project -k compile_commands` for editor and debugger integration.** This gives clangd and
  IDE debugging a standard artifact rather than a bespoke bridge (source:
  https://github.com/xmake-io/xmake/blob/dev/README.md, 2026-09-18).
- **Adopt namespace isolation and tree includes as the monorepo scoping model.** `namespace("ns", function()
  includes("pkg") end)` prevents target, option, and rule name collisions between packages, and a
  sub-directory `xmake.lua` inherits its parent root domain (sources:
  https://github.com/xmake-io/xmake-docs/blob/master/docs/guide/project-configuration/namespace-isolation.md
  and
  https://github.com/xmake-io/xmake-docs/blob/master/docs/guide/project-configuration/multi-level-directories.md,
  2026-09-18).
- **Adopt the built-in local cache by default and expose the toggle.** Local caching is on by default and
  controlled by `xmake f --ccache=n`; it is cross-platform and covers MSVC, unlike external `ccache`
  (source: https://github.com/xmake-io/xmake-docs/blob/master/docs/guide/extras/build-cache.md,
  2026-09-18).
- **Adopt remote toolchain fetching for environment reproducibility.** `add_requires("llvm 10.x", {alias =
  "llvm-10"})` plus `set_toolchains("llvm@llvm-10")`, and `add_requires("muslcc")` plus
  `set_toolchains("@muslcc")`, let a project pin compilers rather than depend on the host install
  (source: https://github.com/xmake-io/xmake/blob/dev/README.md, 2026-09-18).
- **Adopt the broad language matrix where PolyOrch needs mixed-language leaf builds.** Xmake lists native
  support for Rust, Go, Swift, D, Fortran, CUDA, Zig, Nim, Kotlin, and C#, so a single `xmake.lua` can
  cover a polyglot leaf package that would otherwise need several build systems (source:
  https://github.com/xmake-io/xmake/blob/dev/README.md, 2026-09-18).

### [Adapt] Reusable with modification

- **Adapt the `xmake.lua` model: generate it, do not own it.** `xmake.lua` is executable Lua, while
  PolyOrch's source of truth is `polyorch.toml`. PolyOrch should emit or template `xmake.lua` from its own
  model, and should treat any Xmake file as generated output rather than a second configuration authority.
- **Adapt the adapter/engine boundary explicitly.** Define two contracts: an Xmake adapter that invokes
  `xmake` as a subprocess and consumes JSON output, and an Xmake engine path that owns `xmake.lua`
  generation for PolyOrch-native builds. Which of these PolyOrch ships is the open question in
  `docs/architecture.md`; keep the interfaces separate until it is decided.
- **Adapt addon installation for hermetic CI.** Addons install per user in `~/.xmake/addons` and are
  registered in a user-level `addons.conf`, which is global mutable state (source:
  https://github.com/xmake-io/xmake-docs/blob/master/docs/guide/extensions/addons/introduction.md,
  2026-09-18). PolyOrch should pin versions through the committed `xmake-addons.lock` and isolate the Xmake
  home per job or workspace, rather than relying on a shared runner's user home.
- **Adapt the cache integration to PolyOrch's task keys.** The Xmake cache is keyed by Xmake configuration
  (platform, architecture, mode, toolchain). PolyOrch's own task and environment hashes must be folded
  into the Xmake configuration so a task whose declared inputs changed cannot hit a stale cache entry.
- **Adapt remote cache and distributed build as opt-in enterprise features.** Both require running
  `xmake service` and distributing a `client.conf` containing connection tokens over plain TCP (source:
  https://github.com/xmake-io/xmake-docs/blob/master/docs/guide/extras/distributed-compilation.md,
  2026-09-18). Treat them as advanced, explicitly enabled capabilities with a documented trust boundary,
  never as defaults.
- **Adapt plugin naming under the global-namespace constraint.** Command names and template ids are global,
  and Xmake rejects an install that would shadow another addon's command (source:
  https://github.com/xmake-io/xmake-docs/blob/master/docs/guide/extensions/addons/introduction.md,
  2026-09-18). Prefix PolyOrch commands and templates and verify conflicts at install time.
- **Adapt third-party-manager use to the environment layer.** `vcpkg::` manifest mode, `conan::` remotes,
  `nix::`, and the rest require those managers to be present and configured. PolyOrch's environment
  manager (Pixi) should provision them, and PolyOrch should fail fast with a clear diagnostic when a
  declared backend is missing.
- **Adapt the language matrix to declared support.** The README lists many languages, but per-language
  toolchains must be installed and version-pinned by PolyOrch. Treat the list as capability metadata, not
  as a guarantee that every toolchain is present on a given machine.
- **Adapt the addon maturity caveat into version pinning.** The docs note addons require a Xmake from the
  `dev` branch "for now", while the v3.1.1 changelog lists addon support as a new feature (sources:
  https://github.com/xmake-io/xmake-docs/blob/master/docs/guide/extensions/addons/introduction.md and
  https://github.com/xmake-io/xmake/blob/dev/CHANGELOG.md, 2026-09-18). PolyOrch should pin an exact Xmake
  version and test addon behaviour against it before depending on it.

### [Avoid] Known pitfalls / not applicable

- **Do not parse `xmake.lua` as data.** It is executable Lua with user hooks such as `after_build` and
  custom `task` bodies; reading it as a declarative config is unsafe and brittle. Use Xmake's JSON output
  APIs or a controlled generator instead (source:
  https://github.com/xmake-io/xmake/blob/dev/README.md, 2026-09-18).
- **Do not use Xmake as the monorepo-level orchestration graph.** Xmake models targets, packages, and
  rules inside one project; it does not provide a distributed, content-addressed action graph with remote
  execution and hermetic sandboxing. Its "remote build" is file sync plus remote compile, and its
  distributed build is a compile-offload service, not an artifact graph engine (sources:
  https://github.com/xmake-io/xmake-docs/blob/master/docs/guide/extras/remote-compilation.md and
  https://github.com/xmake-io/xmake-docs/blob/master/docs/guide/extras/distributed-compilation.md,
  2026-09-18).
- **Do not describe Xmake as a meta build tool or a wrapper.** It invokes compilers directly, so an
  adapter must not also drive the compiler, or the same sources will be compiled twice through two
  pipelines (source: https://github.com/xmake-io/xmake/blob/dev/README.md, 2026-09-18).
- **Do not lean on a shared `~/.xmake` in parallel or shared CI.** The packages, addons, plugins, service
  config, and environment registries all live under the user home and are mutable; concurrent jobs can
  contend or leak state between projects.
- **Do not make `curl ... | bash` the only bootstrap path.** The README's primary install is a shell
  script piped to bash (or PowerShell `iex`); a governed build should also support a pinned package or
  source install and verify the version (source:
  https://github.com/xmake-io/xmake/blob/dev/README.md, 2026-09-18).
- **Do not grant unvetted plugins and hooks free execution in a governed build.** Xmake plugins, addons,
  and `on_*` script hooks execute arbitrary commands with no signature or allowlist mechanism. PolyOrch
  should restrict which addons and hooks it permits and review them like any other build script.
- **Do not assume the community package repository is a supply-chain boundary.** `xmake-repo` is
  community-maintained and mutable even though individual recipes pin `sha256` values. For governed
  builds, use a private repository plus lock files (source:
  https://github.com/xmake-io/xmake/blob/dev/README.md and
  https://github.com/xmake-io/xmake-docs/blob/master/docs/guide/package-management/xrepo-cli.md,
  2026-09-18).
- **Do not depend on the build DSL being API-stable across Xmake versions.** The project pins its own
  expected Xmake with `set_xmakever`, and features arrive on a fast release cadence, so PolyOrch must pin
  the Xmake version and re-verify on upgrade (source:
  https://github.com/xmake-io/xmake/blob/dev/core/xmake.lua and
  https://github.com/xmake-io/xmake/blob/dev/CHANGELOG.md, 2026-09-18).
- **Do not embed the C/Lua engine in-process.** PolyOrch's implementation language is now **Lua**, shipped
  as an Xmake addon (see `decisions.md` D3); integration still goes through the documented CLI and file
  formats rather than a native linkage into the engine.

## Appendix

### Minimal build file

```lua
target("console")
    set_kind("binary")
    add_files("src/*.c")
```

(source: https://github.com/xmake-io/xmake/blob/dev/README.md, 2026-09-18)

### Dependency declaration with third-party backends

```lua
add_requires("tbox >1.6.1", "libuv master", "vcpkg::ffmpeg", "brew::pcre2/libpcre2-8")
add_requires("conan::openssl/1.1.1g", {alias = "openssl", optional = true, debug = true})
target("test")
    set_kind("binary")
    add_files("src/*.c")
    add_packages("tbox", "libuv", "vcpkg::ffmpeg", "brew::pcre2/libpcre2-8", "openssl")
```

(source: https://github.com/xmake-io/xmake/blob/dev/README.md, 2026-09-18)

### Command surface relevant to integration

| Command | Purpose | Source |
|---|---|---|
| `xmake` | build the current project | README, 2026-09-18 |
| `xmake f -p <plat> -a <arch> -m <mode>` | configure platform, architecture, mode | README, 2026-09-18 |
| `xmake f --menu` | interactive menu configuration | README, 2026-09-18 |
| `xmake show --format=json` | machine-readable project info (v3.1.0) | CHANGELOG, 2026-09-18 |
| `xmake project -k cmake` / `ninja` / `compile_commands` | generate IDE and tooling files | README, 2026-09-18 |
| `xmake require --depgraph` | dependency graph in-project | xrepo CLI docs, 2026-09-18 |
| `xmake test` | run tests | README, 2026-09-18 |
| `xmake service --ccache` / `--distcc` | remote cache / distributed build services | build-cache and distributed docs, 2026-09-18 |
| `xmake addon --install` / `--list` / `--upgrade` | manage addons | addon installation docs, 2026-09-18 |
| `xmake plugin --install` / `--list` | manage plugins (v3.1.0) | plugin development docs, 2026-09-18 |
