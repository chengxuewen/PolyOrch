
cmake_minimum_required(VERSION 3.22)


# Pure helper tree: no compiled sources, so no language is required. A host
# embedding it via add_subdirectory keeps its own languages.
project(PolyOrch VERSION 0.1.1 LANGUAGES NONE)

add_custom_target(${PROJECT_NAME})
set_target_properties(${PROJECT_NAME} PROPERTIES FOLDER ${PROJECT_NAME}/tools)

list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake")
include(${PROJECT_SOURCE_DIR}/cmake/PolyOrchCMakeHelpers.cmake)
include(${PROJECT_SOURCE_DIR}/cmake/PolyOrchOptionHelpers.cmake)
include(${PROJECT_SOURCE_DIR}/cmake/PolyOrchPlatformSupport.cmake)
include(${PROJECT_SOURCE_DIR}/cmake/PolyOrchPixiHelpers.cmake)
include(${PROJECT_SOURCE_DIR}/cmake/PolyOrchRustHelpers.cmake)

polyorch_option(PolyOrch_BUILD_EXAMPLES "Add the examples/ subtree to the build" ${PROJECT_IS_TOP_LEVEL})
if(PolyOrch_BUILD_EXAMPLES)
    add_subdirectory(examples)
endif()

polyorch_option(PolyOrch_BUILD_TESTS "Add the tests/ subtree and register its cases with CTest" ${PROJECT_IS_TOP_LEVEL})
if(PolyOrch_BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()