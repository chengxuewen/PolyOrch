# examples/node-basic -- the source-level js-debug carrier (node face, D33)
#
# The debug-plane counterpart of node-web: node-web's hello-ts shows the
# BUILT-entry shape (main -> dist, breakpoints map through source maps);
# this example declares main -> src/index.js, so the generated launch
# `program` resolves to the real source file and js-debug binds
# breakpoints in it directly -- plain JS needs no source maps. Like every
# node debug row it carries a preLaunchTask; here that rebuilds the stub
# `node-basic-build` mediator (an offline npm install of the file: dep
# plus an echo) -- the no-maps story is unchanged.
# Single-package registration (polyorch_node_build + polyorch_node_debug);
# the workspace machinery is node-web's subject, not repeated here.
#
# Entry points:
#   standalone:  cmake -S examples/node-basic -B build
#   fused:       part of the examples umbrella (PolyOrch_BUILD_NODE_EXAMPLES=ON
#                runs this loop; targets carry the polyorch-node-basic- prefix)
#   run:         node src/index.js  (prints "node-basic total=15", exits 0)
#   debug:       cmake -S examples/node-basic -B build
#                    -DPolyOrch_NODE_VSCODE_DEBUG=ON
#                    -DPolyOrch_VSCODE_DIR=build/.vscode
#                then open the generated launch config and F5 on
#                "PolyOrch: node-basic" -- parking the output via
#                PolyOrch_VSCODE_DIR keeps it out of the source tree;
#                with a workspace root elsewhere, park it there instead.

cmake_minimum_required(VERSION 3.22)
project(node-basic LANGUAGES NONE)

# D33 opt-in (before the include: the tail hook reads the gate at include
# time). This example IS the debug carrier, so it opts in unconditionally
# (the same in-file opt-in node-web carries; the library default stays OFF).
set(PolyOrch_NODE_VSCODE_DEBUG ON)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
include(PolyOrchNodeHelpers)

# standalone REQUIRED (the node-web idiom: the user running this example
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

polyorch_node_build(TARGET node-basic
    MANIFEST "${CMAKE_CURRENT_LIST_DIR}/package.json")

# main -> src/index.js resolves the launch program to the SOURCE entry:
# the F5 story above breaks inside src/index.js, not a generated dist file.
polyorch_node_debug(TARGET node-basic)
