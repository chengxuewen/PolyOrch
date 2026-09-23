# Corrosion Port Ledger

> **ctest namespace note (2026-09-22)**: ctest view names are `polyorch::<stem>`
> (`ff0217b`; CMP0110, floor 3.22) -- case-file stems and the run.sh SKIP-contract
> tokens stay bare. Rationale: bare `t-*` names silently double-register when a host
> tree registers its own (measured 2026-09-22). The WP9 table below uses stems.

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
| `corrosion_parse_package_version(<manifest> <out>)` (corr:2267-2309) | `polyorch_rust_package_version(PACKAGE <p> [MANIFEST <m>] OUT_VAR <v>)` + pure sibling `_polyorch_rust_metadata_package_version` | naming-map | Deviation (mechanism): the reference file(READ)s the manifest and regexes the `[package]` table; PolyOrch reads `cargo metadata --no-deps --format-version 1` (the import machinery's own document, wrapper-isolated, triple-free). Consequences: prerelease versions ride verbatim (the reference's `[0-9.]+` regex truncates them); no following-table needed; `NOTFOUND`-via-out-var became UNDEFINED-OUT + a public FATAL reusing `polyorch_rust_import`'s guard identities. Cache surface: `POLYORCH_RUST_PKG_<name>_VERSION` (dashes normalized to underscores), answered without cargo on a cache hit unless MANIFEST re-reads |
| `CORROSION_VERBOSE_OUTPUT` option + `_CORROSION_VERBOSE_OUTPUT_FLAG` (corr:21,588-589,891) | `PolyOrch_RUST_VERBOSE` cache knob consumed at `polyorch_rust_build`'s argv assembly | naming-map | Deviation: the reference calls `option()` at include time; PolyOrch's modules keep the zero-side-effect include contract, so the knob is a plain cache variable read per build. Flag placement mirrors corr:891 -- the cargo BUILD command only (metadata and setup probes never carry it; t-rust-knobs asserts the cargo-test rule stays flag-free) |
| per-call `ALL_FEATURES` / `NO_DEFAULT_FEATURES` (corr:690-695,710-714,1009-1012) + `CORROSION_ALL_FEATURES` / `CORROSION_NO_DEFAULT_FEATURES` target properties (corr:616-617,1221-1243) | `PolyOrch_RUST_ALL_FEATURES` / `PolyOrch_RUST_NO_DEFAULT_FEATURES` cache defaults seeding the existing `POLYORCH_RUST_*` property carriers | naming-map | The reference composes per-call args with the property (property wins, corr:710 comment) and has NO global selector; PolyOrch adds one (plan WP6): defaults fold into the property init at build(), so the same guarded genex chain expands them and a later `polyorch_rust_set_features` write-through replaces them (the reference's precedence direction preserved). PolyOrch's build() has no per-call selector keywords (features flow through the setter family); `build(FEATURES ..)` + the global ALL default is rejected configure-time with the setter's mutual-exclusion identity |
| `INTERFACE_CORROSION_CARGO_FLAGS` target property (corr:731) | `PolyOrch_RUST_CARGO_FLAGS` cache default seeding `POLYORCH_RUST_CARGO_FLAGS` | naming-map | No reference global counterpart (extension of the same defaults channel); `polyorch_rust_add_cargo_flags` appends AFTER the seeded defaults, the existing list-property genex carries both |
| `COR_NO_USES_TERMINAL` per-call arg (corr:696-700, applied at corr:915/948, documented corr:966/983) | `PolyOrch_RUST_NO_USES_TERMINAL` cache knob via `_polyorch_rust_uterm`, applied to the build mediator rule (both layers) and the `polyorch_rust_test` rule | naming-map | Inverse polarity kept EXACTLY: the default now ASKS FOR the console on cargo-carrying rules (suite-wide text change: Ninja edges gain `pool = console`; Makefile generators carry no textual trace, measured 4.4.3 -- the option is inert there and script mode never reaches rule creation). The reference's shim/clean-target distinction has no PolyOrch analog: the `<TARGET>-cargo` shim and the aggregate carry no COMMAND and stay flag-free |
| -- no reference mechanism (the brief's corr:1109-1117 anchor is the `_generator_add_cargo_targets` call site; the actual `BUILD_SHARED_LIBS` gate corr:539-548 chooses which member of an ALREADY-imported pair the umbrella links) -- | `PolyOrch_RUST_DEFAULT_KINDS` cache (unset -> `STATIC;SHARED`; explicitly empty -> the historical pick-exactly-one FATAL) consumed by kind-less `polyorch_rust_build`, handles `<TARGET>-static` / `-shared` / `-exe` | naming-map | PolyOrch EXTENSION per the port plan, registered not smuggled: a kind-less call dispatches one full build per listed kind through the single-kind machinery (import's dual-kind pairing convention, so mediators, shims, FOLDER, auto-build edges and the PIT-13 guard behave per dispatched handle; unknown entries FATAL before any target exists). `polyorch_rust_install` needs no alignment change -- kind defaulting lives at the build face and install keeps consuming explicit handles, as the reference's explicit `corrosion_install(TARGETS ..)` list does |
| `corrosion_install(TARGETS ..)` per-type DESTINATION / PERMISSIONS / CONFIGURATIONS blocks (hand parse corr:1343-1445; consumed per artifact class at corr:1463-1601; GNUInstallDirs defaults corr:1340) | flat `polyorch_rust_install` keywords `RUNTIME_DESTINATION` / `ARCHIVE_DESTINATION` / `LIBRARY_DESTINATION` / `PERMISSIONS` / `CONFIGURATIONS`, all destination/permission/stub decisions resolved by the pure `_polyorch_rust_install_plan` (row table locked by `t-rust-installplan`; the real install() consumes its rows verbatim) | naming-map | Deviations, all at the argument-shape level: the reference's per-type sub-blocks flatten -- one PERMISSIONS list replaces BOTH default sets on every row; GNUInstallDirs defaults became the literal `bin`/`lib`/`include` (the landed shape, kept byte-compatible -- `t-rust-install-e2e` passes unedited on the new code path); `PRIVATE_HEADER` is parsed upstream but never consumed (corr:1349 -- no install leg reads it) so it is not ported; the INTERFACE_HEADER_SETS / `install(TARGETS FILE_SET HEADERS)` branch (corr:1632-1670) and the `install(DIRECTORY)` include-walk for headers are NOT ported -- `PUBLIC_HEADER <file>...` installs each named FILE flat under the include dest and appends an INTERFACE_INCLUDE_DIRECTORIES line to every static/shared replay entry (no directory tree preserved) |
| generated `<export>Corrosion.cmake` import file keyed on `${PACKAGE_PREFIX_DIR}` (corr:1385-1390 remove-once assumption, per-target appends corr:1529-1600) + a USER-written Config supplying the variable | `<export>-rust.cmake` replay stub (self-locating `_POLYORCH_RUST_ROOT`, pre-WP8 design kept) PLUS a generated `<export>Config.cmake` wrapper including it -- both installed to `lib/cmake/<export>/`, so `find_package(<export> CONFIG REQUIRED)` works through `CMAKE_PREFIX_PATH` at FIXTURE level (`t-rust-install-export`: producer, consumer, per-component `--install --component` filtering, and the stripped-stub `pow` negative leg) | naming-map | Deviations with evidence: we EMIT the wrapper the reference leaves to the user, naming both files explicitly after the EXPORT name (the corr:1536 convention variable is set inside the wrapper but measured cmake 4.4.3: CMake swallows `PACKAGE_PREFIX_DIR` at the find_package boundary -- ordinary variables leak, that reserved one does not -- so the load-bearing line of the wrapper is the `include()`, and the stub never depended on the variable). The `install(EXPORT)` / `install(TARGETS ... EXPORT)` machinery (incl. corr:1642/1663 fallback legs) is not ported -- upstream's own `corrosion_install(EXPORT ...)` is a FATAL (corr:1673-1674) -- the replay stub stays the single export mechanism (port plan G1). One stub per EXPORT name (corr:1389 assumption shared). CONFIGURATIONS gates the artifact rules through CMake's own keyword; MULTI-CONFIG stub staging (per-CONFIG replay locations) was NOT built -- documented seam, and `t-rust-install-export` joins the matrix.sh MC-cell exclusion list with its single-config harness siblings. The ROOT half (PolyOrch's own `PolyOrchConfig.cmake` + package export chain) stays BLOCKED-ON-HOST and was not touched |
| -- no reference mechanism (the WP8 brief's "COMPONENTS" and "ARCHIVE_OUTPUT_ARTIFACTS-ish handling" anchors: `COMPONENTS` occurs ZERO times in corr:1338-1678 at the pin -- grep-verified; the only `ARCHIVE_OUTPUT` hits (corr:386-488) are build-side `*_BYPRODUCTS`; the brief's "per-component blocks" cited at corr:1568-1664 is the shared-library install plus the PUBLIC_HEADER/file-set walk) -- | `COMPONENT <name>` (CMake's own singular install keyword, not the brief's plural) stamps one component on every ARTIFACT rule of the call; the cmake pair stays component-less (always installed on a default `cmake --install`, absent under a `--component` filter) | PolyOrch extension | Registered as an extension, not a port -- see the WP8 anchor audit below. |

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
- **CLOSED (WP9, 2026-09-22)**: custom-profile directory mapping
  (corr:766-770) -- `_polyorch_rust_artifact_names` now normalizes the
  profile NAME `dev` to cargo's artifact DIRECTORY `debug` (the one
  built-in whose name differs from its dir; `test`/`bench` stay
  unmapped -- the reference excludes them for hashed artifact names).
  The fix rides BOTH the naming table (offline rows pinned in
  `t-rust-artifact-paths`) and `polyorch_rust_build`'s single-config
  `_pdir` + the deferred finalize, so `PROFILE dev` now imports from
  `.cargo-target/debug/`. Proven live by `t-rust-customprofiles`'s cp-dev
  leg (artifact in debug/ + debug_assertions run marker).
  No-output-dir staging remains the ledgered deviation it always was.

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

WP6 (workspace/version/knob parity, 2026-09-22) closes the import-time
defaults and the version-surfacing line, and registers the task brief's
stale anchors: corr:1109-1117 and corr:1377 (cited as "BUILD_SHARED_LIBS
default kinds" and "install default kinds") do NOT carry that mechanism at
the pin -- 1109-1117 is `corrosion_import_crate`'s
`_generator_add_cargo_targets` call, 1377 is `corrosion_install`'s
hand-rolled EXPORT argument parse; `BUILD_SHARED_LIBS` itself sits at
corr:539-548 and gates the umbrella's LINK side, not the kinds. The brief's
corr:21-32 "global COR_* knobs" range holds the VERBOSE option and a
removed-feature warning (the ALL/NO_DEFAULT/USES_TERMINAL selectors are
per-call parses at corr:1009-1013). Mechanism verdicts:

- **package-version exposure** -- parity with the metadata-read deviation
  on the naming-map row; the deferred-register line closes with
  `polyorch_rust_package_version`.
- **import-time global defaults** -- a PolyOrch extension at the GLOBAL
  level (only VERBOSE is global upstream; the rest are per-call/property
  composites at corr:710-714). Defaults fold into the property carriers
  build() initialises: knobs unset, every generated rule is byte-
  identical to the pre-WP6 shape except for the USES_TERMINAL default
  (above); knobs set, `t-rust-knobs` locks the tokens in generated
  build.make and the Ninja `pool = console` halves.
- **default kind pair** -- extension, no upstream mechanism (see the
  naming-map row); install-side alignment verified as a no-op.
- **nostd via the target RUSTFLAGS seam** (plan WP6 line): no new
  mechanism was built -- `polyorch_rust_add_rustflags` already carries any
  per-target `--cfg` a no_std build needs. Two anchor corrections
  registered: the plan's corr:94-95 is not the rustflags seam at the pin
  (the reference's per-target form is `corrosion_add_target_local_rustflags`,
  used from corr:834-868), and its LOCAL (`cargo rustc --`) scope stays the
  pre-existing deferred line (PolyOrch's RUSTFLAGS is the GLOBAL env
  variant); no GLOBAL_NO_STD_FLAG twin exists or was invented.
Rows are added per work package as clusters are reconciled against the
reference surface (Phase B, WP3-WP8), completed by the WP10 full-surface
pass.

## WP8 anchor audit (install/export non-root half, 2026-09-22)

The task brief's WP8 region anchors were re-grepped at the pinned c4786e7
before implementing, per the standing anchor discipline. Verdicts:
`corrosion_install` genuinely carries the flat per-type
DESTINATION/PERMISSIONS/CONFIGURATIONS machinery (corr:1338-1678), the
generated-import-file blocks with `${PACKAGE_PREFIX_DIR}` fixups
(corr:1529-1600, variable at 1536/1585/1596), and the PUBLIC_HEADER /
file-set legs (corr:1606-1670). It carries NO component mechanism
(`COMPONENTS`: zero occurrences in the region) and no
`ARCHIVE_OUTPUT_ARTIFACTS` handling; the corr:1568-1664 "per-component
blocks" phrasing in the brief describes the shared-library + header
machinery. The COMPONENT keyword and the generated `<export>Config.cmake`
wrapper are therefore PolyOrch extensions/emit-side deviations,
registered in the naming-map rows above -- not ports. The reference's own
consumer test (`test/corrosion_install/install_lib`) hand-wires imported
targets against the install tree and never exercises the generated import
file; the PolyOrch `t-rust-install-export` fixture goes further and
consumes the staged tree through a real `find_package(polyorch-demo
CONFIG REQUIRED)`, which is the fixture-level half of the brief's
consumer chain. The root-level half (`PolyOrchConfig.cmake`, the
PolyOrch-package install chain, docs/modules promotion) stays
blocked-on-host; no root file was touched by this work package.

## WP7 anchor audit (cxxbridge/cbindgen tool clusters, 2026-09-22)

The brief's region anchors were re-grepped at the pinned c4786e7 BEFORE
implementing and verified exact: `corrosion_add_cxxbridge` corr:1786-1981
(docs ANCHOR pair 1734/1784), `corrosion_experimental_cbindgen`
corr:2068-2264 (docs ANCHOR pair 1984/2066), the cxx-version probe
`_corrosion_check_cxx_version(_helper)` corr:1680-1726, the tool-search
paths `_corrosion_find_rust_paths` corr:FindRust.cmake:224-233, and the
two inline install rules corr:1857-1873 (cxxbridge_v<ver>) /
corr:2166-2184 (_corrosion_cbindgen). The brief's API sketches carried
stale keywords the pin does not have, corrected-to-reference rather than
invented: the cxxbridge sketch's `[STATUS/RUST/CC/CXX]`/`COMMENT` keywords
and the `HEADERS` name (the reference's input list is `FILES`,
corr:1789-1792 -- ported as FILES; "rerun-on-header-change" is the
source-file DEPENDS edge at corr:1959, ported); the cbindgen sketch's
`CONFIG`/`OUTPUT`/`PARSE` keywords (the pin exposes HEADER_NAME /
CBINDGEN_VERSION / FLAGS and its rerun machinery is the DEPFILE at
corr:2235 -- ported in that shape; a cbindgen `-c` config remains
reachable through FLAGS).

Surface rows (additions to the naming map above):

| Reference | PolyOrch | Class |
|---|---|---|
| `corrosion_add_cxxbridge(cxx_target CRATE REGEN_TARGET FILES)` (corr:1786-1981) | `polyorch_rust_cxxbridge(TARGET <handle> FILES <rs>... [REGEN_TARGET] [VERSION] [PREFIX] [OUTPUT_DIR] [ALLOW_INSTALL])` creating `<TARGET>-cxx` | naming-map |
| `corrosion_experimental_cbindgen` dual signature (corr:2068-2264) | `polyorch_rust_cbindgen` with the SAME keywords on both signatures | naming-map |
| `_corrosion_check_cxx_version(_helper)` (corr:1680-1726) | `_polyorch_rust_cxx_version_required` | naming-map |
| inline tool resolution + install rules (corr:1824-1876, 2152-2185; paths corr:find:224-233) | `polyorch_rust_tool_bootstrap` + pure `_polyorch_rust_tool_version_check` (PolyOrchFindRust) | fidelity-gap closed-with-deviation |

Mechanism notes and deviations, by cluster:

- **tool bootstrap consolidation** -- the reference inlines
  discover-then-install per cluster with different shapes (cxxbridge:
  exact-version gate + `--version <v> --root --quiet`, per-target
  `cxxbridge_v<ver>` empty-target trick; cbindgen: presence-only +
  `--locked --root`, shared `_corrosion_cbindgen`); PolyOrch factors ONE
  function: cache `<TOOL-UPPER-UNDERSCORED>_TOOL` (FILEPATH, advanced --
  the INSTALLED_CXXBRIDGE/installed_cbindgen role), search PATH +
  toolchain bin dir + CARGO_HOME/bin + ~/.cargo/bin + the (default)
  build-tree `polyorch-tools/<NAME>[-v<ver>]/bin` roots, exact lock
  compare via the pure helper (corr:1839 semantics; a wrong-version hit
  is demoted to NOTFOUND, corr:1838-1847), and ONE deferred
  `cargo install` rule target `polyorch-tool-<crate>[-v<ver>]` built
  through `_polyorch_rust_command` (the --unset strip leads,
  `CARGO_BUILD_RUSTC=` pins the selected rustc -- corr:1861-1862/2172).
  Deviations: the version-banner regex is name-agnostic (the reference
  hardcodes the binary name, corr:1830/1701); the cxxbridge leg always
  quiets the install rule (corr:1867) while cbindgen follows the inverse
  of `PolyOrch_RUST_VERBOSE` (corr:2177 + corr:21's flag); rules are
  SKIPPED in `cmake -P` script mode (the decision and cache still
  resolve -- same guard class as the imported handles in setup); the
  reference's always-present empty `cxxbridge_v<ver>` target becomes an
  EMPTY `OUT_TARGET` when the tool was discovered (the caller drops its
  DEPENDS keyword -- semantically identical, one fewer phantom target).
- **DISCOVERY-ONLY DEFAULT (the network-discipline deviation)** -- the
  reference's install branch fires unconditionally at configure
  (corr:1850-1876: "No suitable version installed, so use custom target
  to build correct version"); PolyOrch fires it only with explicit
  `ALLOW_INSTALL` (plan R-10 confines crates.io exposure to this cluster
  AND a permission, and the shared-state gate in the plan requires user
  authorization before a `cargo install` mutates the toolchain). Without
  the permission the call reports `live bootstrap deferred (network
  gate)` and the surface FATALs with acquisition guidance (locked by
  t-rust-toolplan's phrase child). The install rule itself is deferred
  to build time exactly like the reference's, so even ALLOW_INSTALL
  never touches the network during a configure. FIRST-LIVE-EVIDENCE
  STATUS: none yet -- `cargo install cxxbridge-cmd` has NEVER been run
  (this host measured crates-io FALSE at WP7 time); the authorization +
  rollback (`cargo uninstall cxxbridge-cmd`) sequence is deferred to the
  first live attempt per the plan.
- **cxxbridge cluster** -- ported verbatim in behavior: the
  `cargo tree -i cxxbridge-cmd || cxx --all-features --target all
  --depth=0` derivation (corr:1680-1726, rationale comment included),
  the rust/cxx.h builtin-header rule (corr:1921-1928), the per-file
  twin invocations with `--include <cxx_t>/<header>` AFTER `--output`
  (corr:1949-1961; argv order locked by `_polyorch_rust_cxxbridge_cmd`
  tables in t-rust-cxxbridge), the directory_component handling for
  FILES under subdirectories (corr:1934-1942; fixture locks `sub/nested`
  both sides), the generated folder layout (corr:1879-1900,
  `polyorch_generated/cxxbridge/<TARGET>-cxx/` instead of
  corrosion_generated), `add_library STATIC` + `$<BUILD_INTERFACE>`/
  `$<INSTALL_INTERFACE:include>` include dirs + `cxx_std_11`
  (corr:1902-1910), the circular PRIVATE/INTERFACE link edges to
  `<CRATE>-static`/`<CRATE>-shared` (corr:1912-1919 -- the WP6 pair
  naming made these names live), PRIVATE sources + PUBLIC headers with
  the corr:1967-1971 ordering rationale, and the header-only
  REGEN_TARGET (corr:1973-1979). Deviations: the C++ target name is
  derived (`<TARGET>-cxx`) not caller-chosen; CRATE resolves against any
  of the pair-handle spellings (the reference has one umbrella target);
  absolute FILES pass through, resolving corr:1940's own todo;
  POLYORCH_RUST_MANIFEST (new handle stamp in build()) replaces
  INTERFACE_COR_PACKAGE_MANIFEST_PATH.
- **cbindgen cluster** -- ported: both signatures and the keyword set
  (corr:2069-2080), the missing-HEADER_NAME and unknown-signature FATALs
  and the AUTHOR_WARNING for unknown args (corr:2082-2107), the auto
  mode's hostbuild triple switch as a genex (corr:2113-2114 --
  normalized: with the PolyOrch empty-cross convention the non-hostbuild
  leg resolves to HOST_TARGET on a host layer where the reference's
  `_CORROSION_RUST_CARGO_TARGET` already named the host), manifest /
  package-name resolution from the handle (corr:2116-2124 ->
  POLYORCH_RUST_MANIFEST / POLYORCH_RUST_PACKAGE), the STATUS
  "using package" line (corr:2148), manual-mode absolute manifest dir +
  non-INTERFACE BINDINGS_TARGET AUTHOR_WARNING (corr:2127-2146; gate
  additionally demands CARGO_PACKAGE -- the reference's own gate
  duplicates BINDINGS_TARGET at corr:2091-2092 and omits CARGO_PACKAGE,
  a typo we correct), the bare `-E env TARGET= CARGO= RUSTC=` rule
  prefix with `--output/--crate/--depfile=/FLAGS` tail +
  COMMAND_EXPAND_LISTS + manifest WORKING_DIRECTORY + DEPFILE
  (corr:2220-2238; argv locked by `_polyorch_rust_cbindgen_cmd` tables,
  env wiring asserted functionally through the stub's echoed header in
  t-rust-cbindgen), the depfile-parent MAKE_DIRECTORY (corr:2212-2217 --
  a first-draft port dropped it and the manual-leg subdirectory depfile
  caught it), and the aggregate + per-header regeneration targets with
  the mediator edge in auto mode (corr:2248-2263). Deviations: the
  CMake>=3.23 FILE_SET HEADERS branch (corr:2194-2200) is NOT ported --
  the reference's pre-3.23 include-dirs fallback is the only shape
  (our 3.25 floor; header install-side flows through
  `polyorch_rust_install(PUBLIC_HEADER)` or the user's own install);
  CBINDGEN_VERSION is WIRED into the lock compare although upstream
  declares it unimplemented (corr:2052 -- strict superset, honored the
  moment a pin is given); the install-branch DEPENDS is inline instead
  of the reference's APPEND-on-second-command (corr:2240-2246, same
  graph effect).
- **live-leg honesty** -- the crates.io-free fixture rule pins the
  cxxbridge VERSION from the tool's own `--version` banner in the parent
  case instead of deriving it via `cargo tree -i cxx` (the reference's
  corr:1701 path needs a real `cxx` dependency, forbidden in fixtures by
  the WP7 brief); `_polyorch_rust_cxx_version_required` is therefore
  ported-but-live-untested until a registry-capable validation runs.
  The reference test groups (`test/cxxbridge` 4-variant + circular pair,
  `test/cbindgen` auto/manual/install, `test/cpp2rust`, `test/rust2cpp`)
  are WP9 fixture-translation material: the MECHANISMS they cover are
  covered here by the stub rule legs + the gated live legs; the circular
  LINK-GROUP variant additionally needs
  `CMAKE_LINK_GROUP_USING_RESCAN_SUPPORTED` (cmake>=3.24 policy surface
  outside this port's link story -- ledger note, decide at WP9). The
  `cbindgen_install*` legs ride the FILE_SET install shape we did not
  port (registered above).### Correction (2026-09-22, post-WP7 audit)

The WP5 report claimed `hostbuild` had zero hits in the pin; re-grep at
`c4786e7` shows `corrosion_set_hostbuild` at corr:1166 with 14 total
hits -- that claim was wrong and the mechanism is ported (row above).
The other two stale-anchor findings (IMPORTED_LINK_DEPENDENT_LIBRARIES,
RUST_TARGET_TRIPLE) stand: genuinely absent at the pin. WP7's
cxx/cbindgen region confirmations were independently re-verified.



## WP9 fidelity audit -- test-parity reconciliation (2026-09-22)

The pinned tree's `test/` directory is the sole ledger for this pass: 22
actual fixture directories enumerated from `corr:test/CMakeLists.txt`
(the brief's remembered "24 entries" count does not exist at the pin --
22 `add_subdirectory` calls is the measured truth). Verdict classes:
PORTED (a live leg or locked table covers the mechanism), PORTED-ADAPTED
(the property under test is covered in a simplified/renamed shape --
deviation named), DEFERRED (exact blocker). New legs follow the
command-layer convention: a physical effect (run marker / compile
failure / file in the tree / archive member), generated-rule text only
as a secondary pin; nothing const-foldable (PIT-21).

| # | Reference dir | Our case(s) | Verdict |
|---|---|---|---|
| 1 | `cargo_flags` | `t-rust-cargoflags` (+ fixture `cargo-flags`) | PORTED (WP9) -- compile_error-per-missing-feature as the reference, delivered through the CARGO_FLAGS property via ONE generate-time genex; `--timings` build-tree file as the second observable. Deviations: import-time `FLAGS` has no PolyOrch import keyword (the channel is `add_cargo_flags`); stable cargo 1.98 `--timings` takes NO value (bare flag; `--timings=html` rejected, measured) and writes `cargo-timings/cargo-timing-*.html` one level under the target dir |
| 2 | `cbindgen` | `t-rust-cbindgen` stub-rule legs + `t-rust-cbindgen-e2e` (gated) | PORTED (WP7) -- live tool legs ride the crates.io + authorization gate (unchanged since WP7) |
| 3 | `config_discovery` | `t-rust-configdisc` | PORTED (WP9) -- offline inversion of the registry-alias trick: `.cargo/config.toml` beside the project root carrying [build] rustflags + [env]; both consumed at COMPILE time (cfg arm + `env!` hard-error), proving the rule's WORKING_DIRECTORY + --manifest-path discovery combo and the load-bearing empty-RUSTFLAGS elision |
| 4 | `corrosion_install` | `t-rust-install-e2e`, `t-rust-install-export` | PORTED (WP4/WP8) -- install surface + find_package consumer chain; per-CFG stub staging remains the documented seam |
| 5 | `cpp2rust` | `t-rust-link-c` (Rust bin <- C staticlib), cluster note | PORTED-ADAPTED -- one C archive, not the reference's three C++ libs (rename + space-path legs: the space trick is locked in the `output-dir` fixture instead); the real `corrosion_link_libraries` direction runs live |
| 6 | `crate_type` | `t-rust-defaultkinds`, import kind derivation | PORTED-ADAPTED -- `FLAGS --crate-type=...` has no analog: PolyOrch reads `[lib] crate-type` from cargo metadata and dispatches kinds from it (the reference's flag exists to stop its own double-build; there is nothing to stop here). The `CRATE_TYPES` import filter is likewise absent (metadata selection is the filter) |
| 7 | `custom_profiles` | `t-rust-customprofiles` (+ `basic_profiles` legs folded in) | PORTED (WP9) -- four explicit spellings (debug / release / nodbg / dev) x distinct BASE_DIRs; dir + run-marker physical per leg; the dev -> debug mapping CLOSED this pass (see the WP4 OPEN-row flip above). The reference's MC genex profile (`$<IF:$<CONFIG:Release>,...>`) and INTERFACE-corrosion-cargo-profile override target are NOT ported: explicit profiles are configure-time literals here by design (deviation, this row) |
| 8 | `custom_target` | -- | DEFERRED -- the blocker is PolyOrch-side, not host-side: `polyorch_rust_setup`'s WP5 family gate rejects a `.json` target-spec file as a triple, and the naming table has no file-name family for one (host capability measured: `RUSTC_BOOTSTRAP=1 rustc -Z unstable-options --print target-spec-json` succeeds, rust-src installed). Porting needs a triple-file design at the derive/naming seam -- register, do not smuggle |
| 9 | `cxxbridge` | `t-rust-cxxbridge` stub-rule legs + `t-rust-cxxbridge-e2e` (gated) | PORTED (WP7) -- circular/link-group variant stays deferred per the WP7 note (`CMAKE_LINK_GROUP_USING_RESCAN` outside this port's link story) |
| 10 | `envvar` | `t-rust-envvars` (+ fixture `env-var`) | PORTED (WP9) -- build.rs panics on a missing var (compile-level physical proof), bakes values via cargo:rustc-env, run asserts the exact strings: literal, generate-time genex-VALUED entry (deviation: the reference genexes NAME=VALUE wholesale -- our setter validates `^[A-Za-z_]\\w*=` so the name stays literal), and the cargo-version token (replaces their COR_CARGO_VERSION_MAJOR/MINOR pair -- PolyOrch exposes the full token). No-env negative leg proves non-ambient (PIT-14 strip holds) |
| 11 | `features` | `t-rust-features` (+ fixture `features`) | PORTED (WP9) -- the headline closure of the analysis's #1 hole: real cfg build with compile-breakage default (NO_DEFAULT_FEATURES load-bearing), genex-delivered feature list (the app_features carrier shape), positive run marker + negative compile-failure both ways |
| 12 | `find_rust` | `t-rust-findrust`, `t-rust-rustc-version`, `t-rust-executables`, setup guards | PORTED (WP3) -- proxy tell, enumeration, floor gate, imported handles; double-`find_package` idempotency == repeated `polyorch_rust_setup` (t-rust-executables); the rustup_proxy disabled-without-rustup leg == the WP3 proxy branch under real rustup |
| 13 | `gensource` | `t-rust-gensource` (+ fixture `gensource`) | PORTED-ADAPTED (WP9) -- generator is a `cmake -P` script, not a host-built Rust binary (its role is the ORDERING edge, not its language -- hostbuild is separately covered); generated file lands in the BINARY tree via env!-supplied absolute path (source-tree generation would race the matrix cells). Rebuild leg deletes the stamped artifact (the reference's unstamped always-run mediator would re-invoke cargo on any build -- the stamping deviation, ledgered at the no-output-dir row, made visible here) |
| 14 | `hostbuild` | `t-rust-crossplan` (suppression + no-op legs), `t-rust-musl` (host-dir fall-back under a real route) | PORTED (WP5) -- the C-function print of their fixture adds no mechanism beyond the link_libraries leg already run in `t-rust-link-c` |
| 15 | `multitarget` | `t-rust-multitarget` (+ fixture `multitarget`) | PORTED (WP9) -- one package, import-yields-three handles (mt_lib + bin1-exe + bin2-exe), distinct-path FATAL at fixture level (configure-time guard) + two runs through ONE shared C static archive. Joins the matrix.sh MC exclusion (import-built handles carry per-config genex locations -- single-config contract by construction). Their bin3/c++ lib: same mechanism, two bins prove the per-handle routing |
| 16 | `nostd` | `t-rust-nostd` (+ fixture `nostd`) | PORTED-ADAPTED (WP9 feasibility form) -- the NO_STD keyword itself stays unported (WP6 ruling; this leg tests the SHAPE: #![no_std] + panic_handler builds through the standard wrapper, C consumer archives against it). Measured deviations recorded at the fixture: debug-profile overflow check and precompiled unwinding core forced `panic = "abort"` profiles in Cargo.toml (a manifest-level property of no_std staticlibs, not of PolyOrch); no executable link -- the reference builds none either (static member), and the no_std archive still carries `DW.ref.rust_eh_personality` |
| 17 | `output directory` | `t-rust-output-dir` + matrix MC cell | PORTED (WP4) |
| 18 | `override_crate_type` | `t-rust-defaultkinds` + import pairing | PORTED-ADAPTED -- the `OVERRIDE_CRATE_TYPE name=kinds` keyword has no analog: kind selection is metadata-derived and the DEFAULT_KINDS pair dispatch is the user-side lever (ledger row above, WP6). Their staticlib+cdylib override effect == what crate-type metadata already declares here |
| 19 | `parse_target_triple` | `t-rust-findrust` (gate leg), `t-rust-artifact-names` / `t-rust-copy-plan` (family-rejection rows) | PORTED-ADAPTED -- the reference WARNS (and continues with the host triple) on an unparsable `Rust_CARGO_TARGET`; PolyOrch FATALs at setup whatever REQUIRED says (the WP5 family-gate deviation, ledgered at the CARGO_TARGET naming-map row) -- the should-fail / should-not-fail pair is covered as pass / hard-fail instead of warn / no-warn |
| 20 | `rust2cpp` | `t-rust-link-c` (C exe <- Rust staticlib, run marker), `t-rust-install-e2e` (archive staging), defaultkinds pair | PORTED -- static + shared kinds of the same direction; the shared cdylib consumer-executable leg stays network-free covered by the pair handles (their `.so` dlopen story is the install seam's job, already locked) |
| 21 | `rustflags` | `t-rust-rustflags` (+ fixture `rustflags`); `cargo_config_rustflags` leg folded into `t-rust-configdisc` | PORTED (WP9) -- plain --cfg, key="value" (cargo shell-words split, quotes reach rustc -- measured), the $<CONFIG> genex flag (debug|release arm either way, the reference's own regex ambiguity kept), and the GLOBAL-scope proof through a path dependency that cannot compile without the cfg (their local-scope some_dependency leg stays the deferred `cargo rustc --` line). Flags-off negative leg fails on the dep's compile_error |
| 22 | `workspace` | `t-rust-import-ws` | PORTED -- CRATES selection + exact imported-set pins; their member3-shadow-bin case == the metadata-driven selection here (unlisted members never emit handles) |

### Product fixes this audit produced (both were latent until a real
### build exercised them -- the value of closing the command-layer gap)

- **GENEX_EVAL wrappers on the deferred build-input reads** (corr:702-727,
  ported shape was missing them): FEATURES / ALL_FEATURES /
  NO_DEFAULT_FEATURES / CARGO_FLAGS / ENV_VARS reads now wrap the
  `$<TARGET_PROPERTY>` in `$<GENEX_EVAL:...>`, and the RUSTFLAGS read uses
  `$<GENEX_EVAL:...>` (NOT TARGET_GENEX_EVAL: measured, TGE re-lists a
  space-joined string property around its quoted elements and mis-parses a
  nested genex boundary -- a `--cfg=key="value"` flag then leaked a stray
  `>` into the argv; corr chose the same spelling for these properties for
  the same reason per its corr:705 todo comment). Without this, a user
  property value carrying a generator expression expanded LITERALLY into
  the cargo argv -- exactly the reference's app_features / INDIRECT_VAR_TEST
  shapes, now locked live by `t-rust-features` / `t-rust-envvars`.
- **`dev` -> `debug` profile-dir normalization** closing the WP4 OPEN row
  (see above): `_polyorch_rust_artifact_names` table + `polyorch_rust_build`
  `_pdir` (dir + deferred finalize) -- argv keeps spelling `--profile dev`.
- **matrix.sh**: `t-rust-multitarget` joins the MC-cell exclusion regex
  (import-built per-config genex locations; classic cells cover it fully,
  and it passed a dedicated MC-Release run at authoring time along with the
  eight explicit-profile/PROFILE-debug siblings -- none of the other eight
  needed an exclusion).

### Register updates from this pass

- `custom_target`: re-registered above with the measured blocker
  (family-gate rejection of file triples + no naming family for one);
  NOT-YET list in the port plan unchanged otherwise.
- `nostd`: the WP6 ruling ("keyword not ported; target-RUSTFLAGS seam
  carries it") stands; `t-rust-nostd` adds the missing FEASIBILITY leg for
  the manifest-level shape and records the panic="abort" measurement.
- Reference `test/README.md` ctest-FIXTURES lifecycle: our drivers'
  marker-gate + scratch isolation + SKIP-veto contract is the accepted
  substitute (analysis TP2 ruling); the reference's
  `PASS_REGULAR_EXPRESSION`-on-run idiom is what the new cases implement
  as execute_process + marker asserts inside `cmake -P` cases.
