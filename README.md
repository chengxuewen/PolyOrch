# PolyOrch

**English** | [Chinese](./README_zh.md)

> **A scalable build orchestrator for polyglot monorepos.**
>
> *Adapter-based integration for heterogeneous build systems, environments, and package managers.*
>
> **面向多语言 monorepo 的可扩展构建编排器。**

PolyOrch orchestrates a polyglot monorepo — many languages, many build systems, one
build graph — through adapters, so every project keeps its native toolchain while the
repository gains a single entry point for build, run, debug, and introspection.

## Status

**The deliverable is a CMake helper surface plus its test suites** — `cmake/` modules
(pixi environment face, rust face), `tests/` (offline units + fixture e2e + generator
matrix), `examples/`. Documentation remains the specification layer; the whitepaper is a
frozen v1.0 record (see D16 in `.agents/memorys/decisions.md`).

| | |
|---|---|
| Phase | Implementation underway — CMake helper surfaces (pixi environment face, rust face), fixture test suite, local generator matrix; D16 supersedes the old Lua/Xmake-addon delivery form |
| Stack | CMake helper surface; Pixi environments; xmake = reference corpus + package-management source (vcpkg · Conan via Xrepo) |
| Tests | `bash tests/run.sh` (offline) · `POLYORCH_TEST_E2E=1 bash tests/run.sh` · `bash tests/matrix.sh` |

The binding gates are the shell checks in `.agents/memorys/conventions.md` (C0–C6) plus
the cmake test suites above.

## Repository layout

```text
docs/          the specification — start at docs/README.md
  whitepaper.md      the frozen v1.0 record (historical; not the working authority)
  derived/           the working product surface: adapters, cli, environment, naming, competitive-analysis, outline
  architecture.md    design baseline: invariants, layers, data flow, open decisions
  modules/           internals reference
  reference/         externally sourced profiles of 12 related projects
.agents/
  rules/         permanent constraints
  memorys/       mutable facts (status / conventions / decisions / pitfalls)
  skills/        agent skills, including 58 vendored Xmake skills
.opencode/     opencode configuration
scripts/       activation trio (pixi.sh/.bat/.ps1); gate runner planned
AGENTS.md      the agent knowledge base, loaded on every turn
SKILL.md       the skills registry
```

## Where to start

| You are | Read |
|---|---|
| New to the project | [`docs/README.md`](./docs/README.md) — the documentation hub |
| Evaluating the design | [`docs/whitepaper.md`](./docs/whitepaper.md), then [`docs/architecture.md`](./docs/architecture.md) |
| An agent working here | [`AGENTS.md`](./AGENTS.md) — the knowledge base |
| Looking for a skill | [`SKILL.md`](./SKILL.md) — the skills registry |

## License

Apache-2.0 — see [`LICENSE`](./LICENSE).

The 58 `xmake-*` / `xrepo-*` skills under `.agents/skills/` are third-party content
under the same license, vendored from `xmake-io/xmake-skills`; their provenance,
pinned commit, and modification statement are recorded in
[`.agents/skills/XMAKE-ATTRIBUTION.md`](./.agents/skills/XMAKE-ATTRIBUTION.md).
