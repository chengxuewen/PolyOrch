# expect: fail
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")

# FROM has a closed value domain (system|pixi); anything else is rejected
# before any locate work.
polyorch_rust_setup(FROM bogus)
message(FATAL_ERROR "expected rejection of FROM bogus")
