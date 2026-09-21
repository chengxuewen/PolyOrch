#!/usr/bin/env bash
# PolyOrch CMake unit tests. Each cases/t-*.cmake runs under `cmake -P`
# (fresh process, fresh cache). A case whose FIRST line is exactly
#   # expect: fail
# must terminate with FATAL_ERROR to pass. Offline by default; set
# POLYORCH_TEST_E2E=1 to also run cases that solve a pixi environment.
# The same cases are registered with CTest via the tests/ subproject
# (configure PolyOrch with -DPolyOrch_BUILD_TESTS=ON; marker lines are shared).
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
    if ! [ "${POLYORCH_TEST_E2E:-0}" = 1 ] && head -n2 "$t" | grep -qx '# e2e: required'; then
        echo "SKIP $t (POLYORCH_TEST_E2E=1 to run)"
        skip=$((skip+1)); continue
    fi
    if cmake -P "$t" >/dev/null 2>&1; then got=0; else got=1; fi
    if [ "$got" -eq "$want" ]; then
        echo "PASS $t"
        pass=$((pass+1))
    else
        echo "FAIL $t (expected exit $want, got $got)"
        cmake -P "$t" 2>&1 | tail -n5
        fail=$((fail+1))
    fi
done
echo "----------------------------------------"
echo "pass=$pass fail=$fail skip=$skip"
rm -rf -- "$_scratch"
# belt: any scratch that still resolved to cwd (older cmake behavior, odd envs)
rm -rf -- polyorch-* polyorch-*-* 2>/dev/null
[ "$fail" -eq 0 ]
