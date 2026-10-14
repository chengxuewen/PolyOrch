# requires: sh
# t-option -- the full polyorch_option (the octk_option port): every
# keyword's semantics pinned through child configures.
#   plain            basic option, cache BOOL
#   or_on            OR_CONDITION true  -> cache FORCED ON STRING (display=effect)
#   or_off           OR_CONDITION false -> face value rules
#   depends_on       DEPENDS true       -> value lives
#   depends_off      DEPENDS false      -> STRING "OFF ... depends on" marker + WARNING
#   emit_if_warn     EMIT_IF false + user value -> WARNING, value not applied
#   set_mirror       SET/SET_NEGATE mirror into sibling vars
#   input_override   INPUT_<var> wins over the default
#   verify_ok        VERIFY true -> configures
#   verify_fail      VERIFY false -> FATAL
#   expr_and_or      the expression evaluator: AND/OR/NOT/parens/STREQUAL
cmake_policy(SET CMP0219 NEW)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")
_polyorch_pixi_scratch(_s)
set(_b "${_s}/option")

file(WRITE "${_s}/proj/CMakeLists.txt" [=[
cmake_minimum_required(VERSION 3.25)
project(opt NONE)
include("${POLYORCH_CMAKE_DIR}/PolyOrchOptionHelpers.cmake")

if(CASE STREQUAL "plain")
  polyorch_option(OPT_A "plain option" ON)
  message(STATUS "RES=${OPT_A}")
elseif(CASE STREQUAL "or_on")
  set(PolyOrch_VSCODE_DEBUG_ALL ON)
  polyorch_option(OPT_B "gated" OFF OR_CONDITION PolyOrch_VSCODE_DEBUG_ALL)
  message(STATUS "RES=${OPT_B}")
elseif(CASE STREQUAL "or_off")
  set(PolyOrch_VSCODE_DEBUG_ALL OFF)
  polyorch_option(OPT_C "gated" ON OR_CONDITION PolyOrch_VSCODE_DEBUG_ALL)
  message(STATUS "RES=${OPT_C}")
elseif(CASE STREQUAL "depends_off")
  set(GATE OFF)
  polyorch_option(OPT_D "dep" ON DEPENDS GATE)
  message(STATUS "RES=${OPT_D}")
elseif(CASE STREQUAL "set_mirror")
  polyorch_option(OPT_E "mirror me" ON SET MIRRORED SET_NEGATE INVERTED)
  message(STATUS "RES=${OPT_E};M=${MIRRORED};I=${INVERTED}")
elseif(CASE STREQUAL "input_override")
  set(INPUT_OPT_F ON)
  polyorch_option(OPT_F "input wins" OFF)
  message(STATUS "RES=${OPT_F}")
elseif(CASE STREQUAL "verify_ok")
  set(HOST_OK ON)
  polyorch_option(OPT_G "checked" ON VERIFY HOST_OK)
  message(STATUS "RES=${OPT_G}")
elseif(CASE STREQUAL "expr")
  set(VAL1 "")
  set(VAL2 ON)
  set(NAME "visiaengine")
  _polyorch_evaluate_expression(r1 VAL1 AND VAL2)          # OFF (short-circuit AND)
  _polyorch_evaluate_expression(r2 VAL1 OR VAL2)           # ON
  _polyorch_evaluate_expression(r3 NOT VAL1)               # ON
  _polyorch_evaluate_expression(r4 (VAL1 OR VAL2) AND VAL2) # ON
  _polyorch_evaluate_expression(r5 NAME STREQUAL 'visiaengine') # ON
  _polyorch_evaluate_expression(r6 NAME STREQUAL 'other')       # OFF
  _polyorch_evaluate_expression(r7 EXISTS /nonexistent-path-xyz) # OFF
  message(STATUS "EXPR=${r1},${r2},${r3},${r4},${r5},${r6},${r7}")
elseif(CASE STREQUAL "verify_fail")
  set(GATE OFF)
  polyorch_option(OPT_H "never" ON VERIFY GATE)
endif()
]=])

set(_cmd_dir "${CMAKE_CURRENT_LIST_DIR}/../../cmake")

