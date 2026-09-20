# Meson Profile

> Sources: https://mesonbuild.com/index.html, https://mesonbuild.com/Overview.html,
> https://mesonbuild.com/Manual.html, https://mesonbuild.com/Running-Meson.html,
> https://mesonbuild.com/Commands.html, https://mesonbuild.com/Syntax.html,
> https://mesonbuild.com/Build-options.html, https://mesonbuild.com/Builtin-options.html,
> https://mesonbuild.com/Unit-tests.html, https://mesonbuild.com/Subprojects.html,
> https://mesonbuild.com/Wrap-dependency-system-manual.html,
> https://mesonbuild.com/Wrapdb-projects.html, https://mesonbuild.com/Cross-compilation.html,
> https://mesonbuild.com/Native-environments.html, https://mesonbuild.com/Machine-files.html,
> https://mesonbuild.com/IDE-integration.html, https://mesonbuild.com/howtox.html,
> https://mesonbuild.com/FAQ.html, https://mesonbuild.com/legal.html,
> https://mesonbuild.com/Release-notes.html, https://mesonbuild.com/Release-notes-for-1-12-0.html,
> https://mesonbuild.com/Release-notes-for-1-1-0.html, https://github.com/mesonbuild/meson;
> researched 2026-09-18.
> Not a derived document: facts here are externally sourced.

## 1. Product Profile

Meson is an open source build system. Its own documentation states the goal directly: "Meson is an
open source build system meant to be both extremely fast, and, even more importantly, as user
friendly as possible" (source: https://mesonbuild.com/index.html, 2026-09-18).

