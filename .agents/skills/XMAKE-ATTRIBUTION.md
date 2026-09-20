# Attribution — Xmake Agent Skills (vendored third party)

Content in this directory is **not authored by PolyOrch**. It is copied verbatim from the
Xmake project's own agent-skill bundle.

| Field | Value |
|---|---|
| Project | `xmake-skills` |
| Source | https://github.com/xmake-io/xmake-skills |
| Publisher | `xmake-io` (the Xmake project) |
| Pinned commit | `ef67caa46353af102a9914a82bfed93f952ca8aa` |
| Commit date | 2026-08-24 |
| Vendored on | 2026-09-20 |
| License | Apache-2.0 — full text in `XMAKE-LICENSE.txt` |
| Skills vendored | 58 |

## Modifications

**None to file content.** The only change is the directory layout: upstream stores each
skill at `skills/<category>/<name>/SKILL.md`; here it is `.agents/skills/<name>/SKILL.md`,
with the category level dropped so the flat skill loader in use discovers it. Frontmatter
is byte-identical and every `name` still equals its directory name.

## Deliberately not vendored

Repo-root files carrying Chinese prose, irrelevant to a skill consumer: `README.md`,
`README_zh.md`, `CONTRIBUTING.md`. Also excluded: `package.json`, `.claude-plugin/`,
`.dsh-plugin/` (a DeepSeek Harness bundle, unused by this project).

## Category map — for re-sync

Upstream groups the skills into 12 categories; the flat layout drops that level. Use this
table to diff against a newer upstream commit.

| Category | Skills |
|---|---|
| ai | xmake-harness |
| basics | xmake-basics, xmake-style, xmake-templates |
| cli | xmake-commands, xmake-introspection, xmake-project-generator, xmake-trybuild |
| languages | xmake-csharp, xmake-cuda, xmake-dlang, xmake-fortran, xmake-go, xmake-kotlin, xmake-nim, xmake-objc, xmake-pascal, xmake-rust, xmake-swift, xmake-vala, xmake-zig |
| ops | xmake-dev, xmake-env-vars, xmake-theme, xmake-troubleshooting |
| packages | xmake-debug-package-source, xmake-network, xmake-private-packages, xmake-repo-testing, xrepo-cli, xrepo-env |
| packaging | xmake-xpack |
| performance | xmake-build-cache, xmake-build-optimization, xmake-distributed-compilation, xmake-remote-compilation |
| project-config | xmake-feature-check, xmake-link-order, xmake-options, xmake-packages, xmake-policy, xmake-rules, xmake-targets |
| scripting | xmake-addon-development, xmake-addons, xmake-async-jobs, xmake-color-output, xmake-custom-plugins, xmake-graph-module, xmake-plugins, xmake-script-modules, xmake-scripting |
| testing | xmake-tests, xmake-unit-tests |
| toolchains | xmake-cross-compilation, xmake-cxx-modules, xmake-toolchains, xmake-zigcc |

## Re-sync procedure

```bash
git clone --depth 1 https://github.com/xmake-io/xmake-skills.git /tmp/xmake-skills
python3 - <<'SYNC_PY'
import pathlib, shutil
src = pathlib.Path("/tmp/xmake-skills/skills")
dst = pathlib.Path(".agents/skills")
for p in src.glob("*/*/SKILL.md"):
    out = dst / p.parent.name / "SKILL.md"
    out.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(p, out)
SYNC_PY
```

Then update the pinned commit above and re-run the repository gates.

## Rejected alternative

Nesting under `.agents/skills/xmake/<category>/<name>/SKILL.md` was rejected: the installed
skill loader iterates only the **immediate** children of a skills root looking for
`SKILL.md`, so a category directory is silently skipped. The flat layout matches the loader
that is actually in use.
