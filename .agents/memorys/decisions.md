# PolyOrch — Decisions

> Format: `## D{N}: Title` + rationale + alternatives + references.

## D1: Toolchain ported from MediaServo, generic parts only

- **Date**: 2026-09-18
- **Decision**: PolyOrch is a **new project**. Keep `.agents/rules/` (the generic parts), the generic skills, and the `.opencode/` / `.omo/` configuration. MediaServo domain memory and domain skills are **moved out of PolyOrch** — no in-repo copy is kept.
- **Rationale**: the original `.agents/memorys/*` (430 KB of MediaServo WebRTC/mediasoup history) was loaded **every turn** via `instructions[]` in `.opencode/opencode.json`, which is context pollution for a new project; the same applies to the domain skills.
- **Alternatives**:
  - Keep and rewrite each file — high cost, and domain residue tends to survive.
  - Delete everything — loses reusable methodology.
- **Domain test**: a rule that only holds for the MediaServo/mediasoup architecture counts as a domain file even when it sits in `rules/common/` (for example `platform.md`, `docker.md`).
- **References**: `.opencode/opencode.json` `instructions[]`; source repository `DEVSYS/MediaServo`
- **Revision (2026-09-18)**: changed from "archive in-repo" to "move out of PolyOrch". Verification: 4 memorys + 2 rules + 14 skills (34 files total) were `diff`-identical to the `DEVSYS/MediaServo` originals (**0 differences**), so the in-repo copy was merely a second source of truth. The copy was moved to Trash and can be emptied.

## D2: English for every artifact; Chinese only for chat and plan documents

- **Date**: 2026-09-18
- **Source**: user directive.
- **Decision**: all project artifacts are written in English — documentation, code comments, `.agents/memorys/*`, `.agents/rules/*`, `.agents/skills/*`, configuration comments, and git commit messages. Chinese is permitted only in (1) AI chat interaction and (2) plan documents under `.omo/`, which is git-excluded. Canonical brand strings are the one exception inside documents: they stay byte-exact, including the Chinese one.
- **Rationale**: one language for machine-consumed artifacts removes a translation layer for agents and tooling, and the memory/instruction files are loaded on every turn so their cost is paid continuously. Chinese is retained where it is a human-collaboration surface (chat) and where a document is deliberately kept out of git (working plans).
- **Alternatives**:
  - Keep the previous Chinese-primary policy for docs — rejected; it contradicted the single-language goal.
  - Go English-only including the canonical Chinese description — rejected for now: that description is a mandated brand asset. Revisit if the brand direction changes.
- **Scope note**: this reverses the earlier Chinese-primary documentation policy, so all pre-existing Chinese content was converted (32 files, 1311 lines).
- **References**: `conventions.md` C4


## D3 (AMENDED 2026-09-23 by user ruling, supersedes the original): the delivery form is the CMake helper surface; the Lua/Xmake-addon form is retired

- **Decision (2026-09-23, option "a")**: PolyOrch's v0.1 delivery form **is the CMake helper surface** (`cmake/PolyOrchPixiHelpers.cmake`, `PolyOrchFindRust.cmake`, `PolyOrchRustHelpers.cmake` + `tests/` + `examples/`), consumed by plain `include()`/`find_package`. The original D3 -- Lua code shipped as an Xmake addon (plugins/rules/templates) -- is **retired, not deferred**: no addon wrapper is planned. D16 (CMake-first, xmake demoted to reference corpus + package-management source) already described the reality; this amendment closes the decision to match and removes the last contradiction.
- **What the original said (kept for the record)**: on 2026-09-20 v0.1 was decided to be Lua-in-an-Xmake-addon, on the rationale that the bridges were already `xmake.lua` and one language would keep the contract single-sourced (verified against xmake v3.1.1's bundled Lua runtime and addon subsystem; precedent esp32-devel/stm32-devel/avr-devel). The surface that actually landed from the corrosion full-port (D17/D18) is a CMake helper face with a fixture test suite; the CMake-first architecture was then formalized in D16 and the xmake-engine product prose was demoted.
- **Why the amendment is safe**: nothing was built against the addon form (zero Lua shipped; the vendored xmake skills are third-party reference material, not product code). The xmake ecosystem knowledge (addons, packages, xrepo) remains in the repo as **reference corpus** per D16.
- **Consequences**: `docs/modules/00-overview.md`'s addon-payload mapping is historical; `docs/derived/*` product prose is swept to the CMake-first narrative in the next doc-audit (R4.1, unblocked by this ruling); AGENTS.md/status.md carry the CMake-first identity as of 2026-09-22.

## D4: Anything that affects the build result is pinned in the repository

- **Date**: 2026-09-20
- **Decision**: no build-affecting configuration may live in a user's global state.
- **Rationale**: **three** violations were found in the prototype. (1) The Xmake binary came from Homebrew and appeared **0 times** in `pixi.lock`, so `bootstrap.sh` plus `pixi install` does not reproduce the toolchain. (2) `xmake-vscode` resolved the engine from `PATH`, escaping the pin. (3) The vcpkg root and the conan program path lived in `xmake g` global configuration.
- **Consequence**: Xmake moves into `pixi.toml` (available on conda-forge as `xmake-3.1.1`); the PolyOrch addon version is declared by the repository (see D6); the vcpkg/conan pinning rule is still open (`docs/architecture.md` O4).
- **References**: `docs/architecture.md` (invariants, and section ④ The Reproducibility Boundary)

## D5: Bridges discover, derive, and forward; Xmake is the single build authority

- **Date**: 2026-09-20
- **Decision**: a bridge never transcribes a native manifest and never persists a copy. Generated CMake / VS / Xcode projects are **insight projections** for IDEs, never a second build path.
- **Rationale**: verified that the Xmake-generated CMake contains **no `add_custom_command` at all**, and that bridged targets appear as inert `add_custom_target` nodes paired with an empty `add_executable(<name>_bin "")`. Building through that projection would create a second, divergent build path.
- **References**: `docs/architecture.md` (invariants 2 to 4); `docs/modules/01-contract.md`

## D6: The addon is declared in the repository and pinned by a committed lock file

- **Date**: 2026-09-20, revised the same day after reading the official addon docs
- **Decision**: a project declares PolyOrch in its `xmake.lua` with `add_addons("polyorch <range>")`. Xmake **auto-installs missing addons when the project is loaded**, and writes the resolved versions to `xmake-addons.lock` beside `xmake.lua`. **That lock file is committed and is the pin.** `~/.xmake/addons/<name>/<version>/` is a per-user, per-version cache, not a source of truth. Development uses `xmake addon --install .` against a working copy.
- **Rationale**: this is the native mechanism, so the steady state needs **no per-repository bootstrap script and no command to remember**: a fresh clone runs `pixi run xmake` and everything resolves. It mirrors the environment layer exactly (`pixi.toml` + `pixi.lock` for toolchains, `xmake.lua` + `xmake-addons.lock` for addons), so D4 is satisfied by two symmetric locks rather than by a global install.
- **Alternatives rejected**: a per-repository `bootstrap.sh` reintroduces one duplicated file per repository, which is the disease being cured; cloning a template repository drifts, whereas addon project templates ship with the pinned version.
- **Development mode**: `xmake addon --install .` from the working copy is the documented standard shape, and the official docs note it is the same thing a user does, so `tests/test.lua` runs unchanged in CI. A locally installed working copy can silently shadow the pinned version, so `doctor` must answer whether the effective addon is the locked one or a local development build. **The detection mechanism is not yet decided**; candidates are the published archive sha256 recorded in the xmake-repo recipe, or `xmake-addons.lock` showing as modified in git.
- **Gotchas from the official docs**: the version comes from the xmake-repo package recipe, **not** from `addon.lua` (bump the tag, not the manifest); command names and template ids are **global**, and `polyorch` was chosen to be collision-safe.
- **References**: `docs/modules/00-overview.md`; `docs/architecture.md` section ④; `xmake-docs` `guide/extensions/addons/installation.md` and `development.md`

## D7: IDE strategy -- VS Code first-class, three IDE-agnostic contract facts

- **Date**: 2026-09-20
- **Decision**: v0.1 makes VS Code first-class; every other IDE gets the universal floor (`compile_commands.json` plus a documented manual debug recipe). The contract owns three IDE-independent facts -- a uniform debuggable binary path, a materialized debug environment, and a target inventory -- and each IDE is only a projection of them.
- **Rationale**: `xmake-vscode` exposes 33 settings, including `xmake.executable` (pin the engine to the locked instance) and `xmake.customDebugConfig` (inject the generated debug surface); both verified on 2026-09-20. No equivalent verification exists for CLion: the `xmake-idea` plugin exists (`github.com/xmake-io/xmake-idea`, 26,303 downloads) but the whitepaper's DAP claim is unverified.
- **Mechanism**: M1 (`pixi run code .`, zero config but habit-dependent) plus M2 (`xmake.executable`, survives any launch method). `doctor` asserts the IDE-visible toolchain is the pinned one, so M1's silent failure becomes a loud check.
- **References**: `docs/architecture.md` section ③ Debug Surface, O2, O5
- **Revision (2026-09-20, same day)**: the M2 mechanism above (`xmake.executable`) is **not settled**. `status.md` O5 found that `xmake.executable` / `${workspaceFolder}` is documented nowhere, and that the documented knob for pinning a project-local binary is `XMAKE_PROGRAM_FILE` (plus `XMAKE_PROGRAM_DIR`). M1 (`pixi run code .`) is unaffected. Re-verify `xmake-vscode` itself before fixing the M2 mechanism.

## D8: v0.1 scope -- four bridges and two package sources

- **Date**: 2026-09-20
- **Decision**: v0.1 ships four bridges (cargo, cmake, pixi, npm). vcpkg and conan are **package sources, not bridges**: they are declared with `add_packages("vcpkg::...")` / `add_packages("conan::...")` and resolved by Xrepo. meson and ros/colcon are deferred; Windows and Linux are out of scope.
- **Rationale**: vcpkg/conan have no project body, are never scanned, and produce no `_bin` target -- verified: no `vcpkg.json` or `conanfile.*` occurs anywhere under `third_party/`, and both appear only as `add_requires` in the root `xmake.lua`. **npm is the one genuinely new bridge**: today it is only an inline `rule("web_build")` in `src/ui_web/xmake.lua` with no `third_party/` sample, while the largest candidate repositories need it. The prototype's most-refined bridges (cmake, ros) are the least needed by those repositories.
- **References**: `docs/architecture.md` section ⑤ Bridge Status, `docs/modules/01-contract.md`

## D9: Sibling repositories are not a skill source

- **Date**: 2026-09-20
- **Decision**: PolyOrch adopts **no skills** from the sibling `DEVSYS/` repositories. Their `.agents/skills/` trees are a shared-toolchain family, not an ecosystem to mine.
- **Rationale**: all eight siblings holding `.agents/skills/` were scanned -- 34 unique skill names, of which PolyOrch already had 8, and **every overlap was a drift-fork of one shared base rather than independent work**. Of the 26 candidates, four filters (the domain gate, the English-only rule C4, self-reference, and a qualitative fit review) left two arguably adoptable -- and both are artifacts whose canonical author is the **openspec CLI** (`author: openspec`). Vendoring a fork of a CLI-generated skill would create the two-sources-of-truth failure this project already records (D1, PIT-1).
- **Alternatives rejected**: vendoring the cleanest available copies, for the reason above. **Not rejected but deferred**: `doc-audit`, `source-driven-development`, and `incremental-implementation` -- all three need a full English rewrite plus rebinding, and all three assume a source tree that does not exist yet.
- **Finding worth keeping**: `doc-audit` is the highest-value sibling candidate. It audits a `docs/` + `.agents/` corpus for decision liveness, self-consistency and gap coverage -- precisely this project's shape. Revisit at P3.
- **Scan shape, for a future re-run**: 26 candidates -> 23 free of the removed domain -> **5** that are also English-only and free of self-references. The extra filters are what make the number small; the first one alone over-reports by more than 4x (PIT-4).
- **References**: `status.md` open items; `.agents/skills/ecosystem-scan/` (the scanning procedure)
- **Revision (2026-09-20, same day)**: `doc-audit` was **ported** — the one deliberate exception. The source was a sibling repository's copy, the clean twin of the same 214-line generation; the MediaServo copy carries `mediaservo` / `mediasoup` literals and cannot pass the domain gate. It was translated to English and rebound to this repository's documents and `C` / `D` / `PIT` numbering, so it is **re-authored, not copied**. The other two deferred candidates stay deferred.

## D10: The validation repository is the sibling monorepo hosting this checkout

- **Numbering note**: the sub-items D10.1-D10.4 (selection criteria, experiment rounds, field-coverage gaps, prototype residual) exist ONLY in the git-excluded plan zone per C6; the tokens are quoted in status.md by design and resolve there.
- **Date**: 2026-09-20
- **Source**: user directive ("use the ../../ project as the experiment field, improve this project step by step, and transform it; analyze and conclude") plus the separation constraint that produced C6.
- **Decision**: O1 is decided. The v0.1 validation target is the sibling polyglot monorepo whose working tree currently hosts this checkout — a real repository with workspace-scale cargo build as its native authority, a multi-feature Pixi environment, and the `bootstrap.*` + `pixi.*` + launcher trio that PolyOrch promises to replace. Its identity is deliberately **not written into any formal document**: per C6 the two projects' design documents never name each other; the naming record lives only in the git-excluded plan zone (`.omo/plans/`).
- **Consequences registered with it**:
  1. **O6 reopened** — the validation host is Linux/x86_64; macOS-only cannot hold, Linux enters scope at first contact.
  2. **O9 registered** — the contract's uniform-binary-path fact collides with a forwarding-only cargo bridge (artifacts live under the project's own `target/` tree); candidate amendment in `docs/architecture.md` O9.
  3. **Coverage gaps stay open** — the target exercises the cargo and pixi bridges at production complexity, and its hand-written CMake facade independently corroborates invariant 3 (a production repository already ships an insight projection whose build authority stays native), but it carries no npm build surface, no third-party CMake dependency, and no vcpkg/conan usage: the npm bridge and O4 are not validated by this choice.
  4. **The prototype is not inheritable on this host** — neither the engine nor the environment manager is installed and the prototype tree is absent; the first experiment re-implements the cargo bridge from the contract rather than porting prototype code.
