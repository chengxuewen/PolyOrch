# tests/fixtures/node-ide-sources -- fixture for cases/t-node-sources.cmake.
# The node-face IDE source mount (rust-face parity): every verb node's
# SOURCES carries the package's display files as HEADER_FILE_ONLY entries --
# cosmetic for IDE trees, never compile inputs. The child resolves the
# properties at its OWN configure time (get_property on same-configure
# targets is legal -- the channel precedent is
# tests/fixtures/ide-sources/CMakeLists.txt writing sources.txt) and reports
# one line per target: "<handle>;n=<count>;<relpath>;...". The case asserts
# inclusion, exclusion, NO_SOURCES, verb parity and the PLAIN polarity from
# a second configure.
cmake_minimum_required(VERSION 3.25)
project(polyorch-fixture-node-ide-sources LANGUAGES NONE)

# Module dir: the in-repo spelling when configured in place; the case copies
# this tree to scratch (its vendor-exclusion bait cannot be committed --
# node_modules is gitignored), and the copy has no ../../../cmake beside it,
# so the parent passes the absolute path through this knob.
if(NOT POLYORCH_HARNESS_CMAKE_DIR)
    get_filename_component(POLYORCH_HARNESS_CMAKE_DIR
        "${CMAKE_CURRENT_SOURCE_DIR}/../../../cmake" ABSOLUTE)
endif()
list(APPEND CMAKE_MODULE_PATH "${POLYORCH_HARNESS_CMAKE_DIR}")
include(PolyOrchNodeHelpers)

# REQUIRED: the case's # requires: node probe passed, the child honors it
# (node-debug fixture shape).
polyorch_node_setup(REQUIRED)

# fixture artifact contract BEFORE any early return (PIT-34).
set(POLYORCH_FIXTURE_ARTIFACTS
    "manifest=${CMAKE_CURRENT_SOURCE_DIR}/package.json")
string(JOIN "\n" _af ${POLYORCH_FIXTURE_ARTIFACTS})
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/polyorch-fixture-artifacts.txt" "${_af}\n")

# creation sites 1+2: build() mediator (mounted) + NO_SOURCES twin (opt-out)
polyorch_node_build(TARGET demo
    MANIFEST "${CMAKE_CURRENT_SOURCE_DIR}/package.json")
polyorch_node_build(TARGET demo-nos NO_SOURCES
    MANIFEST "${CMAKE_CURRENT_SOURCE_DIR}/package.json")
# creation site 1: import per-member mediator (the root manifest doubles as
# the workspace root)
polyorch_node_import(ROOT "${CMAKE_CURRENT_SOURCE_DIR}/package.json")
# creation sites 3+4: verb nodes mount SOFT from the stamped DIR
polyorch_node_test(TARGET demo)
polyorch_node_run(TARGET demo SCRIPT start)

get_property(_demo TARGET demo-build     PROPERTY SOURCES)
get_property(_nos  TARGET demo-nos-build PROPERTY SOURCES)
get_property(_test TARGET demo-test      PROPERTY SOURCES)
get_property(_run  TARGET demo-run-start PROPERTY SOURCES)
get_property(_ws   TARGET ws-one-build   PROPERTY SOURCES)
if(_nos STREQUAL "NOTFOUND")
    set(_nos "")
endif()
# relativize against the (possibly copied) fixture root: tight, path-agnostic
# assertions in the parent case
set(_list_demo "${_demo}")
set(_list_nos "${_nos}")
set(_list_test "${_test}")
set(_list_run "${_run}")
set(_list_ws "${_ws}")
set(_txt "")
foreach(_nm demo nos test run ws)
    set(_fs "${_list_${_nm}}")
    set(_rel "")
    foreach(_f IN LISTS _fs)
        file(RELATIVE_PATH _r "${CMAKE_CURRENT_SOURCE_DIR}" "${_f}")
        list(APPEND _rel "${_r}")
    endforeach()
    list(LENGTH _rel _k)
    list(SORT _rel)
    list(JOIN _rel ";" _j)
    string(APPEND _txt "${_nm};n=${_k};${_j}\n")
endforeach()
# HEADER_FILE_ONLY polarity probe (first mounted file of demo-build)
list(GET _demo 0 _probe)
get_source_file_property(_hfo "${_probe}" HEADER_FILE_ONLY)
string(APPEND _txt "hfo=${_hfo};plain=${PolyOrch_NODE_SOURCES_PLAIN}\n")
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/sources.txt" "${_txt}")
