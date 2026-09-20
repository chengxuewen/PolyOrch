# PolyOrch Whitepaper

> **A scalable build orchestrator for polyglot monorepos.**
>
> *Adapter-based integration for heterogeneous build systems, environments, and package managers.*
>
> **面向多语言 monorepo 的可扩展构建编排器。**

| Field | Value |
| :--- | :--- |
| **Version** | v1.0 |
| **Date** | September 2026 |
| **Status** | **Frozen v1.0 record.** This document is the historical snapshot, not the working authority. The working surface is `docs/derived/` for the product topics, and `docs/architecture.md` plus `docs/modules/` for the design; where they disagree with this record, they win. Known supersessions are listed in `architecture.md` under `Superseded From The Whitepaper`; unresolved claims are tracked in its open decision points. |
| **Topic** | Brand naming, historical decisions, system architecture, and technical positioning |

---

> **How to read this document.** The `§n` tags used throughout `docs/` point here, at the v1.0 record for that
> topic. They are historical references, not a chain of authority: each document under `docs/derived/` is now
> authoritative for its own subject, and `docs/architecture.md` supersedes this record where the two disagree.

## 1. Executive Summary

**PolyOrch** is a scalable build orchestrator for polyglot monorepos. It does not compile code itself. Rather, through a unified adapter architecture it dispatches heterogeneous build systems such as CMake, Xmake, Meson, and Colcon, integrates Pixi for environment management and vcpkg/Conan for package management, and supports unified building, debugging, and dependency management across C++, Rust, Python, TypeScript, WASM, C#, and other languages.

| Layer | Name |
| :--- | :--- |
| **Brand name** | **PolyOrch** |
| **Repository name** | `PolyOrch` |
| **CLI / package name / domain** | `polyorch` |
| **Official acronym** | **PBOS** (Polyglot Build Orchestration System) |
| **Official description** | A scalable build orchestrator for polyglot monorepos. |
| **Chinese description** | 面向多语言 monorepo 的可扩展构建编排器。 |

**One-line positioning**:

> PolyOrch is a scalable build orchestrator for polyglot monorepos, providing adapter-based integration for heterogeneous build systems, environments, and package managers.

Chinese:

> PolyOrch is a scalable build orchestrator for polyglot monorepos that unifies heterogeneous build systems, environments, and package managers through adapters.

---

## 2. Brand Naming

### 2.1 Naming Origin

**PolyOrch** is formed by combining two word roots:

- **Poly**: from **Polyglot**, itself from the Greek *poly-* (many) plus *glot* (tongue, language), meaning "many languages".
- **Orch**: from **Orchestration**, meaning "to orchestrate, to coordinate".

Combined, **PolyOrch** is pronounced **POL-ee-ork**, which conveys the core positioning of "polyglot build orchestration" precisely.

### 2.2 Naming Rules

| Context | Spelling | Notes |
| :--- | :--- | :--- |
| Brand display / logo / document titles | **PolyOrch** | Camel case, so the Poly + Orch roots remain visible |
| GitHub repository name | **PolyOrch** | GitHub repository names are case-insensitive; camel case is kept for display |
| CLI command | `polyorch` | All lowercase, following terminal convention |
| PyPI / npm / crates.io package name | `polyorch` | Package managers require all lowercase |
| Domain | `polyorch.dev` / `polyorch.io` | Domains are case-insensitive; register in lowercase |
| Code import name | `polyorch` | Import names in Python, Node, and similar are conventionally lowercase |

This brand & naming layering follows the convention of mainstream projects such as CMake / cmake and OpenCV / opencv.

### 2.3 Acronym

**Official acronym**: **PBOS**, standing for **P**olyglot **B**uild **O**rchestration **S**ystem.

`PBOS` was found to have no direct conflict in the build-tool space, and is suitable for formal documents, academic papers, and technical indexes.

---

## 3. Historical Decisions

### 3.1 Naming Exploration Phase

The PolyOrch name went through a systematic exploration process, ruling out several candidates that either conflicted with existing names or were semantically imprecise:

