# The Third-Party Dependency Face (D50, v0.8.0)

> Part of the [module reference](./00-overview.md). The authoritative statement
> of each function is (1) its header comment in
> `cmake/PolyOrchThirdPartyHelpers.cmake`, (2) the covering test case, (3) this
> page. When they disagree, the tests are the referee.

## Why this face exists

Consumers (MediaServo first) need GUI-class third-party libraries (SDL3,
Dear ImGui) without vendor lock-in into ad-hoc `ExternalProject` blobs. The
face turns "how did this binary get here" from an archaeology question into a
manifest question: every acquired artifact carries a **full-field cache key**
and a **provenance sidecar**, and every refusal is a FATAL that names the next
step. The design baseline is the sr8 round plan in the parent repo
(`docs/plans/polyorch-sr8-thirdparty-face/`, adjudications F1-F11 + the r4
expert-review fold).

## The seven public verbs (EXPERIMENTAL)

| Verb | What it does |
|---|---|
| `polyorch_thirdparty_fingerprint` | The full-field cache key. `BUILD_TYPE` is REQUIRED (O-3: a multi-config generator with an empty effective config must never collapse two configs into one key); the recipe itself (`RECIPE_SHA256`) and `SCHEMA_VERSION` are key inputs (M1); `OPTIONS` are normalized so ordering/whitespace cannot mint false-distinct keys. |
| `polyorch_thirdparty_fetch` | Verified acquire from a local archive (`URL_HASH` mandatory; a directory URL is refused -- not digests). File patches (`PATCHES`) are verified sha256 FIRST, applied as verbatim same-basename overlays under the archive root LAST (L6). Command-shaped patches (`PATCH_COMMAND`) run after the overlays with the extracted tree as CWD and their command text in the stamp dossier (P3: SDL's Xwayland guard script; a changed command re-acquires and re-patches). The stamp is an inputs memo, never proof the outputs survived: a vanished source re-extracts, and the sweep only deletes fetch's own outputs (sibling `build-<cfg>/install-<cfg>` dirs survive). |
| `polyorch_thirdparty_build` | Independent configure/build/install in a fully separate CMake invocation -- an EXPLICIT verb, never a configure-time side effect (H2). `TOOLCHAIN_FILE` without an explicit compiler pair in `CMAKE_ARGS` is rejected: a half-forwarded cross group silently builds with the host toolchain (H3). `MAKE_PROGRAM` pins the tool's absolute path for child configures running under a sanitized PATH (P3: a ninja that only lives in an activated env vanished and `project()` died with a misleading "CMAKE_C_COMPILER not set"). Full logs land beside the build tree; failures FATAL naming the log. This face injects neither `CMAKE_PREFIX_PATH` nor a compiler into the child (C1 discipline). |
| `polyorch_thirdparty_manifest_write` | The provenance sidecar (JSON): key/key12, license (MANDATORY, L7 -- SDL=zlib, ImGui=MIT class obligations ride the artifact), provider, build_type, recipe digests. |
| `polyorch_thirdparty_package` | Packs an installed prefix into the shared package cache (P2). Name = `<name>-<version>-<triplet>-<profile>-<buildtype>-<linkmode>-<key12>.tar.gz` (§2.4); beside it a bare-hex `.sha256` and a `.manifest.json` sidecar. Packing without a manifest is refused (an anonymous package cannot be judged stale). An idempotent pack compares sidecar identity, never mere file existence. A **relocate gate** scans textual config surfaces (`*.cmake`/`*.pc`/`*.pri`) for build-host absolute paths and refuses to write a pinned prefix into the shared cache (F5 criterion 10). FORMAT seam: only `tar.gz` is writable (`cmake -E tar` on CMake 4.4 has no `--format`; zip/7zip names over tar bytes would be mis-labeled, so they FATAL instead). |
| `polyorch_thirdparty_import` | Consumes the upstream's OWN installed `<Pkg>Config.cmake` (`NO_DEFAULT_PATH` fixed posture) and hands the consumer an ALIAS; upstream target names stay untouched (SDL3:: stays SDL3::). A MACRO on purpose -- find_package(CONFIG) imported targets would evaporate at function return. Never auto-builds at import time (H2): a missing install prefix is a FATAL pointing at the build verb. |
| `polyorch_thirdparty_recipe` | The declarative JSON loader (schema v1 gate, provider-shaped required set: `source` carries the archive pair `url`/`url_hash`, `vcpkg` carries the pin island `pin_dir`; `conan` FATALs toward P7b). Optional `patch_command` (relative path elements resolve against the recipe base; CWD = the source tree) and `fetch_only` (F8 source-wrapper recipes: acquire + patch, then return the source dir -- no build/install/manifest/cache; ImGui rides this). Cache verdict = manifest identity, NOT existence (the QExt/CxxKit stamp check upgraded): same key skips acquire/build, per-config install prefixes. JSON carries static facts only; "probe the system, then pick a profile" stays at the consumer call site. |

## Package cache (P2)

`PACKAGES_DIR` is empty by default (QExt semantics: empty = no packing; zero
side effects). When set, a miss first consults the cache: package present +
sidecar pair present + sha256 matches + sidecar manifest key equals the
current key -> unpack into the install prefix and report **zero build**.
Anything else is a loud refusal, never a fallback:

- missing sidecar pair -> FATAL (a package without provenance is unverifiable);
- sha256 mismatch -> FATAL before the install prefix is touched;
- sidecar key mismatch -> FATAL (kept as a second line behind the key12 in
  the file name, for hand-placed or colliding files);
- extracted tree without an install manifest -> FATAL (corrupt package).

The recipe's cache verdict order is: install-sidecar identity -> package
cache -> build. `PACKAGE_FORMAT` exists but only `tar.gz` is writable today
(F5 seam, see the verb table). The package name embeds the full identity, so
changing any key input (options/profile/triplet/recipe digest/...) yields a
different name and the old package can never be silently reused.

## Dependency providers (P4)

`polyorch_thirdparty_build` / `polyorch_thirdparty_recipe` take
`DEPENDENCY_PROVIDER none|system|pixi` (default **none** -- F3=A: the system
toolchain is the constitution, the pixi fill is implemented but never the
decision by default):

- `none` -- no injection at all (the P1..P3 posture).
- `system` -- sanitize only: `CPATH`, `C_INCLUDE_PATH`, `CPLUS_INCLUDE_PATH`,
  `LIBRARY_PATH`, `COMPILER_PATH`, `CONDA_PREFIX` are `--unset` in the child
  (`cmake -E env`, assignments trailing the unset block -- the measured
  ordering rule).
- `pixi` -- no-activation isolation (disciplines 1/2/3/5): the environment's
  `include`/`lib`/`lib/pkgconfig` SUB-paths are injected into the child env,
  **never the bare prefix** (a prefix carrying `bin/` would let `find_program`
  reach the conda compilers -- the hijack this provider exists to close); an
  explicit compiler (or toolchain file) at the call site is REQUIRED; the
  `pixi.lock` hash and the environment NAME ride the cache key.

Runtime audit (discipline 4): after a `pixi` build the recipe runs
`readelf -d` over the install tree's ELF outputs -- a RUNPATH/RPATH pointing
inside the pixi prefix means the artifact NEEDS THE PIXI RUNTIME and the
manifest gets `pixi_runtime_required: true` (a marker and a WARNING, never a
silent pass; a missing readelf degrades loudly as "not audited").

## Ecosystem provider lane (P7a, vcpkg)

A `provider: "vcpkg"` recipe pins through an ISLAND instead of an archive: one
`pkg-deps/<lib>/vcpkg.json` with `builtin-baseline` committed beside the
recipe. The island's content hash is the artifact-identity anchor (it rides
`ARCHIVE_SHA256` plus explicit `ECOSYSTEM_PROVIDER`/`ECOSYSTEM_PIN_SHA256`/
`ECOSYSTEM_TRIPLET` key fields), so editing a pin -- baseline, override, one
space -- mints a new key and the old artifact can never be silently reused.

