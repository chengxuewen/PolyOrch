# e2e: required
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")

# Task 6 acceptance (P-4 install-consumer chain): polyorch_rust_install
# stages a REAL cargo-built staticlib + bin, the EXPORT replay stub is
# included by a SECOND, unrelated C project, and that consumer links + runs
# through the stub's re-attached interface. The negative leg strips the
# INTERFACE_LINK lines from a stub copy and the SAME consumer must then FAIL
# to link with an undefined `pow` -- proof that what the positive leg
# exercises is what the stub ships (the crate passes the exponent base as an
# argument so rustc can never const-fold the pow call away).
#
# Workspace (mirrors t-rust-import-ws): dash-ed staticlib (calls libm pow),
# say-hi bin, hookme staticlib. The hook leg is a direct polyorch_rust_build
# with [PREBUILD prebuild-stamp]: after building the aggregate the stamp file
# must exist -- nothing else produces it, so the ordering edge is the proof.
# Needs pixi + a host C compiler; skips cleanly without pixi.

polyorch_pixi_find(QUIET)
if(NOT PolyOrch_PIXI_EXECUTABLE)
    message(STATUS "rust-install-e2e: SKIP (no pixi; install chain not exercised)")
    return()
endif()

if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux")
    if(CMAKE_HOST_SYSTEM_PROCESSOR STREQUAL "aarch64")
        set(_plat linux-aarch64)
    else()
        set(_plat linux-64)
    endif()
elseif(CMAKE_HOST_SYSTEM_NAME STREQUAL "Darwin")
    if(CMAKE_HOST_SYSTEM_PROCESSOR STREQUAL "arm64")
        set(_plat osx-arm64)
    else()
        set(_plat osx-64)
    endif()