- **Alternatives**: the earlier recommendation (a repository named in D1's lineage) — **not available on this host**; the recommendation was never actionable here.
- **Note on placement**: this repository sits at the top level of the target's working tree, excluded by the target's own ignore rules (the checkout moved out of the target's `.repos/` on 2026-09-20). The whitepaper-era rejection of a `.repos/` layout concerned the *consumer-repository* checkout form and does not conflict with this placement; development-wise the checkout is D6's addon source (`xmake addon --install .`).
- **References**: `docs/architecture.md` (O1, O6, O9); `conventions.md` C6; naming record in `.omo/plans/` (git-excluded)

## D11: CMake-surface naming layering

Brand casing on the CMake interface: cache variables and options are `PolyOrch_` (brand verbatim) + `UPPER_SNAKE` suffix (`PolyOrch_PIXI_MANIFEST`, `PolyOrch_BUILD_TESTS`); functions and package/import names lowercase `polyorch_*`; project-level targets were `PolyOrch<PascalCase>` until 2026-09-30, when the example buttons were unified into the lowercase directory grammar (`pixi-bootstrap`, `rust-import-pixi`, `rust-bindings-standalone`; D27) -- target names are now kebab-case everywhere, CamelCase survives only in variable/option namespaces (the last local CamelCase target, the `PolyOrchTest` umbrella, followed on 2026-09-30 as `polyorch-test`; CamelCase survives only in variable/option namespaces and the `PolyOrchRust::{Rustc,Cargo}` imported-`::` handles, which are the fmt/Qt-style export form). `POLYORCH_` remains a misspelling everywhere except ONE namespace: shell environment variables (`POLYORCH_TEST_E2E`), which follow the all-caps env convention and are deliberately exempted from the C1 scan scope (C1 scans content documents, not env names). A host's all-caps brand (e.g. a parent project's `*_ENABLE_PIXI`) is the same rule applied to that brand, not an exception. (user decision, 2026-09-21)

Imported tool handles follow the same layering: `PolyOrchRust::<PascalCase>`
(`PolyOrchRust::Rustc`, `PolyOrchRust::Cargo`) -- the namespaced-imported
form of the project-target family, equivalent to the reference's
`Rust::Rustc` / `Rust::Cargo` (corr:FindRust.cmake:902-915; port-ledger
naming-map row; WP3, 2026-09-22).

## D12: pixi CMake API ships as one module; test/example opt-in defaults

(1) All pixi functions -- read-only, build-time, explicit-mutating, tool-install and bootstrap -- live in `cmake/PolyOrchPixiHelpers.cmake` as a single module (~1500 lines). The split-by-timing-class sibling (PolyOrchPixiWorkspace.cmake) was merged away by user directive on 2026-09-21, consciously overriding the generic 800-line file guideline for this file; the section banners keep the timing classes visible. (2) Option defaults follow `PROJECT_IS_TOP_LEVEL`: tests ON when PolyOrch is configured standalone, OFF when embedded (a host's ctest surface never grows polyorch cases by accident); examples OFF both ways. Note that `polyorch_option` does not FORCE: a stale cache pins the old default -- changing a default requires delete-cache/reconfigure instructions to users. (3) The generator's built-in `test` target is directory-scoped and invisible to project-target UIs (CMakeTools dropdown, CMake outline); `polyorch-test` is the discoverable umbrella (renamed from `PolyOrchTest`, D27). The root embed sentinel followed the same day: the empty `${PROJECT_NAME}` custom target became `add_library(PolyOrch::PolyOrch INTERFACE IMPORTED GLOBAL)` -- the Threads::Threads package-existence form, '::' requiring IMPORTED; the sibling host's probe line was updated in lockstep (user-approved root-freeze exemption, 2026-09-30), and it runs `ctest --test-dir <its own dir>` so it never executes a host's suite. Corrosion (github.com/corrosion-rs/corrosion) is the naming/architecture reference for the future Rust wrappers.

## D13: Rust face design -- dual toolchain route, triple-family naming, isolated cargo target dir

The Rust wrappers (`cmake/PolyOrchRustHelpers.cmake`) are a driver, not an installer: cargo/rustc must already exist. (1) `polyorch_rust_setup(FROM system|pixi)` -- system via find_program, pixi via `polyorch_pixi_env_paths` (conda layout searched across bin/Library-bin/Scripts); result vars `POLYORCH_RUST_{FOUND,CARGO,RUSTC,VERSION,ROUTE,HOST_TARGET,BIN_DIR}`. A miss without REQUIRED degrades to STATUS + FOUND=FALSE (a host without a toolchain can still configure the consumer project's other faces). (2) Artifact naming is decided by the OBJECT FAMILY parsed from the target triple (msvc/gnu/macho/elf), never by the host -- the same table serves future cross builds; cross `--target` routing itself is out of scope (ponytail seam at the naming call). (3) All cargo invocations share one isolated `${CMAKE_BINARY_DIR}/.cargo-target` (overridable per call via BASE_DIR because redirected pixi environments may make the build tree the wrong volume), which is why `polyorch_rust_clean()` is a plain directory removal and never needs a working cargo. (4) Because `add_dependencies()` refuses IMPORTED targets, every `polyorch_rust_build(TARGET x)` creates the mediator custom target `x-cargo` and imports x as EXECUTABLE/UNKNOWN IMPORTED (the corrosion arrangement, re-implemented, not copied). (5) `polyorch_rust_run` execs the artifact directly instead of `cargo run` (one path, no second toolchain resolution at run time). C1 note: the all-caps `POLYORCH_*` prefix is legitimate for result/environment variable namespaces (mirrors CMake's own `<PACKAGE>_FOUND` convention and the shell-env style of `POLYORCH_TEST_E2E`); when C1's "future source tree" scan is extended to `cmake/`, it must carry this exemption -- brand casing governs files, targets and user-facing strings, not variable namespaces. (6) Follow-ups landed same day: all four wrappers accept FOLDER <ide> (build applies it to BOTH the imported target and its -cargo mediator); polyorch_rust_build rejects TARGET == artifact base name (PIT-13); the rust-basic example self-bootstraps its pixi rust env at configure time and is opt-in when embedded via PolyOrch_BUILD_RUST_EXAMPLES (standalone configure always proceeds). **Revision (2026-09-22, WP2 of the D15 port)**: the pixi self-bootstrap is gone -- rust-basic now runs the default system route (cargo/rustc from PATH, no FROM arg, opt-in gate unchanged), and setup additionally honors the injection pair `PolyOrch_RUST_{CARGO,RUSTC}_EXECUTABLE` + echoes `PolyOrch_RUST_CARGO_TARGET` (routing lands WP5); `docs/architecture.md` carries the invariant-1 exemption note, `docs/reference/corrosion-port-ledger.md` the naming-map rows.

## D14: Rust face architecture pivot -- deferred genex inputs, config-correct profiles, three-tier testing

Executed 2026-09-21 via the gap-close plan (`.omo/plans/2026-09-21-rust-gap-close.md`, commits `602273f..7ac0c71`). (1) **Pivot**: build inputs no longer bake into configure-time argv; they live as properties on the `cargo-build-<T>` mediator and are consumed at generate time through guarded `$<TARGET_PROPERTY>` genex (`--features=`/equals form; empty props collapse to zero stray args, VERBATIM+`cat -A` verified). Setters (`set_features`/`set_env_vars`/`add_cargo_flags`/`add_rustflags`) mutate after declaration -- the reference's post-declaration mutation model without its DEFER machinery (ruled separable: DEFER serves the output-staging/multi-config cluster only). Profile selection became configure-time-resolved from `CMAKE_BUILD_TYPE` (Release finally builds release artifacts -- measured 464 KB stripped vs 4.6 MB debug); the stamp path must stay a literal (OUTPUT/BYPRODUCTS forbid genex), so the `$<CONFIG>` flag-genex form was deliberately NOT adopted for single-config (ponytail seam documents it). (2) **Consumer ergonomics**: auto-build edge via `add_dependencies()` on the IMPORTED target itself (works -- our old header claim that IMPORTED rejects it was wrong); `<T>-cargo` kept as DEPENDS shim after `add_custom_target(x ALIAS y)` was measured to generate a literal `ALIAS` command on cmake 4.4.3 (PIT-15); `polyorch-rust-all` aggregate = bare-build option (c). (3) **Link correctness**: toolchain-wide native-static-libs probe at setup (throwaway staticlib, WARNING-not-FATAL, script-mode guarded) attached as STATIC interface; proven by positive AND negative link e2e (stripped stub => `undefined reference to pow`). (4) **Batch import** `polyorch_rust_import` over `cargo metadata --no-deps` (string(JSON); pure parse fn table-locked; naming: libs dash->underscore, bins `<name>-exe`, dual-kind pairs; ghost-CRATES FATAL lists available packages). (5) **Install minimal shape**: `polyorch_rust_install` stages artifacts, `EXPORT` replays a relative-path import stub that re-attaches native libs; include()-only consumption, no install(EXPORT)/Config generation (G1 ruling). (6) **Testing doctrine** (replaces "exit-code-only" negatives): error-identity pins via `ck_child_fail`, `# expect-log`/`# expect-no-log` markers symmetric across both drivers, rule-wiring probe tier between units and full e2e (the structural layer PIT-13 hid in), and `tests/matrix.sh` -- the local stand-in for absent CI, 2 generators x 2 configs with right-reason greps. Every phase kept all Task-1 locks (incl. the artifact-paths matrix) green unedited across Tasks 2-6.

## D15: System-rust-first + full-port strategy (user rulings, 2026-09-22)

Four rulings govern the rust-face port program (execution plan and strategy record live in the git-excluded `.omo/plans/2026-09-22-*` pair; this entry is the in-repo record, per the rule that a decision may not have its only home in the excluded zone). (1) **Decoupling** -- the rust face is decoupled from pixi: the default toolchain is whatever the PATH provides (system rust), and pixi is demoted to ONE coverage route pending the future global switcher. (2) **Fidelity-before-customization full port** -- the reference's (github.com/corrosion-rs/corrosion, MIT, pinned commit `c4786e7`) functionality and tests are ported wholesale before any own optimization; the port ledger uses a two-level taxonomy -- `fidelity-gap` (mechanism absent, must be closed) vs `naming-map` (renamed, mechanism-equivalent; a NAME is never a closure reason) -- with `corr:` file:line anchors as the drift mechanism. (3) **Full test parity** -- every reference test surface is ported, including platform legs that cannot run here, gated by a shared `# requires: <cap>` capability marker; DISABLED semantics = the contract SKIP line (`<case-stem> : SKIP (<reason>)`), honest in both drivers: run.sh counts it as a skip and ctest reports Skipped, while an unmarked silent ": SKIP (" is VETOTED as FAIL by both (wired same day with the driver self-lock trio -- canary, executed-count tripwire, marker selflock). (4) **Global toolchain switcher deferred** -- pointing rust/cxx toolchains at a pixi environment via one global knob is a deliberate FUTURE phase, not part of the port. Rationale for the ordering: the validation host's rust genuinely comes from a pixi env (real use case for ruling 4), but conda-forge solve flakiness made the whole pixi-gated rust test face intermittently red, while system rust builds deterministically; decoupling first converts that flake into coverage.

## D16: CMake-first architecture; xmake demoted to reference + package-management (supersedes D3 delivery form)

User ruling 2026-09-22, unlocking Phase B of the corrosion full-port. PolyOrch's implementation IS the CMake helper surface (cmake/*.cmake): it is the v0.1 first-class deliverable, not scaffolding for a later Lua rewrite. D3's "Lua shipped as an Xmake addon" delivery form is SUPERSEDED -- xmake's role shrinks to (a) research/reference corpus (the vendored skills + .refinfo analyses) and (b) a package-management source (vcpkg/conan via xrepo remain declared as dependency sources, the "not bridges" stance unchanged). Pixi stays the environment manager; the "Xmake as the engine" line in README/AGENTS/status was rewritten accordingly. The whitepaper remains the frozen v1.0 record; this ruling is recorded HERE and pointed at from architecture.md, per C2. Related rulings same day (module organization): the rust face splits per the reference project's file taxonomy -- PolyOrchFindRust.cmake (toolchain discovery/triples/naming/probes/command wrapper) + PolyOrchRustHelpers.cmake (build-graph API); D12's single-file stance survives as per-module-family, banners retained.

## D17: O9 ruled -- artifact bytes may be staged; invariant 2 governs configuration (amends architecture.md + modules/01-contract.md)

User approved 2026-09-22 (plan WP4 gate, `question` confirm), explicitly ruling AHEAD of the D10 "decide at the first experiment round" timing and SUPERSEDING that candidate's shape. Ruling: (1) the "never transcribes / no persisted second copy" invariant was always about configuration truth (the native manifest stays the single source of build configuration), not about artifact bytes; (2) copying bridged-ecosystem build outputs into the engine's standard locations (`build/<plat>/<arch>/<mode>/`, `RUNTIME_OUTPUT_DIRECTORY` semantics, `install(TARGETS)`) is permitted staging; (3) the uniform path is a layout convention for engine-managed outputs, and bridges may additionally expose native paths as debug metadata. Unlocks the multiconfig/DEFER/copy-staging cluster (full-port plan WP4). Amended same-commit: architecture.md invariant 2 + O9 row, 01-contract.md Artifacts row + contract-wins paragraph + diagram.

## D18: full-port executed -- fidelity state of the rust face vs the reference

Execution of `2026-09-22-corrosion-full-port-plan.md` completed 2026-09-22 (commits `90df0a9..9713320` minus docs-only tail; WP0-WP9 each green-gated on landing). State: every reference mechanism that this host can prove is ported and PHYSICALLY tested (run markers, archives, compiled consumers, folded-proof negatives); what remains is exactly two buckets -- (1) environment-gated live legs (WP7 tool e2e pending crates.io egress + per-attempt user authorization for `cargo install`; conda R-12 intermittent on the pixi keeper) and (2) the status.md deferred register (Windows/Android derive chains, per-CFG import staging, macOS install_name, local rustflags, INHERITABLE, umbrella glue, file-sets, cargo-side version floor, LLVM mirror-by-choice, custom_target .json specs). The audit trail that got here is itself the invariant: four consecutive WPs caught stale or false anchors by grep-before-trust (including one retracted claim), and the suite doctrine -- never trust property text where a real run can prove it -- surfaced two shipped-then-fixed product bugs (dropped GENEX_EVAL wrappers, dev-profile dir). Fidelity claim boundary: parity is asserted per LEDGER ROW, never globally.

## D19: tool discovery is PREFIX-exclusive; live-tool authorization spent

First live-tool contact (2026-09-22) exposed a discovery-order bug before any test authored for it: `polyorch_rust_tool_bootstrap` searched PREFIX **plus** the ambient cargo locations unconditionally, so a globally installed real tool outranked the caller's explicit PREFIX (and its version gate). Fix: an explicit PREFIX now means "this tree only" (`NO_DEFAULT_PATH`, measured on 4.4.3); ambient fallback (`POLYORCH_RUST_BIN_DIR`/`CARGO_HOME`/`~/.cargo/bin`) survives when no PREFIX is given -- both shapes proven by the suite (stub legs pin PREFIX, e2e legs ride the ambient route). Also recorded: bootstrap's VERSION is dual-use (gate + cargo install specifier), hence full SemVer required (bare `0.29` rejected by cargo, measured); and FindRust-only consumers of `polyorch_rust_tool_bootstrap` miss the Helpers-defined setup guard -- include PolyOrchRustHelpers as the entry module (layering note, no code change; normal entry paths unaffected).

## D20: the standalone ctest entry is an indirect pre-project injection, not a root edit

The root project() declares LANGUAGES NONE (pure helper tree, correct), so CMake never probes a compiler and PlatformSupport's mkspec dispatch (external CxxKit-lineage rewrite, root territory) FATALs standalone. Root files stay frozen, so the standard cmake->ctest entry is restored INDIRECTLY: a generated `CMAKE_PROJECT_TOP_LEVEL_INCLUDES` file runs BEFORE project(), probes the host C++ driver (CXX env, g++/c++, clang++), and plain-sets `CMAKE_CXX_COMPILER_ID` -- a value project(LANGUAGES NONE) provably does not reset (measured 4.4.3). `scripts/ctest.sh` composes this and then drives a plain cmake configure + ctest run: offline 44/44, E2E 65/65; `scripts/inject.cmake` is the stable artifact (R1.4), the script regenerates it only when missing. When the external root rewrite lands (mkspec fallback or real language enablement), the inject becomes redundant and the script degrades to a plain wrapper. Skipped: touching the root to fix detection where it lives -- reserved for the rewrite owner. (Registration note: this entry was first lost when its recording batch aborted mid-script on an unrelated anchor mismatch -- caught by the Momus plan review of 2026-09-22.)

## D21: ctest names are namespaced polyorch::<stem>; case stems stay bare

All registered ctest names are `polyorch::<stem>` (`ff0217b`; single registration point in tests/CMakeLists.txt derives `_tname`, 1 add_test + 7 set_tests_properties reference it; matrix.sh's two -R regexes and the -E excl regex carry the prefix). The run.sh SKIP-contract lines and all case-file stems stay BARE -- the contract is stem-based, not ctest-name-based. Rationale: a host that add_subdirectories PolyOrch with an explicit BUILD_TESTS=ON would otherwise inject 44/65 bare `t-*` names into its ctest space, and add_test duplicates register SILENTLY (measured 2026-09-22: two same-name entries, no error). CMP0110 (3.19) officially allows `::` in names; this repo's floor is 3.22; ':' is literal in POSIX ERE so -R needs no escaping (measured: -N, -R, --show-only=json-v1 all clean on 4.4.3). Precedent: Catch2's `::`-namespaced test names; the top-level default guard (PROJECT_IS_TOP_LEVEL) already existed and governs the default-embed case. Revert = revert ff0217b.

## D22: cache-variable naming grammar -- PolyOrch_<domain>_<category>

One grammar for every user-facing cache variable, decided 2026-09-23 when the examples knobs were renamed: the category word is drawn from a closed set and its position is fixed.
* `PolyOrch_BUILD_*` -- "does this enter the build graph at all" (BUILD_EXAMPLES, BUILD_TESTS, BUILD_RUST_EXAMPLES, BUILD_PIXI_EXAMPLES). CMake's BUILD_TESTING lineage; nothing else may use BUILD_.
* `PolyOrch_*_ROUTE` -- "which toolchain route the graph uses" (PolyOrch_RUST_FROM remains the product-face route; PolyOrch_EXAMPLE_ROUTE system|pixi steers an example; PolyOrch_TEST_ROUTE buds the route into test children). ROUTE values are explicit enums -- boolean ROUTE options are rejected.
* external resources name the resource (PolyOrch_PIXI_MIRROR, PolyOrch_PIXI_CONFIG_FILE); test-surface knobs keep their TEST_ head (PolyOrch_TEST_E2E).
The rename this decision records (all born this session, zero external users): PolyOrch_RUST_EXAMPLES->BUILD_RUST_EXAMPLES, PolyOrch_PIXI_EXAMPLES->BUILD_PIXI_EXAMPLES, PolyOrch_EXAMPLE_PIXI->PolyOrch_EXAMPLE_ROUTE (boolean->enum), PolyOrch_TEST_RUST_FROM->PolyOrch_TEST_ROUTE. New variables must resolve their category word against this table before landing.


## D23: VSCode debug surface shape (2026-09-24, user-ruled item-by-item)

Run-targets only (1A: cargo fingerprint-hashes test binaries -- unknowable at
configure; per-`#[test]` debugging is rust-analyzer's lens, NOT reinvented;
1C whole-package-glob deferred pending a CodeLLDB program-glob measurement).
Tasks ARE generated (2A: preLaunchTask -> `<handle>-build` mediator; F5 =
incremental build of the REAL orchestrated artifact; the defaultBuildTask
alternative could build the whole ALL set). Default OFF at the library,
per-example opt-in (3B': a build system never rewrites a host's editor
settings unasked -- the xmake `project -k` explicit-generator precedent --
while examples demonstrate F5 out of the box); landing rule =
`<CMAKE_SOURCE_DIR>/.vscode` with `PolyOrch_RUST_VSCODE_DIR` as the
workspace-mismatch escape hatch (explicit over implicit, the same stance as
the rejected `FROM auto`). Scope nails: CodeLLDB only (cppvsdbg deferred),
cross-routed handles skip (remote debug deferred), managed-region writes
with a never-rewrite `.polyorch-new` fallback for markerless files.
Reference: plan `.omo/plans/2026-09-24-vscode-debug.md` (Momus OKAY, zero
MUST-FIX); product fixes the plan did not foresee: the latent never-defined
`_med` run-order edge, the CMP0219 macro-backslash policy need in cases, and
the MC genex-in-location expansion.


## D24: tree-button shadow targets retired; launch.json is the debug surface (2026-09-28, user ruling A)

D23-C adopted a shadow executable per run target (C stub + POST_BUILD
artifact adopt) to get native CMake Tools tree Debug buttons. Live
evaluation failed it: the button's provider chain is
cmake-tools-version-gated (cppdbg default needs cpptools; lldb only via
cmake.debugConfig.type, >=1.24), the pin is workspace-global (would
hijack real C++ debugging in embedded hosts), Run never builds first,
and the whole surface rests on cppdbg-era assumptions the ecosystem
research (corrosion/rust-analyzer/xmake-vscode/cmake-tools sources)
confirmed nobody else binds to. Ecosystem consensus: debug configs are
either ephemeral startDebugging (extension-side: cmake-tools,
xmake-vscode, rust-analyzer) or absent (corrosion); no build system
generates launch.json -- PolyOrch's persisted managed-region launch +
tasks generation is the strongest build-side form. Reverted in
e498f8a: shadow function, settings.json region, example LANGUAGES C,
shadow test legs. Deferred: .idea/runConfigurations half-automation
(waits on JetBrains making Custom Build Targets committable);
a PolyOrch VSCode extension is the only route to real tree buttons --
explicitly out of product scope (D16 CMake-helper form) unless
re-scoped by user.


## D25: flagship binding example scope -- L1 now, PyO3 later (2026-09-29, user ruling)

The multi-language-binding discussion landed as examples/rust-bindings
(WP14): one spine crate, two foreign surfaces (cxx bridge for C++ both
directions; extern "C" documented by cbindgen), consumed by the repo's
first real C++ executable and by a separate find_package project against
the installed header. Scoping facts (inventory, explore pass): the
consumer side of the whole repo was 100% C; install(EXPORT) is G1-not-
ported and PUBLIC_HEADER installs flat (nested cxx headers stay a build-
tree surface); Python tooling was zero-implemented. L2 (PyO3/maturin/
wheel + PYO3_* env plumbing) is DEFERRED to its own WP when a real
Python demand appears -- the cdylib kind mapping it needs already
exists. Ecosystem footnotes (librarian pass): cxx+PyO3 hybrids exist
downstream (huggingface/text-generation-inference trtllm backend,
ZettaScaleLabs/hiroz, pyo3-bindgen) but none drive them from CMake
targets; corrosion's own corpus is C++-consumers-only at the pin.
WP14 also closed two latent library gaps the example forced: the
cxxbridge/cbindgen/install TARGET outlets lacked fusion-prefix
resolution (PIT-29 outlets six+seven).


## D26: language bindings triangle delivered (2026-09-29, user ruling: the three language bindings are mandatory)

Python (PyO3), Node.js (napi-rs), and WebAssembly (wasm-pack -> npm pkg/)
are first-class binding surfaces with their own examples (rust-pyext /
rust-nodejs / rust-wasm, WP16-18) -- closing the L2 deferral D25 recorded.
Shape rulings inside the delivery: N-API's stable ABI means the nodejs
crate is a plain cargo build (node is a DEMO dependency, discovered from
PATH or a pixi env, never a build dependency); PyO3 uses abi3-py38 (no
interpreter headers, no libpython) with the interpreter resolved
explicit > pixi env > system and injected as PYO3_PYTHON; wasm ships as
wasm-pack pkg/ in bundler (web deliverable) + nodejs (local demo)
flavors, with --mode no-install and --dev required on restricted egress
(wasm-pack's default toolchain downloads hang) and wasm-opt satisfied by
a pixi binaryen env. Shared infra: install's LANGUAGE_PRODUCT renames
cdylib products to host-language conventions (libspine_py.so ->
spine_py.so / spine-node.node); polyorch_rust_pyext is the first
language-runtime surface verb. Network-bound tools (wasm-pack's own
toolchain downloads, binaryen) are the known egress hazard -- --dev +
no-install + pixi binaryen is the documented restricted-host set.


## D27: example target naming unified into the directory grammar (2026-09-30, user ruling: plan B)

The nine hand-literal CamelCase `PolyOrchExample*` convenience buttons were
the only naming style with no mechanism behind them while ~43 real targets
already followed the lowercase directory grammar. Mainstream survey
(llvm AddLLVM.cmake enforces lowercase `check-*` utilities with a
FATAL_ERROR, commit 8b90c3ed, fetched 2026-09-30; fmt
`add_library(fmt::${target} ALIAS ${target})` and googletest `GTest::gtest`
reserve CamelCase for the exported `::` namespace; Corrosion embeds behind
a `CMAKE_PROJECT_NAME` install guard, commit c4786e7): CamelCase belongs to
exports, never local targets. The buttons joined the grammar --
pixi-bootstrap / pixi-configure / pixi-workspace / pixi-env-run /
rust-import-pixi / rust-link-c-pixi / rust-bindings-standalone / rust-cross
/ rust-install-export -- and the same commit closed the prefix leaks (the
pyext demo through the helper, the nodejs demo by idiom; the
`PolyOrchExample_*` variable namespace deliberately untouched). Same day,
the rule consumed the remaining bare-CamelCase locals: `PolyOrchTest` ->
`polyorch-test` (beside its kebab siblings), and the root embed sentinel
`add_custom_target(${PROJECT_NAME})` ->
`add_library(PolyOrch::PolyOrch INTERFACE IMPORTED GLOBAL)` -- the
Threads::Threads package-existence form ('::' requires IMPORTED; real
targets cannot carry it, measured both ways). The boundary now reads:
kebab real targets, `::` for exported/imported names (PolyOrchRust::
{Rustc,Cargo} stay CamelCase by design), `PolyOrch_*` for variables and
options. Commit-time memory edits referenced this ruling as D27 but the
entry itself was never inserted (the 2026-10-08 doc-audit finding 1,
CRITICAL); this text was reconstructed from the commit record
(36a0582 / 4cf8271 / d0bc0ef). D28 later added the polyorch- namespace
over the whole fused surface -- including these button names -- and
`<dir>-all` aggregates moved to `polyorch-<dir>-all`.

## D28: fused-tree target namespace polyorch-<dir> + caller-project prefix key (2026-09-30, user ruling: plan 4)

Fused (host-embedded) rust example targets all carry the `polyorch-<directory>`
namespace: `polyorch-rust-basic-greet-build`, `polyorch-rust-basic-all`. The
standalone configure keeps bare names (`rust-basic-greet-build`) -- the
prefix exists ONLY in the shared host namespace, where an unprefixed
`<dir>-...` name invites collisions (a host with its own `pixi-configure`
or `rust-basic` directory is realistic; the validation host itself uses pixi).
Mechanics: the fusion loop resolves the prefix ONCE at loop entry, while
`PROJECT_NAME` is still the host's name -- the caller-project knob
`<HOST>_POLYORCH_TARGET_PREFIX` wins if defined (multi-checkout /
nested-embedding separation: each embedding project names its own
instance; a nested PolyOrch copy flips `project(PolyOrch)` and reads its
own keys, so it cannot be hijacked by the outer host's value), else the
default `polyorch-<dir>`. The helper's `_polyorch_rust_apply_target_prefix`
keeps a caller-knob fallback for direct-call consumers (no project()
flip). Knob keys live on the CONSUMER side (B_POLYORCH_TARGET_PREFIX --
the consumer states its own wish), following the LLVM_ENABLE_PROJECTS /
VTK_MODULE_ENABLE_<Module> subject rule; `${PROJECT_NAME}_...` derived
keys were rejected because PROJECT_NAME inside the 5 of 8 fused examples
that call project(<dir>) is the directory name, unreachable by the host.
The per-iteration `unset()` of the loop knobs is load-bearing (Momus
blocker 1: a one-shot trailing unset made `if(NOT DEFINED)` true only on
iteration 1 and silently merged aggregates through the helper's
NOT-TARGET guard). cbindgen aggregates follow the handle grammar
(`<handle>-cbindgen`), replacing the polyorch-cbindgen-<handle>-bindings
form that double-prefixed in fused trees; `polyorch-cbindgen-stub` (the
tool-stub echo marker) is UNRELATED and protected. Hand-written example
targets (cfn, cpplib, app, consumer, cleans, nodejs demo handles) route
through the same prefix idiom. Mainstream anchors: LLVM's enforced
lowercase check-* utilities; fmt/gtest real-name + ::alias split;
Corrosion's minimal-embedded-surface philosophy. (Momus-reviewed plan
2026-09-30; buttons already polyorch-* since the D27 grammar unification
-- buttons in examples/CMakeLists.txt keep their literal names, which now
read as polyorch-*.)


## D29: the node/npm bridge (WP-node-alpha, 2026-09-30 -- eight user-adjudicated rulings)

The fourth bridge (cargo / cmake / pixi / npm -- architecture.md's v0.1 list)
lands as cmake/PolyOrchNodeHelpers.cmake: five verbs (setup / import / build
/ test / run) over npm-pnpm workspaces. Eight rulings, walked one by one
(adjudication-walkthrough protocol, plan
.omo/plans/2026-09-30-node-bridge-alpha.md): (1) corepack abstraction -- the
project's own packageManager field picks the PM, PolyOrch never pins;
command shapes dispatch by PM (npm `run build -w <pkg>` vs pnpm
`--filter <pkg> run build` -- the filter precedes the subcommand, a
two-row template table). (2) dist/ convention + OUTPUT_DIR override;
reading package.json (main/module/exports) is MANIFEST READING (legal),
reading tsconfig/vite.config is CONFIG PROBING (forbidden). (3) long-lived
dev servers DEFERRED -- run is a one-shot verb; the orchestrator does not
run processes. (4) scripts dispatch only -- PolyOrch never invokes
tsc/vite. (5) node discovery = the rust-nodejs three-tier chain
(-DPolyOrchNodeExe= > PATH > pixi env glob) with precise half-missing
reporting (node found + PM missing names the missing half). (A1, amended by
measurement) sanitize '@org/pkg' -> 'org-pkg': '/'->'-', and the leading
'@' is STRIPPED -- add_custom_target rejects '@'-headed names outright
("reserved or not valid", measured); Momus had pre-approved exactly this
degradation. (A2) node owns PolyOrch_NODE_TARGET_PREFIX (its own knob, its
own apply helper -- the rust helper hardcodes the RUST knob and would
silently drop a node prefix); the fusion loop sets both knobs symmetrically.
(A3) t-rust-fusion pins the node family BOTH ways: targets asserted present
when node+pm reachable, asserted ABSENT when not (the degradation itself is
locked). Deliberate v0.1 edges: no install/EXPORT chain, no yarn/bun
specifics (corepack absorbs them), no VSCode debug surface
(backfilled by D33), no FROM pixi form. Implementation-smoke fixes beyond the plan: string(JSON) array
iteration is GET-with-index-path (MEMBER is OBJECT-key-only, measured);
PolyOrchNode_EXECUTABLE is CACHE FORCEd like the PM/FOUND knobs; the
PASSTHROUGH channel takes a proper list (pre-escaped ';' per _inc.cmake's
own note); the case reads the fixture's configure report from the
driver's persisted _configure.log (the rust-family convention). Fixture:
tests/fixtures/node-ws (zero-dependency node scripts -- the orchestrated
surface is the PM's workspace machinery, not a compiler); case:
t-rust-node (4 legs, `# requires: node` = node AND pm, contract skip at
the gate). (Momus-reviewed; NEEDS-WORK 3 text-level blockers fixed in-plan
before implementation.)

D29 FIELD CONTACT (2026-10-08, first external consumption): the validation
host's web-glue cargo step wired via polyorch_rust_build at TRIPLE
wasm32-unknown-unknown (route C skeleton -- bindgen/opt stay in the host
script for round 2). It earned its keep immediately: the cross naming table
rejected wasm triples outright, and the landing added the wasm family --
bin/cdylib -> <crate>.wasm, staticlib stays the elf-style archive, no C
linker plane -- scoped to the REAL rust wasm targets (emscripten rejected:
.cdylib is a .so pair there; the existing t-rust-executables negative leg
caught the first over-broad regex the same day -- reject-unknown doctrine
survived feature growth because a test pinned it).

## D31: the vendored xmake-skill set retires from the loader to the research zone (2026-10-08, user ruling "C" after lead analysis)

58 `xmake-*`/`xrepo-*` skills (C5-manifested, commit ef67caa) moved
byte-identical from `.agents/skills/` to `docs/reference/xmake-skills/`.
Rationale: after D16/D3-amendment retired the addon product form, the set's
entire remaining value is look-up-when-needed (D16's "reference corpus"
pillar, and the open O4 xrepo work), while its cost is per-session: 58
descriptions injected into every context turn plus routing noise in a
68-entry picker where ~58 candidates can never match the current domain.
Deletion was rejected (would orphan the reference-corpus promise and force
re-vendoring at O4); keeping them active was rejected (paying the tax for
a standby posture nothing uses). The manifest/attribution/license move
with the bytes; C5's cd path updated; the domain-leak gate's exception
disappears because the scanned surface no longer contains them -- its
provenance note moves to AGENTS anti-patterns as a location fact. Loader
list is now the 10 generic skills. (C4 note: the skill-phrase allowance's
`.agents/skills` scoping now matches exactly the ten generic files; the
retired set lives outside it and needs no allowance -- its English bytes
pass the plain scan from their new path.)

## D30: numbering continuity -- UNVERIFIED GAP, not a decision (2026-10-08, doc-audit follow-up)

decisions.md jumps D29 -> D31 with no D30 heading and no git-excluded plan-zone note
found either. Either a ruling was never recorded or a number was skipped. Nothing in
any live document REFERENCES "D30", so the gap is harmless; this stub exists to make
the gap itself recorded fact so future audits stop re-flagging it and so D31/D32 are
provably real decisions. If the original D30 content is ever recovered, replace this
stub with the actual record.

## D32: the python face (setup/run + VSCode debugpy, 2026-10-08, user-approved inline execution)

Scope (the D29 precedent held): `PolyOrchPythonHelpers.cmake` ships exactly two verbs --
`polyorch_python_setup()` (three-tier interpreter discovery; tier-a knob WINS over PATH,
following node's documented contract where its code inverted it -- known-deviation 1)
and `polyorch_python_run(TARGET/SCRIPT/NAME/ARGS/ENVS/WORKING_DIRECTORY)` registering
the `<t>-run` button (the rust face's grammar) with `-E env` as the build-time injection
point (no cargo-style host scrub: python legitimately needs PATH/HOME, the pinned
interpreter is the half that matters -- PIT-14's shape does not port). Test/wheel/import
verbs: NOT built, awaiting real consumer pressure (YAGNI, node-beta precedent).

Debug surface: the WP11 machinery was LIFTED into a shared `PolyOrchVSCodeDebugHelpers`
with a single-writer guarantee -- rust and python rows merge into ONE managed region in
launch.json (two face-owned regions would overwrite each other on reconfigure; found in
planning, reviewed as F1); tasks.json stays rust-only with its marker string byte-frozen
(existing user trees must keep parsing, else PLACED_NEW orphans), and a one-shot
legacy-marker migration converts pre-D32 launch regions in place (proven live). Python
rows are debugpy (`type: "debugpy"`, discovered interpreter in `python`, ENVS into
`env`, no preLaunchTask -- no build step), gated by PolyOrch_PYTHON_VSCODE_DEBUG (OFF
default, examples opt in). Spec grammar NAME|INTERP|SCRIPT|CWD|ARGS|ENVS with '|
rejected at every boundary.

Host-contact fixes (round 2, same day, user-reported on the real fused tree,
commit 02df192): run() (a) now sets FOLDER via the rust helper's idiom
(consume PolyOrch_RUST_FOLDER_ROOT, explicit FOLDER arg wins) -- the
buttons had been landing in the directory-default IDE group; pinned by a
File API codemodel leg in t-rust-fusion ($ref folder object, equality on
fused-host/examples/python-basic); (b) the debugpy row label defaults to the
PREFIXED handle without the verb suffix (bare 'greet' collided with the
rust rows' namespaced convention in the same launch.json; explicit NAME
still wins) -- pinned in t-python-knobs leg2. Test-authoring catches of the
round: codemodel folder fields are $ref objects; PASSTHROUGH appends expand
variables at APPEND time (scratch-first ordering, the #22 prologue lesson
in miniature).

Fused entry: examples/python-basic is the loop's tenth subtree (knobs set/unset
symmetrically per PIT-35; D32 caller key <HOST>_POLYORCH_PYTHON_TARGET_PREFIX honored by
_polyorch_python_apply_prefix). Button: polyorch-python-basic-greet-run.

Verification layers (all live on the build host): offline stub-driven contract
(t-python-run: argv/env effects asserted, not rule text), the naming trio
(t-python-knobs: rust-knob non-leak / python prefix / caller-key), the live debug chain
(t-python-vscode: rows tables, merged region, migration, gate both polarities) and the
REAL user chain (t-python-vsdbg: standalone python3 run, 3x "hello, fused!",
byte-idempotent launch.json, zero tasks footprint), plus the honest proof-of-breakpoint
(t-python-dap: pure-stdlib DAP client; contract-SKIP on this host, exact lines recorded
in bc85202 -- the leg is executed nowhere yet). Fusion sentinel extended (t-rust-fusion).
Suite 57/0/29 fail=0.

Product findings from contact: (1) CMake NO_CACHE find_program SHORT-CIRCUITS when the
result variable is already defined, even to "" -- the defensive set(_py "") blinded tier-b
in a real standalone configure (controlled t5/t6 isolated it in one round; the node face
never pre-sets and carries no bug); (2) the planned button grammar run-<t> was stale
against rust run():1867's <handle>-run -- aligned before first commit; (3) examples need
project() placement after the opt-in gate (rust-basic idiom) or discovery dies on
REQUIRED. Incident: the Momus review dispatch role-crept into implementing + committing
(PIT-45; archived, reverted; edit-safety #25 written).

## D33: the node face's debug surface (the D29 deferral backfilled, 2026-10-08)

D29 shipped the npm bridge with "no VSCode debug surface" as a declared v0.1
edge; the python round (D32) proved the debug methodology end to end, and the
user directed the node backfill. Ruling (the one design fork put to the user):
the debug entry is the package ENTRY (main -> module -> exports["."],
`_polyorch_node_read_entry`), not an npm script -- option A. The
runtimeExecutable=npm script shape (option B) was rejected because the
corepack abstraction gives two PM command shapes (npm `-w` vs pnpm
`--filter`) and dev-server scripts are not debug targets (D29 ruling 3);
scripts dispatch stays build-graph-only. TS debugging needs no separate
mechanism: js-debug launches the built entry and maps breakpoints back
through source-map globs -- and js-debug is VSCode built-in, the only family
of the three needing no extension install (rust: CodeLLDB, python: debugpy).

- **gate-first** `polyorch_node_debug`: with the gate OFF the verb returns
  before ANY validation -- the strongest zero footprint (a ghost handle
  passes in silence). The loud contracts (unknown handle, no runtime, empty
  entry, reserved '|', ENVS shape) hold inside the gate-ON domain. This
  OVERRIDES the review-interval proposal to make validation unconditional
  (that law belongs to `polyorch_node_run`, a build verb; registration is a
  debug-surface side effect). Review provenance: Momus x3 + an independent
  Oracle pass; the plan's test machinery was rewritten around three measured
  findings (see the doctrine below).
- spec grammar `NAME|RUNTIME|PROGRAM|CWD|ARGS|ENVS|OUTFILES` (seven fields,
  six '|'); RUNTIME is pinned at registration (three-tier doctrine: the VSCode
  GUI PATH will not know a pixi-env node); program = PACKAGE-ROOT-relative
  join (npm `main` semantics; `./` stripped, IS_ABSOLUTE verbatim; dist/ is
  NEVER re-added -- the review-round formula bug, pinned by a `dist/dist`
  negative and a real-file EXISTS); per-row default `outFiles` glob;
  three sources now merge into ONE managed launch region through the single
  writer (rust+python+node), tasks.json stays rust-only with the byte-frozen
  marker; `_ext` is three-state (a node-only tree never names CodeLLDB).
- **option-placement deviation**: `PolyOrch_NODE_VSCODE_DEBUG` is declared
  AFTER the module's own cmake_minimum_required, unlike the python/rust gates
  at file top (they carry no cmr). Measured: under CMP0077 OLD option()
  WIPES a consumer's preceding set() -- the standalone opt-in would silently
  no-op, and no node-less host could ever see it. `examples/node-web` gained
  the missing cmake_minimum_required header line for the same reason.
- FOLDER consumed at the four node creation sites (import loop, build, test,
  run) -- the python 02df192 idiom. Deliberate behavior change: standalone
  node-web loses its relative-path FOLDER fallback (standalone stays unset,
  family law).
- **test doctrine from this round (measured on cmake 4.4.3)**:
  (1) `cmake_language(DEFER)` is ILLEGAL under `cmake -P` (hard error) --
  script-mode cases include faces with the gate OFF and raise it per branch;
  a subleg child handed the gate on the command line dies at the tail hook
  BEFORE its guard, so rc-only assertions go green on the wrong death --
  FATAL sublegs must assert the child's STDERR TEXT.
  (2) The zero-footprint proof must ride a real configure (the hook never
  registers -> no file); a direct generator call always writes (region_write
  has no empty-rows short-circuit).
  (3) CMake lists do NOT drop empty elements under REPLACE+GET (the
  grammar-collapse hypothesis was measured false; middle and trailing
  empties survive).
  (4) Every configure-mode product leg needs an offline twin (stub tier-a
  knobs) or it never executes before commit -- the node family's
  requires-gated legs are exactly the CI-only detonators.
- Three-face hook ORDERING defect (pre-existing since D32 -- python shared
  it -- FOUND via the user's node-web report 2026-10-08, FIXED): the hook's
  `cmake_language(DEFER CALL ...)` deferred to the END OF THE INCLUDING
  DIRECTORY, so the first opt-in subdirectory fired the generator before
  later siblings registered their specs -- their rows were orphaned forever
  (reproduced offline: python-earlier dirA + node-later dirB landed
  "python 1, node 0"). All three faces now defer with DIRECTORY
  "${CMAKE_SOURCE_DIR}" -- a single write at the true end of configure,
  any include order, any directory depth. Pinned by t-node-vscode's
  cross-sibling ordering leg (scratch order-host, stub knobs, both rows
  asserted; the leg also carries the written-CMakeLists escaping traps:
  every ${VAR} destined for the child must be escaped \${VAR} at write
  time -- three hits while authoring it).
- beta list (not built, not claimed, no corpus): browser debug (pwa-chrome),
  ts-node direct, preLaunchTask auto-build, jest/vitest debug, attach mode,
  js<->native mixed debug, sourcemap path-rewrite surface, FROM-pixi node
  form. Known-deviation 2 inherited: values with embedded quotes/commas are
  unescaped (same class as rust/python).
- `examples/node-web` registers hello-ts ONLY -- @scope/hello-js declares no
  entry; registering it under the baked-ON gate would FATAL every
  node-having host (review round B1). Top-level `"exports":"x.js"` shortform
  remains unresolved by the shipped read_entry (v0.1 contract; import falls
  back to the dist directory).
- Field status: the live legs (t-node-debug, nodeknobs label pin, fusion
  node codemodel folder pin) contract-SKIP on this node-less host -- exact
  lines recorded in their commits; the offline stub-driven polarity pair
  executes the same hook->DEFER->generator chain here in both polarities.

D33 rounds 2-3 (user-found, 2026-10-08 late day; lessons at PIT-46..PIT-50):
- Gate symmetry: node-web/python-basic had ridden the RUST option + cargo
  probe since their D29/D32 entry (borrow misdocumented as design); the
  corrected shape is one PolyOrch_BUILD_{NODE,PYTHON}_EXAMPLES option per
  family (rust/pixi symmetry), pinned both directions by the new
  t-examples-gates (negative proof observed -- C0). examples/README.md now
  carries the family-flag table that made the absence explicable.
- Host became a node host mid-round (`pixi global install nodejs` -- network
  reached conda-forge after all): node 26.10.0 / npm 11.19.1 in ~/.pixi/bin.
  Flip-day caught two bugs at once (PIT-49): the tier-a knob ORDER inversion
  in node setup (PIT-48, comment promised knob-wins, PATH actually won --
  fixed to python's shape; t-node-vscode's stub-vs-real leg is the pin) and
  the missing `HINTS ~/.pixi/bin` on the corepack/npm discovery tiers
  (PIT-47 -- the user's PATH-less interactive shell saw a silent zero-target
  configure; verified fixed with the bare-PATH user-shell simulation).
- Suite numbers post-flip NOT yet re-stamped at the time of writing: the
  offline/matrix re-run with node present is an open item (skip counts move;
  t-rust-nodesetup-missing flips to its own contract-SKIP polarity).

## D34: node source-level debug carrier is node-basic; node-web keeps the dist convention (2026-10-09, user-adjudicated A+C split)
- **Context**: user report "examples/node-web/src is empty, cannot test VSCode breakpoints". Investigation: the empty `packages/*/src/` dirs are by design (git tracks no files there; the packages' build is the package-root `gen.js` emitting `dist/index.js` -- D29 "scripts ARE the build"). The debug surface pointed at the BUILT entry and that built entry itself crashed at runtime (`gen.js` inlined `JSON.stringify(module)` -- functions dropped -- so `greet()` threw TypeError). The debug acceptance fixture was `tests/fixtures/node-debug`, not the example.
- **Decision**: (a) NEW `examples/node-basic` -- the source-level js-debug carrier, symmetric to rust-basic(CodeLLDB)/python-basic(debugpy): package `main` -> `src/index.js` (plain JS), so `polyorch_node_debug` resolves the launch `program` to the real source; no build, no source maps, no dependencies. NodeHelpers unchanged -- `_polyorch_node_read_entry` already resolves source entries. (b) node-web KEEPS `main=dist/index.js` (D29 acceptance, guarded by t-node-vscode entry-grammar); its gen.js bug fixed minimally to emit a runtime `require("../hello-js/dist/index.js")` (workspace edge preserved, artifact now runs). (c) the fixture-vs-gitignore CHECKED-IN contradiction fixed by a NARROW negation scoped to `tests/fixtures/node-debug/dist/` only (build trees stay ignored). (d) real-launch e2e leg (`t-node-basic-launch`): `node --inspect-brk=127.0.0.1:0` (ephemeral port announced on stderr -- DevToolsActivePort is NOT written by node 26.10.0, measured), condition-poll the log, assert `/json/list` (curl `--noproxy "*"`) names the source file, kill-by-PID and reap.
- **Rejected**: pointing node-web's main at src (would dissolve the D29 dist-convention demonstration); custom source-map machinery (YAGNI for plain JS).
- **Reference**: user rulings via question tool 2026-10-09; t-node-basic / t-node-basic-launch / t-examples-gates node-basic legs; fused grammar unchanged (D28).

## D35: IDE source-mount parity -- node and python faces mount sources like rust (2026-10-09, user-adjudicated "both faces full parity")
- **Context**: user-found gap -- the rust face mounts crate sources onto every verb node (mediator/-run/-test) as HEADER_FILE_ONLY SOURCES (cargo-metadata-authoritative list + manifest + lockfile; COSMETIC-ONLY argument exempts GLOB-caution); node/python faces had zero `target_sources`/`SOURCES` presence -- IDE target trees showed rust targets expanded and node/python targets bare. Breakpoint UX note: the F5 launch rows (D33/D34) were always functional; the missing half was "open the file from the IDE tree to set the breakpoint".
- **Decision**: `_polyorch_node_mount_sources` / `_polyorch_python_mount_sources` copy the rust idiom (HEADER_FILE_ONLY ON + family `_SOURCES_PLAIN` escape + HARD-tripwire-at-creation/SOFT-at-reuse + NO_SOURCES on the standalone verb). No metadata authority exists for npm/pip package dirs at configure cost -- the list is a filtered CONFIGURE_DEPENDS glob (display-only makes the precision bar a vendor-tree guard, not a correctness one): node = js/mjs/cjs/ts/tsx/jsx minus node_modules|dist|build|dot-dirs + package.json + lockfiles (package-lock/pnpm-lock/yarn); python = recursive *.py minus venv|.venv|env|build|site-packages|__pycache__|dot-dirs + pyproject.toml/setup.py/requirements.txt (existence-gated). Mount points: node at the four creation sites (import per-member mediator, build, test, run -- same anchors as the D33 FOLDER sweep), python at the run-button site (its only target; root = WORKING_DIRECTORY when set, else caller dir -- WDIR is the crate-dir analogue). workspace-root build() honestly shows member files via the recursive glob (no member recursion problem at per-member sites).
- **Reference**: cases t-node-sources (fixture tests/fixtures/node-ide-sources; mount+exclusions+NO_SOURCES+verb parity+PLAIN polarity+mediator still builds) and t-python-sources (glob+vendor-guard+both polarities+NO_SOURCES+WDIR root+SOFT-not-fatal); precedent copied = t-rust-ide-sources sources.txt channel + t-node-debug/t-python-vsdbg direct -S/-B shape. GATE ALL GREEN after: offline 67/0/26, e2e 89/0/4, matrix 6/6, ctest x2, C1-C6.
- **Deviation from rust (documented)**: no per-manifest cache was ported -- rust's cache exists because it runs `cargo metadata` (an external process); a CMake glob is configure-native and caching it would be dead machinery. The glob IS the authority; display-only is what makes that legitimate.


## D36: remote-button path repair, per-directory FOLDER mirror, examples watchdog (2026-10-09, user-adjudicated one by one: 1-A / 2-B / 3-B)
- Ruling 1 (A): the D27/D28 rename sweep had left 6 remote buttons in
  `examples/CMakeLists.txt` pointing their `-S`/`-P` paths at nonexistent
  `polyorch-*` directories (the real dirs are the bare D27 grammar: pixi-bootstrap,
  pixi-configure, pixi-workspace, pixi-env-run, rust-install-export, rust-cross).
  The 7 path strings were corrected to the directory grammar; target names keep
  the `polyorch-` namespace (D28). The dangling `--target pixi-*` commands and
  umbrella names in `examples/README.md` were aligned to the registered targets.
- Ruling 2 (B): `t-examples-gates` gained leg 3, a scanner that reads
  `examples/CMakeLists.txt`, regex-catches every `${CMAKE_CURRENT_SOURCE_DIR}/<seg>`
  reference and asserts each names a real path, with a fail-closed tripwire when the
  scan matches nothing (no vacuous green). New buttons are covered automatically.
  Negative proof observed: planted bad path -> red, restored -> green.
- Ruling 3 (B): the 9 remote buttons' FOLDER mirrors the directory each drives
  (`${PROJECT_NAME}/examples/<dir>`), unifying the rule with the fusion loop's
  `PolyOrch_RUST_FOLDER_ROOT` grammar: one IDE group = one disk directory.
  No test pinned the old flat value (t-rust-fusion asserts button registration,
  not FOLDER); VS Code's cmake-tools ignores FOLDER -- the gain is VS/Xcode trees.
- Found during verification and fixed in the same round: (a) `_requires.cmake`'s
  node capability probed npm/corepack PATH-only while node got the product's
  three-tier discovery -- a pixi-global npm in `~/.pixi/bin` desynced the gate and
  false-failed `t-rust-fusion`'s else-leg ("degradation broken"); the PM probe now
  mirrors the tiers (PIT-58). (b) the rust-wasm example rules omitted their own
  documented restricted-egress flags: both wasm-pack rules now pin
  `--mode no-install --dev`, plus a wasm-bindgen presence gate (the example
  self-degrades; the case probe mirrors it). Its first post-flip execution had hung
  on wasm-pack's implicit wasm-bindgen download (PIT-55 class recurrence).
- Suite: offline 67/0/26 (matches the D35 baseline; node + wasm legs EXECUTE, no
  desync skips).
- Escalation landed (user-approved, same round): t-examples-gates gained leg 4 --
  it greps examples/README.md for `cmake --build build --target <name>` commands
  and asserts each name is a registered target in a pixi-equipped configure (a
  new hostcfg("buttons") gate). This closes the README-fossil class leg 3 could
  not see: leg 3 checks path strings inside CMakeLists, leg 4 checks the target
  names the README tells users to type. Vacuity tripwire (no --target command =
  FAIL, not silent pass) + pixi-absent graceful degrade (leg 4 skips its own
  checks with a STATUS note, never faking a green). Negative proof observed:
  a deliberately-fossil name made it go red, restoring made it go green.

## D37: node TS debug surface -- built-entry + source maps (A-full); native type-stripping demoted to a documented affordance (2026-10-09, user-ruled "Plan A full + install tsc" -- translated from the user's Chinese; LANDED 2026-10-09, SDD)
- User preference recorded with the ruling: questions framed as best/elegant/complete solutions
  expect the production-complete answer. A persistent minimal-effort persona mode (ponytail)
  prunes gold-plating INSIDE the chosen design -- it must never anchor the headline
  recommendation on the shortcut (the first pass led with "recommend B" and needed an
  explicit 'do not govern by laziness' correction -- translated from the user's Chinese --
  to move to A-full; one wasted round).
- Ruling: TS debugging ships in the industry-standard shape -- package main -> dist/index.js,
  tsc emits dist/index.js.map, js-debug maps breakpoints back through the row's outFiles
  (the emitter already defaults it to ${_dir}/**/*.map). tsc is three-tier discovered
  (PATH -> ~/.pixi/bin -> pixi-env glob, the node face's own idiom); the host gains
  `pixi global install typescript` (user-authorized; probe measured: no tsc anywhere before).
- B (node >=23.6 native type stripping, main -> src/index.ts, zero build) is NOT deleted but
  demoted to a documented dev-fast-path: the mechanism already permits it at zero cost
  (`_polyorch_node_read_entry` is extension-agnostic -- a .ts main flows straight into the
  launch program). It is disqualified as the face: erasable-syntax-only, a runtime version
  floor, and an unverified js-debug .ts binding (TBD). C (tsx/ts-node loader) rejected:
  ARGS maps to program args, not node flags -- no runtimeArgs slot, would need env plumbing
  plus an external dep.
- Approved scope, UNIMPLEMENTED as of this entry (4 tasks open, no code landed -- do not
  quote suite numbers for this feature): (1) new example examples/node-ts-basic, the 12th
  fused entry and TS sibling carrier of node-basic under the D34 carrier grammar; node-web
  and hello-ts stay as-is (the zero-dependency PM-machinery identity is kept intact);
  (2) node debug spec grammar 7 -> 8 fields (BUILD_TARGET stamped at registration, same
  reasoning as RUNTIME) + explicit "sourceMaps": true + preLaunchTask in generated rows;
  (3) tasks.json single-writer region merges node rows after rust (marker STRING unchanged);
  (4) t-node-debug/t-node-vscode updated, new t-node-ts-debug e2e (real tsc build; dist+map
  exist; .map sources=src; row content; CDP-level breakpoint binding remains a documented
  manual line -- honest scope); (5) examples/README row, guarded by the leg-4 watchdog.
- Context: the field symptom that surfaced the question (hello-ts debug row missing) was the
  DEFER-orphanning defect, fixed separately by 8a02fe9 (PIT-60); the TS DEMO gap was a
  fixture gap. Both were real and distinct -- neither was the other's explanation.

LANDED (2026-10-09, subagent-driven): all six plan tasks executed and reviewed.
New example `examples/node-ts-basic/` (TS carrier: main->dist, `tsc` emits
`index.js.map`, `polyorch_node_debug` row carries sourceMaps + a preLaunchTask
that rebuilds the `node-ts-basic-build` mediator; three-tier tsc prereq probe,
STATUS-degrades when absent). Library: `_polyorch_node_vscode_rows` widened to a
3-arg (LAUNCH_OUT TASKS_OUT) rust-parity shape; `polyorch_node_debug` stamps the
8th spec field `${_dh}-build`; sourceMaps rides every node row unconditionally,
preLaunchTask + a tasks.json row ride only when field 8 is present (length-guard
keeps legacy 7-field rows rendering); the single-writer tasks region now merges
rust-then-node (marker string byte-frozen). Tests: t-node-vscode/t-node-debug/
t-node-basic polarity flipped + pins (sourceMaps, preLaunchTask, the load-bearing
`--target`, OFF-leg tasks-absence); new t-node-ts-debug.cmake (live tsc build +
dist/map/demo + byte asserts, negative proof on a /tmp copy). Verification:
scripts/gate.sh one-shot ALL GREEN -- C1-C6, offline 68/0/26, e2e, matrix 6/6
(incl Ninja Multi-Config), ctest standalone+e2e. tsc installed host-side via
`pixi global install typescript` (6.0.2). Native type-stripping (route B) stayed
documented-fallback only, as ruled. Deviation noted: the carrier opts in via a
normal (not cache) `set(PolyOrch_NODE_VSCODE_DEBUG ON)`, which shadows -D=OFF, so
t-node-ts-debug's OFF-polarity leg exercises a scratch copy with the opt-in line
stripped -- same zero-footprint assertion at the library-default OFF.
POST-REVIEW USER-FOUND FIX (2026-10-10, systematic-debugging + PIT-62): the real
VSCode F5 broke -- `cmake --build --target <ts-mediator>` -> `npm run build` ->
`tsc: not found`, because the node `build()` mediator ran the PM bare and the npm
script resolved `tsc` from the invoker's AMBIENT PATH (a VSCode task shell lacks
the tool dir). The e2e had MASKED it by injecting the tool dirs into its own build
env -- a green e2e that said nothing about the user's shell. Root-cause class fix
(PIT-48 sibling sweep): a `_polyorch_node_rule_path` helper wraps ALL FOUR PM
mediators (import-member/build/test/run) in `cmake -E env "PATH=<node>:<pm>:$ENV{PATH}"`
(node-face twin of rust PIT-14 host-env isolation), and the example declares
`PolyOrchNode_BUILD_ENV_PATH=<tsc dir>` for tools not co-located with node. The e2e
build leg now runs under `PATH=/usr/bin:/bin` (RED pre-fix, GREEN post) as the
regression lock. Verified: offline 68/0/26, e2e 90/0/4, matrix 6/6, all node cases,
C1/C4/C6; node-web's `node gen.js` sibling case also fixed. Windows caveat noted
(`$ENV{PATH}` with ';' splits a cmake list under -E env) -- node family is
Linux-first (O6), for the future cross round.

PIT-63 follow-up (2026-10-10, user-found grey TS breakpoint): the D37 default `OUTFILES`
was `${_dir}/**/*.map` -- wrong per js-debug (outFiles matches GENERATED .js). Fixed to
`${_dir}/**/*.js` + node_modules exclusion, restoring breakpoint prediction so the
import-time-computes carrier binds before running. Regression-pinned in t-node-ts-debug
byte-exact. offline 68/0/26, matrix 6/6. User CONFIRMED VSCode F5 binds+pauses after reconfigure (2026-10-10): grey-breakpoint cleared at the GUI layer.
## D38: Example debug-depth round -- vendored-lib F5 stories + python JUST_MY_CODE (2026-10-10)
- **Decision**: deepen the node/python examples so the debug surface is exercised for real scenarios: npm `file:`-linked vendored libraries (JS source-breakpoint story; TS prebuilt dist+map story), multi-file src everywhere, node-web cross-package OUTFILES, and one product change: `polyorch_python_run` gains single-value keyword `JUST_MY_CODE` -- spec grows a 7th field, renderer flips `"justMyCode"` to false ONLY on literal OFF, legacy 6-field rows and default-ON rendering byte-unchanged (guarded by list-LENGTH; equality-pinned by canned legs in t-python-vsdbg).
- **Rationale**: the examples' deliberate zero-dependency shape made library/dependency breakpointing untestable and left debugpy library-stepping with no mechanism at all (hardcoded true). `file:` installs are registry-free (offline invariant intact, `.npmrc` + `--no-audit --no-fund` belt); node's symlink+realpath behavior makes the vendor dir the natural breakpoint home and the default outFiles glob already covers it.
- **Reference**: plan `.omo/plans/2026-10-10-example-debug-depth.md` (Momus-approved); execution 13c2812..10ffdef; stdlib `json` chosen as the python library-stepping demo (no interpreter deps, debugpy treats stdlib as not-my-code).
