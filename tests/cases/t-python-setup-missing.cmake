# requires: no-python
cmake_policy(SET CMP0219 NEW)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

# t-python-setup-missing -- the degradation matrix of the python face
# (D32 / the nodesetup-missing shape). Only runs on hosts with no
# interpreter on PATH and none in the pixi globs (the no-python probe);
# a host WITH python contract-skips instead of false-failing.
polyorch_requires(no-python _req)
if(NOT _req)
    message(STATUS "t-python-setup-missing : SKIP (no-python probe false: an interpreter is reachable)")
    return()
endif()

_polyorch_pixi_scratch(_s)

# ---- leg 1: silent degrade (no REQUIRED): STATUS names the sources --------
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../cmake")
include(PolyOrchPythonHelpers)
polyorch_python_setup()
ck(NOT POLYORCH_PYTHON_FOUND)

# ---- leg 2: the verbs stay quiet-degrading (no FATAL, no targets) ---------
polyorch_python_run(TARGET greet SCRIPT "${_s}/main.py")
# ran to this line = no FATAL was raised

# ---- leg 3: REQUIRED is loud: a child -P script must die with the name ----
set(_child "${_s}/req-child.cmake")
set(_mp "${CMAKE_CURRENT_LIST_DIR}/../../cmake")
file(WRITE "${_child}"
    "list(APPEND CMAKE_MODULE_PATH \"${_mp}\")\n"
    "include(PolyOrchPythonHelpers)\n"
    "polyorch_python_setup(REQUIRED)\n")
execute_process(COMMAND "${CMAKE_COMMAND}" -P "${_child}"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(_rc EQUAL 0)
    message(FATAL_ERROR "REQUIRED setup unexpectedly SUCCEEDED on a no-python host: ${_out}")
endif()
string(JOIN "" _both "${_out}" "${_err}")
ck(_both MATCHES "REQUIRED but no interpreter")
message(STATUS "t-python-setup-missing: OK (silent degrade + REQUIRED loudness)")
