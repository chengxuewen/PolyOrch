# PolyOrch — Pitfalls

> Format (five parts, per `.agents/rules/common/lesson-memory.md`):
>
> ```markdown
> ## PIT-{n}: Title (date)
> - **Symptom**: ...
> - **Root cause**: ...
> - **Solution**: ...
> - **Verification**: ...
> - **Forbidden**: ...
> ```

## PIT-1: A grep gate that scans `.agents/memorys/` self-matches (2026-09-18)

- **Symptom**: the C1 brand-casing check in `conventions.md` returned FAIL while `docs/` had zero real violations. Every hit landed on the very lines of `conventions.md` / `pitfalls.md` that list the counter-examples.
- **Root cause**: rule and pitfall files must **enumerate the forbidden spellings** (`Polyorch` / `polyOrch` / `POLYORCH`) as counter-examples, but the check's scan scope included `.agents/memorys/`, so the counter-examples tripped their own gate. Adding `--exclude=<self>` only plays whack-a-mole: any newly written file that records the counter-example triggers it again.
- **Solution**: scope brand/naming gates to the **content directories** (`docs/` and the future source tree). Do **not** scan `.agents/memorys/`.
- **Verification**: `grep -rqE 'Polyorch|polyOrch|POLYORCH' docs/ && echo FAIL || echo PASS` -> PASS
- **Forbidden**: writing a "scan the rules directory" gate whose literal pattern matches the rule file, without excluding the rule file itself.


## PIT-2: An authoritative document carried an unverifiable external claim (2026-09-18)

- **Symptom**: `docs/whitepaper.md` §7.1 and §8.1 list "Guild" as a "Rust-native polyglot monorepo orchestrator" with a `guild.toml` config. Targeted verification found no such project: no matching repository, zero public code-search hits for `guild.toml`, and the name collides with `guildai`, an ML experiment tracker.
- **Root cause**: the whitepaper's competitor table was written from plausibility rather than verification. Each entry is a one-line claim, and several of them are genuine projects (Aster resolved to a real repository), which made the single fabricated entry hard to spot by inspection alone.
- **Solution**: before any external project claim propagates from the whitepaper into derived docs or profiles, resolve it against a primary source (its own repository or official documentation). `docs/reference/README.md` records the verified anchors and the one unverifiable entry.
- **Verification**: every project named in the whitepaper must resolve to a repository or official docs URL. Re-run that check whenever a new project name enters the whitepaper.
- **Forbidden**: writing a profile, comparison row, or benchmark for a project that cannot be resolved to a primary source.

## PIT-3: Impossible constraints in a delegated prompt cause silent agent loops (2026-09-18)

