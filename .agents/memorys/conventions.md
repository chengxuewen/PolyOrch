# PolyOrch — Conventions

> Loaded into `instructions[]` on every turn. Keep it short.
> Format per `.agents/rules/common/lesson-memory.md`: `C{n}: "<constraint>" + a runnable check command`.
> A convention without a runnable check is not a convention.

## C0: "Constraints must be executable"

Every constraint must carry a concrete command and a pass/fail criterion. "Be careful about X" is not a constraint.

```bash
# Template: replace the placeholders with a real check
test -f .opencode/opencode.json && python3 -m json.tool .opencode/opencode.json > /dev/null && echo "config valid"
```

## C1: "Brand and naming layering"

Brand names and document titles use `PolyOrch` (camel case, showing the Poly + Orch roots); the CLI command, package name, and code import name use `polyorch` (all lowercase); the official acronym is **PBOS** (Polyglot Build Orchestration System). Misspellings such as `Polyorch` / `polyOrch` / `POLYORCH` are forbidden.

```bash
# Scope is the content files: docs/ and the repository-root documents (README.md,
# SKILL.md), plus the future source tree.
# Instruction and rule files (AGENTS.md, .agents/) are NOT scanned: they legitimately
# contain the forbidden literals as counter-examples (see PIT-1).
if grep -rqE 'Polyorch|polyOrch|POLYORCH' docs/ README.md SKILL.md; then
  echo "FAIL: wrong brand casing"; exit 1
else echo "PASS"; fi
```

## C2: "Authority is federated, and every external fact carries a source"

`docs/whitepaper.md` is the **frozen v1.0 record** -- a historical snapshot, not the arbiter of product facts. Authority is federated: each document answers for its own subject.

- **Product surface** -- `docs/derived/` (adapters, cli, environment, naming, competitive-analysis, outline). Authoritative for what PolyOrch is and what it promises.
- **Design baseline** -- `docs/architecture.md` and `docs/modules/`. Authoritative for how it is built. A design document may supersede a statement in the record, but must say so explicitly (see `architecture.md` -> `Superseded From The Whitepaper`). Verified empirical findings live here too -- for example that the Xmake-generated CMake contains no `add_custom_command`, so bridged targets are inert in it.
- **Externally sourced** -- `docs/reference/` is a research zone.

**Every document must source its external facts.** A version number, date, API name, benchmark, licence, or claim about another project either carries `(source: <primary source>, <date>)` or is marked `TBD`. Primary sources only: the project's own repository, official documentation, release notes, changelogs -- not blog posts, listicles, or marketing pages. Unverifiable means unstated.

This replaced the earlier single-source model, in which `whitepaper.md` outranked every other document and the extracted documents could state nothing it did not. That model kept a partly-superseded record load-bearing, and it is what let the record's own unsupported entries survive. The sourcing rule that replaces it is **strictly stronger**, because it demands a traceable primary source rather than a reference to another document: it would have refused the Guild entry (PIT-2) at the point of writing.

```bash
grep -qF 'A scalable build orchestrator for polyglot monorepos.' docs/whitepaper.md || { echo "FAIL: main description missing"; exit 1; }
grep -qF 'Adapter-based integration for heterogeneous build systems, environments, and package managers.' docs/whitepaper.md || { echo "FAIL: subtitle missing"; exit 1; }
grep -qF '面向多语言 monorepo 的可扩展构建编排器。' docs/whitepaper.md || { echo "FAIL: Chinese main description missing"; exit 1; }
# The record must declare itself frozen, or the authority model silently reverts.
grep -qF 'Frozen v1.0 record' docs/whitepaper.md || { echo "FAIL: whitepaper archive status missing"; exit 1; }
# docs/ may hold at its root only three anchors: the hub, the authoritative source, and the
# design baseline. Everything else is classified by the subdirectory it lives in: derived/
# (bound by this convention), modules/ (design), reference/ (externally sourced).
python3 - <<'CHECK'
import pathlib, sys
DOCS = pathlib.Path("docs")
ROOT_ALLOWED = {"README.md", "whitepaper.md", "architecture.md"}
root_actual = {p.name for p in DOCS.glob("*.md")}
stray = sorted(root_actual - ROOT_ALLOWED)
derived = sorted(p.name for p in (DOCS / "derived").glob("*.md")) if (DOCS / "derived").is_dir() else []
mods = sorted(p.name for p in (DOCS / "modules").glob("*.md")) if (DOCS / "modules").is_dir() else []
print("docs/ root:", sorted(root_actual))
print("stray at root:", stray or "none")
print("derived:", derived)
print("modules:", mods)
ok = not stray and derived and "00-overview.md" in mods
sys.exit(0 if ok else 1)
CHECK
echo "PASS"
```

## C3: "docs cross-links must resolve"

Links between documents under `docs/` must be relative (`./x.md`) and their targets must exist.
The scan is recursive, so `docs/modules/` and `docs/reference/` are covered too.

```bash
python3 - <<'PY'
import re, pathlib, sys
bad = []
for md in pathlib.Path("docs").rglob("*.md"):
    for link in re.findall(r"\]\((\./[^)]+\.md)\)", md.read_text()):
        if not (md.parent / link).resolve().exists():
            bad.append(f"{md}: {link}")
print("BROKEN:", bad or "none")
sys.exit(1 if bad else 0)
PY
```

