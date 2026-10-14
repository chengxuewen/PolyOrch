# requires: sh
# t-wasm-serve -- polyorch_rust_wasm_serve surface: the button exists,
# the assembly COMMANDs carry the page+data+pkg copies, the serve step
# pins the wasm MIME + port, the glue edge rides the stamped pkg root.
cmake_policy(SET CMP0219 NEW)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")
_polyorch_pixi_scratch(_s)
set(_b "${_s}/wasm-serve")

file(WRITE "${_s}/proj/CMakeLists.txt" [=[
cmake_minimum_required(VERSION 3.25)
project(exsrv NONE)
include("${POLYORCH_CMAKE_DIR}/PolyOrchRustHelpers.cmake")
add_executable(wasmmod IMPORTED)
set_target_properties(wasmmod PROPERTIES POLYORCH_WASM_PKG_ROOT "${CMAKE_BINARY_DIR}/web")
file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/web/pkg-web")
file(WRITE "${CMAKE_BINARY_DIR}/web/pkg-web/visiaengine_wasm.js" "// pkg")
file(WRITE "${CMAKE_SOURCE_DIR}/page.html" "<html></html>")
file(WRITE "${CMAKE_SOURCE_DIR}/park.geojson" "{}")
polyorch_rust_wasm_serve(TARGET wasmmod NAME_PREFIX visiaengine-wasm
    DIRECTORY "${CMAKE_BINARY_DIR}/web-demo"
    SOURCES "${CMAKE_SOURCE_DIR}/page.html"
    DATA "${CMAKE_SOURCE_DIR}/park.geojson"
    FLAVOR web PORT 8017 FOLDER "bindings/wasm")
]=])

set(_cmd_dir "${CMAKE_CURRENT_LIST_DIR}/../../cmake")
execute_process(COMMAND "${CMAKE_COMMAND}"
    -S "${_s}/proj" -B "${_b}"
    "-DPOLYORCH_CMAKE_DIR=${_cmd_dir}"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _o ERROR_VARIABLE _e)
file(WRITE "${_s}/run.out" "${_o}\n---stderr---\n${_e}")
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "configure failed; log: ${_s}/run.out")
endif()

file(READ "${_b}/CMakeFiles/TargetDirectories.txt" _td)
if(NOT _td MATCHES "visiaengine-wasm-serve")
    message(FATAL_ERROR "missing visiaengine-wasm-serve; log: ${_s}/run.out")
endif()
set(_bm "${_b}/CMakeFiles/visiaengine-wasm-serve.dir/build.make")
if(NOT EXISTS "${_bm}")
    message(FATAL_ERROR "no build.make for visiaengine-wasm-serve")
endif()
file(READ "${_bm}" _body)
# the serve body moved to a generated .py (semicolons must not ride
# command lists); build.make pins the script path, the script pins content
foreach(marker "copy_if_different" "copy_directory" "polyorch-wasm-serve-8017.py")
    if(NOT _body MATCHES "${marker}")
        message(FATAL_ERROR "serve button missing marker: ${marker}")
    endif()
endforeach()
# single top-level child project: the script lands at the build root
set(_ss "${_b}/polyorch-wasm-serve-8017.py")
if(NOT EXISTS "${_ss}")
    message(FATAL_ERROR "serve script not generated at ${_ss}")
endif()
file(READ "${_ss}" _sc)
foreach(marker "extensions_map" "application/wasm" "8017")
    if(NOT _sc MATCHES "${marker}")
        message(FATAL_ERROR "serve script missing marker: ${marker}")
    endif()
endforeach()
message(STATUS "t-wasm-serve: button ledger + assembly + script/MIME pins PASS")
