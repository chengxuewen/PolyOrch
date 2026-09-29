# requires: system-rust
cmake_policy(SET CMP0219 NEW)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

# WP17: "Node.js consumes a rust addon" (napi-rs). The crate builds with
# zero node involvement (stable ABI); the demo target needs node. This
# case skips cleanly when node is absent (same contract as tool gates).
_polyorch_pixi_scratch(_s)
set(_b "${_s}/rnj")
# node for the demo leg: system PATH, else a pixi env's bin/node
set(_node "")
find_program(_node node)
if(NOT _node)
    file(GLOB _pixinode
        "$ENV{HOME}/.pixi/envs/*/bin/node"
        "/tmp/opencode/*/pixi/envs/default/bin/node"
        "/tmp/opencode/*/.pixi/envs/default/bin/node")
    list(LENGTH _pixinode _pn)
    if(_pn GREATER 0)
        list(GET _pixinode 0 _node)
    endif()
endif()
drv_run(_dlog _rc SKIP_VAR _skip
    FIXTURE "${CMAKE_CURRENT_LIST_DIR}/../../examples/rust-nodejs"
    BUILD "${_b}"
    PASSTHROUGH "-DPolyOrchRustNodeExe=${_node}")
if(_skip)
    message(STATUS "t-rust-nodejs : SKIP (fixture gate: no cargo)")
    return()
endif()

# build the cdylib explicitly (custom target)
execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_b}"
    --target spine-node-build
    RESULT_VARIABLE _rc OUTPUT_QUIET ERROR_QUIET)
ck(_rc EQUAL 0)

# the artifact exists in the isolated target dir (cdylib, cargo lib name)
set(_cfg "$ENV{POLYORCH_TEST_CONFIG}")
if(_cfg AND EXISTS "${_b}/.cargo-target/${_cfg}/libspine_node.so")
    set(_so "${_b}/.cargo-target/${_cfg}/libspine_node.so")
else()
    file(GLOB _so "${_b}/.cargo-target/*/libspine_node.so" "${_b}/.cargo-target/libspine_node.so")
    list(LENGTH _so _n)
    ck(_n EQUAL 1)
    list(GET _so 0 _so)
endif()
ck(EXISTS "${_so}")

# node available? run the demo; else the artifact assertions above stand
find_program(_node node)
if(NOT _node)
    # a pixi env's node, if one exists (any env with node counts; absence
    # falls through to the artifact-only verdict below)
    file(GLOB _pixinode
        "$ENV{HOME}/.pixi/envs/*/bin/node"
        "/tmp/opencode/*/.pixi/envs/default/bin/node"
        "/tmp/opencode/*/pixi/envs/default/bin/node")
    list(LENGTH _pixinode _pn)
    if(_pn GREATER 0)
        list(GET _pixinode 0 _node)
    endif()
endif()
if(_node)
    execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_b}"
        --target spine-node-demo
        RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
    if(NOT _rc EQUAL 0)
        message(STATUS "nodejs demo rc=${_rc}: ${_err}${_out}")
    endif()
    ck(_rc EQUAL 0)
    ck(_out MATCHES "hello from spine-node")
    string(FIND "${_out}" "add(19,23) = 42" _hit)
    ck(_hit GREATER -1)
    message(STATUS "t-rust-nodejs: OK (napi cdylib + .node staging + node consumer, 42)")
else()
    message(STATUS "t-rust-nodejs: OK (napi cdylib artifact; node absent -- demo leg skipped)")
endif()
