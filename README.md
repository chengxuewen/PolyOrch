# PolyOrch

> **A scalable build orchestrator for polyglot monorepos.**
>
> *Adapter-based integration for heterogeneous build systems, environments, and package managers.*
>
> **面向多语言 monorepo 的可扩展构建编排器。**

PolyOrch orchestrates a polyglot monorepo — many languages, many build systems, one
build graph — through adapters, so every project keeps its native toolchain while the
repository gains a single entry point for build, run, debug, and introspection.

## Status

**This repository contains no source code.** It is documentation-first: the deliverable
at this stage is the v1.0 specification, plus the agent toolchain that will build it.
There is no `src/`, no build entry point, and no test suite — do not look for one.

| | |
|---|---|
| Phase | Design landed — whitepaper v1.0, architecture design baseline, module reference, 12 project profiles |
| Planned stack | Lua, shipped as an Xmake addon (Xmake as the engine, Pixi for environments) |
| Source tree | not yet added |

The real gates today are the shell checks in `.agents/memorys/conventions.md` (C0–C5);
there is no build or test system to run.

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
scripts/       empty — a planned gate runner
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
