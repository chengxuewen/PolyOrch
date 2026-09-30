# tests/fixtures/node-ws -- fixture for cases/t-rust-node.cmake (D29).
# The npm bridge's contract surface: a two-member workspace with a
# workspace:* dependency edge and an '@scope' name (A1 sanitize). The build
# scripts are zero-dependency node scripts -- the orchestrated surface is
# the package manager's workspace machinery, not a compiler (adjudication 4).
cmake_minimum_required(VERSION 3.25)
project(polyorch-fixture-node-ws LANGUAGES NONE)

get_filename_component(_polyorch_cmake_dir
    "${CMAKE_CURRENT_SOURCE_DIR}/../../../cmake" ABSOLUTE)
list(APPEND CMAKE_MODULE_PATH "${_polyorch_cmake_dir}")
include(PolyOrchNodeHelpers)

# REQUIRED here: the case probe passed, the child must honor it (the
# driver's PATH composition is the contract the probe mirrors).
polyorch_node_setup(REQUIRED)

# fixture artifact contract BEFORE any early return (PIT-34).
# The manifest is the configure-time artifact; the dist products are
# asserted by the case's build leg (the mediators are custom targets, not
# in ALL -- the driver's build cannot have produced them yet; the case
# builds hello-ui-build explicitly and EXISTS-checks both dist trees).
set(POLYORCH_FIXTURE_ARTIFACTS
    "manifest=${CMAKE_CURRENT_SOURCE_DIR}/package.json")
string(JOIN "\n" _af ${POLYORCH_FIXTURE_ARTIFACTS})
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/polyorch-fixture-artifacts.txt" "${_af}\n")

polyorch_node_import(ROOT "${CMAKE_CURRENT_SOURCE_DIR}/package.json")

# family verbs: one test gate (loud absence) + the FOLDER-less standalone shape
polyorch_node_test(TARGET "scope-hello-ui")   # no scripts.test -> loud STATUS skip
polyorch_node_test(TARGET "hello-js")         # none here either -> skip line in log
