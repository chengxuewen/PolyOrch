# requires: node
# t-node-debug -- the live js-debug chain on a real toolchain (D33 T4):
# fixture -> setup -> build() registration -> debug verb -> spec -> tail-hook
# DEFER -> generator -> parked launch.json. Direct -S/-B configures (no
# fixture driver): MC-safe by shape, like t-python-vsdbg's twin. On node-less
# hosts the whole case contract-SKIPs at the gate; the offline execution of
# this exact chain is carried by t-node-vscode's stub-driven polarity legs.
# Assertions are substring/FIND -- the generated file is JSONC (marker
# comments), string(JSON) would choke (B6a).
cmake_policy(SET CMP0219 NEW)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

polyorch_requires(node _req)
if(NOT _req)
    message(STATUS "t-node-debug : SKIP (no node+pm on PATH/pixi-glob)")
    return()
endif()

_polyorch_pixi_scratch(_s)
get_filename_component(_fx
    "${CMAKE_CURRENT_LIST_DIR}/../fixtures/node-debug" ABSOLUTE)
# normalized to match the child's CMAKE_CURRENT_SOURCE_DIR exactly -- the
# raw "cases/../fixtures" spelling never appears in the generated row
# (found on the leg's first real execution, node now installed)
set(_entry "${_fx}/dist/index.js")

# ---- ON polarity: gate passed, output parked ------------------------------
execute_process(
    COMMAND "${CMAKE_COMMAND}" -S "${_fx}" -B "${_s}/on"
        "-DPolyOrch_NODE_VSCODE_DEBUG=ON"
        "-DPolyOrch_VSCODE_DIR=${_s}/vson"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
ck(_rc EQUAL 0)
file(READ "${_s}/vson/launch.json" _c)
string(FIND "${_c}" "\"name\": \"PolyOrch: debug-demo\"" _h)
ck(NOT _h LESS 0)                                    # default label = handle
string(FIND "${_c}" "\"program\": \"${_entry}\"" _h)
ck(NOT _h LESS 0)                                    # package-root join, no dist/dist
ck(EXISTS "${_entry}")                                # the row points at a real file
ck(_c MATCHES "\"runtimeExecutable\": \"")            # non-empty runtime pin
ck(_c MATCHES "\"type\": \"node\"")
ck(_c MATCHES "\"sourceMaps\": true")
string(FIND "${_c}" "\"preLaunchTask\": \"PolyOrch: debug-demo\"" _h)
ck(NOT _h LESS 0)
# node rows now merge into the frozen-marker tasks region (rust-then-node)
ck(EXISTS "${_s}/vson/tasks.json")
file(READ "${_s}/vson/tasks.json" _tj)
string(FIND "${_tj}" "PolyOrch rust build tasks" _h)
ck(NOT _h LESS 0)                              # marker byte-frozen
string(FIND "${_tj}" "\"label\": \"PolyOrch: debug-demo\"" _h)
ck(NOT _h LESS 0)                              # node task row present
# the managed marker rides, and the STATUS count names node
ck(_c MATCHES "PolyOrch debug configs")

# ---- OFF polarity: fresh dirs, gate not passed ----------------------------
execute_process(
    COMMAND "${CMAKE_COMMAND}" -S "${_fx}" -B "${_s}/off"
        "-DPolyOrch_VSCODE_DIR=${_s}/vsoff"
    RESULT_VARIABLE _rc2 OUTPUT_QUIET ERROR_QUIET)
ck(_rc2 EQUAL 0)
# the hook never registers the DEFER -> the generator never runs -> the file
# is absent ENTIRELY (zero footprint, not an empty region)
ck(NOT EXISTS "${_s}/vsoff/launch.json")
ck(NOT EXISTS "${_s}/vsoff/tasks.json")          # OFF gate: no tasks file either

message(STATUS "t-node-debug: OK (live rows + runtime pin + node tasks merged + OFF zero footprint)")
