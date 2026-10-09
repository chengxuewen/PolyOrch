cmake_policy(SET CMP0219 NEW)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../cmake")
include(PolyOrchRustHelpers)
include(PolyOrchPythonHelpers)
include(PolyOrchNodeHelpers)

# t-node-vscode -- the js-debug registration contract (D33 T1).
# legs: verb->spec->rows tables (entry grammar four branches, prefix
# flowed into the label, args/envs/outfiles serialization, bare-row shape)
# / gate-OFF zero footprint (strongest sense: a ghost handle passes in
# silence) / FATAL sublegs asserting the CHILD STDERR TEXT -- rc alone
# could go green on the wrong death (B-2: cmake_language(DEFER) is
# illegal under -P, measured rc=1 on this host; a child handed the gate
# on the command line would die at the T2 tail hook BEFORE its guard).
# NO requires marker: every leg here runs offline (B-4: the requires:node
# legs of this feature never execute on this host -- the offline pair is
# this file + t-node-vscode's T2 stub-configure polarity legs).
#
# Script-mode doctrine: the face is included with the gate OFF (script
# mode + a gate-ON include would hit the DEFER illegality once T2 lands
# the tail hook); the gate is raised PER BRANCH after the include.

_polyorch_pixi_scratch(_s)

set(PolyOrchNode_EXECUTABLE "/stub/node")
set(PolyOrch_NODE_TARGET_PREFIX "px")

set(_pkg "${_s}/pkgdir")

# canned manifests -- the entry grammar's four branches
set(_m1 "${_s}/m1.json")
file(WRITE "${_m1}" "{\"name\":\"p1\",\"main\":\"dist/index.js\"}")
set(_m2 "${_s}/m2.json")
file(WRITE "${_m2}" "{\"name\":\"p2\",\"module\":\"./lib/entry.mjs\"}")
set(_m3 "${_s}/m3.json")
file(WRITE "${_m3}" "{\"name\":\"p3\",\"exports\":{\".\":{\"default\":\"out/main.cjs\"}}}")
set(_m4 "${_s}/m4.json")
# NOTE: top-level "exports":"e.js" SHORTFORM is NOT resolved by the shipped
# read_entry (object-with-"." or absent -- the v0.1 contract; import falls
# back to the dist DIRECTORY for such packages). The branch tested here is
# exports["."] as a STRING value inside the object.
file(WRITE "${_m4}" "{\"name\":\"p4\",\"exports\":{\".\":\"out/s.js\"}}")
set(_m5 "${_s}/m5.json")
file(WRITE "${_m5}" "{\"name\":\"p5\"}")
# absolute-entry manifest (rare but contracted: IS_ABSOLUTE rides verbatim)
set(_m6 "${_s}/m6.json")
file(WRITE "${_m6}" "{\"name\":\"p6\",\"main\":\"/abs/entry.js\"}")

foreach(_i 1 2 3 4 5 6)
    set_property(GLOBAL PROPERTY "POLYORCH_NODE_DIR_px-p${_i}" "${_pkg}")
    set_property(GLOBAL PROPERTY "POLYORCH_NODE_MANIFEST_px-p${_i}" "${_m${_i}}")
endforeach()

# ---- FATAL sublegs (run FIRST: the parent's gate-ON legs fill the table) --
if(POLYORCH_TEST_NODE_VSCODE_BAD)
    set(PolyOrch_NODE_VSCODE_DEBUG ON)   # branch-local, after the include
    if(POLYORCH_TEST_NODE_VSCODE_BAD STREQUAL "pipe-name")
        polyorch_node_debug(TARGET "p1" NAME "bad|name")
    elseif(POLYORCH_TEST_NODE_VSCODE_BAD STREQUAL "pipe-args")
        polyorch_node_debug(TARGET "p1" ARGS "x|y")
    elseif(POLYORCH_TEST_NODE_VSCODE_BAD STREQUAL "pipe-envs")
        polyorch_node_debug(TARGET "p1" ENVS "A=B|C")
    elseif(POLYORCH_TEST_NODE_VSCODE_BAD STREQUAL "pipe-outfiles")
        polyorch_node_debug(TARGET "p1" OUTFILES "a|b")
    elseif(POLYORCH_TEST_NODE_VSCODE_BAD STREQUAL "empty-entry")
        polyorch_node_debug(TARGET "p5")
    elseif(POLYORCH_TEST_NODE_VSCODE_BAD STREQUAL "unknown-handle")
        polyorch_node_debug(TARGET "ghost")
    elseif(POLYORCH_TEST_NODE_VSCODE_BAD STREQUAL "no-runtime")
        unset(PolyOrchNode_EXECUTABLE)
        polyorch_node_debug(TARGET "p1")
    elseif(POLYORCH_TEST_NODE_VSCODE_BAD STREQUAL "bad-envs")
        polyorch_node_debug(TARGET "p1" ENVS "not-a-assignment")
    else()
        message(FATAL_ERROR "unknown bad-leg: ${POLYORCH_TEST_NODE_VSCODE_BAD}")
    endif()
    message(FATAL_ERROR "expected the guard to fire (leg ${POLYORCH_TEST_NODE_VSCODE_BAD})")
