# PolyOrch Modules — Overview

> Reference for PolyOrch internals. Read [`../architecture.md`](../architecture.md) first: it carries the
> invariants and the structural view. These modules are looked up, not read through.

## What PolyOrch is

Under D16 (2026-09-22; D3 amended 2026-09-23) PolyOrch **is the CMake helper surface**:
plain `cmake/*.cmake` modules plus their fixture test suites and examples. There is no
compiled PolyOrch binary and no addon wrapper -- the earlier "Lua shipped as an Xmake
addon" delivery form is retired, not deferred. The whitepaper's CLI (`init`/`enter`/
`build`/`debug`/`doctor`) remains the v1.0 record's product model; v0.1 ships the library
face it will sit on.

| Deliverable | Shipped construct (D16) |
|---|---|
| Environment face (pixi) | `cmake/PolyOrchPixiHelpers.cmake` -- find/setup/install/env_target/paths/activate/workspace-declaration verbs |
| Rust build graph | `cmake/PolyOrchFindRust.cmake` (toolchain discovery) + `cmake/PolyOrchRustHelpers.cmake` (build/import/test/run/install/cxxbridge/cbindgen/pyext) |
| Node build graph (D29) | `cmake/PolyOrchNodeHelpers.cmake` -- setup/import/build/test/run over npm-pnpm workspaces |
| Option/platform plumbing | `PolyOrchOptionHelpers`, `PolyOrchCMakeHelpers`, `PolyOrchPlatformSupport` |
| The contract itself | [01-contract.md](./01-contract.md) + the executable case suite in `tests/` |

The full function index lives in [05-surface-inventory.md](./05-surface-inventory.md).

## Module layout

```
cmake/
├── PolyOrchPixiHelpers.cmake      environment face (one module, D12)
├── PolyOrchFindRust.cmake         rust toolchain layer (D16 file split)
├── PolyOrchRustHelpers.cmake      rust build-graph API
├── PolyOrchNodeHelpers.cmake      node/npm workspaces (D29)
├── PolyOrchOptionHelpers.cmake    polyorch_option + expression helpers
├── PolyOrchCMakeHelpers.cmake     shared utilities (CxxKit lineage)
└── PolyOrchPlatformSupport.cmake  platform/triple detection (external rewrite in flight)
```

Consumption is `include()` / `add_subdirectory()` -- no registry, no cache directory, no
lockfile shadow (the D6 addon-drift hole retired with the addon form; the consumer pins
the checkout itself). Xmake's standing roles are the reference corpus and a
package-management source (vcpkg/conan via xrepo, O4 open); the pinned vendored skill set
under `docs/reference/xmake-skills/` is research material, not shipped payload.

## Modules

| Module | Covers |
|---|---|
| [`01-contract.md`](./01-contract.md) | bridge contract, package-source contract, derivation rules |
| [`02-dependency-workflow.md`](./02-dependency-workflow.md) | how a consumer depends on PolyOrch; the two development loops |
| [`03-error-model.md`](./03-error-model.md) | degrade versus fail hard |
| [`04-testing-strategy.md`](./04-testing-strategy.md) | the five executable layers |
| [`05-surface-inventory.md`](./05-surface-inventory.md) | the shipped function index (44 public verbs, D16 form) |

## Related documents

- [`../architecture.md`](../architecture.md) — the design baseline
- [`../README.md`](../README.md) — the documentation index
- [`../reference/README.md`](../reference/README.md) — profiles of related projects
