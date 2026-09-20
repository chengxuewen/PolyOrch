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
| Git | `main`, 1 commit (`53daae9`, 2026-09-20); clean tree |

## Phase

`P2 — design landed`. Whitepaper v1.0, 12 verified project profiles, the architecture design baseline (`docs/architecture.md`), and the module reference (`docs/modules/`) are in place; no source tree yet (no `xmake.lua`, no `pixi.toml`, no addon payload).

## Modules

_none — no source code yet_

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

## Open Items

- [ ] **Pick the M3 validation repository** -- recommended MediaServo; see `docs/architecture.md` O1
- [x] **O3 RESOLVED** (2026-09-20) -- project-level addon declaration confirmed: `add_addons("<name> <range>")`, resolved versions pinned in `xmake-addons.lock`, registry at `~/.xmake/addons/addons.conf`; see `decisions.md` D6
- [ ] **O2 -- a decision, not a verification.** The whitepaper's `xmake-idea`/DAP claim found **no support**: zero matches for `xmake-idea`, DAP or `launch.json` across the vendored corpus, whose only VS Code debug path debugs Xmake's own Lua. Remove or annotate the claim in `docs/whitepaper.md`
- [ ] **O4 -- narrowed.** vcpkg/conan **as Xrepo package sources is confirmed** (`xrepo install vcpkg::zlib`, `conan::zlib/1.2.11`); the open half is bringing them **inside a Pixi-managed environment** -- Pixi is mentioned nowhere in the corpus. This is the last violation of the D4 pinning invariant
- [ ] **O5 -- reframed.** `xmake.executable` / `${workspaceFolder}` is documented nowhere; the documented knob for pinning a project-local binary is `XMAKE_PROGRAM_FILE` (plus `XMAKE_PROGRAM_DIR`). Verify against `xmake-vscode` itself, then pick D7's mechanism
- [ ] **Decide the addon-version detection mechanism** for `doctor` -- no runtime version accessor is documented, and the addon version lives in the xmake-repo recipe/tag, not `addon.lua`. Open in `decisions.md` D6 and `docs/modules/03-error-model.md`
- [ ] **Review the whitepaper's unsupported claims** -- Guild (PIT-2) and the CLion/DAP assertion (reinforced by the O2 finding above)
- [ ] **Fill the openspec coverage gap** — PolyOrch ships `apply-change` / `archive-change` / `sync-specs` but no `explore` / `propose` / `verify`. Generate them from the `openspec` CLI, their canonical author, rather than porting a drifted sibling copy; see D9
- [x] **`doc-audit` PORTED** (2026-09-20) — re-authored in English from the VisiaEngine copy and rebound to this repository's documents and `C` / `D` / `PIT` numbering; see D9
- [ ] Add the source tree
- [ ] Build `scripts/` and real project verification commands

## History

MediaServo-era memory (through 2026-08) was **removed** from PolyOrch on 2026-09-18 — no in-repo copy is kept. Source of truth remains the `DEVSYS/MediaServo` repository.