endif()

foreach(_leg pipe-name pipe-args pipe-envs pipe-outfiles empty-entry
             unknown-handle no-runtime bad-envs)
    execute_process(COMMAND "${CMAKE_COMMAND}"
        "-DPOLYORCH_TEST_NODE_VSCODE_BAD=${_leg}"
        -P "${CMAKE_CURRENT_LIST_FILE}"
        RESULT_VARIABLE _rc ERROR_VARIABLE _re)
    ck_fail_rc(_rc)
    # the death must be OUR guard, not a stray include-time error (B-2)
    string(FIND "${_re}" "polyorch_node_debug:" _hit)
    if(_hit LESS 0)
        message(FATAL_ERROR
            "bad-leg '${_leg}' died for the wrong reason: ${_re}")
    endif()
    # and NOT the vacuous tail: the child must never reach its
    # "expected the guard to fire" line (that would mean the guard slept)
    string(FIND "${_re}" "expected the guard to fire" _slept)
    if(NOT _slept LESS 0)
        message(FATAL_ERROR "bad-leg '${_leg}' guard did not fire")
    endif()
endforeach()

# ---- gate OFF: strongest zero footprint -- ghost handle passes silently --
polyorch_node_debug(TARGET "ghost")
get_property(_sp0 GLOBAL PROPERTY POLYORCH_NODE_DEBUG_SPECS)
if(_sp0)
    message(FATAL_ERROR "gate-OFF registration left specs: ${_sp0}")
endif()

# ---- verb -> spec -> rows tables (gate raised per-leg, doctrine-safe) -----
set(PolyOrch_NODE_VSCODE_DEBUG ON)
polyorch_node_debug(TARGET "p1")
polyorch_node_debug(TARGET "p2")
polyorch_node_debug(TARGET "p3" ARGS "one" "two" ENVS "NODE_ENV=dev"
    OUTFILES "dist/**/*.map,src/**/*.map")
polyorch_node_debug(TARGET "p4" NAME "custom lbl")
polyorch_node_debug(TARGET "p6")

get_property(_specs GLOBAL PROPERTY POLYORCH_NODE_DEBUG_SPECS)
list(LENGTH _specs _n)
ck(_n EQUAL 5)
_polyorch_node_vscode_rows("${_specs}" _L)

ck(_L MATCHES "\"type\": \"node\"")
ck(_L MATCHES "\"runtimeExecutable\": \"/stub/node\"")
# entry grammar: main, module with ./ stripped, exports-object default,
# exports-string, absolute verbatim -- all through the one program field
string(FIND "${_L}" "\"program\": \"${_pkg}/dist/index.js\"" _h)
ck(NOT _h LESS 0)
string(FIND "${_L}" "\"program\": \"${_pkg}/lib/entry.mjs\"" _h)
ck(NOT _h LESS 0)
string(FIND "${_L}" "\"program\": \"${_pkg}/out/main.cjs\"" _h)
ck(NOT _h LESS 0)
string(FIND "${_L}" "\"program\": \"${_pkg}/out/s.js\"" _h)
ck(NOT _h LESS 0)
string(FIND "${_L}" "\"program\": \"/abs/entry.js\"" _h)
ck(NOT _h LESS 0)
ck(NOT _L MATCHES "dist/dist")                      # B1: never double-applied
# label = prefixed handle (px-p1); NAME override sanitized-verbatim
string(FIND "${_L}" "\"name\": \"PolyOrch: px-p1\"" _h)
ck(NOT _h LESS 0)
string(FIND "${_L}" "\"name\": \"PolyOrch: custom lbl\"" _h)
ck(NOT _h LESS 0)
# serialization: args array, env object, multi-glob outFiles, defaults
string(FIND "${_L}" "\"args\": [\"one\", \"two\", ]" _h)
ck(NOT _h LESS 0)
string(FIND "${_L}" "\"env\": {\"NODE_ENV\": \"dev\", }" _h)
ck(NOT _h LESS 0)
string(FIND "${_L}" "\"outFiles\": [\"dist/**/*.map\", \"src/**/*.map\", ]" _h)
ck(NOT _h LESS 0)
string(FIND "${_L}" "\"outFiles\": [\"${_pkg}/**/*.map\", ]" _h)
ck(NOT _h LESS 0)                                   # per-row default glob
# skipFiles rides every row (5 launch objects, region contract comma)
string(REGEX MATCHALL "\"request\": \"launch\"" _r "${_L}")
list(LENGTH _r _nr)
ck(_nr EQUAL 5)
string(REGEX MATCHALL "<node_internals>" _sf "${_L}")
list(LENGTH _sf _nsf)
ck(_nsf EQUAL 5)
# bare row (p1): args/env keys omitted ENTIRELY (outFiles default rides --
# the python precedent keeps outFiles unconditional? no: it is emitted per
# row from the spec, the default filled at REGISTRATION. The bare-row check
# therefore pins args/env only.)
list(GET _specs 0 _spec1)                    # p1 was registered first
_polyorch_node_vscode_rows("${_spec1}" _bare)  # single-row isolation
string(FIND "${_bare}" "args" _ha)
string(FIND "${_bare}" "env" _he)
if(NOT _ha LESS 0 OR NOT _he LESS 0)
    message(FATAL_ERROR "bare row leaked args/env keys: ${_bare}")
