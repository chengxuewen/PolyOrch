# Corrosion Port Ledger

> Externally sourced record (C2): the mechanism-by-mechanism account of the
> full port of corrosion's functionality and test machinery into PolyOrch's
> CMake surface. Provenance, licence and drift policy:
> [`./corrosion-ATTRIBUTION.md`](./corrosion-ATTRIBUTION.md) (upstream pinned
> at `c4786e7`, MIT). Anchors use the attribution's `corr:` shorthand --
> `corr:<file>:<lines>` inside the pinned checkout.

## Taxonomy (two levels, per D15)

Every ledger row is exactly one of:

| Class | Meaning | Closure rule |
|---|---|---|
| `fidelity-gap` | The mechanism is absent from PolyOrch | Close only by implementing the mechanism (or by an explicit ruled N/A with a reason) |
| `naming-map` | The mechanism is present and equivalent under a different name | A NAME is never a closure reason -- equivalence is judged by behaviour; the row exists so the name delta is auditable |

## Naming map

| Reference name (corr anchor) | PolyOrch name | Class | Notes |
|---|---|---|---|
| `Rust_COMPILER` user-var promotion (corr:FindRust.cmake:324-332) surfaced to callers as the `RUSTC_EXECUTABLE` tool path (corr:Corrosion.cmake:59-66,113) | `PolyOrch_RUSTC_EXECUTABLE` cache input of `polyorch_rust_setup` | naming-map | Honored first on **both** routes (system and pixi), bypassing `find_program`; set-but-nonexistent is a FATAL. Mechanism-equivalent: user-supplied path wins over discovery |
| `Rust_CARGO` user-var promotion (corr:FindRust.cmake:324-332) surfaced as the `CARGO_EXECUTABLE` tool path (corr:Corrosion.cmake:59-66,114) | `PolyOrch_RUST_CARGO_EXECUTABLE` cache input of `polyorch_rust_setup` | naming-map | Same semantics as the rustc row; the pair keeps result vars `POLYORCH_RUST_{CARGO,RUSTC}` unchanged |
| `Rust_CARGO_TARGET` (corr:FindRust.cmake:659-791 derivation chain) | `PolyOrch_RUST_CARGO_TARGET` cache input, echoed to `POLYORCH_RUST_CARGO_TARGET` | naming-map | WP2 scope is define + document + echo only -- a non-empty value prints a STATUS saying `--target` routing is not implemented (WP5 consumes it). The reference's derivation chain is a separate future row |
| `Rust_CARGO_HOST_TARGET` (corr:FindRust.cmake:637-638,841) | `POLYORCH_RUST_HOST_TARGET` result variable | naming-map | Pre-existing (D13); cached-triple-vs-result-var mechanics differ only because discovery is per-configure here |

## Fidelity gaps

None registered as of WP2. Rows are added per work package as clusters are
reconciled against the reference surface (Phase B, WP3-WP8), completed by the
WP10 full-surface pass.
