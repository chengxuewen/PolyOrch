# expect-log collides with the artifact base name
# expect-no-log Unknown CMake command
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")

# Self-test of the expect-log / expect-no-log marker mechanism (both drivers
# must agree): the child re-exec hits the PIT-13 collision guard (FATAL, rc
# non-zero -- proven as an error identity by t-rust-collision itself); the
# parent ECHOES the child's stderr to its own stdout and exits 0. The verdict
# therefore comes from the MARKERS alone: phrase present (expect-log) and
# "Unknown CMake command" absent (expect-no-log, proving the negative side is
# wired -- a misspelled command here would fail the case).
if(POLYORCH_CHILD)
    set(POLYORCH_RUST_FOUND  TRUE  CACHE INTERNAL "")
    set(POLYORCH_RUST_CARGO  "${CMAKE_COMMAND}" CACHE INTERNAL "")
    set(POLYORCH_RUST_HOST_TARGET "x86_64-unknown-linux-gnu" CACHE INTERNAL "")
    set(POLYORCH_RUST_ROUTE  "system" CACHE INTERNAL "")
    _polyorch_pixi_scratch(_s)
    file(WRITE "${_s}/Cargo.toml" [==[
[package]
name = "greet"
version = "0.1.0"
edition = "2021"

[workspace]
]==])
    polyorch_rust_build(TARGET greet PACKAGE greet CRATE greet BINARY
        MANIFEST "${_s}/Cargo.toml")
    message(FATAL_ERROR "expected the PIT-13 collision guard to fire")
endif()

execute_process(
    COMMAND "${CMAKE_COMMAND}" "-DPOLYORCH_CHILD=1" -P "${CMAKE_CURRENT_LIST_FILE}"
    ENVIRONMENT "POLYORCH_CHILD=1"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(_rc EQUAL 0)
    message(FATAL_ERROR "marker self-test: collision child unexpectedly exited 0")
endif()
message("${_err}")
message(STATUS "rust-build-args-msg: marker mechanism exercised (rc=${_rc})")
