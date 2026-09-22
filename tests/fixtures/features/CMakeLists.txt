# tests/fixtures/features -- fixture for cases/t-rust-features.cmake.
# WP9 gap-1 (reference test/features): the feature set that reaches CARGO is
# proven by a REAL cfg effect, not by property text. The crate cannot compile
# while its default feature is active (compile-breakage, the reference's own
# trick) and prints exactly the enabled feature names, so
#   polyorch_rust_set_features(FEATURES ... NO_DEFAULT_FEATURES)
# is load-bearing twice: deactivation lets the build happen at all, the
# FEATURES list decides which markers the run prints.
cmake_minimum_required(VERSION 3.25)
project(polyorch-fixture-features LANGUAGES NONE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(PolyOrchRustHelpers)
include("${CMAKE_CURRENT_LIST_DIR}/../../cases/_requires.cmake")

polyorch_requires(system-rust _req)
if(NOT _req)
    message(STATUS "polyorch-fixture-features : SKIP (no cargo on the child PATH)")
    return()
endif()

polyorch_rust_setup(REQUIRED)

# Negative handle: default features ACTIVE -> the compile_error fires. Built
# only on demand (the mediator is not in ALL), never listed as an artifact.
polyorch_rust_build(TARGET feat-off PACKAGE feat-probe CRATE feat-probe BINARY
    PROFILE debug BASE_DIR "${CMAKE_BINARY_DIR}/.cargo-target-off"
    MANIFEST "${CMAKE_CURRENT_LIST_DIR}/rust-ws/Cargo.toml")

# Positive handle: all three features on, defaults off. FEATURES is ONE
# generate-time genex reading the carrier's app_features list -- the
# reference's exact test/features shape
# ($<TARGET_PROPERTY:consumer,app_features>).
add_custom_target(feat-carrier)
set_property(TARGET feat-carrier APPEND PROPERTY app_features one)
set_property(TARGET feat-carrier APPEND PROPERTY app_features two)
set_property(TARGET feat-carrier APPEND PROPERTY app_features three)

polyorch_rust_build(TARGET feat-on PACKAGE feat-probe CRATE feat-probe BINARY
    PROFILE debug BASE_DIR "${CMAKE_BINARY_DIR}/.cargo-target-on"
    MANIFEST "${CMAKE_CURRENT_LIST_DIR}/rust-ws/Cargo.toml")
polyorch_rust_set_features(TARGET feat-on
    FEATURES "$<TARGET_PROPERTY:feat-carrier,app_features>"
    NO_DEFAULT_FEATURES)

get_target_property(_fb feat-on IMPORTED_LOCATION)
file(WRITE "${CMAKE_BINARY_DIR}/polyorch-fixture-artifacts.txt"
    "featbin=${_fb}\n")
