# tests/fixtures/link-c -- fixture for cases/t-rust-link-c.cmake.
# P-2 acceptance: a Rust STATIC artifact linked by a real C consumer, end to
# end. The chain exercised for real (nothing mocked):
#   system rust -> polyorch_rust_setup (default route, WITH probe) -> the probe
#   discovers the system libs this triple's libstd needs -> polyorch_rust_build
#   (STATIC) attaches them as INTERFACE_LINK_LIBRARIES -> the C executable
#   (main.c) links the staticlib and, crucially, the C link would FAIL without
#   that interface: the crate calls libm's pow(), which the C compiler does
#   not link implicitly.
cmake_minimum_required(VERSION 3.25)
project(polyorch-fixture-link-c LANGUAGES C)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(PolyOrchRustHelpers)
include("${CMAKE_CURRENT_LIST_DIR}/../../cases/_requires.cmake")

# Since WP2 the rust face defaults to the toolchain on PATH (the driver
# composes the child PATH with ~/.cargo/bin -- tests/fixtures/_driver.cmake);
# this probe mirrors the case-side `# requires: system-rust` gate.
polyorch_requires(system-rust _req)
if(NOT _req)
    message(STATUS "polyorch-fixture-link-c : SKIP (no cargo on the child PATH)")
    return()
endif()

# Probe ON (default): the STATIC interface this test asserts comes from it.
polyorch_rust_setup(REQUIRED)

# Evidence the probe actually ran and found the toolchain's system libs.
file(WRITE "${CMAKE_BINARY_DIR}/native_libs.txt" "${POLYORCH_RUST_NATIVE_LIBS}")

polyorch_rust_build(TARGET greet-lib PACKAGE probe_staticlib CRATE probe_staticlib
    STATIC MANIFEST "${CMAKE_CURRENT_LIST_DIR}/rust-ws/Cargo.toml")
get_target_property(_iface greet-lib INTERFACE_LINK_LIBRARIES)
file(WRITE "${CMAKE_BINARY_DIR}/iface.txt" "${_iface}")

add_executable(capp "${CMAKE_CURRENT_LIST_DIR}/main.c")
target_link_libraries(capp PRIVATE greet-lib)

set(POLYORCH_FIXTURE_ARTIFACTS
    "capp=${CMAKE_BINARY_DIR}/capp${CMAKE_EXECUTABLE_SUFFIX}")
string(JOIN "\n" _af ${POLYORCH_FIXTURE_ARTIFACTS})
file(WRITE "${CMAKE_BINARY_DIR}/polyorch-fixture-artifacts.txt" "${_af}\n")
