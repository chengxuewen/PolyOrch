# PolyOrch Documentation Hub

> This document serves as the index and reading entry point for the PolyOrch documentation library. `whitepaper.md` is the frozen v1.0 record; authority is federated across the documents below.

> **A scalable build orchestrator for polyglot monorepos.**
>
> *Adapter-based integration for heterogeneous build systems, environments, and package managers.*
>
> **面向多语言 monorepo 的可扩展构建编排器。**

---

## Doc Map

| Doc | Description |
| :--- | :--- |
| [Whitepaper](./whitepaper.md) | **Frozen v1.0 record** -- the historical snapshot for brand naming, historical decisions, system architecture, and technical positioning. Not the working authority |
| [This index](./README.md) | Documentation index, navigation table, and reading paths for three audience types |
| [Architecture Design](./architecture.md) | Design baseline: invariants, layered view, data flow, debug surface, reproducibility boundary, bridge priority, and open decisions |
| [Module Reference](./modules/00-overview.md) | Internals reference: the contract, dependency and development workflow, error model, and testing strategy |
| [Adapters](./derived/adapters.md) | CMake / Xmake / Meson / Colcon adapter details and IDE debugging |
| [Environment & Dependencies](./derived/environment.md) | Pixi environment management and vcpkg / Conan / Xrepo dependency unification |
| [CLI](./derived/cli.md) | `polyorch` command reference and `polyorch.toml` / `xmake.lua` configuration examples |
| [Naming](./derived/naming.md) | Naming origin, naming rules, historical decisions, and positioning convergence |
| [Competitive Analysis](./derived/competitive-analysis.md) | Full benchmarking against Bazel / Buck2 / Pants / moon / Aster / Guild / colcon |
| [Project Outline](./derived/outline.md) | Goals / Non-Goals, layer breakdown, doc map, and milestones (proposed) |
| [Reference Profiles](./reference/README.md) | Externally-sourced profiles of 12 related projects (build orchestrators, build engines, environment/packaging managers). A research zone, bound by C2's sourcing rule |

**Authority note**: authority is federated -- each document answers for its own subject, and `whitepaper.md` is the frozen v1.0 record rather than the arbiter of product facts. The directory a document lives in states its class: `derived/` is the working product surface, `modules/` together with `architecture.md` is the design baseline (decisions, invariants, and empirically verified findings), and `reference/` is externally sourced. This directory's root holds only three anchors: this hub, the record, and the design baseline. **Every document must source its external facts** -- see `.agents/memorys/conventions.md` C2.

---

## Reading Paths

| Reader | Suggested order | Purpose |
| :--- | :--- | :--- |
| Newcomer (what is this project?) | Whitepaper → Naming → CLI → (optional) Environment & Dependencies → (optional) Competitive Analysis | Quickly build a holistic understanding of PolyOrch's positioning and usage |
| Architect (evaluating system design) | Whitepaper → Architecture Design → Adapters → Environment & Dependencies → Competitive Analysis → Project Outline | Evaluate the layered architecture, adapter mechanism, and open questions |
| Contributor (joining development) | Whitepaper → Architecture Design → CLI → Adapters → Project Outline (milestones proposed) → Environment & Dependencies | Master the architectural constraints and proposal scope that implementation depends on |

---

> **PolyOrch: A scalable build orchestrator for polyglot monorepos.**