elseif(CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
    set(_plat win-64)
else()
    message(STATUS "rust-install-e2e: SKIP (no pixi platform for ${CMAKE_HOST_SYSTEM_NAME})")
    return()
endif()

_polyorch_pixi_scratch(_r)
set(POLYORCH_II_CMKEDIR "${CMAKE_CURRENT_LIST_DIR}/../../cmake")
set(POLYORCH_II_WS "${_r}/ws")
set(POLYORCH_II_ENVS "${_r}/pixi-envs")
set(POLYORCH_II_CWS "${_r}/cws")
set(POLYORCH_II_PLATFORM "${_plat}")
set(POLYORCH_II_STAGE "${_r}/stage")
set(POLYORCH_II_MAIN "${_r}/consumer/main.c")
file(MAKE_DIRECTORY "${_r}/consumer")

# --- cargo workspace ---------------------------------------------------------
file(WRITE "${POLYORCH_II_CWS}/Cargo.toml" [==[
[workspace]
members = ["dash-ed", "say-hi", "hookme"]
]==])
file(WRITE "${POLYORCH_II_CWS}/dash-ed/Cargo.toml" [==[
[package]
name = "dash-ed"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["staticlib"]
]==])
file(WRITE "${POLYORCH_II_CWS}/dash-ed/src/lib.rs" [==[
extern "C" {
    fn pow(x: f64, y: f64) -> f64; // libm: NOT linked implicitly by cc
}

// The base arrives from the caller, so this is a genuine undefined `pow`
// reference inside the archive: the final C link REQUIRES the probe's
// system-lib interface, shipped through the stub.
#[no_mangle]
pub extern "C" fn dash_pow(a: i32) -> i32 {
    unsafe { pow(a as f64, 2.0) as i32 }
}
]==])
file(WRITE "${POLYORCH_II_CWS}/say-hi/Cargo.toml" [==[
[package]
name = "say-hi"
version = "0.1.0"
edition = "2021"
]==])
file(WRITE "${POLYORCH_II_CWS}/say-hi/src/main.rs" [==[
fn main() {
    println!("INSTALL_E2E_BIN");
}
]==])
file(WRITE "${POLYORCH_II_CWS}/hookme/Cargo.toml" [==[
[package]
name = "hookme"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["staticlib"]
]==])
file(WRITE "${POLYORCH_II_CWS}/hookme/src/lib.rs" [==[
pub fn noop() {}
]==])

# --- shared consumer source --------------------------------------------------
file(WRITE "${POLYORCH_II_MAIN}" [==[
#include <stdio.h>
extern int dash_pow(int);
int main(void) {
    int v = dash_pow(32);
    if (v != 1024) {
        printf("INSTALL_E2E_BAD %d\n", v);
        return 1;
    }
    printf("INSTALL_E2E_CONSUMED\n");
    return 0;
}
]==])

# --- child project: bootstrap, probe ON, import + PREBUILD build, install ----
file(WRITE "${_r}/CMakeLists.in" [==[
cmake_minimum_required(VERSION 3.25)
project(polyorch-rust-install-e2e LANGUAGES NONE)
list(APPEND CMAKE_MODULE_PATH "@POLYORCH_II_CMKEDIR@")
include(PolyOrchPixiHelpers)
include(PolyOrchRustHelpers)

polyorch_pixi_init(WORKDIR "@POLYORCH_II_WS@" NAME t-rust-install-e2e VERSION 0.1.0
    CHANNELS conda-forge PLATFORMS "@POLYORCH_II_PLATFORM@"
    ENVIRONMENTS_DIR "@POLYORCH_II_ENVS@" IF_NOT_EXISTS)
polyorch_pixi_setup(MANIFEST "@POLYORCH_II_WS@/pixi.toml" ENVIRONMENT rust)
polyorch_pixi_dependency(DEPENDS rust FEATURE rust NO_INSTALL)
polyorch_pixi_environment_add(NAME rust FEATURES rust)
polyorch_pixi_install(ENVIRONMENT rust)

# Probe ON (default): the installed-STATIC consumer chain is this test.
polyorch_rust_setup(FROM pixi REQUIRED)

# PREBUILD leg: the stamp target produces nothing the build otherwise needs;
# its file existing after the aggregate build proves the ordering edge.
add_custom_target(prebuild-stamp
    COMMAND ${CMAKE_COMMAND} -E touch "${CMAKE_BINARY_DIR}/prebuild.txt")

polyorch_rust_import(MANIFEST "@POLYORCH_II_CWS@/Cargo.toml"
    CRATES dash-ed;say-hi IMPORTED_TARGETS _imps)
file(WRITE "${CMAKE_BINARY_DIR}/imported.txt" "${_imps}")

polyorch_rust_build(TARGET hook-lib PACKAGE hookme CRATE hookme STATIC
    MANIFEST "@POLYORCH_II_CWS@/Cargo.toml" PREBUILD prebuild-stamp)

polyorch_rust_install(TARGETS dash_ed say-hi-exe EXPORT demo)

# Staged-name evidence from the resolved genexes (the parent derives the
# staged paths from these, never re-spelling file names).
file(GENERATE OUTPUT "${CMAKE_BINARY_DIR}/name_static.txt" CONTENT "$<TARGET_FILE_NAME:dash_ed>")
file(GENERATE OUTPUT "${CMAKE_BINARY_DIR}/name_bin.txt" CONTENT "$<TARGET_FILE_NAME:say-hi-exe>")
]==])
configure_file("${_r}/CMakeLists.in" "${_r}/proj/CMakeLists.txt" @ONLY)

# --- consumer projects: identical shape, good stub vs stripped stub ----------
file(WRITE "${_r}/consumer.cmake.in" [==[
cmake_minimum_required(VERSION 3.25)
project(polyorch-rust-install-consumer LANGUAGES C)
include("@POLYORCH_II_STUB@")
if(NOT TARGET dash_ed)
    message(FATAL_ERROR "consumer: stub did not define dash_ed")
endif()
if(NOT TARGET say-hi-exe)
    message(FATAL_ERROR "consumer: stub did not define say-hi-exe")
endif()
get_target_property(_loc dash_ed IMPORTED_LOCATION)
if(NOT EXISTS "${_loc}")
    message(FATAL_ERROR "consumer: stub location does not exist: ${_loc}")
endif()
add_executable(capp "@POLYORCH_II_MAIN@")
target_link_libraries(capp PRIVATE dash_ed)
file(GENERATE OUTPUT "${CMAKE_BINARY_DIR}/capp.txt" CONTENT "$<TARGET_FILE:capp>")
file(GENERATE OUTPUT "${CMAKE_BINARY_DIR}/exe.txt" CONTENT "$<TARGET_FILE:say-hi-exe>")
get_target_property(_ifl dash_ed INTERFACE_LINK_LIBRARIES)
file(WRITE "${CMAKE_BINARY_DIR}/ifl.txt" "${_ifl}")
]==])
configure_file("${_r}/consumer.cmake.in" "${_r}/cproj/CMakeLists.txt" @ONLY)

# --- configure child; measured start (PIT-9) ---------------------------------
string(TIMESTAMP _t0 "%s")
execute_process(COMMAND "${CMAKE_COMMAND}" -S "${_r}/proj" -B "${_r}/b"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "rust-install-e2e: child configure failed (${_rc})\n${_out}${_err}")
endif()

file(READ "${_r}/b/imported.txt" _imps)
ck_str("${_imps}" "dash_ed;say-hi-exe")

# --- build everything through the aggregate (covers the PREBUILD mediator) ---
execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_r}/b"
    --target polyorch-rust-all
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "rust-install-e2e: child build failed (${_rc})\n${_out}${_err}")
endif()
ck_file("${_r}/b/prebuild.txt")