- **Repository**: `https://github.com/mesonbuild/meson` (source:
  https://github.com/mesonbuild/meson, 2026-09-18).
- **Official documentation**: `https://mesonbuild.com` (source:
  https://mesonbuild.com/Manual.html, 2026-09-18).
- **Current release**: 1.12.0, published 2026-08-10 (source:
  https://api.github.com/repos/mesonbuild/meson/releases/latest, 2026-09-18). The release notes
  page states "Meson 1.12.0 was released on 10 August 2026" (source:
  https://mesonbuild.com/Release-notes-for-1-12-0.html, 2026-09-18).
- **Next release**: 1.13.0 is listed as "in development" (source:
  https://mesonbuild.com/Release-notes.html, 2026-09-18).
- **License**: Apache License 2.0. The legal page states "Meson is licensed under the Apache 2
  license" (source: https://mesonbuild.com/legal.html, 2026-09-18). The repository license file is
  `COPYING` and GitHub reports the SPDX identifier as `Apache-2.0` (source:
  https://api.github.com/repos/mesonbuild/meson/license, 2026-09-18).
- **Trademark**: "Meson is a registered trademark of Jussi Pakkanen" (source:
  https://mesonbuild.com/legal.html, 2026-09-18).
- **Implementation language**: Python. The FAQ devotes an entry to "Why is Meson implemented in
  Python rather than [programming language X]?" and explains that Python was chosen for bootstrapping
  reasons (minimal dependencies, wide CPU support, contributor accessibility) (source:
  https://mesonbuild.com/FAQ.html, 2026-09-18).
- **Runtime requirements**: Python 3 and Ninja. The quick guide states Ninja "is only needed if you
  use the Ninja backend. Meson can also generate native VS and Xcode project files" (source:
  https://mesonbuild.com/Quick-guide.html, 2026-09-18). If Ninja is unavailable, Meson is also
  distributed on PyPI and is runnable from an extracted source tree or git checkout (source:
  https://mesonbuild.com/FAQ.html, 2026-09-18).

Meson is a build system, not a meta build tool and not a package manager. Dependency acquisition is
handled by a separate mechanism (the wrap system, described below), and dependency discovery is
delegated to platform conventions such as pkg-config and CMake.

## 2. Technical Characteristics

### Overall Architecture

Meson uses a strict two-phase model: a **configure** phase followed by a **build** phase.

1. **Configure.** `meson setup <builddir> <sourcedir>` reads the project's `meson.build` files and
   produces a fully configured, self-contained build directory (source:
   https://mesonbuild.com/Commands.html, 2026-09-18). The documented workflow is "run `setup`,
   followed by `compile`, and then `install`" (source: https://mesonbuild.com/Commands.html,
   2026-09-18).
2. **Build.** The configure phase emits a build description for a backend; the backend then executes
   it. The default backend is Ninja: "Meson prefers ninja by default" (source:
   https://mesonbuild.com/Builtin-options.html, 2026-09-18). The guide adds that after the initial
   configure step "ninja is the only command you ever need to type to compile" (source:
   https://mesonbuild.com/Running-Meson.html, 2026-09-18).

Alternative backends are Visual Studio (`vs`, `vs2010`, ..., `vs2026`) and `xcode` for native IDE
project generation, plus `none` for projects that only need configuration, testing and installation
without build rules (source: https://mesonbuild.com/Commands.html, 2026-09-18; the `none` backend was
introduced in 1.1.0, source: https://mesonbuild.com/Release-notes-for-1-1-0.html, 2026-09-18).
There is deliberately no Make backend; the FAQ argues Make "simply cannot be made fast" and
recommends Ninja (source: https://mesonbuild.com/FAQ.html, 2026-09-18).

Build directories are self-contained and disposable. Since 0.57.0 Meson writes a `.gitignore` (and
`.hgignore`) into each build directory that glob-ignores `*`, because all generated files should stay
out of version control (source: https://mesonbuild.com/FAQ.html, 2026-09-18).

**Regeneration is implicit.** Ninja detects changes to `meson.build` and the source tree and
re-runs Meson automatically: "No matter how you alter your source tree (short of moving it to a
completely new location), Meson will detect the changes and regenerate itself accordingly" (source:
https://mesonbuild.com/Running-Meson.html, 2026-09-18). An orchestrator therefore cannot assume the
configure step runs exactly once per build.

**Exit codes are part of the contract.** "Meson exits with status 0 if successful, 1 for problems
with the command line or meson.build file, and 2 for internal errors" (source:
https://mesonbuild.com/Running-Meson.html, 2026-09-18).

### Key Capabilities

- **Build description language.** A custom, non-Turing-complete DSL, described as "a very readable
  and user friendly non-Turing complete DSL" (source: https://mesonbuild.com/index.html,
  2026-09-18). The overview states the language was designed for "simplicity, clarity and
  conciseness", inspired by Python's readability (source: https://mesonbuild.com/Overview.html,
  2026-09-18).
- **Type model.** The language is "strongly typed so no object is ever converted to another under
  the covers", while variables have no visible type, making it "dynamically typed (also known as
  duck typed)" (source: https://mesonbuild.com/Syntax.html, 2026-09-18). The main building blocks
  are variables, numbers, booleans, strings, arrays, function calls, method calls, `if` statements
  and `include`s (source: https://mesonbuild.com/Syntax.html, 2026-09-18).
- **Multi-language.** Homepage feature list: "supported languages include C, C++, C#, D, Fortran,
  Java, Rust" (source: https://mesonbuild.com/index.html, 2026-09-18). The language argument
  reference additionally lists CUDA, Objective C, Objective C++, Vala, Cython, NASM, MASM and
  Linear ASM (source: https://mesonbuild.com/Reference-tables.html, 2026-09-18).
- **Multiplatform.** "multiplatform support for Linux, macOS, Windows, GCC, Clang, Visual Studio
  and others" (source: https://mesonbuild.com/index.html, 2026-09-18).
- **Cross compilation.** "full support for cross compilation through the use of a cross build
  definition file", plus support for bare metal targets (source:
  https://mesonbuild.com/Cross-compilation.html, 2026-09-18; https://mesonbuild.com/index.html,
  2026-09-18). Native files are the non-cross equivalent for describing the build machine (source:
  https://mesonbuild.com/Native-environments.html, 2026-09-18).
- **Built-in test system.** "Meson comes with a fully functional unit test system" driven by
  `meson test` (source: https://mesonbuild.com/Unit-tests.html, 2026-09-18).
- **First-class modern tooling.** The overview names "unit testing, code coverage reporting,
  precompiled headers and the like" as features that "should be immediately available to any project
  using Meson" (source: https://mesonbuild.com/Overview.html, 2026-09-18).

### Tech Stack

- Implementation: Python, packaged as the `mesonbuild` Python package and shipped on PyPI (source:
  https://mesonbuild.com/FAQ.html, 2026-09-18).
- Repository top level (per the GitHub file listing): `.github`, `ci`, `cross`, `data`, `docs`,
  `graphics`, `man`, `manual tests`, `mesonbuild`, `packaging` (source:
  https://github.com/mesonbuild/meson, 2026-09-18). The engine itself lives under `mesonbuild`.
- Test suite runs under Python with Meson's own unit runner; the FAQ instructs contributor changes
  to files such as `mesonbuild/compilers/c.py` and `mesonbuild/environment.py` (source:
  https://mesonbuild.com/FAQ.html, 2026-09-18).
- Backend tooling: Ninja (default), Visual Studio / MSBuild, Xcode (source:
  https://mesonbuild.com/Running-Meson.html, 2026-09-18).

## 3. Feature Overview

### Core Modules

- **Interpreter and language runtime**: evaluates `meson.build` files, including function calls,
  method calls, `if` statements, arrays and `include`s (source: https://mesonbuild.com/Syntax.html,
  2026-09-18).
- **Compiler abstraction**: per-language compiler classes and detection logic, for example
  `mesonbuild/compilers/c.py` and `detect_c_compiler` in `mesonbuild/environment.py` (source:
  https://mesonbuild.com/FAQ.html, 2026-09-18).
- **Build backends**: the Ninja generator plus Visual Studio and Xcode generators, selected by the
  `backend` option (source: https://mesonbuild.com/Builtin-options.html, 2026-09-18).
- **Dependency resolvers**: `dependency()` resolves through pkg-config and CMake, with config-tool
  support (the pybind example shows pkg-config, cmake and `pybind11-config` coexistence) and
  subproject fallback (source: https://mesonbuild.com/Release-notes-for-1-1-0.html, 2026-09-18;
  https://mesonbuild.com/Wrap-dependency-system-manual.html, 2026-09-18).
- **Wrap / subproject system**: local `subprojects/` trees plus `.wrap` files that can fetch
  archives or git repositories, with checksums and patch overlays (source:
  https://mesonbuild.com/Subprojects.html, 2026-09-18).
- **Introspection**: machine-readable JSON emitted into a `meson-info` directory in the build
  directory, refreshed on reconfigure or option change (source:
  https://mesonbuild.com/IDE-integration.html, 2026-09-18).

### Notable Features

- **`meson` command surface.** Documented commands include `setup`, `compile`, `install`, `test`,
  `introspect`, `subprojects`, `wrap`, `dist`, `devenv` and `rewrite`, with `meson [COMMAND]
  [COMMAND_OPTIONS]` syntax (source: https://mesonbuild.com/Commands.html, 2026-09-18).
- **Build options.** Declared in `meson.options` at the source root, with types `string`, `boolean`,
  `combo`, `integer`, `array` and `feature` (source: https://mesonbuild.com/Build-options.html,
  2026-09-18).
- **Feature options.** A `feature` option has three states, `enabled`, `disabled` and `auto`, and is
  designed to be passed to the `required` keyword of `dependency()`, `find_program()`,
  `subproject()` and others (source: https://mesonbuild.com/Build-options.html, 2026-09-18).
- **Built-in options.** Universal options include `buildtype` (mapping `plain`, `debug`,
  `debugoptimized`, `release`, `minsize` to `debug` and `optimization` combinations), `backend`, and
  the Ninja-specific `backend_max_links` (source: https://mesonbuild.com/Builtin-options.html,
  2026-09-18; https://mesonbuild.com/Build-options.html, 2026-09-18).
- **Test selection.** Tests can be addressed by name, by `(sub)project:test`, by wildcard (since
  1.2.0) and by suite; `--slice i/n` (since 1.8.0) splits a test set across machines (source:
  https://mesonbuild.com/Unit-tests.html, 2026-09-18).
- **Test protocols.** Default `exitcode` protocol, with exit code 77 reported as skipped and exit
  code 99 reported as `ERROR`; 1.11.0 renamed `should_fail` to `expected_fail` and added
  `expected_exitcode` (source: https://mesonbuild.com/Unit-tests.html, 2026-09-18).
- **Installation.** `meson install -C builddir`, default prefix `/usr/local`, `--prefix` at configure
  time, and `DESTDIR` support; `ninja -C builddir install` is equivalent (source:
  https://mesonbuild.com/Running-Meson.html, 2026-09-18).
- **Install tags.** `install_subdir()` and related install functions accept `install_tag`, used by
  `meson install --tags` (source: https://mesonbuild.com/Reference-manual_functions.html,
  2026-09-18).
- **Source releases.** `meson dist` generates a release archive (default format `xztar`) from the
  source tree (source: https://mesonbuild.com/Commands.html, 2026-09-18).
- **Development environment.** `meson devenv` runs a command or interactive shell with the build
  directory's environment applied, and can dump that environment (source:
  https://mesonbuild.com/Commands.html, 2026-09-18).
- **Wrap dependency system.** `.wrap` files describe `source_url`, `source_filename`,
  `source_hash`, `patch_url` / `patch_filename` / `patch_directory`, and a `[provide]` section that
  maps dependency names to the subproject (source:
  https://mesonbuild.com/Wrap-dependency-system-manual.html, 2026-09-18). Since 1.3.0 the
  `MESON_PACKAGE_CACHE_DIR` environment variable can replace the project-local
  `subprojects/packagecache`, allowing a shared cache across projects (source:
  https://mesonbuild.com/Wrap-dependency-system-manual.html, 2026-09-18).
- **WrapDB.** An online repository of ready-to-use wraps at `https://wrapdb.mesonbuild.com`,
  installed with `meson wrap install <project>` (source: https://mesonbuild.com/Wrapdb-projects.html,
  2026-09-18). Release 1.12.0 lifted the single-name restriction so multiple wraps can be installed
  in one invocation (source: https://mesonbuild.com/Release-notes-for-1-12-0.html, 2026-09-18).
- **Wrap modes.** `--wrap-mode=nodownload`, `nofallback`, `forcefallback`, plus
  `--force-fallback-for=<list>` give users and distros control over network use and fallback
  behavior (source: https://mesonbuild.com/Subprojects.html, 2026-09-18).
- **Mixed build systems in wraps.** Since 1.3.0 a wrap's `method` can be `meson` (default), `cmake`
  or `cargo`; the CMake path is explicitly documented as experimental with "no backwards or forwards
  compatibility guarantees" (source: https://mesonbuild.com/Wrap-dependency-system-manual.html,
  2026-09-18).
- **Cross and native machine files.** INI-format files with `[binaries]`, `[host_machine]`,
  `[build_machine]`, `[target_machine]` and `[properties]` sections; properties include `sys_root`,
  `pkg_config_libdir`, `cmake_toolchain_file`, `cmake_defaults`, `cmake_use_exe_wrapper` and
  `java_home` (source: https://mesonbuild.com/Machine-files.html, 2026-09-18).
- **Devenv integration.** The environment set by `meson devenv` includes `MESON_DEVENV`,
  `MESON_PROJECT_NAME`, an extended `PKG_CONFIG_PATH` pointing at generated `-uninstalled.pc` files,
  and an extended `PATH` / `LD_LIBRARY_PATH` (source: https://mesonbuild.com/Commands.html,
  2026-09-18).

### Extensibility / Plugin Mechanism

Meson's extensibility model is deliberately narrow, and this is a defining constraint for any
orchestrator adapter.

- **No general plugin API.** The FAQ entry on proprietary toolchains states that compiler details
  "cannot be input via a configuration file, instead it requires changes to Meson's source code that
  need to be submitted to Meson master repository" (source: https://mesonbuild.com/FAQ.html,
  2026-09-18). Adding a compiler is an upstream contribution, not a configuration or plugin action.
- **Configuration-level extension** is available through the language itself: `run_command()` runs a
  command during the setup process with `capture`, `check`, `console` and `env` controls (source:
  https://mesonbuild.com/Reference-manual_functions.html, 2026-09-18); custom targets and code
  generation steps are supported because "you first need to build a custom tool and then use that
  tool to generate more source code" is an explicitly recognized need (source:
  https://mesonbuild.com/Overview.html, 2026-09-18).
- **Program and dependency overrides.** `meson.override_find_program()` lets a subproject provide a
  program so that `find_program()` resolves to it. Release 1.12.0 added a `native` keyword to both
  `subproject()` and `meson.override_find_program()` so a subproject can be built for the host or the
  build machine, which the release notes tie to Cargo workspaces building procedural macro crates
  (source: https://mesonbuild.com/Release-notes-for-1-12-0.html, 2026-09-18).
- **Subproject composition.** `subproject()` embeds external dependencies, while `subdir()` is the
  normal in-tree mechanism; the FAQ says the answer to "subdir or subproject" is "almost always
  `subdir`" (source: https://mesonbuild.com/FAQ.html, 2026-09-18).

There is no documented stable ABI for third-party backends, and no documented mechanism for an
external tool to inject build graph nodes without going through the DSL.

## 4. Status & Ecosystem

- **Release cadence.** The release notes index lists sequential 1.x releases with 1.13.0 currently
  in development (source: https://mesonbuild.com/Release-notes.html, 2026-09-18).
- **1.12.0 changes relevant to integration**: `subproject()` and `meson.override_find_program()` gain
  the `native` keyword for host-versus-build-machine targeting; OpenHarmony / HarmonyOS is
  recognized as an Android subsystem; support for the CACHEDIR.TAG specification; `dependency
  ('atomic')` works on MSVC >= 19.35.32124; `meson wrap install` accepts multiple positional
  arguments (source: https://mesonbuild.com/Release-notes-for-1-12-0.html, 2026-09-18).
- **1.1.0 changes that still shape usage**: `meson.options` was introduced as the preferred options
  filename, replacing `meson_options.txt`; the `none` backend was added; `--reconfigure` and
  `--wipe` became usable on an empty or failed build directory; `meson introspect` moved log output
  to stderr so stdout stays clean JSON (source: https://mesonbuild.com/Release-notes-for-1-1-0.html,
  2026-09-18).
- **Options filename migration.** The build options documentation states plainly: "Its name is
  `meson.options` ... For versions of meson before 1.1, this file was called `meson_options.txt`"
  (source: https://mesonbuild.com/Build-options.html, 2026-09-18). Any PolyOrch documentation,
  template, or detection heuristic must use `meson.options` and must not repeat the outdated
  `meson_options.txt` name as current.
- **Ecosystem: WrapDB.** Meson maintains a curated wrap database whose front page "lists all
  projects that are on the service"; adding a project is a pull request against
  `github.com/mesonbuild/wrapdb` (source: https://mesonbuild.com/Wrapdb-projects.html, 2026-09-18).
- **Ecosystem: pkg-config and CMake compatibility.** Meson operates inside the existing native
  ecosystem rather than replacing it. `dependency()` understands pkg-config and CMake packages, and
  wraps can wrap CMake or Cargo projects (source:
  https://mesonbuild.com/Release-notes-for-1-1-0.html, 2026-09-18;
  https://mesonbuild.com/Wrap-dependency-system-manual.html, 2026-09-18).
- **Ecosystem: IDE and tooling integration.** Meson intentionally does not write a backend per IDE.
  Instead it emits `meson-info/intro-*.json` introspection files (`intro-benchmarks.json`,
  `intro-buildoptions.json`, and others), and IDEs can watch that directory for changes (source:
  https://mesonbuild.com/IDE-integration.html, 2026-09-18).
- **Governance / licensing.** Copyright is held by "all members of the Meson development team";
  no corporate single-vendor claim is documented (source: https://mesonbuild.com/legal.html, 2026-09-18).

## 5. Market Positioning

Meson positions itself as the user-friendly, performance-conscious alternative in the native build
system space, and its documented arguments are aimed at the pain of writing and debugging build
definitions:

- The stated design point is that "every moment a developer spends writing or debugging build
  definitions is a second wasted", and so is time spent waiting for the build system (source:
  https://mesonbuild.com/index.html, 2026-09-18).
- The language is the differentiator: a purpose-built, non-Turing-complete DSL, chosen for
  "simplicity, clarity and conciseness" (source: https://mesonbuild.com/Overview.html, 2026-09-18).
- Performance positioning is explicit: no Make backend exists because Make "simply cannot be made
  fast", and users are told "Just use Ninja" (source: https://mesonbuild.com/FAQ.html, 2026-09-18).
- The feature set is positioned as batteries-included rather than macro-driven: unit testing,
  coverage reporting and precompiled headers "should just work out of the box" without third-party
  macros (source: https://mesonbuild.com/Overview.html, 2026-09-18).
- Dependency handling is ecosystem-compatible: a "built-in multiplatform dependency provider that
  works together with distro packages" (source: https://mesonbuild.com/index.html, 2026-09-18).
- The `none` backend opens a niche for configure-test-install pipelines that do not need a compiler
  backend at all (source: https://mesonbuild.com/Release-notes-for-1-1-0.html, 2026-09-18).

For PolyOrch, Meson occupies the "well-supported third-party build system" slot: a mature,
Python-installable configure step whose output is consumed by Ninja. It is not a monorepo
orchestrator and does not manage environments; those responsibilities remain with PolyOrch.

## 6. Product Highlights

The capabilities most relevant to an orchestrator, stated as documented facts:

1. **A stable, inspectable two-phase interface.** Configure with `meson setup`, then build. The
   build directory is self-contained, and the configure result is machine-readable JSON (source:
   https://mesonbuild.com/IDE-integration.html, 2026-09-18).
2. **Structured introspection instead of output scraping.** `meson introspect` supports
   `--projectinfo`, `--targets`, `--tests`, `--buildoptions`, `--dependencies`,
   `--scan-dependencies`, `--machines`, `--installed`, `--install-plan`, `--compilers` and more, with
   `-a/--all` and JSON output (source: https://mesonbuild.com/Commands.html, 2026-09-18).
3. **Deterministic exit-code semantics.** 0 for success, 1 for command-line / `meson.build` problems,
   2 for internal errors (source: https://mesonbuild.com/Running-Meson.html, 2026-09-18).
4. **A real test runner with sharding.** `meson test` supports suites, wildcards, repeat, timeouts,
   `--wrapper`, `--gdb`, benchmarking and `--slice i/n` (source:
   https://mesonbuild.com/Commands.html, 2026-09-18; https://mesonbuild.com/Unit-tests.html,
   2026-09-18).
5. **Reproducible-dependency controls.** Wrap modes can forbid network access or forbid fallbacks,
   and a shared package cache can be pointed at by environment variable (source:
   https://mesonbuild.com/Subprojects.html, 2026-09-18;
   https://mesonbuild.com/Wrap-dependency-system-manual.html, 2026-09-18).
6. **First-class cross compilation.** Cross and native files make toolchain and property selection a
   declarative input rather than a shell script (source: https://mesonbuild.com/Cross-compilation.html,
   2026-09-18; https://mesonbuild.com/Machine-files.html, 2026-09-18).
7. **A ready dependency database.** WrapDB provides wraps installable with one command, and 1.12.0
   allows several at once (source: https://mesonbuild.com/Wrapdb-projects.html, 2026-09-18;
   https://mesonbuild.com/Release-notes-for-1-12-0.html, 2026-09-18).
8. **Packaging and install staging.** `meson install`, `DESTDIR`, install tags and `meson dist` cover
   the standard release steps (source: https://mesonbuild.com/Running-Meson.html, 2026-09-18;
   https://mesonbuild.com/Commands.html, 2026-09-18).

## 7. Value to PolyOrch

PolyOrch ships a Meson adapter whose current shape is: run `meson setup`, then run `ninja`. The
points below are ordered by how directly they affect that adapter and the orchestration model around
it. PolyOrch's own engine is Xmake, its environment manager is Pixi, and it reaches vcpkg and Conan
through Xmake's `vcpkg::` and `conan::` namespaces. Meson has no equivalent native dependency
namespace, which is the central integration gap and is called out below.

### [Adopt] Directly reusable

- **[Adopt] Treat `meson setup` as a mandatory, separately reported step.** The adapter should run
  `meson setup <builddir> <sourcedir>` explicitly (not the bare default command, which is deprecated
  since 0.64.0) and cache the result, because everything downstream depends on a successful configure
  (source: https://mesonbuild.com/Commands.html, 2026-09-18).
- **[Adopt] Classify failures using Meson's documented exit codes.** Map exit 1 to a
  configuration/source error surfaced to the user, and exit 2 to an internal Meson error that the
  orchestrator should report with the full command line and build log (source:
  https://mesonbuild.com/Running-Meson.html, 2026-09-18).
- **[Adopt] Discover targets and tests via `meson introspect`, not via `meson.build` parsing.** Use
  `meson introspect <builddir> --targets`, `--tests`, `--buildoptions`, `--dependencies` and
  `--scan-dependencies` to populate PolyOrch's graph and task list after configure (source:
  https://mesonbuild.com/Commands.html, 2026-09-18).
- **[Adopt] Read the `meson-info/intro-*.json` files as the cached introspection surface.** The
  directory is refreshed on reconfigure or option change, and `meson-info.json` is guaranteed to be
  the last file written, so the adapter can use its appearance as a completion signal (source:
  https://mesonbuild.com/IDE-integration.html, 2026-09-18).
- **[Adopt] Delegate test execution to `meson test` and use `--slice i/n` for scheduling.** PolyOrch's
  parallel task scheduler can shard an expensive Meson test suite across workers with `--slice`, and
  can use `--list` to enumerate without running (source:
  https://mesonbuild.com/Unit-tests.html, 2026-09-18; https://mesonbuild.com/Commands.html,
  2026-09-18).
- **[Adopt] Map Meson test protocols into PolyOrch's result model.** Exit code 77 means skipped and
  99 means `ERROR` under the default `exitcode` protocol, and 1.11.0 added `expected_exitcode`; the
  adapter must translate these rather than treating any non-zero code as a plain failure (source:
  https://mesonbuild.com/Unit-tests.html, 2026-09-18).
- **[Adopt] Use build options (`-D name=value`) as the canonical per-project configuration channel.**
  Types include `boolean`, `combo`, `integer`, `array`, `string` and `feature`; `feature` values
  `enabled` / `disabled` / `auto` map cleanly onto tri-state PolyOrch feature flags (source:
  https://mesonbuild.com/Build-options.html, 2026-09-18).
- **[Adopt] Use the documented `buildtype` mapping when PolyOrch exposes debug/release presets.**
  `debug`, `release`, `debugoptimized`, `minsize` and `plain` correspond to defined `debug` and
  `optimization` combinations, so the adapter should emit `-Dbuildtype=...` (or the finer-grained
  pair) rather than inventing flag sets (source: https://mesonbuild.com/Builtin-options.html,
  2026-09-18).
- **[Adopt] Use cross files and native files as the cross-compilation interface.** The adapter should
  accept a cross file path from `polyorch.toml` and pass `--cross-file`, and use `--native-file` for
  native overrides; both are documented first-class inputs to `setup` (source:
  https://mesonbuild.com/Cross-compilation.html, 2026-09-18;
  https://mesonbuild.com/Native-environments.html, 2026-09-18).
- **[Adopt] Use `DESTDIR` plus a configure-time `--prefix` for staged installs.** This is the
  documented packaging path and integrates with PolyOrch release tasks without patching project files
  (source: https://mesonbuild.com/Running-Meson.html, 2026-09-18).
- **[Adopt] Use `meson dist` for source-release tasks.** It is a first-class command that produces a
  release archive and can include subproject sources, which removes the need for PolyOrch to
  reimplement tarball assembly (source: https://mesonbuild.com/Commands.html, 2026-09-18).
- **[Adopt] Use `meson devenv --dump` to capture the runtime environment for tasks.** The dumped
  environment includes the build-directory `PATH`, `LD_LIBRARY_PATH` and the `PKG_CONFIG_PATH`
  extension pointing at `-uninstalled.pc` files, which is exactly the state a downstream task needs
  (source: https://mesonbuild.com/Commands.html, 2026-09-18).
- **[Adopt] Enforce offline dependency resolution with `--wrap-mode=nodownload` in hermetic profiles.**
  This forbids network use during configure and only uses preexisting sources, which pairs with a
  PolyOrch-managed package cache (source: https://mesonbuild.com/Subprojects.html, 2026-09-18).
- **[Adopt] Support a shared wrap cache via `MESON_PACKAGE_CACHE_DIR`.** Since 1.3.0 it can replace
  the per-project `subprojects/packagecache`, so PolyOrch can host one cache directory for the whole
  monorepo (source: https://mesonbuild.com/Wrap-dependency-system-manual.html, 2026-09-18).

### [Adapt] Reusable with modification

- **[Adapt] Replace "parse the build file, then plan" with "configure, then introspect".** Meson's
  language is real code with functions, method calls, control flow and duck typing, so a static
  parser cannot soundly recover the target graph; the adapter must configure once and read
  `meson introspect` (source: https://mesonbuild.com/Syntax.html, 2026-09-18;
  https://mesonbuild.com/Commands.html, 2026-09-18). PolyOrch's planner needs an explicit
  "configure is part of discovery" phase for Meson projects.
- **[Adapt] Generate the Meson native file from the Pixi environment.** Meson reads compilers such as
  `CC` from the environment during first invocation, but PolyOrch should not rely on ambient state:
  it should write a native file containing the Pixi-resolved compiler binaries and `pkg_config_libdir`
  / `pkg_config_path`, then pass `--native-file` (source: https://mesonbuild.com/howtox.html,
  2026-09-18; https://mesonbuild.com/Machine-files.html, 2026-09-18).
- **[Adapt] Bridge vcpkg and Conan into Meson through pkg-config and CMake variables.** Meson has no
  `vcpkg::` or `conan::` namespace; it resolves dependencies through pkg-config and CMake. The
  adapter should point `PKG_CONFIG_PATH`, `CMAKE_PREFIX_PATH` and, where needed, a `cmake_toolchain_file`
  property at the prefixes produced by Xmake's `vcpkg::` / `conan::` integration, and document this
  mapping in the adapter contract (source: https://mesonbuild.com/Release-notes-for-1-1-0.html,
  2026-09-18; https://mesonbuild.com/Machine-files.html, 2026-09-18).
- **[Adapt] Detect implicit regeneration and invalidate configure state.** Ninja silently re-runs
  Meson when `meson.build` changes, so PolyOrch should hash `meson.build` and `meson.options` files
  and force `meson setup --reconfigure` when they change, instead of assuming its cached configure
  result is still valid (source: https://mesonbuild.com/Running-Meson.html, 2026-09-18).
- **[Adapt] Always repeat the full `-D` option set on `--reconfigure` / `--wipe`.** Since 1.1.0 those
  flags work on an empty or previously failed build directory, but "previously passed command line
  options must be repeated as only a successful build saves configured options" (source:
  https://mesonbuild.com/Release-notes-for-1-1-0.html, 2026-09-18). PolyOrch cannot rely on a
  half-configured directory remembering options.
- **[Adapt] Pick one build entry point and pin it.** `ninja -C <builddir>` and `meson compile
  -C <builddir>` are both valid; `meson compile` also accepts `-j`, `-l` and `--ninja-args` (source:
  https://mesonbuild.com/Commands.html, 2026-09-18; https://mesonbuild.com/Running-Meson.html,
  2026-09-18). The adapter should standardize on one so that cache keys, logs and cancellation behave
  consistently, rather than choosing per invocation.
- **[Adapt] Treat WrapDB as a fallback dependency source, not a primary one.** PolyOrch's stated
  dependency path is vcpkg / Conan via Xmake. Where a Meson project needs a dependency those do not
  provide, the adapter can fall back to `meson wrap install <name>` (multiple names supported since
  1.12.0) while recording the wrap in the lock state (source:
  https://mesonbuild.com/Wrapdb-projects.html, 2026-09-18;
  https://mesonbuild.com/Release-notes-for-1-12-0.html, 2026-09-18).
- **[Adapt] Isolate mixed-build-system subprojects.** Wrap `method` can be `cmake` or `cargo`, but the
  CMake path is marked experimental with no compatibility guarantees, so PolyOrch should treat such
  subprojects as opaque units and not attempt cross-adapter graph unification through them (source:
  https://mesonbuild.com/Wrap-dependency-system-manual.html, 2026-09-18).
- **[Adapt] Use the `none` backend for configure-test-install-only packages.** For projects with no
  build rules, `--backend=none` removes the Ninja dependency entirely, which PolyOrch can exploit to
  schedule those packages on workers without Ninja installed (source:
  https://mesonbuild.com/Release-notes-for-1-1-0.html, 2026-09-18).
- **[Adapt] Map PolyOrch's dependency graph onto Meson's `subdir()` convention.** Inside a single
  Meson project the norm is `subdir()` per directory rather than `subproject()`, and subproject
  declaration must be at the top level `meson.build`; PolyOrch should not force intra-project
  subdivision into separate Meson projects (source: https://mesonbuild.com/FAQ.html, 2026-09-18;
  https://mesonbuild.com/Subprojects.html, 2026-09-18).
- **[Adapt] Use `meson.override_find_program()` and the 1.12.0 `native` keyword when a package must
  produce a build-time tool.** This is the documented mechanism for a subproject to supply a program
  to its parent, and the `native` keyword exists precisely for build-machine versus host-machine
  duality (source: https://mesonbuild.com/Release-notes-for-1-12-0.html, 2026-09-18). PolyOrch can
  lean on this instead of adding its own tool-staging layer for Meson projects.

### [Avoid] Known pitfalls / not applicable

- **[Avoid] Do not write `meson_options.txt` as if it were current.** The file was renamed to
  `meson.options` in 1.1.0; PolyOrch docs, templates and file detection must use `meson.options` and
  may mention the old name only as historical (source: https://mesonbuild.com/Build-options.html,
  2026-09-18; https://mesonbuild.com/Release-notes-for-1-1-0.html, 2026-09-18).
- **[Avoid] Do not parse `meson.build` textually to extract targets, sources or dependencies.** The
  language is dynamically typed with control flow, so such a parser is unsound; use introspection
  after configure (source: https://mesonbuild.com/Syntax.html, 2026-09-18).
- **[Avoid] Do not assume a Make backend or a generic "make-like" build command.** Meson has no Make
  backend by design, and the backend set is Ninja, `none`, the Visual Studio family and Xcode
  (source: https://mesonbuild.com/FAQ.html, 2026-09-18; https://mesonbuild.com/Commands.html,
  2026-09-18).
- **[Avoid] Do not invoke the bare `meson [options]` default command.** The implicit default is
  deprecated since 0.64.0 specifically to avoid clashes with future commands; always pass an explicit
  subcommand such as `setup` (source: https://mesonbuild.com/Commands.html, 2026-09-18).
- **[Avoid] Do not rely on WrapDB downloads inside hermetic builds.** A wrap without a populated
  package cache will fetch from the network; if PolyOrch promises offline or reproducible builds it
  must combine `--wrap-mode=nodownload` with `MESON_PACKAGE_CACHE_DIR` and fail loudly on a cache
  miss (source: https://mesonbuild.com/Subprojects.html, 2026-09-18;
  https://mesonbuild.com/Wrap-dependency-system-manual.html, 2026-09-18).
- **[Avoid] Do not depend on experimental CMake-in-Meson wraps for production orchestration.** The
  wrap documentation states the CMake method has "no backwards or forwards compatibility
  guarantees", which is incompatible with a stable adapter contract (source:
  https://mesonbuild.com/Wrap-dependency-system-manual.html, 2026-09-18).
- **[Avoid] Do not fork or monkeypatch Meson to add toolchain support.** The documented path for a
  new compiler is an upstream code contribution to the Meson repository; a forked engine would
  diverge from the pinned toolchain and break PolyOrch's reproducibility story (source:
  https://mesonbuild.com/FAQ.html, 2026-09-18).
- **[Avoid] Do not expect Meson to model a monorepo workspace.** Meson has projects and subprojects,
  not a workspace-level package graph; PolyOrch must own the monorepo graph layer and treat each
  Meson project as one node (source: https://mesonbuild.com/Subprojects.html, 2026-09-18).
- **[Avoid] Do not treat introspection output as stable without pinning the Meson version.** JSON
  introspection and the CLI surface evolve across releases (for example `expected_fail` and
  `expected_exitcode` arrived in 1.11.0, and `--slice` in 1.8.0), so the adapter should pin a Meson
  version per project and assert it via the project's `meson_version` declaration (source:
  https://mesonbuild.com/Unit-tests.html, 2026-09-18;
  https://mesonbuild.com/Reference-manual_functions.html, 2026-09-18).
- **[Avoid] Do not assume `meson test` starts from a clean build.** Rebuild behavior is coupled to
  the backend, and `--no-rebuild` exists for deliberate use, so PolyOrch should make its own
  build-before-test step explicit rather than relying on test invocation side effects (source:
  https://mesonbuild.com/Commands.html, 2026-09-18).
