# requires: sh
# t-native-debug -- the T-H8 native face: registration validation
# (EXECUTABLE-or-FATAL), the output-dir chain (target > dir var >
# current bin dir), the CodeLLDB rows + self-target task rows, the
# gate polarity (OFF = no file), and the ALL composite forcing NATIVE
# via the polyorch_option OR_CONDITION (cache shape pin).
cmake_policy(SET CMP0219 NEW)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")
_polyorch_pixi_scratch(_s)
set(_b "${_s}/nat")

# --- the fixture project (a REAL executable -- TYPE query needs it) ---
file(WRITE "${_s}/proj/CMakeLists.txt" [=[
cmake_minimum_required(VERSION 3.25)
project(natdbg C)
include("${POLYORCH_CMAKE_DIR}/PolyOrchRustHelpers.cmake")
file(WRITE "${CMAKE_CURRENT_SOURCE_DIR}/main.c" "int main(void){return 0;}\n")
add_executable(nat_app main.c)
set_target_properties(nat_app PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
if(NOT NO_REG)
  polyorch_native_debug(TARGET nat_app CWD "${CMAKE_SOURCE_DIR}")
endif()
# negative: a non-executable target must FATAL
if(NEG_LIB)
  add_library(some_lib STATIC main.c)
  polyorch_native_debug(TARGET some_lib)
endif()
]=])

set(_cmd_dir "${CMAKE_CURRENT_LIST_DIR}/../../cmake")
set(_vs "${_s}/vs")

# --- leg 1: gate ON polarity, rows tables ---
execute_process(COMMAND "${CMAKE_COMMAND}"
    -S "${_s}/proj" -B "${_b}/on"
    "-DPOLYORCH_CMAKE_DIR=${_cmd_dir}"
    "-DPolyOrch_VSCODE_DEBUG_NATIVE=ON"
    "-DPolyOrch_VSCODE_DIR=${_vs}/on"
    RESULT_VARIABLE _rc OUTPUT_QUIET ERROR_VARIABLE _e)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "gate-on configure failed: ${_e}")
endif()
file(READ "${_vs}/on/launch.json" _lj)
# literal substring checks (FIND, not MATCHES -- no regex engine traps)
foreach(marker "PolyOrch: nat_app (debug/native)" "\"type\": \"lldb\""
               "bin/nat_app" "preLaunchTask")
    string(FIND "${_lj}" "${marker}" _at)
    if(_at LESS 0)
        message(FATAL_ERROR "launch row missing marker: ${marker}")
    endif()
endforeach()
file(READ "${_vs}/on/tasks.json" _tj)
string(FIND "${_tj}" "\"--target\", \"nat_app\"" _at)
if(_at LESS 0)
    message(FATAL_ERROR "task row must build the TARGET ITSELF (no -build mediator)")
endif()
message(STATUS "t-native-debug: gate-on rows + self-target task -- OK")

# --- leg 2: gate OFF polarity (hook short-circuits, nothing written) ---
execute_process(COMMAND "${CMAKE_COMMAND}"
    -S "${_s}/proj" -B "${_b}/off"
    "-DPOLYORCH_CMAKE_DIR=${_cmd_dir}"
    "-DPolyOrch_VSCODE_DIR=${_vs}/off"
    RESULT_VARIABLE _rc OUTPUT_QUIET ERROR_QUIET)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "gate-off configure failed")
endif()
if(EXISTS "${_vs}/off/launch.json")
    message(FATAL_ERROR "gate-off wrote launch.json -- polarity broken")
endif()
message(STATUS "t-native-debug: gate-off silence -- OK")

# --- leg 3: ALL composite forces the native face (OR_CONDITION) ---
execute_process(COMMAND "${CMAKE_COMMAND}"
    -S "${_s}/proj" -B "${_b}/all"
    "-DPOLYORCH_CMAKE_DIR=${_cmd_dir}"
    "-DPolyOrch_VSCODE_DEBUG_ALL=ON"
    "-DPolyOrch_VSCODE_DIR=${_vs}/all"
    RESULT_VARIABLE _rc OUTPUT_QUIET ERROR_QUIET)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "ALL-on configure failed")
endif()
if(NOT EXISTS "${_vs}/all/launch.json")
    message(FATAL_ERROR "ALL=ON must force the native face (rows expected)")
endif()
file(READ "${_b}/all/CMakeCache.txt" _ct)
if(NOT _ct MATCHES "PolyOrch_VSCODE_DEBUG_NATIVE:STRING=ON")
    message(FATAL_ERROR "ALL=ON did not FORCE the NATIVE cache -- display != effect")
endif()
message(STATUS "t-native-debug: ALL composite + FORCE cache -- OK")

# --- leg 4: the TYPE guard (a library target dies) ---
execute_process(COMMAND "${CMAKE_COMMAND}"
    -S "${_s}/proj" -B "${_b}/neg"
    "-DPOLYORCH_CMAKE_DIR=${_cmd_dir}"
    "-DNEG_LIB=ON"
    RESULT_VARIABLE _rc OUTPUT_QUIET ERROR_QUIET)
if(_rc EQUAL 0)
    message(FATAL_ERROR "non-executable target accepted -- guard dead")
endif()
message(STATUS "t-native-debug: EXECUTABLE guard -- OK")

# --- leg 5: ARGS surface (@-joined argv lands as a JSON array) ---
file(WRITE "${_s}/proj2/CMakeLists.txt" [=[
cmake_minimum_required(VERSION 3.25)
project(natdbg2 C)
include("${POLYORCH_CMAKE_DIR}/PolyOrchRustHelpers.cmake")
file(WRITE "${CMAKE_CURRENT_SOURCE_DIR}/main.c" "int main(void){return 0;}\n")
add_executable(arg_app main.c)
polyorch_native_debug(TARGET arg_app CWD "${CMAKE_SOURCE_DIR}" ARGS "--frames;3")
]=])
execute_process(COMMAND "${CMAKE_COMMAND}"
    -S "${_s}/proj2" -B "${_b}/args"
    "-DPOLYORCH_CMAKE_DIR=${_cmd_dir}"
    "-DPolyOrch_VSCODE_DEBUG_NATIVE=ON"
    "-DPolyOrch_VSCODE_DIR=${_vs}/args"
    RESULT_VARIABLE _rc OUTPUT_QUIET ERROR_VARIABLE _e)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "args leg configure failed: ${_e}")
endif()
file(READ "${_vs}/args/launch.json" _aj)
if(NOT _aj MATCHES "\"args\": \\[\"--frames\", \"3\"\\]")
    message(FATAL_ERROR "args JSON array wrong; launch tail: ${_aj}")
endif()
message(STATUS "t-native-debug: ARGS -> JSON array -- OK")

message(STATUS "t-native-debug: the native face PASS (5 legs)")
