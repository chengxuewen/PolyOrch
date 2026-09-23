#!/usr/bin/env bash
# Local generator matrix (stand-in for the absent CI): throwaway host project
# x {Unix Makefiles, Ninja} x {Debug, Release} (4 classic cells), full suite
# with e2e on, PLUS one Ninja Multi-Config cell (WP4) -- see the MC note below.
# The repo ROOT is deliberately not configured (standalone it FATALs at the
# PlatformSupport mkspec detection - known state c79c4bf); the host only
# wires cmake/ + tests/.
#   usage: bash tests/matrix.sh          # ~1 min warm, network on cold cache
# Each cell exports POLYORCH_TEST_CONFIG=<cfg> and POLYORCH_TEST_GENERATOR=<g>
# into ctest (children inherit): t-rust-profile-release asserts the cargo
# profile dir the cell's CMAKE_BUILD_TYPE demands, and the fixture-driver
# cases (rule-wiring/import-ws/link-c/install-e2e/install-export) forward both into
# fixtures/_driver.cmake, so every fixture configure+build runs on the cell's
# generator and config. The per-cell verdict additionally greps the
# verbose re-run of that case for "(<Cfg> -> .cargo-target/<cfg>/" -- a
# Release cell may not pass via a debug artifact (right-reason gate).
#
# MC cell (WP4): runs the suite under -G "Ninja Multi-Config" twice,
# ctest -C Debug then -C Release (POLYORCH_TEST_CONFIG follows), EXCLUDING
# the pre-WP4 fixture-driver cases (rule-wiring/import-ws/link-c/
# install-e2e) plus the WP8 install-export case: their artifact contracts are written in single-config shape
# (capp=<b>/capp; import-ws pins file(GENERATE) without a $<CONFIG> slot,
# which an MC tree collapses to last-config-wins) -- a property of the
# harnesses, not of the product. Those four stay fully covered by the
# classic cells. The MC proof itself lives in t-rust-output-dir, which
# re-aims its single-config legs at Unix Makefiles under an MC parent and
# drives its own -G "Ninja Multi-Config" children with --config Debug AND
# Release (per-CFG IMPORTED_LOCATION + staging); the cell's right-reason
# gate greps its verbose re-run for the MC-Debug/.cargo-target/debug and
# MC-Release/.cargo-target/release markers.
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
        cl="$(echo "$c" | tr 'A-Z' 'a-z')"
        if cmake -S "$root/host" -B "$b" -G "$g" -DCMAKE_BUILD_TYPE="$c" \
                -DPolyOrch_TEST_E2E=ON > "$b.log" 2>&1 \
           && POLYORCH_TEST_E2E=1 POLYORCH_TEST_CONFIG="$c" POLYORCH_TEST_GENERATOR="$g" ctest --test-dir "$b" --output-on-failure >> "$b.log" 2>&1 \
           && POLYORCH_TEST_CONFIG="$c" ctest --test-dir "$b" -R '^polyorch::t-rust-profile-release$' -V >> "$b.log" 2>&1 \
           && grep -qE "\($c -> \.cargo-target/$cl/" "$b.log"; then
            echo "PASS [$g / $c]"
        else
            echo "FAIL [$g / $c] (log: $b.log)"; tail -n 15 "$b.log"; rc_all=1
        fi
    done
done

# --- Ninja Multi-Config cell (WP4) ------------------------------------------
# See the header MC note. Skips the single-config-shaped fixture cases
# (the pre-WP4 four + install-export + the WP9 import-built multitarget
# fixture: its per-config genex locations make the literal-path artifact
# contract single-config shape);
# the MC proof is t-rust-output-dir's own MC legs (--config Debug AND Release
# inside the case), so the cell's right-reason gate re-runs it verbose and
# greps both config markers.
if command -v ninja >/dev/null 2>&1; then
    cells=$((cells+1))
    b="$root/b-mc"
    excl='^polyorch::t-rust-(rule-wiring|import-ws|link-c|install-e2e|install-export|multitarget)$'
    if cmake -S "$root/host" -B "$b" -G "Ninja Multi-Config" \
            -DPolyOrch_TEST_E2E=ON > "$b.log" 2>&1 \
       && POLYORCH_TEST_E2E=1 POLYORCH_TEST_CONFIG=Debug POLYORCH_TEST_GENERATOR="Ninja Multi-Config" \
              ctest --test-dir "$b" -C Debug -E "$excl" --output-on-failure >> "$b.log" 2>&1 \
       && POLYORCH_TEST_E2E=1 POLYORCH_TEST_CONFIG=Release POLYORCH_TEST_GENERATOR="Ninja Multi-Config" \
              ctest --test-dir "$b" -C Release -E "$excl" --output-on-failure >> "$b.log" 2>&1 \
       && POLYORCH_TEST_CONFIG=Release ctest --test-dir "$b" -C Release -R '^polyorch::t-rust-output-dir$' -V >> "$b.log" 2>&1 \
       && grep -qE "MC-Debug cargo=.*\.cargo-target/debug/" "$b.log" \
       && grep -qE "MC-Release cargo=.*\.cargo-target/release/" "$b.log"; then
        echo "PASS [Ninja Multi-Config]"
    else
        echo "FAIL [Ninja Multi-Config] (log: $b.log)"; tail -n 15 "$b.log"; rc_all=1
    fi
else
    echo "NOTE Ninja Multi-Config cell skipped: ninja not on PATH"
fi
echo "matrix: $cells cell(s), rc=$rc_all"
exit $rc_all
