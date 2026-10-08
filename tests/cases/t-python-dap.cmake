# requires: debugpy
cmake_policy(SET CMP0219 NEW)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

# t-python-dap -- the breakpoint-hit proof (D32 T5). Proves the debug
# claim end to end WITHOUT VS Code: a pure-stdlib DAP client (probe.py)
# drives debugpy through its listen adapter, sets one breakpoint on the
# marker line parsed from target.py's source, and asserts a stopped event
# with reason == "breakpoint" whose top frame is exactly that line -- the
# same chain the generated launch.json triggers on F5.
# Gating: `# requires: debugpy` (interpreter importable). Hosts without
# the module contract-SKIP honestly (WP7 tool-leg precedent); this leg is
# NOT silently droppable -- the veto catches an unmarked skip.
polyorch_requires(debugpy _req)
if(NOT _req)
    message(STATUS "t-python-dap : SKIP (no debugpy importable in a probed interpreter)")
    return()
endif()

# the probe runs under whatever interpreter the debugpy probe found --
# resolve it exactly like the probe does (PATH, ~/.pixi/bin, pixi glob).
find_program(_py NAMES python3 python)
if(NOT _py)
    find_program(_py NAMES python3 python PATHS "$ENV{HOME}/.pixi/bin")
endif()
if(NOT _py)
    file(GLOB _g "$ENV{HOME}/.pixi/envs/*/bin/python3"
        "/tmp/opencode/*/.pixi/envs/default/bin/python3")
    list(GET _g 0 _py)
endif()

set(_fx "${CMAKE_CURRENT_LIST_DIR}/../fixtures/python-dap")
_polyorch_pixi_scratch(_s)
file(COPY "${_fx}/target.py" "${_fx}/probe.py" DESTINATION "${_s}")

execute_process(COMMAND "${_py}" "${_s}/probe.py" "${_py}" "56579" "${_s}/target.py"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err
    TIMEOUT 60)
string(JOIN "" _all "${_out}" "${_err}")
if(NOT _rc EQUAL 0 OR NOT _all MATCHES "POLYORCH_DAP_OK")
    message(FATAL_ERROR "DAP breakpoint proof failed (rc=${_rc}): ${_all}")
endif()
message(STATUS "t-python-dap: OK (real breakpoint hit through debugpy, stdlib DAP client)")
