#!/usr/bin/env bash
# PolyOrch CMake unit tests. Each cases/t-*.cmake runs under `cmake -P`
# (fresh process, fresh cache). Marker contract (identical in
# tests/CMakeLists.txt; full text in cases/_requires.cmake):
#   line 1   "# expect: fail"     -> the case must end in FATAL_ERROR
#            "# expect-log <re>"  -> exit 0 AND captured stdout+stderr must
#                                    contain a POSIX ERE match
#            "# e2e: required"    -> solves a real pixi environment; runs
#                                    only with POLYORCH_TEST_E2E=1 (unchanged,
#                                    orthogonal to the requires gate below)
#   line 2   optional "# expect-no-log <re>" (only as a real marker line --
#            nothing else on line 2 is ever a regex) or "# e2e: required"
#   by line 3 optional "# requires: <cap>" AFTER the expect/e2e markers. The
#            driver does NOT pre-gate on it: the case probes the capability
#            itself (cases/_requires.cmake) and, on a miss, prints the
#            contract skip line "<stem> : SKIP (<reason>)" and exits 0 --
#            counted here as SKIP (and as "Skipped" by ctest). A want-pass
#            case WITHOUT the marker that prints ": SKIP (" is VETOTED as a
#            FAIL: a silent skip is never a pass. Driver-level skip wording
#            ("SKIP <path> (...)") lacks the " : " and cannot collide --
#            t-driver-selflock.cmake pins both facts.
# Self-lock: t-driver-canary.cmake stamps $TMPDIR; a missing stamp after the
# loop, or zero executed cases with a non-empty case list, fails the run.
set -u
cd "$(dirname "$0")"

# Route every case's scratch into one directory we own and delete at the end:
# cmake -P has no CMAKE_CURRENT_BINARY_DIR, so _polyorch_pixi_scratch falls back
# to $TMPDIR -- pin it here instead of littering /tmp when the caller left it unset.
_scratch="$(pwd)/.scratch"
rm -rf -- "$_scratch"; mkdir -p "$_scratch"
export TMPDIR="$_scratch"

pass=0; fail=0; skip=0; registered=0
for t in cases/t-*.cmake; do
    registered=$((registered+1))
    want=0; got=0
    head -n1 "$t" | grep -qx '# expect: fail' && want=1
    logre=""; nologre=""
    if [ "$want" -eq 0 ]; then
        logre="$(head -n1 "$t" | sed -n 's/^# expect-log //p')"
        # Only a real marker line counts: an unconditional `p` would feed
        # any line 2 (typically an include statement) back as a forbidden-
        # log regex. Gate the print on the prefix matching.
        nologre="$(sed -n '2{/^# expect-no-log /{s/^# expect-no-log //;p}}' "$t")"
    fi
    reqline="$(head -n3 "$t" | grep -m1 '^# requires: ' || true)"
    reqcap="${reqline#'# requires: '}"
    if ! [ "${POLYORCH_TEST_E2E:-0}" = 1 ] && head -n2 "$t" | grep -qx '# e2e: required'; then
        echo "SKIP $t (POLYORCH_TEST_E2E=1 to run)"
        skip=$((skip+1)); continue
    fi
    log="$_scratch/.caselog"
    if cmake -P "$t" > "$log" 2>&1; then got=0; else got=1; fi
    # SKIP contract (see header). Exit-0 only: a failing case is judged by
    # its verdict, not vetoed for quoting the shape in an error message.
    if [ "$got" -eq 0 ] && grep -qF ': SKIP (' "$log"; then
        if [ "$want" -eq 0 ] && [ -z "$reqcap" ]; then
            echo "FAIL $t (SKIP veto -- unmarked case skipped as:"
            grep -F ': SKIP (' "$log"
            fail=$((fail+1)); rm -f -- "$log"; continue
        elif [ -n "$reqcap" ]; then
            echo "SKIP $t (contract skip, requires: $reqcap)"
            grep -F ': SKIP (' "$log"
            skip=$((skip+1)); rm -f -- "$log"; continue
        fi
    fi
    ok=0
    if [ -n "$logre$nologre" ]; then
        if [ "$got" -eq 0 ] \
           && { [ -z "$logre" ] || grep -qE "$logre" "$log"; } \
           && { [ -z "$nologre" ] || ! grep -qE "$nologre" "$log"; }; then ok=1; fi
    elif [ "$got" -eq "$want" ]; then ok=1; fi
    if [ "$ok" -eq 1 ]; then
        echo "PASS $t"
        pass=$((pass+1))
    else
        echo "FAIL $t (want-exit=$want got=$got logre='$logre' nologre='$nologre')"
        tail -n5 "$log"
        fail=$((fail+1))
    fi
    rm -f -- "$log"
done
# Tripwires: a suite that quietly stopped running cases must not report green.
# (executed is snapshotted from the loop alone so both wires can fire at once.)
executed=$((pass+fail))
[ -f "$_scratch/polyorch-canary.stamp" ] || {
    echo "DRIVER TRIPWIRE: canary did not execute (case filter broken?)"; fail=$((fail+1)); }
[ "$registered" -gt 0 ] && [ "$executed" -eq 0 ] && {
    echo "DRIVER TRIPWIRE: 0 of $registered case(s) executed"; fail=$((fail+1)); }
echo "----------------------------------------"
echo "pass=$pass fail=$fail skip=$skip"
rm -rf -- "$_scratch"
# belt: any scratch that still resolved to cwd (older cmake behavior, odd envs)
rm -rf -- polyorch-* polyorch-*-* 2>/dev/null
[ "$fail" -eq 0 ]
