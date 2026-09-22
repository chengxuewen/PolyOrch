# tests/fixtures/custom-profiles -- fixture for cases/t-rust-customprofiles.cmake.
# WP9 gap-5 (reference test/custom_profiles + basic_profiles): four explicit
# PROFILE spellings through the same crate, each into its OWN cargo target
# dir (every artifact path distinct -- the multitarget RUN_SERIAL lesson
# applied: one cargo target dir shared by several handles of the same crate
# lets the last fingerprint win):
#   cp-debug    PROFILE debug   -> no --profile flag,    <base>/.ct-debug/debug
#   cp-release  PROFILE release -> --release,             <base>/.ct-release/release
#   cp-nodbg    PROFILE nodbg   -> --profile nodbg,      <base>/.ct-nodbg/nodbg
#   cp-dev      PROFILE dev     -> --profile dev,        <base>/.ct-dev/debug
# The cp-dev row pins the WP9 closure of the ledger OPEN row: cargo's
# built-in `dev` profile WRITES debug/, so the profile name is not the
# directory name -- PolyOrch normalizes it (corr:766-770). Custom names stay
# verbatim. The profile EFFECT is read off the RUN OUTPUT: debug_assertions
# is on in debug/dev, off in nodbg (the reference's [profile.*]
# debug-assertions toggle), never off a folded constant (PIT-21).
cmake_minimum_required(VERSION 3.25)
project(polyorch-fixture-custom-profiles LANGUAGES NONE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(PolyOrchRustHelpers)
include("${CMAKE_CURRENT_LIST_DIR}/../../cases/_requires.cmake")

polyorch_requires(system-rust _req)
if(NOT _req)
    message(STATUS "polyorch-fixture-custom-profiles : SKIP (no cargo on the child PATH)")
    return()
endif()

polyorch_rust_setup(REQUIRED)

set(_man "${CMAKE_CURRENT_LIST_DIR}/rust-ws/Cargo.toml")
polyorch_rust_build(TARGET cp-debug PACKAGE pp-probe CRATE pp-probe
    BINARY PROFILE debug BASE_DIR "${CMAKE_BINARY_DIR}/.ct-debug"
    MANIFEST "${_man}")
polyorch_rust_build(TARGET cp-release PACKAGE pp-probe CRATE pp-probe
    BINARY PROFILE release BASE_DIR "${CMAKE_BINARY_DIR}/.ct-release"
    MANIFEST "${_man}")
polyorch_rust_build(TARGET cp-nodbg PACKAGE pp-probe CRATE pp-probe
    BINARY PROFILE nodbg BASE_DIR "${CMAKE_BINARY_DIR}/.ct-nodbg"
    MANIFEST "${_man}")
polyorch_rust_build(TARGET cp-dev PACKAGE pp-probe CRATE pp-probe
    BINARY PROFILE dev BASE_DIR "${CMAKE_BINARY_DIR}/.ct-dev"
    MANIFEST "${_man}")

foreach(_h cp-debug cp-release cp-nodbg cp-dev)
    get_target_property(_loc ${_h} IMPORTED_LOCATION)
    string(REPLACE "cp-" "" _key ${_h})
    list(APPEND _arts "${_key}=${_loc}")
endforeach()
string(JOIN "\n" _af ${_arts})
file(WRITE "${CMAKE_BINARY_DIR}/polyorch-fixture-artifacts.txt" "${_af}\n")
