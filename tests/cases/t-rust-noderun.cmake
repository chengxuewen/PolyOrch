# requires: node
# t-rust-noderun -- the run verb's contract: SCRIPT verbs register
# `<handle>-run-<script>` one-shot targets, ARGS pass through "--", and the
# mediator commands carry the PM dispatch with the workspace flags (the
# two-row table). Stub tools: the PM dispatch surface is what is under
# test, not real script execution (real execution is pinned in
# t-rust-node's build leg).
cmake_policy(SET CMP0219 NEW)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

_polyorch_pixi_scratch(_s)
set(_b "${_s}/node-run")

# the stub chain (t-rust-cxxbridge's fixture-stub shape): a PM that logs
# argv and succeeds, a node that exists
set(_stub_dir "${_s}/stubs")
file(MAKE_DIRECTORY "${_stub_dir}")
file(WRITE "${_stub_dir}/npm" "#!/bin/sh
echo \"NPM-STUB: \$@\" >> \"${_stub_dir}/calls.log\"
exit 0
")
file(WRITE "${_stub_dir}/node" "#!/bin/sh
echo \"v22.0.0-stub\"
exit 0
")
file(COPY "${_stub_dir}/npm" "${_stub_dir}/node"
     DESTINATION "${_stub_dir}"
     FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE)

set(_pass "-DPolyOrchNodeExe=${_stub_dir}/node")
list(APPEND _pass "-DPolyOrchNodeNpm=${_stub_dir}/npm")
drv_run(_dlog _rc SKIP_VAR _skip
    FIXTURE "${CMAKE_CURRENT_LIST_DIR}/../fixtures/node-ws"
    BUILD "${_b}"
    PASSTHROUGH ${_pass})
if(_skip)
    message(STATUS "t-rust-noderun : SKIP (fixture gate)")
    return()
endif()
ck(_rc EQUAL 0)
file(READ "${_b}/_configure.log" _clog)

# leg 1: run verbs registered under the -run-<script> grammar, both members
file(READ "${_b}/CMakeFiles/TargetDirectories.txt" _tdirs)
foreach(_t "hello-js-run-hello" "scope-hello-ui-run-hello")
    string(FIND "${_tdirs}" "${_t}" _hit)
    if(_hit LESS 0)
        message(FATAL_ERROR "check failed: run target '${_t}' not registered")
    endif()
endforeach()

# leg 2: the ARGS passthrough lands in the generated rule verbatim. The
# per-target rule file is generator-dependent (Make: build.make inside the
# .dir; Ninja: rules in build.ninja) -- read whichever exists.
set(_rulefiles "${_b}/CMakeFiles/hello-js-run-args.dir/build.make")
list(APPEND _rulefiles "${_b}/build.ninja")
set(_bmt "")
foreach(_rf ${_rulefiles})
    if(EXISTS "${_rf}")
        file(READ "${_rf}" _bmt)
        break()
    endif()
endforeach()
if(_bmt STREQUAL "")
    message(FATAL_ERROR "check failed: no rule file for run-args (generator?)")
endif()
ck(_bmt MATCHES "run-args")
ck(_bmt MATCHES "--port=8080")

message(STATUS "t-rust-noderun: OK")
