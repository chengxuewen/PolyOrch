# t-node-ctest -- node-face legs of D45/SR3:
#   (1) UNPARSED guard (the pre-existing hole the full-review BLOCKER-1c
#       pinned closed): unknown args FATAL before anything resolves;
#   (2) CTEST kw: the ctest entry consumes the button's command vector
#       (single source); defaults NAME <handle>-test / LABELS node /
#       WORKING_DIRECTORY = the mediator's own package dir;
#   (3) explicit overrides land;
#   (4) no scripts.test => loud STATUS and NO entry either surface.
# Offline deterministic: node-exe knob points at cmake (harmless --version
# answerer), PM at /bin/echo (t-node-pnpmws shape).
cmake_policy(SET CMP0219 NEW)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchNodeHelpers.cmake")

if(POLYORCH_CHILD)
    polyorch_node_test(TARGET app NOPE)
    message(FATAL_ERROR "expected unknown-args FATAL")
endif()
ck_child_fail("polyorch_node_test: unknown args: NOPE")

_polyorch_pixi_scratch(_s)
set(_fx "${_s}/fx")
set(_pcd "${CMAKE_CURRENT_LIST_DIR}/../../cmake")
foreach(_p app app2 nott)
    file(MAKE_DIRECTORY "${_fx}/${_p}")
    if(_p STREQUAL "nott")
        file(WRITE "${_fx}/${_p}/package.json"
            "{\"name\":\"${_p}\",\"version\":\"0.0.0\"}\n")
    else()
        file(WRITE "${_fx}/${_p}/package.json"
            "{\"name\":\"${_p}\",\"version\":\"0.0.0\",\"scripts\":{\"test\":\"echo t\"}}\n")
    endif()
endforeach()
file(WRITE "${_fx}/package.json"
    "{\"name\":\"root\",\"private\":true,\"workspaces\":[\"app\",\"app2\",\"nott\"]}\n")
file(WRITE "${_fx}/CMakeLists.txt" [=[
cmake_minimum_required(VERSION 3.25)
project(polyorch-node-ctest NONE)
enable_testing()
list(APPEND CMAKE_MODULE_PATH "${POLYORCH_TEST_CMKEDIR}")
include(PolyOrchNodeHelpers)
polyorch_node_setup()
polyorch_node_import(ROOT "${CMAKE_CURRENT_SOURCE_DIR}/package.json")
# defaults leg (handle app2)
polyorch_node_test(TARGET app2 CTEST)
# explicit leg (handle app)
polyorch_node_test(TARGET app CTEST CTEST_NAME app-ct CTEST_LABELS "node;lanes")
# (4) loud no-op leg: no scripts.test -- STATUS, no button, no entry
polyorch_node_test(TARGET nott CTEST)
]=])

execute_process(COMMAND ${CMAKE_COMMAND}
    -G "Unix Makefiles"
    -S "${_fx}" -B "${_s}/b"
    "-DPOLYORCH_TEST_CMKEDIR=${_pcd}"
    "-DPolyOrchNodeExe=${CMAKE_COMMAND}"
    "-DPolyOrchNodeNpm=/bin/echo"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _o ERROR_VARIABLE _e)
string(JOIN "\n" _all "${_o}" "${_e}")
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "configure failed rc=${_rc}:\n${_all}")
endif()

# (4) STATUS posture kept on the ctest-capable verb
string(FIND "${_all}" "has no scripts.test" _sk)
if(_sk LESS 0)
    message(FATAL_ERROR "nott leg lost the loud-skip STATUS:\n${_all}")
endif()

file(READ "${_s}/b/CTestTestfile.cmake" _ct)

string(REGEX MATCHALL "add_test\\([^\n]*" _ats "${_ct}")
list(LENGTH _ats _n)
if(NOT _n EQUAL 2)
    list(LENGTH _ats _got)
    message(FATAL_ERROR "expected 2 ctest entries (app-ct + default app2-test), got ${_got}:\n${_ct}")
endif()
if(_ct MATCHES "add_test[^\\n]*nott")
    message(FATAL_ERROR "scripts.test-less handle leaked a ctest entry")
endif()

# normalize (quote/backslash/newline flattening, t-rust-ctest sibling)
function(_norm out in)
    string(REPLACE "\"" "" _t "${${in}}")
    string(REPLACE "\\" "" _t "${_t}")
    string(REPLACE "\n" " " _t "${_t}")
    while(_t MATCHES "  ")
        string(REPLACE "  " " " _t "${_t}")
    endwhile()
    set(${out} "${_t}" PARENT_SCOPE)
endfunction()
_norm(_cn _ct)

# (2) single source + defaults: app2 entry runs the PM command core, LABELS
# node, WORKING_DIRECTORY = the handle root the mediator itself uses
# (workspace shape: the ROOT manifest dir, exactly the button's own cwd)
if(NOT _cn MATCHES "run test -w app2")
    message(FATAL_ERROR "app2 entry lost the shared command core:\n${_cn}")
endif()
if(NOT _cn MATCHES "app2-test PROPERTIES LABELS node WORKING_DIRECTORY ${_fx}")
    message(FATAL_ERROR "app2 defaults wrong:\n${_cn}")
endif()

# (3) explicit leg
if(NOT _cn MATCHES "app-ct PROPERTIES LABELS node;lanes WORKING_DIRECTORY ${_fx}")
    message(FATAL_ERROR "explicit leg not applied:\n${_cn}")
endif()

# button-side same-vector pin: app2 button build.make carries the core too
file(READ "${_s}/b/CMakeFiles/app2-test.dir/build.make" _bm)
_norm(_bn _bm)
string(FIND "${_bn}" "run test -w app2" _pb)
if(_pb LESS 0)
    message(FATAL_ERROR "button recipe lost the core (single-source broken):\n${_bn}")
endif()

message(STATUS "t-node-ctest: OK")
