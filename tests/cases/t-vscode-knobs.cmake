# requires: sh
# t-vscode-knobs -- the T-H7 knob family (ALL boolean, octk OR semantics):
# the gate matrix through the real _polyorch_vscode_debug_gate in child
# configures (scope-real: the helper reads cache vars).
#   all_all       ALL=ON               -> every face ON
#   all_off_face  ALL=OFF + NODE=ON    -> NODE only (faces rule when ALL off)
#   face_only     RUST=ON              -> RUST only
#   legacy_only   legacy RUST knob     -> honored one cycle
#   default_off   nothing set          -> OFF
#   both          new + legacy RUST    -> FATAL (ambiguity is loud)
cmake_policy(SET CMP0219 NEW)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")
_polyorch_pixi_scratch(_s)
set(_b "${_s}/knobs")

file(WRITE "${_s}/proj/CMakeLists.txt" [=[
cmake_minimum_required(VERSION 3.25)
project(knobs NONE)
include("${POLYORCH_CMAKE_DIR}/_polyorch_vscode_debug_gate.cmake")

macro(probe face)
  _polyorch_vscode_debug_gate(${face} _v)
  message(STATUS "PROBE ${face}=${_v}")
endmacro()

if(CASE STREQUAL "all_all")
  set(PolyOrch_VSCODE_DEBUG_ALL ON)
  probe(RUST)
  probe(NODE)
elseif(CASE STREQUAL "all_off_face")
  set(PolyOrch_VSCODE_DEBUG_ALL OFF)
  set(PolyOrch_VSCODE_DEBUG_NODE ON)
  probe(RUST)
  probe(NODE)
elseif(CASE STREQUAL "face_only")
  set(PolyOrch_VSCODE_DEBUG_RUST ON)
  probe(RUST)
  probe(NODE)
elseif(CASE STREQUAL "legacy_only")
  set(PolyOrch_RUST_VSCODE_DEBUG ON)
  probe(RUST)
elseif(CASE STREQUAL "default_off")
  probe(RUST)
elseif(CASE STREQUAL "both")
  set(PolyOrch_VSCODE_DEBUG_RUST ON)
  set(PolyOrch_RUST_VSCODE_DEBUG ON)
  probe(RUST)
endif()
]=])

set(_cmd_dir "${CMAKE_CURRENT_LIST_DIR}/../../cmake")

foreach(case all_all all_off_face face_only legacy_only default_off)
  execute_process(COMMAND "${CMAKE_COMMAND}"
      -S "${_s}/proj" -B "${_b}/${case}"
      "-DPOLYORCH_CMAKE_DIR=${_cmd_dir}"
      "-DCASE=${case}"
      RESULT_VARIABLE _rc OUTPUT_VARIABLE _o ERROR_VARIABLE _e)
  string(REGEX MATCHALL "PROBE [A-Z]+=[A-Za-z]+" _got "${_o}${_e}")
  if(NOT _got)
    message(FATAL_ERROR "case ${case}: no probe lines (rc=${_rc}) ${_e}")
  endif()
  if(case STREQUAL "all_all")
    if(NOT "PROBE RUST=ON" IN_LIST _got OR NOT "PROBE NODE=ON" IN_LIST _got)
      message(FATAL_ERROR "all_all: expected both ON, got ${_got}")
    endif()
  elseif(case STREQUAL "all_off_face")
    if(NOT "PROBE RUST=OFF" IN_LIST _got OR NOT "PROBE NODE=ON" IN_LIST _got)
      message(FATAL_ERROR "all_off_face: expected RUST=OFF NODE=ON, got ${_got}")
    endif()
  elseif(case STREQUAL "face_only")
    if(NOT "PROBE RUST=ON" IN_LIST _got OR NOT "PROBE NODE=OFF" IN_LIST _got)
      message(FATAL_ERROR "face_only: expected RUST=ON NODE=OFF, got ${_got}")
    endif()
  elseif(case STREQUAL "legacy_only")
    if(NOT "PROBE RUST=ON" STREQUAL "${_got}")
      message(FATAL_ERROR "legacy_only: expected RUST=ON via legacy, got ${_got}")
    endif()
  elseif(case STREQUAL "default_off")
    if(NOT "PROBE RUST=OFF" STREQUAL "${_got}")
      message(FATAL_ERROR "default_off: expected RUST=OFF, got ${_got}")
    endif()
  endif()
  message(STATUS "case ${case}: ${_got} -- OK")
endforeach()

# the both-set leg: ambiguity fails loud
execute_process(COMMAND "${CMAKE_COMMAND}"
    -S "${_s}/proj" -B "${_b}/both"
    "-DPOLYORCH_CMAKE_DIR=${_cmd_dir}"
    "-DCASE=both"
    RESULT_VARIABLE _rc OUTPUT_QUIET ERROR_QUIET)
if(_rc EQUAL 0)
  message(FATAL_ERROR "case both: expected configure FAILURE, got rc=0")
endif()
message(STATUS "case both: fails loud -- OK")

message(STATUS "t-vscode-knobs: gate matrix PASS (6 cases)")
