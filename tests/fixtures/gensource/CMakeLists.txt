# tests/fixtures/gensource -- fixture for cases/t-rust-gensource.cmake.
# WP9 gap-7 (reference test/gensource, simplified): a generated .rs file
# MUST exist before cargo runs. The reference wires the generator as a
# cargo-prebuild dependency; PolyOrch's port uses the PREBUILD keyword's
# ordering edge and proves it PHYSICALLY:
#   * the generated file goes into the BINARY tree (source-tree generation,
#     like the reference, would race the matrix cells);
#   * the marker text is copied to a build-tree INPUT at configure time, so
#     the case can flip it to GENV2 and re-run the custom command -- the
#     cargo rule re-reads it through include! + env!, proving the file the
#     build script compiles IS the generated one;
#   * the rebuild leg asserts the new marker in the NEW binary.
cmake_minimum_required(VERSION 3.25)
project(polyorch-fixture-gensource LANGUAGES NONE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(PolyOrchRustHelpers)
include("${CMAKE_CURRENT_LIST_DIR}/../../cases/_requires.cmake")

polyorch_requires(system-rust _req)
if(NOT _req)
    message(STATUS "polyorch-fixture-gensource : SKIP (no cargo on the child PATH)")
    return()
endif()

polyorch_rust_setup(REQUIRED)

# Build-tree input copy of the marker (the case rewrites it to flip GENV1 ->
# GENV2; rewriting a source-tree file would race the matrix cells).
file(READ "${CMAKE_CURRENT_LIST_DIR}/marker.txt" _m0)
string(STRIP "${_m0}" _m0)
file(WRITE "${CMAKE_BINARY_DIR}/marker_in.txt" "${_m0}\n")

# The generator as a CMake custom command (the reference wires a host-built
# Rust generator binary; the ORDERING contract, not the generator's language,
# is the property under test -- and this keeps the fixture crates.io-free).
set(_gen_rs "${CMAKE_BINARY_DIR}/gen/incl.rs")
add_custom_command(OUTPUT "${_gen_rs}"
    COMMAND "${CMAKE_COMMAND}"
        "-DIN=${CMAKE_BINARY_DIR}/marker_in.txt" "-DOUT=${_gen_rs}"
        -P "${CMAKE_CURRENT_LIST_DIR}/_gen.cmake"
    DEPENDS "${CMAKE_BINARY_DIR}/marker_in.txt"
    COMMENT "generating incl.rs (POLYORCH_GEN marker)"
    VERBATIM)
add_custom_target(gs-gen DEPENDS "${_gen_rs}")

polyorch_rust_build(TARGET gs-bin PACKAGE gs-probe CRATE gs-probe BINARY
    PROFILE debug BASE_DIR "${CMAKE_BINARY_DIR}/.cargo-target-gs"
    PREBUILD gs-gen
    MANIFEST "${CMAKE_CURRENT_LIST_DIR}/rust-ws/Cargo.toml")
polyorch_rust_set_env_vars(TARGET gs-bin
    "POLYORCH_GEN_DIR=${CMAKE_BINARY_DIR}/gen")

get_target_property(_gb gs-bin IMPORTED_LOCATION)
file(WRITE "${CMAKE_BINARY_DIR}/polyorch-fixture-artifacts.txt"
    "bin=${_gb}
gen=${_gen_rs}
")
