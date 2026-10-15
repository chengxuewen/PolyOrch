# tests/fixtures/rust-lib -- fixture for cases/t-rust-lib.cmake (R3 LIB kind).
# One lib crate (lib name demo_core) plus one bin (never_built) in the same
# package: the bin exists ONLY so the e2e can prove `cargo build --lib`
# restricts to the lib target -- after the mediator build the rlib must exist
# and the bin path must NOT. The call also names the aggregate
# (PolyOrch_RUST_AGGREGATE_NAME liball); the case drives a FRESH build dir
# through the aggregate alone, so a missing membership edge strands the rlib
# and the driver's artifact assertion fails loudly (behavioral edge proof, not
# text). The handle is INTERFACE IMPORTED (no link line, ordering + path only,
# decisions.md D42) -- the artifact path rides POLYORCH_RUST_LIB.
cmake_minimum_required(VERSION 3.25)
project(polyorch-fixture-rust-lib LANGUAGES NONE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(PolyOrchRustHelpers)
include("${CMAKE_CURRENT_LIST_DIR}/../../cases/_requires.cmake")

polyorch_requires(system-rust _req)
if(NOT _req)
    message(STATUS "polyorch-fixture-rust-lib : SKIP (no cargo on the child PATH)")
    return()
endif()

polyorch_rust_setup(REQUIRED NO_NATIVE_PROBE)

set(PolyOrch_RUST_AGGREGATE_NAME "liball")
polyorch_rust_build(TARGET demo PACKAGE lib-demo CRATE demo_core LIB
    MANIFEST "${CMAKE_CURRENT_LIST_DIR}/rust-ws/Cargo.toml")

# Handle stance pin (the same assertions the offline child carries, re-proved
# on the real setup route): INTERFACE imported, no IMPORTED_LOCATION, the path
# on both name spaces.
get_target_property(_type demo TYPE)
if(NOT _type STREQUAL "INTERFACE_LIBRARY")
    message(FATAL_ERROR "rust-lib fixture: handle type '${_type}' != INTERFACE_LIBRARY")
endif()
get_target_property(_loc demo IMPORTED_LOCATION)
if(_loc AND NOT _loc MATCHES "NOTFOUND")
    message(FATAL_ERROR "rust-lib fixture: LIB handle carries IMPORTED_LOCATION ${_loc}")
endif()
get_target_property(_lp demo POLYORCH_RUST_LIB)
get_target_property(_mp demo-build POLYORCH_RUST_LIB)
if(NOT _lp STREQUAL _mp)
    message(FATAL_ERROR "rust-lib fixture: handle/mediator path split ${_lp} vs ${_mp}")
endif()

# Cargo profile follows CMAKE_BUILD_TYPE (corr:762 semantics, same mapping the
# build rule uses internally): unset/Debug -> debug, anything else -> release.
string(TOLOWER "${CMAKE_BUILD_TYPE}" _bt)
if(_bt STREQUAL "" OR _bt STREQUAL "debug")
    set(_profile debug)
else()
    set(_profile release)
endif()
# Contract cross-check: the naming table must agree with the stamped property
# on the single-config host layer (the property is genex-free here).
_polyorch_rust_artifact_names(TRIPLE "${POLYORCH_RUST_HOST_TARGET}" KIND lib
    CRATE demo_core PROFILE "${_profile}" FILE_OUT _f DIR_OUT _d)
if(NOT _lp STREQUAL "${_d}/${_f}")
    message(FATAL_ERROR
        "rust-lib fixture: POLYORCH_RUST_LIB '${_lp}' != table '${_d}/${_f}'")
endif()

set(POLYORCH_FIXTURE_ARTIFACTS "demo=${_lp}")
string(JOIN "\n" _af ${POLYORCH_FIXTURE_ARTIFACTS})
file(WRITE "${CMAKE_BINARY_DIR}/polyorch-fixture-artifacts.txt" "${_af}\n")