endif()
# empty table -> empty text
_polyorch_node_vscode_rows("" _EL)
string(COMPARE EQUAL "${_EL}" "" _e0)
ck(_e0)

# ---- three-source merge (direct generator call, t-python-vscode leg-2
# shape: OVERWRITING set_property seeds -- APPEND would mix the parent's
# (a)-leg residue into the row-count assertions) ---------------------------
set(_vd "${_s}/vsmerge")
set(PolyOrch_VSCODE_DIR "${_vd}")
set_property(GLOBAL PROPERTY POLYORCH_RUST_DEBUG_SPECS
    "alpha|/b/alpha|/src/alpha|debug")
set_property(GLOBAL PROPERTY POLYORCH_PYTHON_DEBUG_SPECS
    "greet|/usr/bin/python3|/src/main.py|/src||")
set_property(GLOBAL PROPERTY POLYORCH_NODE_DEBUG_SPECS
    "runme|/stub/node|${_pkg}/dist/index.js|${_pkg}|||${_pkg}/**/*.map")
_polyorch_vscode_debug_generate()
file(READ "${_vd}/launch.json" _c)
ck(_c MATCHES "PolyOrch debug configs")              # combined marker
ck(_c MATCHES "\"type\": \"lldb\"")                # rust row
ck(_c MATCHES "\"type\": \"debugpy\"")             # python row
ck(_c MATCHES "\"type\": \"node\"")                # node row
ck(_c MATCHES "\"runtimeExecutable\": \"/stub/node\"")
ck(NOT _c MATCHES "rust debug configs")              # legacy marker gone
file(SHA256 "${_vd}/launch.json" _h1)
_polyorch_vscode_debug_generate()                    # idempotent
file(SHA256 "${_vd}/launch.json" _h2)
ck(_h1 STREQUAL _h2)
file(READ "${_vd}/tasks.json" _tj)                   # rust specs -> tasks
ck(_tj MATCHES "PolyOrch rust build tasks")          # frozen marker

# ---- configure-mode polarity legs (B-4: the HOOK is product code and must
# run HERE, not only where the GUI is). Stub-driven tier-a knobs: node-ws
# configures offline (setup REQUIRED is honored by the stubs, the import
# never invokes the PM at configure). T2 tail hook: gate ON at include time
# registers the DEFER -- legal in real configure mode, the exact path a
# user's workspace takes.
set(_stub_dir "${_s}/stubs")
file(MAKE_DIRECTORY "${_stub_dir}")
file(WRITE "${_stub_dir}/npm" "#!/bin/sh\nexit 0\n")
file(WRITE "${_stub_dir}/node" "#!/bin/sh\necho v22\n")
file(COPY "${_stub_dir}/npm" "${_stub_dir}/node" DESTINATION "${_stub_dir}"
     FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE)

drv_run(_dl _rc SKIP_VAR _skip
    FIXTURE "${CMAKE_CURRENT_LIST_DIR}/../fixtures/node-ws"
    BUILD "${_s}/ws-on"
    PASSTHROUGH "-DPolyOrchNodeExe=${_stub_dir}/node"
        "-DPolyOrchNodeNpm=${_stub_dir}/npm"
        "-DPolyOrch_NODE_VSCODE_DEBUG=ON"
        "-DPolyOrch_VSCODE_DIR=${_s}/vson")
ck(_rc EQUAL 0)
file(READ "${_s}/vson/launch.json" _on)
string(FIND "${_on}" "\"name\": \"PolyOrch: hello-js\"" _h)
ck(NOT _h LESS 0)                                    # live chain -> label
string(FIND "${_on}" "\"runtimeExecutable\": \"${_stub_dir}/node\"" _h)
ck(NOT _h LESS 0)                                    # tier-a knob -> RUNTIME
ck(NOT _on MATCHES "hello-js-run")                   # no verb tail (parity)
string(FIND "${_on}" "\"type\": \"node\"" _h)
ck(NOT _h LESS 0)

