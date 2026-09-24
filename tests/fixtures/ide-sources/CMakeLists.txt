# tests/fixtures/ide-sources -- fixture for cases/t-rust-ide-sources.cmake.
# The IDE source mount: <handle>-build SOURCES carries the crate's rust
# files (glob, CONFIGURE_DEPENDS) as HEADER_FILE_ONLY entries -- cosmetic
# for IDE trees, never compile inputs. The fixture resolves the property
# at configure time and reports it through the artifacts channel.
cmake_minimum_required(VERSION 3.25)
project(polyorch-fixture-ide-sources LANGUAGES NONE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(PolyOrchRustHelpers)
include("${CMAKE_CURRENT_LIST_DIR}/../../cases/_requires.cmake")

polyorch_requires(system-rust _req)
if(NOT _req)
    message(STATUS "polyorch-fixture-ide-sources : SKIP (no cargo on the child PATH)")
    return()
endif()

polyorch_rust_setup(REQUIRED NO_NATIVE_PROBE)

# RELATIVE manifest on purpose: the source-mount anchor must resolve it
# absolutely, or the glob scans the wrong tree (the user-reported bug).
polyorch_rust_build(TARGET sm PACKAGE ide-src CRATE ide-src
    STATIC MANIFEST "${CMAKE_CURRENT_LIST_DIR}/rs/Cargo.toml")
# relative manifest: legal, resolved against CMAKE_CURRENT_SOURCE_DIR
file(RELATIVE_PATH _rel_m "${CMAKE_SOURCE_DIR}" "${CMAKE_CURRENT_LIST_DIR}/rs/Cargo.toml")
polyorch_rust_build(TARGET sm-rel PACKAGE ide-src CRATE ide-src
    STATIC NO_SOURCES   # guard-pass leg: route resolves, sources live on sm
    MANIFEST "${_rel_m}"
    BASE_DIR "${CMAKE_BINARY_DIR}/rel")
polyorch_rust_build(TARGET sm-nos PACKAGE ide-src CRATE ide-src
    STATIC NO_SOURCES
    MANIFEST "${CMAKE_CURRENT_LIST_DIR}/rs/Cargo.toml"
    BASE_DIR "${CMAKE_BINARY_DIR}/ns")

get_property(_srcs TARGET sm-build PROPERTY SOURCES)
list(LENGTH _srcs _n)
list(JOIN _srcs ";" _srcs_j)
get_property(_srcs2 TARGET sm-nos-build PROPERTY SOURCES)
list(LENGTH _srcs2 _n2)
# properties channel (NOT artifacts.txt -- the driver asserts those are paths)
file(WRITE "${CMAKE_BINARY_DIR}/sources.txt"
    "n=${_n}\nfiles=${_srcs_j}\nnos=${_n2}\n")
set(POLYORCH_FIXTURE_ARTIFACTS
    "manifest=${CMAKE_CURRENT_LIST_DIR}/rs/Cargo.toml")   # driver asserts existence
string(JOIN "\n" _af ${POLYORCH_FIXTURE_ARTIFACTS})
file(WRITE "${CMAKE_BINARY_DIR}/polyorch-fixture-artifacts.txt" "${_af}\n")
