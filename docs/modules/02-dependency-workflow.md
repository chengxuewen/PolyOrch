# Dependency and Development Workflow

> Part of the [module reference](./00-overview.md).


### How a consumer depends on PolyOrch

Three forms, in decreasing order of pinning strength:

| # | Form | Mechanism | For |
|---|---|---|---|
| 1 | **declaration plus lock** | `add_addons("polyorch <range>")` in the consumer's `xmake.lua`; resolved versions committed in `xmake-addons.lock` | production |
| 2 | **own recipe repository** | a recipe repo carrying `addons/p/polyorch/xmake.lua` whose `add_urls` points at the PolyOrch repository, registered with `xmake repo --add` (project-local by default) | before publication |
| 3 | **imperative** | `xmake addon --install <local path | github:owner/repo#ref | https git url>` | CI fallback, one-off |

Payload references from a consumer target:

```lua
add_rules("@addon/polyorch/cmake")
includes("@addon/polyorch/board")
import("@addon.polyorch.graph")
```

**The structural asymmetry that shapes everything below:** `add_addons` accepts only a name plus a version range. `xmake addon --install` additionally accepts a git URL, a git ref, and a local directory. **There is no declarative way to point a project at a working copy.**

### Two development loops

| | Hot loop | Faithful loop |
|---|---|---|
| **Trigger** | edit the PolyOrch source | edit the PolyOrch source, then commit and tag or push a ref |
| **Wiring** | `xmake addon --install <working copy>` | a recipe repo whose `add_urls` points at your git repo, registered with `xmake repo --add` (project-local), then `xmake addon --upgrade` |
| **Latency** | immediate, no commit needed | one commit and one resolve per change |
| **What it exercises** | the payloads only | the real production path: recipe, download, **sha256 verification**, version derivation |
| **Use it for** | day-to-day iteration | anything before a release or a PR |

The hot loop is the documented *standard shape*: `tests/test.lua` uses it, and CI runs the same thing unchanged.

**Do not bypass the addon system by `includes()`-ing the source by path.** That invalidates every `@addon/...` reference and creates a second reference scheme — the two-sources-of-truth failure recorded in D1 and PIT-1.

### Mode detection is mandatory

Because the hot loop silently shadows the pinned version, `doctor` must state which one is in effect:

```text
polyorch 0.1.3 (locked)      normal
polyorch 0.1.3 (local dev)   a working copy shadows the pin; CI must fail
```

Candidates for the detector: compare the installed payload against the published sha256 recorded in the recipe, or treat a modified `xmake-addons.lock` in git as the override signal. **Mechanism not yet decided.**

### Unverified

- whether `add_addons` truly rejects a path or URL (the documentation simply does not define one)
- where a project-local repository registration is stored, which decides whether it is committed or ignored
- how a **local directory** install derives its version; the docs describe version derivation only for the published recipe path

## Related documents

- [`./01-contract.md`](./01-contract.md)
- [`../architecture.md`](../architecture.md)