drv_run(_dl2 _rc2 SKIP_VAR _skip2
    FIXTURE "${CMAKE_CURRENT_LIST_DIR}/../fixtures/node-ws"
    BUILD "${_s}/ws-off"
    PASSTHROUGH "-DPolyOrchNodeExe=${_stub_dir}/node"
        "-DPolyOrchNodeNpm=${_stub_dir}/npm"
        "-DPolyOrch_VSCODE_DIR=${_s}/vsoff")
ck(_rc2 EQUAL 0)
# the honest OFF shape: the tail hook never registers the DEFER -> the
# generator never runs -> NO file at all (asserting this via a direct
# generator call would lie: region_write has no empty-rows short-circuit,
# B-1/Momus-r3 mutual finding)
ck(NOT EXISTS "${_s}/vsoff/launch.json")

# ---- cross-sibling ordering regression (the measured defect: with the
# hook DEFER-ing to the INCLUDING directory, the first opt-in subdir fires
# the generator before later siblings register -- "node 0" orphan rows).
# The fix defers to the TOP-LEVEL end; this leg pins the invariant offline:
# python opts in EARLIER (dirA), node LATER (dirB), both rows must land.
set(_mh "${_s}/orderhost")
file(MAKE_DIRECTORY "${_mh}/dirA" "${_mh}/dirB")
file(WRITE "${_mh}/CMakeLists.txt"
"cmake_minimum_required(VERSION 3.25)\nproject(order-host LANGUAGES NONE)\nadd_subdirectory(dirA)\nadd_subdirectory(dirB)\n")
file(WRITE "${_mh}/dirA/CMakeLists.txt"
"list(APPEND CMAKE_MODULE_PATH \"\${POLYORCH_ORDER_MODDIR}\")\ninclude(PolyOrchPythonHelpers)\npolyorch_python_setup()\npolyorch_python_run(TARGET greet SCRIPT \"\${CMAKE_CURRENT_SOURCE_DIR}/m.py\")\n")
file(WRITE "${_mh}/dirA/m.py" "print(1)\n")
file(WRITE "${_mh}/dirB/CMakeLists.txt"
"list(APPEND CMAKE_MODULE_PATH \"\${POLYORCH_ORDER_MODDIR}\")\ninclude(PolyOrchNodeHelpers)\npolyorch_node_setup()\npolyorch_node_build(TARGET hi-ts MANIFEST \"\${CMAKE_CURRENT_SOURCE_DIR}/package.json\")\npolyorch_node_debug(TARGET hi-ts)\n")
file(WRITE "${_mh}/dirB/package.json" "{\"name\":\"hi-ts\",\"main\":\"dist/index.js\",\"scripts\":{\"build\":\"echo stub\"}}\n")
file(MAKE_DIRECTORY "${_mh}/dirB/dist")
file(WRITE "${_mh}/dirB/dist/index.js" "console.log(1)\n")
execute_process(
    COMMAND "${CMAKE_COMMAND}" -S "${_mh}" -B "${_mh}/b"
        "-DPolyOrch_VSCODE_DIR=${_s}/vsorder"
        "-DPolyOrch_PYTHON_VSCODE_DEBUG=ON" "-DPolyOrch_NODE_VSCODE_DEBUG=ON"
        "-DPolyOrchNodeExe=${_stub_dir}/node" "-DPolyOrchNodeNpm=${_stub_dir}/npm"
        "-DPolyOrchPythonExe=${_stub_dir}/node"
        "-DPOLYORCH_ORDER_MODDIR=${CMAKE_CURRENT_LIST_DIR}/../../cmake"
    RESULT_VARIABLE _rco OUTPUT_QUIET ERROR_VARIABLE _erco)
if(NOT _rco EQUAL 0)
    message(FATAL_ERROR "order-host configure failed: ${_erco}")
endif()
file(READ "${_s}/vsorder/launch.json" _ord)
string(FIND "${_ord}" "PolyOrch: greet" _h)          # earlier sibling
ck(NOT _h LESS 0)
string(FIND "${_ord}" "PolyOrch: hi-ts" _h)          # LATER sibling -- no orphan
ck(NOT _h LESS 0)
ck(_ord MATCHES "\"type\": \"debugpy\"")
ck(_ord MATCHES "\"type\": \"node\"")

message(STATUS "t-node-vscode: OK (FATAL family + gate-off silence + rows tables + 3-source merge + configure polarity both ways + cross-sibling ordering)")
