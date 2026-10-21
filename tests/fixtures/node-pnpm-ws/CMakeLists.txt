# tests/fixtures/node-pnpm-ws -- SR1 fixture: pnpm-workspace.yaml enumeration
# + packageManager PM probe. The root package.json deliberately has NO
# workspaces field (the pnpm shape); the member list lives solely in
# pnpm-workspace.yaml. Configure-only: no real node/pnpm needed -- the case
# passes the node-exe knob (cmake itself answers `--version` as a no-op
# binary) and the pnpm stub knob; the -build mediators exist but never run.
cmake_minimum_required(VERSION 3.25)
project(polyorch-fixture-node-pnpm-ws LANGUAGES NONE)

get_filename_component(_polyorch_cmake_dir
    "${CMAKE_CURRENT_SOURCE_DIR}/../../../cmake" ABSOLUTE)
list(APPEND CMAKE_MODULE_PATH "${_polyorch_cmake_dir}")
include(PolyOrchNodeHelpers)

polyorch_node_setup(REQUIRED)

# PM probe leg: packageManager "pnpm@..." must have selected pnpm.
if(NOT PolyOrchNode_PM_NAME STREQUAL "pnpm")
    message(FATAL_ERROR
        "pnpminspect: PM probe did not select pnpm (got '${PolyOrchNode_PM_NAME}')")
endif()

polyorch_node_import(ROOT "${CMAKE_CURRENT_SOURCE_DIR}/package.json")

# yaml enumeration leg: both members discovered via pnpm-workspace.yaml.
list(LENGTH POLYORCH_NODE_IMPORT_HANDLES _nh)
if(NOT _nh EQUAL 2)
    message(FATAL_ERROR
        "pnpminspect: expected 2 members from pnpm-workspace.yaml, got ${_nh}")
endif()
foreach(_h IN LISTS POLYORCH_NODE_IMPORT_HANDLES)
    if(NOT TARGET "${_h}-build")
        message(FATAL_ERROR "pnpminspect: missing -build mediator for '${_h}'")
    endif()
endforeach()

message(STATUS "PASS-PNPMWS [${POLYORCH_NODE_IMPORT_HANDLES}]")
