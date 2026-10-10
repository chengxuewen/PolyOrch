# examples/node-ts-basic -- the TS debug carrier (node face, D37)
#
# The built-entry counterpart of node-basic: node-basic declares
# main -> src/index.js so js-debug binds the source directly; this example
# declares main -> dist/index.js, tsc emits the source map beside it, and
# the generated launch row carries `sourceMaps` + a `preLaunchTask` that
# runs this package's build mediator -- F5 = build first, then debug with
# breakpoints landing back in src/index.ts through the map.
# Single-package registration (polyorch_node_build + polyorch_node_debug);
# the workspace machinery stays node-web's subject.
#
# Prerequisite (human-side, like cargo for the rust examples): `tsc` must
# be reachable on PATH (e.g. `pixi global install typescript`); the probe
# below checks PATH, ~/.pixi/bin, then pixi-env globs and degrades with a
# STATUS note. The build mediator is the plain `PM run build` -- the
# package manager child resolves tsc from its own PATH.
#
# Entry points:
#   standalone:  cmake -S examples/node-ts-basic -B build
#   fused:       part of the examples umbrella (PolyOrch_BUILD_NODE_EXAMPLES=ON
#                runs this loop; targets carry the polyorch-node-ts-basic- prefix)
#   run:         node dist/index.js  (after the build; prints "node-ts-basic total=15")
#   debug:       cmake -S examples/node-ts-basic -B build
#                    -DPolyOrch_VSCODE_DIR=build/.vscode
#                then open the generated launch config and F5 on
#                "PolyOrch: node-ts-basic" -- the preLaunchTask rebuilds
#                dist through `node-ts-basic-build`, parking the output via
#                PolyOrch_VSCODE_DIR keeps it out of the source tree;
#                with a workspace root elsewhere, park it there instead.

cmake_minimum_required(VERSION 3.22)
project(node-ts-basic LANGUAGES NONE)

# D37 opt-in (before the include: the tail hook reads the gate at include
# time). This example IS the TS debug carrier, so it opts in unconditionally
# (the same in-file opt-in node-basic carries; the library default stays OFF).
set(PolyOrch_NODE_VSCODE_DEBUG ON)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
include(PolyOrchNodeHelpers)

# fixture artifact contract BEFORE every early return (PIT-34 discipline):
# the tsc probe below can return() early, so the file is written first.
set(POLYORCH_FIXTURE_ARTIFACTS
    "manifest=${CMAKE_CURRENT_LIST_DIR}/package.json")
string(JOIN "\n" _af ${POLYORCH_FIXTURE_ARTIFACTS})
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/polyorch-fixture-artifacts.txt" "${_af}\n")

# tsc: the example's own prereq (rust-wasm doctrine: three-tier PATH
# discovery, STATUS-degraded when absent -- the library ships the
# mechanism, not the tool).
find_program(PolyOrchTsCompiler tsc)
if(NOT PolyOrchTsCompiler)
    find_program(PolyOrchTsCompiler tsc PATHS "$ENV{HOME}/.pixi/bin")
endif()
if(NOT PolyOrchTsCompiler)
    file(GLOB _tsenv "$ENV{HOME}/.pixi/envs/*/bin/tsc")
    list(LENGTH _tsenv _tsn)
    if(_tsn GREATER 0)
        list(GET _tsenv 0 PolyOrchTsCompiler)
    endif()
endif()
if(NOT PolyOrchTsCompiler)
    message(STATUS "node-ts-basic: not registered -- no tsc on PATH/pixi "
                   "(pixi global install typescript)")
    return()
endif()

# standalone REQUIRED (the node-basic idiom: the user running this example
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

# tsc may live in a different dir than node (not guaranteed co-located);
# declare its dir so the build mediator carries it (PATH self-sufficiency,
# D37 user-found fix). The library always prepends the node+PM dirs itself.
get_filename_component(_tsbin "${PolyOrchTsCompiler}" DIRECTORY)
set(PolyOrchNode_BUILD_ENV_PATH "${_tsbin}")
polyorch_node_build(TARGET node-ts-basic
    MANIFEST "${CMAKE_CURRENT_LIST_DIR}/package.json")

# main -> dist/index.js resolves the launch program to the BUILT entry;
# the row's sourceMaps + outFiles glob fold breakpoints back into src/.
polyorch_node_debug(TARGET node-ts-basic)
