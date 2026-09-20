# Adapters

> **Authoritative for the adapter surface.** The v1.0 record for this topic is whitepaper §6.2 and §6.4. Describes the four adapter types (CMake / Xmake / Meson / Colcon) -- their target systems, integration methods, artifact consumption, incremental build capability, and current status -- plus IDE and debugging integration. See the terminology note below for how these map onto the design baseline's *bridges*.

## Adapter Overview (§6.2)

PolyOrch's core differentiator is its **adapter architecture**. Adapters are responsible for connecting heterogeneous build systems into a unified orchestration framework:

| Adapter | Target System | Integration Method |
| :--- | :--- | :--- |
| **CMake Adapter** | Existing CMake projects | Invokes `cmake --build`, consumes `install/` artifacts |
| **Xmake Adapter** | Native Xmake modules | Direct drive, enjoying full caching and incremental builds |
| **Meson Adapter** | Meson projects | Invokes `meson setup` + `ninja` |
| **Colcon Adapter** | ROS 2 workspaces | Invokes `colcon build`, integrates the `package.xml` ecosystem |

The adapter mechanism allows PolyOrch to bring polyglot projects into a single build graph without rewriting existing build logic.

> **Terminology.** The whitepaper calls these *adapters*. The design baseline reframes the same role for v0.1 as **bridges** and ships four of them — cargo, cmake, pixi, npm — deferring meson and ros/colcon; see `docs/architecture.md` ⑤ and `decisions.md` D8. The Xmake row above is the **engine**, not a bridge: its dual role is resolved, with Xmake as the substrate.

## Adapter Details

### CMake Adapter

| Dimension | Content | Source |
| :--- | :--- | :--- |
| Target system | Existing CMake projects | §6.2 |
| Integration method | Invokes `cmake --build` | §6.2, §5.3 |
| Artifacts consumed | `install/` artifacts | §6.2; §5.3 states "consumes its build artifacts" |
| Incremental build capability | Not specified individually by the whitepaper; the Core layer uniformly handles "incremental build and cache management" | §5.1 |
| Current status | Compatible with existing projects | §5.1 architecture diagram |

### Xmake Adapter

| Dimension | Content | Source |
| :--- | :--- | :--- |
| Target system | Native Xmake modules | §6.2 |
| Integration method | Direct drive | §6.2, §5.3 |
| Artifacts consumed | Does not consume external artifacts; Xmake also serves as the native build engine — a dual role that is now **resolved** (Xmake is the engine), see `docs/architecture.md` | §5.1, §9.2 |
| Incremental build capability | Enjoying full caching and incremental builds | §6.2 |
| Current status | Core build engine | §5.1 architecture diagram, §9.2 `xmake = { enabled = true, core = true }` |

### Meson Adapter

| Dimension | Content | Source |
| :--- | :--- | :--- |
| Target system | Meson projects | §6.2 |
| Integration method | Invokes `meson setup` + `ninja` | §6.2, §5.3 |
| Artifacts consumed | The whitepaper does not specify Meson's artifact consumption path, TBD | §6.2 |
| Incremental build capability | Not specified by the whitepaper, TBD | §6.2 |
| Current status | Future extension | §5.1 architecture diagram |

### Colcon Adapter

| Dimension | Content | Source |
| :--- | :--- | :--- |
| Target system | ROS 2 workspaces | §6.2 |
| Integration method | Invokes `colcon build` | §6.2, §5.3 |
| Artifacts consumed | Integrates the `package.xml` ecosystem; specific artifact paths not specified by the whitepaper, TBD | §6.2 |
| Incremental build capability | Not specified by the whitepaper, TBD | §6.2 |
| Current status | ROS 2 ecosystem | §5.1 architecture diagram |

## Fields the Adapter Interface Must Define

> The whitepaper does **not define** any concrete interface shape (no trait, struct, or function signature is given). The fields below are the minimum information set **strictly inferred** from the whitepaper's configuration examples (§9.2), adapter table (§6.2), and data flow (§5.2). Concrete types and shapes are TBD.

- **Adapter identifier**: The configuration key name in `[adapters]` (`cmake` / `xmake` / `colcon` / `meson`), used to enable or disable the corresponding adapter in configuration (§9.2).
- **Target system identification basis**: The adapter must be able to route based on project type, i.e., determine which adapter to use based on project files (`CMakeLists.txt`, `xmake.lua`, `Cargo.toml`, `package.json`, etc.) (§5.2 steps 2-3).
- **Invocation command**: The actual command for the target build system (`cmake --build`, `meson setup` + `ninja`, `colcon build`; Xmake uses direct drive) (§6.2).
- **Artifact consumption path**: Where to obtain build artifacts after adapter execution (CMake consumes `install/` artifacts; others see the table above, TBD) (§6.2, §5.3).
- **Incremental build capability**: Whether it has built-in caching and incremental capabilities (only Xmake explicitly "enjoys full caching and incremental builds"; the Core layer uniformly handles incremental build and cache management) (§6.2, §5.1).
- **Enabled state**: `enabled = true | false` (§9.2).
- **Role flag**: `core = true`, currently used only for Xmake, marking its core build engine role (§9.2).
- **Additional parameters**: Such as Colcon's `workspace = "ros2_ws"`, specifying the external workspace path (§9.2).

> How the above fields are organized into an interface (object, function, or configuration structure) is not specified by the whitepaper and is TBD. The Xmake adapter's exact responsibilities are settled by the resolved dual role — Xmake is the engine, not an adapter; see [Architecture Design](../architecture.md).

## IDE & Debugging (§6.4)

**VS Code**: The `xmake-vscode` plugin automatically generates debug configurations, so users don't need to manually create `launch.json`.

**CLion / IntelliJ**: **unverified, do not rely on it.** The whitepaper asserts that the `xmake-idea` plugin provides native debugging via DAP from CLion 2026.1, but no primary source has been found for the claim — see `docs/architecture.md` O2 and `status.md`.

**Unified debugging**: PolyOrch's `polyorch debug <target>` command automatically performs the following steps:

1. Build the target in `RelWithDebInfo` or `Debug` mode
2. Generate the corresponding IDE debug configuration
3. Launch the debugger with `program` pointing to the uniform debuggable binary at `build/<plat>/<arch>/<mode>/<name>` (see `docs/architecture.md` ③)
4. Map debug paths back to source via `sourceFileMap` or symlinks

## Related Docs

- [Whitepaper](../whitepaper.md) (§5.3, §6.2, §6.4)
- [Architecture Design](../architecture.md)
- [CLI](./cli.md)
- [Project Outline](./outline.md)
