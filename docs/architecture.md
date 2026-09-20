# PolyOrch Architecture Design

**v0.1 | 2026-09-20** | Input: whitepaper v1.0 + 12 verified project profiles (`docs/reference/`) + the `DEVSYS/xmake` prototype
Status: **design baseline**. Diagrams show the target; current reality is tracked in `AGENTS.md` and `.agents/memorys/status.md`. Decision evolution is recorded in `.agents/memorys/decisions.md` (D1 onward).

---

## Design Invariants (outrank every diagram below)

1. **Anything that affects the build result is pinned in the repository.** No build-affecting configuration may live in a user's global state. This invariant was earned three times over: the build engine came from a global package manager, the IDE resolved the engine from `PATH`, and package-source roots lived in global tool config.
2. **A bridge discovers, derives, and forwards. It never transcribes.** The native manifest is the only source of truth; the xmake targets are a view derived on every configure. There is no persisted second copy.
3. **One build authority.** Xmake builds. Generated CMake / VS / Xcode projects are **insight projections** for IDEs, never a second build path. Verified against the prototype: the generated CMake contains no `add_custom_command` at all, and bridged targets appear as inert `add_custom_target` nodes paired with an empty `add_executable(<name>_bin "")`.
4. **Zero intrusion.** A bridged project directory stays pure native. No xmake file may be written inside it.
5. **Optional absence degrades and complains; a suspicious toolchain source fails hard.** A missing optional toolchain must not break configure. A build that would silently use the wrong toolchain must not proceed.
6. **PolyOrch does not re-implement an engine.** Xmake already owns the dependency graph, cache, toolchain management, and package resolution. PolyOrch owns *how things connect*.

---

## ① Layered View

```
┌ consumer repo ───────────────────────────────────────────────────────────────┐
│ xmake.lua    add_addons("polyorch <range>") . add_requires("vcpkg::...")     │
│ pixi.toml    toolchains + xmake        xmake-addons.lock   pinned addon      │
│ third_party/<name>/<native manifest>                                         │  pure native, zero intrusion
└──────────────────────────────────────────────────────────────────────────────┘
                               |  pixi run xmake
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

The whitepaper's product-level view is a four-layer stack (orchestration / adapter / build engine / environment-dependency). The view above is the implementation form of the same thing: the whitepaper's "adapter layer" and "build engine layer" both resolve to the single Xmake tree, and its "environment and dependency layer" resolves to Pixi plus package-source declarations.

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
| The PolyOrch addon | `xmake.lua`: `add_addons("polyorch <range>")` | `xmake-addons.lock`, **committed** | `~/.xmake/addons/<name>/<version>/` |
| Package sources (vcpkg / conan) | `xmake.lua`: `add_requires(...)` | **open, O4**: currently global tool config, which violates invariant 1 | — |

The same three layers, with the open holes called out:

```
┌ reproducibility boundary ──────────────────────────────────────────────────────┐
│              declared          pinned by           cache                       │
├────────────────────────────────────────────────────────────────────────────────┤
│ toolchains   pixi.toml         pixi.lock           .pixi/                      │
│ addon        xmake.lua         xmake-addons.lock   ~/.xmake/addons/<n>/<v>     │
│              add_addons(..)                                                    │
│ packages     xmake.lua         OPEN (O4)           -                           │
│              add_requires(..)                                                  │
├────────────────────────────────────────────────────────────────────────────────┤
│ ^ two invariant-1 holes: package sources (O4) and addon drift (D6)             │
└────────────────────────────────────────────────────────────────────────────────┘
```


The environment layer and the addon layer are symmetric: a declaration file plus a committed lock, with a git-ignored per-user cache behind it. Xmake **auto-installs declared addons when the project is loaded**, and `pixi run` installs the environment when required. Consequently **no per-repository bootstrap script exists**: a fresh clone needs one command, `pixi run xmake`.

Two invariant-1 holes remain. (1) **Package sources (O4)**: vcpkg/conan pinning is still a global tool setting. (2) **Addon version drift (D6)**: a locally installed working copy can silently shadow the pinned addon, and no detection mechanism is decided. Pixi itself is a documented one-time machine prerequisite, not a per-repository file.

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
| O1 | Which real repository is the validation target? | **recommended: MediaServo**, which carries exactly the `bootstrap.*` + `pixi.*` + launcher trio being replaced |
| O2 | Does `xmake-idea` actually provide DAP native debugging, and from which CLion version? | **unverified**. The plugin's existence is confirmed; the whitepaper's debugging claim is not. The vendored corpus has zero matches for `xmake-idea` or DAP, so the claim should be removed or annotated |
| O3 | ~~What is the exact syntax for a project to declare an addon?~~ | **resolved**: `add_addons("<name> [<range>]")` plus a committed `xmake-addons.lock`. Xmake auto-installs missing addons on project load |
| O4 | Can vcpkg and conan themselves be brought inside Pixi? | **narrowed 2026-09-20**: consuming them **as Xrepo package sources is confirmed** (`xrepo install vcpkg::zlib`, `conan::zlib/1.2.11`). The open half is bringing them inside a **Pixi-managed environment**; Pixi appears nowhere in the vendored corpus. Still the last invariant-1 violation |
| O5 | Does `xmake.executable` expand `${workspaceFolder}`? | **narrowed 2026-09-20**: neither is documented anywhere, and the documented knob for pinning a project-local binary is `XMAKE_PROGRAM_FILE` (plus `XMAKE_PROGRAM_DIR`). Re-verify against `xmake-vscode` itself, then pick D7's mechanism |
| O6 | When do Windows and Linux enter scope? | **resolved for v0.1**: out of scope; the prototype is macOS-only. Revisit after v0.1 |
| O7 | What is the scope of the repository merge? | not defined |
| O8 | What happens to the whitepaper's unsupported claims? | open; covers the Guild entry (PIT-2) and the CLion/DAP assertion, which is tracked as O2. See `status.md` |

## Superseded From The Whitepaper

- **Xmake's dual role** is resolved empirically. The prototype generated the CMake project, so Xmake is the substrate while CMake is an output or a dispatch target. The earlier "Open Architecture Questions" section of this document is superseded by the invariants above.
- **PolyOrch's own implementation language** is decided: Lua, delivered as an Xmake addon.
- **A per-repository `bootstrap.sh`, and a `.repos/` checkout directory, were both considered and dropped.** Either would reintroduce one duplicated file per repository, which is the disease being cured. The native mechanism (declared addons plus a committed lock) removes the need for both.

## Related Documents

- [`./whitepaper.md`](./whitepaper.md) — the authoritative product source, v1.0
- [`./modules/00-overview.md`](./modules/00-overview.md) — module reference index
- [`./reference/README.md`](./reference/README.md) — profiles of the 12 related projects
- [`./adapters.md`](./derived/adapters.md) — the product-level adapter description
- [`./cli.md`](./derived/cli.md) — command surface and configuration file shapes
- [`./outline.md`](./derived/outline.md) — goals, non-goals, and proposed milestones
