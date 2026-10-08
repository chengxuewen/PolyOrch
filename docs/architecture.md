# PolyOrch Architecture Design

**v0.1 | 2026-09-20** | Input: whitepaper v1.0 + 12 verified project profiles (`docs/reference/`) + the `DEVSYS/xmake` prototype
Status: **design baseline**. Diagrams show the target; current reality is tracked in `AGENTS.md` and `.agents/memorys/status.md`. Decision evolution is recorded in `.agents/memorys/decisions.md` (D1 onward).

> **D16 lens (2026-09-22, governs every line below)**: the delivery form is the **CMake helper
> surface** (`cmake/*.cmake`, consumed by `include()` / `add_subdirectory()`); the earlier
> "Lua shipped as an Xmake addon" model is retired (D3 amendment 2026-09-23). Xmake's standing
> roles are the reference corpus and a package-management source (vcpkg/conan via xrepo). Where
> this document says "Xmake builds", "the PolyOrch addon", or draws an addon/`add_addons` layer,
> D16 governs and the sentence describes the prototype-era model. The whitepaper stays the frozen
> v1.0 record; this lens is the pointer D16 promised.

---

## Design Invariants (outrank every diagram below)

1. **Anything that affects the build result is pinned in the repository.** No build-affecting configuration may live in a user's global state. This invariant was earned three times over: the build engine came from a global package manager, the IDE resolved the engine from `PATH`, and package-source roots lived in global tool config.
2. **A bridge discovers, derives, and forwards. It never transcribes.** The native manifest is the only source of truth for *configuration*; the bridge targets are a view derived on every configure, never a persisted second copy of it. (Amended 2026-09-22, D17: the invariant governs configuration, not bytes -- *staging a copy of a build's output artifacts* into the engine's standard directories is permitted and is how bridged ecosystems participate in uniform paths, IDE layout, and `install(TARGETS)`.)
3. **One build authority.** Xmake builds. (Amended by D16: under the shipped form the single build authority per project is its native build system, driven through the CMake helper surface; "Xmake builds" was the prototype-era engine claim, kept here as the historical anchor for the insight-projection evidence that follows.) Generated CMake / VS / Xcode projects are **insight projections** for IDEs, never a second build path. Verified against the prototype: the generated CMake contains no `add_custom_command` at all, and bridged targets appear as inert `add_custom_target` nodes paired with an empty `add_executable(<name>_bin "")`.
4. **Zero intrusion.** A bridged project directory stays pure native. No xmake file may be written inside it. (D16 generalizes the prohibition: no PolyOrch-generated file of any kind -- including CMake fragments -- inside a bridged directory.)
5. **Optional absence degrades and complains; a suspicious toolchain source fails hard.** A missing optional toolchain must not break configure. A build that would silently use the wrong toolchain must not proceed.
6. **PolyOrch does not re-implement an engine.** Xmake already owns the dependency graph, cache, toolchain management, and package resolution. PolyOrch owns *how things connect*. (D16 reading: the sentence survives by generalizing -- cargo, CMake, meson and friends own their engines; the helper surface never re-implements one. The prototype's engine is now the reference corpus.)

---

## ① Layered View

```
┌ consumer repo ───────────────────────────────────────────────────────────────┐
│ CMakeLists   add_subdirectory(PolyOrch) . add_requires via xrepo (O4)      │
│ pixi.toml    toolchains + cmake        pixi.lock committed (D16)            │
│ third_party/<name>/<native manifest>                                         │  pure native, zero intrusion
└──────────────────────────────────────────────────────────────────────────────┘
                               |  pixi run cmake
                               v
┌──────────────────────────────────────────────────────────────────────────────┐
│ CLI        polyorch init / enter / build / debug / graph / doctor            │
├──────────────────────────────────────────────────────────────────────────────┤
│ CONTRACT   bridge contract  +  package-source contract                       │
├──────────────────────────────────────────────────────────────────────────────┤
│ BRIDGES    cargo . cmake . pixi . npm                                        │  (v0.1)
│            meson . ros / colcon                                              │  (deferred)
├──────────────────────────────────────────────────────────────────────────────┤
│ ENGINE     Xmake                                                             │  dep graph / cache / toolchain / Xrepo
└──────────────────────────────────────────────────────────────────────────────┘
```

The whitepaper's product-level view is a four-layer stack (orchestration / adapter / build engine / environment-dependency). The view above is the implementation form of the same thing: under the whitepaper's v1.0 model the "adapter layer" and "build engine layer" both resolved to the single Xmake tree; under D16 each project's native build system is its own engine and the bridge roles are carried by the CMake helper surface (rust / node / pixi faces). The "environment and dependency layer" resolves to Pixi plus package-source declarations (O4 open).

## ② Data Flow
```
┌ flow ──────────────────────────────────────────────────────────────────────────┐
│ 1 init       polyorch init  -> skeleton: pixi.toml + xmake.lua + third_party/  │
│ 2 configure  bridges scan   -> target tree (in memory; nothing persisted)      │
│ 3 build      xmake dispatch -> native tool -> artifacts                        │
│ 4 debug      surface gen    -> .vscode/* + launch.json -> <name>_bin           │
├────────────────────────────────────────────────────────────────────────────────┤
│ doctor introspects after moment 2                                              │
└────────────────────────────────────────────────────────────────────────────────┘
```

`doctor` introspects after moment 2. It inspects the derived target tree, not the text of the manifests.

## ③ Debug Surface

The contract owns three facts that mention no IDE:

1. every debuggable unit has a real binary at `build/<plat>/<arch>/<mode>/<name>`
2. the environment a debugger needs is materialized (an env file or a variable set)
3. there is a target inventory classifying each unit (native / python / ros-node)

An IDE adapter is then only a **projection** of those facts:

| IDE | Insight | Build | Debug |
|---|---|---|---|
| **VS Code (v0.1 first-class)** | `xmake-vscode`, 33 settings | must go through the pinned Xmake | `xmake.customDebugConfig` injection, plus generated `launch.json` for what the extension cannot express |
| CLion / IntelliJ (deferred) | `xmake-idea` plugin, or `xmake project -k cmake` | must go through Xmake; the generated CMake is hollow for bridged targets | capability unverified; fallback is a custom run configuration pointing at the pre-built binary |
| Anything else | `xmake project -k compile_commands --lsp=clangd` | Xmake | documented manual recipe |

**How the IDE gets the pinned engine.** `xmake-vscode` resolves the executable from `PATH` by default, so an unconfigured IDE silently escapes the pin. Two mechanisms are used together:

- **M1** — launch the editor inside the environment (`pixi run code .`). Zero configuration, but it depends on a habit, and opening the editor normally silently re-opens the hole.
- **M2** — set `"xmake.executable"` to the environment's Xmake. Survives any launch method. Whether this setting expands `${workspaceFolder}` is **unverified**; if it does not, only an absolute path works and portability is lost.

`doctor` must therefore assert that the IDE-visible toolchain is the pinned one, converting M1's silent failure into a loud check.


The three facts and their single projection:

```
┌ debug surface ─────────────────────────────────────────────────────────────────────┐
│ contract facts (IDE-agnostic)                       ->  projection                 │
├────────────────────────────────────────────────────────────────────────────────────┤
│ 1 build/<plat>/<arch>/<mode>/<name>                  VS Code: xmake.executable     │
│ 2 debug environment (env file / variable set)            + customDebugConfig       │
│ 3 target inventory (native / python / ros-node)      others : compile_commands     │
├────────────────────────────────────────────────────────────────────────────────────┤
│ CLion deferred; xmake-idea DAP ability unverified                                  │
└────────────────────────────────────────────────────────────────────────────────────┘
```

## ④ The Reproducibility Boundary

Every build-affecting input has exactly one home:

| Input | Declared in | Pinned by | Cache |
|---|---|---|---|
| Toolchains, CMake, Ninja, ROS, and Xmake itself | `pixi.toml` | `pixi.lock`, **committed** | `.pixi/` |
| The PolyOrch helper surface (D16; retires the addon row) | consumer `CMakeLists.txt`: `add_subdirectory(PolyOrch)` | the consumer repo's gitlink / checkout pin, **committed** | the consumer's build tree |
| Package sources (vcpkg / conan) | `xmake.lua`: `add_requires(...)` | **open, O4**: currently global tool config, which violates invariant 1 | — |

The same three layers, with the open holes called out:

```
┌ reproducibility boundary ──────────────────────────────────────────────────────┐
│              declared          pinned by           cache                       │
├────────────────────────────────────────────────────────────────────────────────┤
│ toolchains   pixi.toml         pixi.lock           .pixi/                      │
│ helpers      CMakeLists.txt    gitlink/checkout    build tree                │
│              add_subdirectory( )                                               │
│ packages     xmake.lua         OPEN (O4)           -                           │
│              add_requires(..)                                                  │
├────────────────────────────────────────────────────────────────────────────────┤
│ ^ one invariant-1 hole remains: package sources (O4) -- D6 retired by D16      │
└────────────────────────────────────────────────────────────────────────────────┘
```


The environment layer is a declaration file plus a committed lock, with a git-ignored per-user cache behind it; `pixi run` installs the environment when required. The helper surface needs no such layer (D16): it is consumed from the repository checkout itself, so **no per-repository bootstrap script exists** and no addon-install mechanism exists either.

One invariant-1 hole remains. (1) **Package sources (O4)**: vcpkg/conan pinning is still a global tool setting. (The former second hole, **addon version drift (D6)**, retired with the addon form by D16: nothing is installed, so nothing can shadow.) Pixi itself is a documented one-time machine prerequisite, not a per-repository file.

A **consumer** project follows the same three layers, and its dependency on PolyOrch is the second row. Section 10 covers the three ways to declare that dependency and the two development loops behind it.

## ⑤ Bridge Status and v0.1 Priority

| Bridge | Prototype state | v0.1 |
|---|---|---|
| **cargo** | implemented, `third_party/fastsum/` | refine |
| **cmake** | implemented, `third_party/fastmath/` | refine |
| **pixi** | implemented, `third_party/faststats/` | refine |
| **npm** | **inline rule only** (`src/ui_web/xmake.lua`); no `third_party/` sample exists | **build**: the main new work |
| meson | implemented, `third_party/fastvec/` | deferred |
| ros / colcon | implemented, `third_party/turtle_follow/` | deferred |
| vcpkg | package source only (`add_requires`) | define the declaration and pinning rule |
| conan | package source only (`add_requires`) | define the declaration and pinning rule |

The risk this table exposes: the prototype's most-refined bridges (cmake, ros) are the least needed by the largest candidate repositories, while the bridge those repositories do need (npm) is the least developed.

## Open Decision Points

| # | Question | State |
|---|---|---|
| O1 | Which real repository is the validation target? | **decided 2026-09-20 (D10)**: the sibling polyglot monorepo whose working tree currently hosts this checkout — selected by the user. Its identity is recorded only in the git-excluded plan zone (C6), never named in formal documents. Selection criteria it meets: workspace-scale cargo build as the native authority, a multi-feature Pixi environment, and the `bootstrap.*` + `pixi.*` + launcher trio being replaced. Zero FIELD coverage there: the npm bridge shipped since D29 (cargo/cmake/pixi/npm — all four bridges now have code and repo-proven tests) but the validation target has not consumed it yet; third-party CMake dependencies and vcpkg/conan usage likewise remain unvalidated by this choice |
| O2 | Does `xmake-idea` actually provide DAP native debugging, and from which CLion version? | **unverified**. The plugin's existence is confirmed; the whitepaper's debugging claim is not. The vendored corpus has zero matches for `xmake-idea` or DAP, so the claim should be removed or annotated |
| O3 | ~~What is the exact syntax for a project to declare an addon?~~ | **resolved**: `add_addons("<name> [<range>]")` plus a committed `xmake-addons.lock`. Xmake auto-installs missing addons on project load |
| O4 | Can vcpkg and conan themselves be brought inside Pixi? | **narrowed 2026-09-20**: consuming them **as Xrepo package sources is confirmed** (`xrepo install vcpkg::zlib`, `conan::zlib/1.2.11`). The open half is bringing them inside a **Pixi-managed environment**; Pixi appears nowhere in the vendored corpus. Still the last invariant-1 violation |
| O5 | Does `xmake.executable` expand `${workspaceFolder}`? | **narrowed 2026-09-20**: neither is documented anywhere, and the documented knob for pinning a project-local binary is `XMAKE_PROGRAM_FILE` (plus `XMAKE_PROGRAM_DIR`). Re-verify against `xmake-vscode` itself, then pick D7's mechanism |
| O6 | When do Windows and Linux enter scope? | **reopened 2026-09-20 (D10)**: the selected validation host is Linux/x86_64, so the prototype's macOS-only scope cannot hold; Linux enters scope at first experiment contact. Windows stays out of v0.1 |
| O7 | What is the scope of the repository merge? | not defined |
| O8 | What happens to the whitepaper's unsupported claims? | open; covers the Guild entry (PIT-2) and the CLion/DAP assertion, which is tracked as O2. See `status.md` |
| O9 | Does the contract's uniform-binary-path fact survive a native ecosystem whose output directory cannot be relocated without transcribing? | **RULED 2026-09-22 (D17, supersedes the D10 candidate and its 'first experiment round' timing)**: invariant 2 always governed *configuration*, not artifact bytes; staging copies of native outputs into standard directories is permitted. The uniform path is a layout convention for engine-managed outputs; debug metadata may carry the native build path. `modules/01-contract.md` amended in the same commit |

### Ruled: the CMake experiment surface's default Rust toolchain (2026-09-22, D15)

The design-baseline CMake helpers' rust face defaults to the toolchain the
`PATH` provides (or an explicitly injected executable pair --
`PolyOrch_RUST_CARGO_EXECUTABLE` / `PolyOrch_RUSTC_EXECUTABLE`): the default
toolchain is deliberately **not pinned** by any repository file. This is an
explicit exemption to invariant 1 and D4 for this surface only, registered
here per D15: pinning or switching a toolchain is a runtime / environment
concern (a rustup override, a shell, an environment manager), not a fact the
bridge invents. The pixi route of the same helpers stays as (a) one coverage
test proving the explicit-environment route works and (b) the seed of the
deferred phase-D global toolchain switcher, which is where pinning will
re-enter as an explicit user choice.

## Superseded From The Whitepaper

- **Xmake's dual role** is resolved empirically. The prototype generated the CMake project, so Xmake is the substrate while CMake is an output or a dispatch target. The earlier "Open Architecture Questions" section of this document is superseded by the invariants above.
- **PolyOrch's own implementation language and delivery form** is decided by D16 (2026-09-22; D3 amended 2026-09-23): the CMake helper surface is the v0.1 deliverable, consumed by plain `include()` / `add_subdirectory()`. The earlier "Lua, delivered as an Xmake addon" ruling is RETIRED, not deferred.
- **A per-repository `bootstrap.sh`, and a `.repos/` checkout directory, were both considered and dropped.** Either would reintroduce one duplicated file per repository, which is the disease being cured. The helper surface plus committed lockfiles removes the need for both (the pre-D16 phrasing "declared addons plus a committed lock" was the same argument under the retired addon form).

## Related Documents

- [`./whitepaper.md`](./whitepaper.md) — the frozen v1.0 record (authority is federated, C2; its delivery claims superseded by D16)
- [`./modules/00-overview.md`](./modules/00-overview.md) — module reference index
- [`./reference/README.md`](./reference/README.md) — profiles of the 12 related projects
- [`./adapters.md`](./derived/adapters.md) — the product-level adapter description
- [`./cli.md`](./derived/cli.md) — command surface and configuration file shapes
- [`./outline.md`](./derived/outline.md) — goals, non-goals, and proposed milestones
