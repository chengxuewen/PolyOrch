include("/cmake/PolyOrchRustHelpers.cmake")
polyorch_rust_build(TARGET t PACKAGE p CRATE c SHARED EXAMPLE)
message(STATUS "NO-GUARD-FIRE")
