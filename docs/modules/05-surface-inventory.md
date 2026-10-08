# The Shipped Surface -- Module Inventory

> Part of the [module reference](./00-overview.md). This is the INDEX of what actually
> ships: every public `polyorch_*` function, one row per function, signature quoted from the
> source header comment. The index is not the spec: the authoritative statement of a
> function's behavior is (1) its header comment in `cmake/<module>.cmake`, (2) the contract
> clauses in [01-contract.md](./01-contract.md), and (3) its covering test case. When those
> disagree, the tests are the referee (the repo's own doctrine: never trust property text
> where a real run can prove it).

## Consumption form (D16)

The deliverable is the CMake helper surface: plain files under `cmake/`, consumed by

```cmake
list(APPEND CMAKE_MODULE_PATH "<path>/PolyOrch/cmake")
include(PolyOrchRustHelpers)     # rust face (brings PolyOrchFindRust)
include(PolyOrchNodeHelpers)     # node face (D29)
include(PolyOrchPixiHelpers)     # environment face
```

or, in the embedded shape, `add_subdirectory(PolyOrch)` from the host (embed sentinel:
`if(NOT TARGET PolyOrch::PolyOrch)`, D27) with the `PolyOrch_BUILD_*` options. Target
naming on the fused surface follows the D27/D28 grammar: kebab real targets under the
`polyorch-<dir>-` namespace, `::` for exported/imported names only.

## Public functions (44)

### `PolyOrchFindRust.cmake` -- rust toolchain discovery

| Function | Signature (source comment) |
|---|---|
| `polyorch_rust_version_ok` | `polyorch_rust_version_ok(<actual> <out-var> [VERSION <v> [EXACT]] [RANGE <min>..<max>])` |
| `polyorch_rust_setup` | `polyorch_rust_setup([FROM <system\|pixi>] [REQUIRED] [NO_NATIVE_PROBE])` |
| `polyorch_rust_tool_bootstrap` | `polyorch_rust_tool_bootstrap(TOOL <crate> [BINARY <name>] [VERSION <v>]` |

Covered by: `t-rust-findrust`, `t-rust-setup-*`, `t-rust-rustc-version`, `t-rust-toolplan`.

### `PolyOrchRustHelpers.cmake` -- rust build graph

| Function | Signature (source comment) |
|---|---|
| `polyorch_rust_build` | `polyorch_rust_build(TARGET <n> [PACKAGE p] [CRATE c] [BINARY\|STATIC\|SHARED] [PROFILE p] [MANIFEST path] [LOCKED\|FROZEN] [NO_SOURCES] [PREBUILD t] [DEPENDS t...] [FEATURES a;b] [BASE_DIR d] [FOLDER f])` |
| `polyorch_rust_import` | `polyorch_rust_import(MANIFEST <path> [CRATES a;b] [LOCKED\|FROZEN]` |
| `polyorch_rust_package_version` | `polyorch_rust_package_version(PACKAGE <p> [MANIFEST <path>] OUT_VAR <out>)` |
| `polyorch_rust_set_features` | `polyorch_rust_set_features(TARGET <n> [FEATURES a;b] [ALL_FEATURES]` |
| `polyorch_rust_set_env_vars` | `polyorch_rust_set_env_vars(TARGET <n> [VAR=VALUE ...])` |
| `polyorch_rust_add_cargo_flags` | `polyorch_rust_add_cargo_flags(TARGET <n> [FLAGS <flag>...])` |
| `polyorch_rust_add_rustflags` | `polyorch_rust_add_rustflags(TARGET <n> [FLAGS <flag>...])` |
| `polyorch_rust_set_hostbuild` | `polyorch_rust_set_hostbuild(TARGET <n>)` |
| `polyorch_rust_link_libraries` | `polyorch_rust_link_libraries(TARGET <n> <library\|target\|abs-path>...)` |
| `polyorch_rust_test` | `polyorch_rust_test(PACKAGE <p> [NAME <t>] [MANIFEST <path>] [ALL] [ARGS ...]` |
| `polyorch_rust_run` | `polyorch_rust_run(TARGET <imported> [FOLDER <ide>])` |
| `polyorch_rust_clean` | `polyorch_rust_clean([NAME <t>] [BASE_DIR <td>] [FOLDER <ide>])` |
| `polyorch_rust_install` | `polyorch_rust_install(TARGETS <handle>...` |
| `polyorch_rust_cxxbridge` | `polyorch_rust_cxxbridge(TARGET <rust-handle> FILES <file.rs>...` |
| `polyorch_rust_cbindgen` | `polyorch_rust_cbindgen(TARGET <rust-handle> HEADER_NAME <h.h>` |
| `polyorch_rust_pyext` | `polyorch_rust_pyext(TARGET <cdylib-handle> MODULE <import-name>` |

Covered by: the `t-rust-*` family (`build`/`import`/`setters`/`linkplan`/`crossplan`/`install*`/`cxxbridge`/`cbindgen`/`pyext`/`vscodedebug`/...).

### `PolyOrchNodeHelpers.cmake` -- node/npm workspaces (D29)

