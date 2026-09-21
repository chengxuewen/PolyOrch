#!/usr/bin/env bash
# Local generator matrix (stand-in for the absent CI): throwaway host project
# x {Unix Makefiles, Ninja} x {Debug, Release}, full suite with e2e on.
# The repo ROOT is deliberately not configured (standalone it FATALs at the
# PlatformSupport mkspec detection - known state c79c4bf); the host only
# wires cmake/ + tests/.
#   usage: bash tests/matrix.sh          # ~1 min warm, network on cold cache
# NOTE(Task 2): the Release cells still build cargo `debug` artifacts (known
# flaw, profile<->CMAKE_BUILD_TYPE genex mapping); when it lands, add a
# per-cell profile-anchor assertion here: under CMAKE_BUILD_TYPE=Release the
# rust e2e rule must produce .cargo-target/release/<bin>, not .../debug/.
set -u
cd "$(dirname "$0")"; here="$(pwd)"; repo="$(dirname "$here")"
root="$(mktemp -d)"; trap 'rm -rf -- "$root"' EXIT
mkdir -p "$root/host"
cat > "$root/host/CMakeLists.txt" <<EOF
cmake_minimum_required(VERSION 3.25)
project(matrixhost LANGUAGES NONE)
list(APPEND CMAKE_MODULE_PATH "$repo/cmake")
include(PolyOrchCMakeHelpers)
include(PolyOrchPixiHelpers)
enable_testing()
add_subdirectory("$repo/tests" polyorch-tests)
EOF
rc_all=0; cells=0
for g in "Unix Makefiles" Ninja; do
    if [ "$g" = Ninja ] && ! command -v ninja >/dev/null 2>&1; then
        echo "NOTE generator cell skipped: ninja not on PATH"; continue
    fi
    for c in Debug Release; do
        b="$root/b-$(echo "$g$c" | tr -d ' ')"
        cells=$((cells+1))
        if cmake -S "$root/host" -B "$b" -G "$g" -DCMAKE_BUILD_TYPE="$c" \
                -DPolyOrch_TEST_E2E=ON > "$b.log" 2>&1 \
           && POLYORCH_TEST_E2E=1 ctest --test-dir "$b" --output-on-failure >> "$b.log" 2>&1; then
            echo "PASS [$g / $c]"
        else
            echo "FAIL [$g / $c] (log: $b.log)"; tail -n 15 "$b.log"; rc_all=1
        fi
    done
done
echo "matrix: $cells cell(s), rc=$rc_all"
exit $rc_all
