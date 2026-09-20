# Project Outline

> **Authoritative for goals, non-goals, and the proposed roadmap.** Synthesized from the v1.0 record (§4.1 and §4.2 for goals and non-goals, §5.1 for the layer breakdown) plus the doc map. The record contains no roadmap: every milestone here is a **proposal**, not agreed scope.

## Goals (§4.1)

PolyOrch's design goals revolve around five dimensions:

1. **Unified build orchestration**: Provide a single build entry point for polyglot monorepos, hiding the differences between underlying heterogeneous build systems.
2. **Adapter architecture**: Support heterogeneous build systems such as CMake, Xmake, Meson, and Colcon, as well as future build tools, through an extensible adapter mechanism.
3. **Environment and dependency unification**: Integrate Pixi to implement reproducible development environments, unifying dependency sources from package managers such as vcpkg, Conan, and Xrepo.
4. **Native polyglot compilation**: Use Xmake as the native build engine, supporting mixed compilation and cross-language calls for C++/Rust/Swift/Go and other languages within a single target.
5. **IDE-friendly experience**: Provide automated debug configuration generation, delivering near-native C++ project breakpoint debugging in mainstream IDEs like VS Code and CLion.

## Non-Goals (§4.2)

PolyOrch clearly defines the following boundaries of responsibility:

- **Does not replace each language's native build system**: CMake remains CMake, Cargo remains Cargo; PolyOrch handles orchestration and dispatching, not rewriting build logic.
- **Does not replace package managers**: vcpkg, Conan, and Xrepo continue handling package management responsibilities; PolyOrch provides a unified entry point.
- **Does not enforce a unified build language**: Each language project continues using its native build system; PolyOrch bridges them through adapters.

## Layer Breakdown (derived from §5.1 four-layer architecture)

| Module | Responsibility | Layer | Dependencies |
| :--- | :--- | :--- | :--- |
| PolyOrch Core | Project discovery and dependency graph construction, adapter dispatch and task orchestration, incremental build and cache management, CLI interface | Orchestration Layer | Adapter Layer (task dispatch) |
| CLI (`polyorch build/run/clean/debug`, plus `graph` / `list`) | Command entry point triggered by users and IDEs | Orchestration Layer | PolyOrch Core |
| Adapter Framework | Mechanism for connecting heterogeneous build systems into a unified orchestration graph | Adapter Layer | Orchestration Layer; external build tools |
| CMake Adapter | Compatible with existing CMake projects: invokes `cmake --build`, consumes `install/` artifacts | Adapter Layer | CMake |
| Xmake Adapter | Directly drives native Xmake modules, enjoying full caching and incremental builds; the dual role is **resolved** — Xmake is the engine, not an adapter (see [Architecture Design](../architecture.md)) | Adapter Layer | Xmake core engine |
| Meson Adapter | Invokes `meson setup` + `ninja` | Adapter Layer | Meson / Ninja |
| Colcon Adapter | Invokes `colcon build`, integrates ROS 2 workspaces and `package.xml` ecosystem | Adapter Layer | colcon |
| Xmake Core Engine | Native polyglot compilation (C++/Rust/Python/TS/WASM/C#), Xrepo package management (vcpkg/Conan namespaces), built-in build cache/cross-compilation/distributed compilation, Addon extension system | Build Engine Layer | Environment & Dependency Layer |
| Pixi Environment Management | Toolchain version unification, conda-forge / PyPI, `pixi.lock` reproducibility | Environment & Dependency Layer | None (lowest layer) |
| Package Manager Access | vcpkg (manifest mode), Conan, Xrepo (built-in) as dependency sources | Environment & Dependency Layer | Individual package managers |

> The dependency column order is derived from §5.2 data flow (CLI → Core → Adapters → Engine → Environment). Exact interfaces between modules are TBD.

## Doc Map

| Doc | Target Audience | Primary Content |
| :--- | :--- | :--- |
| [Whitepaper](../whitepaper.md) | Everyone | Authoritative source document v1.0; brand naming, historical decisions, system architecture, and technical positioning |
| [Documentation Index](../README.md) | Everyone | Index, navigation table, and reading paths |
| [Architecture Design](../architecture.md) | Architects / Contributors | Design baseline: invariants, the layered view, data flow, the debug surface, the reproducibility boundary, bridge priority, and open decisions |
| [Module Reference](../modules/00-overview.md) | Contributors | Internals reference: the contract, the dependency workflow, the error model, the testing strategy |
| [Reference Profiles](../reference/README.md) | Architects / Researchers | Externally sourced profiles of 12 related projects |
| [Adapters](./adapters.md) | Contributors | Four adapter types and debugging integration |
| [Environment & Dependencies](./environment.md) | Contributors | Pixi and vcpkg/Conan/Xrepo |
| [CLI](./cli.md) | Users / Contributors | Command reference and configuration examples |
| [Naming](./naming.md) | Everyone | Naming origin, rules, and historical decisions |
| [Competitive Analysis](./competitive-analysis.md) | Architects | Full benchmarking against Bazel and other tools |

## Milestones (proposed)

> The whitepaper **does not contain a roadmap**. All milestones below are **proposals (proposed / TBD)**, derived only from §4.1 Goals and §4.2 Non-Goals, containing no dates. Each item must be confirmed and aligned with the whitepaper before implementation.

- **M1 (proposed): Workspace Skeleton & CLI Foundation** — Corresponds to Goal 1. Establish `polyorch.toml` workspace configuration, project discovery and dependency graph construction, and command entry points like `polyorch build / list / graph`. Subject to non-goal constraints: do not rewrite existing build logic for any language.
- **M2 (proposed): Xmake Native Engine Integration** — Corresponds to Goals 1, 4. Use Xmake as the core build engine to connect native module building, incremental caching, and polyglot compilation entry points. Prerequisite: none. The Xmake dual-role question is resolved empirically (Xmake is the substrate; CMake is a generated output or a dispatch target). See the [Architecture Design](../architecture.md).
- **M3 (proposed): Adapter Expansion (CMake / Colcon / Meson)** — Corresponds to Goal 2. Connect three types of heterogeneous build systems into a unified build graph without rewriting existing build logic; priority and scope TBD.
- **M4 (proposed): Environment & Dependency Unification** — Corresponds to Goal 3. Integrate Pixi (all build commands run through `pixi run`) with vcpkg/Conan/Xrepo dependency access.
- **M5 (proposed): IDE Debugging Experience** — Corresponds to Goal 5. `polyorch debug` auto-generates debug configurations, supporting breakpoint debugging in VS Code and CLion. Subject to §6.4 constraints.
- **M6 (proposed): Polyglot Compilation Verification** — Corresponds to Goal 4. Verify polyglot scenarios such as C++ and Rust `cxxbridge` interop; iteration order and acceptance criteria TBD.

## Related Docs

- [Whitepaper](../whitepaper.md) (§4.1, §4.2, §5.1)
- [Architecture Design](../architecture.md)
- [Adapters](./adapters.md)
- [Environment & Dependencies](./environment.md)
- [CLI](./cli.md)
- [Documentation Index](../README.md)
