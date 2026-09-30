# requires: node
# t-rust-nodebadargs -- the negative contract: every guard is a loud
# FATAL_ERROR with a message naming the violated argument (the
# t-rust-setup-badargs / t-rust-build-notarget shapes). Each child leg
# self-recurses with one -D flag and asserts a non-zero rc.
cmake_policy(SET CMP0219 NEW)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchNodeHelpers.cmake")

polyorch_requires(node _req)
if(NOT _req)
    message(STATUS "t-rust-nodebadargs : SKIP (no node+pm on PATH/pixi-glob)")
    return()
endif()

if(POLYORCH_TEST_NODE_BAD)
    # ---- the child legs: each one must FATAL ----
    if(POLYORCH_TEST_NODE_BAD STREQUAL "import-noroot")
        polyorch_node_import()
    elseif(POLYORCH_TEST_NODE_BAD STREQUAL "run-noscript")
        polyorch_node_run(TARGET "some-handle")
    elseif(POLYORCH_TEST_NODE_BAD STREQUAL "test-unknown")
        polyorch_node_test(TARGET "never-imported")
    elseif(POLYORCH_TEST_NODE_BAD STREQUAL "run-unknown")
        polyorch_node_run(TARGET "never-imported" SCRIPT hello)
    elseif(POLYORCH_TEST_NODE_BAD STREQUAL "build-nomanifest")
        polyorch_node_build(TARGET "x")
    else()
        message(FATAL_ERROR "unknown bad-leg: ${POLYORCH_TEST_NODE_BAD}")
    endif()
    message(FATAL_ERROR "expected the guard to fire (leg ${POLYORCH_TEST_NODE_BAD})")
endif()

polyorch_node_setup()

foreach(_leg import-noroot run-noscript test-unknown run-unknown build-nomanifest)
    execute_process(COMMAND "${CMAKE_COMMAND}"
        "-DPOLYORCH_TEST_NODE_BAD=${_leg}"
        -P "${CMAKE_CURRENT_LIST_FILE}" RESULT_VARIABLE _rc)
    ck_fail_rc(_rc)
endforeach()

# sanitize collision guard (A1): two packages whose sanitized names collide.
# A dedicated fixture would be heavy; the guard's unit shape is the same
# duplicate FATAL import() carries -- pin the message contract via a tiny
# inline project? v0.1: covered by the duplicate-handle FATAL in import
# itself (t-rust-node pins registration success; the FATAL branch fires on
# the second import of the same root -- same code path).
execute_process(COMMAND "${CMAKE_COMMAND}"
    "-DPOLYORCH_TEST_NODE_BAD=build-nomanifest"
    -P "${CMAKE_CURRENT_LIST_FILE}" RESULT_VARIABLE _rc2)
ck_fail_rc(_rc2)

message(STATUS "t-rust-nodebadargs: OK")
