# PolyOrch Skills Registry

The skills available to agents working in this repository, in two layers.

> Not loaded as a skill itself — the skill loader scans the child directories of a
> skills root, and this file sits at the repository root. It is a registry, not a skill.

## Layer 1 — Plugin skills (not versioned with this repository)

Loaded by the plugins declared in `.opencode/opencode.json` → `plugin`. Generic
methodology, applicable to every project, so this file does not enumerate them.

| Plugin | Provides |
|---|---|
| `superpowers` | Brainstorming, planning, TDD, systematic debugging, code review, git worktrees |
| `ponytail` | Over-engineering review, and the lazy-solution discipline |
| `oh-my-openagent` | The OMO orchestration layer |
| `context-mode` | Sandboxed context processing and an indexed knowledge base |

## Layer 2 — Project skills (`.agents/skills/`, versioned with this repository)

Two groups: the nine authored for this repository, and a vendored third-party set.

### 2a. Authored here (9)

| Skill | Type | What it does |
|---|---|---|
| `think-before-act` | Meta-constraint | Investigate before acting; present options for approval |
| `skill-router` | Meta-constraint | Analyze intent and recommend a skill set |
| `ecosystem-scan` | Meta-constraint | Audit `.agents/` and scan for adoptable skills |
| `lesson-review` | Memory | Batch session review; write lessons into `.agents/memorys/` |
| `book-to-skill` | Documentation | Convert books and documents into structured skills |
| `doc-audit` | Documentation | Audit the documents and `.agents/` for consistency, decision liveness, and gaps |
| `openspec-apply-change` | Specification | Implement tasks from an OpenSpec change |
| `openspec-archive-change` | Specification | Archive a completed change |
| `openspec-sync-specs` | Specification | Sync delta specs into the main specs |

### 2b. Vendored third party (58)

The `xmake-*` and `xrepo-*` skills are the Xmake project's own agent-skill bundle.
**They are not authored here and are not part of the generic toolchain port.** They
are copied verbatim from `xmake-io/xmake-skills` at commit `ef67caa` (Apache-2.0).

| | |
|---|---|
| Provenance, and the 12-category map | `.agents/skills/XMAKE-ATTRIBUTION.md` |
| License text | `.agents/skills/XMAKE-LICENSE.txt` |
| Integrity check | `.agents/skills/XMAKE-MANIFEST.sha256` (convention C5) |

Coverage: addon / plugin / rule authoring, Lua scripting, package management and
Xrepo, toolchains and cross-compilation, testing, build performance, and 13
non-C/C++ languages. Load one whenever a task touches Xmake itself — which, for this
project, is most of them.

## Division of labour

| Layer | Location | Nature |
|---|---|---|
| Rules | `.agents/rules/` | Permanent constraints; some load on every turn (see `.opencode/opencode.json` → `instructions`, 16 entries) |
| Memory | `.agents/memorys/` | Mutable facts — the `C` / `D` / `PIT` numbering systems |
| Skills | this file | On-demand deep workflows |

Agents activate a skill automatically from its `SKILL.md` frontmatter `description`.
There is no manual invocation.
