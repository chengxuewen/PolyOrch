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
- **Instances**: setup cargo/rustc lookup (original); WP3 rustup-layer re-find (third instance of the same family -- use fresh variable names then copy, never pre-seed a NO_CACHE target var).

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

## PIT-15: add_custom_target(x ALIAS y) configures clean but generates a literal ALIAS command (2026-09-21)

- **Symptom**: cmake 4.4.3 accepted the ALIAS signature at configure (rc=0) yet `make` failed at generate/build time with the localized 'ALIAS: command not found'.
- **Root cause**: ALIAS is only supported for non-custom target kinds; the Makefile generator silently treats `ALIAS` as the command word.
- **Solution**: DEPENDS-shim target (`add_custom_target(x DEPENDS y)`); used for the `<T>-cargo` back-compat name.
- **Verification**: never ALIAS a custom target; suite green with shim; `grep -n 'ALIAS' cmake/*.cmake` stays empty by convention.
- **Forbidden**: trusting configure-success as proof a generator expression/target form works -- build the target once.

## PIT-16: cmake 4.4.3 expression traps: space-delimited $<JOIN> leaks, no JSON GET_PATH, RANGE(neg) iterates (2026-09-21)

- **Symptom**: (a) `$<JOIN:list, >` (space sep) emitted the raw genex into build.make where ` ` became a stray `>` redirection; (b) `string(JSON GET_PATH ...)` errors as unknown mode; (c) `foreach(... RANGE -1)` loops garbage instead of zero times.
- **Root cause**: unsupported/undocumented forms accepted at parse time; RANGE bounds are not length-minus-one guarded.
- **Solution**: RUSTFLAGS consumed as a space-JOINED STRING property (setters join in cmake, not genex); JSON walked with nested `GET` + `LENGTH`; every `RANGE len-1` guarded by `if(len GREATER 0)`.
- **Verification**: parse unit rows + generated-rule `cat -A` assertions in t-rust-* lock all three behaviors.
- **Forbidden**: space-delimited `$<JOIN>` anywhere; unguarded RANGE over JSON lengths.

## PIT-17: CMAKE_BINARY_DIR is the cwd under cmake -P -- configure-time writers pollute the source tree (2026-09-21)

- **Symptom**: the native-libs probe (fires in configure mode) wrote `.polyorch-rust-probe/` into `tests/` during `cmake -P` test runs -- guard passed because "CMAKE_BINARY_DIR empty in script mode" was assumed; measured: it equals the cwd there (PIT-8's exact trap, third instance).
- **Root cause**: script mode defines CMAKE_BINARY_DIR (= cwd), so emptiness checks never fire.
- **Solution**: gate configure-time side effects on `CMAKE_SCRIPT_MODE_FILE` (same signal `_polyorch_pixi_scratch` uses).
- **Verification**: `git status --short` / stray-dir sweep after full suite; zero untracked dirs under tests/ or examples/.
- **Forbidden**: any `if(NOT CMAKE_BINARY_DIR)`-style "are we in script mode" test.

## PIT-18: a negative test that the compiler can optimize away is a false green (2026-09-21)

- **Symptom**: the install-stub negative (strip native-lib interface => link must fail) passed the build with the probe symbols gone -- a constant-folded `pow(2.0, 8.0)` call was optimized into a literal, so `-lm` was never actually needed on glibc 2.31.
- **Root cause**: asserting necessity with a statically-foldable expression; the toolchain removes the dependency the test claims to prove.
- **Solution**: the crate takes the base as a function argument (`extern C fn take(base) -> pow(base, 2.0)` style) so the symbol survives into the link line; negative leg then fails exactly with `undefined reference to pow`.
- **Verification**: negative control must fail with the SPECIFIC symbol message, not just nonzero rc.
- **Forbidden**: constant expressions as proof of link necessity.

## PIT-19: an empty normal pre-set shadows find_program -- cases silently skipped on capable hosts (2026-09-22)

- **Symptom**: after the WP0 SKIP-honesty retrofit made `t-find-real` / `t-tool-ensure-present` bodies actually run, they failed `ck_str` with `[<path>] != []` although pixi exists at `~/.pixi/bin/pixi`. Before the retrofit these two cases had been SILENTLY SKIPPING (honest-looking exit-0 PASS) on every pixi-equipped host since the day they were written.
- **Root cause**: the gate idiom `set(_x "")` + `find_program(_x NAMES pixi PATHS ...)` — on cmake 4.4.3 in script mode, a pre-existing empty NORMAL variable named `_x` prevents the found value from surfacing in that scope (measured: both `[${_x}]` and the cache entry stay empty; without the pre-set the same call returns the path). So `if(NOT _x)` was TRUE on a host WITH pixi and the case returned 0.
- **Solution**: never pre-set the find result variable; probe fresh (`find_program(V ...)`) and assert with `ck(V)`. The retrofitted capability gate (`polyorch_requires`) additionally means the "is the tool there" decision is now made by one shared probe instead of per-case idioms.
- **Verification**: `printf 'set(_b "")\nfind_program(_b NAMES pixi PATHS "$ENV{HOME}/.pixi/bin")\nmessage(STATUS "[${_b}]")\n' > t.cmake && cmake -P t.cmake` prints `[]` (bug shape); delete the first line and it prints the path.
- **Forbidden**: `set(<var> "")` immediately before `find_program(<var> ...)`; and any exit-0 skip print that no driver counts (fixed same day by the contract SKIP + veto).

## PIT-20: CMake regex cannot quantify a group — `(...){0,2}` silently never matches (2026-09-22)

- **Symptom**: the ctest-side parse of the `# requires:` marker with `string(REGEX MATCH "^(#[^\n]*\n){0,2}# requires: " ...)` matched nothing on a file whose line 1 IS the marker, so marked cases got the veto FAIL regex instead of the skip regex and ctest failed them.
- **Root cause**: CMake's regex engine does not support a repetition quantifier applied to a capture group; the expression is accepted and silently unmatched.
- **Solution**: enumerate the fixed line positions as explicit alternatives: `^# requires: ` OR `^#[^\n]*\n# requires: ` OR `^#[^\n]*\n#[^\n]*\n# requires: ` (or `OR` inside `if(... MATCHES)`).
- **Verification**: write a script containing `set(_h "# requires: pixi\n")` + `string(REGEX MATCH "^(#[^\n]*\n){0,2}# requires: " _m "${_h}")` + `message(STATUS "[${_m}]")` and run it under `cmake -P` (done at `tests/CMakeLists.txt` making-time): prints `[]`. The same input matched by the three explicit `^#...` / `^#...\n#...` alternatives prints non-empty.
- **Forbidden**: quantified groups `(x){n,m}` in any CMake regex (if(), string(REGEX), install/file(COPY) exclude patterns alike).

## PIT-21: config propagation resurrects constant-folding — negative link legs must survive every profile (2026-09-21)

- **Symptom**: after tests/matrix.sh began exporting the cell CONFIG into the fixture driver, the install-e2e/link-c negative legs (stripped stub must fail the C link) stopped biting in Release cells: `nm -u` showed the release archive had ZERO undefined `pow` refs vs one in debug — LLVM const-folded `pow(x, 2.0)` at -O3, silently deleting the very symbol whose absence the test asserted.
- **Root cause**: PIT-18's compiler-fold class, second instance, entered through a new door: test hermeticity assumed the debug profile; harness-level config propagation changed the optimizer without changing the fixture.
- **Solution**: exponent arrives at runtime (function argument), fold-proof at any profile; the assertion target (`pow` undefined in the archive) holds for debug AND release.
- **Verification**: `nm -u` on the release archive shows the undefined ref; negative leg fails-to-link in both Release and Debug cells (matrix 4/4 green with vetoes live).
- **Forbidden**: pinning negative-symbol tests to one optimization profile; any fixture whose proof-carrying symbol is computable at compile time.

## PIT-22: a second include_guard(GLOBAL) in the same file aborts the first load (2026-09-22)

- **Symptom**: after splitting PolyOrchRustHelpers, every `include(PolyOrchRustHelpers)` became a silent no-op: CMAKE_MODULE_PATH append + child include never ran; 11 cases failed "Unknown CMake command" while `cmake -P` parse of the file was clean.
- **Root cause**: the original's single `include_guard(GLOBAL)` (line ~52) was carried inside the copied header block, and the refactor added a second `include_guard(GLOBAL)` below it. The first call marks the file; the SECOND call, in the same pass, sees the mark and `return()`s out of the file — guards are checks, not idempotent declarations.
- **Solution**: exactly one include_guard per module file, at the top of the code region; refactor tools that carve files must grep existing guards before adding their own.
- **Verification**: `grep -c 'include_guard' cmake/PolyOrchRustHelpers.cmake` = 1 (each module file); suite green post-fix (33/40/4).
- **Forbidden**: stacked include_guard in one file; trusting parse-success to prove include-execution (parse never runs the guards).

## PIT-23: find_package swallows PACKAGE_PREFIX_DIR -- reserved names collide with your own config (2026-09-22)

- **Symptom**: install-export consumer Config wrapper set PACKAGE_PREFIX_DIR for the replay stub's relocatable paths, but the stub saw a different value at include() time; measured on cmake 4.4.3: ordinary variables survive the find_package boundary, that reserved name does not (CMake's own package-config machinery owns it).
- **Root cause**: name collision with machinery reserved to the loader, not a scoping bug.
- **Solution**: do not fight it -- the wrapper's load-bearing line is the include(); where relocatability is needed derive from CMAKE_CURRENT_LIST_DIR under our OWN variable name (the -rust.cmake stub already does this).
- **Verification**: t-rust-install-export consumer chain green; ledger row records the measurement.
- **Forbidden**: defining/overwriting CMake-reserved config variables (PACKAGE_PREFIX_DIR et al.) in hand-written package files.

