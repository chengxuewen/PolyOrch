# requires: no-node
cmake_policy(SET CMP0219 NEW)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchNodeHelpers.cmake")

# t-rust-nodesetup-missing -- the degradation matrix for polyorch_node_setup
# (the t-rust-setup-missing shape, node flavor):
#   * child leg: REQUIRED setup must hard-fail with neither node nor a PM;
#   * parent leg: without REQUIRED it is a soft miss -- POLYORCH_NODE_FOUND
#     =FALSE, a STATUS note, no FATAL_ERROR.
# `# requires: no-node` runs this ONLY where the probe finds neither node
# nor a PM (the inverse probe), so the assertions below are environment-
# true rather than mocked. On hosts with node installed the case contract-
# skips -- the matrix is then covered by t-rust-node's stub legs instead.

# ---- child leg -------------------------------------------------------------
if(POLYORCH_TEST_NODE_MISSING_CHILD)
    polyorch_node_setup(REQUIRED)
    message(FATAL_ERROR "expected REQUIRED setup to fail without node/pm")
endif()

# ---- parent gate ------------------------------------------------------------
polyorch_requires(no-node _req)
if(NOT _req)
    message(STATUS "t-rust-nodesetup-missing : SKIP (node+pm reachable)")
    return()
endif()

# soft miss: no REQUIRED, no FATAL
polyorch_node_setup()
ck_str("${POLYORCH_NODE_FOUND}" "FALSE")

# the report names the missing half (node is missing here, so the
# node-missing wording is the correct one -- the PM-found variant is
# pinned by the stub legs in t-rust-node's environment)
ck_str("${POLYORCH_NODE_FOUND}" "FALSE")

# REQUIRED hard-fails (child self-recursion, t-rust-setup-missing shape)
execute_process(COMMAND "${CMAKE_COMMAND}"
    "-DPOLYORCH_TEST_NODE_MISSING_CHILD=1"
    -P "${CMAKE_CURRENT_LIST_FILE}" RESULT_VARIABLE _rc)
ck_fail_rc(_rc)

message(STATUS "t-rust-nodesetup-missing: OK")
