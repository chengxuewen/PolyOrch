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
# won over PATH. CARGO_TARGET leg (WP5 flip of the WP2 echo contract): a
# known cross triple is consumed into POLYORCH_RUST_CARGO_TARGET, a
# host-equal selection normalizes to the empty host layer, and an unknown
# triple fails at the naming-table family gate.
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

# (a) child legs: an injected path that does not exist must FATAL -- proven
# BEFORE any discovery, so this works whatever PATH holds; the unknown-triple
# leg (c3) reuses the same fork with a leg selector.
if(POLYORCH_CHILD)
    if("$ENV{POLYORCH_EXEC_LEG}" STREQUAL "badtriple")
        # The family gate runs before discovery, so this leg needs no
        # working toolchain -- just the bogus cache value.
        set(PolyOrch_RUST_CARGO_TARGET "wasm32-eabi-polyorch" CACHE INTERNAL "")
        polyorch_rust_setup(FROM system NO_NATIVE_PROBE)
        message(FATAL_ERROR "expected setup to reject the unknown cross triple")
    endif()
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

# (c1) WP5 consumption: a known cross triple carries through verbatim
# (family gate passes) and the host triple stays what the stubs report.
set(PolyOrch_RUST_CARGO_TARGET "x86_64-unknown-linux-musl" CACHE STRING "WP5 consumed" FORCE)
polyorch_rust_setup(FROM system REQUIRED NO_NATIVE_PROBE)
ck_str("${POLYORCH_RUST_CARGO_TARGET}" "x86_64-unknown-linux-musl")
ck_str("${POLYORCH_RUST_HOST_TARGET}" "x86_64-unknown-linux-gnu")

# (c2) an explicit host-equal selection is a no-op: normalized to the empty
# host layer (the locked t-rust-artifact-paths shape stays reachable).
set(PolyOrch_RUST_CARGO_TARGET "x86_64-unknown-linux-gnu" CACHE STRING "host-equal" FORCE)
polyorch_rust_setup(FROM system REQUIRED NO_NATIVE_PROBE)
ck_str("${POLYORCH_RUST_CARGO_TARGET}" "")

# (c3) an unknown triple FATALs at the naming-table family gate (cross must
# name a family PolyOrch can build and -- until the cross cluster's naming
# tables -- reason about); with or without REQUIRED it is an author mistake.
set(ENV{POLYORCH_EXEC_LEG} "badtriple")
ck_child_fail("unrecognized target triple .wasm32-eabi-polyorch.")
unset(ENV{POLYORCH_EXEC_LEG})
set(PolyOrch_RUST_CARGO_TARGET "" CACHE STRING "cleared" FORCE)

message(STATUS "rust-executables: OK (injection beat PATH: 9.9.9 vs 1.98.1; target consumed/gated)")
