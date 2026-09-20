# Brand Naming

> **Authoritative for brand naming.** The v1.0 record for this topic is whitepaper §2, §3, and §8.3. Records the naming origin, the naming rules, the formal abbreviation, and the historical decisions (rejected candidates, naming strategy shift, positioning convergence).

## Naming Origin (§2.1)

**PolyOrch** is formed from two word roots:

- **Poly** — from **Polyglot**, derived from Greek *poly-* (many) + *glot* (tongue/language), meaning "multilingual."
- **Orch** — from **Orchestration**, meaning "arranging and coordinating."

Combined, **PolyOrch** is pronounced **POL-ee-ork**, accurately conveying the core positioning of "polyglot build orchestration."

## Naming Rules (§2.2)

| Context | Style | Notes |
| :--- | :--- | :--- |
| Brand display / Logo / Doc titles | **PolyOrch** | Camel case, recognizable as Poly + Orch roots |
| GitHub repository name | **PolyOrch** | GitHub repo names are case-insensitive; display preserves camel case |
| CLI command | `polyorch` | All lowercase, consistent with terminal conventions |
| PyPI / npm / crates.io package name | `polyorch` | Package managers require all lowercase |
| Domain name | `polyorch.dev` / `polyorch.io` | Domain names are case-insensitive; register in lowercase |
| Code import name | `polyorch` | Python / Node import names are typically all lowercase |

This layering follows the naming conventions of mainstream projects like CMake / cmake and OpenCV / opencv.

## Formal Abbreviation (§2.3)

**Formal abbreviation**: **PBOS** = Polyglot Build Orchestration System

`PBOS` has no direct conflicts found in the build tooling space, making it suitable for formal documents, academic papers, and technical indexes.

## Historical Decisions (§3)

### 3.1 Naming Exploration Phase

PolyOrch's naming underwent a systematic exploration process, eliminating multiple candidates that had conflicts or semantic inaccuracies:

| Candidate | Full Name | Rejection Reason |
| :--- | :--- | :--- |
| ODESYS | Open Dataflow Engineering System | "Engineering" too broad; "Development" not captured in the abbreviation |
| DOCA | Dataflow-Oriented Control Architecture | Conflicts with NVIDIA DOCA |
| DODA | Dataflow-Oriented Distributed Architecture | A small number of open-source projects in the tech space use this name |
| DODAS | Dataflow-Oriented Distributed Architecture System | Conflicts with CERN DODAS |
| DODDS | Dataflow-Oriented Distributed Development System | Conflicts with the abbreviation for the U.S. Department of Defense Education Activity |
| DDSA | Dataflow Distributed System Architecture | Conflicts with the chemical substance DDSA |
| Polycon | Polyglot Construction | Trademark conflict with a construction materials company |
| Polcon | Polyglot Construction | Conflicts across Polish sci-fi conventions and political science indexes |
| PolyCons | Polyglot Construction | Conflicts with the existing `polycons` framework |
| Foundry | (foundry) | Multiple projects with the same name (blockchain, AI) |
| Loom | (loom) | Already occupied by Shopify's `@shopify/loom` |
| Anvil | (anvil) | Already occupied by the `anvil-build` build system |
| Crucible | (crucible) | Already used for a code generation engine |
| Kiln | (kiln) | Already used for AI orchestration and SystemVerilog tools |

### 3.2 Naming Strategy Shift

After eliminating numerous "descriptive compound words" and "common English words," the naming strategy shifted from **function-descriptive** to **root-combination coinage**. The naming logic of `PolyOrch` mirrors that of `colcon`: take the first few letters of two words and combine them into a short, readable, brand-worthy new word.

| colcon | PolyOrch |
| :--- | :--- |
| **col**lective + **con**struction | **Poly**glot + **Orch**estration |
| Pronounced KOL-kon | Pronounced POL-ee-ork |
| Meta-build tool (ROS 2 ecosystem) | Build orchestrator (polyglot monorepo) |

### 3.3 Positioning Convergence

After the name was settled, the project positioning converged through multiple rounds of discussion to:

> **A scalable build orchestrator for polyglot monorepos.**

This description synthesizes the expression patterns used by mainstream projects in the industry:

| Project | Official Description |
| :--- | :--- |
| Aster | "A build orchestrator for polyglot monorepos." |
| moon | "A Bazel-inspired polyglot build orchestrator." |
| Pants | "A scalable build system for monorepos." |
| Guild | "Rust-native polyglot monorepo orchestrator." |

**PolyOrch** ultimately adopted **"A scalable build orchestrator for polyglot monorepos"** as its formal description, aligning with industry conventions while preserving the project's differentiated positioning in adapter-driven, heterogeneous toolchain integration.

## Naming References (§8.3)

- **colcon**: **col**lective + **con**struction, taking the first few letters of two words, pronounced KOL-kon.
- **Bazel**: Derived from a letter rearrangement of Google's internal tool Blaze; no full form exists.
- **Buck2**: The second generation of Meta's build tool Buck.
- **CMake**: **C**ross-platform **Make**, brand `CMake`, command `cmake`.
- **OpenCV**: **Open** **C**omputer **V**ision, brand `OpenCV`, package name `opencv`.

## Related Docs

- [Whitepaper](../whitepaper.md) (§2, §3, §8.3)
- [Documentation Index](../README.md)
- [CLI](./cli.md) (CLI / package / import name `polyorch`)
- [Competitive Analysis](./competitive-analysis.md) (colcon and other competitor positioning comparisons)
