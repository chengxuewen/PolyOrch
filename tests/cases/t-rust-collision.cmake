# expect: fail
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")

# PIT-13 regression net: polyorch_rust_build must REFUSE a TARGET whose name
# equals the artifact base name -- an IMPORTED target named like its output
# file makes the Makefile generator silently swallow the producing rule.
# The setup result variables are injected directly (the guard reads variables,
# so no toolchain is needed; same injection style as t-rust-run-args uses for
# -D). Host triple pinned to the linux-gnu family so the bin artifact base
# name is exactly the crate name. Measured today-text (locked 2026-09-21):
#   polyorch_rust_build: TARGET 'greet' collides with the artifact base name 'greet' -- an IMPORTED target named like its output file makes the Makefile generator silently swallow the producing rule (PIT-13). Give the CMake TARGET a different name.
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

ck_child_fail("collides with the artifact base name")
# Trailing FATAL = the "# expect: fail" marker's contract payload (the parent
# must exit non-zero); ck_child_fail above is the real gate.
message(FATAL_ERROR "expected failure observed: PIT-13 collision guard")
