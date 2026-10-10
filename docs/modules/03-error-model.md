# Error Model

> Part of the [module reference](./00-overview.md).


| Failure | Policy | Why |
|---|---|---|
| Optional native tool absent (meson, colcon) | **degrade**: the bridge becomes a no-op with an explicit warning; `doctor` reports "degraded" | a repository must not fail to configure because one optional toolchain is missing |
| Toolchain source is wrong (a globally installed Xmake used instead of the pinned one) | **fail hard** | the dangerous case: it silently produces trustworthy-looking artifacts from an untrustworthy toolchain |
| Contract violation (naming collision, an xmake file inside `third_party/`, wrong artifact path) | `doctor` errors and names the clause | backed by violating fixtures |
| Addon version drift (a local dev install shadows the pinned version) | **dormant (D16, 2026-10-10 note)** -- the addon form is retired; `doctor`'s detection question applies only if that form returns (see D6 revision note) | the shipped CMake surface installs nothing, so nothing can shadow (see `docs/architecture.md` invariants-1 note) |
| A bridge name collides with a generator-emitted name | the naming rule is part of the contract; `doctor` checks uniqueness | a real collision already cost time in the prototype |
| Xmake absent | `pixi run` installs the environment, which carries Xmake | Pixi is a one-time machine prerequisite, documented once rather than repeated per repository |

## Related documents

- [`./04-testing-strategy.md`](./04-testing-strategy.md)
- [`../architecture.md`](../architecture.md)
