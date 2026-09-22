# tests/fixtures/rule-wiring -- fixture for cases/t-rust-rule-wiring.cmake.
# The systemic PIT-13 net, fixture edition: the collision guard only protects
# against a name the USER picks; the class of bug is "the producing rule
# silently vanished in the real build system". This project proves the rule
# SURVIVES generation: the system cargo on the child PATH feeds
# polyorch_rust_setup, polyorch_rust_build
# wraps the greet-cli crate in rust-ws/, and the contract-anchored artifact
# (naming-table derived, genex-free) is declared for the driver to verify.
# The imported handle `greet` and the artifact base name `greet-cli` are kept
# DISTINCT on purpose -- the PIT-13 collision shape.
cmake_minimum_required(VERSION 3.25)
project(polyorch-fixture-rule-wiring LANGUAGES NONE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(PolyOrchRustHelpers)
include("${CMAKE_CURRENT_LIST_DIR}/../../cases/_requires.cmake")

# Contract gate (mirrors the case marker system): the driver relays this skip
# as "DRIVER: skip (...)" and stops honestly.
# Since WP2 the rust face defaults to the toolchain on PATH (the driver
# composes the child PATH with ~/.cargo/bin -- tests/fixtures/_driver.cmake);
# this probe mirrors the case-side `# requires: system-rust` gate.
polyorch_requires(system-rust _req)
if(NOT _req)
    message(STATUS "polyorch-fixture-rule-wiring : SKIP (no cargo on the child PATH)")
    return()
endif()

polyorch_rust_setup(REQUIRED NO_NATIVE_PROBE)

# The mediator, not the IMPORTED handle -- building "greet" itself is exactly
# the silently-no-op case PIT-13 describes. The case asks the driver to build
# the legacy mediator name "greet-cargo" (the rename to cargo-build-<T> must
# not break it).
polyorch_rust_build(TARGET greet PACKAGE greet-cli CRATE greet-cli BINARY
    MANIFEST "${CMAKE_CURRENT_LIST_DIR}/rust-ws/Cargo.toml")

# Cargo profile follows CMAKE_BUILD_TYPE (corr:762 semantics, same mapping the
# build rule uses internally): unset/Debug -> debug, anything else -> release.
string(TOLOWER "${CMAKE_BUILD_TYPE}" _bt)
if(_bt STREQUAL "" OR _bt STREQUAL "debug")
    set(_profile debug)
else()
    set(_profile release)
endif()
_polyorch_rust_artifact_names(TRIPLE "${POLYORCH_RUST_HOST_TARGET}" KIND bin
    CRATE greet-cli PROFILE "${_profile}" FILE_OUT _f DIR_OUT _d)

set(POLYORCH_FIXTURE_ARTIFACTS "greet=${_d}/${_f}")
string(JOIN "\n" _af ${POLYORCH_FIXTURE_ARTIFACTS})
file(WRITE "${CMAKE_BINARY_DIR}/polyorch-fixture-artifacts.txt" "${_af}\n")