# --- stage -------------------------------------------------------------------
execute_process(COMMAND "${CMAKE_COMMAND}" --install "${_r}/b"
    --prefix "${POLYORCH_II_STAGE}"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "rust-install-e2e: install failed (${_rc})\n${_out}${_err}")
endif()

file(READ "${_r}/b/name_static.txt" _sname)
file(READ "${_r}/b/name_bin.txt" _bname)
set(_staged_lib "${POLYORCH_II_STAGE}/lib/${_sname}")
set(_staged_bin "${POLYORCH_II_STAGE}/bin/${_bname}")
set(_stub "${POLYORCH_II_STAGE}/lib/cmake/demo/demo-rust.cmake")
ck_file("${_staged_lib}")
ck_file("${_staged_bin}")
ck_file("${_stub}")

# The staged binary is standalone: run it from the install tree.
execute_process(COMMAND "${_staged_bin}"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(NOT _rc EQUAL 0 OR NOT _out MATCHES "INSTALL_E2E_BIN")
    message(FATAL_ERROR "rust-install-e2e: staged bin rc=${_rc} out=[${_out}${_err}]")
endif()

# --- positive consumer: a fresh project, C only, include(stub) --------------
set(POLYORCH_II_STUB "${_stub}")
configure_file("${_r}/consumer.cmake.in" "${_r}/cproj/CMakeLists.txt" @ONLY)
execute_process(COMMAND "${CMAKE_COMMAND}" -S "${_r}/cproj" -B "${_r}/cb"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "rust-install-e2e: consumer configure failed (${_rc})\n${_out}${_err}")
endif()
execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_r}/cb" --target capp
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "rust-install-e2e: consumer build failed (${_rc})\n${_out}${_err}")
endif()
file(READ "${_r}/cb/capp.txt" _capp)
ck_file("${_capp}")
execute_process(COMMAND "${_capp}"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(NOT _rc EQUAL 0 OR NOT _out MATCHES "INSTALL_E2E_CONSUMED")
    message(FATAL_ERROR "rust-install-e2e: consumer rc=${_rc} out=[${_out}${_err}]")
endif()
# The stub must have carried the bin too: run the staged exe THROUGH it.
file(READ "${_r}/cb/exe.txt" _staged_via_stub)
if(NOT _staged_via_stub STREQUAL _staged_bin)
    message(FATAL_ERROR "rust-install-e2e: stub bin path [${_staged_via_stub}] != staged [${_staged_bin}]")
endif()
file(READ "${_r}/cb/ifl.txt" _ifl)
if(_ifl STREQUAL "")
    message(FATAL_ERROR "rust-install-e2e: stub re-attached no INTERFACE_LINK_LIBRARIES")
endif()
message(STATUS "rust-install-e2e: consumer link interface [${_ifl}]")

# --- negative leg: stripped stub must break the SAME consumer link -----------
file(READ "${_stub}" _stubtxt)
string(REGEX REPLACE "[^\n]*INTERFACE_LINK[^\n]*" "" _badtxt "${_stubtxt}")
string(FIND "${_badtxt}" "INTERFACE_LINK" _still)
if(NOT _still EQUAL -1)
    message(FATAL_ERROR "rust-install-e2e: strip did not remove the INTERFACE lines")
endif()
set(_badstub "${POLYORCH_II_STAGE}/lib/cmake/demo/demo-rust-bad.cmake")
file(WRITE "${_badstub}" "${_badtxt}")
set(POLYORCH_II_STUB "${_badstub}")
configure_file("${_r}/consumer.cmake.in" "${_r}/cproj-neg/CMakeLists.txt" @ONLY)
execute_process(COMMAND "${CMAKE_COMMAND}" -S "${_r}/cproj-neg" -B "${_r}/cbneg"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "rust-install-e2e: neg consumer configure failed (${_rc})\n${_out}${_err}")
endif()
execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_r}/cbneg" --target capp
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(_rc EQUAL 0)
    message(FATAL_ERROR
        "rust-install-e2e: NEGATIVE leg did not bite -- capp linked against the "
        "stripped stub, so the probed system libs were never load-bearing")
endif()
string(REPLACE "\n" " " _flat "${_out}${_err}")
if(NOT _flat MATCHES "undefined reference to .?pow")
    message(FATAL_ERROR "rust-install-e2e: neg link failed (rc=${_rc}) but not on pow:\n${_out}${_err}")
endif()
string(REGEX MATCH "[^ ]*undefined reference to .?pow[^ ]*" _excerpt "${_flat}")

string(TIMESTAMP _t1 "%s")
math(EXPR _dt "${_t1} - ${_t0}")
message(STATUS
    "rust-install-e2e: OK (staged lib/${_sname} + bin/${_bname}, stub replay incl. "
    "bin-path equality + interface [${_ifl}]; stripped stub -> ${_excerpt}; ${_dt}s)")
