# PolyOrch Reference — Project Profiles

> Research zone. This directory is **externally sourced**: it is the one place in `docs/` that may state facts about other projects. The sourcing rule below is the project-wide rule from `.agents/memorys/conventions.md` C2, applied here in its most demanding form — nothing here may rest on the v1.0 record.

## Purpose

Profile documents for the projects PolyOrch relates to: the build orchestrators it competes with,
the build engines it drives or embeds, and the environment and package managers it integrates.

The reason each document exists is its final section: **what PolyOrch should adopt, adapt, or avoid.**

## Layout

| Directory | Covers |
|---|---|
| `research/build-orchestrator/` | Polyglot monorepo build orchestrators (competitors) |
| `research/build-engine/` | Build engines PolyOrch drives or embeds |
| `research/environment-deps/` | Environment managers and C/C++ package managers |

## Profile Template (mandatory)

```markdown
# <Project> Profile

> Sources: <primary URLs>, researched <date>
> Not a derived document: facts here are externally sourced.

## 1. Product Profile
## 2. Technical Characteristics
### Overall Architecture
### Key Capabilities
### Tech Stack
## 3. Feature Overview
### Core Modules
### Notable Features
### Extensibility / Plugin Mechanism
## 4. Status & Ecosystem
## 5. Market Positioning
## 6. Product Highlights
## 7. Value to PolyOrch
### [Adopt] Directly reusable
### [Adapt] Reusable with modification
### [Avoid] Known pitfalls / not applicable
## Appendix (optional deep dives)
```

Length: **300-500 lines**. Section 7 is the reason the document exists. Do not skimp on it.

## Sourcing Rules

1. **Every external fact carries a source and a date**: `(source: https://example.com/doc, 2026-09-18)`. No unsourced version numbers, dates, benchmarks, or licences. This is the project-wide rule stated in `.agents/memorys/conventions.md` C2; the items below say how it applies in this zone.
2. **Primary sources only**: the project's own repository, official documentation, release notes, changelogs. Not blog posts, not listicles, not marketing pages.
3. **Unverifiable means unstated.** If a fact cannot be confirmed, write `TBD` or omit it. Never fill a gap with a plausible guess.
4. **Section 7 must bucket every point** as `[Adopt]`, `[Adapt]`, or `[Avoid]`, and every point must be actionable for PolyOrch specifically.
5. **No em dashes.** Use commas, periods, colons, or parentheses.
6. **English only** (`.agents/memorys/conventions.md` C4). Zero Chinese characters.

## Verified Anchors (researched 2026-09-18)

Starting facts for each profile. Confirm and extend these, but do not contradict them without a newer source.

| Project | Repository | Version | License | Impl language | Config |
|---|---|---|---|---|---|
| Aster | `github.com/ArchAstro/aster` | v0.14.1 (2026-08-28) | MIT | Rust | `aster.toml` |
| moon | `github.com/moonrepo/moon` | v2.5.5 (2026-09-15) | MIT | Rust | `moon.yml`, `.moon/workspace.yml` |
| Pants | `github.com/pantsbuild/pants` | 2.33.1 (2026-08-27) | Apache-2.0 | Python plus a Rust engine | `pants.toml`, `BUILD` files |
| Bazel | `github.com/bazelbuild/bazel` | 9.2.0 (2026-07-13) | Apache-2.0 | Java and C++ | Starlark `BUILD`, `MODULE.bazel` |
| Buck2 | `github.com/facebook/buck2` | date-based, 2026-09-15 | Apache-2.0 AND MIT | Rust | Starlark `BUCK`, `.buckconfig` |
| colcon | `github.com/colcon/colcon-core` | 0.21.3 (2026-09-17) | Apache-2.0 | Python | `package.xml` plus native build files |
| Xmake | `github.com/xmake-io/xmake` | v3.1.1 | Apache-2.0 | C plus Lua | `xmake.lua` |
| CMake | `gitlab.kitware.com/cmake/cmake` (GitHub mirror `github.com/Kitware/CMake`) | 4.4.3 (2026-08-25) | BSD-3-Clause | C/C++ | `CMakeLists.txt`, `CMakePresets.json` |
| Meson | `github.com/mesonbuild/meson` | 1.12.0 (2026-08-10) | Apache-2.0 | Python | `meson.build`, `meson.options` |
| Pixi | `github.com/prefix-dev/pixi` | v0.81.0 (2026-09-15) | BSD-3-Clause | Rust | `pixi.toml`, `pixi.lock` |
| vcpkg | `github.com/microsoft/vcpkg` (tool: `github.com/microsoft/vcpkg-tool`) | rolling, date-stamped: ports 2026-07-29, tool 2026-07-27 | MIT (ported libraries keep their own licences) | C++ (the tool) | `vcpkg.json` manifest, ports, registries |
| Conan | `github.com/conan-io/conan` | 2.32.0 (2026-08-31) | MIT | Python | `conanfile.py`, `conanfile.txt` |

## Index

### `research/build-orchestrator/`

| Profile | Note |
|---|---|
| `aster.md` | Real project; its README tagline matches the whitepaper's wording |
| `bazel.md` | `WORKSPACE` is legacy; the modern dependency system is Bzlmod (`MODULE.bazel`) |
| `buck2.md` | Distinct from the archived first-generation Java `facebook/buck` |
| `colcon.md` | A META build tool: never describe it as a plain build system |
| `moon.md` | |
| `pants.md` | |

### `research/build-engine/`

| Profile | Note |
|---|---|
| `xmake.md` | The `vcpkg::` and `conan::` namespaces are confirmed real (Xmake docs, 2026-09-18) |
| `cmake.md` | |
| `meson.md` | Uses `meson.options`, renamed from `meson_options.txt` in 1.1 |

### `research/environment-deps/`

| Profile | Note |
|---|---|
| `pixi.md` | |
| `vcpkg.md` | |
| `conan.md` | |

## Not Profiled

**Guild.** The whitepaper (§7.1, §8.1) lists "Guild" as a "Rust-native polyglot monorepo orchestrator" with a `guild.toml` config file. This could not be verified on 2026-09-18:

- No repository matching that description was found.
- A public code search for `guild.toml` returned zero hits.
- The name collides with `guildai`, an ML experiment-tracking toolkit in Python.

No profile is written, because writing one would require inventing the project. **The whitepaper's Guild entry is unsupported and should be reviewed or removed.**
