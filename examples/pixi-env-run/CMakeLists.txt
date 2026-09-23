# PolyOrch example: pixi environments are for ANY tool, not just rust.
# This is the "what do I GET from pixi" demo: materialize an environment
# that carries a tool, then run that tool from the env inside ordinary
# CMake custom targets -- no PATH games, no global installs.
#
#   # standalone:
#   cmake -S examples/pixi-env-run -B build -DPolyOrch_EXAMPLE_ROUTE=pixi
#   cmake --build build                       # two demo targets
#
# The first configure solves + installs (network; add
# -DPolyOrch_PIXI_MIRROR=cn on a domestic network), later ones are stamped
# no-ops. The manifest asks for `cmake` so the demo works everywhere; swap
# it for your real tools.
cmake_minimum_required(VERSION 3.22)
project(pixi-env-run-example LANGUAGES NONE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../cmake")
include(PolyOrchPixiHelpers)

set(PolyOrch_EXAMPLE_ROUTE "" CACHE STRING
    "example route: empty = skip this pixi-only demo; 'pixi' = materialize + run")
if(NOT PolyOrch_EXAMPLE_ROUTE STREQUAL "pixi")
    message(STATUS "pixi-env-run: skipped (opt in with -DPolyOrch_EXAMPLE_ROUTE=pixi; first configure solves)")
    return()
endif()

# [1/3] Declare + materialize the env (explicit action: solve + install now).
set(POLYORCH_PIXI_ENVIRONMENTS_DIR "${CMAKE_BINARY_DIR}/pixi-envs")
polyorch_pixi_setup(MANIFEST "${CMAKE_CURRENT_LIST_DIR}/pixi.toml" ENVIRONMENT tools)
polyorch_pixi_dependency(DEPENDS cmake FEATURE tools NO_INSTALL)
polyorch_pixi_install(ENVIRONMENT tools)

# [2/3] Where IS the env? env_paths answers read-only (prefix + bin dirs) --
# this is what "consuming the env" looks like: paths you can put on a
# custom command's PATH.
polyorch_pixi_env_paths(BIN_OUT _bin)
message(STATUS "pixi-env-run: env bin = ${_bin}")

# [3/3] Run env tools three ways:
#   (a) a plain execute_process during configure (env cmake --version)
execute_process(COMMAND "${_bin}/cmake" --version
    OUTPUT_VARIABLE _v ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE)
string(REGEX MATCH "cmake version [^\n]*" _v "${_v}")
message(STATUS "pixi-env-run: env cmake says '${_v}'")

#   (b) a custom target that runs the env tool at build time
add_custom_target(pixi-cmake-version
    COMMAND "${_bin}/cmake" --version
    COMMENT "Running the env's cmake")

#   (c) the env's cmake used as the tool to CONFIGURE another project --
#       the toolchain-independence punchline: this configure does not care
#       which cmake runs it.
add_custom_target(pixi-cmake-smoke
    COMMAND "${_bin}/cmake" -S "${CMAKE_CURRENT_LIST_DIR}" -B "${CMAKE_BINARY_DIR}/smoke"
    COMMENT "Configure THIS project with the env's own cmake")
