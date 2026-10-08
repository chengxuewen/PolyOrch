# requires: posix-shell
cmake_policy(SET CMP0219 NEW)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

# t-python-run -- the python face core contract (D32 / WP-python T2).
# legs: configure report / button registration / the real behavior leg
# through a POSIX stub interpreter (argv + injected env asserted from the
# stub's own log). No python on PATH is required: the tier-a knob hands the
# stub straight to setup(), which is exactly the CI-pinning shape.
# generator-neutral by design: the behavior leg runs the custom target on
# whatever generator the driver picked; we assert on EFFECTS, not rule text.
_polyorch_pixi_scratch(_s)
set(_b "${_s}/py-run")

# ---- stub interpreter: records argv + the two fixture env vars ------------
set(_stub "${_s}/py-stub")
file(WRITE "${_stub}" [=[#!/bin/sh
{ echo "ARGS:$*"; echo "ENV PGREET=${PGREET:-none} PMODE=${PMODE:-none}"; } >> "${STUBLOG:-/dev/null}"
echo "python-stub ($1)"
exit 0
]=])
file(CHMOD "${_stub}" PERMISSIONS
    OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ WORLD_READ)

set(ENV{STUBLOG} "${_s}/stub.log")
drv_run(_dlog _rc SKIP_VAR _skip
    FIXTURE "${CMAKE_CURRENT_LIST_DIR}/../fixtures/python-run"
    BUILD "${_b}"
    PASSTHROUGH "-DPolyOrchPythonExe=${_stub}")
ck(_rc EQUAL 0)

# ---- leg 1: the configure report ------------------------------------------
file(READ "${_b}/_configure.log" _clog)
ck(_clog MATCHES "polyorch_python: interpreter")
ck(_clog MATCHES "python-stub")          # --version round-tripped through the knob

# ---- leg 2: button registration (run-<target> grammar; NAME never renames
# the button -- the label is display-side) -----------------------------------
file(READ "${_b}/CMakeFiles/TargetDirectories.txt" _tdirs)
foreach(_t "run-greet" "run-calc")
    string(FIND "${_tdirs}" "${_t}" _hit)
    if(_hit LESS 0)
        message(FATAL_ERROR "check failed: python run target '${_t}' not registered")
    endif()
endforeach()

# ---- leg 3: behavior through the stub: script + ARGS + ENVS all land ------
execute_process(
    COMMAND "${CMAKE_COMMAND}" --build "${_b}" --target "run-greet"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _bo ERROR_VARIABLE _be)
ck(_rc EQUAL 0)
file(READ "${_s}/stub.log" _stublog)
get_filename_component(_fx "${CMAKE_CURRENT_LIST_DIR}/../fixtures/python-run" ABSOLUTE)
ck(_stublog MATCHES "ARGS:${_fx}/main.py one two")
ck(_stublog MATCHES "ENV PGREET=hi PMODE=fixture")
# WORKING_DIRECTORY default = script dir: the stub itself is not cwd-sensitive,
# but the COMMENT ran; pin the no-ENVS leg stays clean (calc has no PGREET):
file(REMOVE "${_s}/stub.log")
execute_process(
    COMMAND "${CMAKE_COMMAND}" --build "${_b}" --target "run-calc"
    RESULT_VARIABLE _rc2)
ck(_rc2 EQUAL 0)
file(READ "${_s}/stub.log" _stub2)
ck(_stub2 MATCHES "ENV PGREET=none PMODE=none")
message(STATUS "t-python-run: OK (report + buttons + argv/env behavior x2)")
