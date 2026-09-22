# tests/fixtures/cbindgen -- fixture for cases/t-rust-cbindgen.cmake (stub
# legs) and cases/t-rust-cbindgen-e2e.cmake (live leg). Drives BOTH
# signatures of polyorch_rust_cbindgen: an auto leg on a real imported
# handle (rules generated, cargo never built here -- the regen targets run
# only the tool) and a manual leg on a user INTERFACE target with an
# explicit TARGET_TRIPLE and a HEADER_NAME carrying a relative directory.
# The tool is the tool-stubs/ stand-in offline (its header echoes the
# TARGET/CARGO/RUSTC env the rule passed -- a functional env assertion)
# or the real cbindgen live (# requires: cbindgen).
cmake_minimum_required(VERSION 3.25)
project(polyorch-fixture-cbindgen LANGUAGES NONE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(PolyOrchRustHelpers)
include("${CMAKE_CURRENT_LIST_DIR}/../../cases/_requires.cmake")

# setup feeds the rule's CARGO=/RUSTC= env values, and the auto leg needs
# the handle's mediator for the hostbuild triple switch.
polyorch_requires(system-rust _req)
if(NOT _req)
    message(STATUS "polyorch-fixture-cbindgen : SKIP (no cargo on the child PATH)")
    return()
endif()

polyorch_rust_setup(REQUIRED)

polyorch_rust_build(TARGET cb-lib PACKAGE cb_fixture CRATE cb_fixture
    STATIC MANIFEST "${CMAKE_CURRENT_LIST_DIR}/rust/Cargo.toml")

set(_pkw "")
if(DEFINED POLYORCH_TEST_TOOL_PREFIX)
    set(_stub "${POLYORCH_TEST_TOOL_PREFIX}/bin/cbindgen")
    file(CHMOD "${_stub}" PERMISSIONS
        OWNER_READ OWNER_WRITE OWNER_EXECUTE
        GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
    set(_pkw PREFIX "${POLYORCH_TEST_TOOL_PREFIX}")
endif()

# auto signature: attaches to the imported handle itself
polyorch_rust_cbindgen(TARGET cb-lib HEADER_NAME rust-lib.h ${_pkw})

# manual signature: own INTERFACE target, explicit triple, header under a
# relative directory (corr:2210-2213).
add_library(cb-manual INTERFACE)
polyorch_rust_cbindgen(
    MANIFEST_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}/rust"
    CARGO_PACKAGE cb_fixture
    BINDINGS_TARGET cb-manual
    TARGET_TRIPLE x86_64-unknown-linux-musl
    HEADER_NAME sub/manual.h
    ${_pkw})

file(WRITE "${CMAKE_BINARY_DIR}/host_triple.txt" "${POLYORCH_RUST_HOST_TARGET}\n")

set(_g "${CMAKE_CURRENT_BINARY_DIR}/polyorch_generated/cbindgen")
set(POLYORCH_FIXTURE_ARTIFACTS
    "autohdr=${_g}/cb-lib/include/rust-lib.h"
    "autodep=${_g}/cb-lib/depfile/rust-lib.h.d"
    "manualhdr=${_g}/cb-manual/include/sub/manual.h"
    "manualdep=${_g}/cb-manual/depfile/sub/manual.h.d")
string(JOIN "\n" _af ${POLYORCH_FIXTURE_ARTIFACTS})
file(WRITE "${CMAKE_BINARY_DIR}/polyorch-fixture-artifacts.txt" "${_af}\n")