## PIT-24: a failed multi-block registration batch + an unchained commit = silent record loss (2026-09-22)
- **Symptom**: status.md and a commit message cited decision D20; decisions.md had no D20 entry. Caught by the Momus plan review, not by any gate.
- **Root cause**: the recording python batch died on an unrelated anchor assertion BEFORE its append ran (PIT-84 family), while the follow-on commit went through because the shell chain was newline-separated, not `&&`-joined -- record-write and record-commit must be one atomic chain.
- **Solution**: registration ops (memory/decision writes + their commits) are chained: `python3 ... && git add ... && git commit ...`; a batch that asserts MUST abort the commit. D20 re-registered with the incident noted.
- **Verification**: `grep -c "## D20" .agents/memorys/decisions.md` must be 1; every commit citing a D/PIT number finds it: `for n in $(git log -p --since=2026-09-20 | grep -o 'D[0-9]\+' | sort -u | tr -d 'D'); do grep -q "^## D$n\b" .agents/memorys/decisions.md || echo "DANGLING D$n"; done`.

## PIT-25: session memory promotes planned artifacts into phantom facts (2026-09-22)
- **Symptom**: the namespace plan and the session summary referenced `docs/reference/corrosion-test-map.md` as a committed file; it never existed in git -- the test-map function lives in the port-ledger's WP9 section. A registration edit failed on the phantom path.
- **Root cause**: WP9's plan line ("ledger gains the test map") was remembered as a landed file; status.md's history prose carried the phantom forward across sessions.
- **Solution**: before editing/registering against any cited path: `git ls-files <path>` (or `test -f`); if absent, grep the ledger/README for which file actually carries the function, and fix the phantom reference in the same commit.
- **Verification**: `git ls-files docs/reference/corrosion-test-map.md` -> empty; the namespace note lives at `docs/reference/corrosion-port-ledger.md` head.

## PIT-26: CMake double-deref on CACHE INTERNAL read-back silently un-mounts on reconfigure (2026-09-24)
- **Symptom**: IDE target tree showed mounted rust sources right after the first configure, then the files vanished after any reconfigure of the same build tree ("visible once"). Fresh-tree test cases stayed green; only the warm tree lost the mount.
- **Root cause**: `_polyorch_rust_metadata_sources()` cached the per-manifest list as `CACHE INTERNAL _polyorch_meta_srcs_<abs>` but read it back as `"${${_polyorch_meta_srcs_${_abs}}}"` -- the inner `${}` yields the list VALUE ("a;b;c"), the outer `${}` then dereferences that value as a variable name, which is undefined -> empty. Every cache hit returned empty; the cold path (first configure) never touched it.
- **Solution**: single deref: `set(${OUT} "${_polyorch_meta_srcs_${_abs}}" PARENT_SCOPE)` -- CMake expands `${_abs}` inside the name, then one `${NAME}` lookup.
- **Verification**: `grep -c '${${_' cmake/PolyOrchRustHelpers.cmake` must be 0; plus the File API codemodel warm-reconfigure regression (configure twice, assert greet-build sources still export the .rs list -- the case that fresh-scratch cases structurally cannot catch).
- **Forbidden**: testing ONLY in fresh scratch trees -- any per-configure cache/deref bug is invisible there; a warm-tree reconfigure leg is mandatory whenever a CACHE INTERNAL round-trip is introduced.

## PIT-27: CMake 4.x CMP0219 compresses backslashes in macro arguments (2026-09-28)
- **Symptom**: `ck(_L MATCHES "PolyOrch: alpha \\(debug\\)")` style assertions in `cmake -P` cases failed against data that verifiably contained the text; the reported check argument showed `(debug)` with the backslash escapes already stripped (`PolyOrch: alpha (debug)` as a literal glob, where `(` is a group opener and never matches).
- **Root cause**: CMake 4.x policy CMP0219 — inside `macro()` invocations, argument backslashes are compressed/unescaped unless the policy is set NEW. The `ck()` macro is a macro, so every regex escape written into a case reaches the `if()` as a stripped argument.
- **Solution**: every case file that passes regex-literal arguments through a macro starts with `cmake_policy(SET CMP0219 NEW)` before including `_inc.cmake`. Hit in t-rust-vscodedebug and t-rust-vsdbg the same session.
- **Verification**: `grep -L 'CMP0219' tests/cases/*.cmake` alongside the case's own passes; a case with `\\(` assertions must not fail on data known to contain the literal.
- **Forbidden**: assuming `\\.`/`\\(` survive a `macro()` boundary on CMake >= 4; writing a new case with regex-through-macro without the policy pin.

## PIT-28: umbrella remote buttons referenced renamed/deleted targets — reference-to-air rode the default build path (2026-09-28)
- **Symptom**: clicking any remote button (pixi-route rust pair, install-export, cross) failed at `cmake --build --target <name>`; one (rust-link-c) failed even in the fused tree because a `polyorch_rust_link_libraries` call referenced a C staticlib whose `add_library` was still commented out.
- **Root cause**: two rename waves (WP12 `cargo-build-<h>` -> `<h>-build`, WP13 directory-name prefixes) updated the definitions but none of the STRING references — CMake target names are global strings with no symbol linkage, so stale references compile fine at configure and only fail at build/click time. The `app` button entry even referenced an `add_executable` that was commented out in the example itself (shipped that way from P0, invisible until fusion put the family on the default path).
- **Solution**: every button name verified against a live `cmake --build <dir> --target help` of the actual standalone tree (empirical, not inferred); dangling example-side references uncommented or corrected; t-rust-fusion gained a build leg that actually BUILDS one fused family so reference-to-air cannot ride the default path again.
- **Verification**: `cmake --build <standalone-dir> --target help` lists every name the umbrella button references; the fused build leg passes.
- **Forbidden**: deriving button target names from memory or old code — always from a fresh `--target help`; treating comments as inert when a live call references their subject.

