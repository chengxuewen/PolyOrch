# expect: fail
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")

# FROM has a closed value domain (system|pixi); anything else is rejected
# before any locate work. Parent asserts FAILURE BY ERROR IDENTITY; the
# measured today-text (locked 2026-09-21) is
#   polyorch_rust_setup: FROM must be system or pixi, got 'bogus'
if(POLYORCH_CHILD)
    polyorch_rust_setup(FROM bogus)
    message(FATAL_ERROR "expected rejection of FROM bogus")
endif()

ck_child_fail("FROM must be system or pixi, got 'bogus'")
# Trailing FATAL = the "# expect: fail" marker's contract payload (the parent
# must exit non-zero); ck_child_fail above is the real gate.
message(FATAL_ERROR "expected failure observed: polyorch_rust_setup FROM bogus")
