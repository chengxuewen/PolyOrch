# tests/fixtures/env-var -- fixture for cases/t-rust-envvars.cmake.
# WP9 gap-4 (reference test/envvar): polyorch_rust_set_env_vars drives a
# REAL build-script env. Three entry shapes ride the channel: a literal
# VAR=VALUE, a VAR=generate-time-genex (the reference's INDIRECT_VAR_TEST
# trick), and a configure-time version token (the reference's
# COR_CARGO_VERSION_MAJOR/MINOR pair). build.rs panics on any missing var
# and bakes the values into the binary via cargo:rustc-env, so the case
# asserts the run output. The negative handle sets NO env and must fail to
# build at all.
cmake_minimum_required(VERSION 3.25)
project(polyorch-fixture-env-var LANGUAGES NONE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(PolyOrchRustHelpers)
include("${CMAKE_CURRENT_LIST_DIR}/../../cases/_requires.cmake")

polyorch_requires(system-rust _req)
if(NOT _req)
    message(STATUS "polyorch-fixture-env-var : SKIP (no cargo on the child PATH)")
    return()
endif()

polyorch_rust_setup(REQUIRED)

# Negative handle: NO env vars -> build.rs panics before compiling.
polyorch_rust_build(TARGET ev-off PACKAGE ev-probe CRATE ev-probe BINARY
    PROFILE debug BASE_DIR "${CMAKE_BINARY_DIR}/.cargo-target-off"
    MANIFEST "${CMAKE_CURRENT_LIST_DIR}/rust-ws/Cargo.toml")

# The genex-valued entry: the value side is read off a property at generate
# time (the reference reads it off the C++ consumer target).
add_custom_target(ev-carrier)
set_property(TARGET ev-carrier PROPERTY indirect_var "IND_VALUE")

polyorch_rust_build(TARGET ev-on PACKAGE ev-probe CRATE ev-probe BINARY
    PROFILE debug BASE_DIR "${CMAKE_BINARY_DIR}/.cargo-target-on"
    MANIFEST "${CMAKE_CURRENT_LIST_DIR}/rust-ws/Cargo.toml")
polyorch_rust_set_env_vars(TARGET ev-on
    POLYORCH_ENV_PROBE=EXPECTED_VALUE
    "POLYORCH_ENV_GENEX=$<TARGET_PROPERTY:ev-carrier,indirect_var>"
    "POLYORCH_ENV_CARGO_VER=${POLYORCH_RUST_CARGO_VERSION}")

get_target_property(_eb ev-on IMPORTED_LOCATION)
file(WRITE "${CMAKE_BINARY_DIR}/polyorch-fixture-artifacts.txt"
    "evbin=${_eb}\n")