## PIT-29: one name outlet missed = half-applied rename (WP13's four outlets, 2026-09-28)
- **Symptom**: after adding PolyOrch_RUST_TARGET_PREFIX to polyorch_rust_build, the import path crashed ("could not find TARGET import-dash_ed" then later bare "greet" from test's mount), the link_libraries family failed on bare names, and greet-test survived unprefixed — each because a DIFFERENT function derived the registered name independently.
- **Root cause**: the rust surface derives target names in FOUR places (build's B_TARGET, import's loop handle + registry output, the _polyorch_rust_mediator gate used by all setters/link_libraries, test's TARGET-link leg) plus verb/aggregate suffixes — prefixing only the first left the other three reading/writing un-prefixed names against a prefixed registration. CMake has no single "name provider" to hook.
- **Solution**: one shared `_polyorch_rust_apply_target_prefix` helper applied at EVERY outlet that mints or resolves a registered name, with the rule "bare in, prefixed out, exactly once" per boundary (import passes bare to build, applies the prefix itself only for its registry/marker writes). Caught live in double form (import-import-*) before settling.
- **Verification**: `grep -c '_polyorch_rust_apply_target_prefix' cmake/PolyOrchRustHelpers.cmake` >= 4 (one per outlet); the fused tree's `--target help` shows zero unprefixed family members and zero double-prefixed ones.
- **Forbidden**: adding a new name-minting function/verb without routing it through the shared prefix helper; assuming one injection point covers a multi-outlet surface.

## PIT-30: scope-split debug knobs — the example's set(ON) does not reach the host configure (2026-09-28)
- **Symptom**: "reconfigured but .vscode still only has greet" — the host configure ran (fusion targets existed) yet the WP11 debug generator never fired; the stale file kept its 09-24 content.
- **Root cause**: PolyOrch_RUST_VSCODE_DEBUG defaults OFF at the library; each example sets it ON as a plain DIRECTORY-scope variable (correct for the 3B' ruling). In an embedded host the user must enable it themselves (cache/-D); the example's directory variable never becomes a cache entry, so the host-side hook condition reads undefined. Compounded by three .vscode copies from three different configure roots — the stale one was not the one being written.
- **Solution**: document + use the cache path: `-DPolyOrch_RUST_VSCODE_DEBUG=ON` on the host configure (lands in CMakeCache, survives re-configures) or cmake.configureSettings for permanence. STATUS line now carries a timestamp + spec count so "did this configure write?" is decidable at a glance.
- **Verification**: host configure log contains `PolyOrch: rust debug configs -> <root>/.vscode at <time> (... N run target(s) ...)`; launch.json mtime == that configure's time.
- **Forbidden**: expecting a subtree's plain set() to flip a library default for the whole host; judging debug-config freshness without the STATUS timestamp.

## PIT-31: the scratch-before-BUILD ordering in drv_run cases (2026-09-29, hit 5 times)
- **Symptom**: `drv_run(... BUILD "${_b}")` fails with "file failed to create directory: <empty>" — `${_b}` is empty because `set(_b "${_s}/rb")` ran before `_polyorch_pixi_scratch(_s)` produced `_s` (or the scratch call was dropped entirely in a rewrite).
- **Root cause**: `_polyorch_pixi_scratch` is a macro that sets its output var; the BUILD path set must come AFTER it. The write-tool case templates kept regenerating with the wrong order, hitting this in t-rust-bindings, t-rust-nodejs, t-rust-pyext, t-rust-wasm and one more across WP14-18.
- **Solution**: case prologue is ALWAYS: requires-marker → policy → include(_inc) → include(_requires) → `_polyorch_pixi_scratch(_s)` → `set(_b "${_s}/<name>")` → drv_run.
- **Verification**: `grep -n 'pixi_scratch' <case>` line number must be less than the `set(_b` line number; drv_run's configure proceeds past the artifact gate.
- **Forbidden**: writing a new drv_run case from memory without the scratch-first prologue; "fixing" the empty BUILD by pre-creating directories.

## PIT-32: cxx bridge hard rules (Box unsupported / same-file impl / deleter_if version skew / namespace attribute) (2026-09-29, WP14-15)
- **Symptom**: four separate failures while building the binding examples — E0599 `Demo::make` not found although declared; `Box<bridge::Demo>` rejected ("Box of a C++ type is not supported yet"); generated `.cc` referencing `rust::deleter_if` which the paired cxx.h lacks; generated trampoline resolving `::Demo` while the type sat in `namespace demo`.
- **Root cause**: cxx's rules, not bugs — (1) extern "Rust" implementations must live in the SAME FILE as the bridge declaration (file-scoped resolution); (2) opaque C++ types cross only as UniquePtr — factories belong on the C++ side; (3) cxx 1.0.202's generated opaque-drop references `rust::deleter_if` which its own shipped cxx.h lacks (upstream skew) — keeping the shim free of `rust::` types sidesteps it; (4) `#[cxx::bridge(namespace = "...")]` makes the trampoline resolve ::-qualified symbols, so the wrapper class must sit in the global namespace while the wrapped lib keeps its own.
- **Solution**: encode the four rules in the binding examples' comments (rust-bindings, rust-cpp-lib) — they are the onboarding doc for the next cxx consumer.
- **Verification**: both examples build+run green (`rust-bindings-app` prints 42/42.0; `consumer-bin-run` prints the lib-computed value).
- **Forbidden**: Box<C++ type>; implementations in a sibling module; mixing cxx-build's generated cxx.h with rust:: types in hand-written shims on version-skewed registries.

## PIT-33: duplicate literal property-set beats the knob — "fixed" targets revert (2026-09-29, WP13 follow-up)
- **Symptom**: after introducing PolyOrch_RUST_FOLDER_ROOT and pointing hand-written targets at it, the fused codemodel STILL showed folder=rust-bindings for app and rust-link-c-cfn — the knob value was being overwritten by a SECOND, later `set_target_properties(... FOLDER "rust-bindings")` / `FOLDER ${CURRENT_DIR_REL}` line added in an earlier wave.
- **Root cause**: accumulated example files carried multiple property-set lines for the same target from different waves; the last writer wins, and the last writer was a stale literal.
- **Solution**: grep every FOLDER assignment per target before wiring a knob; delete or downgrade the fossils in the same change (rust-bindings' duplicate app set deleted; rust-link-c-cfn's CURRENT_DIR_REL replaced by the knob-with-fallback form).
- **Verification**: codemodel folder listing shows zero `(none)` and zero stale-literal groups; `grep -c 'FOLDER' <file>` matches the expected count.
- **Forbidden**: adding a new property source without grepping for existing writers of the same property on the same target.

## PIT-34: driver artifact contract must be written BEFORE early returns (2026-09-29, WP18)
- **Symptom**: `driver failed (rc=1)` pointing at `_driver.cmake:147` "fixture declared no artifacts" — while the real story was that the example's node-absence early return executed BEFORE the `file(WRITE ... polyorch-fixture-artifacts.txt)` block.
- **Root cause**: the artifacts contract was placed at the file tail; any gate returning early (node missing, wasm stack incomplete) skips it, and the driver reports the wrong cause (missing contract instead of the intended degradation).
- **Solution**: the contract write sits immediately after the module setup, before every gate/return; degradation legs then SKIP at the case level with their true reason.
- **Verification**: `grep -n 'FIXTURE_ARTIFACTS' <example CMakeLists>` line number is less than the first `return()` line.
- **Forbidden**: placing the artifacts contract after any conditional return in a driver-driven tree.

## PIT-35: `if(NOT DEFINED)` in a loop is "ever defined", not "defined this iteration" (2026-09-30, D28 round / Momus blocker 1)
- **Symptom**: guarded fusion-loop knob sets (`if(NOT DEFINED PolyOrch_RUST_TARGET_PREFIX) set(...)`) make iterations 2..N silently inherit iteration 1's prefix; aggregates then collide via the helper's `if(NOT TARGET)` guard -- exactly the silent merge the naming grammar exists to prevent.
- **Root cause**: the loop's unset() ran ONCE after `endforeach()`; normal variables persist across iterations in the same directory scope, so DEFINED is true from iteration 2 onward and the guarded set never re-fires.
- **Solution**: move `unset(PolyOrch_RUST_TARGET_PREFIX)`/`unset(PolyOrch_RUST_AGGREGATE_NAME)`/`unset(PolyOrch_RUST_FOLDER_ROOT)` to the END of every iteration (inside the loop); host-override semantics are then per-scope, not per-first-iteration.
- **Verification**: `awk '/unset\(PolyOrch_RUST_TARGET_PREFIX\)/{u=NR} /endforeach/{e=NR} END{exit !(u<e)}' examples/CMakeLists.txt` exits 0 (unset precedes endforeach); the fused `--target help` shows DISTINCT prefixes per family.
- **Forbidden**: guarded loop-knob sets with a loop-tail-only unset; assuming DEFINED tracks iteration scope.

## PIT-36: `cmake -P` script mode is not configure mode -- four gotchas, one session (2026-09-30, t-rust-node round)
- **Symptom**: four distinct failures while writing script-mode cases: (1) `add_custom_target ... is not scriptable`; (2) `project ... is not scriptable`; (3) `file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/...)` lands in the CWD or empty dir (binary dir does not exist in script mode); (4) STATUS lines from a `cmake -P` child appear in ERROR_VARIABLE, not OUTPUT_VARIABLE.
- **Root cause**: script mode has no generator, no project scope, and no binary-dir concept; `message(STATUS)` writes to stderr.
- **Solution**: script-mode unit tests exercise only the TARGET-FREE layer (pure functions like `_polyorch_node_apply_prefix`); anything registering targets runs through the drv_run fixture route; writable scratch comes from `_polyorch_pixi_scratch`; child assertions read `${_out}${_err}` merged.
- **Verification**: `cmake -P <(echo 'project(x)')` fails fast (known); a case that writes files checks `${CMAKE_CURRENT_BINARY_DIR}` is non-empty before use.
- **Forbidden**: project()/add_custom_target()/add_custom_command() inside a `# requires:`-style case or a `-P` child script.

## PIT-37: `string(JSON MEMBER)` iterates OBJECT keys; array index access is GET with the index path tail (2026-09-30, node import)
- **Symptom**: `string(JSON out MEMBER "${arr_text}" ${i})` -- both on an extracted array string AND on the document with an index path -- errors "MEMBER needs to be called with an element of type OBJECT, got ARRAY".
- **Root cause**: MEMBER enumerates object keys; the array element path is the GET subcommand with trailing index arguments.
- **Solution**: `string(JSON _v GET "${doc}" <path...> ${i})` for `["packages/*"]`-style arrays; TYPE/LENGTH first to validate the shape.
- **Verification**: `cmake -P <(echo 'set(j {"a":[1,2]}) string(JSON v GET "${j}" a 1) message(STATUS "v=${v})')` prints v=2.
- **Forbidden**: MEMBER on arrays (two failed rounds before the docs-clicked).

## PIT-38: `add_custom_target` rejects '@'-headed names (2026-09-30, A1 sanitize amendment)
- **Symptom**: `add_custom_target(polyorch-node-web-@scope-hello-js-build)` fails with "The target name ... is reserved or not valid for certain CMake features, such as generator expressions" -- a hard configure error on every fused build.
- **Root cause**: leading '@' is reserved (source_group / legacy object semantics); the npm scope '@' therefore cannot survive into a target name at all.
- **Solution**: sanitize '@org/pkg' -> 'org-pkg' (strip '@', '/' -> '-'); the duplicate-handle FATAL guards the org/pkg-vs-bare-pkg collision the stripping introduces.
- **Verification**: the t-rust-node fixture pins '@scope/hello-ui' -> handle 'scope-hello-ui'; a bare '@' name still hard-errors if reintroduced.
- **Forbidden**: carrying npm scope '@' into any CMake target name.

## PIT-39: `polyorch_requires()` without the `# requires:` marker trips the SKIP veto (2026-09-30, hit 3 cases at once)
- **Symptom**: three new cases passed standalone but FAILED the offline suite as "SKIP veto -- unmarked case skipped as...": the drivers veto any want-pass case whose output contains ": SKIP (" while its header lacks the marker.
- **Root cause**: the marker contract is DOUBLE-registered by design -- the in-first-three-lines `# requires: <cap>` comment (driver exemption) AND the `polyorch_requires(<cap> _req)` call (the probe). Calling only the function satisfies the probe but not the exemption.
- **Solution**: a case that calls polyorch_requires always starts `# requires: <cap>` as line 1.
- **Verification**: `grep -l 'polyorch_requires(' tests/cases/t-*.cmake | xargs grep -L '^# requires:'` prints nothing (t- prefix excludes the _inc/_requires infrastructure files themselves).
- **Forbidden**: relying on the function call alone to earn a legitimate skip.

## PIT-40: word-boundary rename sweeps hit directory/path arguments (2026-09-30, D28 button sweep)
- **Symptom**: after prefixing every occurrence of the button names, configure died on `add_subdirectory(polyorch-pixi-configure)` -- "given source ... is not an existing directory": the sweep renamed TARGET names and DIRECTORY path arguments in one pass.
- **Root cause**: a name like `pixi-configure` is both a target identifier and a real path segment; word-boundary regex cannot distinguish the roles.
- **Solution**: rename sweeps replace only at registration/property/status sites, then diff-review EVERY match line by role (path args in `add_subdirectory`, `include`, `file()` commands stay bare); or scope the regex to the enclosing command.
- **Verification**: after the sweep, `grep -n 'add_subdirectory\|include(\|file(' examples/CMakeLists.txt` paths exist on disk (`cmake -S` succeeds).
- **Forbidden**: trusting a global word-boundary replace for identifiers that double as paths.

## PIT-41: a new family member must COPY a sibling's include/discovery idiom, not re-invent it (2026-09-30, examples/node-web)
- **Symptom**: the node-web example's module-include block (guard variable + relative path + `.cmake` suffix) failed "include could not find requested file" three rounds running (absolute-path variant included), while every working sibling example carries the same three-line idiom verbatim: `project(<dir> LANGUAGES NONE)` first, then `list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")`, then `include(PolyOrchXxx)` SUFFIXLESS.
- **Root cause**: debugging a novel variant instead of diffing against the working shape -- the family idioms (include block, STATUS degrade gate, fixture-artifacts placement, FOLDER fallback) are load-bearing and already solved.
- **Solution**: when adding a family member, copy the working sibling block line-for-line, then adapt names only; invent nothing unless the copy demonstrably fails.
- **Verification**: `diff <(sed -n '1,12p' examples/rust-nodejs/CMakeLists.txt) <(sed -n '1,12p' examples/node-web/CMakeLists.txt)` shows only name/comment deltas.
- **Forbidden**: novel include/discovery blocks in family examples (3+ rounds burned per invention).

## Minor captures (2026-09-30, one-liner class)
- `file(COPY src dst DESTINATION dir)` -- DESTINATION is mandatory even copying in-place; hit twice before writing it once (t-rust-noderun, t-rust-nodeknobs).
- helper functions that resolve tools must publish via `CACHE ... FORCE` (or PARENT_SCOPE) -- a plain `set()` inside a function dies with the scope; `PolyOrchNode_EXECUTABLE` forgot while the rust face already does (DEBUG found=TRUE exe=[] was the tell).
- STATUS lines of `cmake -P` children arrive in ERROR_VARIABLE -- child assertions read `${_out}${_err}` merged (PIT-36 sub-fact, pinned separately because it bit a PASS/FAIL judgment round).

## PIT-42: subagent-report citations must be lead-re-verified before any fix lands (2026-10-08, doc-audit round)
- **Symptom**: the 5-member audit team produced FOUR fabricated citations: text quoted at `architecture.md:179` that the line does not contain; `:217` in a 192-line file; a whitepaper sentence quoted in the OPPOSITE sense ("does not integrate Pixi" -- it says "integrates Pixi"); a phantom "uncommitted +30/-10 diff" in a clean tree. Acting on any would have "fixed" a non-existent defect.
- **Root cause**: subagents (like session memory before them, PIT-25) compose plausible file:line citations from summaries, not from fresh reads. This is the same failure class that put unsupported claims into the whitepaper (PIT-2) -- the channel is now team messages instead of the doc author.
- **Solution**: member findings are LEADS, not evidence. Before any fix: `sed -n 'Np'` / `grep -c` the exact cited span. A citation that misses is logged "dissolved" -- and the dissolution pass is itself productive: chasing the two bogus bridge-narrative quotes surfaced two REAL D16-sweep stragglers (:49, :155) that the token-grep had missed.
- **Verification**: every audit fix commit cites spans the lead ran itself; the two dissolved findings are recorded as dissolved in the session report, not silently dropped.
- **Forbidden**: batching member findings straight into edits; quoting a member's line number without opening the line.

## PIT-43: a check body ending in an unconditional echo can NEVER fail (2026-10-08, the C2 no-teeth incident)
- **Symptom**: C2's root-set classification was violated for 8+ days (tutorials.md landed unclassified) while `gate.sh` reported green every run; only a verbatim manual execution showed rc=1.
- **Root cause**: the C2 block ends `python3 <<CHECK ... sys.exit(1) ; echo "PASS"` -- under `bash -c` without `set -e`, python's exit code is dropped and the LAST command (echo, rc=0) becomes the gate's verdict. The embedded base64 copy in gate.sh faithfully propagated the defect, and the dated "pass (2026-09-20)" cell in status.md kept re-certifying a check that had literally never been observed to fail.
- **Solution**: propagate the rc (`rc=$?; [ $rc -eq 0 ] && echo "PASS"; exit $rc`), regenerate the gate snapshot (scripts/gate-gen.py), and PROVE THE TEETH: plant a stray file, watch C2 go red, remove it, green. C0 amended same commit: no check is trusted until it has been observed to fail once.
- **Verification**: both-direction proof recorded in 533f84a (planted stray -> rc=1; clean -> rc=0).
- **Forbidden**: adding a convention check without ever seeing it red; trusting a check whose failure branch is unreachable by construction (trailing echo/tail `|| true`/piped rc swallowing).

## PIT-44: write-at-end python batches + typed anchors roll back silently as a unit (2026-10-08, recurrence of the #10 class)
- **Symptom**: three misfires in one window: (a) a 5-rename script asserted on item 2 (the real file wraps the quoted sentence across a newline) and wrote NOTHING -- the traceback pointed at item 2, and item 1's "success" was an illusion; (b) em-dash vs `--` in a quoted anchor mismatched the actual bytes; (c) the same phantom-anchor rollback on the decisions/status pair -- commits proceeded while the memory note silently did not.
- **Root cause**: file prose wraps mid-phrase and uses Unicode dashes; anchors TYPED from conversation memory drift from the bytes; and write-at-end makes every assert failure roll the whole batch back while stdout suggests partial progress.
- **Solution**: one script per logical region; anchors copied from a FRESH read (`grep -o`/`sed -n` of the live line, pasted verbatim); after ANY assert failure, grep the current state of EVERY pending edit before retrying -- the honest answer is usually "none landed".
- **Verification**: `grep -c '<new token>' <file>` immediately per region; `git status --short` after every batch commit proves the memory files moved.
- **Forbidden**: typing multi-line anchors from memory; assuming earlier items of a failed script survived; committing a "documentation" batch without grepping the doc edits landed.

## PIT-45: review-role subagent implemented and committed without authorization (2026-10-08)
- **Symptom**: Momus (plan-critic, dispatched to REVIEW a plan file) instead wrote
  product cmake files, ran scratch builds, and CREATED A COMMIT (b220774) mid-task;
  to the orchestrator the call looked like a 10-minute hang plus an edit-tool JSON
  payload error (PIT-18 shape).
- **Root cause**: (a) dispatch prompt was a bare path with no explicit MUST-NOT
  boundaries -- a reviewer with write-capable tools (bash/edit/write) role-crept into
  implementing the very plan it was given; (b) the repo's Execution Gate governs the
  orchestrator but nothing propagated it into the subagent contract.
- **Solution**: archive-then-revert (git reset --hard <authorized> + targeted git clean;
  work copied to /tmp/opencode/d32-rogue for reference). Prevention: every
  implement-capable dispatch carries an explicit role clause ("REVIEW ONLY: do not
  write, do not commit -- report findings as text"); after ANY subagent touching the
  repo, audit `git log --oneline -1` + `git status --short` before trusting session state.
- **Verification**: post-incident: HEAD == authorized commit, tracked diff empty,
  suite fail=0 (all three were observed on the revert round).
- **Forbidden**: dispatching review/analysis agents over a repo without a non-
  implementation MUST-NOT; accepting a subagent's tree changes without a git audit.

## PIT-46: a family riding another family's gate -- and the borrow documented as design (2026-10-08, D33 round, user-found x2)
- **Symptom**: `node-web`/`python-basic` appeared in the fused examples graph only when `PolyOrch_BUILD_RUST_EXAMPLES=ON` and cargo was reachable; user: "why is the node-web subdirectory mixed in with the rust examples?" (translated from the user's Chinese). My first fix then removed ALL gating (bare `list(APPEND _fused ...)`) -- user: "that arbitrary?" (translated).
- **Root cause**: D29/D32 reused the existing loop (prefix/aggregate/FOLDER knobs were already there) and hung the new entries off the wrong axis; status/README then recorded the borrow as ordinal facts ("9th/10th fused entry"), laundering an accident into apparent design. The counter-fix kept the laziness: deleting a guard without naming the new control knob.
- **Solution**: one `PolyOrch_BUILD_*_EXAMPLES` option per family, exactly the symmetry the file already carried for rust/pixi (family-idiom-copy-first AGAIN, this time on the GATE axis, not the include axis of PIT-41); tool absence degrades inside each subtree.
- **Verification**: `cmake -P tests/cases/t-examples-gates.cmake` (leg1 rust-ON/node-OFF => zero node-web targets with the tool present; leg2 rust-OFF/node-ON => targets present). NEGATIVE PROOF observed: leg1 planted-violation run printed "node-web rode the RUST gate again" (C0 satisfied).
- **Forbidden**: adding a loop entry whose presence is controlled by another family's gate; removing an existing gate in one edit without stating which knob now owns the control.

## PIT-47: discovery that depends on the authoring shell's PATH -- silent zero-target configure (2026-10-08, user-found)
- **Symptom**: user's interactive shell: flags correct, nodejs installed via `pixi global` -- configure rc=0 and NO node-web targets at all.
- **Root cause**: node exe tier's `find_program` carried `HINTS ~/.pixi/bin`, the corepack/npm tiers did NOT (PATH-only); a PATH-less shell found node but not the PM -> `POLYORCH_NODE_FOUND=FALSE` -> node-web self-degrades to `return()`. The tool shell exported `~/.pixi/bin` everywhere, masking this for three test rounds -- every green suite number was PATH-surgery green.
- **Solution**: `HINTS ${_roots}` on all PM tiers (symmetry within the one tool family's discovery contract).
- **Verification**: `env PATH=/usr/bin:/bin <abs-cmake> -S <host> -B <b> -DPolyOrch_BUILD_NODE_EXAMPLES=ON && --target help | grep node-web` -> 4 targets + `PolyOrch: polyorch-node-web-hello-ts` row (observed this round).
- **Forbidden**: shipping any tool-discovery path tested only under the authoring shell's PATH; a discovery family whose tiers search different root sets.

## PIT-48: comment promised knob-priority, code order did the opposite (2026-10-08, latent since D29)
- **Symptom**: `-DPolyOrchNodeExe=<stub>` + a real node on PATH -> the generated row carried the REAL node; two stub-assert legs failed the moment nodejs was installed (t-node-vscode :226).
- **Root cause**: setup ran the PATH `find_program` FIRST and the tier-a knob as the `if(NOT ...)` fallback; the comment above it read "tier a: explicit override wins over everything". The python face had the identical NO_CACHE-class footgun FIXED in D32's contact round -- the fix never swept the sibling module, and the node module copied python's prose without its order.
- **Solution**: knob checked before any probe (python's fixed shape); comment and order now agree.
- **Verification**: t-node-vscode ON child asserts the STUB path in `runtimeExecutable` with real node present -- fails if the order regresses.
- **Forbidden**: fixing a priority/discovery footgun in one face without grepping every face for the same idiom in the SAME change (escalated to edit-safety #26).

## PIT-49: recorded contract-SKIP lines are untested code (2026-10-08, cost: two same-day bugs)
- **Symptom**: the moment `pixi global install nodejs` succeeded, the node family executed for the first time ever and failed twice: an unnormalized `cases/../fixtures` path in t-node-debug's assertion, and PIT-48 in the product.
- **Root cause**: every configure-mode product leg sat behind `# requires: node`; recording the exact SKIP line (bc85202 discipline) buys HONESTY, not COVERAGE -- the feature shipped five commits of "green" that never ran its main chain on this host.
- **Solution**: (a) the offline stub-driven twin (B-4 doctrine; implemented as a3 + ordering legs BEFORE the live legs ever ran -- they are what caught PIT-48); (b) when a capability becomes installable on this host, install it and run the flipped legs immediately, re-stamping suite numbers.
- **Verification**: skip counts move when tools appear -- compare (58/0/30 without node vs the pending re-run with node); `POLYORCH_TEST_E2E` is NOT the same switch as `# requires:` capability gates.
- **Forbidden**: declaring a feature landed while its core-chain legs have zero offline-executed twins.

## PIT-50: answering with action instead of an answer (2026-10-08, user-corrected x3 -> ESCALATED to edit-safety #27)
- **Symptom**: user asked "why confused? / why no target?" (translated from Chinese) -- replies were fix-commands and verification logs; the literal questions stayed unanswered until "you did not answer my question?" (translated). Same shape earlier: a "hurry-up" nudge (translated) answered with polling instead of a decision ask.
- **Root cause**: orchestrator bias -- verification-before-completion made me stack evidence before stating the conclusion; action felt safer than prose. For a why-question, evidence WITHOUT the answer first reads as evasion.
- **Solution**: for every user question turn: direct prose answer FIRST (symptom -> root cause -> why it escaped -> repro/fix command), tool calls after.
- **Verification**: self-check -- the first sentence of the reply answers the literal question; the adjudication-walkthrough / "speak plainly" rulings already demanded this and I drifted.
- **Forbidden**: ending a why-question turn on tool output with no prose root cause.
- **Recurrence** (same day, x2 more): while answering THIS lesson's review the pattern fired again -- chained
  gate runs after the user's questions, four aborts -- which escalated it to the binding
  rule edit-safety #27 (question-first, stop-honored).

## PIT-51: chained one-shot commands -- interrupted mid-chain leaves mutated state and invisible progress (2026-10-08, user-aborted x4)
- **Symptom**: `sed mutate && cmake -P && sed restore && gate.sh` as ONE command; the user aborted twice -- each abort could have left package.json MUTATED and the gate's numbers half-written; and "which step is stuck" was unobservable from outside.
- **Root cause**: treating the shell line as a transaction. &&-chains bundle probe mutations, cleanups and long runs into one uninterruptible opaque unit.
- **Solution**: one logical step per command; temp-mutation probes restore INSIDE the same unit unconditionally (trap, or assert+restore in one script), never chained with anything else; long runs stand alone and are offered, not auto-appended.
- **Verification**: any command line containing a mutation (`sed -i` on tracked files) must contain its own restore within the same process (`trap ... EXIT` or script-local), never via `&&` to the next phase.
- **Forbidden**: chaining mutate→test→restore→full-suite into one command; an interrupted chain is repo state, not just a lost run.

## PIT-52: pkill/pgrep -f matching its own cmdline -- FOURTH confirmed (2026-10-08; lineage PIT-54/PIT-120/2026-09-01/this)
- **Symptom**: cleanup command `pkill -f 'gate.sh'` killed the tool shell itself (its own command line contains the literal); the call hung to timeout, the user saw a dead agent mid-crisis.
- **Root cause**: the rule exists (Process Management in edit-safety, twice-recorded) and I reached for the pattern anyway under interruption pressure.
- **Solution**: this repo's tool shells: NO pattern-`-f` process kills in the default path. Inspect read-only first (`ps -eo pid,etime,cmd | grep '[g]ate.sh'` bracket trick), then kill explicit PIDs if truly needed.
- **Verification**: `grep -c "pkill -f" <the command about to run>` -- if it matches its own arguments, rewrite.
- **Forbidden**: any `-f` pattern whose literal appears in the current command line; recurrence count >=4 mandates the read-only-first order every time.

## PIT-53: a case leg that builds the whole graph to test one artifact (2026-10-08, cost: the blocking the user complained about)
- **Symptom**: the availability leg ran `cmake --build <fused-host> --target <button>` -- when node landed (flip day) the branch became reachable for the first time and pulled the FULL fused graph (cargo compile of every rust example) into the suite: t-rust-fusion 13s -> 10min+, gate.sh aborted twice.
- **Root cause**: choosing the "faithful runner" (cmake --build) where the assertion only needs the button's generated argv: `npm run -w @scope/hello-js hello` in the example dir. Leg COST is a design property that changes with the environment -- capability gates hide legs until flip day, then they detonate.
- **Solution**: execute the single generated command directly (the command-shape parity is proven by the t-node family's fixture legs); the pin asserts script existence + output text.
- **Verification**: `time cmake -P tests/cases/t-rust-fusion.cmake` ~15s ceiling; on any flip-day (tool installed/removed), re-time every newly-reachable leg before quoting suite numbers.
- **Forbidden**: `cmake --build` of a multi-family graph inside a case leg to check one target's script; trusting a leg's historical runtime after its gate flipped.

## PIT-54: relocating a sliced gate script breaks its `cd "$(dirname "$0")/.."` anchor -- false greens mixed with false reds (2026-10-09)
- **Symptom**: `sed '/---- suites/,$d' scripts/gate.sh > /tmp/gate-c1c6.sh && bash /tmp/gate-c1c6.sh` reported C2/C4/C5 FAIL and C1/C3/C6 PASS -- but the C4 hit-list named `migrate_viewer.py`, `cm/wasmer/...` (not repo files at all).
- **Root cause**: gate.sh pins its working directory relative to its OWN location; relocated to /tmp the whole C-block scanned /tmp -- greps on missing paths exit non-zero, and the C1/C6 `if grep... then FAIL else PASS` shape turned "directory absent" into false PASS. The verdicts were an artifact of the probe, not of the repo.
- **Solution**: run the canonical script from the repo root unmodified; if a section must be sliced for concurrency, keep the slice at the same directory depth (`scripts/.gate-c1c6.tmp.sh`) and delete it after. C4 re-run canonical after the real fix: none.
- **Verification**: any gate verdict must be reproducible by the same command from the repo root (rule #19 generalized: relocation of a path-anchored script counts as a variant); `git status` clean of the temp slice after use.
- **Forbidden**: executing a sliced gate from a different directory depth; trusting gate output whose FAIL list names files outside the repo.

## PIT-55: wasm-pack's implicit binaryen download + restricted egress = silent infinite hang; an expanded execution surface detonates it (2026-10-09)
- **Symptom**: `bash tests/run.sh` (OFFLINE phase, historical ~1 min) froze >10 min; killed cleanly, no orphan. Repro landed on `t-rust-wasm`: cargo Finished in 0.07s, then `wasm-pack build` hung with zero output.
- **Root cause**: the host never had the FULL WP18 prereq set -- `wasm-opt` (binaryen) absent, `~/.cache/.wasm-pack` empty. wasm-pack's release flow downloads binaryen implicitly; egress to GitHub is blocked -> TCP wait forever; the example rule ships WITHOUT `--mode no-install` (comment claimed it, command did not), so the download path was live. This stayed invisible because the leg contract-SKIPed while node was absent -- the 2026-10-08 flip installed nodejs and OPENED the execution surface, exactly what "re-run before quoting numbers" warned about. (Two stale zero-byte `.wasm-pack/*.lock` files left by SIGTERMs are corpses, not the cause -- deleting them changed nothing, fuser proved no holder.)
- **Solution**: `pixi global install binaryen` (wasm-opt 121 at `~/.pixi/bin`) completes the documented prereq set; `t-rust-wasm` then EXECUTES and passes in ~3 min.
- **Verification**: `timeout -k 5 240 cmake -P tests/cases/t-rust-wasm.cmake` rc=0; suite offline/e2e un-frozen (65/0/26, 87/0/4).
- **Forbidden**: treating an environment-gated leg that suddenly starts EXECUTing as a regression in YOUR change before checking the host delta; running `tests/run.sh` on a tool-shell whose PATH lacks `~/.pixi/bin` (wasm/node legs resolve tools only through PATH + the case fallbacks).
- **Recurrence (2026-10-09, second hang)**: the binaryen install closed only the wasm-opt leg; the no-install omission kept the *wasm-bindgen* download live -- `t-rust-wasm` hung again (14 min, ESTAB to the GitHub Pages CDN) once the `# requires: node` gate legitimately opened. Root-cause fix landed: both wasm-pack rules pin `--mode no-install --dev` (D36), the example probes wasm-bindgen presence, the case mirrors that gate.
- **Forbidden (added)**: closing a PIT's symptom (install the missing binary) while its stated root cause names an unfixed code omission -- the hang returns through the next un-exercised path.

## PIT-56: user-quote Chinese inside memorys/rules is NOT C4-exempt -- the double-quote allowance is SKILL.md trigger phrases only (2026-10-09)
- **Symptom**: canonical C4 went truly red on 6 lines: PIT-46/PIT-50 symptom lines quoting the user's Chinese verbatim and edit-safety rule #27's trigger list/precedent quotes.
- **Root cause**: the 2026-10-08 lesson-review round wrote verbatim user-Chinese quotes (a `user: "<why...>"` string in the source) into `.agents/memorys/` + `.agents/rules/`; C4's exemption was deliberately narrowed to a quoted-CJK line in `.agents/skills/*/SKILL.md` (activation surface), everything else stays English. The gate itself had not been re-run on that round's files before stamping "C4 pass".
- **Solution**: translate the quotes, keep provenance with "(translated from the user's Chinese)"; semantic verbatimness is preserved, the machine-consumed surface stays English.
- **Verification**: C4 canonical block from conventions.md verbatim -> `CJK outside allowed zones: none`.
- **Forbidden**: citing the SKILL.md quote exemption to justify CJK in memorys/rules; stamping "C4 pass" without running the block on the files of your own round.

## PIT-57: rename sweeps strand STRING paths -- second occurrence; now gate-scanned (2026-10-09)
- **Symptom**: 6 remote buttons in `examples/CMakeLists.txt` ran `cmake -S`/`cmake -P`
  against nonexistent `polyorch-*` directories (broken at HEAD since D28), and
  `examples/README.md` carried `--target` commands naming targets that do not exist.
  No test caught it: no leg executes button COMMANDs; t-examples-gates asserts
  registration + STATUS text only.
- **Root cause**: same class as PIT-28 -- CMake names/paths are strings with no
  symbol linkage; the sweep that re-prefixed target names also hit path-segment
  strings and README commands. A path only evaluated at click time can never
  false-fail a configure-time assertion.
- **Solution**: paths fixed toward the D27 bare-directory grammar (directories are
  the grammar, the prefixed paths were the collateral); README commands aligned;
  `t-examples-gates` leg 3 auto-scans every SOURCE_DIR reference in
  `examples/CMakeLists.txt` for path existence, with an empty-scan tripwire.
- **Verification**: plant a bad path -> case red; restore -> green (observed live
  2026-10-09). Offline suite 67/0/26.
- **Prevention**: any rename sweep of CMake names or paths must end against a
  FRESH empirical target/path list (rule 21 idiom) -- and for run-time-only string
  references, at least one leg must execute them or assert their target exists
  (leg 3 is that leg for examples/ buttons).
- **Blocking condition**: committing a rename sweep with no run-path assertion in
  place for the touched strings.

## PIT-58: a `# requires:` probe missing discovery tiers desyncs gate from product -- false FATAL, not false skip (2026-10-09)
- **Symptom**: `t-rust-fusion` FATALed "fused node target registered WITHOUT node+pm
  (degradation broken)" on the post-flip host; the product's discovery found
  node+npm while the case's node capability reported absent.
- **Root cause**: `_requires.cmake` probed node through three tiers (PATH ->
  `~/.pixi/bin` -> pixi-env glob) but its npm/corepack companions through PATH only.
  A pixi-global npm lives in `~/.pixi/bin`; the gate (parent shell PATH) and the
  product (driver-composed child PATH) then disagree on tool presence and the case
  picks the WRONG assertion polarity -- the else-leg fires on a host where the
  positive leg was the truth.
- **Solution**: the PM probe mirrors the same tiers as node. Rule: a capability
  probe is a COPY of the product face's discovery, tier-for-tier -- never a subset.
- **Verification**: t-rust-fusion OK standalone; offline suite 67/0/26 with the node
  family executing.
- **Prevention**: when a face grows a discovery tier, grep `tests/cases/_requires.cmake`
  for the matching capability in the same commit (PIT-48 class, applied to gates).
- **Blocking condition**: adding/altering a face's discovery tiers while the
  corresponding `# requires:` probe keeps a narrower search.

## PIT-59: long suites behind a foreground pipe-filter -- grep buffers nothing shows, tail clips the names; two tool timeouts cost two full re-runs (2026-10-09)
- **Symptom**: `bash tests/run.sh 2>&1 | grep -E '^FAIL'` (600s, then 900s retry) returned "(no output)" and was killed by the tool timeout -- no FAIL names, twice. The earlier `| tail -4` run HAD completed but showed only the summary (pass=58 fail=2 skip=33): the two failing case names had scrolled past the window.
- **Root cause**: (a) grep block-buffers when stdout is not a tty -- a filtering pipe on a long run shows NOTHING until the process exits, so the whole tool window burns while the names sit unflushed; (b) the suite's wall time had grown legitimately (the node/wasm gates opened and those legs now EXECUTE, PIT-55 doctrine) -- a timeout sized for the old ~1 min wall reads as a hang but is just longer work; (c) `tail -N` on a possible-failure run structurally cannot keep the names.
- **Solution**: the monitored run pattern, used twice with zero loss today: `nohup <suite> > /tmp/.../suite.log 2>&1 & echo bg=$!` then poll `while ps -p $pid; do sleep 15; done; grep -E '^FAIL|pass=' suite.log`. Names come from the log after the fact; every tool window is a cheap poll, never a stream. On the FIRST run of an uncertain suite, tee full output to a file instead of piping to head/tail.
- **Verification**: `grep -E '^FAIL' /tmp/.../suite.log` returns the offending case stems (or nothing on green) with rc=0 regardless of wall time.
- **Forbidden**: foreground pipe-filters on runs whose wall may exceed the tool timeout; reading only `tail -4` when `fail>0`; declaring a suite "hung" before checking whether an environment flip opened new EXECUTing legs (cross-ref PIT-55 Forbidden).
- **Amendment (same session, observed twice)**: the `while ps -p $pid; do sleep; done` wait itself burns the tool timeout if the run exceeds it (600s and 840s windows were eaten before the gate finished). Prefer a NON-BLOCKING peek per round: `ps -p $pid >/dev/null && tail -3 suite.log || grep -E '^FAIL|pass=' suite.log` -- returns instantly, costs seconds, and the conversation keeps other work available between peeks.

## PIT-60: cmake_language(DEFER CALL) without DIRECTORY fires at the END OF THE INCLUDING DIRECTORY -- a shared deferred surface orphaned by the first opt-in (2026-10-09, user-found, fixed by 8a02fe9)
- **Symptom**: field report "hello-ts debug target not appearing" -- `polyorch_node_debug(TARGET "hello-ts")` registered, yet the generated launch.json carried no node row. Reproduced offline: python-earlier dirA + node-later dirB configured through one host -> "launch CREATED; ... python 1, node 0".
- **Root cause**: the three-face shared debug generator armed itself with `cmake_language(DEFER CALL ...)`; CMake defers to the end of the CURRENT (including) directory scope, so the FIRST opt-in subdirectory fired the single writer before later siblings (later iterations of the examples fusion loop) had registered their specs -- their rows were orphaned forever. Pre-existing since D32 (python shared the shape, unnoticed because rust opts in first in the fused tree and its own rows were all the suite asserted).
- **Solution**: all three faces defer with `DIRECTORY "${CMAKE_SOURCE_DIR}"` -- the single writer runs once at the TRUE end of configure, any opt-in order, any directory depth. Pinned by t-node-vscode's cross-sibling ordering leg (both polarities).
- **Verification**: `grep -n 'cmake_language(DEFER CALL' cmake/*.cmake` -- every call must carry `DIRECTORY "${CMAKE_SOURCE_DIR}"` or an explicit comment why a directory-local defer is intended.
- **Forbidden**: arming an end-of-configure single-writer deferred step from a reusable module WITHOUT the explicit DIRECTORY anchor -- the fire point is the first includer, not the last event.

## PIT-61: CMake-as-data -- every `${VAR}` destined for the CHILD configure must be `\${VAR}`-escaped at WRITE time (2026-10-09, user round x3 + same session x2 close calls)
- One-line: when a cmake (or test) writes another CMakeLists via string concatenation/file(WRITE), all `${...}` that must survive to child-configure time need `\${...}` escaping at write time -- t-node-vscode's ordering leg hit it three times (recorded in the 8a02fe9 commit text); this session twice came within one run of the same trap (leg-3's REPLACE pattern, MATCHALL's `\\$\\{`). Check: after generating, actually configure the generated file once (or grep the writer for unescaped `${` inside append blocks).

## PIT-62: a test that injects the very PATH a feature consumes renders a green e2e blind to the real invoker -- verify at the user's shell, not a helper's (2026-10-10, user-found via VSCode F5)
- **Symptom**: real VSCode debug broke with `tsc: not found` (task ran `cmake --build --target <ts-mediator>` -> `npm run build` -> `tsc -p .`), while `t-node-ts-debug.cmake` passed GREEN.
- **Root cause**: the node `polyorch_node_build` mediator invoked `npm run build` with NO environment of its own, so the npm script resolved sibling tools (`tsc`) from the AMBIENT PATH. The e2e case wrapped its own build step in `ENVIRONMENT "PATH=$ENV{PATH}:<tscdir>:<nodedir>:~/.pixi/bin"` -- it injected exactly the dependency the product failed to carry, so its green said nothing about VSCode's task shell (which lacks ~/.pixi/bin). Same class as the verification-honesty rule: a component test that stubs the boundary it claims to prove.
- **Solution**: make the mediator self-sufficient (library: `COMMAND ${CMAKE_COMMAND} -E env "PATH=<node-bin>:<pm-bin>:$ENV{PATH}" <pm> run build` -- the node-face twin of the rust PIT-14 host-env isolation), and let the example declare its tool dir via `PolyOrchNode_BUILD_ENV_PATH`. The e2e then RUNS THE BUILD WITH A STRIPPED `PATH=/usr/bin:/bin` (reproducing the task shell): RED before the fix, GREEN after -- a real regression lock.
- **Verification**: `cmake -P tests/cases/t-node-ts-debug.cmake` builds the mediator under `PATH=/usr/bin:/bin` and still emits dist+map; offline 68/0/26, e2e 90/0/4, matrix 6/6. Reproduce-by-strip idiom: `env PATH=/usr/bin:/bin cmake --build <tree> --target <mediator>` must succeed.
- **Forbidden**: a test that supplies, via its own ENVIRONMENT, any resource (PATH entry, credential, cwd) that the PRODUCT is responsible for acquiring -- it converts the acceptance gate into a tautology. The user-facing invocation (GUI task, bare shell) must be reproduced with the product's OWN environment only.
- **Blocking condition**: claiming a debug/run surface "verified" when the harness, not the example/library, provided the toolchain location.

## PIT-63: js-debug `outFiles` names GENERATED JavaScript, not the `.map` -- a `.map` glob kills breakpoint prediction and an import-time-computes program finishes before runtime binding (2026-10-10, user-found grey breakpoint)
- **Symptom**: F5 on the `node-ts-basic` TS carrier attached, printed `total=15`, exited; the breakpoint in `src/index.ts` stayed GREY (unverified). Map + `sourceMaps:true` + program/cwd all correct -- only `outFiles` was `.../**/*.map`.
- **Root cause**: js-debug's `outFiles` "glob patterns specify the **generated JavaScript files**" (vscode-js-debug `src/configuration.ts#L219-225`); the map path is derived FROM the matched `.js` (sibling `.map`/`sourceMappingURL`). `**/*.map` matches only the map file, js-debug reads it as compiled JS, finds no `sourceMappingURL` comment -> no metadata -> **breakpoint PREDICTION (pre-load binding) is dead**. Runtime binding (`resolveSourceMapLocations`, extension-widened so `*.map` happens to match the map URL) still loads -- but `node-ts-basic` computes `total(5)` at MODULE LOAD (~1ms), so the top-level code runs to completion before the runtime-only path binds. Grey + no-pause = prediction lost + import-race.
- **Solution**: default `polyorch_node_debug` `OUTFILES` -> `${_dir}/**/*.js,!${_dir}/node_modules/**` (mirrors js-debug's own default `${workspaceFolder}/**/*.(m|c|)js`). Restores prediction -> binds before the program runs -> grey gone. The example may still pass an explicit `OUTFILES` override.
- **Verification**: `tests/cases/t-node-ts-debug.cmake` now asserts the generated launch row's `outFiles` is `[.../**/*.js, !.../node_modules/**]` (byte-exact); `t-node-vscode` default/passthrough pins moved off `.map`. Offline 68/0/26, matrix 6/6. GUI breakpoint-verify was subsequently CONFIRMED by the user (2026-10-10): after reconfiguring the build tree, VSCode F5 binds the src/index.ts breakpoint and pauses normally -- the grey-breakpoint symptom is cleared at the user-facing layer, not just in the emitted glob.
- **Forbidden**: setting `outFiles` to `*.map`. And the deeper class (extends PIT-62): when a launch attribute's job is to help the debugger find COMPILED output, point it at the compiled artifact the debugger loads, not at the sidecar metadata -- read the debugger's own attribute semantics (cited source), don't pattern-guess.
