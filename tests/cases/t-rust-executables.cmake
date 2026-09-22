# requires: posix-shell
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")

# WP2 executable-injection pair (the reference's user-var promotion equivalent,
# corr:FindRust.cmake:324-332 -- names per our D11 layering, ledger naming-map):
#   PolyOrch_RUST_CARGO_EXECUTABLE / PolyOrch_RUSTC_EXECUTABLE are honored
#   FIRST by polyorch_rust_setup -- when set, find_program is bypassed and the
#   value is validated (nonexistent path => FATAL regardless of REQUIRED).
# Offline proof via stub scripts (t-rust-rustc-version pattern): a discovery
# stub pair sits at the front of PATH printing 1.98.1, the INJECTED pair is a
# distinct stub printing 9.9.9 -- if setup still reports 9.9.9 the injection
# won over PATH. CARGO_TARGET leg: PolyOrch_RUST_CARGO_TARGET echoes verbatim
# into POLYORCH_RUST_CARGO_TARGET (WP5 consumes; warning-only placeholder).
# POSIX-only: the stubs are /bin/sh scripts (same gate as t-rust-rustc-version).
polyorch_requires(posix-shell _req)
if(NOT _req)
    message(STATUS "t-rust-executables : SKIP (stubs need a POSIX shell)")
    return()
endif()

_polyorch_pixi_scratch(_s)
set(_bin "${_s}/stubbin")       # discovered pair: cargo/rustc 1.98.1
set(_inj "${_s}/injected")      # injected pair: cargo/rustc 9.9.9
# Re-created before the child fork: the child leg names these dirs in its
# assertion paths (file(MAKE_DIRECTORY) is idempotent).
file(MAKE_DIRECTORY "${_bin}" "${_inj}")

# (a) child leg: an injected path that does not exist must FATAL -- proven
# BEFORE any discovery, so this works whatever PATH holds.
if(POLYORCH_CHILD)
    set(PolyOrch_RUST_CARGO_EXECUTABLE "${_bin}/nonexistent-cargo" CACHE INTERNAL "")
    polyorch_rust_setup(FROM system REQUIRED)
    message(FATAL_ERROR "expected setup to reject a nonexistent injected cargo")
endif()
# \s+ between "such" and "file": message(FATAL_ERROR) wraps long lines, so
# the flatten can leave a double space at the wrap point.
ck_child_fail("PolyOrch_RUST_CARGO_EXECUTABLE is set but no such +file")

file(WRITE "${_bin}/rustc" "#!/bin/sh
cat <<'STUB'
rustc 1.98.1 (abcdef123 2026-06-30)
binary: rustc
host: x86_64-unknown-linux-gnu
release: 1.98.1
STUB
")
file(WRITE "${_bin}/cargo" "#!/bin/sh
echo 'cargo 1.98.1 (fedcba987 2026-06-30)'
")
file(WRITE "${_inj}/rustc" "#!/bin/sh
cat <<'STUB'
rustc 9.9.9 (deadbeef0 2026-06-30)
binary: rustc
host: x86_64-unknown-linux-gnu
release: 9.9.9
STUB
")
file(WRITE "${_inj}/cargo" "#!/bin/sh
echo 'cargo 9.9.9 (deadbeef0 2026-06-30)'
")
foreach(_f "${_bin}/rustc" "${_bin}/cargo" "${_inj}/rustc" "${_inj}/cargo")
    file(CHMOD "${_f}"
        PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE
                    GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
endforeach()
set(ENV{PATH} "${_bin}:$ENV{PATH}")

# (b) injection wins over PATH: PATH yields 1.98.1, the injected stubs are
# versioned 9.9.9 -- the result vars must carry the injected paths + version.
set(PolyOrch_RUST_CARGO_EXECUTABLE "${_inj}/cargo" CACHE INTERNAL "")
set(PolyOrch_RUSTC_EXECUTABLE "${_inj}/rustc" CACHE INTERNAL "")
polyorch_rust_setup(FROM system REQUIRED NO_NATIVE_PROBE)
ck_str("${POLYORCH_RUST_FOUND}" "TRUE")
ck_str("${POLYORCH_RUST_CARGO}" "${_inj}/cargo")
ck_str("${POLYORCH_RUST_RUSTC}" "${_inj}/rustc")
ck_str("${POLYORCH_RUST_VERSION}" "9.9.9")
ck_str("${POLYORCH_RUST_RUSTC_VERSION}" "9.9.9")
ck_str("${POLYORCH_RUST_BIN_DIR}" "${_inj}")

# (c) CARGO_TARGET echo (WP2 scope: define + document + echo; routing lands
# in WP5). The result var must carry the cache value verbatim.
set(PolyOrch_RUST_CARGO_TARGET "wasm32-eabi-polyorch" CACHE STRING "WP2 echo-only")
polyorch_rust_setup(FROM system REQUIRED NO_NATIVE_PROBE)
ck_str("${POLYORCH_RUST_CARGO_TARGET}" "wasm32-eabi-polyorch")

message(STATUS "rust-executables: OK (injection beat PATH: 9.9.9 vs 1.98.1; target echo verbatim)")
