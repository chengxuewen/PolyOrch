# tests/fixtures/cargo-flags -- fixture for cases/t-rust-cargoflags.cmake.
# WP9 gap-3 (reference test/cargo_flags): the FLAGS argv channel drives a
# real build. Two observable halves:
#   cf-flags   -- the crate cannot compile unless --features=one,two,three
#                 reached cargo, and the ONLY carrier of that flag is the
#                 POLYORCH_RUST_CARGO_FLAGS property read through a
#                 generate-time genex (the reference's more_flags leg; the
#                 value is one genex so the expanded flag stays ONE argv
#                 argument -- the mixed literal+genex list shape is not the
#                 reference's either, corr:705 todo).
#   cf-timings -- a flag with a physical BUILD-TREE effect: --timings
#                 must land cargo-timing-*.html in the cargo target dir
#                 (the reference's own observable-proof trick for this group).
cmake_minimum_required(VERSION 3.25)
project(polyorch-fixture-cargo-flags LANGUAGES NONE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(PolyOrchRustHelpers)
include("${CMAKE_CURRENT_LIST_DIR}/../../cases/_requires.cmake")

polyorch_requires(system-rust _req)
if(NOT _req)
    message(STATUS "polyorch-fixture-cargo-flags : SKIP (no cargo on the child PATH)")
    return()
endif()

polyorch_rust_setup(REQUIRED)

add_custom_target(cf-carrier)
set_property(TARGET cf-carrier PROPERTY more_flags "--features=one,two,three")

polyorch_rust_build(TARGET cf-flags PACKAGE cf-probe CRATE cf-probe BINARY
    PROFILE debug BASE_DIR "${CMAKE_BINARY_DIR}/.cargo-target-flags"
    MANIFEST "${CMAKE_CURRENT_LIST_DIR}/rust-ws/Cargo.toml")
polyorch_rust_add_cargo_flags(TARGET cf-flags
    FLAGS "$<TARGET_PROPERTY:cf-carrier,more_flags>")

polyorch_rust_build(TARGET cf-timings PACKAGE cf-probe CRATE cf-probe BINARY
    PROFILE debug BASE_DIR "${CMAKE_BINARY_DIR}/.cargo-target-timings"
    FEATURES one two three
    MANIFEST "${CMAKE_CURRENT_LIST_DIR}/rust-ws/Cargo.toml")
polyorch_rust_add_cargo_flags(TARGET cf-timings FLAGS --timings)

get_target_property(_cb cf-flags IMPORTED_LOCATION)
get_target_property(_tb cf-timings IMPORTED_LOCATION)
file(WRITE "${CMAKE_BINARY_DIR}/polyorch-fixture-artifacts.txt"
    "cfbin=${_cb}
timbase=${CMAKE_BINARY_DIR}/.cargo-target-timings
cfbin2=${_tb}
")
