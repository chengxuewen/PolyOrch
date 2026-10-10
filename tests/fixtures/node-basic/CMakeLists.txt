# tests/fixtures/node-basic -- source-entry js-debug registration fixture
# (the node-debug fixture's twin: identical chain, but main -> src/index.js
# instead of dist, proving the launch program resolves to the SOURCE file).
# Zero dependencies: src/index.js is CHECKED IN, so the configure registers
# the row without any build executing. The PM is never invoked by these
# cases (the -build mediator exists but is not built) -- the fixture honors
# `# requires: node` because setup(REQUIRED) demands the toolchain at
# configure time.
cmake_minimum_required(VERSION 3.25)
project(polyorch-fixture-node-basic LANGUAGES NONE)

get_filename_component(_polyorch_cmake_dir
    "${CMAKE_CURRENT_SOURCE_DIR}/../../../cmake" ABSOLUTE)
list(APPEND CMAKE_MODULE_PATH "${_polyorch_cmake_dir}")
include(PolyOrchNodeHelpers)

# REQUIRED: the case's probe passed, the child must honor it (node-ws shape).
polyorch_node_setup(REQUIRED)

# fixture artifact contract BEFORE any early return (PIT-34).
set(POLYORCH_FIXTURE_ARTIFACTS
    "manifest=${CMAKE_CURRENT_SOURCE_DIR}/package.json")
string(JOIN "\n" _af ${POLYORCH_FIXTURE_ARTIFACTS})
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/polyorch-fixture-artifacts.txt" "${_af}\n")

# standalone single-package registration (build() stores the GLOBAL
# MANIFEST/DIR properties the debug verb reads -- the import loop's twin).
polyorch_node_build(TARGET node-basic
    MANIFEST "${CMAKE_CURRENT_SOURCE_DIR}/package.json")

# gate-first: no-op unless -DPolyOrch_NODE_VSCODE_DEBUG=ON is passed; both
# polarities ride this same fixture (t-node-basic configures it twice).
polyorch_node_debug(TARGET node-basic)
