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
