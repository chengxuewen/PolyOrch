include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")

# polyorch_rust_setup info vars (Task 3C): the module already captures the
# full `rustc -vV` output to parse host:; the release: line must additionally
# surface as POLYORCH_RUST_RUSTC_VERSION next to POLYORCH_RUST_VERSION (the
# cargo version). Offline proof via stub rustc/cargo scripts at the front of
# PATH (find_program NO_CACHE re-searches the env PATH per call, so the stubs
# are what setup locates). Windows skipped: POSIX shell stubs.
if(NOT UNIX)
    message(STATUS "rust-rustc-version: SKIP (POSIX shell stubs)")
    return()
endif()

_polyorch_pixi_scratch(_s)
set(_bin "${_s}/stubbin")
file(MAKE_DIRECTORY "${_bin}")
file(WRITE "${_bin}/rustc" "#!/bin/sh
cat <<'STUB'
rustc 1.98.1 (abcdef123 2026-06-30)
binary: rustc
commit-hash: abcdef123
commit-date: 2026-06-30
host: x86_64-unknown-linux-gnu
release: 1.98.1
LLVM version: 21.1.0
STUB
")
file(WRITE "${_bin}/cargo" "#!/bin/sh
echo 'cargo 1.98.1 (fedcba987 2026-06-30)'
")
file(CHMOD "${_bin}/rustc" "${_bin}/cargo"
    PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE
                GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)

set(ENV{PATH} "${_bin}:$ENV{PATH}")

polyorch_rust_setup(FROM system REQUIRED)
ck_str("${POLYORCH_RUST_FOUND}" "TRUE")
ck_str("${POLYORCH_RUST_VERSION}" "1.98.1")
ck_str("${POLYORCH_RUST_HOST_TARGET}" "x86_64-unknown-linux-gnu")
# The new info var this case exists for:
ck_str("${POLYORCH_RUST_RUSTC_VERSION}" "1.98.1")

message(STATUS "rust-rustc-version: OK (rustc ${POLYORCH_RUST_RUSTC_VERSION} / cargo ${POLYORCH_RUST_VERSION})")
