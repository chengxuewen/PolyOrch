include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")

# Re-executed as a child so the expected FATAL_ERROR does not abort the parent
# (an in-process FATAL would end the script before any assertion could run).
if(POLYORCH_TEST_RUST_NAMES_CHILD)
    _polyorch_rust_artifact_names(TRIPLE bogus-triple KIND bin CRATE greet FILE_OUT _f)
    message(FATAL_ERROR "expected rejection of unrecognized triple 'bogus-triple'")
endif()

# Naming table across the three families (unix / windows-msvc / windows-gnu).
# unix: bare bin, lib-prefixed .a/.so
_polyorch_rust_artifact_names(TRIPLE x86_64-unknown-linux-gnu KIND bin CRATE greet FILE_OUT f)
ck_str("${f}" "greet")
_polyorch_rust_artifact_names(TRIPLE x86_64-unknown-linux-gnu KIND static CRATE greet FILE_OUT f)
ck_str("${f}" "libgreet.a")
_polyorch_rust_artifact_names(TRIPLE x86_64-unknown-linux-gnu KIND shared CRATE greet
    FILE_OUT f DIR_OUT d)
ck_str("${f}" "libgreet.so")
# darwin shared
_polyorch_rust_artifact_names(TRIPLE aarch64-apple-darwin KIND shared CRATE greet FILE_OUT f)
ck_str("${f}" "libgreet.dylib")
# windows-msvc: .exe bin, greet.lib static, greet.dll shared + <crate>.dll.lib implib
_polyorch_rust_artifact_names(TRIPLE x86_64-pc-windows-msvc KIND bin CRATE greet FILE_OUT f)
ck_str("${f}" "greet.exe")
_polyorch_rust_artifact_names(TRIPLE x86_64-pc-windows-msvc KIND static CRATE greet FILE_OUT f)
ck_str("${f}" "greet.lib")
_polyorch_rust_artifact_names(TRIPLE x86_64-pc-windows-msvc KIND shared CRATE greet
    FILE_OUT f IMPLIB_OUT i)
ck_str("${f}" "greet.dll")
ck_str("${i}" "greet.dll.lib")
# windows-gnu: .a static, greet.dll shared + libgreet.dll.a implib
_polyorch_rust_artifact_names(TRIPLE x86_64-pc-windows-gnu KIND static CRATE greet FILE_OUT f)
ck_str("${f}" "libgreet.a")
_polyorch_rust_artifact_names(TRIPLE x86_64-pc-windows-gnu KIND shared CRATE greet
    FILE_OUT f IMPLIB_OUT i)
ck_str("${f}" "greet.dll")
ck_str("${i}" "libgreet.dll.a")

# Directory contract (lead ruling): DIR_OUT is the ABSOLUTE <base>/<profile>,
# base = BASE_DIR else ${CMAKE_BINARY_DIR}/.cargo-target; OUT_BASE_DIR receives
# the base. Pass BASE_DIR so the assertion is independent of CMAKE_BINARY_DIR.
_polyorch_rust_artifact_names(TRIPLE x86_64-unknown-linux-gnu KIND bin CRATE greet
    BASE_DIR /p/td PROFILE release FILE_OUT f DIR_OUT d OUT_BASE_DIR b)
ck_str("${f}" "greet")
ck_str("${d}" "/p/td/release")
ck_str("${b}" "/p/td")

# Unrecognized triple (neither a known unix family nor windows-*): rejected.
execute_process(COMMAND "${CMAKE_COMMAND}" "-DPOLYORCH_TEST_RUST_NAMES_CHILD=1"
    -P "${CMAKE_CURRENT_LIST_FILE}" RESULT_VARIABLE _rc)
ck_fail_rc(_rc)

message(STATUS "rust-artifact-names: OK")
