# tests/fixtures/install-export/consumer -- the SECOND project of
# t-rust-install-export: it discovers the staged rust package through a
# real find_package(polyorch-demo CONFIG REQUIRED) (the case passes
# -DCMAKE_PREFIX_PATH=<install stage> via the driver's PASSTHROUGH), so
# the generated <export>Config.cmake wrapper -> <export>-rust.cmake stub
# chain is what defines the `demo` handle here. The compile succeeds only
# if the stub re-attached the PUBLIC_HEADER directory (main.c includes
# <demo.h>); the link succeeds only if it re-attached the probed system
# libs (demo_pow keeps a live libm `pow` call). The case points the SAME
# project at a stub with the INTERFACE_LINK lines stripped: the link must
# then fail on `pow`.
cmake_minimum_required(VERSION 3.25)
project(polyorch-install-export-consumer LANGUAGES C)

find_package(polyorch-demo CONFIG REQUIRED)

if(NOT TARGET demo)
    message(FATAL_ERROR "consumer: find_package did not define demo")
endif()
if(NOT TARGET say-exe)
    message(FATAL_ERROR "consumer: find_package did not define say-exe")
endif()
# PACKAGE_PREFIX_DIR (the corr:1536 convention) IS set inside the Config
# while it processes -- measured, cmake 4.4.3, CMake then swallows that
# reserved name at the find_package boundary (ordinary variables leak,
# this one does not), so it cannot be re-read here. The chain is proven
# load-bearing by the stub replay + include-dir + link legs below.
get_target_property(_inc demo INTERFACE_INCLUDE_DIRECTORIES)
if(NOT _inc)
    message(FATAL_ERROR "consumer: stub attached no INTERFACE_INCLUDE_DIRECTORIES")
endif()
get_target_property(_loc demo IMPORTED_LOCATION)
if(NOT EXISTS "${_loc}")
    message(FATAL_ERROR "consumer: stub location does not exist: ${_loc}")
endif()

add_executable(capp "${CMAKE_CURRENT_LIST_DIR}/main.c")
target_link_libraries(capp PRIVATE demo)
file(GENERATE OUTPUT "${CMAKE_BINARY_DIR}/capp.txt" CONTENT "$<TARGET_FILE:capp>")

set(POLYORCH_FIXTURE_ARTIFACTS
    "capp=${CMAKE_BINARY_DIR}/capp${CMAKE_EXECUTABLE_SUFFIX}")
string(JOIN "\n" _af ${POLYORCH_FIXTURE_ARTIFACTS})
file(WRITE "${CMAKE_BINARY_DIR}/polyorch-fixture-artifacts.txt" "${_af}\n")
