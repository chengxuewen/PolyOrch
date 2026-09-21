include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")

# _polyorch_rust_cargo_args: pure argv construction for `cargo build`.
# Containment/absence helpers (case-local; _inc.cmake stays untouched).
macro(_has lst v)
    list(FIND ${lst} "${v}" _pos)
    if(_pos EQUAL -1)
        message(FATAL_ERROR "expected element [${v}] in ${${lst}} (line ${CMAKE_CURRENT_LIST_LINE})")
    endif()
endmacro()
macro(_no lst v)
    list(FIND ${lst} "${v}" _pos)
    if(NOT _pos EQUAL -1)
        message(FATAL_ERROR "unexpected element [${v}] in ${${lst}} (line ${CMAKE_CURRENT_LIST_LINE})")
    endif()
endmacro()
macro(_after lst flag val)
    list(FIND ${lst} "${flag}" _i)
    if(_i LESS 0)
        message(FATAL_ERROR "expected flag [${flag}] in ${${lst}} (line ${CMAKE_CURRENT_LIST_LINE})")
    endif()
    math(EXPR _j "${_i}+1")
    list(GET ${lst} ${_j} _n)
    ck(_n STREQUAL "${val}")
endmacro()

# release profile: --release present, --profile absent; lead token is `build`.
_polyorch_rust_cargo_args(PACKAGE greet KIND bin CRATE greet PROFILE release
    MANIFEST /x/Cargo.toml ARGO_OUT a)
list(GET a 0 _lead)
ck_str("${_lead}" "build")
_has(a "--release")
_no(a "--profile")
_after(a "--package" "greet")
_after(a "--manifest-path" "/x/Cargo.toml")
_after(a "--bin" "greet")

# custom profile: --profile <name> present, --release absent.
_polyorch_rust_cargo_args(PACKAGE greet KIND bin CRATE greet PROFILE dev ARGO_OUT a)
_has(a "--profile")
_no(a "--release")
_after(a "--profile" "dev")

# default (debug) profile: neither flag.
_polyorch_rust_cargo_args(PACKAGE greet KIND bin CRATE greet ARGO_OUT a)
_no(a "--release")
_no(a "--profile")

# features: semicolon list becomes one comma-joined argument.
_polyorch_rust_cargo_args(PACKAGE greet KIND bin CRATE greet FEATURES a;b ARGO_OUT a)
_after(a "--features" "a,b")
_no(a "a")
_no(a "b")

# lib kinds carry no --bin selector; bin kind does.
_polyorch_rust_cargo_args(PACKAGE greet KIND static CRATE greet ARGO_OUT a)
_no(a "--bin")
_polyorch_rust_cargo_args(PACKAGE greet KIND shared CRATE greet ARGO_OUT a)
_no(a "--bin")

# lock modes pass through as flags; MANIFEST is optional (absent -> no flag).
_polyorch_rust_cargo_args(PACKAGE greet LOCKED ARGO_OUT a)
_has(a "--locked")
_no(a "--frozen")
_no(a "--manifest-path")
_polyorch_rust_cargo_args(PACKAGE greet FROZEN ARGO_OUT a)
_has(a "--frozen")

message(STATUS "rust-cargo-args: OK")
