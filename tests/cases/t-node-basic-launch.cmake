# requires: node
# t-node-basic-launch -- the real-launch leg: run examples/node-basic's
# SOURCE entry under `node --inspect-brk=127.0.0.1:0` (port 0: node picks
# an ephemeral one and announces it on stderr -- no hardcoded port), poll
# the child's log for the documented "Debugger listening on ws://" line
# (condition-based wait, capped). DevToolsActivePort is NOT the signal:
# node 26.10.0 here creates that file for neither a fixed port nor port 0
# (measured on this case's first run); the stderr line is what VSCode's
# auto-attach parses. Assert the inspector endpoint answers and names the
# source file, then kill the
# child by PID. This is exactly what the generated js-debug row runs
# (runtimeExecutable + program == src/index.js), so a hit proves the
# source-level breakpoint story end to end without a VSCode GUI. A plain
# demo run at the tail pins both stdout markers incl. the vendorlib line.
# Never pkill/pgrep -f: kill-by-PID only (process-management rule).
cmake_policy(SET CMP0219 NEW)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

polyorch_requires(node _req)
if(NOT _req)
    message(STATUS "t-node-basic-launch : SKIP (no node+pm on PATH/pixi-glob)")
    return()
endif()

# resolve the node executable with the same three tiers as the probe
# (PATH -> ~/.pixi/bin -> pixi-env glob): the parent tool shell may carry
# neither dir on PATH.
find_program(_node NAMES node)
if(NOT _node)
    find_program(_node NAMES node PATHS "$ENV{HOME}/.pixi/bin")
endif()
if(NOT _node)
    file(GLOB _node_g "$ENV{HOME}/.pixi/envs/*/bin/node")
    if(_node_g)
        list(GET _node_g 0 _node)
    endif()
endif()
if(NOT _node)
    message(FATAL_ERROR "node cap passed but the executable is not locatable (probe drift)")
endif()

find_program(_curl NAMES curl)
if(NOT _curl)
    message(STATUS "t-node-basic-launch : SKIP (curl absent, endpoint probe impossible)")
    return()
endif()

_polyorch_pixi_scratch(_s)
get_filename_component(_script
    "${CMAKE_CURRENT_LIST_DIR}/../../examples/node-basic/src/index.js" ABSOLUTE)
ck(EXISTS "${_script}")
set(_log "${_s}/node-inspect.log")
file(REMOVE "${_log}")

# background the child (sh detaches it, echoes the PID, exits; node stays
# alive suspended at the first line under --inspect-brk)
execute_process(
    COMMAND sh -c "'${_node}' --inspect-brk=127.0.0.1:0 '${_script}' >'${_log}' 2>&1 & echo $!"
    WORKING_DIRECTORY "${_s}"
    RESULT_VARIABLE _lrc OUTPUT_VARIABLE _pid ERROR_VARIABLE _lerr)
ck(_lrc EQUAL 0)
string(STRIP "${_pid}" _pid)
ck(_pid MATCHES "^[0-9]+$")

# condition-based wait (cap 20s): poll the log for the announced port
set(_port "")
set(_tries 0)
while(_port STREQUAL "" AND _tries LESS 200)
    if(EXISTS "${_log}")
        file(STRINGS "${_log}" _listen_line REGEX "Debugger listening on ws://")
        if(_listen_line)
            string(REGEX MATCH "127\\.0\\.0\\.1:([0-9]+)" _m "${_listen_line}")
            if(_m)
                set(_port "${CMAKE_MATCH_1}")
            endif()
        endif()
    endif()
    if(_port STREQUAL "")
        execute_process(COMMAND "${CMAKE_COMMAND}" -E sleep 0.1)
        math(EXPR _tries "${_tries} + 1")
    endif()
endwhile()
ck(_port MATCHES "^[0-9]+$")

# endpoint alive: --noproxy guards against a proxy env swallowing localhost
execute_process(
    COMMAND "${_curl}" --noproxy "*" -sS --max-time 5
        "http://127.0.0.1:${_port}/json/list"
    RESULT_VARIABLE _crc OUTPUT_VARIABLE _body ERROR_QUIET)
ck(_crc EQUAL 0)
ck(_body MATCHES "node.js")    # the inspector answers as a node.js instance
ck(_body MATCHES "index.js")    # the debug target IS the source entry

# kill by PID, then confirm death (condition-based, capped)
execute_process(COMMAND sh -c "kill '${_pid}' 2>/dev/null || true")
set(_st "alive")
set(_tries 0)
while(_st STREQUAL "alive" AND _tries LESS 100)
    execute_process(
        COMMAND sh -c "kill -0 '${_pid}' 2>/dev/null && echo alive || echo dead"
        OUTPUT_VARIABLE _st OUTPUT_STRIP_TRAILING_WHITESPACE)
    math(EXPR _tries "${_tries} + 1")
    if(_st STREQUAL "alive")
        execute_process(COMMAND "${CMAKE_COMMAND}" -E sleep 0.05)
    endif()
endwhile()
ck(_st STREQUAL "dead")

# ---- plain demo leg (example-debug-depth Task 5): run the SAME entry
# without the inspector and pin BOTH stdout markers -- the total line and
# the vendored-lib line. The second marker needs the file: dependency
# linked: npm install creates node_modules/vendorlib as a SYMLINK whose
# realpath is vendor/vendorlib/index.js -- the exact file the README's
# vendor breakpoint story names. The install rides here, not before the
# inspect legs: --inspect-brk suspends at the first line, so no require()
# had run by then and the launch assertions never needed the tree linked.
# --no-audit --no-fund is the example's own build-script shape (offline,
# egress-safe).
get_filename_component(_ex "${CMAKE_CURRENT_LIST_DIR}/../../examples/node-basic" ABSOLUTE)
find_program(_npm NAMES npm)
if(NOT _npm)
    find_program(_npm NAMES npm PATHS "$ENV{HOME}/.pixi/bin")
endif()
if(NOT _npm)
    file(GLOB _npm_g "$ENV{HOME}/.pixi/envs/*/bin/npm")
    if(_npm_g)
        list(GET _npm_g 0 _npm)
    endif()
endif()
if(NOT _npm)
    message(FATAL_ERROR "node cap passed but npm is not locatable (probe drift)")
endif()
cmake_path(GET _npm PARENT_PATH _pmdir)
cmake_path(GET _node PARENT_PATH _ndir)
# the tool shell carries neither node nor npm on PATH: put the two tool
# dirs plus ~/.pixi/bin into the child PATH (t-node-ts-debug's shape) so
# the npm trampoline's `env node` shebang resolves.
set(_env "PATH=$ENV{PATH}:${_ndir}:${_pmdir}:$ENV{HOME}/.pixi/bin")
execute_process(
    COMMAND "${_npm}" install --no-audit --no-fund
    WORKING_DIRECTORY "${_ex}"
    ENVIRONMENT "${_env}"
    RESULT_VARIABLE _irc OUTPUT_QUIET ERROR_QUIET)
ck(_irc EQUAL 0)
execute_process(
    COMMAND "${_node}" "${_script}"
    WORKING_DIRECTORY "${_ex}"
    ENVIRONMENT "${_env}"
    RESULT_VARIABLE _drc OUTPUT_VARIABLE _dout ERROR_VARIABLE _derr)
ck(_drc EQUAL 0)
ck(_dout MATCHES "node-basic total=15")
ck(_dout MATCHES "node-basic/vendorlib: OK")

message(STATUS "t-node-basic-launch: OK (inspect endpoint on src/index.js, child reaped, demo pins total+vendorlib)")
