# requires: system-rust
cmake_policy(SET CMP0219 NEW)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

# WP18: "Web frontends consume a rust crate via an npm package"
# (wasm-pack). Heavy toolchain prerequisites (wasm32 target, wasm-pack,
# wasm-bindgen CLI pair, wasm-opt) -- every leg degrades to STATUS in the
# example; this case probes the same set and SKIPs when absent, so hosts
# without the wasm stack keep their green gate.
_polyorch_pixi_scratch(_s)
set(_b "${_s}/rwa")
drv_run(_dlog _rc SKIP_VAR _skip
    FIXTURE "${CMAKE_CURRENT_LIST_DIR}/../../examples/rust-wasm"
    BUILD "${_b}")
if(_skip)
    message(STATUS "t-rust-wasm : SKIP (fixture gate: no cargo)")
    return()
endif()

# prereq probes (mirror the example's own gates)
find_program(_wp wasm-pack)
find_program(_wbg wasm-bindgen)
find_program(_node node)
if(NOT _node)
    file(GLOB _pixinode
        "$ENV{HOME}/.pixi/envs/*/bin/node"
        "/tmp/opencode/*/.pixi/envs/default/bin/node"
        "/tmp/opencode/*/pixi/envs/default/bin/node")
    list(LENGTH _pixinode _pn)
    if(_pn GREATER 0)
        list(GET _pixinode 0 _node)
    endif()
endif()
find_program(_wopt wasm-opt)
if(NOT _wopt)
    file(GLOB _pixiopt
        "/tmp/opencode/*/.pixi/envs/default/bin/wasm-opt"
        "/tmp/opencode/*/pixi/envs/default/bin/wasm-opt")
    list(LENGTH _pixiopt _po)
    if(_po GREATER 0)
        list(GET _pixiopt 0 _wopt)
    endif()
endif()
execute_process(COMMAND rustup target list --installed OUTPUT_VARIABLE _rtgt ERROR_QUIET)
string(FIND "${_rtgt}" "wasm32-unknown-unknown" _haswasm)
if(NOT _wp OR NOT _node OR NOT _wbg OR _haswasm LESS 0)
    message(STATUS "t-rust-wasm : SKIP (wasm stack incomplete: pack=${_wp} bindgen=${_wbg} node=${_node} target=${_haswasm})")
    return()
endif()

# build BOTH flavors + run the demo (node imports the nodejs pkg)
set(_extra_path "")
if(_wopt)
    cmake_path(GET _wopt PARENT_PATH _woptdir)
    set(_extra_path ":${_woptdir}")
endif()
execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_b}"
    --target rust-wasm-demo
    ENVIRONMENT "PATH=$ENV{PATH}${_extra_path}"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(NOT _rc EQUAL 0)
    message(STATUS "wasm demo rc=${_rc}: ${_err}${_out}")
endif()
ck(_rc EQUAL 0)
ck(_out MATCHES "hello from spine-wasm")
string(FIND "${_out}" "add(19,23) = 42" _hit)
ck(_hit GREATER -1)

# the bundler deliverable (web frontend artifact): build it explicitly
# (custom target) then assert the npm package manifest set
execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_b}"
    --target rust-wasm-pkg-bundler
    ENVIRONMENT "PATH=$ENV{PATH}${_extra_path}"
    RESULT_VARIABLE _rc OUTPUT_QUIET ERROR_QUIET)
ck(_rc EQUAL 0)
ck(EXISTS "${_b}/pkg-web/spine_wasm.js")
ck(EXISTS "${_b}/pkg-web/spine_wasm_bg.wasm")
ck(EXISTS "${_b}/pkg-web/spine_wasm.d.ts")
ck(EXISTS "${_b}/pkg-web/package.json")

message(STATUS "t-rust-wasm: OK (wasm-pack pkg/ both flavors + node consumer + npm deliverable)")
