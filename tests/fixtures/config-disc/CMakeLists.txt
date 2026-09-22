# tests/fixtures/config-disc -- fixture for cases/t-rust-configdisc.cmake.
# WP9 gap-8 (reference test/config_discovery): cargo must FIND the
# .cargo/config.toml that sits beside the CMake project root, through the
# exact WORKING_DIRECTORY (--build runs in CMAKE_CURRENT_SOURCE_DIR) +
# --manifest-path (rust-ws/Cargo.toml) combo the PolyOrch cargo rule uses.
# The reference makes discovery load-bearing with a registry alias (needs
# crates.io); the inversion here keeps the fixture offline: [build]
# rustflags + [env] carry the settings, and the crate cannot even COMPILE
# unless cargo applied them (env! on a missing var is a hard error). This
# also exercises the deliberate RUSTFLAGS-elision contract: an empty
# RUSTFLAGS= entry would shadow the config file's rustflags (measured, the
# composition comment in polyorch_rust_build).
cmake_minimum_required(VERSION 3.25)
project(polyorch-fixture-config-disc LANGUAGES NONE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(PolyOrchRustHelpers)
include("${CMAKE_CURRENT_LIST_DIR}/../../cases/_requires.cmake")

polyorch_requires(system-rust _req)
if(NOT _req)
    message(STATUS "polyorch-fixture-config-disc : SKIP (no cargo on the child PATH)")
    return()
endif()

polyorch_rust_setup(REQUIRED)

polyorch_rust_build(TARGET cd-bin PACKAGE cd-probe CRATE cd-probe BINARY
    PROFILE debug BASE_DIR "${CMAKE_BINARY_DIR}/.cargo-target-cd"
    MANIFEST "${CMAKE_CURRENT_LIST_DIR}/rust-ws/Cargo.toml")

get_target_property(_cb cd-bin IMPORTED_LOCATION)
file(WRITE "${CMAKE_BINARY_DIR}/polyorch-fixture-artifacts.txt"
    "bin=${_cb}\n")
