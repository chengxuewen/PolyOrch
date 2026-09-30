# requires: node
cmake_policy(SET CMP0219 NEW)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

# t-rust-node -- the node bridge contract (D29 / WP-node-alpha)
# legs: configure report / import tables (handles + A1 sanitize) / a real
# build through the PM (workspace edge + dist convention) / the scripts.test
# gate. Gating: `# requires: node` (probe in _requires.cmake: PATH + pixi
# glob) + the drivers' global POLYORCH_TEST_E2E gate for the build leg (the
# t-rust-rustflags precedent, Momus fix 3 -- no per-leg e2e declarations).
# parent-side contract gate (the cxxbridge posix-shell idiom): the marker
# above only exempts the SKIP veto; the probe runs HERE. node AND a PM
# (corepack|npm) both required -- setup degrades on a missing PM and the
# verbs register nothing, so a deep FATAL inside the fixture is the wrong
# failure mode; the contract skip belongs at the gate.
polyorch_requires(node _req)
if(NOT _req)
    message(STATUS "t-rust-node : SKIP (no node+pm on PATH/pixi-glob)")
    return()
endif()

_polyorch_pixi_scratch(_s)
set(_b "${_s}/node-bridge")

# ---- configure the fixture workspace through the bridge -------------------
# Tier-a determinism: pass the probed node explicitly (-DPolyOrchNodeExe=).
find_program(_tnode NAMES node)
if(NOT _tnode)
    find_program(_tnode NAMES node PATHS "$ENV{HOME}/.pixi/bin")
endif()
if(NOT _tnode)
    file(GLOB _tpn "$ENV{HOME}/.pixi/envs/*/bin/node")
    list(LENGTH _tpn _tpn_n)
    if(_tpn_n GREATER 0)
        list(GET _tpn 0 _tnode)
    endif()
endif()
# tier-a for the PM as well: the driver child's PATH is the composed
# minimal one (cargo/pixi dirs), so the case hands over whatever the parent
# probe found -- corepack first, bare npm otherwise.
set(_pass "-DPolyOrchNodeExe=${_tnode}")
find_program(_tcp NAMES corepack)
if(_tcp)
    list(APPEND _pass "-DPolyOrchNodeCorepack=${_tcp}")
else()
    find_program(_tnpm NAMES npm)
    if(_tnpm)
        list(APPEND _pass "-DPolyOrchNodeNpm=${_tnpm}")
    endif()
endif()
drv_run(_dlog _rc SKIP_VAR _skip
    FIXTURE "${CMAKE_CURRENT_LIST_DIR}/../fixtures/node-ws"
    BUILD "${_b}"
    PASSTHROUGH ${_pass})
if(_skip)
    message(STATUS "t-rust-node : SKIP (fixture gate: no node/pm)")
    return()
endif()
ck(_rc EQUAL 0)

# ---- leg 1: the configure report -------------------------------------------
# The fixture's configure output lives in the driver's persisted log (the
# rust-family negative-leg convention: assert against the raw
# _configure.log), not in drv_run's captured stdout.
file(READ "${_b}/_configure.log" _clog)
ck(_clog MATCHES "polyorch_node: node")
ck(_clog MATCHES "polyorch_node_import: 2 handle")

# ---- leg 2: import tables ---------------------------------------------------
# standalone names: bare + sanitized ('@scope/hello-ui' -> 'scope-hello-ui';
# the '@' prefix is stripped -- add_custom_target rejects '@'-headed names,
# measured). The driver's artifact contract asserted the dist products
# during drv_run; here we pin the handle names.
file(READ "${_b}/CMakeFiles/TargetDirectories.txt" _tdirs)
foreach(_t "scope-hello-ui-build" "hello-js-build")
    string(FIND "${_tdirs}" "${_t}" _hit)
    if(_hit LESS 0)
        message(FATAL_ERROR "check failed: node handle '${_t}' not registered")
    endif()
endforeach()

# ---- leg 3: real build through the PM --------------------------------------
# hello-ui's gen.js REQUIRES the sibling's product at gen time (the
# workspace:* dependency edge, exercised for real), and both members must
# emit dist/index.js (the dist convention, adjudication 2). The PM is real:
# the PM dispatch IS the surface under test.
execute_process(
    COMMAND "${CMAKE_COMMAND}" --build "${_b}" --target "scope-hello-ui-build"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _bo ERROR_VARIABLE _be)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "node bridge build failed (rc=${_rc}): ${_bo}${_be}")
endif()
# the mediators run with WORKING_DIRECTORY at the fixture SOURCE root --
# the dist convention lands next to each manifest (source tree), which is
# exactly what the driver's artifact contract keys on
ck(EXISTS "${CMAKE_CURRENT_LIST_DIR}/../fixtures/node-ws/packages/hello-js/dist/index.js")
ck(EXISTS "${CMAKE_CURRENT_LIST_DIR}/../fixtures/node-ws/packages/@scope/hello-ui/dist/index.js")

# ---- leg 4: the scripts.test gate (loud absence) ---------------------------
ck(_clog MATCHES "no scripts.test")
