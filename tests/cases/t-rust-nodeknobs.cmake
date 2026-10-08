# requires: node
# t-rust-nodeknobs -- the naming-knob contract (A2): node owns
# PolyOrch_NODE_TARGET_PREFIX, rust owns PolyOrch_RUST_TARGET_PREFIX, and
# NEITHER leaks into the other. add_custom_target is not scriptable, so the
# knob effects are exercised through the driver-configured fixture with
# PASSTHROUGH knob values; handle names are asserted from the persisted
# configure log.
cmake_policy(SET CMP0219 NEW)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

polyorch_requires(node _req)
if(NOT _req)
    message(STATUS "t-rust-nodeknobs : SKIP (no node+pm on PATH/pixi-glob)")
    return()
endif()

# stub chain: the import surface is what is under test, no real builds.
# Script mode has NO binary dir -- the scratch root is the writable anchor
# (the same lesson t-rust-cxxbridge's stub dir already carries).
_polyorch_pixi_scratch(_s0)
set(_stub_dir "${_s0}/stubs")
file(MAKE_DIRECTORY "${_stub_dir}")
file(WRITE "${_stub_dir}/npm" "#!/bin/sh\nexit 0\n")
file(WRITE "${_stub_dir}/node" "#!/bin/sh\necho v22\n")
file(COPY "${_stub_dir}/npm" "${_stub_dir}/node"
     DESTINATION "${_stub_dir}"
     FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE)

# ---- leg 1: independence -- rust knob set, node knob UNSET => bare names --
set(_pass "-DPolyOrchNodeExe=${_stub_dir}/node")
list(APPEND _pass "-DPolyOrchNodeNpm=${_stub_dir}/npm")
list(APPEND _pass "-DPolyOrch_RUST_TARGET_PREFIX=po-rust")
_polyorch_pixi_scratch(_s)
set(_b1 "${_s}/knobs-indep")
drv_run(_dlog _rc SKIP_VAR _skip
    FIXTURE "${CMAKE_CURRENT_LIST_DIR}/../fixtures/node-ws"
    BUILD "${_b1}"
    PASSTHROUGH ${_pass})
if(_skip)
    message(STATUS "t-rust-nodeknobs : SKIP (fixture gate)")
    return()
endif()
ck(_rc EQUAL 0)
file(READ "${_b1}/_configure.log" _clog)
ck(_clog MATCHES "2 handle\\(s\\) imported \\[hello-js;scope-hello-ui\\]")
string(FIND "${_clog}" "po-rust-hello-js" _leak)
if(NOT _leak LESS 0)
    message(FATAL_ERROR "check failed: RUST knob leaked into node naming")
endif()

# ---- leg 2: the node knob prefixes exactly like the rust knob does --------
set(_pass2 "-DPolyOrchNodeExe=${_stub_dir}/node")
list(APPEND _pass2 "-DPolyOrchNodeNpm=${_stub_dir}/npm")
list(APPEND _pass2 "-DPolyOrch_NODE_TARGET_PREFIX=po-node")
_polyorch_pixi_scratch(_s2)
# D33: the gate + a PARKED output dir ride leg2. Appended after the scratch
# exists -- list(APPEND) expands ${_s2} NOW (the 02df192 catch, kept warm).
list(APPEND _pass2 "-DPolyOrch_NODE_VSCODE_DEBUG=ON" "-DPolyOrch_VSCODE_DIR=${_s2}/vs")
set(_b2 "${_s2}/knobs-pref")
drv_run(_dlog2 _rc SKIP_VAR _skip
    FIXTURE "${CMAKE_CURRENT_LIST_DIR}/../fixtures/node-ws"
    BUILD "${_b2}"
    PASSTHROUGH ${_pass2})
ck(_rc EQUAL 0)
file(READ "${_b2}/_configure.log" _clog2)
ck(_clog2 MATCHES "2 handle\\(s\\) imported \\[po-node-hello-js;po-node-scope-hello-ui\\]")
# D33 label parity (runs on node hosts; on this host the whole case
# contract-SKIPs -- exact line recorded in the commit): debug rows carry
# the PREFIXED handle and NO verb tail -- the host-contact fix the python
# face learned late, born fixed here.
file(READ "${_s2}/vs/launch.json" _lj2)
ck(_lj2 MATCHES "PolyOrch: po-node-hello-js")
ck(NOT _lj2 MATCHES "po-node-hello-js-run")

# ---- leg 3: caller-key precedence (the D28 formula, node flavor) ----------
# <PROJECT>_POLYORCH_NODE_TARGET_PREFIX wins over the classic knob. The key
# carries hyphens when the consumer's project name has them (legal in CMake
# variables, unpassable via -D), so the child script IS the caller: written
# from a template (PIT-85: no heredoc-in-string quoting), configured with
# the real module dir, and run in script mode (no targets needed for the
# apply helper's unit shape).
set(_child "${_stub_dir}/knobs-caller-child.cmake")
file(READ "${CMAKE_CURRENT_LIST_DIR}/_nodeknobs-caller-child.cmake.in" _tmpl)
string(REPLACE "@MODULE_DIR@" "${CMAKE_CURRENT_LIST_DIR}" _tmpl "${_tmpl}")
file(WRITE "${_child}" "${_tmpl}")
execute_process(COMMAND "${CMAKE_COMMAND}" -P "${_child}"
    RESULT_VARIABLE _rc3 OUTPUT_VARIABLE _o3 ERROR_VARIABLE _e3)
ck(_rc3 EQUAL 0)
# STATUS lines go to stderr; assert on the merged pair
set(_o3all "${_o3}${_e3}")
ck(_o3all MATCHES "knobs-caller-child: OK")

message(STATUS "t-rust-nodeknobs: OK")
