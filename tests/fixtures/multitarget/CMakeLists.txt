# tests/fixtures/multitarget -- fixture for cases/t-rust-multitarget.cmake.
# WP9 gap-6 (reference test/multitarget): ONE package, import-driven,
# yielding DISTINCT mediators and DISTINCT artifact paths per cargo target
# -- the rlib + its two bins in one polyorch_rust_import, both bins linking
# the same C static lib through polyorch_rust_link_libraries. The reference
# notes RUN_SERIAL "since the target dir size may cause issues"; here the
# distinctness (bin1 vs bin2 mediators, two --bin rules from one manifest)
# is the property under test, so the driver builds the two bin mediators
# explicitly and the case asserts the two run outputs separately.
cmake_minimum_required(VERSION 3.25)
project(polyorch-fixture-multitarget LANGUAGES C)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(PolyOrchRustHelpers)
include("${CMAKE_CURRENT_LIST_DIR}/../../cases/_requires.cmake")

polyorch_requires(system-rust _req)
if(NOT _req)
    message(STATUS "polyorch-fixture-multitarget : SKIP (no cargo on the child PATH)")
    return()
endif()

polyorch_rust_setup(REQUIRED)

polyorch_rust_import(MANIFEST "${CMAKE_CURRENT_LIST_DIR}/rust-ws/Cargo.toml"
    IMPORTED_TARGETS _imps)
# The import must have yielded one handle per importable cargo target: the
# staticlib (from [lib] crate-type: kinds lib+staticlib yield the BARE
# mt_lib handle -- only static+shared pairs get -static/-shared) and both
# bins (-exe suffix).
foreach(_want mt_lib bin1-exe bin2-exe)
    if(NOT _want IN_LIST _imps)
        message(FATAL_ERROR
            "polyorch-fixture-multitarget: import set [${_imps}] lacks ${_want}")
    endif()
endforeach()

add_library(clib_mt STATIC "${CMAKE_CURRENT_LIST_DIR}/clib_mt.c")
polyorch_rust_link_libraries(TARGET bin1-exe clib_mt)
polyorch_rust_link_libraries(TARGET bin2-exe clib_mt)

# Distinct paths: the two bin handles must not collapse onto one artifact.
get_target_property(_b1 bin1-exe IMPORTED_LOCATION)
get_target_property(_b2 bin2-exe IMPORTED_LOCATION)
if(_b1 STREQUAL _b2)
    message(FATAL_ERROR "polyorch-fixture-multitarget: bin1/bin2 share ${_b1}")
endif()
if(NOT _b1 MATCHES "/bin1$" OR NOT _b2 MATCHES "/bin2$")
    message(FATAL_ERROR
        "polyorch-fixture-multitarget: naming table broke bin1=${_b1} bin2=${_b2}")
endif()

file(WRITE "${CMAKE_BINARY_DIR}/polyorch-fixture-artifacts.txt"
    "bin1=${_b1}
bin2=${_b2}
")
