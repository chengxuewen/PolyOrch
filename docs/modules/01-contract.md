# The PolyOrch Contract

> Part of the [module reference](./00-overview.md). The contract is versioned; bridges declare the version they
> conform to.


**Bridge contract** (cargo · cmake · pixi · npm):

| Clause | Rule |
|---|---|
| Scan | `<repo>/third_party/*/<native manifest>`; one recognized manifest per bridged project |
| Derive | `<name>` = build target driving the native tool; `<name>_bin` = debuggable binary target |
| Artifacts | intermediates to `build/.<tool>/<name>/`; final debuggable binaries to `build/<plat>/<arch>/<mode>/<name>`. Bridged-native outputs may reach those paths by **staged copy** (D17): the uniform path is the engine's layout convention, and a bridge may additionally expose the ecosystem-native location as debug metadata |
| Debug metadata | each bridge exposes what a debugger needs: program, cwd, environment |
| Zero intrusion | no xmake file may be written inside `third_party/<name>/` |
| Uniqueness | derived names must not collide with names the project generator emits |

**Package-source contract** (vcpkg · conan):

These are **not bridges**. They have no project body, are never scanned, and produce no `_bin` target. They are dependency sources declared by consuming targets (`add_packages("vcpkg::...")`, `add_packages("conan::...")`) and resolved by Xrepo. What the contract must define is a *declaration and pinning* rule, which is precisely where invariant 1 is currently violated (see ④).

## Integration points

The seven seams the contract has to cover, carried over from the v1.0 record (§5.3):

| Integration point | Implementation |
|---|---|
| PolyOrch to Xmake | Xmake is the core build engine, driven directly |
| PolyOrch to CMake | the bridge invokes CMake and consumes its build artifacts |
| PolyOrch to Colcon | the bridge invokes `colcon build` and integrates the ROS 2 workspace |
| PolyOrch to Meson | the bridge invokes `meson setup` plus `ninja` |
| Xmake to vcpkg/Conan | `add_requires("vcpkg::...")` / `add_requires("conan::...")` |
| Environment unification | Pixi manages the toolchain; `pixi run` executes build commands |
| IDE debugging | the debug surface points `program` at the uniform binary path above, **not** at `install/` |

Note the last row. The v1.0 record said the debugger should point at an executable *under `install/`*, which
contradicts the uniform artifact path in the bridge contract above. **The contract wins** -- as amended by D17 (2026-09-22), which scopes the uniform path as a layout convention reached by staged copy, not an anti-copy taboo on build outputs. This is exactly the
kind of supersession the archive framing on `../whitepaper.md` makes explicit.

## Derivation rules

How a bridged project becomes targets:

```
┌ bridge ────────────────────────────────────────────────────────────────────┐
│ third_party/<name>/<native manifest>                                       │  pure native; no xmake file inside
├────────────────────────────────────────────────────────────────────────────┤
│     |  scan, on every configure                                            │
│     v                                                                      │
│ <name>       -> drives cargo | cmake | pixi | npm                          │
│ <name>_bin   -> debuggable entry (breakpoints work here)                   │
├────────────────────────────────────────────────────────────────────────────┤
│     |  artifacts                                                           │
│     v                                                                      │
│ build/.<tool>/<name>/                                                      │  intermediates
│ build/<plat>/<arch>/<mode>/<name>                                          │  final, uniform (staged copy ok, D17)
└────────────────────────────────────────────────────────────────────────────┘
```

Zero intrusion is what makes the contract verifiable: there is no persisted second copy of a manifest, so
drift is impossible by construction.

## Related documents

- [`./00-overview.md`](./00-overview.md) — payload layout and reference styles
- [`../architecture.md`](../architecture.md) — invariants and the layered view