- **Symptom**: four agents in a row failed to translate `docs/whitepaper.md` (423 lines, 191 Chinese lines) into English. One ran 9m29s and produced nothing; its reasoning was an endless search for a box padding that does not exist. A 176-line sibling file converted without trouble under the same prompt style.
- **Root cause**: the prompt required two mutually exclusive things at once: keep the four-layer ASCII diagram's original 65-column outer box, AND translate the four adapter boxes' labels to English. English is roughly twice as wide as CJK, so four boxes each needing about 19 columns cannot fit in the roughly 50 columns available. The constraint was unsatisfiable, and the agents had no instruction to report impossibility instead of looping.
- **Solution**: (1) check that a geometry or format constraint is satisfiable before delegating it; (2) generate width-sensitive ASCII art programmatically so padding is computed, never eyeballed; (3) instruct agents explicitly to report impossibility rather than iterate. Translating CJK diagram labels requires WIDENING the box (here: 65 to 79 interior columns, 81 total), not transliterating in place.
- **Verification**: every line inside a ```text fence must have identical display width, counting a CJK glyph as 2 columns and a Latin character as 1. Check with a width function before and after any diagram edit.
- **Forbidden**: delegating a large mechanical rewrite together with an unresolved geometric constraint on the same file; assuming CJK-width ASCII art survives translation at its original dimensions.

## PIT-4: A single-gate "clean" count over-reports by more than 4x (2026-09-20)

- **Symptom**: a sibling-repository skill scan reported "23 candidates are gate-clean" and then "5 directly usable" from the same data. The first number counted only freedom from the removed WebRTC domain.
- **Root cause**: the scan tested **one** gate -- the domain-leak pattern -- and reported the survivors as clean, because the most familiar gate was mistaken for the complete constraint set. Two other binding constraints were never applied: C4 (English-only artifacts) and portability (a copy that hardcodes its own repository's name). 12 of the 23 failed C4, meaning Chinese text was one step away from being adopted into an English-only repository by a count that called it "clean".
- **Solution**: before reporting a survivor count, enumerate **every** gate that applies to the artifact class and apply them together. For an adopted or vendored file the applicable set here is the domain gate, C4, self-reference, and the target format (`name` equals the directory name). Report the count after the last filter, and say how many filters were applied.
- **Verification**: three checks, one verdict -- `grep -rliE -e mediaservo -e mediasoup -e webrtc -e 'sfu-' -e msrtc <dir>` is empty, AND the same tree has zero CJK lines, AND zero occurrences of the source project's own name.
- **Forbidden**: calling an artifact "clean" or "gate-clean" after testing a single gate; reporting a candidate count derived from a partial filter set without naming how many filters produced it.

## PIT-5: A version string was read as a dev-branch marker, convicting two correct documents (2026-09-20)

- **Symptom**: an audit declared a CRITICAL contradiction -- "v0.1 needs a master-build Xmake, but D4 pins the conda-forge release `xmake-3.1.1`". The premise was that the local binary `v3.1.1+20260827` was "a **master build**: the `+date` suffix is the dev-branch marker, not a release tag". That premise was written into `decisions.md` D3 earlier the same day and then quoted back as established fact.
- **Root cause**: a version string was interpreted from a guess instead of evidence. Xmake's `+` suffix is not one thing: `+<yyyymmdd>` is a **build date** (releases carry it too), while `+master.<sha>` is what a master-branch build looks like. The local `+20260827` matched v3.1.1's release date exactly (2026-08-27, the same day as the conda-forge package) -- a fact that was available and not checked. Two documents that were right (D4's conda-forge pin, and the whitepaper's "v3.1.1 introduced the Addon extension system") were judged wrong on the strength of the bad premise.
- **Solution**: never derive a capability or a provenance claim from the *shape* of a version string. Install the exact artifact the design pins and run the command. Resolution: `pixi exec -c conda-forge --spec "xmake=3.1.1" -- xmake addon --list` exits 0 with the full catalogue, and that package reports `v3.1.1+master.3ba37a0d4` -- so the pin in D4 is sufficient and the addon subsystem ships in v3.1.1.
- **Verification**: `pixi exec -c conda-forge --spec "xmake=3.1.1" -- xmake addon --list; echo $?` must exit 0 and print the addon catalogue. Re-run it whenever a version, a pin, or a capability claim changes.
- **Forbidden**: inferring build provenance or feature availability from the shape of a version string; recording such an inference in memory as a verified finding.

## PIT-6: `pixi run` forwards every argument after the task name to the task (2026-09-21)

- **Symptom**: `pixi run <task> -m <manifest>` does not select the manifest — the `-m <manifest>` tokens are appended to the task command itself (measured on pixi 0.78.0: `echo` printed the flags).
- **Root cause**: `pixi run` treats everything after the task name as the task's argv; per-subcommand options (`-m`, `--config-file`) must precede it. The generic `_polyorch_pixi_command()` builder appends context flags *last*, which is correct for `install`/`update` (no trailing positionals) but wrong for `run`.
- **Solution**: `polyorch_pixi_bootstrap()` builds its smoke `pixi run` command by hand with the context flags before the task name (see the `[3/3]` block in `cmake/PolyOrchPixiHelpers.cmake`).
- **Verification**: `bash tests/run.sh` with `POLYORCH_TEST_E2E=1` — `t-bootstrap-e2e.cmake` smoke-runs a task through the full path.
- **Forbidden**: routing any future `pixi run <task> <args>` wrapper through `_polyorch_pixi_command()` without moving context flags before the task name.

## PIT-7: if() assertion macros in cmake tests: three parse traps that fake a suite green or red (2026-09-21, rewritten after two wrong diagnoses)

- **Symptom**: `ck()`-style assertion macros misfire in ways that look random: a true expression fails; `EXISTS` reports a file missing while `ls` shows it; `ck(${rc} NOT_EQUAL 0)` dies with "Unknown arguments specified" even though the rc is right; `cmake -E test -x` returns 1 on an executable file.
- **Root cause** (measured on CMake 4.4.3; all three are distinct):
  1. Passing a whole condition as ONE quoted string (`ck("_x MATCHES \"^a$\"")`) makes `${expr}`/`${ARGN}` expand to a single token -- if() never re-splits it into a comparison chain. Bare tokens only.
  2. After expansion, `"` characters inside a value are LITERAL, not quoting: `ck("EXISTS \"${p}\"")` hands EXISTS a path that literally contains quotes -> false. Argument-consuming operators (EXISTS/IS_DIRECTORY/...) must receive real arguments; never pre-quote a condition.
  3. `NOT_EQUAL` IS NOT AN if() OPERATOR (never was; invented here). And `cmake -E test` WAS REMOVED in CMake 4 -- probe executability by launching the file and asserting the absence of "Permission denied", not by `test -x`.
- **Solution** (`tests/cases/_inc.cmake`): `ck(<bare tokens>)` -> `if(NOT (${ARGN}))`; `ck_file(path)` / `ck_str` / `ck_fail_rc(var)` helpers write their quotes LITERALLY in the macro body (safe under expansion); expected-failure rc asserts use `ck_fail_rc`, not NOT_EQUAL.
- **Verification**: `bash tests/run.sh` (13 pass / 1 skip) and `ctest --test-dir <bld> -DPolyOrch_BUILD_TESTS=ON` (13/13). New assertion macros must fail loud: `ck(1 NOT_EQUAL 0)` must ERROR, which is exactly how this pitfall was caught the second time.
- **Forbidden**: `ck("<whole condition>")` pre-quoted strings; `NOT_EQUAL` in any if(); `cmake -E test` for any purpose.

## PIT-8: Script mode sets CMAKE_CURRENT_BINARY_DIR to the invocation cwd (2026-09-21)

- **Symptom**: `tests/polyorch-XXXXXXXX` scratch directories accumulated in the source tree (15 of them); a "clean?" check missed them because it searched only for `.pixi`/`pixi.lock`.
- **Root cause**: `_polyorch_pixi_scratch()` preferred `CMAKE_CURRENT_BINARY_DIR`, which under `cmake -P` is NOT absent (an earlier module comment claimed so — wrong) but equal to the invocation cwd. Script mode therefore wrote "build-dir" scratch into the source tree, and the driver's cleanup glob never ran for direct `cmake -P` invocations.
- **Solution**: scratch uses the build dir only outside script mode (`AND NOT CMAKE_SCRIPT_MODE_FILE`), else `$TMPDIR`/`%TEMP%`/`/tmp`; run.sh pins TMPDIR into `tests/.scratch` and belt-deletes `polyorch-*` in the tests dir; the ctest registration pins TMPDIR/TEMP into `<build>/scratch` so nothing lands in /tmp either.
- **Verification**: after `bash tests/run.sh` (and after `ctest`), `ls tests/polyorch-*` and `ls /tmp/polyorch-*` must both be empty.
- **Forbidden**: trusting `CMAKE_CURRENT_BINARY_DIR` as "a real build dir" without checking `CMAKE_SCRIPT_MODE_FILE`.

## PIT-9: A self-skipping test gated on an always-empty cache passes vacuously (2026-09-21)

- **Symptom**: `t-bootstrap-e2e` reported PASS in 0.01s under ctest and 13/13 under run.sh, while never executing the path it claims to cover: each `cmake -P` case starts with a fresh cache where `PolyOrch_PIXI_EXECUTABLE` is declared empty, so the `if(NOT PolyOrch_PIXI_EXECUTABLE) return()` skip branch fired unconditionally.
- **Root cause**: gating a skip on a variable that requires a prior call (`polyorch_pixi_find`) to populate, without making that call; the skip path exits 0, which reads as "pass" to any exit-code-based runner.
- **Solution**: the case calls `polyorch_pixi_find(QUIET)` before the gate. Self-skip gates must perform ACTIVE detection (`find_program`/`find_package`) in the same process.
- **Verification**: a test's first acceptance must show evidence of work (elapsed time, status lines, artifacts) — not only exit 0. Compare `ctest -L e2e --verbose` timing before/after: 0.01s (vacuous) vs ~0.1s (real install+smoke run).
- **Forbidden**: accepting "pass" from a newly written skip-capable test without at least one run whose output proves the covered branch executed.

## PIT-10: CMAKE_CURRENT_LIST_DIR inside a function resolves to the CALLER's file (2026-09-21)

- **Symptom**: `polyorch_pixi_scripts_install()` failed with "missing /tmp/opencode/../scripts/pixi.sh" (and `tests/cases/../scripts/...` from the suite) -- it built paths from `${CMAKE_CURRENT_LIST_DIR}/../scripts`, which is correct at include time but wrong inside a function body called from elsewhere.
- **Root cause**: CMake variable scope is dynamic: inside a function, `CMAKE_CURRENT_LIST_DIR` is the *currently processed list file at the call site*, not the file where the function is defined.
- **Solution**: use `CMAKE_CURRENT_FUNCTION_LIST_DIR` (>=3.17; module floor is 3.22) for any resource path relative to the defining file -- measured correct in both `cmake -P` and configure contexts.
- **Verification**: `bash tests/run.sh` -- `t-scripts-install.cmake` calls the function from a test-case file (different directory), which is exactly the context that exposed the bug.
- **Forbidden**: building module-relative resource paths from `CMAKE_CURRENT_LIST_DIR` inside function bodies.

## PIT-11: renamed test-case operators and ad-hoc gate rewrites fake verification (2026-09-21)

- **Symptom**: (a) `ck(${rc} NOT_EQUAL 0)` died with "Unknown arguments specified" -- `NOT_EQUAL` is not an if() operator (invented); two older cases carried it latently. (b) `cmake -E test -x` returned 1 on an executable file -- the subcommand was removed in CMake 4. (c) hand-retyped gate probes reported C4/C6 FAIL while the canonical commands passed -- two false alarms burned a round each way.
- **Root cause**: writing verification against remembered APIs instead of the local docs; re-deriving gate scripts from memory instead of copying the canonical text.
- **Solution**: for operators, `cmake --help-command if` is one subprocess away -- check before inventing; executability is proven by launching and asserting the absence of "Permission denied" (`ck_fail_rc`/launch-probe helpers); gates are executed verbatim from `conventions.md`.
- **Verification**: `grep -rn 'NOT_EQUAL\|cmake -E test' tests/` returns nothing; suite 13/13 + 14/14.
- **Forbidden**: inventing if() operators; `cmake -E test` for any purpose; paraphrasing a gate command instead of copying it verbatim.

## PIT-12: find_program(..., NO_CACHE) skips the search when the result var was pre-set empty (2026-09-21)

- **Symptom**: `polyorch_rust_setup(FROM pixi REQUIRED)` reported "pixi environment has no cargo/rustc" in the e2e case while `.pixi/envs/rust/bin/cargo` demonstrably existed (env_paths probe: YES). Deterministic, two runs.
- **Root cause**: `find_program(_x ... NO_CACHE)` treats a DEFINED result variable -- including an empty-string `set(_x "")` -- as already resolved and returns without searching. The cache-mode intuition ("empty is not a valid found value, it re-searches") does not carry over to NO_CACHE.
- **Solution**: do not pre-set lookup variables to ""; leave them undefined (`unset(_x)` if a previous branch may have set them). Probe: `set(_x ""); find_program(_x NAMES cmake NO_DEFAULT_PATH PATHS /usr/bin NO_CACHE)` => stays empty; without the pre-set => /usr/bin/cmake.
- **Verification**: `grep -n 'set(_cargo "")\|set(_rustc "")' cmake/PolyOrchRustHelpers.cmake` returns nothing; `POLYORCH_TEST_E2E=1 bash tests/run.sh` t-rust-e2e green.
- **Forbidden**: initializing a variable to empty immediately before any `find_program/find_path/find_package(... NO_CACHE)` call in this codebase.

## PIT-13: an IMPORTED target named like its artifact base name silently swallows the Makefile rule (2026-09-21)

- **Symptom**: `polyorch_rust_build(TARGET greet-cli ... CRATE greet-cli BINARY)` configured with zero errors, but `make greet-cli-cargo` said "no rule to make `.cargo-target/debug/greet-cli`" -- the `cargo build` command had vanished from every build.make. Three suspects were chased and cleared (run-wrapper command string, test+run combo, empty pixi env) before isolation found the real one.
- **Root cause**: with `add_custom_command(OUTPUT <dir>/foo)` + a custom target depending on it, adding `add_executable(foo IMPORTED GLOBAL)` whose name equals the output's base name makes the Unix Makefiles generator drop the producing rule. Proven by minimal repro: imported name `foo` + file `foo` -> rule count 0; renamed to `bar` -> rule 1, build clean. CMake bug-class behavior, no diagnostic.
- **Solution**: keep the three namespaces distinct (CMake TARGET != artifact base name). Now enforced: `polyorch_rust_build` FATALs at configure time on collision with a rename suggestion. The example uses TARGET `greet` vs binary `greet-cli`.
- **Verification**: `cmake -P` scratch injecting TARGET==CRATE hits the guard; `examples/rust-basic` umbrella chain builds + `run-greet` prints `hello, world!`.
- **Forbidden**: assuming an imported/produced-name coincidence is harmless; trusting "it configured fine" as buildability evidence -- always run the mediator target once.

## PIT-14: host-activated compiler flags leak into cargo children and break the example link (2026-09-21)

- **Symptom**: under an embedding host's build env, rust-basic's `cargo build` compiled but failed linking: `cc: error: unrecognized command-line option '-mcet'`. The same chain passed in a clean shell -- non-reproducible-by-source.
- **Root cause**: `_polyorch_rust_command` wraps PATH (pixi route) but passes the rest of the ambient environment through; a conda-activated shell contributes CC/CFLAGS-family flags aimed at a different toolchain, and rustc forwards them to `cc`. No repo file contained `-mcet` (grep: only conda binaries).
- **Solution**: run example chains from a normal shell, or add the planned per-crate env/rustflags control hooks (status.md Open Items, corrosion `set_env_vars` equivalent) before embedding under hostile hosts.
- **Verification**: clean-shell umbrella run green; a "fails under my terminal, passes under CI" report on rust cases should check `env | grep -E 'RUSTFLAGS|CFLAGS|CC='` first.
- **Forbidden**: treating env-leak failures as module bugs; also blanket-stripping CFLAGS inside the wrapper without an explicit opt (breaks legitimate cross toolchains).
