# requires: sh
# t-vscode-knobs -- the T-H7 knob family: the gate matrix (ALL composite
# dictator values / per-face knobs / legacy honor / both-set FATAL /
# junk ALL FATAL) driven through the real _polyorch_vscode_debug_gate
# function in a child configure (scope-real: the helper reads cache vars).
cmake_policy(SET CMP0219 NEW)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")
_polyorch_pixi_scratch(_s)
set(_b "${_s}/knobs")

file(WRITE "${_s}/proj/CMakeLists.txt" [=[
cmake_minimum_required(VERSION 3.25)
project(knobs NONE)
include("${POLYORCH_CMAKE_DIR}/_polyorch_vscode_debug_gate.cmake")

# probe macro: one gate call -> one line "FACE=<on>"
macro(probe face)
  _polyorch_vscode_debug_gate(${face} _v)
  message(STATUS "PROBE ${face}=${_v}")
endmacro()

if(CASE STREQUAL "all_all")
  set(PolyOrch_VSCODE_DEBUG_ALL "ALL")
  probe(RUST)
  probe(NODE)
elseif(CASE STREQUAL "all_rust")
  set(PolyOrch_VSCODE_DEBUG_ALL "RUST")
  probe(RUST)
  probe(NODE)
elseif(CASE STREQUAL "face_only")
  set(PolyOrch_VSCODE_DEBUG_RUST ON)
  probe(RUST)
  probe(NODE)
elseif(CASE STREQUAL "legacy_only")
  set(PolyOrch_RUST_VSCODE_DEBUG ON)
  probe(RUST)
elseif(CASE STREQUAL "both")
  set(PolyOrch_VSCODE_DEBUG_RUST ON)
  set(PolyOrch_RUST_VSCODE_DEBUG ON)
  probe(RUST)
elseif(CASE STREQUAL "junk")
  set(PolyOrch_VSCODE_DEBUG_ALL "on-plz")
  probe(RUST)
elseif(CASE STREQUAL "default_off")
  probe(RUST)
endif()
]=])

set(_cmd_dir "${CMAKE_CURRENT_LIST_DIR}/../../cmake")

foreach(case all_all all_rust face_only legacy_only default_off)
  set(_rc "")
  set(_o "")
  set(_e "")
  execute_process(COMMAND "${CMAKE_COMMAND}"
      -S "${_s}/proj" -B "${_b}/${case}"
      "-DPOLYORCH_CMAKE_DIR=${_cmd_dir}"
      "-DCASE=${case}"
      RESULT_VARIABLE _rc OUTPUT_VARIABLE _o ERROR_VARIABLE _e)
  string(FIND "${_o}${_e}" "PROBE RUST=" _rp)
  if(_rp LESS 0)
    message(FATAL_ERROR "case ${case}: no probe lines (rc=${_rc}) ${_e}")
  endif()
  string(REGEX MATCHALL "PROBE [A-Z]+=[A-Za-z]+" _hits "${_o}${_e}")
  set(_got "${_hits}")
  if(case STREQUAL "all_all")
    if(NOT "PROBE RUST=ON" IN_LIST _got OR NOT "PROBE NODE=ON" IN_LIST _got)
      message(FATAL_ERROR "all_all: expected both ON, got ${_got}")
    endif()
  elseif(case STREQUAL "all_rust")
    if(NOT "PROBE RUST=ON" IN_LIST _got OR NOT "PROBE NODE=OFF" IN_LIST _got)
      message(FATAL_ERROR "all_rust: expected RUST=ON NODE=OFF, got ${_got}")
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

foreach(case both junk)
  set(_rc "")
  execute_process(COMMAND "${CMAKE_COMMAND}"
      -S "${_s}/proj" -B "${_b}/${case}"
      "-DPOLYORCH_CMAKE_DIR=${_cmd_dir}"
      "-DCASE=${case}"
      RESULT_VARIABLE _rc OUTPUT_QUIET ERROR_QUIET)
  if(_rc EQUAL 0)
    message(FATAL_ERROR "case ${case}: expected configure FAILURE, got rc=0")
  endif()
  message(STATUS "case ${case}: fails loud -- OK")
endforeach()

message(STATUS "t-vscode-knobs: gate matrix PASS (7 cases)")