| Candidate | Full name | Reason for rejection |
| :--- | :--- | :--- |
| ODESYS | Open Dataflow Engineering System | Engineering is too broad, and Development did not make it into the acronym |
| DOCA | Dataflow-Oriented Control Architecture | Conflicts with NVIDIA DOCA |
| DODA | Dataflow-Oriented Distributed Architecture | A small number of open-source projects in the technical domain already use it |
| DODAS | Dataflow-Oriented Distributed Architecture System | Conflicts with CERN DODAS |
| DODDS | Dataflow-Oriented Distributed Development System | Conflicts with the US Department of Defense Dependents Schools acronym |
| DDSA | Dataflow Distributed System Architecture | Conflicts with the chemical substance DDSA |
| Polycon | Polyglot Construction | Shares a name with a construction-materials company trademark |
| Polcon | Polyglot Construction | Conflicts across multiple domains, including a Polish science-fiction convention and a political-science index |
| PolyCons | Polyglot Construction | Conflicts with the existing `polycons` framework |
| Foundry | Foundry | Multiple projects share the name (blockchain, AI) |
| Loom | Loom | Already taken by Shopify's `@shopify/loom` |
| Anvil | Anvil | An `anvil-build` build system already exists |
| Crucible | Crucible | Already used for a code-generation engine |
| Kiln | Kiln | Already used for AI orchestration and SystemVerilog tooling |

### 3.2 Naming Strategy Shift

After ruling out a large number of "descriptive compound words" and "common English words", the naming strategy shifted from **functional-descriptive** to **root-combination coinage**. The logic behind `PolyOrch` matches that of `colcon`: take the leading letters of two words and combine them into a short, readable neologism with brand character.

| colcon | PolyOrch |
| :--- | :--- |
| **col**lective + **con**struction | **Poly**glot + **Orch**estration |
| Pronounced KOL-kon | Pronounced POL-ee-ork |
| Meta build tool (ROS 2 ecosystem) | Build orchestrator (polyglot monorepo) |

### 3.3 Positioning Convergence

Once the name was settled, the project positioning converged, across several rounds of discussion, to:

> **A scalable build orchestrator for polyglot monorepos.**

This description synthesizes the phrasing used by mainstream projects in the field:

| Project | Official description |
| :--- | :--- |
| Aster | "A build orchestrator for polyglot monorepos." |
| moon | "A Bazel-inspired polyglot build orchestrator." |
| Pants | "A scalable build system for monorepos." |
| Guild | "Rust-native polyglot monorepo orchestrator." |

**PolyOrch** ultimately adopted **"A scalable build orchestrator for polyglot monorepos"** as its official description. It conforms to industry convention while preserving the project's differentiation in adapter-driven integration of heterogeneous toolchains.

---

## 4. System Goals

### 4.1 Core Goals

The PolyOrch design goals span the following five dimensions:

1. **Unified build orchestration**: provide a single build entry point for polyglot monorepos, hiding the differences between the underlying heterogeneous build systems.
2. **Adapter architecture**: through an extensible adapter mechanism, support heterogeneous build systems such as CMake, Xmake, Meson, and Colcon, along with build tools added in the future.
3. **Unified environment and dependencies**: integrate Pixi to provide a reproducible development environment, and manage dependency sources from vcpkg, Conan, Xrepo, and similar package managers in a unified way.
4. **Native polyglot compilation**: use Xmake as the native build engine to support mixed compilation and cross-language calls within a single target for C++, Rust, Swift, Go, and other languages.
5. **IDE-friendly experience**: provide automated debug configuration generation, delivering a breakpoint debugging experience close to a native C++ project in mainstream IDEs such as VS Code and CLion.

### 4.2 Non-Goals

PolyOrch explicitly draws the following responsibility boundaries:

- **It does not replace each language's native build system**: CMake remains CMake and Cargo remains Cargo. PolyOrch handles orchestration and dispatch, not rewriting build logic.
- **It does not replace package managers**: vcpkg, Conan, and Xrepo continue to carry package-management responsibility. PolyOrch provides a unified entry point.
- **It does not force a single build language**: each language's project continues to use its customary build system, and PolyOrch bridges them through adapters.

---

## 5. System Architecture

### 5.1 Layered Architecture

PolyOrch uses a **layered orchestration architecture**, divided from top to bottom into four layers:

