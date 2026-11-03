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

## The six public verbs (EXPERIMENTAL)

| Verb | What it does |
|---|---|
| `polyorch_thirdparty_fingerprint` | The full-field cache key. `BUILD_TYPE` is REQUIRED (O-3: a multi-config generator with an empty effective config must never collapse two configs into one key); the recipe itself (`RECIPE_SHA256`) and `SCHEMA_VERSION` are key inputs (M1); `OPTIONS` are normalized so ordering/whitespace cannot mint false-distinct keys. |
| `polyorch_thirdparty_fetch` | Verified acquire from a local archive (`URL_HASH` mandatory; a directory URL is refused -- not digests). Patches are verified sha256 FIRST, applied as verbatim same-basename overlays under the archive root LAST (L6). The stamp is an inputs memo, never proof the outputs survived: a vanished source re-extracts, and the sweep only deletes fetch's own outputs (sibling `build-<cfg>/install-<cfg>` dirs survive). |
| `polyorch_thirdparty_build` | Independent configure/build/install in a fully separate CMake invocation -- an EXPLICIT verb, never a configure-time side effect (H2). `TOOLCHAIN_FILE` without an explicit compiler pair in `CMAKE_ARGS` is rejected: a half-forwarded cross group silently builds with the host toolchain (H3). Full logs land beside the build tree; failures FATAL naming the log. This face injects neither `CMAKE_PREFIX_PATH` nor a compiler into the child (C1 discipline). |
| `polyorch_thirdparty_manifest_write` | The provenance sidecar (JSON): key/key12, license (MANDATORY, L7 -- SDL=zlib, ImGui=MIT class obligations ride the artifact), provider, build_type, recipe digests. |
| `polyorch_thirdparty_import` | Consumes the upstream's OWN installed `<Pkg>Config.cmake` (`NO_DEFAULT_PATH` fixed posture) and hands the consumer an ALIAS; upstream target names stay untouched (SDL3:: stays SDL3::). A MACRO on purpose -- find_package(CONFIG) imported targets would evaporate at function return. Never auto-builds at import time (H2): a missing install prefix is a FATAL pointing at the build verb. |
| `polyorch_thirdparty_recipe` | The declarative JSON loader (schema v1 gate: provider seams FATAL pointing at P2/P7). Cache verdict = manifest identity, NOT existence (the QExt/CxxKit stamp check upgraded): same key skips acquire/build, per-config install prefixes. JSON carries static facts only; "probe the system, then pick a profile" stays at the consumer call site. |

## Deliberate seams (louder than any doc)

- `provider: vcpkg|conan` -> FATAL naming the P7 provider face (prerequisites
  O-10/O-11/PolyOrch O4) -- reserved, not implemented.
- `provider: prebuilt|system` -> FATAL naming the P2 package-cache face.
- P1 is **zero-network**: archives ship in-repo (or on a local path); a
  missing URL is a FATAL, never a download.

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
`t-thirdparty-recipe-e2e` / `-seams` (capability `cxx`; see
`tests/fixtures/thirdparty-basic/`).
