# expect: fail
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")

# polyorch_rust_run executes the artifact of an existing imported target
# directly; a call before setup is rejected by the shared guard (as is an
# unknown TARGET once setup has run). Parent asserts FAILURE BY ERROR
# IDENTITY; the measured today-text (locked 2026-09-21) is
#   polyorch_rust_run: call polyorch_rust_setup first (POLYORCH_RUST_FOUND is not TRUE; nothing is located yet)
if(POLYORCH_CHILD)
    polyorch_rust_run(TARGET does-not-exist)
    message(FATAL_ERROR "expected polyorch_rust_run to reject a call before setup")
endif()

ck_child_fail("polyorch_rust_run: call polyorch_rust_setup first")
# Trailing FATAL = the "# expect: fail" marker's contract payload (the parent
# must exit non-zero); ck_child_fail above is the real gate.
message(FATAL_ERROR "expected failure observed: polyorch_rust_run before setup")