```text
┌───────────────────────────────────────────────────────────────────────────────┐
│                              Orchestration Layer                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │  PolyOrch Core                                                          │  │
│  │  • Project discovery + dependency graph                                 │  │
│  │  • Adapter dispatch + task orchestration                                │  │
│  │  • Incremental builds + cache                                           │  │
│  │  • CLI (polyorch build/run/clean/debug)                                 │  │
│  └─────────────────────────────────────────────────────────────────────────┘  │
├───────────────────────────────────────────────────────────────────────────────┤
│                                 Adapter Layer                                 │
│  ┌────────────────┐ ┌────────────────┐ ┌────────────────┐ ┌────────────────┐  │
│  │ CMake adapter  │ │ Xmake adapter  │ │ Meson adapter  │ │ Colcon adapter │  │
│  │   (existing)   │ │ (core engine)  │ │    (future)    │ │    (ROS 2)     │  │
│  └────────────────┘ └────────────────┘ └────────────────┘ └────────────────┘  │
├───────────────────────────────────────────────────────────────────────────────┤
│                              Build Engine Layer                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │  Xmake core engine                                                      │  │
│  │  • Native polyglot compilation (C++/Rust/Python/TS/WASM/C#)             │  │
│  │  • Xrepo packages (vcpkg/Conan namespaces)                              │  │
│  │  • Build cache, cross-compilation, distributed builds                   │  │
│  │  • Addon system (plugins/rules/toolchains/templates)                    │  │
│  └─────────────────────────────────────────────────────────────────────────┘  │
├───────────────────────────────────────────────────────────────────────────────┤
│                        Environment & Dependency Layer                         │
│  ┌───────────────────────────────────┐ ┌───────────────────────────────────┐  │
│  │   Pixi (environment management)   │ │    Package managers (sources)     │  │
│  │    Unified toolchain versions     │ │       vcpkg (manifest mode)       │  │
│  │        conda-forge / PyPI         │ │               Conan               │  │
│  │     pixi.lock reproducibility     │ │         Xrepo (built-in)          │  │
│  └───────────────────────────────────┘ └───────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Data Flow

1. **A developer triggers a build**: through the CLI (`polyorch build`) or an IDE integration.
2. **Project discovery and dependency graph construction**: PolyOrch Core scans the workspace, discovers the per-language project files (`CMakeLists.txt`, `xmake.lua`, `Cargo.toml`, `package.json`, and similar), and builds a unified dependency graph.
3. **Adapter dispatch**: based on project type, the matching adapter (CMake / Xmake / Meson / Colcon) is selected to carry out the build task.
4. **Build engine execution**: the Xmake core engine handles the build of native modules, including cross-language compilation, Xrepo dependency resolution, and compilation and linking.
5. **Environment isolation**: every build command runs inside a Pixi-managed environment, ensuring consistent toolchain versions.
6. **Artifact output**: build artifacts are written to a unified `install/` or `build/` directory for final linking and debugging.

### 5.3 Key Integration Points

| Integration point | Implementation |
| :--- | :--- |
| PolyOrch to Xmake | Xmake serves as the core build engine and is driven directly |
| PolyOrch to CMake | The adapter invokes CMake and consumes its build artifacts |
| PolyOrch to Colcon | The adapter invokes `colcon build` and integrates the ROS 2 workspace |
| PolyOrch to Meson | The adapter invokes `meson setup` plus `ninja` |
| Xmake to vcpkg/Conan | `add_requires("vcpkg::...")` / `add_requires("conan::...")` |
| Environment unification | Pixi manages the toolchain, and `pixi run` executes build commands |
| IDE debugging | Auto-generate `launch.json`, with `program` pointing at the executable under `install/` |

---

## 6. Core Features

### 6.1 Polyglot Build Orchestration

PolyOrch uses **Xmake** as its native build engine, with native support for the following languages:

| Language | Support | Maturity |
| :--- | :--- | :--- |
| **C/C++** | Native Xmake support, C++20 modules, cross-compilation | Production-ready |
| **Rust** | Native Xmake support, with `cxxbridge` for cross-language calls | Production-ready |
| **Python** | The `python.library` rule, pybind11 bindings | Production-ready |
| **TypeScript/Node.js** | Invokes npm through a custom rule | Available |
| **WASM** | `rules_wasm`, building WASM components from Rust/Go/C++ | Available |
| **C#** | Xmake v3.0.8+ supports the dotnet toolchain, with P/Invoke interoperability | Available |

Xmake bundles a Lua 5.5 runtime and supports the `addons` extension system, where a single addon can carry plugins, rules, toolchains, project templates, and Lua modules.

### 6.2 Adapter Mechanism

PolyOrch's core differentiator is its **adapter architecture**. Adapters bring heterogeneous build systems into the unified orchestration framework:

| Adapter | Target system | Integration |
| :--- | :--- | :--- |
| **CMake adapter** | Existing CMake projects | Invokes `cmake --build` and consumes the `install/` artifacts |
| **Xmake adapter** | Native Xmake modules | Driven directly, with full caching and incremental builds |
| **Meson adapter** | Meson projects | Invokes `meson setup` plus `ninja` |
| **Colcon adapter** | ROS 2 workspaces | Invokes `colcon build` and integrates the `package.xml` ecosystem |

The adapter mechanism lets PolyOrch fold polyglot projects into a single build graph without rewriting any existing build logic.

### 6.3 Unified Environment and Dependencies

**Pixi integration**:

Pixi acts as the environment manager, defining toolchain versions through `pixi.toml`, with `pixi.lock` guaranteeing reproducibility. PolyOrch executes every build command inside a controlled environment through `pixi run`.

**Package manager integration**:

Xmake natively supports vcpkg and Conan through namespaces:

```lua
-- Use a vcpkg package directly (manifest mode supports version selection)
add_requires("vcpkg::zlib 1.2.11")

