# tests/fixtures/install-versioned -- producer fixture for
# t-rust-install-versioned-e2e (SR5 combined acceptance): a REAL cargo-built
# cdylib staged through the full SR5 keyword shape -- SOVERSION/VERSION
# triple + NAMESPACE + handle=alias + COMPONENTS + SUITE_VERSION/
# COMPATIBILITY + STRIP + HEADERS_DIRECTORY + GLOB_HEADERS + STALE_GLOB.
# The case drives cmake --install twice (with and without --strip) and
# consumes the tree with a second, unrelated C project through
# find_package(vpack CONFIG REQUIRED COMPONENTS runtime).
cmake_minimum_required(VERSION 3.25)
project(polyorch-fixture-install-versioned LANGUAGES NONE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(PolyOrchRustHelpers)
include("${CMAKE_CURRENT_LIST_DIR}/../../cases/_requires.cmake")

polyorch_requires(system-rust _req)
if(NOT _req)
    message(STATUS "polyorch-fixture-install-versioned : SKIP (no cargo on the child PATH)")
    return()
endif()

polyorch_rust_setup(REQUIRED)

polyorch_rust_build(TARGET vkit PACKAGE vkit CRATE vkit SHARED
    MANIFEST "${CMAKE_CURRENT_LIST_DIR}/rust-ws/vkit/Cargo.toml")

polyorch_rust_install(TARGETS "vkit=lib" EXPORT vpack NAMESPACE "vpack::"
    SOVERSION 0 VERSION 0.1.2 STRIP
    SUITE_VERSION 0.1.2 COMPATIBILITY SameMajorVersion
    COMPONENTS "runtime=vkit"
    HEADERS_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}/include" DESTINATION include/vpack # tree: impl.h -> include/vpack/impl.h
    GLOB_HEADERS "${CMAKE_CURRENT_LIST_DIR}/include"
    STALE_GLOB "libvkit*")

file(GENERATE OUTPUT "${CMAKE_BINARY_DIR}/name_shared.txt"
    CONTENT "$<TARGET_FILE_NAME:vkit>")

string(TOLOWER "${CMAKE_BUILD_TYPE}" _bt)
if(_bt STREQUAL "" OR _bt STREQUAL "debug")
    set(_profile debug)
else()
    set(_profile release)
endif()
_polyorch_rust_artifact_names(TRIPLE "${POLYORCH_RUST_HOST_TARGET}"
    KIND shared CRATE vkit PROFILE "${_profile}" FILE_OUT _sf DIR_OUT _sd)

set(POLYORCH_FIXTURE_ARTIFACTS "shared=${_sd}/${_sf}")
string(JOIN "\n" _af ${POLYORCH_FIXTURE_ARTIFACTS})
file(WRITE "${CMAKE_BINARY_DIR}/polyorch-fixture-artifacts.txt" "${_af}\n")
