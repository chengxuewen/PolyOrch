# Competitive Analysis

> **Authoritative for the competitive positioning.** The v1.0 record for this topic is whitepaper §7. Preserves the competitor overview, the differentiation positioning, and the comparison summary.

## Competitor Overview (§7.1)

| Project | Positioning | Core Language | Configuration | Core Mechanism | Difference from PolyOrch |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Bazel** | Large-scale polyglot build system | Java | Starlark | Hermetic build + remote execution | PolyOrch is lighter and doesn't enforce a unified build language |
| **Buck2** | Meta's Bazel replacement | Rust | Starlark | High performance + remote execution | PolyOrch provides a more friendly IDE debugging experience |
| **Pants** | Monorepo build system | Python | BUILD files | Dependency inference + fine-grained caching | PolyOrch supports more languages with a more flexible adapter architecture |
| **moon** | Polyglot build orchestrator | Rust | YAML/TOML | Project graph + content-addressed caching | PolyOrch natively integrates vcpkg/Conan/Pixi |
| **Aster** | Polyglot monorepo orchestrator | Rust | `aster.toml` | Project discovery + dependency graph | PolyOrch uses Xmake as its build engine, not a pure dispatcher |
| **Guild** | Rust-native monorepo orchestrator | Rust | `guild.toml` | Task dependency graph + parallel execution | PolyOrch supports CMake/Colcon adapters |
| **colcon** | ROS 2 meta-build tool | Python | `package.xml` | Workspace dispatch + extension points | PolyOrch is not bound to the ROS ecosystem; it targets general polyglot monorepos |

## Differentiation (§7.2)

PolyOrch's core differences from existing tools are:

**1. Xmake as a build engine, not a pure dispatcher**

Aster, moon, Pants, and Guild are fundamentally **dispatchers**: they invoke each language's native build tools but don't provide a build engine themselves. PolyOrch, on the other hand, uses **Xmake as its native build engine**. Xmake handles both native module building and package management as well as dispatching to adapters.

**2. Adapter architecture flexibility**

Unlike Bazel, which requires all projects to use a unified `BUILD` file, PolyOrch bridges existing build systems through adapters. CMake projects continue using CMake, Colcon workspaces continue using Colcon, and PolyOrch handles unified orchestration.

**3. Deep integration of environment and dependencies**

PolyOrch natively integrates Pixi environment management and vcpkg/Conan package management, something Aster, moon, Pants, Guild, and other tools lack. Pixi ensures consistent toolchain versions across platforms, while Xrepo unifies C++ dependency handling from vcpkg and Conan.

**4. Native polyglot compilation support**

Xmake has unique advantages in cross-language polyglot compilation. Around 10 lines of configuration can achieve C++ and Rust `cxxbridge` interop, automatic header generation for Swift and C++, and C# and C/C++ P/Invoke interop.

## Comparison Summary (§7.3)

| Dimension | PolyOrch | Bazel | Pants | moon | Aster | colcon |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Polyglot compilation** | Native | Native | Partial | Partial | Dispatch | Extension |
| **CMake compatibility** | Adapter | rules_foreign_cc | None | None | None | Native |
| **Colcon integration** | Adapter | None | None | None | None | Native |
| **vcpkg/Conan** | Native | Toolchain files | None | None | None | Weak |
| **Pixi environment** | Native | None | None | proto | None | None |
| **IDE debugging** | Auto-generated | Requires config | Requires config | Requires config | Requires config | Requires config |
| **Learning curve** | Low | High | Medium | Medium | Low | Low |

## Related Docs

- [Whitepaper](../whitepaper.md) (§7; see also §8.1 industry reference projects)
- [Architecture Design](../architecture.md)
- [Naming](./naming.md) (colcon naming logic comparison)
- [Project Outline](./outline.md)