-- Use a Conan package directly
add_requires("conan::openssl/1.1.1g", {alias = "openssl"})
```

Xmake automatically invokes the corresponding package manager to download and install dependencies, and handles the header and link-library paths.

### 6.4 IDE and Debugging

**VS Code**: the `xmake-vscode` plugin generates debug configurations automatically, so users do not need to create `launch.json` by hand.

**CLion / IntelliJ**: the `xmake-idea` plugin supports native debugging through DAP starting with CLion 2026.1.

**Unified debugging**: PolyOrch's `polyorch debug <target>` command performs the following steps automatically:

1. Build the target in `RelWithDebInfo` or `Debug` mode
2. Generate the corresponding IDE debug configuration
3. Launch the debugger, with `program` pointing at the executable under `install/`
4. Map the debug paths back to source through `sourceFileMap` or symlinks

---

## 7. Competitor and Benchmark Analysis

### 7.1 Competitor Overview

| Project | Positioning | Core language | Configuration | Core mechanism | Difference from PolyOrch |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Bazel** | Large-scale polyglot build system | Java | Starlark | Hermetic builds plus remote execution | PolyOrch is lighter and does not force a single build language |
| **Buck2** | Meta's Bazel alternative | Rust | Starlark | High performance plus remote execution | PolyOrch offers a friendlier IDE debugging experience |
| **Pants** | Monorepo build system | Python | BUILD files | Dependency inference plus fine-grained caching | PolyOrch supports more languages, and its adapter architecture is more flexible |
| **moon** | Polyglot build orchestrator | Rust | YAML/TOML | Project graph plus content-addressed caching | PolyOrch integrates vcpkg/Conan/Pixi natively |
| **Aster** | Polyglot monorepo orchestrator | Rust | `aster.toml` | Project discovery plus dependency graph | PolyOrch uses Xmake as a build engine rather than being a pure scheduler |
| **Guild** | Rust-native monorepo orchestrator | Rust | `guild.toml` | Task dependency graph plus parallel execution | PolyOrch supports CMake and Colcon adapters |
| **colcon** | ROS 2 meta build tool | Python | `package.xml` | Workspace scheduling plus extension points | PolyOrch is not tied to the ROS ecosystem and targets generic polyglot monorepos |

### 7.2 Differentiation

PolyOrch's core differences from existing tools are:

**1. Xmake as a build engine, not a pure scheduler**

Aster, moon, Pants, and Guild are essentially **schedulers**: they invoke each language's native build tool and provide no build engine of their own. PolyOrch instead treats **Xmake as its native build engine**. Xmake handles both the building and package management of native modules and the dispatching of adapters.

**2. The flexibility of the adapter architecture**

Unlike Bazel, which requires all projects to use a unified `BUILD` file, PolyOrch bridges existing build systems through adapters. CMake projects keep using CMake, Colcon workspaces keep using Colcon, and PolyOrch handles the unified orchestration.

**3. Deep integration of environment and dependencies**

PolyOrch natively integrates Pixi environment management and vcpkg/Conan package management, which tools such as Aster, moon, Pants, and Guild do not offer. Pixi keeps toolchain versions consistent across platforms, and Xrepo handles C++ dependencies coming from vcpkg and Conan in a unified way.

**4. Native support for polyglot compilation**

Xmake has a distinctive advantage in cross-language compilation. Roughly ten lines of configuration are enough to achieve `cxxbridge` interoperability between C++ and Rust, automatic header generation between Swift and C++, and P/Invoke interoperability between C# and C/C++.

### 7.3 Comparison Summary

| Dimension | PolyOrch | Bazel | Pants | moon | Aster | colcon |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Polyglot compilation** | Native | Native | Partial | Partial | Scheduled | Extension |
| **CMake compatibility** | Adapter | rules_foreign_cc | None | None | None | Native |
| **Colcon integration** | Adapter | None | None | None | None | Native |
| **vcpkg/Conan** | Native | Toolchain files | None | None | None | Weak |
| **Pixi environment** | Native | None | None | proto | None | None |
| **IDE debugging** | Auto-generated | Requires setup | Requires setup | Requires setup | Requires setup | Requires setup |
| **Learning curve** | Low | High | Medium | Medium | Low | Low |

---

## 8. References

### 8.1 Industry Reference Projects

- **Aster**: "A build orchestrator for polyglot monorepos." Supports Elixir, Python, TypeScript, Go, and Rust.
- **moon**: "A Bazel-inspired polyglot build orchestrator." Built in Rust, with remote caching support.
- **Pants**: "A scalable build system for monorepos." Dependency inference and fine-grained caching.
- **Guild**: "Rust-native polyglot monorepo orchestrator." Task dependency graph and parallel execution.
- **Bazel**: Google's polyglot build system, with hermetic builds and remote execution.
- **colcon**: the ROS 2 meta build tool, with a modular architecture built on extension points.

### 8.2 Tech Stack References

- **Xmake**: a Lua-based cross-platform build tool. v3.1.1 introduced the Addon extension system, v3.0.8 added C# support, and v3.0.9 upgraded the Lua 5.5 runtime.
- **Pixi**: a unified environment manager integrating the conda-forge and PyPI ecosystems, guaranteeing reproducibility through `pixi.lock`.
- **vcpkg / Conan**: natively integrated by Xmake through namespaces, with support for manifest mode and version selection.

### 8.3 Naming References

- **colcon**: **col**lective + **con**struction, taking the leading letters of two words and combining them. Pronounced KOL-kon.
- **Bazel**: an anagram of Google's internal tool Blaze, with no full form.
- **Buck2**: the second generation of Meta's build tool Buck.
- **CMake**: **C**ross-platform **Make**. The brand is `CMake` and the command is `cmake`.
- **OpenCV**: **Open** **C**omputer **V**ision. The brand is `OpenCV` and the package name is `opencv`.

---

## 9. Appendix

### 9.1 Command-Line Interface

```bash
# Build every project
polyorch build

