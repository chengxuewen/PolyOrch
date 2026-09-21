# expect: fail
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")

# LOCKED and FROZEN are mutually exclusive: rejected at entry.
_polyorch_rust_cargo_args(PACKAGE greet LOCKED FROZEN ARGO_OUT a)
message(FATAL_ERROR "expected rejection of LOCKED+FROZEN together")