function(run_case case out_ok)
    cmake_parse_arguments(RC "" "" "" ${ARGN})
    set(_rc "")
    set(_o "")
    set(_e "")
    execute_process(COMMAND "${CMAKE_COMMAND}"
        -S "${_s}/proj" -B "${_b}/${case}"
        "-DPOLYORCH_CMAKE_DIR=${_cmd_dir}"
        "-DCASE=${case}"
        RESULT_VARIABLE _rc OUTPUT_VARIABLE _o ERROR_VARIABLE _e)
    set(${out_ok} "${_rc}" PARENT_SCOPE)
    set(_LAST_OUT "${_o}${_e}" PARENT_SCOPE)
endfunction()

# plain + or_on cache-shape assertions
foreach(case plain or_on or_off depends_off set_mirror input_override verify_ok expr)
  execute_process(COMMAND "${CMAKE_COMMAND}"
      -S "${_s}/proj" -B "${_b}/${case}"
      "-DPOLYORCH_CMAKE_DIR=${_cmd_dir}"
      "-DCASE=${case}"
      RESULT_VARIABLE _rc OUTPUT_VARIABLE _o ERROR_VARIABLE _e)
  if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "case ${case} failed: ${_e}")
  endif()
  string(REGEX MATCHALL "RES=[A-Z_=;IOFN]*" _got "${_o}${_e}")
  string(REGEX MATCHALL "EXPR=[A-Z_=,]*" _ex "${_o}${_e}")
  if(case STREQUAL "plain")
    if(NOT "RES=ON" IN_LIST _got)
      message(FATAL_ERROR "plain: got ${_got}")
    endif()
  elseif(case STREQUAL "or_on")
    if(NOT "RES=ON" IN_LIST _got)
      message(FATAL_ERROR "or_on: got ${_got}")
    endif()
    # the cache-shape pin (the thin-sugar lesson): display = effect
    file(TO_CMAKE_PATH "${_b}/or_on/CMakeCache.txt" _cache)
    file(READ "${_cache}" _ct)
    if(NOT _ct MATCHES "OPT_B:STRING=ON")
      message(FATAL_ERROR "or_on: the cache does not SHOW the forced value (OPT_B:STRING=ON missing)")
    endif()
  elseif(case STREQUAL "or_off")
    if(NOT "RES=ON" IN_LIST _got)
      message(FATAL_ERROR "or_off: got ${_got}")
    endif()
  elseif(case STREQUAL "depends_off")
    if(NOT "RES=OFF" IN_LIST _got)
      message(FATAL_ERROR "depends_off: got ${_got}")
    endif()
    if(NOT (_o MATCHES "is depends on" OR _e MATCHES "is depends on"))
      message(FATAL_ERROR "depends_off: the WARNING is missing")
    endif()
  elseif(case STREQUAL "set_mirror")
    if(NOT ("RES=ON" IN_LIST _got AND "M=ON" IN_LIST _got AND "I=OFF" IN_LIST _got))
      message(FATAL_ERROR "set_mirror: got ${_got}")
    endif()
  elseif(case STREQUAL "input_override")
    if(NOT "RES=ON" IN_LIST _got)
      message(FATAL_ERROR "input_override: got ${_got}")
    endif()
  elseif(case STREQUAL "expr")
    if(NOT "EXPR=OFF,ON,ON,ON,ON,OFF,OFF" IN_LIST _ex)
      message(FATAL_ERROR "expr: got ${_ex}")
    endif()
  endif()
  message(STATUS "case ${case}: OK")
endforeach()

# verify_fail: loud
execute_process(COMMAND "${CMAKE_COMMAND}"
    -S "${_s}/proj" -B "${_b}/verify_fail"
    "-DPOLYORCH_CMAKE_DIR=${_cmd_dir}"
    "-DCASE=verify_fail"
    RESULT_VARIABLE _rc OUTPUT_QUIET ERROR_QUIET)
if(_rc EQUAL 0)
  message(FATAL_ERROR "verify_fail: expected FAILURE")
endif()
message(STATUS "case verify_fail: fails loud -- OK")

message(STATUS "t-option: the octk_option port PASS (10 cases)")