## C4: "English for the machine-consumed surface; Chinese only where nothing loads it"

Every artifact an agent loads or a tool parses is written in **English**: documentation under `docs/`, `.agents/memorys/*`, `.agents/rules/*`, `.agents/skills/*`, configuration comments, and git commit messages. The reason is the one stated below -- a single language removes a translation layer for agents and tooling, and the memory and instruction files are loaded on every turn, so their cost is paid continuously.

Chinese is permitted in three places:

1. **AI chat interaction** — conversation with the user, and prompts/messages to sub-agents.
2. **Plan documents under `.omo/`** — git-excluded working plans (`.gitignore` ignores `.omo/*`, with `.omo/omo.jsonc` re-included as config, which itself is English).
3. **`README_zh.md`** — a Chinese mirror of the repository front door, for human readers. It is deliberately *not* in `instructions[]` and nothing parses it, so it does not pay the cost this convention exists to avoid. `README.md` stays the authoritative version where the two differ, and the mirror covers the same sections.

**Exception — canonical brand strings.** The three canonical descriptions are brand assets rather than prose, and stay byte-exact, including the Chinese one:

- `A scalable build orchestrator for polyglot monorepos.`
- `Adapter-based integration for heterogeneous build systems, environments, and package managers.`
- `面向多语言 monorepo 的可扩展构建编排器。`

```bash
# Only the canonical Chinese brand string may remain in artifacts.
# .omo/ is skipped entirely: it is the Chinese-permitted zone (plans + session state).
# book-to-skill is skipped: vendored third-party code whose Chinese strings are FUNCTIONAL
# DATA (CJK chapter-heading patterns the parser matches), not prose. Translating them breaks
# the parser. Same rationale as excluding node_modules.
python3 - <<'PY'
import re, pathlib, sys
CJK = re.compile(r"[\u4e00-\u9fff]")
ALLOWED = "面向多语言 monorepo 的可扩展构建编排器。"
EXTS = {".md", ".mjs", ".js", ".json", ".jsonc", ".toml", ".sh", ".txt", ".py", ".yaml", ".yml"}
SKIP = {".git", "node_modules", ".omo", "target", ".pixi", "book-to-skill"}
# A single named file, not a pattern: the Chinese mirror of the front door (see rule 3 above).
ALLOW_FILES = {"README_zh.md"}
skip_files = {"package-lock.json"} | ALLOW_FILES
bad = []
for p in pathlib.Path(".").rglob("*"):
    if not p.is_file() or p.suffix not in EXTS or p.name in skip_files:
        continue
    if any(part in SKIP for part in p.parts):
        continue
    for i, line in enumerate(p.read_text(errors="ignore").splitlines(), 1):
        if CJK.search(line) and ALLOWED not in line:
            bad.append(f"{p}:{i}")
print("CJK outside allowed zones:", bad or "none")
sys.exit(1 if bad else 0)
PY
```

## C5: "Vendored third-party skills stay byte-identical to their pinned upstream commit"

`.agents/skills/xmake-*` and `.agents/skills/xrepo-*` are a vendored third-party set
(`xmake-io/xmake-skills`, commit `ef67caa`, Apache-2.0). They are copied verbatim and are **not**
part of the generic port. A local edit silently becomes an unstated modification under
Apache-2.0 section 4(b), so such an edit must be impossible to make by accident.

```bash
# Run from the repository root. Offline; 58 entries expected.
cd .agents/skills && python3 - <<'CHK'
import hashlib, pathlib, sys
bad = []
for line in pathlib.Path("XMAKE-MANIFEST.sha256").read_text().splitlines():
    digest, rel = line.split("  ", 1)
    p = pathlib.Path(rel)
    if not p.is_file(): bad.append("MISSING " + rel)
    elif hashlib.sha256(p.read_bytes()).hexdigest() != digest: bad.append("MODIFIED " + rel)
print("vendored drift:", bad or "none")
sys.exit(1 if bad else 0)
CHK
```

A `MODIFIED` entry means vendored content was edited. Either revert it, or record the change in
`.agents/skills/XMAKE-ATTRIBUTION.md` and regenerate the manifest.


## C6: "The two sibling projects' design documents never name each other"

PolyOrch and its validation target are separate products whose architecture and design records
evolve independently. No formal artifact (everything under `docs/` and `.agents/`, plus the
root documents) may contain the other project's **name**. A formal document may describe the
validation target by *criteria* (workspace-scale cargo build, multi-feature Pixi environment,
the bootstrap trio) but never by name. The join — which repository was chosen, what the
experiments found against it — is recorded only in git-excluded plan documents under
`.omo/plans/`. Rationale: user directive, 2026-09-20 — a name-link in either direction
couples two independent revision histories and leaks one project's status into the other's
design record.

```bash
# The pattern is bracketed so this file does not self-match (PIT-1).
if grep -rilE '[Vv]isia[E]ngine' docs/ .agents/ AGENTS.md README.md README_zh.md SKILL.md; then
  echo "FAIL: cross-project name leaked into a formal document"; exit 1
else echo "PASS"; fi
```