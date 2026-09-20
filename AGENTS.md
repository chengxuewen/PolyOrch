# PROJECT KNOWLEDGE BASE

**Generated:** 2026-09-18
**Commit:** `53daae9` — initial commit (2026-09-20)
**Branch:** main

## OVERVIEW

PolyOrch — a scalable build orchestrator for polyglot monorepos, providing adapter-based
integration for heterogeneous build systems, environments, and package managers.

**This repository contains NO source code.** It is docs-first: the deliverable is the v1.0
specification plus an agent toolchain. Do not hunt for `src/`, `crates/`, or a build entry
point — none exist. The integration stack it *describes* (Xmake / Pixi / vcpkg / Conan) is the
subject matter, not a local dependency.

## STRUCTURE

```
PolyOrch/
├── README.md      # repository front door
├── SKILL.md       # skills registry (plugin layer + project layer)
├── LICENSE        # Apache-2.0
├── AGENTS.md      # agent knowledge base — loaded every turn
├── docs/          # whitepaper.md (frozen v1.0 record) + architecture.md (design baseline)
│   ├── derived/   # derived docs: adapters, cli, environment, naming, competitive-analysis, outline
│   ├── modules/   # internals reference
│   └── reference/ # externally sourced profiles of 12 related projects
├── .agents/
│   ├── memorys/   # status / conventions / decisions / pitfalls — loaded every turn
│   ├── rules/     # common + 12 languages + web; ported, generic-only
│   └── skills/    # 9 generic + 58 vendored xmake-*/xrepo-* (book-to-skill is vendored Python)
├── .opencode/     # opencode config + 5 MCP launcher scripts (.mjs)
├── .omo/          # OMO agent config
└── package.json   # single devDependency: @colbymchenry/codegraph
```

## WHERE TO LOOK

| Task | Location | Notes |
|---|---|---|
| What PolyOrch *is* | `docs/derived/` | the working product surface; `docs/whitepaper.md` is the frozen v1.0 record, not the arbiter |
| Architecture, layers, dataflow | `docs/architecture.md` | design baseline: invariants, sections ①-⑤, and the open decision points |
| Adapters (CMake/Xmake/Meson/Colcon) | `docs/derived/adapters.md` | the core differentiator |
| CLI + config file shapes | `docs/derived/cli.md` | `polyorch.toml`, `xmake.lua` |
| Naming, PBOS, rejected candidates | `docs/derived/naming.md` | |
| Competitors / differentiation | `docs/derived/competitive-analysis.md` | |
| Roadmap | `docs/derived/outline.md` | milestones are PROPOSALS, not commitments |
| Current project state | `.agents/memorys/status.md` | |
| Binding rules + runnable checks | `.agents/memorys/conventions.md` | |
| Why decisions were made | `.agents/memorys/decisions.md` | |
| Known traps | `.agents/memorys/pitfalls.md` | |

## CONVENTIONS

Deviations that actually bind here. Runnable checks live in `.agents/memorys/conventions.md`.

- **All artifacts are English** — docs, comments, memory, skill files, config comments, commits.
  Chinese is permitted only in AI chat and in plan documents under `.omo/` (git-excluded). See C4.
- **Canonical strings — byte-exact, never retranslate:**
  - `A scalable build orchestrator for polyglot monorepos.`
  - `Adapter-based integration for heterogeneous build systems, environments, and package managers.`
  - `面向多语言 monorepo 的可扩展构建编排器。`
- **`PolyOrch`** (camel, Poly + Orch) for brand/titles; **`polyorch`** (lowercase) for CLI,
  package, and import names. Acronym **PBOS**.
- **Authority is federated.** Each document answers for its own subject; `docs/whitepaper.md` is the frozen v1.0 record, not the arbiter of product facts. Every document must source its external facts -- see C2.
- **Unknowns are marked `TBD`** rather than guessed.
- **Relative links only** between docs (`./x.md`).

## ANTI-PATTERNS (THIS PROJECT)

- **Do not invent facts.** No version numbers, dates, benchmarks, API/trait names, or features
  absent from the whitepaper. Generation enforced this; keep enforcing it.