Verdict order: install manifest -> package cache -> **ecosystem generate** ->
source build. The generate is the ONE network step and only runs under an
explicit `GENERATE_ECOSYSTEM`. Without it and without a pre-baked artifact the
lane FATALs -- strict-first, no auto-fallback to source, no implicit registry
fetch -- and the refusal is an operator manual (philosophy, the generate
switch, a copy-pasteable command with the lane's exact env, the
`provider "source"` off-ramp).

A generate clones the registry treeless at the pinned baseline, makes a tool
available (four rungs: `VCPKG_PROGRAM` > `vcpkg` already in the root > the
anchor's `tools/bin` > bootstrap into the root, which the baseline pins by
release tag+sha; `BOOTSTRAP_TOOL off` refuses to download), installs a COPY of
the island under the anchor (manifest mode would otherwise write
`vcpkg_installed/` into the in-repo island -- zero intrusion holds), consumes
the flat prefix `<pin copy>/vcpkg_installed/<triplet>` directly, runs it
through the SAME relocate gate as source builds (no exemption: the pack is
refused if the output pins the generate host), and packs it into
`PACKAGES_DIR` with its sidecars. Every vcpkg child runs in a pinned env
(anchor-local downloads and cache, no metrics, no PATH lookup, `--vcpkg-root`
passed explicitly because the tool otherwise derives its root from its own
directory). Triplet is supplier-derived (`TRIPLET` override > `PolyOrch_VCPKG_TRIPLET`
> host facts; static adds the `-static` suffix and the lane writes that
overlay triplet itself, release-only).

