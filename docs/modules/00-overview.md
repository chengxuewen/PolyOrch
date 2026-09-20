# PolyOrch Modules — Overview

> Reference for PolyOrch internals. Read [`../architecture.md`](../architecture.md) first: it carries the
> invariants and the structural view. These modules are looked up, not read through.

## What PolyOrch is

PolyOrch is delivered as **one Xmake addon**. The addon extension system maps one-to-one onto the three deliverables:

| Deliverable | Addon construct |
|---|---|
| CLI commands (`init` / `enter` / `build` / `debug` / `doctor`) | **plugins** |
| Bridge library (cargo · cmake · pixi · npm) | **rules** |
| `init` scaffolding | **project templates** |
| The contract itself | versioned document plus a `doctor` plugin that validates it |

## Addon payload layout

Xmake fixes the payload layout, and it maps directly onto the deliverables:

```
┌ polyorch/   installs to ~/.xmake/addons/polyorch/<version>/ ─────────────┐
│ addon.lua                                                                │  manifest; the only required file
│ tests/test.lua                                                           │  NOT installed (set_sourcedir isolates it)
│ src/                                                                     │  the payload root
│   plugins/<cmd>/                                                         │  -> xmake <cmd>                        CLI
│   rules/<bridge>/                                                        │  -> add_rules("@addon/polyorch/<b>")  bridges
│   templates/...                                                          │  -> xmake create -t ...                init
│   modules/                                                               │  -> import("@addon.polyorch.foo")      shared Lua
│   includes/                                                              │  -> includes("@addon/polyorch/<x>")   package defs
│   toolchains/<name>/                                                     │  -> set_toolchains("@addon/polyorch")  toolchains
└──────────────────────────────────────────────────────────────────────────┘
```

PolyOrch claims `plugins/`, `rules/`, `templates/`, `modules/` and `includes/`. `toolchains/` is
**available but unused in v0.1** -- PolyOrch ships no compiler. It is listed because Xmake, not
PolyOrch, decides which payload directories exist.

Two rules follow and are part of the contract:

- **Payloads must never hardcode their own addon name.** They refer to each other through `@self` (`import("@self.private.board")`), which is what lets the same code run both installed and from a working copy.
- **Only payload directories are installed**, so `tests/`, CI files, and the README never reach the user's cache. `set_sourcedir("src")` is what enforces that.

## Reference styles

```lua
includes("@addon/polyorch/board")           -- an includes file
add_rules("@addon/polyorch/cmake")          -- a rule
import("@addon.polyorch.graph")             -- a module (dots, not slashes)
```

| Reference | Points at |
|---|---|
| `@addon/<name>/<payload>` | a rule, toolchain or includes file used by the project APIs |
| `@addon.<name>.<module>` | a Lua module used by `import()` |
| `@self.<module>` | a module of the addon that owns the running script |

## Where things live

```text
~/.xmake/addons/<name>/<version>/    the installed payloads (a cache, not a source of truth)
~/.xmake/addons/addons.conf          the registry Xmake reads on startup
<project>/xmake-addons.lock          the versions this project resolved (committed)
```

The precedent for this shape is the official catalogue: `esp32-devel`, `stm32-devel` and `avr-devel` each ship
a toolchain, build rules and project templates; `doxygen-plugin`, `format-plugin` and `serial-tools` register
a command each.

## Modules

| Module | Covers |
|---|---|
| [`01-contract.md`](./01-contract.md) | bridge contract, package-source contract, derivation rules |
| [`02-dependency-workflow.md`](./02-dependency-workflow.md) | how a consumer depends on PolyOrch; the two development loops |
| [`03-error-model.md`](./03-error-model.md) | degrade versus fail hard |
| [`04-testing-strategy.md`](./04-testing-strategy.md) | the five executable layers |

## Related documents

- [`../architecture.md`](../architecture.md) — the design baseline
- [`../README.md`](../README.md) — the documentation index
- [`../reference/README.md`](../reference/README.md) — profiles of related projects
