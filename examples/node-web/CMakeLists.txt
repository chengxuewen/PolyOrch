# examples/node-web -- the npm bridge (D29 / WP-node-alpha)
#
# "CMake orchestrates an npm/pnpm workspace": polyorch_node_import reads the
# root manifest's workspaces globs and registers one -build mediator per
# member (the workspace:* dependency edge hello-ts -> @scope/hello-js is a
# real add_dependencies edge). The packages' build scripts are zero-dependency
# node scripts on purpose: the ORCHESTRATED surface is the package manager's
# workspace machinery (resolution, -w/--filter dispatch, dist/ convention),
# not a compiler -- PolyOrch never invokes tsc/vite (adjudication 4).
#
# Entry points:
#   standalone:  cmake -S examples/node-web -B build
#   fused:       part of the examples umbrella (PolyOrch_BUILD_RUST_EXAMPLES=ON
#                runs this loop; targets carry the polyorch-node-web- prefix)
#   run:         cmake --build build --target <prefix>hello-ts-run-hello

project(node-web LANGUAGES NONE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
include(PolyOrchNodeHelpers)

# standalone REQUIRED (the rust-basic idiom: the user running this example
# alone is making an environment statement -- a missing node is fatal HERE,
# a STATUS note in the fused tree)
if(NOT POLYORCH_NODE_FOUND AND NOT PolyOrch_RUST_TARGET_PREFIX AND NOT PolyOrch_NODE_TARGET_PREFIX)
    polyorch_node_setup(REQUIRED)
else()
    polyorch_node_setup()
endif()

if(NOT POLYORCH_NODE_FOUND)
    # fused-tree degradation: register nothing, say why (family convention)
    return()
endif()

# fixture artifact contract BEFORE every early return... there are no more
# early returns; kept at the top anyway per PIT-34 discipline.
set(POLYORCH_FIXTURE_ARTIFACTS
    "manifest=${CMAKE_CURRENT_LIST_DIR}/package.json")
string(JOIN "\n" _af ${POLYORCH_FIXTURE_ARTIFACTS})
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/polyorch-fixture-artifacts.txt" "${_af}\n")

# FOLDER idiom: the fusion loop injects PolyOrch_RUST_FOLDER_ROOT for the
# whole family (it is the family root despite the historical RUST substring);
# standalone falls back to this directory's relative name.
if(PolyOrch_RUST_FOLDER_ROOT)
    set(_nfolder "${PolyOrch_RUST_FOLDER_ROOT}")
else()
    file(RELATIVE_PATH _nfolder
        "${CMAKE_SOURCE_DIR}"
        "${CMAKE_CURRENT_SOURCE_DIR}")
endif()

polyorch_node_import(ROOT "${CMAKE_CURRENT_LIST_DIR}/package.json")

# family verbs over the imported handles:
#   @scope/hello-js -> scope-hello-js (A1 sanitize as measured: add_custom_target
#                      rejects '@'-headed names, so the '@' is stripped) ->
#                      polyorch-node-web-scope-hello-js (fused)
#   hello-ts        -> hello-ts -> polyorch-node-web-hello-ts
polyorch_node_test(TARGET "scope-hello-js")     # no scripts.test -> loud STATUS skip
polyorch_node_test(TARGET "hello-ts")           # has scripts.test  -> registered
polyorch_node_run(TARGET "scope-hello-js" SCRIPT hello)

# FOLDER: the registered names are PREFIXED in the fused tree (the rust-nodejs
# demo idiom -- compose both branches, or reuse the loop's knobs directly)
if(PolyOrch_NODE_TARGET_PREFIX)
    set(_h1 "${PolyOrch_NODE_TARGET_PREFIX}-scope-hello-js-build")
    set(_h2 "${PolyOrch_NODE_TARGET_PREFIX}-hello-ts-build")
    set(_h3 "${PolyOrch_NODE_TARGET_PREFIX}-hello-ts-test")
    set(_h4 "${PolyOrch_NODE_TARGET_PREFIX}-scope-hello-js-run-hello")
else()
    set(_h1 "scope-hello-js-build")
    set(_h2 "hello-ts-build")
    set(_h3 "hello-ts-test")
    set(_h4 "scope-hello-js-run-hello")
endif()
set_target_properties("${_h1}" "${_h2}" "${_h3}" "${_h4}"
    PROPERTIES FOLDER "${_nfolder}")
