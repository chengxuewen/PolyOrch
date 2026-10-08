# WP12: system-route example fusion (umbrella add_subdirectory form).
# Fuses the three system-route examples into a scratch host configure and
# asserts the resulting target tree: per-example verb targets exist, the
# per-example aggregates carry example-prefixed names (no silent merge),
# and the remote-control buttons (pixi routes, install-export) are still
# registered. Offline (cargo not needed for the target-existence legs --
# the scratch configure skips tool-less subtrees via the STATUS gates, but
# with cargo present it fuses fully; requires: system-rust).
# requires: system-rust
cmake_policy(SET CMP0219 NEW)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")

_polyorch_pixi_scratch(_s)
set(_h "${_s}/fused")

# Host configure == the umbrella (the examples root IS a host when fused
# standalone-configured). Path composition mirrors the driver child PATH.
file(MAKE_DIRECTORY "${_h}")
file(WRITE "${_h}/CMakeLists.txt"
"cmake_minimum_required(VERSION 3.22)\n"
"project(fused-host LANGUAGES C)\n"
"add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/../../examples examples)\n")
execute_process(
    COMMAND "${CMAKE_COMMAND}" -S "${_h}" -B "${_h}/b"
        -DPolyOrch_BUILD_EXAMPLES=ON -DPolyOrch_BUILD_RUST_EXAMPLES=ON
    ENVIRONMENT "PATH=$ENV{PATH}:$ENV{HOME}/.cargo/bin:$ENV{HOME}/.pixi/bin"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
ck(_rc EQUAL 0)
string(REGEX MATCHALL "CMake Error" _cerrs "${_out}${_err}")
list(LENGTH _cerrs _nerr)
ck(_nerr EQUAL 0)

# target existence via the generated build tree's target directory list
file(READ "${_h}/b/CMakeFiles/TargetDirectories.txt" _tdirs)
foreach(_t "polyorch-rust-basic-greet-build" "polyorch-rust-basic-greet-run"
           "polyorch-rust-import-dash_ed-build" "polyorch-rust-link-c-cli-user-tool-build"
           "polyorch-rust-profile-features-demo-rel-build"
           "polyorch-rust-basic-all" "polyorch-rust-import-all" "polyorch-rust-link-c-all"
           "polyorch-rust-profile-features-all"
           )
    string(FIND "${_tdirs}" "${_t}.dir" _hit)
    if(_hit LESS 0)
        message(FATAL_ERROR "check failed: fused target '${_t}' absent from host tree")
    endif()
endforeach()

# A3 (D29): the node family rides the same fused namespace -- asserted ONLY
# when node+pm are reachable (the fusion tree's STATUS degradation is the
# no-node contract, same as the rust family's no-cargo degradation). The
# sanitize shape (@scope/hello-js -> scope-hello-js) is pinned when present.
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")
polyorch_requires(node _node_req)
set(_node_names
    "polyorch-node-web-scope-hello-js-build"
    "polyorch-node-web-hello-ts-build"
    "polyorch-node-web-scope-hello-js-run-hello")
if(_node_req)
    foreach(_t ${_node_names})
        string(FIND "${_tdirs}" "${_t}.dir" _hit)
        if(_hit LESS 0)
            message(FATAL_ERROR "check failed: fused node target '${_t}' absent from host tree")
        endif()
    endforeach()
    # D33: node buttons/mediators sit in the loop's per-example IDE group
    # (the host-contact FOLDER contract, python leg's twin below; the
    # reply files carry the folder as a $ref object).
    file(MAKE_DIRECTORY "${_h}/b/.cmake/api/v1/query/codemodel-v2")
    execute_process(
        COMMAND "${CMAKE_COMMAND}" -S "${_h}" -B "${_h}/b"
        ENVIRONMENT "PATH=$ENV{PATH}:$ENV{HOME}/.cargo/bin:$ENV{HOME}/.pixi/bin"
        RESULT_VARIABLE _rcn OUTPUT_QUIET ERROR_QUIET)
    ck(_rcn EQUAL 0)
    set(_foldnd "")
    file(GLOB _tjs "${_h}/b/.cmake/api/v1/reply/target-*.json")
    foreach(_tj ${_tjs})
        file(READ "${_tj}" _j)
        string(JSON _nm GET "${_j}" name)
        if(_nm STREQUAL "polyorch-node-web-hello-ts-build")
            string(JSON _fp ERROR_VARIABLE _fe GET "${_j}" folder)
            if(_fe)
                message(FATAL_ERROR "node mediator carries NO FOLDER (IDE misgroup): ${_fe}")
            endif()
            string(JSON _fpn GET "${_fp}" name)
            set(_foldnd "${_fpn}")
        endif()
    endforeach()
    if(_foldnd STREQUAL "")
        message(FATAL_ERROR "codemodel reply never produced the node target json")
    endif()
    ck_str("${_foldnd}" "fused-host/examples/node-web")
else()
    foreach(_t ${_node_names})
        string(FIND "${_tdirs}" "${_t}.dir" _hit)
        if(NOT _hit LESS 0)
            message(FATAL_ERROR "check failed: fused node target '${_t}' registered WITHOUT node+pm (degradation broken)")
        endif()
    endforeach()
endif()

# D32: the python family rides the same fused namespace (A3 pattern --
# asserted ONLY when an interpreter is reachable; the else-leg pins that
# python-basic registers NOTHING without one, the loop's per-face gate).
polyorch_requires(python _py_req)
set(_py_names
    "polyorch-python-basic-greet-run")
if(_py_req)
    foreach(_t ${_py_names})
        string(FIND "${_tdirs}" "${_t}.dir" _hit)
        if(_hit LESS 0)
            message(FATAL_ERROR "check failed: fused python target '${_t}' absent from host tree")
        endif()
    endforeach()
    # D32 host-contact fix: the python button must sit in the SAME IDE
    # group shape its rust siblings carry (the fused-FOLDER complaint from
    # the real host tree). File API codemodel is the only truth source for
    # the FOLDER property on non-IDE generators -- seed a query, re-drive
    # configure (incremental), read the target's folder field.
    file(MAKE_DIRECTORY "${_h}/b/.cmake/api/v1/query/codemodel-v2")
    execute_process(
        COMMAND "${CMAKE_COMMAND}" -S "${_h}" -B "${_h}/b"
        ENVIRONMENT "PATH=$ENV{PATH}:$ENV{HOME}/.cargo/bin:$ENV{HOME}/.pixi/bin"
        RESULT_VARIABLE _rcf OUTPUT_QUIET ERROR_QUIET)
    ck(_rcf EQUAL 0)
    set(_foldpy "")
    file(GLOB _tjs "${_h}/b/.cmake/api/v1/reply/target-*.json")
    foreach(_tj ${_tjs})
        file(READ "${_tj}" _j)
        string(JSON _nm GET "${_j}" name)
        if(_nm STREQUAL "polyorch-python-basic-greet-run")
            string(JSON _fp ERROR_VARIABLE _fe GET "${_j}" folder)
            if(_fe)
                message(FATAL_ERROR "python button carries NO FOLDER property (IDE misgroup): ${_fe}")
            endif()
            # codemodel folder fields are $ref objects: {"name": "..."}
            string(JSON _fpn GET "${_fp}" name)
            set(_foldpy "${_fpn}")
        endif()
    endforeach()
    if(_foldpy STREQUAL "")
        message(FATAL_ERROR "codemodel reply never produced the python target json")
    endif()
    ck_str("${_foldpy}" "fused-host/examples/python-basic")
else()
    foreach(_t ${_py_names})
        string(FIND "${_tdirs}" "${_t}.dir" _hit)
        if(NOT _hit LESS 0)
            message(FATAL_ERROR "check failed: fused python target '${_t}' registered WITHOUT an interpreter")
        endif()
    endforeach()
endif()

# remote-control buttons still registered (pixi route + install-export)
foreach(_btn "polyorch-rust-install-export")
    string(FIND "${_tdirs}" "${_btn}.dir" _hit)
    if(_hit LESS 0)
        message(FATAL_ERROR "check failed: remote button '${_btn}' missing")
    endif()
endforeach()

# WP13 mount correctness on the import path: the dashed-package crates
# (dash-ed lib + say-hi bin) each mount THEIR OWN sources (the selector
# normalization compare + the manifest+crate cache key)
execute_process(
    COMMAND "${CMAKE_COMMAND}" -S "${_h}" -B "${_h}/b"
        -DPolyOrch_BUILD_EXAMPLES=ON -DPolyOrch_BUILD_RUST_EXAMPLES=ON
        -DPolyOrch_RUST_VSCODE_DIR=${_h}/vsout
    ENVIRONMENT "PATH=$ENV{PATH}:$ENV{HOME}/.cargo/bin:$ENV{HOME}/.pixi/bin"
    RESULT_VARIABLE _rc OUTPUT_QUIET ERROR_QUIET)
ck(_rc EQUAL 0)
# WP13 mount correctness on the import path (File API codemodel, the
# layer VSCode consumes): the dashed-package crates each mount THEIR OWN
# sources -- selector-normalization compare + manifest+crate cache key.
set(_b2 "${_s}/fused-q")
file(MAKE_DIRECTORY "${_b2}/.cmake/api/v1/query/client-vscode")
file(WRITE "${_b2}/.cmake/api/v1/query/client-vscode/query.json"
    "{\"requests\":[{\"kind\":\"codemodel\",\"version\":2}]}")
execute_process(
    COMMAND "${CMAKE_COMMAND}" -S "${_h}" -B "${_b2}"
        -DPolyOrch_BUILD_EXAMPLES=ON -DPolyOrch_BUILD_RUST_EXAMPLES=ON
    ENVIRONMENT "PATH=$ENV{PATH}:$ENV{HOME}/.cargo/bin:$ENV{HOME}/.pixi/bin"
    RESULT_VARIABLE _rc OUTPUT_QUIET ERROR_QUIET)
ck(_rc EQUAL 0)
# the codemodel index only REFERENCES targets; the sources live in the
# per-target reply files -- scan all of them
file(GLOB _cmf "${_b2}/.cmake/api/v1/reply/target-*.json")
list(LENGTH _cmf _ncm)
ck(_ncm GREATER 4)   # a fused tree has ~20 targets; 0-4 means the query never ran
set(_cmj "")
foreach(_f ${_cmf})
    file(READ "${_f}" _one)
    string(APPEND _cmj "${_one}")
endforeach()
string(FIND "${_cmj}" "dash-ed/src/lib.rs" _hit1)
string(FIND "${_cmj}" "say-hi/src/main.rs" _hit2)
ck(_hit1 GREATER -1)
ck(_hit2 GREATER -1)
# contamination guard: dash-ed's lib.rs must appear EXACTLY once in the
# whole reply (a manifest-only cache key would mount it on say-hi too)
string(REGEX MATCHALL "dash-ed/src/lib.rs" _lhits "${_cmj}")
list(LENGTH _lhits _nl)
ck(_nl EQUAL 1)

# WP13 regression lock: the fused default path must actually BUILD each
# family (rust-link-c's direction-2 C staticlib once lived in a comment
# while link_libraries referenced it -- invisible until fused).
execute_process(
    COMMAND "${CMAKE_COMMAND}" --build "${_b2}/examples/rust-link-c" --target polyorch-rust-link-c-cli-user-tool-build
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _bo ERROR_VARIABLE _be)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "fused link-c build failed (rc=${_rc}): ${_bo}${_be}")
endif()

message(STATUS "t-rust-fusion: OK (3 fused verb sets + prefixed aggregates + remote buttons intact)")