- **Do not reintroduce MediaServo / mediasoup / WebRTC content.** It was deliberately removed
  (see D1). `.agents/rules/*` must stay domain-neutral and `.agents/skills/*` must stay free of
  that removed domain — a gate checks both. Vendored third-party skills are the one exception, and
  they are named explicitly in `.agents/skills/XMAKE-ATTRIBUTION.md`.
- **Do not write forbidden literals into a directory a gate scans.** A check that scans a file
  which lists its own forbidden patterns self-matches. See PIT-1.
- **Do not treat `docs/derived/outline.md` milestones as agreed scope.** They are proposals.
- **Do not edit before confirmation.** The Execution Gate in
  `.agents/rules/common/development-workflow.md` is binding.

## COMMANDS

There is no build or test system — the project has no code. These are the real gates:

```bash
# brand / CLI naming must be correctly cased
grep -rqE 'Polyorch|polyOrch|POLYORCH' docs/ && echo FAIL || echo PASS

# canonical taglines present byte-exact
grep -qF 'A scalable build orchestrator for polyglot monorepos.' docs/whitepaper.md && echo PASS

# relative doc links resolve
python3 -c "import re,pathlib,sys;bad=[f'{m}:{l}' for m in pathlib.Path('docs').glob('*.md') for l in re.findall(r'\]\((\./[^)]+\.md)\)',m.read_text()) if not (m.parent/l).resolve().exists()];print(bad or 'none');sys.exit(1 if bad else 0)"

# no domain leakage into the toolchain
grep -rliE -e mediaservo -e mediasoup -e webrtc -e 'sfu-' -e msrtc .agents/rules .agents/skills .opencode .omo .gitignore

# English-only artifacts (the canonical Chinese brand string is the sole exception)
python3 -c "import re,pathlib,sys;C=re.compile(r'[\u4e00-\u9fff]');A='面向多语言 monorepo 的可扩展构建编排器。';bad=[f'{p}:{i}' for p in list(pathlib.Path('docs').rglob('*'))+list(pathlib.Path('.agents').rglob('*'))+[pathlib.Path('AGENTS.md')] if p.is_file() and p.suffix in {'.md','.json','.jsonc'} for i,l in enumerate(p.read_text(errors='ignore').splitlines(),1) if C.search(l) and A not in l];print(bad or 'none');sys.exit(1 if bad else 0)"

# opencode config parses
python3 -m json.tool .opencode/opencode.json > /dev/null && echo "config valid"
```

## NOTES

- **macOS case-insensitive filesystem gotcha:** `.agents/rules/common/agents.md` is loaded by
  opencode as `AGENTS.md` for that directory. Renaming or moving it silently changes the
  instructions agents receive.
- **The git state has been misdescribed before — verify it, do not trust memory.** The repository
  now has an initial commit (`53daae9`, 2026-09-20), so `HEAD` exists and `git restore`/`git checkout
  work normally. Before that commit the index was already populated while `HEAD` did not exist, and
  the memory claimed the tree was "everything untracked" while 219 of 223 entries were staged — a
  claim that would have made `git clean -fd` look safe when it would have deleted the four
  genuinely-untracked files. Check `git log` and `git status` before any git recovery action.
- **Both former design blockers are resolved.** (1) PolyOrch's implementation language is
  **Lua**, shipped as an Xmake addon (D3). (2) Xmake is the **engine**, not an adapter — its dual
  role is settled in `docs/architecture.md` under `Superseded From The Whitepaper`.
- **`.agents/rules/` and `.agents/skills/` are ported toolchain, not project opinions.** Only
  `rules/common`, `rules/*` language sets, and 8 generic skills survived the port; 14 domain
  skills and 2 disguised-domain rules (`platform.md`, `docker.md`) were removed. A 9th generic
  skill, `doc-audit`, was ported from a sibling repository later — see `decisions.md` D9.
  Separately, 58 `xmake-*` / `xrepo-*` skills are a vendored third-party set pinned to an upstream
  commit — see `.agents/skills/XMAKE-ATTRIBUTION.md`. They are not part of the port.
