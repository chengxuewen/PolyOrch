# requires: posix-shell
cmake_policy(SET CMP0219 NEW)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

# t-python-knobs -- the python naming-knob contract (D32, G1: the node A2
# trio mirrored). add_custom_target is not scriptable, so the knob effects
# are exercised through the driver-configured fixture with PASSTHROUGH knob
# values; button names are asserted from TargetDirectories.txt.
# legs: rust-knob non-leak / python-knob prefix / caller-key precedence.
_polyorch_pixi_scratch(_s0)
set(_stub_dir "${_s0}/stubs")
file(MAKE_DIRECTORY "${_stub_dir}")
file(WRITE "${_stub_dir}/py" "#!/bin/sh\necho Python 3.x-stub\nexit 0\n")
file(COPY "${_stub_dir}/py" DESTINATION "${_stub_dir}"
     FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE)

# ---- leg 1: independence -- the RUST knob set, python knob UNSET => bare names
set(_pass "-DPolyOrchPythonExe=${_stub_dir}/py")
list(APPEND _pass "-DPolyOrch_RUST_TARGET_PREFIX=po-rust")
_polyorch_pixi_scratch(_s)
set(_b1 "${_s}/knobs-indep")
drv_run(_dlog _rc SKIP_VAR _skip
    FIXTURE "${CMAKE_CURRENT_LIST_DIR}/../fixtures/python-run"
    BUILD "${_b1}"
    PASSTHROUGH ${_pass})
ck(_rc EQUAL 0)
file(READ "${_b1}/CMakeFiles/TargetDirectories.txt" _td1)
string(FIND "${_td1}" "po-rust" _leak)
if(NOT _leak LESS 0)
    message(FATAL_ERROR "check failed: RUST knob leaked into python naming")
endif()
string(FIND "${_td1}" "greet-run.dir" _bare)
if(_bare LESS 0)
    message(FATAL_ERROR "check failed: bare python button missing")
endif()

# ---- leg 2: the python knob prefixes exactly like the rust/node ones -----
set(_pass2 "-DPolyOrchPythonExe=${_stub_dir}/py")
list(APPEND _pass2 "-DPolyOrch_PYTHON_TARGET_PREFIX=po-py")
_polyorch_pixi_scratch(_s2)
set(_b2 "${_s2}/knobs-pref")
drv_run(_dlog2 _rc2 SKIP_VAR _skip2
    FIXTURE "${CMAKE_CURRENT_LIST_DIR}/../fixtures/python-run"
    BUILD "${_b2}"
    PASSTHROUGH ${_pass2})
ck(_rc2 EQUAL 0)
file(READ "${_b2}/CMakeFiles/TargetDirectories.txt" _td2)
string(FIND "${_td2}" "po-py-greet-run.dir" _hit)
if(_hit LESS 0)
    message(FATAL_ERROR "check failed: python knob did not prefix the button")
endif()

# ---- leg 3: caller-key precedence (the D28 formula, python flavor) -------
# <PROJECT>_POLYORCH_PYTHON_TARGET_PREFIX wins over the classic knob. The
# child script IS the caller (script mode has no project(), so PROJECT_NAME
# is hand-set -- the node caller-child precedent, PIT-85 template shape).
set(_child "${_s0}/knobs-caller-child.cmake")
file(READ "${CMAKE_CURRENT_LIST_DIR}/_pythonknobs-caller-child.cmake.in" _tmpl)
string(REPLACE "@MODULE_DIR@" "${CMAKE_CURRENT_LIST_DIR}/../../cmake" _tmpl "${_tmpl}")
file(WRITE "${_child}" "${_tmpl}")
execute_process(COMMAND "${CMAKE_COMMAND}" -P "${_child}"
    RESULT_VARIABLE _rc3 OUTPUT_VARIABLE _o3 ERROR_VARIABLE _e3)
ck(_rc3 EQUAL 0)
string(JOIN "" _o3all "${_o3}" "${_e3}")
ck(_o3all MATCHES "py-knobs-caller-child: OK")

message(STATUS "t-python-knobs: OK (non-leak + prefix + caller-key)")
