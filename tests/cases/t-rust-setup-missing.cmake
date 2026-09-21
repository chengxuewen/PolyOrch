include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")

# Child leg: REQUIRED setup must hard-fail when no system cargo exists.
if(POLYORCH_TEST_RUST_MISSING_CHILD)
    polyorch_rust_setup(FROM system REQUIRED)
    message(FATAL_ERROR "expected REQUIRED setup to fail without a system cargo")
endif()

# Contract: a missing toolchain without REQUIRED is a soft miss --
# POLYORCH_RUST_FOUND=FALSE and no FATAL_ERROR. Only meaningful where the
# system PATH truly has no cargo (this project's validation host); elsewhere
# the case skips rather than false-fails.
find_program(_cargo NAMES cargo)
if(_cargo)
    message(STATUS "rust-setup-missing: SKIP (system cargo found: ${_cargo})")
    return()
endif()

polyorch_rust_setup()
ck_str("${POLYORCH_RUST_FOUND}" "FALSE")

execute_process(COMMAND "${CMAKE_COMMAND}" "-DPOLYORCH_TEST_RUST_MISSING_CHILD=1"
    -P "${CMAKE_CURRENT_LIST_FILE}" RESULT_VARIABLE _rc)
ck_fail_rc(_rc)

message(STATUS "rust-setup-missing: OK")