# Build a specific target
polyorch build //services/api

# Run a specific target
polyorch run //apps/cli

# Debug a specific target (auto-generates the IDE debug configuration)
polyorch debug //services/api

# Clean the build cache
polyorch clean

# Build only the affected packages
polyorch build --affected --base=main

# Print the project dependency graph
polyorch graph

# List projects
polyorch list
```

### 9.2 Configuration File Examples

**`polyorch.toml`** (workspace configuration):

```toml
[workspace]
members = ["services/*", "libs/*", "apps/*"]

[adapters]
cmake = { enabled = true }
xmake = { enabled = true, core = true }
colcon = { enabled = true, workspace = "ros2_ws" }
meson = { enabled = false }

[environment]
pixi = true
```

**`xmake.lua`** (native module build):

```lua
add_rules("mode.debug", "mode.release")

add_requires("vcpkg::zlib 1.2.11")
add_requires("conan::openssl/1.1.1g", {alias = "openssl"})

target("core_cpp")
    set_kind("static")
    add_files("src/*.cpp")
    add_includedirs("include", {public = true})
    add_packages("zlib", "openssl")

target("perf_rust")
    set_kind("static")
    add_files("src/lib.rs")
    set_values("rust.cratetype", "staticlib")
```

---

**PolyOrch Whitepaper v1.0**
**PolyOrch: A scalable build orchestrator for polyglot monorepos.**
