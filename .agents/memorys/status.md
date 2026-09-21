# PolyOrch — Status

> Loaded into `instructions[]` on every turn. Keep it short — detail belongs in `decisions.md` / `pitfalls.md`.

## Project

| Field | Value |
|---|---|
| Name | PolyOrch |
| Path | `DEVSYS/PolyOrch` |
| Domain | Polyglot monorepo build orchestration |
| Brand / CLI | `PolyOrch` / `polyorch` |
| Official acronym | **PBOS** (Polyglot Build Orchestration System) |
| Stack | PolyOrch itself: **Lua**, shipped as an Xmake addon (D3). Integration: Xmake (engine) / Pixi (environment) / vcpkg · Conan via Xrepo (package sources, not bridges) |
| Vendored deps | `.agents/skills/xmake-*` / `xrepo-*` -- 58 Xmake agent skills (Apache-2.0, pinned commit `ef67caa`). See `XMAKE-ATTRIBUTION.md` |
| Language policy | **English for all artifacts.** Chinese only for AI chat and plan docs under `.omo/` — see C4 |
| Git | `main`; docs-first history through `f04c1fb`, cmake surface committed 2026-09-21 |

> Working-copy location is intentionally not stated in this file (C6); see D10 and the git-excluded plan zone.

## Phase

`P2 — design landed`. Whitepaper v1.0, 12 verified project profiles, the architecture design baseline (`docs/architecture.md`), and the module reference (`docs/modules/`) are in place. A CMake helper surface has landed in-tree (`cmake/`, `scripts/`, `tests/`, `examples/`); the D3 product form (Lua in an Xmake addon) has NOT yet consumed it -- see Open Items.

## Modules

| Module | What |
|---|---|
| `cmake/PolyOrchPixiHelpers.cmake` | single pixi module (~1500 lines, D12): find / tool_ensure / tool_install / install / env_target / env_paths / activate_script / scripts_install / setup / report / bootstrap + manifest-mutating actions |
| `cmake/PolyOrchOptionHelpers.cmake` | `polyorch_option` + expression helpers |
| `cmake/PolyOrchRustHelpers.cmake` | rust module (D13): setup(FROM system\|pixi) / build / test / run / clean, triple-family artifact naming, isolated cargo target dir, FOLDER on all four, TARGET-vs-artifact-name guard (PIT-13) |
| `scripts/` | activation trio `pixi.sh` / `pixi.bat` / `pixi.ps1`; installed beside `.pixi/` via `COPY_SCRIPTS` |
| `examples/` | pixi-bootstrap (`cmake -P`), pixi-configure, pixi-workspace; each also a `PolyOrchExample*` target |
| `tests/` | `run.sh` driver + CTest registration; 14 `cmake -P` cases (markers shared) |

## Verification

| Check | Command | Result |
|---|---|---|
| opencode config parses | `python3 -m json.tool .opencode/opencode.json > /dev/null` | pass (2026-09-18) |
| no domain leakage into toolchain | `grep -rliE -e mediaservo -e mediasoup -e webrtc -e 'sfu-' -e msrtc .agents/rules .agents/skills .opencode .omo .gitignore` | empty (2026-09-20; scope now includes the 58 vendored skills) |
| brand / naming layering | see `conventions.md` C1 | pass (2026-09-18) |
| canonical taglines byte-exact | see `conventions.md` C2 | pass (2026-09-18) |
| docs cross-links resolve | see `conventions.md` C3 | pass (2026-09-18) |
| derived-doc set classified | see `conventions.md` C2 | pass (2026-09-20) |
| English-only artifacts | see `conventions.md` C4 | pass (2026-09-18) |
| vendored Xmake skills unmodified | see `conventions.md` C5 | pass (2026-09-20) |
| design-doc separation (no cross-naming) | see `conventions.md` C6 | pass (2026-09-20) |
| cmake unit suite | `bash tests/run.sh` | pass 13/13 offline; 14/14 with `POLYORCH_TEST_E2E=1` (2026-09-21) |
| CTest registration | `cmake -B <b> -DPolyOrch_BUILD_TESTS=ON && ctest --test-dir <b>` | pass 13/13 (2026-09-21); **blocked standalone** -- root configure FATALs at PlatformSupport mkspec detection without host context (c79c4bf known state) -- re-run under the host or after mkspec fallback lands |
| rust offline suite | `bash tests/run.sh` | pass 21/21 + 2 skip (2026-09-21) |
| rust e2e (real cargo via pixi) | `POLYORCH_TEST_E2E=1 bash tests/run.sh` | pass 23/23, 4.5MB ELF artifact built+verified (2026-09-21) |
| rust-basic umbrella chain | `cmake --build <host> --target PolyOrchExampleRustBasic` | configure(bootstrap env) -> greet-cargo -> run-greet prints `hello, world!` (2026-09-21, clean shell; see PIT-14) |

