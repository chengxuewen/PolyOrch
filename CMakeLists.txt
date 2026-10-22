
cmake_minimum_required(VERSION 3.25)  # 2026-10-10 (user adjudication 5-B): the node face's
# module-body cmr has required 3.25 since D33; raising the root declaration removes the
# drift so a too-old host fails HERE, at configure start, with CMake's standard error.

# Pure helper tree: no compiled sources. An embedding host does not need to enable CXX
# to add this directory -- BUT the PlatformSupport module needs a CXX compiler identity
# from an ANCESTOR project() (or an equivalent injection such as
# CMAKE_PROJECT_TOP_LEVEL_INCLUDES); without one its mkspec probe is a FATAL_ERROR.
project(PolyOrch VERSION 0.7.1 LANGUAGES NONE)

# Embed sentinel: a host detects "already added" via `if(NOT TARGET PolyOrch::PolyOrch)`.
# Imported so the name may carry '::' (real targets cannot; measured in tests/CMakeLists.txt)
# -- the Threads::Threads / <pkg>::<pkg> existence form (D27 naming grammar).
# 2026-10-10 (user adjudication 1-A): the sentinel carries the winning copy's module dir
# and version as INTERFACE properties -- the ONLY location/version channel readable from
# a host scope after add_subdirectory returns (module path does not propagate sideways;
# PolyOrch_SOURCE_DIR is a stale-prone cache entry under multiple checkouts).
if(TARGET PolyOrch::PolyOrch)
    message(STATUS "PolyOrch: sentinel already registered by an outer scope or a foreign target; skipping this copy")
    return()
endif()
add_library(PolyOrch::PolyOrch INTERFACE IMPORTED GLOBAL)
set_property(TARGET PolyOrch::PolyOrch PROPERTY INTERFACE_POLYORCH_CMAKE_DIR "${CMAKE_CURRENT_LIST_DIR}/cmake")
set_property(TARGET PolyOrch::PolyOrch PROPERTY INTERFACE_POLYORCH_VERSION "${PROJECT_VERSION}")

list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake")
include(${PROJECT_SOURCE_DIR}/cmake/PolyOrchCMakeHelpers.cmake)
include(${PROJECT_SOURCE_DIR}/cmake/PolyOrchOptionHelpers.cmake)
include(${PROJECT_SOURCE_DIR}/cmake/PolyOrchPlatformSupport.cmake)
include(${PROJECT_SOURCE_DIR}/cmake/PolyOrchPixiHelpers.cmake)
include(${PROJECT_SOURCE_DIR}/cmake/PolyOrchRustHelpers.cmake)
include(${PROJECT_SOURCE_DIR}/cmake/PolyOrchNodeHelpers.cmake)
include(${PROJECT_SOURCE_DIR}/cmake/PolyOrchPythonHelpers.cmake)
include(${PROJECT_SOURCE_DIR}/cmake/PolyOrchVSCodeDebugHelpers.cmake)
# 2026-10-10 (user adjudication 3-A): the sentinel contract is the COMPLETE face set --
# node/python/vscode joins the root include list so `add_subdirectory(PolyOrch)` alone
# delivers every polyorch_* command. The include_guard in each module makes this idempotent
# with the faces' own transitive includes (RustHelpers already pulls VSCodeDebug).

polyorch_option(PolyOrch_BUILD_EXAMPLES "Add the examples/ subtree to the build" ${PROJECT_IS_TOP_LEVEL})
if(PolyOrch_BUILD_EXAMPLES)
    add_subdirectory(examples)
endif()

polyorch_option(PolyOrch_BUILD_TESTS "Add the tests/ subtree and register its cases with CTest" ${PROJECT_IS_TOP_LEVEL})
if(PolyOrch_BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()