| Function | Signature (source comment) |
|---|---|
| `polyorch_node_setup` | `polyorch_node_setup([REQUIRED])` |
| `polyorch_node_import` | `polyorch_node_import(ROOT <root-package.json>)` |
| `polyorch_node_build` | `polyorch_node_build(TARGET <handle> MANIFEST <package.json> [OUTPUT_DIR <dir>])` |
| `polyorch_node_test` | `polyorch_node_test(TARGET <handle>)` |
| `polyorch_node_run` | `polyorch_node_run(TARGET <handle> SCRIPT <name> [ARGS ...])` |

Covered by: `t-rust-node`, `t-rust-noderun`, `t-rust-nodebadargs`, `t-rust-nodeknobs`, `t-rust-nodesetup-missing`, `t-rust-fusion`.

### `PolyOrchPixiHelpers.cmake` -- pixi environments

| Function | Signature (source comment) |
|---|---|
| `polyorch_pixi_find` | `polyorch_pixi_find([VERSION <x.y.z>] [REQUIRED] [QUIET])` |
| `polyorch_pixi_setup` | `polyorch_pixi_setup([MANIFEST <p>] [ENVIRONMENT <n>] [VERSION <x.y.z>]` |
| `polyorch_pixi_install` | `polyorch_pixi_install([ENVIRONMENT <n>] [ALL] [FROZEN] [LOCKED])` |
| `polyorch_pixi_env_target` | `polyorch_pixi_env_target(NAME <t> [ENVIRONMENT <n>] [ALL] [FROZEN] [LOCKED]` |
| `polyorch_pixi_lock_check` | `polyorch_pixi_lock_check([QUIET])` |
| `polyorch_pixi_env_paths` | `polyorch_pixi_env_paths([ENVIRONMENT <n>] [PREFIX_OUT <v>] [BIN_OUT <v>]` |
| `polyorch_pixi_activate_script` | `polyorch_pixi_activate_script(OUTPUT <file> [SHELL <s>] [ENVIRONMENT <n>])` |
| `polyorch_pixi_scripts_install` | `polyorch_pixi_scripts_install([WORKDIR <dir>])` |
| `polyorch_pixi_report` | `polyorch_pixi_report([ENVIRONMENT <n>])` |
| `polyorch_pixi_config_set` | `polyorch_pixi_config_set(KEY <k> VALUE <v> [SCOPE local\|global\|system] [UNSET])` |
| `polyorch_pixi_mirror` | `polyorch_pixi_mirror(SET <url...> [SCOPE local\|global])` |
| `polyorch_pixi_channel` | `polyorch_pixi_channel([ADD <url...> \| REMOVE <url...> \| LIST_OUT <var>]` |
| `polyorch_pixi_init` | `polyorch_pixi_init(WORKDIR <dir> [NAME <n>] [VERSION <x.y.z>] [CHANNELS <url...>]` |
| `polyorch_pixi_dependency` | `polyorch_pixi_dependency(DEPENDS <spec...> [REMOVE] [FEATURE <f>]` |
| `polyorch_pixi_environment_add` | `polyorch_pixi_environment_add(NAME <n> [FEATURES <f...>] [SOLVE_GROUP <g>]` |
| `polyorch_pixi_task_add` | `polyorch_pixi_task_add(NAME <n> COMMAND <cmd...> [FEATURE <f>] [ENVIRONMENT <n>]` |
| `polyorch_pixi_publish` | `polyorch_pixi_publish(TARGET_DIR <dir> \| CHANNEL <url> [PATH <p>]` |
| `polyorch_pixi_tool_install` | `polyorch_pixi_tool_install([VERSION <x.y.z>] [HOME <dir>] [URL <installer-url>]` |
| `polyorch_pixi_tool_ensure` | `polyorch_pixi_tool_ensure([VERSION <x.y.z>] [URL <installer-url>]` |
| `polyorch_pixi_bootstrap` | `polyorch_pixi_bootstrap([VERSION <x.y.z>] [MANIFEST <p>] [ENVIRONMENT <n>]` |

Covered by: `t-bootstrap-*`, `t-find-real`, `t-env-arg`, `t-json-array*`, `t-scratch`, `t-search-manifest`, `t-scripts-install`, `t-tool-ensure-*`, `t-command-vector`, `t-init-workspace`, `t-install-frozen-locked`.

## Helper modules (no public surface of their own)

- `PolyOrchOptionHelpers.cmake` -- `polyorch_option` (option with
  `PROJECT_IS_TOP_LEVEL`-derived default) plus the expression helpers
  `polyorch_parse_all_arguments` and the genex evaluation shims used by the
  rust/node faces.
- `PolyOrchCMakeHelpers.cmake` -- CxxKit-lineage shared utilities
  (`polyorch_normalize_name`, `polyorch_evaluate_expression`,
  `polyorch_path_join`, `polyorch_fetch_3rdparty`, `polyorch_add_subdirectory`
  and friends); internal plumbing, not part of the bridge contract.
- `PolyOrchPlatformSupport.cmake` -- platform/triple/mkspec detection shared
  with the host (external rewrite in flight; see `AGENTS.md`).

## Related documents

- [`00-overview.md`](./00-overview.md) -- module reference index
- [`01-contract.md`](./01-contract.md) -- the bridge contract these functions implement
- [`../architecture.md`](../architecture.md) -- the design baseline (D16 lens at its head)
