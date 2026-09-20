# Environment & Dependencies

> **Authoritative for the environment and dependency surface.** The v1.0 record for this topic is whitepaper §6.3, with the Environment & Dependency layer from §5.1 and the Tech Stack References from §8.2. Describes Pixi environment management and the vcpkg / Conan / Xrepo dependency unification mechanism.

## Pixi Environment Management

Pixi serves as the environment manager, defining toolchain versions through `pixi.toml` and ensuring reproducibility via `pixi.lock`. PolyOrch executes all build commands in a controlled environment through `pixi run`.

| Capability | Description | Source |
| :--- | :--- | :--- |
| Toolchain version unification | All projects share consistent compiler and toolchain versions | §5.1 |
| conda-forge / PyPI | Integrates both ecosystems as toolchain sources | §5.1, §8.2 |
| `pixi.lock` reproducibility | Locks dependencies to guarantee a reproducible environment | §5.1, §6.3, §8.2 |
| Execution entry point | All build commands run through `pixi run` | §6.3, §5.3 |

In the data flow (§5.2 step 5), "environment isolation" ensures all build commands execute within a Pixi-managed environment, guaranteeing consistent toolchain versions. This layer sits at the bottom of the four-layer architecture, providing a controlled environment for the Build Engine Layer (Xmake).

## Package Manager Integration

| Package Manager | Role | Description |
| :--- | :--- | :--- |
| vcpkg | Dependency source | Manifest mode (§5.1); Xmake provides native support via namespaces, supporting manifest mode and version selection (§8.2) |
| Conan | Dependency source | §5.1; also accessed through Xmake namespaces (§6.3, §8.2) |
| Xrepo | Built-in | Xmake's built-in package management entry point, hosting the vcpkg / Conan namespaces (§5.1) |

Xmake natively supports vcpkg and Conan through namespaces:

```lua
-- Use vcpkg packages directly (supports manifest mode for version specification)
add_requires("vcpkg::zlib 1.2.11")

-- Use Conan packages directly
add_requires("conan::openssl/1.1.1g", {alias = "openssl"})
```

Xmake automatically invokes the corresponding package manager to download and install dependencies, and handles header file and library linking paths.

> In other words: Xmake handles dependency resolution (Xrepo) and automatically injects the resolved results into compilation commands (header paths and library paths), so the build layer needs no manual configuration.

## Tech Stack References (§8.2)

- **Xmake** — Lua-based cross-platform build tool; v3.1.1 introduced the Addon extension system, v3.0.8 added C# support, v3.0.9 upgraded to Lua 5.5 runtime.
- **Pixi** — Unified environment manager integrating conda-forge and PyPI ecosystems, ensuring reproducibility through `pixi.lock`.
- **vcpkg / Conan** — Natively integrated by Xmake through namespaces, supporting manifest mode and version selection.

## Related Docs

- [Whitepaper](../whitepaper.md) (§5.1, §6.3, §8.2)
- [Architecture Design](../architecture.md)
- [CLI](./cli.md) (`[environment] pixi = true` in `polyorch.toml`)
- [Project Outline](./outline.md)