## Open Items

- [x] **O1 RESOLVED** (2026-09-20, D10) -- validation repository is the sibling monorepo hosting this checkout; identity recorded only in the git-excluded plan zone per C6
- [ ] **O6 REOPENED** (D10) -- the validation host is Linux/x86_64; macOS-only no longer holds, Linux enters scope at first experiment contact
- [ ] **O9 registered** (D10) -- the contract's uniform-binary-path fact collides with a forwarding-only cargo bridge; candidate amendment in `docs/architecture.md` O9; decide at the first experiment round
- [ ] **Prototype not on this host** (D10.4) -- engine and environment manager are not installed and the prototype tree is absent; the first experiment re-implements the cargo bridge from the contract (plan zone S1-S2)
- [ ] **Experiment-field coverage gaps stay open** (D10.3) -- npm bridge and O4 get zero coverage from the validation target; do not treat them as adjudicated
- [x] **O3 RESOLVED** (2026-09-20) -- project-level addon declaration confirmed: `add_addons("<name> <range>")`, resolved versions pinned in `xmake-addons.lock`, registry at `~/.xmake/addons/addons.conf`; see `decisions.md` D6
- [ ] **O2 -- a decision, not a verification.** The whitepaper's `xmake-idea`/DAP claim found **no support**: zero matches for `xmake-idea`, DAP or `launch.json` across the vendored corpus, whose only VS Code debug path debugs Xmake's own Lua. Remove or annotate the claim in `docs/whitepaper.md`
- [ ] **O4 -- narrowed.** vcpkg/conan **as Xrepo package sources is confirmed** (`xrepo install vcpkg::zlib`, `conan::zlib/1.2.11`); the open half is bringing them **inside a Pixi-managed environment** -- Pixi is mentioned nowhere in the corpus. This is the last violation of the D4 pinning invariant
- [ ] **O5 -- reframed.** `xmake.executable` / `${workspaceFolder}` is documented nowhere; the documented knob for pinning a project-local binary is `XMAKE_PROGRAM_FILE` (plus `XMAKE_PROGRAM_DIR`). Verify against `xmake-vscode` itself, then pick D7's mechanism
- [ ] **Decide the addon-version detection mechanism** for `doctor` -- no runtime version accessor is documented, and the addon version lives in the xmake-repo recipe/tag, not `addon.lua`. Open in `decisions.md` D6 and `docs/modules/03-error-model.md`
- [ ] **Review the whitepaper's unsupported claims** -- Guild (PIT-2) and the CLion/DAP assertion (reinforced by the O2 finding above)
- [ ] **Fill the openspec coverage gap** — PolyOrch ships `apply-change` / `archive-change` / `sync-specs` but no `explore` / `propose` / `verify`. Generate them from the `openspec` CLI, their canonical author, rather than porting a drifted sibling copy; see D9
- [x] **`doc-audit` PORTED** (2026-09-20) — re-authored in English from a sibling repository's copy and rebound to this repository's documents and `C` / `D` / `PIT` numbering; see D9
- [x] Source surface landed: single pixi CMake module + scripts + tests + examples (D12)
- [ ] Resolve the D3 vs reality gap: the in-tree surface is CMake; D3 records the implementation as Lua-in-an-Xmake-addon -- amend the decision or fold the CMake modules into the addon plan (doc-audit question)
- [x] Rust helpers landed: dual-route toolchain + build/test/run/clean wrappers (D13); example `rust-basic` lands with the squad's commits; cross-`--target` routing deliberately out of v0 scope
- [ ] **Corrosion capability-gap backlog** (measured against the reference's current code, 2026-09-21): P0 profile<->CMAKE_BUILD_TYPE genex mapping -- `Release` currently still builds cargo `debug` artifacts silently; P0 cross-`--target` routing (deferred by D13; the triple-family naming table is the reserved seam); P1 `NO_DEFAULT_FEATURES`/`ALL_FEATURES` + per-crate RUSTFLAGS/env pass-through hooks (the `-mcet` host-leak of PIT-14 wants this explicit outlet); P1 multi-crate batch import via `cargo metadata`; P2 `polyorch_rust_install()` export rules; P2 Windows cdylib runtime-dll staging next to consumer exes; small: cargo/rustc minimum-version check, package-version exposure. Ahead of the reference: pixi environment routing, IDE FOLDER grouping, configure-time name-collision guard
- [ ] Gate runner in `scripts/` (canonical C1-C6 + suite one-shot)
- [ ] Root README/AGENTS still describe the repo as having no source code -- stale against `cmake/`/`scripts/`/`tests/`/`examples/`

## History

MediaServo-era memory (through 2026-08) was **removed** from PolyOrch on 2026-09-18 — no in-repo copy is kept. Source of truth remains the `DEVSYS/MediaServo` repository.
