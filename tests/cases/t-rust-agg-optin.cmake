# requires: sh
# t-rust-agg-optin -- the T-H10 aggregate semantics: NO aggregate exists
# unless the host names one (the default-named button escaped into every
# host's IDE tree before this round), and the aggregate takes the FOLDER
# of its CREATING call only (first-writer pin; later registrations must
# not drag the tree-wide button into their own folder -- measured defect:
# the drift landed polyorch-rust-all in the host's examples/rs).
cmake_policy(SET CMP0219 NEW)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")
_polyorch_pixi_scratch(_s)
set(_b "${_s}/agg")

# child A: no knob -> no aggregate under any name
file(WRITE "${_s}/projA/CMakeLists.txt" [=[
cmake_minimum_required(VERSION 3.25)
project(aggA NONE)
include("${POLYORCH_CMAKE_DIR}/PolyOrchRustHelpers.cmake")
set(POLYORCH_RUST_FOUND TRUE CACHE INTERNAL "")
set(POLYORCH_RUST_CARGO "/bin/true" CACHE INTERNAL "")
set(POLYORCH_RUST_HOST_TARGET "x86_64-unknown-linux-gnu" CACHE INTERNAL "")
file(WRITE "${CMAKE_CURRENT_SOURCE_DIR}/Cargo.toml" "[package]\nname = \"p\"\nversion = \"0.1.0\"\nedition = \"2021\"\n")
polyorch_rust_build(TARGET t_a PACKAGE p CRATE t_a STATIC
  MANIFEST "${CMAKE_CURRENT_SOURCE_DIR}/Cargo.toml" NO_SOURCES FOLDER "lane/a")
if(TARGET polyorch-rust-all)
  message(STATUS "PROBE_A=default-present")
else()
  message(STATUS "PROBE_A=none")
endif()
]=])

# child B: named knob, two lanes -> the aggregate joins ONLY the creator's folder
file(WRITE "${_s}/projB/CMakeLists.txt" [=[
cmake_minimum_required(VERSION 3.25)
project(aggB NONE)
include("${POLYORCH_CMAKE_DIR}/PolyOrchRustHelpers.cmake")
set(PolyOrch_RUST_AGGREGATE_NAME "my-agg" CACHE STRING "")
set(POLYORCH_RUST_FOUND TRUE CACHE INTERNAL "")
set(POLYORCH_RUST_CARGO "/bin/true" CACHE INTERNAL "")
set(POLYORCH_RUST_HOST_TARGET "x86_64-unknown-linux-gnu" CACHE INTERNAL "")
file(WRITE "${CMAKE_CURRENT_SOURCE_DIR}/Cargo.toml" "[package]\nname = \"p\"\nversion = \"0.1.0\"\nedition = \"2021\"\n")
foreach(_n b1 b2)
  polyorch_rust_build(TARGET ${_n} PACKAGE p CRATE ${_n} STATIC
      MANIFEST "${CMAKE_CURRENT_SOURCE_DIR}/Cargo.toml" NO_SOURCES FOLDER "lane/${_n}")
endforeach()
get_target_property(_f my-agg FOLDER)
get_target_property(_f1 b1-build FOLDER)
get_target_property(_f2 b2-build FOLDER)
message(STATUS "PROBE_B=agg FOLD_AGG=${_f} FOLD_b1=${_f1} FOLD_b2=${_f2}")
]=])

set(_cmd_dir "${CMAKE_CURRENT_LIST_DIR}/../../cmake")
foreach(proj A B)
    execute_process(COMMAND "${CMAKE_COMMAND}"
        -S "${_s}/proj${proj}" -B "${_b}/${proj}"
        "-DPOLYORCH_CMAKE_DIR=${_cmd_dir}"
        RESULT_VARIABLE _rc OUTPUT_VARIABLE _o ERROR_VARIABLE _e)
    if(NOT _rc EQUAL 0)
        message(FATAL_ERROR "proj${proj} configure failed: ${_e}")
    endif()
    string(APPEND _ALL "${_o}${_e}")
endforeach()

if(NOT _ALL MATCHES "PROBE_A=none")
    message(FATAL_ERROR "no-knob tree grew an aggregate: ${_ALL}")
endif()
if(NOT _ALL MATCHES "PROBE_B=agg FOLD_AGG=lane/b1 FOLD_b1=lane/b1 FOLD_b2=lane/b2")
    message(FATAL_ERROR "named aggregate folder drift: ${_ALL}")
endif()
message(STATUS "t-rust-agg-optin: no-knob none + first-writer folder pin -- PASS")
