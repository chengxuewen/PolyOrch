# tests/fixtures/install-e2e -- fixture for cases/t-rust-install-e2e.cmake.
# Task 6 acceptance (P-4 install-consumer chain): polyorch_rust_install stages
# a REAL cargo-built staticlib + bin, the EXPORT replay stub is included by a
# SECOND, unrelated C project (consumer/), and that consumer links + runs
# through the stub's re-attached interface. The negative leg (driven by the
# case) strips the INTERFACE_LINK lines from a stub copy and the SAME consumer
# must then FAIL to link with an undefined `pow` -- proof that what the
# positive leg exercises is what the stub ships (dash-ed passes the exponent
# base as an argument so rustc can never const-fold the pow call away).
#
# Workspace (mirrors the import-ws fixture): dash-ed staticlib (calls libm
# pow), say-hi bin, hookme staticlib. The hook leg is a direct
# polyorch_rust_build with [PREBUILD prebuild-stamp]: after building the
# aggregate the stamp file must exist -- nothing else produces it, so the
# ordering edge is the proof.
cmake_minimum_required(VERSION 3.25)
project(polyorch-fixture-install-e2e LANGUAGES NONE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(PolyOrchRustHelpers)
include("${CMAKE_CURRENT_LIST_DIR}/../../cases/_requires.cmake")

# Since WP2 the rust face defaults to the toolchain on PATH (the driver
# composes the child PATH with ~/.cargo/bin -- tests/fixtures/_driver.cmake);
# this probe mirrors the case-side `# requires: system-rust` gate.
polyorch_requires(system-rust _req)
if(NOT _req)
    message(STATUS "polyorch-fixture-install-e2e : SKIP (no cargo on the child PATH)")
    return()
endif()

# Probe ON (default): the installed-STATIC consumer chain is this test.
polyorch_rust_setup(REQUIRED)

set(_cws "${CMAKE_CURRENT_LIST_DIR}/rust-ws")

# PREBUILD leg: the stamp target produces nothing the build otherwise needs;
# its file existing after the aggregate build proves the ordering edge.
add_custom_target(prebuild-stamp
    COMMAND ${CMAKE_COMMAND} -E touch "${CMAKE_BINARY_DIR}/prebuild.txt")

polyorch_rust_import(MANIFEST "${_cws}/Cargo.toml"
    CRATES dash-ed;say-hi IMPORTED_TARGETS _imps)
file(WRITE "${CMAKE_BINARY_DIR}/imported.txt" "${_imps}")

polyorch_rust_build(TARGET hook-lib PACKAGE hookme CRATE hookme STATIC
    MANIFEST "${_cws}/Cargo.toml" PREBUILD prebuild-stamp)

polyorch_rust_install(TARGETS dash_ed say-hi-exe EXPORT demo)

# Staged-name evidence from the resolved genexes (the case derives the staged
# paths from these, never re-spelling file names).
file(GENERATE OUTPUT "${CMAKE_BINARY_DIR}/name_static.txt" CONTENT "$<TARGET_FILE_NAME:dash_ed>")
file(GENERATE OUTPUT "${CMAKE_BINARY_DIR}/name_bin.txt" CONTENT "$<TARGET_FILE_NAME:say-hi-exe>")

# Pre-install evidence: the cargo-built artifacts behind the handles exist
# once the build ran (profile mapping as the build rule resolves it).
string(TOLOWER "${CMAKE_BUILD_TYPE}" _bt)
if(_bt STREQUAL "" OR _bt STREQUAL "debug")
    set(_profile debug)
else()
    set(_profile release)
endif()
_polyorch_rust_artifact_names(TRIPLE "${POLYORCH_RUST_HOST_TARGET}"
    KIND static CRATE dash_ed PROFILE "${_profile}" FILE_OUT _lf DIR_OUT _ld)
_polyorch_rust_artifact_names(TRIPLE "${POLYORCH_RUST_HOST_TARGET}"
    KIND bin CRATE say-hi PROFILE "${_profile}" FILE_OUT _bf DIR_OUT _bd)

set(POLYORCH_FIXTURE_ARTIFACTS
    "static_lib=${_ld}/${_lf}"
    "bin=${_bd}/${_bf}"
    "prebuild=${CMAKE_BINARY_DIR}/prebuild.txt")
string(JOIN "\n" _af ${POLYORCH_FIXTURE_ARTIFACTS})
file(WRITE "${CMAKE_BINARY_DIR}/polyorch-fixture-artifacts.txt" "${_af}\n")
