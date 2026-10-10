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
#   run:         cmake --build build --target <prefix>scope-hello-js-run-hello
#   debug:       js-debug rows (VSCode built-in, no extension) land in the
#                shared managed region; standalone usage parks the output:
#                cmake -S examples/node-web -B build -DPolyOrch_VSCODE_DIR=build/.vscode

cmake_minimum_required(VERSION 3.22)
project(node-web LANGUAGES NONE)

# D33 opt-in (before the include: the tail hook reads the gate at include
# time). hello-ts ONLY -- @scope/hello-js declares no entry (main/module/
# exports), registering it would FATAL inside the gate on every node-having
# host (momus-v2 B1).
set(PolyOrch_NODE_VSCODE_DEBUG ON)

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

polyorch_node_import(ROOT "${CMAKE_CURRENT_LIST_DIR}/package.json")

# family verbs over the imported handles:
#   @scope/hello-js -> scope-hello-js (A1 sanitize as measured: add_custom_target
#                      rejects '@'-headed names, so the '@' is stripped) ->
#                      polyorch-node-web-scope-hello-js (fused)
#   hello-ts        -> hello-ts -> polyorch-node-web-hello-ts
polyorch_node_test(TARGET "scope-hello-js")     # no scripts.test -> loud STATUS skip
polyorch_node_test(TARGET "hello-ts")           # has scripts.test  -> registered
polyorch_node_run(TARGET "scope-hello-js" SCRIPT hello)

# Cross-package stepping: hello-ts imports hello-js via workspace:*; the
# runtime resolves the linked package to its REALPATH under
# packages/hello-js -- outside the row's default per-package glob. An
# explicit comma-separated OUTFILES REPLACES the defaults with both
# packages' dist globs plus the node_modules exclusion the defaults
# carried, so breakpoint prediction survives the hop. Never glob .map
# here (PIT-63).
polyorch_node_debug(TARGET "hello-ts"
    OUTFILES "${CMAKE_CURRENT_SOURCE_DIR}/packages/hello-ts/dist/**/*.js,${CMAKE_CURRENT_SOURCE_DIR}/packages/hello-js/dist/**/*.js,!${CMAKE_CURRENT_SOURCE_DIR}/packages/**/node_modules/**")

# FOLDER is set at the four helper creation sites (root sweep, D33) -- the
# example composes nothing.
