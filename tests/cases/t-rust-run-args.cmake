# expect: fail
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")

# polyorch_rust_run executes the artifact of an existing imported target
# directly; an unknown TARGET is rejected (as is a call before setup).
polyorch_rust_run(TARGET does-not-exist)
message(FATAL_ERROR "expected polyorch_rust_run to reject an unknown TARGET")
