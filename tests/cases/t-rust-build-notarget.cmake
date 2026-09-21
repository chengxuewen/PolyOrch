# expect: fail
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")

# TARGET is mandatory (it names the IMPORTED target and the -cargo mediator).
polyorch_rust_build(PACKAGE greet CRATE greet BINARY)
message(FATAL_ERROR "expected polyorch_rust_build to require TARGET")
