# tests/fixtures/node-strip-scopes -- D47 fixture: scope-strip + prefix
# interplay. Two members @mediaservo/admin and @mediaservo/client plus a bare
# client: with PolyOrch_NODE_STRIP_SCOPES=mediaservo the scoped handles
# collapse to admin/client (then the prefix keeps them namespaced); without
# the knob they keep the legacy mediaservo-admin/mediaservo-client forms.
# Configure-only: no real toolchain -- the node-exe knob points at cmake
# itself, the PM knob at /bin/echo; the -build mediators exist but never run.
cmake_minimum_required(VERSION 3.25)
project(polyorch-fixture-node-strip LANGUAGES NONE)

get_filename_component(_polyorch_cmake_dir
    "${CMAKE_CURRENT_SOURCE_DIR}/../../../cmake" ABSOLUTE)
list(APPEND CMAKE_MODULE_PATH "${_polyorch_cmake_dir}")
include(PolyOrchNodeHelpers)

polyorch_node_setup(REQUIRED)

polyorch_node_import(ROOT "${CMAKE_CURRENT_SOURCE_DIR}/package.json")

set(_px "")
if(PolyOrch_NODE_TARGET_PREFIX)
    set(_px "${PolyOrch_NODE_TARGET_PREFIX}-")
endif()
if(PolyOrch_NODE_STRIP_SCOPES)
    set(_want "${_px}admin;${_px}client;${_px}client-legacy")
else()
    set(_want "${_px}mediaservo-admin;${_px}mediaservo-client;${_px}client-legacy")
endif()
list(SORT _want)
set(_got "${POLYORCH_NODE_IMPORT_HANDLES}")
list(SORT _got)
if(NOT _got STREQUAL _want)
    message(FATAL_ERROR
        "stripinspect: handles [${POLYORCH_NODE_IMPORT_HANDLES}] != [${_want}]")
endif()
foreach(_h IN LISTS POLYORCH_NODE_IMPORT_HANDLES)
    if(NOT TARGET "${_h}-build")
        message(FATAL_ERROR "stripinspect: missing -build mediator for '${_h}'")
    endif()
endforeach()

message(STATUS "PASS-STRIP [${POLYORCH_NODE_IMPORT_HANDLES}]")
