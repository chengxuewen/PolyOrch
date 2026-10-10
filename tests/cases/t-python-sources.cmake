# requires: python
cmake_policy(SET CMP0219 NEW)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

# t-python-sources -- the python face IDE source-mount contract (rust-face
# parity, _polyorch_python_mount_sources). Generates a child project whose
# run verbs assert from INSIDE the configure via get_property on the target
# SOURCES (the t-python-vsdbg direct -S/-B precedent): default-root glob
# (main.py + pkg recursion + the three metadata pins), the vendor-tree
# exclusion (.venv/__pycache__/venv/env/build/site-packages poison dirs),
# HEADER_FILE_ONLY polarity with the PLAIN escape exercised as a second
# build tree (two BUILD TREES of one source tree, the WP3 shape), the
# NO_SOURCES opt-out, the WORKING_DIRECTORY root choice, and the SOFT
# contract (a missing WDIR must not fail the configure). The parent only
# checks rc + the OK marker.
polyorch_requires(python _req)
if(NOT _req)
    message(STATUS "t-python-sources : SKIP (no python interpreter reachable)")
    return()
endif()

_polyorch_pixi_scratch(_s)
set(_src "${_s}/src")
file(MAKE_DIRECTORY "${_src}/pkg" "${_src}/.venv/lib/site-packages"
    "${_src}/__pycache__" "${_src}/venv" "${_src}/env" "${_src}/build")
file(WRITE "${_src}/main.py" "print('mounted probe')\n")
file(WRITE "${_src}/pyproject.toml" "[project]\nname = 'probe'\n")
file(WRITE "${_src}/setup.py" "from setuptools import setup\n")
file(WRITE "${_src}/requirements.txt" "debugpy\n")
file(WRITE "${_src}/pkg/__init__.py" "")
file(WRITE "${_src}/pkg/mod.py" "X = 1\n")
foreach(_poison ".venv/lib/site-packages/evil.py" "__pycache__/cached.py"
        "venv/gone.py" "env/gone.py" "build/gone.py")
    file(WRITE "${_src}/${_poison}" "raise SystemExit(1)\n")
endforeach()

set(_child [=[
cmake_minimum_required(VERSION 3.22)
project(t-python-sources-child LANGUAGES NONE)
list(APPEND CMAKE_MODULE_PATH "@MODULE_DIR@")
include(PolyOrchPythonHelpers)

macro(cfail msg)
    message(FATAL_ERROR "t-python-sources-child: ${msg}")
endmacro()

# -- default root: the caller dir (WORKING_DIRECTORY unset) ----------------
polyorch_python_run(TARGET greet SCRIPT "${CMAKE_CURRENT_SOURCE_DIR}/main.py")
get_property(_g TARGET greet-run PROPERTY SOURCES)
if(NOT _g)
    cfail("greet-run carries no sources")
endif()
foreach(_want main.py pyproject.toml setup.py requirements.txt __init__.py mod.py)
    string(FIND "${_g}" "${_want}" _hit)
    if(_hit LESS 0)
        cfail("greet-run SOURCES lack ${_want}: ${_g}")
    endif()
endforeach()
foreach(_bad .venv __pycache__ /venv/ /env/ /build/ site-packages
        evil.py cached.py gone.py)
    string(FIND "${_g}" "${_bad}" _hit)
    if(NOT _hit LESS 0)
        cfail("greet-run SOURCES mounted a vendor entry (${_bad}): ${_g}")
    endif()
endforeach()

# -- display property polarity (PLAIN escape branches on the knob) ---------
get_source_file_property(_hf "${CMAKE_CURRENT_SOURCE_DIR}/main.py" HEADER_FILE_ONLY)
if(PolyOrch_PYTHON_SOURCES_PLAIN)
    if(_hf)
        cfail("PLAIN=ON must serve plain sources (HEADER_FILE_ONLY still set)")
    endif()
    set(_mode plain)
else()
    if(NOT _hf)
        cfail("default mount must mark sources HEADER_FILE_ONLY ON")
    endif()
    set(_mode default)
endif()

# -- NO_SOURCES opt-out: the button stays bare ------------------------------
polyorch_python_run(TARGET quiet SCRIPT "${CMAKE_CURRENT_SOURCE_DIR}/main.py" NO_SOURCES)
get_property(_q TARGET quiet-run PROPERTY SOURCES)
if(_q)
    cfail("NO_SOURCES left entries on quiet-run: ${_q}")
endif()

# -- WDIR root selection: the mount follows WORKING_DIRECTORY --------------
polyorch_python_run(TARGET sub SCRIPT "${CMAKE_CURRENT_SOURCE_DIR}/main.py"
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/pkg")
get_property(_w TARGET sub-run PROPERTY SOURCES)
string(FIND "${_w}" "mod.py" _hit)
if(_hit LESS 0)
    cfail("sub-run must mount the WORKING_DIRECTORY tree: ${_w}")
endif()
string(FIND "${_w}" "main.py" _hit)
if(NOT _hit LESS 0)
    cfail("sub-run must NOT mount the caller root: ${_w}")
endif()

# -- SOFT contract: a missing WDIR skips, never fatals --------------------
polyorch_python_run(TARGET ghost SCRIPT "${CMAKE_CURRENT_SOURCE_DIR}/main.py"
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/nope")
get_property(_gh TARGET ghost-run PROPERTY SOURCES)
if(_gh)
    cfail("ghost-run must stay bare (missing WDIR is SOFT): ${_gh}")
endif()
message(STATUS "t-python-sources-child: OK (${_mode} polarity)")
]=])
string(REPLACE "@MODULE_DIR@" "${CMAKE_CURRENT_LIST_DIR}/../../cmake" _child "${_child}")
file(WRITE "${_src}/CMakeLists.txt" "${_child}")

# leg 1: the default tree (HEADER_FILE_ONLY ON polarity)
execute_process(COMMAND "${CMAKE_COMMAND}" -S "${_src}" -B "${_s}/b1"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _o ERROR_VARIABLE _e)
string(JOIN "" _log "${_o}" "${_e}")
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "t-python-sources: default configure failed (rc=${_rc}):\n${_log}")
endif()
ck(_log MATCHES "t-python-sources-child: OK .default polarity.")

# leg 2: the PLAIN escape (separate build tree, knob cache ON)
execute_process(COMMAND "${CMAKE_COMMAND}" -S "${_src}" -B "${_s}/b2"
    "-DPolyOrch_PYTHON_SOURCES_PLAIN=ON"
    RESULT_VARIABLE _rc2 OUTPUT_VARIABLE _o2 ERROR_VARIABLE _e2)
string(JOIN "" _log2 "${_o2}" "${_e2}")
if(NOT _rc2 EQUAL 0)
    message(FATAL_ERROR "t-python-sources: PLAIN configure failed (rc=${_rc2}):\n${_log2}")
endif()
ck(_log2 MATCHES "t-python-sources-child: OK .plain polarity.")

message(STATUS "t-python-sources: OK (glob + vendor-guard + polarity x2 + NO_SOURCES + WDIR + SOFT)")
