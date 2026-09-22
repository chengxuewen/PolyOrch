include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")

# Table-driven LOCK of _polyorch_rust_artifact_names current behavior (pure
# offline, no markers): full DIR_OUT / FILE_OUT / IMPLIB strings per triple
# family x kind x profile, including the ${CMAKE_BINARY_DIR}/.cargo-target/
# <profile> default-anchor contract. Measured against the module 2026-09-21;
# Task 2's argv-lazy refactor must keep this table green (no-regression lock).
# t_ckpt <triple> <kind> <profile-or-EMPTY> <expect-file> <expect-dir-base> <expect-implib>
macro(t_ckpt tr kl pf ef ed ei)
    set(_pf "")
    if(NOT "${pf}" STREQUAL "EMPTY")
        set(_pf PROFILE "${pf}")
    endif()
    _polyorch_rust_artifact_names(TRIPLE "${tr}" KIND "${kl}" CRATE greet
        ${_pf} BASE_DIR /p/td FILE_OUT _f DIR_OUT _d IMPLIB_OUT _i)
    unset(_pf)
    ck_str("${_f}" "${ef}")
    ck_str("${_d}" "${ed}")
    ck_str("${_i}" "${ei}")
endmacro()

# --- elf family (linux-android-bsd style): bare bin, lib-prefixed .a/.so ----
t_ckpt(x86_64-unknown-linux-gnu bin    EMPTY   greet     /p/td/debug   "")
t_ckpt(x86_64-unknown-linux-gnu bin    debug   greet     /p/td/debug   "")
t_ckpt(x86_64-unknown-linux-gnu bin    release greet     /p/td/release "")
# WP9: cargo's built-in `dev` profile writes to debug/ -- name != dir
t_ckpt(x86_64-unknown-linux-gnu bin    dev     greet     /p/td/debug   "")
t_ckpt(x86_64-unknown-linux-gnu static dev     libgreet.a /p/td/debug   "")
t_ckpt(x86_64-unknown-linux-gnu bin    prof-x  greet     /p/td/prof-x  "")
t_ckpt(x86_64-unknown-linux-gnu static EMPTY   libgreet.a  /p/td/debug   "")
t_ckpt(x86_64-unknown-linux-gnu static release libgreet.a  /p/td/release "")
t_ckpt(x86_64-unknown-linux-gnu shared release libgreet.so /p/td/release "")
# --- macho family (apple/darwin) ---------------------------------------------
t_ckpt(aarch64-apple-darwin bin    prof-x  greet       /p/td/prof-x  "")
t_ckpt(aarch64-apple-darwin static release libgreet.a  /p/td/release "")
t_ckpt(aarch64-apple-darwin shared EMPTY   libgreet.dylib /p/td/debug "")
# --- msvc family: no lib prefix, .exe/.lib/.dll, implib <crate>.dll.lib -----
t_ckpt(x86_64-pc-windows-msvc bin    EMPTY   greet.exe    /p/td/debug   "")
t_ckpt(x86_64-pc-windows-msvc bin    release greet.exe    /p/td/release "")
t_ckpt(x86_64-pc-windows-msvc static release greet.lib    /p/td/release "")
t_ckpt(x86_64-pc-windows-msvc shared prof-x  greet.dll    /p/td/prof-x  greet.dll.lib)
# --- windows-gnu implib row: lib-prefixed .a/.dll.a --------------------------
t_ckpt(x86_64-pc-windows-gnu bin    EMPTY   greet.exe    /p/td/debug   "")
t_ckpt(x86_64-pc-windows-gnu static release libgreet.a   /p/td/release "")
t_ckpt(x86_64-pc-windows-gnu shared EMPTY   greet.dll    /p/td/debug   libgreet.dll.a)

# --- default anchor contract: no BASE_DIR -> ${CMAKE_BINARY_DIR}/.cargo-target
# In `cmake -P` CMAKE_BINARY_DIR is the invocation cwd (measured 4.4.3) --
# assert the CONTRACT (suffix + OUT_BASE_DIR agreement), not the absolute cwd.
_polyorch_rust_artifact_names(TRIPLE x86_64-unknown-linux-gnu KIND bin CRATE greet
    PROFILE release FILE_OUT _f DIR_OUT _d OUT_BASE_DIR _b)
ck_str("${_d}" "${CMAKE_BINARY_DIR}/.cargo-target/release")
ck_str("${_b}" "${CMAKE_BINARY_DIR}/.cargo-target")
ck(_d MATCHES "^${CMAKE_BINARY_DIR}/[.]cargo-target/[a-z-]+$")

message(STATUS "rust-artifact-paths: OK (behavior locked)")
