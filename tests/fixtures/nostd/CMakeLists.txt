# tests/fixtures/nostd -- fixture for cases/t-rust-nostd.cmake.
# WP9 gap-9 (reference test/nostd, feasibility form): the reference gates
# behind its NO_STD keyword (absent here -- ledgered); the portable kernel
# is that a #![no_std] crate with its own panic_handler BUILDS through the
# standard wrapper and CMake links a consumer against it AS ARCHIVE MEMBERS
# (the reference's shape: nostd-cpp-lib is a STATIC target; the no_std
# archive still carries DW.ref.rust_eh_personality, so an executable link
# would need the runtime the crate deliberately omits). No keyword, no
# crates.io, no -nostdlib trickery.
cmake_minimum_required(VERSION 3.25)
project(polyorch-fixture-nostd LANGUAGES C)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(PolyOrchRustHelpers)
include("${CMAKE_CURRENT_LIST_DIR}/../../cases/_requires.cmake")

polyorch_requires(system-rust _req)
if(NOT _req)
    message(STATUS "polyorch-fixture-nostd : SKIP (no cargo on the child PATH)")
    return()
endif()

polyorch_rust_setup(REQUIRED)

polyorch_rust_build(TARGET ns-lib PACKAGE ns-probe CRATE ns_probe STATIC
    PROFILE debug BASE_DIR "${CMAKE_BINARY_DIR}/.cargo-target-ns"
    MANIFEST "${CMAKE_CURRENT_LIST_DIR}/rust-ws/Cargo.toml")
add_library(ns-cpp STATIC "${CMAKE_CURRENT_LIST_DIR}/ns_link.c")
target_link_libraries(ns-cpp PRIVATE ns-lib)

get_target_property(_ns ns-lib IMPORTED_LOCATION)
file(WRITE "${CMAKE_BINARY_DIR}/polyorch-fixture-artifacts.txt"
    "lib=${_ns}
cpp=${CMAKE_BINARY_DIR}/libns-cpp.a
")
