# requires: sh
# t-native-debug -- the T-H8 native face: registration validation
# (EXECUTABLE-or-FATAL), the output-dir chain (target > dir var >
# current bin dir), the CodeLLDB rows + self-target task rows, the
# gate polarity (OFF = no file), the ALL composite forcing NATIVE
# via the polyorch_option OR_CONDITION (cache shape pin), and the
# per-tree region slicing (examples-ide-unification ruling 4):
# two build dirs against one .vscode dir must never erase each
# other's slice, a cross-tree duplicate row lands ONCE (skip-on-name,
# launch name == tasks label), and a markerless-id legacy BEGIN is
# re-titled to the claiming tree's id on first sight.
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

# --- leg 6: two-tree slicing -- alternating configures never erase ---
# (examples-ide-unification ruling 4: the bridge tree vs a preset tree
#  share one .vscode dir; each rewrites only its own slice)
set(_vs2 "${_vs}/two")
set(_proj_args "-DPOLYORCH_CMAKE_DIR=${_cmd_dir}"
    "-DPolyOrch_VSCODE_DEBUG_NATIVE=ON" "-DPolyOrch_VSCODE_DIR=${_vs2}")
execute_process(COMMAND "${CMAKE_COMMAND}"
    -S "${_s}/proj" -B "${_b}/treeA" ${_proj_args}
    RESULT_VARIABLE _rc OUTPUT_QUIET ERROR_VARIABLE _e)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "treeA configure failed: ${_e}")
endif()
execute_process(COMMAND "${CMAKE_COMMAND}"
    -S "${_s}/proj" -B "${_b}/treeB" ${_proj_args}
    RESULT_VARIABLE _rc OUTPUT_QUIET ERROR_VARIABLE _e)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "treeB configure failed: ${_e}")
endif()
file(READ "${_vs2}/launch.json" _lj)
string(REGEX MATCHALL "__POLYORCH_GENERATED_BEGIN__" _slices "${_lj}")
list(LENGTH _slices _nslices)
if(_nslices LESS 2)
    message(FATAL_ERROR "two trees must leave two slices; got ${_nslices}: ${_lj}")
endif()
string(FIND "${_lj}" "PolyOrch: nat_app" _at)
if(_at LESS 0)
    message(FATAL_ERROR "the row vanished after the treeB configure (cross-tree erase)")
endif()
# skip-on-name: the duplicate row lands EXACTLY once across the two slices
# (count the "name":-prefixed occurrence -- the bare string also rides the
# row's own preLaunchTask value, so one block == two bare hits)
string(REGEX MATCHALL "\"name\": \"PolyOrch: nat_app \\(debug/native\\)\"" _dups "${_lj}")
list(LENGTH _dups _ndups)
if(NOT _ndups EQUAL 1)
    message(FATAL_ERROR "skip-on-name dedup broken: ${_ndups} copies of the row: ${_lj}")
endif()
# treeB's slice must exist but be EMPTY of nat_app (treeA holds the row)
string(SHA1 _tid_b "${_b}/treeB")
string(SUBSTRING "${_tid_b}" 0 8 _tid_b)
string(FIND "${_lj}" "__POLYORCH_GENERATED_BEGIN__ ${_tid_b} " _at)
if(_at LESS 0)
    message(FATAL_ERROR "treeB's titled slice missing (id = ${_tid_b}): ${_lj}")
endif()
# re-configure treeA: its REPLACED must not touch treeB's slice
execute_process(COMMAND "${CMAKE_COMMAND}"
    -S "${_s}/proj" -B "${_b}/treeA" ${_proj_args}
    RESULT_VARIABLE _rc OUTPUT_QUIET ERROR_VARIABLE _e)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "treeA re-configure failed: ${_e}")
endif()
file(READ "${_vs2}/launch.json" _lj)
string(FIND "${_lj}" "__POLYORCH_GENERATED_BEGIN__ ${_tid_b} " _at)
if(_at LESS 0)
    message(FATAL_ERROR "treeA re-configure erased treeB's slice")
endif()
string(FIND "${_lj}" "PolyOrch: nat_app" _at)
if(_at LESS 0)
    message(FATAL_ERROR "treeA re-configure dropped its own row (self-canceling dedup)")
endif()
message(STATUS "t-native-debug: two-tree slicing + dedup -- OK")

# --- leg 7: tasks label uniqueness across the two slices ---
file(READ "${_vs2}/tasks.json" _tj)
string(REGEX MATCHALL "__POLYORCH_GENERATED_BEGIN__" _tslices "${_tj}")
list(LENGTH _tslices _ntslices)
if(_ntslices LESS 2)
    message(FATAL_ERROR "tasks.json must carry two slices; got ${_ntslices}: ${_tj}")
endif()
string(REGEX MATCHALL "\"label\": \"PolyOrch: nat_app \\(debug/native\\)\"" _tdups "${_tj}")
list(LENGTH _tdups _ntdups)
if(NOT _ntdups EQUAL 1)
    message(FATAL_ERROR "tasks label dedup broken: ${_ntdups} copies: ${_tj}")
endif()
# the surviving task row must build SOME tree (its command stays intact)
string(FIND "${_tj}" "--target\", \"nat_app" _at)
if(_at LESS 0)
    message(FATAL_ERROR "the deduped task row lost its build command: ${_tj}")
endif()
message(STATUS "t-native-debug: tasks label unique across trees -- OK")

# --- leg 8: legacy markerless-id BEGIN is re-titled to the claiming tree ---
file(WRITE "${_vs2}/launch.json"
"{\n    \"version\": \"0.2.0\",\n    \"configurations\": [\n// __POLYORCH_GENERATED_BEGIN__ (PolyOrch debug configs; keep this block last, regenerate via reconfigure)\n        {\n            \"name\": \"PolyOrch: legacy_row\",\n            \"type\": \"lldb\",\n            \"request\": \"launch\",\n            \"program\": \"/x\",\n            \"args\": [],\n            \"preLaunchTask\": \"PolyOrch: legacy_row\"\n        },\n// __POLYORCH_GENERATED_END__\n    ]\n}\n")
execute_process(COMMAND "${CMAKE_COMMAND}"
    -S "${_s}/proj" -B "${_b}/treeC" ${_proj_args}
    RESULT_VARIABLE _rc OUTPUT_QUIET ERROR_VARIABLE _e)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "treeC (legacy migrate) configure failed: ${_e}")
endif()
file(READ "${_vs2}/launch.json" _lj)
string(FIND "${_lj}" "__POLYORCH_GENERATED_BEGIN__ (" _at)
if(_at GREATER -1)
    message(FATAL_ERROR "legacy markerless-id BEGIN survived the migration: ${_lj}")
endif()
string(SHA1 _tid_c "${_b}/treeC")
string(SUBSTRING "${_tid_c}" 0 8 _tid_c)
string(FIND "${_lj}" "__POLYORCH_GENERATED_BEGIN__ ${_tid_c} " _at)
if(_at LESS 0)
    message(FATAL_ERROR "legacy region not re-titled to treeC (${_tid_c}): ${_lj}")
endif()
message(STATUS "t-native-debug: legacy re-title migration -- OK")

message(STATUS "t-native-debug: the native face PASS (8 legs)")
