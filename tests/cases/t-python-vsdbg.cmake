# requires: python
cmake_policy(SET CMP0219 NEW)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

# t-python-vsdbg -- the example-level live chain (D32, G2: the t-rust-vsdbg
# mirror for the python face). Standalone-configures examples/python-basic
# (the exact user chain from the example header), then asserts the real
# debugpy launch row, the ZERO tasks footprint (python has no build task --
# the deliberate rust difference), idempotent reconfigure, and that the
# button actually executes the example's main.py through the interpreter
# the face discovered. No driver: the example is not a fixture and must not
# become one for test convenience (the rust-basic standalone chain set the
# precedent of direct -S/-B assertions).
polyorch_requires(python _req)
if(NOT _req)
    message(STATUS "t-python-vsdbg : SKIP (no python interpreter reachable)")
    return()
endif()

_polyorch_pixi_scratch(_s)
set(_b "${_s}/vsb")
set(_ex "${CMAKE_CURRENT_LIST_DIR}/../../examples/python-basic")

execute_process(COMMAND "${CMAKE_COMMAND}"
    -S "${_ex}" -B "${_b}" "-DPolyOrch_VSCODE_DIR=${_b}/vs"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
string(JOIN "" _log "${_out}" "${_err}")
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "python-basic standalone configure failed (rc=${_rc}): ${_log}")
endif()
ck(_log MATCHES "polyorch_python: interpreter")
ck(_log MATCHES "debug configs")

# ---- the generated document ----------------------------------------------
file(READ "${_b}/vs/launch.json" _lj)
ck(_lj MATCHES "\"name\": \"PolyOrch: greet\"")
ck(_lj MATCHES "\"type\": \"debugpy\"")
ck(_lj MATCHES "\"request\": \"launch\"")
ck(_lj MATCHES "\"justMyCode\": true")
ck(_lj MATCHES "main.py")
ck(_lj MATCHES "POLYORCH_WHO")            # the example's ENVS injection serialized
ck(NOT EXISTS "${_b}/vs/tasks.json")      # python: zero task footprint
ck(_lj MATCHES "__POLYORCH_GENERATED_BEGIN__")

# ---- idempotency: reconfigure must not touch the bytes ---------------------
file(SHA256 "${_b}/vs/launch.json" _h1)
execute_process(COMMAND "${CMAKE_COMMAND}" -S "${_ex}" -B "${_b}"
    RESULT_VARIABLE _rc2 OUTPUT_QUIET ERROR_QUIET)
ck(_rc2 EQUAL 0)
file(SHA256 "${_b}/vs/launch.json" _h2)
ck(_h1 STREQUAL _h2)

# ---- the button really runs (real interpreter, real script, real env) ------
execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_b}" --target greet-run
    RESULT_VARIABLE _rc3 OUTPUT_VARIABLE _ro ERROR_VARIABLE _re)
ck(_rc3 EQUAL 0)
string(REGEX MATCHALL "hello, fused!" _hellos "${_ro}")
list(LENGTH _hellos _n)
ck(_n EQUAL 3)                            # main.py's loop count, ENVS value honored
message(STATUS "t-python-vsdbg: OK (live rows + zero-tasks + idempotent + real run x3)")
