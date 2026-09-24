# tests/fixtures/vsdbg -- e2e fixture for cases/t-rust-vsdbg.cmake.
# A runnable bin crate + polyorch_rust_run with the VSCode debug surface ON
# (dir redirected into the build tree so the configure never writes outside
# the scratch). Reports the spec table through properties.txt.
cmake_minimum_required(VERSION 3.25)
project(polyorch-fixture-vsdbg LANGUAGES C)   # cc for the shadow target under test

# the debug surface hooks at INCLUDE time -- opt in before pulling it in
set(PolyOrch_RUST_VSCODE_DEBUG ON)
set(PolyOrch_RUST_VSCODE_DIR "${CMAKE_BINARY_DIR}/vsout" CACHE PATH "")

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(PolyOrchRustHelpers)
include("${CMAKE_CURRENT_LIST_DIR}/../../cases/_requires.cmake")

polyorch_requires(system-rust _req)
if(NOT _req)
    message(STATUS "polyorch-fixture-vsdbg : SKIP (no cargo on the child PATH)")
    return()
endif()

polyorch_rust_setup(REQUIRED NO_NATIVE_PROBE)

polyorch_rust_build(TARGET vb PACKAGE vsdbg-bin CRATE vsdbg-bin
    BINARY MANIFEST "${CMAKE_CURRENT_LIST_DIR}/rs/Cargo.toml")
polyorch_rust_run(TARGET vb)

get_property(_specs GLOBAL PROPERTY POLYORCH_RUST_DEBUG_SPECS)
string(JOIN "||" _specs_j ${_specs})
file(WRITE "${CMAKE_BINARY_DIR}/properties.txt"
    "specs=${_specs_j}\n")
set(POLYORCH_FIXTURE_ARTIFACTS
    "manifest=${CMAKE_CURRENT_LIST_DIR}/rs/Cargo.toml")
string(JOIN "\n" _af ${POLYORCH_FIXTURE_ARTIFACTS})
file(WRITE "${CMAKE_BINARY_DIR}/polyorch-fixture-artifacts.txt" "${_af}\n")
