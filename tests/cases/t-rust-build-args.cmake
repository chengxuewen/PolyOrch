# expect: fail
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")

# polyorch_rust_build consumes the polyorch_rust_setup results; calling it
# before setup must fail with "call polyorch_rust_setup first".
polyorch_rust_build(TARGET greet-bin PACKAGE greet CRATE greet BINARY
    MANIFEST "${CMAKE_CURRENT_LIST_DIR}/no-such-Cargo.toml")
message(FATAL_ERROR "expected polyorch_rust_build to require polyorch_rust_setup")