Lane postures `BINARY_CACHE` and `BOOTSTRAP_TOOL` are call-site knobs ONLY --
never recipe JSON, because the recipe hash is a key input and a speed switch
must not mint a cache identity. Default: binary cache off (`clear`), bootstrap
allowed. The vcpkg cache lives in the anchor, is never keyed, dies with it.

## Deliberate seams (louder than any doc)

- `provider: conan` -> FATAL naming the P7b lane (same shape as vcpkg: the
  island is `conanfile` + `conan.lock`, the profile is generated from cmake
  facts). Reserved, not implemented. `provider: vcpkg` LANDED with P7a (above).
- `provider: prebuilt|system` -> FATAL naming the P3+ consumer lanes -- the
  P2 package cache covers SOURCE builds only, it is not a prebuilt recipe.
- `DEPENDENCY_PROVIDER sysroot` -> FATAL naming the cross/device batch (P6,
  O-5); none/system/pixi landed with P4.
- The face is **zero-network** for source recipes: archives ship in-repo (or
  on a local path); a missing URL is a FATAL, never a download. The ecosystem
  lane is the deliberate exception, and it is behind `GENERATE_ECOSYSTEM` --
  without that switch a vcpkg recipe with no cached artifact also never
  touches the network.

## Non-goals (pinned by the r4 review)

No byte-level reproducibility (timestamps/absolute paths/compression/parallel
all move bytes); the reproducibility promise stops at "same key -> same
content at the manifest level" (L8). No remote-cache trust story: the sidecar
is self-attested (anti-corruption, not anti-poisoning) -- shared directories
consume read-only and cross-team sharing needs an external trust anchor (M3).

## Covered by

`t-thirdparty-fingerprint-basics` / `-required`, `t-thirdparty-fetch-basic` /
`-hash-mismatch` / `-patch-mismatch`, `t-thirdparty-build-e2e` /
`-halfgroup`, `t-thirdparty-manifest-license`, `t-thirdparty-import-h2`,
`t-thirdparty-recipe-e2e` / `-seams`, `t-thirdparty-package-basic` /
`-corrupt` / `-relocate`, `t-thirdparty-provider-pixi` (sub-path injection,
child-env sanitization, the explicit-compiler negative, provider/lock/env
keying) / `t-thirdparty-provider-seams` (sysroot + guard refusals, the
faked-readelf audit legs, the manifest marker) (capability `cxx` for the
build legs; see `tests/fixtures/thirdparty-basic/`).

The ecosystem lane is covered offline by `t-thirdparty-provider-vcpkg` (14
refusal legs: the strict manual word-for-word plus the FORCE_SYSTEM_BINARIES
negative, the O-13 reds with the source recipe as the green control, island
and license-drift refusals, the lane-knob refusals, both triplet refusals; and
inline checks on the pinned env, both postures, directory creation, the
triplet ladder, pin-hash sensitivity, ECOSYSTEM_* keying) and online by
`t-thirdparty-provider-vcpkg-e2e` (`# e2e: required`: generate -> island zero
intrusion -> pack + sidecars -> offline reuse with the registry root deleted
-> changed island strict refusal; no host preparation needed, the lane
bootstraps the tool itself; see `tests/fixtures/thirdparty-ecosystem/`).
