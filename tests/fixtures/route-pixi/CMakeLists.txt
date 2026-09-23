# tests/fixtures/route-pixi -- the pixi-route connectivity harness (dual-route
# plan WP3, 2026-09-23). Proves the FULL pixi line: pixi env materialization
# (setup + dependency + install -- the same explicit sequence the keeper case
# drives) -> polyorch_rust_setup(FROM pixi REQUIRED) -> cargo build INSIDE the
# env -> the binary runs and prints its marker. The route is the assertion:
# system cargo must not be consulted (REQUIRED + the env-scoped PATH wrapper
# make a silent system fallback impossible; PIT-14 strip holds per route).
cmake_minimum_required(VERSION 3.25)
project(polyorch-fixture-route-pixi LANGUAGES NONE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(PolyOrchPixiHelpers)
include(PolyOrchRustHelpers)
include("${CMAKE_CURRENT_LIST_DIR}/../../cases/_requires.cmake")

# Gate = the pixi TOOL only (the pixi-rust capability means an ALREADY
# materialized store; this fixture is its own materializer, so a cold store
# must not skip it -- network is its own loud failure via pixi_install).
polyorch_requires(pixi _req)
if(NOT _req)
    message(STATUS "polyorch-fixture-route-pixi : SKIP (no pixi tool)")
    return()
endif()

set(POLYORCH_PIXI_ENVIRONMENTS_DIR "${CMAKE_BINARY_DIR}/pixi-envs")
polyorch_pixi_setup(MANIFEST "${CMAKE_CURRENT_LIST_DIR}/ws/pixi.toml" ENVIRONMENT rust)
polyorch_pixi_dependency(DEPENDS rust FEATURE rust NO_INSTALL)
polyorch_pixi_install(ENVIRONMENT rust)

polyorch_rust_setup(FROM pixi REQUIRED)

polyorch_rust_build(TARGET rp-probe PACKAGE route-probe CRATE route-probe BINARY
    PROFILE debug BASE_DIR "${CMAKE_BINARY_DIR}/.cargo-target"
    MANIFEST "${CMAKE_CURRENT_LIST_DIR}/ws/Cargo.toml")

get_target_property(_bin rp-probe IMPORTED_LOCATION)
file(WRITE "${CMAKE_BINARY_DIR}/polyorch-fixture-artifacts.txt" "rpbin=${_bin}\n")
