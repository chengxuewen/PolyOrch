# requires: system-rust
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

# IDE source mount (2026-09-23): <handle>-build SOURCES carries the crate's
# rust files (glob + CONFIGURE_DEPENDS) as HEADER_FILE_ONLY entries --
# cosmetic for IDE trees, never compile inputs. The fixture resolves the
# SOURCES properties at configure time and writes them to sources.txt
# (the artifacts channel is for real paths only); this case asserts the
# counts, the expected files, the NO_SOURCES opt-out, and builds the
# mediator to prove the mount did not perturb the build chain.
set(_cfg "$ENV{POLYORCH_TEST_CONFIG}")
if(NOT _cfg)
    set(_cfg Debug)
endif()
_polyorch_pixi_scratch(_s)

set(_b "${_s}/is")
drv_run(_dlog _rc SKIP_VAR _skip
    FIXTURE "${CMAKE_CURRENT_LIST_DIR}/../fixtures/ide-sources"
    BUILD "${_b}" CONFIG "${_cfg}")
if(_skip)
    message(STATUS "t-rust-ide-sources : SKIP (fixture gate: no cargo)")
    return()
endif()

file(READ "${_b}/sources.txt" _src)
string(REGEX MATCH "n=([0-9]+)" _ "${_src}")
set(_n "${CMAKE_MATCH_1}")
ck(_n GREATER 0)
ck(_src MATCHES "lib\\.rs")
ck(_src MATCHES "Cargo\\.toml")        # the mount adds the manifest explicitly (dep edits live there)
string(REGEX MATCH "nos=([0-9]+)" _ "${_src}")
ck(CMAKE_MATCH_1 STREQUAL "0")
message(STATUS "ide-sources: OK (${_n} files mounted; NO_SOURCES opt-out empty)")

# verb-node parity (debug-workflow symmetry): run + test carry the same set
# capture into named vars (the file's existing CMAKE_MATCH pattern -- the
# magic var resolves unpredictably inside the ck macro's nested ${ARGN} deref)
string(REGEX MATCH "run=(.*)" _ "${_src}")
set(_run1 "${CMAKE_MATCH_1}")
string(REGEX MATCH "test=(.*)" _ "${_src}")
set(_test1 "${CMAKE_MATCH_1}")
foreach(_leg run test)
    set(_v "${_${_leg}1}")
    ck(_v MATCHES "lib\\.rs")
    ck(_v MATCHES "Cargo\\.toml")
    ck(_v MATCHES "Cargo\\.lock")
endforeach()
message(STATUS "ide-sources: verb-node mount parity OK")

# build the mediator: the mount must not perturb the chain
execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_b}" --target sm-build
    RESULT_VARIABLE _rc OUTPUT_QUIET ERROR_QUIET)
ck(_rc EQUAL 0)
message(STATUS "ide-sources: mediator build OK")

# empty-MANIFEST FATAL leg: build() without MANIFEST fails loudly
set(_bad "${_b}/noman")
file(MAKE_DIRECTORY "${_bad}")
file(WRITE "${_bad}/CMakeLists.txt"
    "cmake_minimum_required(VERSION 3.25)\nproject(n LANGUAGES NONE)\nlist(APPEND CMAKE_MODULE_PATH \"${CMAKE_CURRENT_LIST_DIR}/../../../cmake\")\ninclude(PolyOrchRustHelpers)\nset(POLYORCH_RUST_FOUND TRUE CACHE INTERNAL \"\")\nset(POLYORCH_RUST_CARGO \"/usr/bin/cmake\" CACHE INTERNAL \"\")\nset(POLYORCH_RUST_RUSTC \"/usr/bin/cmake\" CACHE INTERNAL \"\")\nset(POLYORCH_RUST_HOST_TARGET \"x86_64-unknown-linux-gnu\" CACHE INTERNAL \"\")\nset(POLYORCH_RUST_ROUTE \"system\" CACHE INTERNAL \"\")\npolyorch_rust_build(TARGET x PACKAGE x CRATE x BINARY)\n")
execute_process(COMMAND "${CMAKE_COMMAND}" -S "${_bad}" -B "${_bad}/b"
    RESULT_VARIABLE _rc OUTPUT_QUIET ERROR_QUIET)
ck(NOT _rc EQUAL 0)   # the guard fired
message(STATUS "ide-sources: empty-MANIFEST FATAL leg OK")
