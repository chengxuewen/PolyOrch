# e2e: required
# requires: pixi-rust
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")

# The systemic PIT-13 net: the collision guard only protects against a name
# the USER picks; the class of bug is "the producing rule silently vanished in
# the real build system". This case proves the rule SURVIVES generation: it
# configures + builds examples/rust-basic standalone (its configure
# self-bootstraps the pixi rust env -- offline once cached; cargo artifacts
# land in the scratch BINARY dir, the source tree keeps only its gitignored
# .pixi/ store, measured) and asserts the contract-anchored artifact
# ${CMAKE_BINARY_DIR}/.cargo-target/debug/<bin> exists and is non-empty.
#
# SKIP lever measurement (2026-09-21, cmake 4.4.3): forcing
# -DPolyOrch_PIXI_EXECUTABLE=/nonexistent does NOT yield a graceful skip --
# the value is honored as cache and polyorch_pixi_find then HARD-FATALs on
# the failed version probe ("pixi at /nonexistent/pixi does not run"), it
# does not re-search and come back empty. The working lever is the requires
# gate below: probe the capability (polyorch_requires, filesystem only --
# no solve) IN THE PARENT and return() before ever spawning the child.

polyorch_requires(pixi-rust _req)
if(NOT _req)
    message(STATUS "t-rust-rule-wiring : SKIP (no pixi env materialized with a cargo)")
    return()
endif()

# examples/rust-basic's pixi workspace declares these platforms only.
if(NOT CMAKE_HOST_SYSTEM_NAME MATCHES "^(Linux|Darwin|Windows)$")
    message(STATUS "t-rust-rule-wiring : SKIP (no pixi platform for ${CMAKE_HOST_SYSTEM_NAME})")
    return()
endif()

_polyorch_pixi_scratch(_s)
set(_src "${CMAKE_CURRENT_LIST_DIR}/../../examples/rust-basic")
set(_b "${_s}/b")

execute_process(COMMAND "${CMAKE_COMMAND}" -S "${_src}" -B "${_b}"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "rust-rule-wiring: child configure failed (${_rc})\n${_out}${_err}")
endif()

# The mediator target, not the IMPORTED handle -- building "greet" itself is
# exactly the silently-no-op case PIT-13 describes.
execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_b}" --target greet-cargo
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "rust-rule-wiring: child build failed (${_rc})\n${_out}${_err}")
endif()

# Contract anchor + naming table agreement: the file the pure table promises
# is the file the real generator produced.
_polyorch_rust_artifact_names(TRIPLE x86_64-unknown-linux-gnu KIND bin
    CRATE greet-cli PROFILE debug FILE_OUT _f)
if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Darwin")
    set(_tri aarch64-apple-darwin)
    if(CMAKE_HOST_SYSTEM_PROCESSOR STREQUAL "x86_64")
        set(_tri x86_64-apple-darwin)
    endif()
    _polyorch_rust_artifact_names(TRIPLE ${_tri} KIND bin
        CRATE greet-cli PROFILE debug FILE_OUT _f)
elseif(CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
    _polyorch_rust_artifact_names(TRIPLE x86_64-pc-windows-msvc KIND bin
        CRATE greet-cli PROFILE debug FILE_OUT _f)
endif()
set(_art "${_b}/.cargo-target/debug/${_f}")
ck_file("${_art}")
file(SIZE "${_art}" _len)
ck(_len GREATER 0)

message(STATUS "rust-rule-wiring: OK (producing rule survived generation: ${_art}, ${_len} bytes)")
