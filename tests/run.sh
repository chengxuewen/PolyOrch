#!/usr/bin/env bash
# PolyOrch CMake unit tests. Each cases/t-*.cmake runs under `cmake -P`
# (fresh process, fresh cache). A case whose FIRST line is exactly
#   # expect: fail
# must terminate with FATAL_ERROR to pass. Offline by default; set
# POLYORCH_TEST_E2E=1 to also run cases that solve a pixi environment.
# The same cases are registered with CTest via the tests/ subproject
# (configure PolyOrch with -DPolyOrch_BUILD_TESTS=ON; marker lines are shared).
# Two more markers (first line, optional second line; same semantics in both
# drivers -- here by grep on the captured log, in CTest via
# PASS_REGULAR_EXPRESSION / FAIL_REGULAR_EXPRESSION):
#   # expect-log <re>      -> case must exit 0 AND captured stdout+stderr
#                             (POSIX ERE) must contain a match
#   # expect-no-log <re>   -> (line 2, with expect-log) AND must NOT contain it
set -u
cd "$(dirname "$0")"

# Route every case's scratch into one directory we own and delete at the end:
# cmake -P has no CMAKE_CURRENT_BINARY_DIR, so _polyorch_pixi_scratch falls back
# to $TMPDIR -- pin it here instead of littering /tmp when the caller left it unset.
_scratch="$(pwd)/.scratch"
rm -rf -- "$_scratch"; mkdir -p "$_scratch"
export TMPDIR="$_scratch"
cd "$(dirname "$0")"

pass=0; fail=0; skip=0
for t in cases/t-*.cmake; do
    want=0; got=0
    head -n1 "$t" | grep -qx '# expect: fail' && want=1
    logre=""; nologre=""
    if [ "$want" -eq 0 ]; then
        logre="$(head -n1 "$t" | sed -n 's/^# expect-log //p')"
        nologre="$(sed -n '2{s/^# expect-no-log //;p}' "$t")"
    fi
    if ! [ "${POLYORCH_TEST_E2E:-0}" = 1 ] && head -n2 "$t" | grep -qx '# e2e: required'; then
        echo "SKIP $t (POLYORCH_TEST_E2E=1 to run)"
        skip=$((skip+1)); continue
    fi
    log="$_scratch/.caselog"
    if cmake -P "$t" > "$log" 2>&1; then got=0; else got=1; fi
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
echo "----------------------------------------"
echo "pass=$pass fail=$fail skip=$skip"
rm -rf -- "$_scratch"
# belt: any scratch that still resolved to cwd (older cmake behavior, odd envs)
rm -rf -- polyorch-* polyorch-*-* 2>/dev/null
[ "$fail" -eq 0 ]
