# PolyOrch example: build a pixi workspace from CMake alone -- no external
# pixi.toml. Name, version, channels and platforms all come from the
# polyorch_pixi_init() call; ENVIRONMENTS_DIR puts the (multi-GB) env storage
# OUTSIDE the source tree at a fixed path while .pixi/ keeps only config.toml.
#
#   cmake -S examples/pixi-workspace -B build
#
# Nothing here reaches the network: creating the manifest and setting workspace
# properties are local. Installation stays an explicit `pixi install` step, so
# this is safe to run from an ordinary configure.
cmake_minimum_required(VERSION 3.22)
project(example-pixi-workspace LANGUAGES NONE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
include(PolyOrchPixiHelpers)

polyorch_pixi_find(QUIET)
if(NOT PolyOrch_PIXI_EXECUTABLE)
    message(WARNING
        "pixi not found -- run the pixi-bootstrap example first; "
        "workspace creation skipped")
    return()
endif()

set(_ws "${CMAKE_CURRENT_BINARY_DIR}/workspace")
polyorch_pixi_init(
    WORKDIR         "${_ws}"
    NAME            pixi-from-cmake
    VERSION         0.1.0
    CHANNELS        conda-forge
    PLATFORMS       linux-64 osx-arm64
    ENVIRONMENTS_DIR "${CMAKE_CURRENT_BINARY_DIR}/pixi-envs"
    IF_NOT_EXISTS           # idempotent across reconfigures, keeps user edits
    COPY_SCRIPTS)           # installs pixi.sh/pixi.bat/pixi.ps1 next to .pixi,
                            # so `source ./pixi.sh` activates this workspace


# The properties came from CMake args; read them back through pixi itself.
execute_process(COMMAND "${PolyOrch_PIXI_EXECUTABLE}" workspace name get
    -m "${_ws}" OUTPUT_VARIABLE _name OUTPUT_STRIP_TRAILING_WHITESPACE)
execute_process(COMMAND "${PolyOrch_PIXI_EXECUTABLE}" workspace version get
    -m "${_ws}" OUTPUT_VARIABLE _ver OUTPUT_STRIP_TRAILING_WHITESPACE)
message(STATUS "pixi workspace from CMake: name=${_name} version=${_ver}")
message(STATUS "  manifest: ${_ws}/pixi.toml")
message(STATUS "  envs dir: ${CMAKE_CURRENT_BINARY_DIR}/pixi-envs")
