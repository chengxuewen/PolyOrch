cmake_policy(SET CMP0219 NEW)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../cmake")
include(PolyOrchRustHelpers)
include(PolyOrchPythonHelpers)

# t-python-vscode -- the debugpy rows + registration contract (D32 T3).
# legs: pure rows tables / combined-region + legacy migration through a
# direct generate call / the live registration path through the fixture
# child (gate ON knob, VSCODE_DIR parked in scratch -- the face's full
# run()->spec->DEFER chain exercised for real, no source-tree pollution).
_polyorch_pixi_scratch(_s)

# ---- 1) rows: spec table -> debugpy region text ---------------------------
set(_specs
    "greet|/usr/bin/python3|/src/main.py|/src|one,two|PGREET=hi,PMODE=fixture"
    "fast|/a b/python 3|/src/calc mode.py|/src||")
_polyorch_python_vscode_rows("${_specs}" _L)
ck(_L MATCHES "\"type\": \"debugpy\"")
ck(_L MATCHES "\"name\": \"PolyOrch: greet\"")
ck(_L MATCHES "\"program\": \"/src/main.py\"")
ck(_L MATCHES "\"python\": \"/a b/python 3\"")   # spaces verbatim
ck(_L MATCHES "\"justMyCode\": true")
# literal containment (NOT MATCHES): CMake quote-parsing eats `\[` into a
# bare `[` and the regex then degrades to a character class (measured --
# the ck macro's own "never pre-quote" family of traps, PIT-18 adjacent).
string(FIND "${_L}" "\"args\": [\"one\", \"two\", ]" _ia)
ck(NOT _ia LESS 0)
string(FIND "${_L}" "\"env\": {\"PGREET\": \"hi\", \"PMODE\": \"fixture\", }" _ie)
ck(NOT _ie LESS 0)
# the bare row: both optional keys omitted ENTIRELY
string(REGEX MATCH "PolyOrch: fast.*\}" _bare "${_L}")
ck(_bare MATCHES "cwd")
string(FIND "${_bare}" "args" _ha)
string(FIND "${_bare}" "env" _he)
if(NOT _ha LESS 0 OR NOT _he LESS 0)
    message(FATAL_ERROR "bare row leaked args/env keys: ${_bare}")
endif()
# row count: exactly two launch objects, comma-terminated (region contract)
string(REGEX MATCHALL "\"request\": \"launch\"" _n "${_L}")
list(LENGTH _n _rows)
ck(_rows EQUAL 2)
# empty table -> empty text
_polyorch_python_vscode_rows("" _EL)
string(COMPARE EQUAL "${_EL}" "" _e0)
ck(_e0)

# ---- 2) combined region + legacy migration (direct generator call) --------
set(_vd "${_s}/vs2")
set(PolyOrch_VSCODE_DIR "${_vd}")
set_property(GLOBAL PROPERTY POLYORCH_RUST_DEBUG_SPECS
    "alpha|/b/alpha|/src/alpha|debug")
set_property(GLOBAL PROPERTY POLYORCH_PYTHON_DEBUG_SPECS
    "greet|/usr/bin/python3|/src/main.py|/src||PGREET=hi")
_polyorch_vscode_debug_generate()
file(READ "${_vd}/launch.json" _c)
ck(_c MATCHES "PolyOrch debug configs")           # combined marker
ck(_c MATCHES "\"type\": \"lldb\"")               # rust row present
ck(_c MATCHES "\"type\": \"debugpy\"")            # python row present
ck(NOT _c MATCHES "rust debug configs")
file(SHA256 "${_vd}/launch.json" _h1)
_polyorch_vscode_debug_generate()                 # idempotent
file(SHA256 "${_vd}/launch.json" _h2)
ck(_h1 STREQUAL _h2)
# tasks.json: rust-only face rows -> written with the FROZEN marker
file(READ "${_vd}/tasks.json" _tj)
ck(_tj MATCHES "PolyOrch rust build tasks")

# legacy migration leg: seed the OLD launch marker, regenerate, expect the
# combined marker in place and the rows replaced
file(WRITE "${_vd}/launch.json"
"{
    \"version\": \"0.2.0\",
    \"configurations\": [
// __POLYORCH_GENERATED_BEGIN__ (PolyOrch rust debug configs; keep this block last, regenerate via reconfigure)
        {\"name\": \"stale\"},
// __POLYORCH_GENERATED_END__
    ]
}
")
_polyorch_vscode_debug_generate()
file(READ "${_vd}/launch.json" _m)
ck(_m MATCHES "PolyOrch debug configs")
ck(NOT _m MATCHES "rust debug configs")
ck(NOT _m MATCHES "stale")
ck(_m MATCHES "debugpy")

# ---- 3) live registration path: fixture child with the gate ON -----------
set(_stub "${_s}/py-stub")
file(WRITE "${_stub}" [=[#!/bin/sh
echo "python-stub ($1)"
exit 0
]=])
file(CHMOD "${_stub}" PERMISSIONS
    OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ WORLD_READ)
set(_b "${_s}/py-vsdbg")
drv_run(_dlog _rc SKIP_VAR _skip
    FIXTURE "${CMAKE_CURRENT_LIST_DIR}/../fixtures/python-run"
    BUILD "${_b}"
    PASSTHROUGH "-DPolyOrchPythonExe=${_stub}" "-DPolyOrch_PYTHON_VSCODE_DEBUG=ON" "-DPolyOrch_VSCODE_DIR=${_s}/vs3")
ck(_rc EQUAL 0)
file(READ "${_s}/vs3/launch.json" _g)
ck(_g MATCHES "PolyOrch: greet")
ck(_g MATCHES "PolyOrch: fast")             # NAME override reached the label
ck(_g MATCHES "\"python\": \"${_stub}\"")   # tier-a knob flowed to the row
ck(_g MATCHES "PGREET")                     # fixture ENVS serialized
string(FIND "${_g}" "debugpy" _d1)
if(_d1 LESS 0)
    message(FATAL_ERROR "no debugpy row from the live chain")
endif()
# gate OFF: no spec registered AND the generator never hooks -> no file at
# all (the honest OFF shape: zero footprint, not an empty region)
file(REMOVE "${_s}/vs3/launch.json")
drv_run(_dlog2 _rc2 SKIP_VAR _skip2
    FIXTURE "${CMAKE_CURRENT_LIST_DIR}/../fixtures/python-run"
    BUILD "${_b}"
    PASSTHROUGH "-DPolyOrchPythonExe=${_stub}" "-DPolyOrch_PYTHON_VSCODE_DEBUG=OFF" "-DPolyOrch_VSCODE_DIR=${_s}/vs3")
ck(_rc2 EQUAL 0)
ck(NOT EXISTS "${_s}/vs3/launch.json")
message(STATUS "t-python-vscode: OK (rows + combined region + migration + live gate both polarities)")
