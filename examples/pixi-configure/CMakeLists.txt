# PolyOrch example: consume a pixi environment from an ordinary configure step.
#
#   cmake -S examples/pixi-configure -B build
#
# Read-only by design (no install, no lock write, no $HOME touch): it locates
# pixi, resolves the manifest and reports what would be used. A real project
# would add_subdirectory(PolyOrch) instead of including the module directly,
# and defer environment installation to build time with
#   polyorch_pixi_env_target(FROZEN)
cmake_minimum_required(VERSION 3.22)
project(example-pixi-configure LANGUAGES NONE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
include(PolyOrchPixiHelpers)

polyorch_pixi_find(QUIET)
if(NOT PolyOrch_PIXI_EXECUTABLE)
    message(WARNING
        "pixi not found -- run: cmake -P ../pixi-bootstrap/bootstrap.cmake")
else()
    polyorch_pixi_setup(
        MANIFEST "${CMAKE_CURRENT_SOURCE_DIR}/pixi.toml"
        REPORT)
endif()
