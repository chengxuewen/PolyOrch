# expect: fail
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")

# polyorch_rust_build consumes the polyorch_rust_setup results; calling it
# before setup must fail. The parent re-execs this file as a child
# (POLYORCH_CHILD) so the FATAL does not abort the assertions, and pins the
# FAILURE BY ERROR IDENTITY: the measured today-text (locked 2026-09-21) is
#   polyorch_rust_build: call polyorch_rust_setup first (POLYORCH_RUST_FOUND is not TRUE; nothing is located yet)
if(POLYORCH_CHILD)
    polyorch_rust_build(TARGET greet-bin PACKAGE greet CRATE greet BINARY
        MANIFEST "${CMAKE_CURRENT_LIST_DIR}/no-such-Cargo.toml")
    message(FATAL_ERROR "expected polyorch_rust_build to require polyorch_rust_setup")
endif()

ck_child_fail("polyorch_rust_build: call polyorch_rust_setup first")
# The "# expect: fail" marker (single verdict source in both drivers) still
# requires the PARENT to exit non-zero. The identity assertion above is the
# real gate; this trailing FATAL is only the marker's contract payload - if
# ck_child_fail had not seen the exact FATAL, the parent would already have
# died inside it with the child's full output in the message.
message(FATAL_ERROR "expected failure observed: polyorch_rust_build before setup")
