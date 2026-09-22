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
| `Rust_CARGO_TARGET` (corr:FindRust.cmake:659-791 derivation chain) | `PolyOrch_RUST_CARGO_TARGET` cache input, echoed to `POLYORCH_RUST_CARGO_TARGET`; selector function `_polyorch_rust_derive_target` | naming-map | WP3 delivered the derivation SHAPE (override-then-host-fallback); **WP5 consumed it**: `polyorch_rust_setup` runs the chain pre-discovery through the naming-table family gate (unknown triple FATALs whatever REQUIRED says), normalizes a host-equal selection to the empty host layer, and STATUS-announces a routed triple. The Windows/Android/OHOS chains (corr find:662-780) remain the documented seam in `_polyorch_rust_derive_target`; see the fidelity table for the open half |
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
| `_handle_output_directory_genex` (corr:130-148) | `_polyorch_rust_sanitized_out_dir` (PolyOrchFindRust) | naming-map | Same contract: `$<CONFIG>` rewritten (an empty config also eats the preceding `/`, no `dir//file`), any other surviving genex signals failure by leaving the out-var undefined -- the caller raises the FATAL (the reference's warn-then-fatal split, corr:196-199/217-222). Table-locked by `t-rust-copy-plan` |
| `_corrosion_set_imported_location(_deferred)` (corr:156-262) + `_corrosion_copy_byproducts(_deferred)` (corr:264-376) | `_polyorch_rust_finalize` / `_polyorch_rust_finalize_deferred` / `_polyorch_rust_finalize_pass` / `_polyorch_rust_role_outdir` (PolyOrchRustHelpers) | naming-map | The reference defers two finalize events that duplicate the directory resolution (its corr:294 comment admits it); PolyOrch merges them into ONE `EVAL CODE` + `DEFER CALL` per handle, late-expanding `[[...]]` args behind an ARGN FATAL guard, looping role x config inside. Deviations: file names ride the frozen naming table (the deferred `.exe`-suffix logic corr:117-128,168-171 is unnecessary -- the triple is resolved at configure); the `-static|-shared` exposed-target name remap (corr:159-163) is not ported because the suffixed PolyOrch handle IS the imported target the user sets properties on |
| no-output-dir default: location + stage to `CMAKE_CURRENT_BINARY_DIR` (corr:192-194, 300-305) | in-place cargo artifact, no staging (single-config and MC alike) | fidelity-gap | Deviation, ruled required by the locked contracts: `t-rust-import-ws` pins `$<TARGET_FILE>` equal to the naming-table cargo path and the fixture harnesses pin single-config default locations. Staging, when a property IS expressed, mirrors the reference exactly (`make_directory` + `copy_if_different` + BYPRODUCTS, literal filenames on config-class dirs only). Close only by amending those contracts |
| per-config cargo target dir `build_dir = $<CONFIG>` (corr:676-686, 782-786) | shared `.cargo-target` base, configs segregated by cargo's own profile dir genex `$<IF:$<OR:$<CONFIG:Debug>,$<CONFIG:>>,debug,release>` (corr:772) with the matching `--release` conditional (corr:762, both ported verbatim) | fidelity-gap | Deviation, documented in `polyorch_rust_build`: no `<Config>/<profile>` double-nesting, the single-config layout stays byte-stable, and RelWithDebInfo shares cargo's release fingerprint exactly as its `--release` flag implies. If config-flip churn is ever measured, prepend `$<CONFIG>/` to the base -- the seam is the one `_dir` assignment |
| gnullvm implib `deps/` workaround keyed on `Rust_CARGO_TARGET_ENV` (corr:334-337) | `_polyorch_rust_copy_plan` `KIND implib` testing `TRIPLE MATCHES "gnullvm$"` | naming-map | The env half of the triple is read from the triple text here (the v0 family table), not from a parsed FindRust field. Table-locked by `t-rust-copy-plan`, incl. the mingw row proving NO deps/ outside gnullvm |
| `_corrosion_initialize_properties` (corr:2313-2326) | inline loop in `polyorch_rust_build` mirroring `CMAKE_{RUNTIME,ARCHIVE,LIBRARY}_OUTPUT_DIRECTORY(_<CFG>)` onto the handle at creation | naming-map | PDB_OUTPUT_DIRECTORY not ported (the v0 rust face emits no pdb). The mirror is load-bearing: an IMPORTED target never consults the `CMAKE_*` variables itself (measured, cmake 4.4.3) and the finalize reads properties only |
| `corrosion_set_hostbuild` + `_CORR_PROP_HOST_BUILD` consumed as rule genex (corr:717-728,1166-1172) | `polyorch_rust_set_hostbuild` + mediator property `POLYORCH_RUST_HOST_BUILD` | naming-map | Mechanism ported with two deviations, both locked by tests: the reference ALWAYS passes `--target` (host builds nest under the host-triple dir); PolyOrch omits the flag on the host layer -- the locked t-rust-artifact-paths layout -- and the setter's generate-time genex only suppresses the flag under an ACTIVE cross route. On a non-cross host the setter is observably a no-op versus the default; t-rust-crossplan asserts exactly that (rule text + identical rebased locations), t-rust-musl proves the fall-back to the distinct host directories under a real route. Cross mediators are deliberately UNSTAMPED custom targets (the reference stamps nothing either -- corr:915-920 comment: the path depends on this very property, so it may not be a stamped OUTPUT); the host layer keeps its stamped rule. Eager (configure-time) locations remain cross-shaped until the deferred finalize re-reads the property; a `polyorch_rust_install` of a hostbuild-flipped cross handle reads the stale-eager path (documented at the setter; install is a host-layer surface in v0) |
| `corrosion_cc_rs_flags` trio `CC_/CXX_/AR_<stripped-triple>` (corr:779-793) + the Darwin `SDKROOT`/`MACOSX_DEPLOYMENT_TARGET`/`--sysroot` block (corr:651-657,818-829) | `_polyorch_rust_forward_env` (pure) consumed by the build/test rules | naming-map | The trio/Apple-block conditions are ported (values from CMAKE_* discovery, empty = language not enabled = no entry). Deviations: (1) the key is the UPPER-UNDERSCORE form `_polyorch_rust_triple_env_form` (corr:600-607) where the reference uses its lower/underscore `stripped_target_triple` -- cc-rs accepts the uppercase form and the linker keys need it anyway; (2) the msvc family emits NOTHING (corr guards only AR there; the task's env gate is the superset and cl is not a cc-rs driver); (3) `--sysroot` rides the caller's GLOBAL RUSTFLAGS as `-Clink-arg=` tokens (corr injects local rustflags through `cargo rustc --`, a surface not ported); (4) on a cross route the rule carries BOTH the cross- and host-keyed trios so a hostbuild flip leaves cc-rs the names it reads (corr's iOS hostbuild workaround, corr:809-819, is the precedent for host-keyed env); (5) `LIBRARY_PATH` is not this builder's input (next row) |
| `LIBRARY_PATH` fixed old-macOS SDK path (corr:748-757) | `LIBRARY_PATH` env entry derived from `polyorch_rust_link_libraries`' linker-file dirs (`POLYORCH_RUST_LINK_DIRS` mediator property, `:` join) | fidelity-gap closed-with-deviation | Same rationale (RUSTFLAGS' `-L` never reaches build-script linking), opposite sourcing: the reference hardcodes one SDK path; PolyOrch derives from the declared link surface. Windows `;` join deferred until a windows validation leg exists; table-locked by t-rust-linkplan (B4) |
| `corrosion_link_libraries` (corr:1254-1310) | `polyorch_rust_link_libraries` | naming-map | Staticlib early-return to the CMake link interface: ported (APPEND, keeping the probe-attached system libs intact). CMake-target conversion `$<TARGET_LINKER_FILE_DIR>/<BASE_NAME>` -> `-L/-l`: ported, but the terms ride the GLOBAL RUSTFLAGS env (`POLYORCH_RUST_LINK_LIBRARIES` property, `$<TARGET_GENEX_EVAL>`-joined) where the reference passes them as LOCAL rustflags after `cargo rustc --` -- deviation: dependencies compile with the extra search/link args visible (correctness-neutral for `-L`; `-l` on the final link is per-crate-neutral in practice; RUSTFLAGS is whitespace-split, so a space in a linker-file dir breaks the path -- the reference shares the limit). `LINKER_LANGUAGE` collection for the cross default-linker CXX pick: ported as the `POLYORCH_RUST_LINK_LANGS` genex. Absolute-path `-Clink-arg=` and bare-name `-l` legs: ported. iOS `EFFECTIVE_PLATFORM_NAME` hack: not ported (no Apple validation leg) |
| `CARGO_TARGET_<T>_LINKER` env wiring + `_corrosion_host_linker` precedent (corr:600-607,815,852-857) | `_polyorch_rust_linker_plan` (pure conditions) + `_polyorch_rust_linker_entries` (rule assembly) + `PolyOrch_RUST_LINKER_<TRIPLE-UP>` cache knob + `CMAKE_CROSSCOMPILING_EMULATOR` -> `CARGO_TARGET_<T>_RUNNER` forwarding + configure-time `<tup>-linker` wrapper materialization under `${CMAKE_BINARY_DIR}/.polyorch-rust/` + `polyorch_rust_run` emulator prefix | fidelity-gap closed-with-deviation | See the WP5b fidelity section: the cited corr regions do not exist in the pinned checkout, the implemented shape is the cargo env contract + the two ported lessons (never-a-stamped-OUTPUT wrapper; no quoting of env file values). Default compiler-as-linker injection is CROSS-rules-only (the reference injects on host too; measured redundant here). Table-locked by t-rust-linkplan; the explicit knob is per-TRIPLE where the reference's `corrosion_set_linker` is per-TARGET (next row) |
| `corrosion_set_linker(<target> <linker>)` -> `INTERFACE_CORROSION_LINKER` (corr:1144-1163) | -- not ported -- (`PolyOrch_RUST_LINKER_<TRIPLE-UP>` cache knob covers one-linker-per-configure) | fidelity-gap | Ruled deferred: PolyOrch's v0 cross model is one routed triple per configure; a per-target linker becomes necessary with per-target cross routing. The reference's MSVC warn-and-ignore + staticlib warn are subsumed by the plan's family gates |
| `Rust_CARGO_TARGET_ENV`-keyed extras (task brief's "corr:896-940 THINLTO/OBJC/ASM/RC" cluster) | -- not ported -- | fidelity-gap | The pinned checkout contains no such mechanism (grep-verified: `THINLTO`, `OBJC`, RC-asm, `CMAKE_LINKER` additions absent under `cmake/`); nothing to port without inventing upstream behavior. Register against a future pin bump |
| reference test group `test/output directory` (its CMakeLists:51-139: targetprop / var / pdb-fallback legs, free space-path dirs, MC `$<CONFIG>/` path selection) | legs `tp` / `cv` / space-build-dir + `mcd` / `mcr` of `tests/fixtures/output-dir` + `t-rust-output-dir` (and the matrix.sh MC cell) | naming-map | targetprop and var legs ported (the var leg by the init row above); the free space trick lands in both the build dir and the dest dirs; pdb and postbuild-move legs not ported (no pdb surface; the reference's `LOCATION_$<CONFIG>` genex read is superseded by per-config `file(GENERATE)` target-file probes) |

## Fidelity gaps

WP2/WP3 left no open rows. WP3's FindRust-parity rows are
closed as follows, per mechanism:

- **toolchain-selection knob** -- parity delivered (see the two naming-map
  rows above; the selected-name write-back is the one documented omission).
- **rustup enumeration + proxy resolution** -- parity delivered with the
  two deviations recorded on the rows (injected-proxy kept; override
  marker parsed-not-acted; opt-out knob not ported).
- **version semantics** (`polyorch_rust_version_ok`, floor, exports) --
  parity delivered with the no-auto-scan deviation.
- **imported handles** -- parity delivered with the replacement deviation.
- **CARGO_TARGET derivation + consumption** -- CLOSED with WP5 (2026-09-22):
  setup runs the derivation chain through the family gate and every
  build/test rule routes `--target=<tup>` into the `.cargo-target/<tup>/`
  namespace (real x86_64-unknown-linux-musl legs: t-rust-musl). Still open
  (unchanged): the reference's Windows/Android/OHOS chains
  (corr:FindRust.cmake:662-780) stay the documented seam in
  `_polyorch_rust_derive_target` -- no Windows/Android validation contact
  exists -- as does the `Rust_CROSSCOMPILING` derivation (find:834-838).
- **`cargo metadata` triple-freedom** -- behavior note: cargo metadata
  accepts NO `--target` (measured: rc=1 "unexpected argument", cargo
  1.98.1), so the import probe and the setup probes stay triple-free; the
  `--no-deps` parse reads `packages[].targets` only (platform-independent),
  and every build rule the replay creates carries the routing.
- **native-static-libs probe** -- one cached probe per configure on the
  EFFECTIVE (cross-or-host) triple; a hostbuild-flipped handle keeps the
  cross probe's system-lib list (same-family musl/gnu identical; foreign-
  family hostbuild + static install consumption is a known, documented
  ceiling at the probe).

WP4 (multiconfig / DEFER / copy-staging) closes the multi-config surface the
D17 ruling unlocked, per mechanism:

- **output-directory resolution + per-CFG locations + staging** -- parity
  delivered with the three deviations on the rows above (merged single defer,
  in-place default, literal filenames from the naming table).
- **MC cargo rule** -- `--release` and the profile dir ride the reference's
  own genexes (corr:762/772); the per-config target-dir shape deviates as
  ledgered. Proven live by `t-rust-output-dir` MC legs and the matrix
  `Ninja Multi-Config` cell.
- **gnullvm deps/ importlib** -- parity (table-locked offline; no gnullvm
  toolchain exists on the validation host, so the BYPRODUCTS/plan paths are
  exercised by injection, not by a real build).
- **OPEN (new row)**: custom-profile directory mapping (corr:766-770): the
  reference maps the profile name `dev` to cargo's `debug` output dir;
  `_polyorch_rust_artifact_names` uses the profile name verbatim as the
  directory, so `PROFILE dev` would look in `.cargo-target/dev` (a pre-WP4
  limitation of the PROFILE keyword, now also on the MC path). Register the
  fix with the custom-profiles cluster, not silently.

WP5 / WP5b (cross routing + linker control plane, 2026-09-22) fidelity note
(block-level, applies to every row above citing the linker plane): the task
brief's WP5b anchors -- corr:633-646 (project-stage HOST_OS override),
corr:959-981 + 1061-1070 (embedded linker from `CMAKE_CROSSCOMPILING_EMULATOR`),
corr:1075-1079 (quoting lesson), corr:1352-1360 (RUNNER), corr:1396-1423
(install gate), corr:FindRust.cmake:242-244 (RUNNER) -- are **not present in
the pinned c4786e7 checkout**: a case-insensitive scan for
`CROSSCOMPILING_EMULATOR`, `RUNNER`, `THINLTO`, `OBJC` and the RC/ASM-addition
shape finds zero hits anywhere under its `cmake/`. The mechanisms above were
therefore implemented from the cargo configuration contract
(`CARGO_TARGET_<TRIPLE>_LINKER` / `_RUNNER`) and the lessons the brief records
verbatim (the wrapper file is configure-time material and must never be a
custom-command OUTPUT -- implemented literally and grepped in t-rust-linkplan
B2; env values carry no shell quoting -- VERBATIM-token discipline noted at
`_polyorch_rust_command`). DEFERRED with that evidence, not silently skipped:
- any REAL emulation leg (no qemu on the validation host; no
  `# requires: qemu-<tuple>` gate exists by design);
- the THINLTO/OBJC/OBJCXX/RC/ASM env additions (nothing upstream to port --
  re-register against a future pin bump);
- the project-stage `CMAKE_HOST_SYSTEM_NAME` override for cross timing
  (corr:633-646 per the brief) -- PolyOrch resolves its toolchain per
  `polyorch_rust_setup` call with the triple supplied by the knob, the
  reference's timing trap has no analog in this architecture;
- install-gate "target==host or emulator present" (the reference has no
  gate at the pin; `polyorch_rust_install` remains a host-layer surface).

Rows are added per work package as clusters are reconciled against the
reference surface (Phase B, WP3-WP8), completed by the WP10 full-surface
pass.
