# tests/fixtures/rustflags -- fixture for cases/t-rust-rustflags.cmake.
# WP9 gap-2 (reference test/rustflags): polyorch_rust_add_rustflags drives a
# REAL cfg build. Flavors ported: plain --cfg, key="value" (the reference's
# --cfg=test_rustflag_cfg1="..." shape), and a generate-time $<CONFIG>
# genex (--cfg=test_rustflag_cfg2="$<IF:...>" in the reference). The
# GLOBAL-variant deviation is proven positively instead: the flag must reach
# the path dependency (rf-dep refuses to compile without --cfg=rf_glob) --
# the local `cargo rustc --` scope stays ledgered-deferred.
cmake_minimum_required(VERSION 3.25)
project(polyorch-fixture-rustflags LANGUAGES NONE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(PolyOrchRustHelpers)
include("${CMAKE_CURRENT_LIST_DIR}/../../cases/_requires.cmake")

polyorch_requires(system-rust _req)
if(NOT _req)
    message(STATUS "polyorch-fixture-rustflags : SKIP (no cargo on the child PATH)")
    return()
endif()

polyorch_rust_setup(REQUIRED)

# Negative handle: NO rustflags -> rf-dep's compile_error fires.
polyorch_rust_build(TARGET rf-off PACKAGE rf-probe CRATE rf-probe BINARY
    PROFILE debug BASE_DIR "${CMAKE_BINARY_DIR}/.cargo-target-off"
    MANIFEST "${CMAKE_CURRENT_LIST_DIR}/rust-ws/Cargo.toml")

polyorch_rust_build(TARGET rf-on PACKAGE rf-probe CRATE rf-probe BINARY
    PROFILE debug BASE_DIR "${CMAKE_BINARY_DIR}/.cargo-target-on"
    MANIFEST "${CMAKE_CURRENT_LIST_DIR}/rust-ws/Cargo.toml")
polyorch_rust_add_rustflags(TARGET rf-on FLAGS
    "--cfg=rf_one"
    "--cfg=rf_two=\"v\""
    "--cfg=rf_glob"
    "--cfg=rf_mode=\"$<IF:$<OR:$<CONFIG:Debug>,$<CONFIG:>>,debug,release>\"")

get_target_property(_rb rf-on IMPORTED_LOCATION)
file(WRITE "${CMAKE_BINARY_DIR}/polyorch-fixture-artifacts.txt"
    "rfbin=${_rb}\n")
