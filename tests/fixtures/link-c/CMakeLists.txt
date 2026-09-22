# tests/fixtures/link-c -- fixture for cases/t-rust-link-c.cmake.
# P-2 acceptance: a Rust STATIC artifact linked by a real C consumer, end to
# end. The chain exercised for real (nothing mocked):
#   pixi rust -> polyorch_rust_setup (FROM pixi, WITH probe) -> the probe
#   discovers the system libs this triple's libstd needs -> polyorch_rust_build
#   (STATIC) attaches them as INTERFACE_LINK_LIBRARIES -> the C executable
#   (main.c) links the staticlib and, crucially, the C link would FAIL without
#   that interface: the crate calls libm's pow(), which the C compiler does
#   not link implicitly.
cmake_minimum_required(VERSION 3.25)
project(polyorch-fixture-link-c LANGUAGES C)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(PolyOrchPixiHelpers)
include(PolyOrchRustHelpers)
include("${CMAKE_CURRENT_LIST_DIR}/../../cases/_requires.cmake")

polyorch_requires(pixi-rust _req)
if(NOT _req)
    message(STATUS "polyorch-fixture-link-c : SKIP (no pixi env materialized with a cargo)")
    return()
endif()

# --- pixi bootstrap (WP2 deletes this block + pixi.toml) ----------------------
# Shared workspace override: a case that drives this fixture twice (positive
# + negative leg) points both configures at one pixi workspace so the second
# install replays the first one's lock instead of re-solving (the heredoc-era
# shared WORKDIR behavior). Default: one workspace per build dir.
if(POLYORCH_FIXTURE_PIXI_WS)
    set(_ws "${POLYORCH_FIXTURE_PIXI_WS}")
else()
    set(_ws "${CMAKE_BINARY_DIR}/pixi-ws")
endif()
file(MAKE_DIRECTORY "${_ws}")
file(COPY_FILE "${CMAKE_CURRENT_LIST_DIR}/pixi.toml" "${_ws}/pixi.toml")
polyorch_pixi_setup(MANIFEST "${_ws}/pixi.toml" ENVIRONMENT rust INSTALL)

# Probe ON (default): the STATIC interface this test asserts comes from it.
polyorch_rust_setup(FROM pixi REQUIRED)

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
