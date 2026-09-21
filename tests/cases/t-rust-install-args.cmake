# expect: fail
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")

# polyorch_rust_install argument validation, locked by error identity. The
# child branch is selected through the POLYORCH_INSTALL_CASE environment
# variable (inherited by the ck_child_fail re-exec) so one case file pins
# two distinct FATALs. Script mode cannot create targets at all (measured
# on 4.4.3: "add_library command is not scriptable"), so both pins are
# validation errors raised BEFORE any target walk:
#   unknown   -- a handle that was never declared
#   notargets -- TARGETS absent entirely
# The "not a PolyOrch rust import" branch needs an EXISTING target, which no
# script-mode process can have; it is exercised by t-rust-install-e2e's child
# side instead of a third offline pin.
if(POLYORCH_CHILD)
    if("$ENV{POLYORCH_INSTALL_CASE}" STREQUAL "notargets")
        polyorch_rust_install(EXPORT demo)
        message(FATAL_ERROR "expected rejection of an empty TARGETS list")
    else()
        polyorch_rust_install(TARGETS ghost-handle EXPORT demo)
        message(FATAL_ERROR "expected rejection of the unknown handle 'ghost-handle'")
    endif()
endif()

set(ENV{POLYORCH_INSTALL_CASE} unknown)
ck_child_fail("polyorch_rust_install: no target 'ghost-handle'")
set(ENV{POLYORCH_INSTALL_CASE} notargets)
ck_child_fail("missing required argument 'A_TARGETS'")

# Trailing FATAL = the "# expect: fail" marker's contract payload (the parent
# must exit non-zero); the ck_child_fail pins above are the real gate.
message(FATAL_ERROR "expected failure observed: polyorch_rust_install arg validation")
