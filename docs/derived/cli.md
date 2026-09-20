# CLI & Configuration

> **Authoritative for the CLI and configuration surface.** The v1.0 record for this topic is whitepaper §9.1 and §9.2. Provides the `polyorch` command reference and the `polyorch.toml` / `xmake.lua` examples.

## Command Reference (§9.1)

| Command | Purpose | Example |
| :--- | :--- | :--- |
| `polyorch build` | Build all projects | `polyorch build` |
| `polyorch build <target>` | Build a specific target | `polyorch build //services/api` |
| `polyorch run <target>` | Run a specific target | `polyorch run //apps/cli` |
| `polyorch debug <target>` | Debug a specific target (auto-generates IDE debug config) | `polyorch debug //services/api` |
| `polyorch clean` | Clean build cache | `polyorch clean` |
| `polyorch build --affected --base=main` | Build only affected packages | `polyorch build --affected --base=main` |
| `polyorch graph` | List project dependency graph | `polyorch graph` |
| `polyorch list` | Display project list | `polyorch list` |

> The semantics of `--base=main` (e.g., whether it is equivalent to git's comparison baseline) are not elaborated by the whitepaper and are TBD.

Original examples (preserved byte-for-byte):

```bash
# Build all projects
polyorch build

# Build a specific target
polyorch build //services/api

# Run a specific target
polyorch run //apps/cli

# Debug a specific target (auto-generates IDE debug config)
polyorch debug //services/api

# Clean build cache
polyorch clean

# Build only affected packages
polyorch build --affected --base=main

# List project dependency graph
polyorch graph

# Display project list
polyorch list
```

## Configuration Examples (§9.2)

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

### `[adapters]` Key Reference

| Config Key | Meaning & Purpose |
| :--- | :--- |
| `cmake = { enabled = true }` | Enables the CMake adapter for connecting existing CMake projects (corresponds to status "Compatible with existing projects") |
| `xmake = { enabled = true, core = true }` | Enables the Xmake adapter and marks `core = true`, i.e., the native core build engine role (corresponds to status "Core build engine") |
| `colcon = { enabled = true, workspace = "ros2_ws" }` | Enables the Colcon adapter and specifies the ROS 2 workspace directory `ros2_ws` (corresponds to status "ROS 2 ecosystem") |
| `meson = { enabled = false }` | Disables the Meson adapter (corresponds to status "Future extension", currently not enabled) |

> Other config keys: `[workspace] members` declares workspace member directory globs; `[environment] pixi = true` enables Pixi environment management (see also [Environment & Dependencies](./environment.md)).
>
> Xmake appears in both the Adapter Layer and the Build Engine Layer. That dual role is **resolved**: Xmake is the engine, and `core = true` marks it. The whitepaper's "Xmake Adapter" row is the engine seen from the adapter table. See the [Architecture Design](../architecture.md).

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

## Related Docs

- [Whitepaper](../whitepaper.md) (§9.1, §9.2)
- [Architecture Design](../architecture.md)
- [Adapters](./adapters.md)
- [Environment & Dependencies](./environment.md)
- [Naming](./naming.md) (naming rules for CLI / package / import name `polyorch`)
