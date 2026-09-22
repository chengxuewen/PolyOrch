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
| `Rust_CARGO_TARGET` (corr:FindRust.cmake:659-791 derivation chain) | `PolyOrch_RUST_CARGO_TARGET` cache input, echoed to `POLYORCH_RUST_CARGO_TARGET`; selector function `_polyorch_rust_derive_target` | naming-map | WP2 scope was define + document + echo only -- unchanged (a non-empty value still prints a STATUS saying `--target` routing is not implemented; WP5 consumes it). WP3 delivered the derivation SHAPE: override-then-host-fallback, with the WP5b seam marked where the reference's Windows/Android/OHOS chains (find:662-780) insert; see the fidelity table for the open half |
| `Rust_CARGO_HOST_TARGET` (corr:FindRust.cmake:637-638,841) | `POLYORCH_RUST_HOST_TARGET` result variable | naming-map | Pre-existing (D13); cached-triple-vs-result-var mechanics differ only because discovery is per-configure here |
| `Rust_TOOLCHAIN` (corr:FindRust.cmake:216-219,238-247,465) | `PolyOrch_RUST_TOOLCHAIN` cache input of `polyorch_rust_setup` | naming-map | Same contract: when set, resolution goes through rustup; unknown names FATAL listing the available toolchains, with the reference's `<name>-<default host>` retry (find:472-503) ported. The reference also caches the SELECTED name back into the same variable (find:465-466) -- PolyOrch keeps the knob strictly input-only and records the selection in the resolved paths instead |
| `Rust_RESOLVE_RUSTUP_TOOLCHAINS` (corr:FindRust.cmake:221-222,319-321) | -- not ported -- | fidelity-gap | Deviation, ruled deferred: the reference's opt-out of proxy descent is unnecessary here because descent is triggered only by a positive proxy tell (auto-detect cannot mis-fire on a direct toolchain), and the injection pair already covers deliberately-pinned setups. Register again if an opt-out demand appears |
| `Rust_RUSTUP_TOOLCHAINS` / `_RUSTC_PATH` / `_CARGO_PATH` / `_VERSION` parallel lists (corr:FindRust.cmake:423-437); `_TOOLCHAIN_<t>_PATH` / `_VERSION` (find:355,378) | `POLYORCH_RUST_TOOLCHAINS` (names; single `direct` entry when no rustup was involved), `POLYORCH_RUST_TOOLCHAIN_HOST` (the default's name), per-toolchain `POLYORCH_RUST_TOOLCHAIN_<name>_PATH` / `_VERSION` cache entries | naming-map | Parallel arrays became per-name cache entries; the per-index rustc/cargo PATH lists are not exported -- the selected toolchain's binaries are re-found under `<root>/bin` at selection time (find:512-516,547-552 shape), and entries whose rustc fails the version probe are dropped with an AUTHOR_WARNING instead of kept as NOTFOUND placeholders (find:388-398) |
| rustup-proxy tell via `RUSTUP_FORCE_ARG0=rustup` + `--version` (corr:FindRust.cmake:279-312) | same mechanism inside `polyorch_rust_setup`'s system route (undocumented internals `_polyorch_rust_parse_toolchain_list` / `_polyorch_rust_enumerate_toolchains`) | naming-map | Mechanism read from the reference and confirmed against rustup 1.29.1 behavior on the validation host. Deviation: a user-INJECTED path is never discarded for being a proxy (the reference warns and drops it, find:296-307) -- the WP2 injection contract keeps the given path verbatim; `POLYORCH_RUST_BIN_DIR` then points inside the toolchain, not at the proxy dir |
| `(override)` / `(active)` toolchain markers (corr:FindRust.cmake:361-363,441-445) | parsed, not acted on | fidelity-gap | Deviation, registered closed-with-deviation: selection is the `(default)`-marked entry (or, with no default, the first kept entry); a directory-scoped rustup override on the configure cwd is ignored. PolyOrch selects via knob or default -- never via ambient cwd state (determinism, D4's spirit) |
| `_findrust_version_ok` (corr:FindRust.cmake:38-71) | `polyorch_rust_version_ok(<actual> <out> [VERSION <v> [EXACT]] [RANGE <min>..<max>])` | naming-map | Same predicate, argument-driven instead of reading `find_package` globals; RANGE is inclusive-only (the reference's EXCLUDE upper bound, find:42-43, is not ported); malformed actuals yield FALSE silently, malformed constraints FATAL |
| `find_package(Rust <ver>[ EXACT] [RANGE ..])` version specifier (corr:FindRust.cmake:39-66,439-463) | `PolyOrch_RUST_MIN_VERSION` cache knob applied by `polyorch_rust_setup` | naming-map | Deviation: the reference rescans the enumerated toolchains for ANY version satisfying the requirement (find:446-462); PolyOrch's floor tests only the SELECTED toolchain and a miss is a normal setup MISS (FOUND=FALSE / REQUIRED FATAL naming found-vs-required). No silent toolchain substitution behind the user's back; measured-only floors otherwise unchanged (the deferred register stands) |
| `Rust_CARGO_VERSION` (+`_MAJOR/_MINOR/_PATCH`, corr:FindRust.cmake:591-607) | `POLYORCH_RUST_CARGO_VERSION` result variable (token; the D13-era `POLYORCH_RUST_VERSION` stays as the locked alias) | naming-map | The reference's no-prefix cargo-version workaround (find:596-601) is not ported: a cargo stub that does not print `cargo <ver>` is a version-probe miss like any other |
| `Rust_VERSION_MAJOR/MINOR/PATCH` (corr:FindRust.cmake:620-624, from rustc) | `POLYORCH_RUST_VERSION_MAJOR/MINOR/PATCH` result variables (normalized rustc triple, `-nightly`-style suffixes dropped) | naming-map | Note the naming asymmetry inherited from D13: `POLYORCH_RUST_VERSION` is the CARGO token, the MAJOR/MINOR/PATCH triple is the RUSTC one -- mirroring the reference, where `Rust_VERSION` is rustc's and cargo's carries its own prefix |
| `Rust::Rustc` / `Rust::Cargo` imported executable targets (corr:FindRust.cmake:902-915) | `PolyOrchRust::Rustc` / `PolyOrchRust::Cargo` created on successful `polyorch_rust_setup` | naming-map | D11 target-naming family. Deviation: the reference creates once behind `if(NOT TARGET)`; PolyOrch REPLACES `IMPORTED_LOCATION` on every successful setup so a re-run with different knobs cannot pin stale paths. Skipped in `cmake -P` script mode (add_executable is not scriptable -- same guard class as the native-libs probe) |

## Fidelity gaps

No open rows registered as of WP2/WP3. WP3's FindRust-parity rows are
closed as follows, per mechanism:

- **toolchain-selection knob** -- parity delivered (see the two naming-map
  rows above; the selected-name write-back is the one documented omission).
- **rustup enumeration + proxy resolution** -- parity delivered with the
  two deviations recorded on the rows (injected-proxy kept; override
  marker parsed-not-acted; opt-out knob not ported).
- **version semantics** (`polyorch_rust_version_ok`, floor, exports) --
  parity delivered with the no-auto-scan deviation.
- **imported handles** -- parity delivered with the replacement deviation.
- **CARGO_TARGET derivation** -- SHAPE delivered (`_polyorch_rust_derive
  target` = override + host fallback, seam marked); the reference's
  Windows/Android/OHOS chains (corr:FindRust.cmake:662-780) stay open
  under the WP5b routing work package, as does the `Rust_CROSSCOMPILING`
  derivation (find:834-838) that consumes them.

Rows are added per work package as clusters are reconciled against the
reference surface (Phase B, WP3-WP8), completed by the WP10 full-surface
pass.
