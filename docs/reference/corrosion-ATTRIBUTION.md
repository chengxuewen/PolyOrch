# Corrosion Port Attribution

> Externally sourced record for the corrosion-derived material in this repository.
> (source: https://github.com/corrosion-rs/corrosion, primary project repository, 2026-09-22)

## Upstream

| Field | Value |
|---|---|
| Project | corrosion — Rust/CMake integration ("Use Rust with CMake and Cargo with style") |
| Repository | `github.com/corrosion-rs/corrosion` |
| Pinned commit | `c4786e7ae2d5ade784aca29448df362c874ed04e` (2026-05-16) |
| Licence | MIT, single licence (source: the `LICENSE` file at the pinned commit, 2026-09-22) |
| Licence text | [`./LICENSE.corrosion`](./LICENSE.corrosion) -- verbatim copy of the pinned checkout's `LICENSE` |

## Scope of this attribution

This document covers the full-port of corrosion's functionality and test
machinery into PolyOrch's CMake surface (planned work packages WP1-WP10 of
the 2026-09-22 port plan). Porting derives from an MIT-licensed work and is
permitted; the licence's attribution condition (retain the copyright and
permission notice) is satisfied by shipping the licence text beside this
record and by marking each derived file.

The convention going forward: **every file whose mechanics are ported from
the reference carries a header line**

```cmake
# Adapted from corrosion (MIT, commit c4786e7): <upstream path:lines>
```

naming the upstream file and the region adapted. Adaptation means the
mechanics were re-implemented in PolyOrch's naming and structure; nothing is
wholesale-copied. The first shipment under this convention is WP1
(`tests/fixtures/_driver.cmake`, adapted from the reference's
`test/ConfigureAndBuild.cmake` and `test/TestFileExists.cmake`).

As of this writing (WP1), no file under `cmake/` carries the header: the
existing modules predate the port and their reference-derived mechanics were
absorbed before the convention landed. Retroactive headers or claims for that
material are deferred to the WP10 reconciliation, which will also extend this
document with a full modification statement.

## Drift policy

Drift between upstream and the port is tracked by the **port ledger's
`corr:` anchors**: every ported mechanism records its upstream file and line
range, so "what diverged and why" is answerable from the ledger alone. This
is deliberately **not** a C5-style sha256 manifest
(`.agents/memorys/conventions.md` C5): a manifest pins bytes, while this port
intends to change bytes -- the deliverable is PolyOrch code that behaves like
the reference, not a copy of it. Intentional deviation is the design, so a
byte-identity gate would encode the wrong invariant. Where a deviation is
deliberate, the ledger says so; where it is accidental, the ledger is the bug
report.

## Modification statement (full-port execution, 2026-09-22)

* **What was taken**: mechanisms only (command shapes, the property-carrier
  architecture, ordering rules, naming contracts, test doctrines), always
  re-expressed in PolyOrch naming and file layout. No source file was copied;
  no CMake code was vendored.
* **Where each mechanism is accounted**: `corrosion-port-ledger.md` maps
  upstream lines to ours per function/knob, with the deviation stated.
  Deviations are of two kinds, both registered: deliberate design choices
  (configure-time stamp resolution on the host layer, kindless pair
  dispatch, no umbrella glue, uppercase cc-rs keys, staging not applied by
  default) and simplifications of deferred clusters (local rustflags,
  file-sets, Windows/Android derive chains) -- never presented as parity.
* **Fidelity corrections in flight**: brief-internal line anchors were
  re-grepped at the pin; absent ones were registered rather than invented,
  and one false 'absent' claim (hostbuild) was retracted -- the ledger's
  audit sections keep the grep evidence for each event.
* **Not ported by policy**: the reference's CI (PolyOrch runs the local
  tests/matrix.sh stand-in), install(EXPORT) set machinery, per-CFG
  import-file staging, and everything in the status.md deferred register
  (including Rust_LLVM_VERSION, deliberately unmirrored: no gate uses it).
* **Live-tool boundary**: cxxbridge/cbindgen e2e legs are gated on tool
  presence + the crates.io capability; no `cargo install` has run (registry
  egress was down at port time; the shared-state gate demands explicit
  user authorization at the first live attempt, `cargo uninstall` rollback).

## Not covered here

* The PolyOrch architecture record and the whitepaper describe PolyOrch's own
  design; they do not cite corrosion as their authority.
* The validation-target identity and the experiment findings are recorded
  only in git-excluded plan documents, per `conventions.md` C6.
