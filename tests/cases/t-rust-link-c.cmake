# e2e: required
# requires: pixi-rust
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

# P-2 acceptance for the whole rust gap-close epic (Task 4): a Rust STATIC
# artifact linked by a real C consumer, end to end. This is the first piece of
# evidence in the experiment-field sense that a bridge-produced Rust library is
# actually usable from C, and it is the ONLY place the native-static-libs probe
# runs against a live toolchain (t-rust-native-libs only exercises the parser).
#
# Chain exercised for real (nothing mocked):
#   pixi rust -> polyorch_rust_setup (FROM pixi, WITH probe) -> the probe
#   discovers the system libs this triple's libstd needs -> polyorch_rust_build
#   (STATIC) attaches them as INTERFACE_LINK_LIBRARIES -> a C executable links
#   the staticlib and, crucially, the C link would FAIL without that interface:
#   the crate calls libm's pow(), which the C compiler does not link implicitly.
#
# Needs pixi + a materialized pixi cargo env + a host C compiler; skips
# honestly without pixi-rust.

polyorch_requires(pixi-rust _req)
if(NOT _req)
    message(STATUS "t-rust-link-c : SKIP (no pixi env materialized with a cargo)")
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
    message(STATUS "t-rust-link-c : SKIP (no pixi platform for ${CMAKE_HOST_SYSTEM_NAME})")
    return()
endif()

_polyorch_pixi_scratch(_r)
set(POLYORCH_LC_CMKEDIR "${CMAKE_CURRENT_LIST_DIR}/../../cmake")
set(POLYORCH_LC_WS "${_r}/ws")
set(POLYORCH_LC_ENVS "${_r}/pixi-envs")
set(POLYORCH_LC_PROJ "${_r}/proj")
set(POLYORCH_LC_CRATE "${_r}/proj/crate")
set(POLYORCH_LC_PLATFORM "${_plat}")
file(MAKE_DIRECTORY "${POLYORCH_LC_CRATE}/src")

# --- mini staticlib crate: zero external deps, but it calls libm (pow) and
#     libc (getpid) through extern "C" so the final C link needs the probe's
#     system libraries. No crates.io, no network beyond the rust toolchain. -----
file(WRITE "${POLYORCH_LC_CRATE}/Cargo.toml" [==[
[package]
name = "probe_staticlib"
version = "0.1.0"
edition = "2021"

[workspace]

[lib]
name = "probe_staticlib"
crate-type = ["staticlib"]
]==])
file(WRITE "${POLYORCH_LC_CRATE}/src/lib.rs" [==[
extern "C" {
    fn pow(x: f64, y: f64) -> f64; // lives in libm: NOT linked implicitly by cc
    fn getpid() -> i32;             // lives in libc
}

// 2^10 via libm's pow(): resolving this symbol at final link REQUIRES the
// system-lib interface the native-static-libs probe attaches.
#[no_mangle]
pub extern "C" fn rust_calc() -> i32 {
    unsafe { pow(2.0, 10.0) as i32 }
}

#[no_mangle]
pub extern "C" fn rust_pid() -> i32 {
    unsafe { getpid() }
}
]==])

# --- mini C consumer: the whole point is that this compiles + links against
#     the Rust staticlib THROUGH the propagated interface, with no hand-written
#     system libraries. --------------------------------------
file(WRITE "${POLYORCH_LC_PROJ}/main.c" [==[
#include <stdio.h>
extern int rust_calc(void);
extern int rust_pid(void);
int main(void) {
    int v = rust_calc();
    int p = rust_pid();
    if (v != 1024 || p <= 0) {
        printf("POLYORCH_RUST_LINK_BAD calc=%d pid=%d\n", v, p);
        return 1;
    }
    printf("POLYORCH_RUST_LINK_OK pid=%d\n", p);
    return 0;
}
]==])

# --- child project (real configure + build): pixi bootstrap WITH the probe,
#     STATIC import, a C executable linked against it. Bracket literal: ${}
#     survives to the child; only @..@ is substituted here. ----------------
file(WRITE "${_r}/CMakeLists.in" [==[
cmake_minimum_required(VERSION 3.25)
project(polyorch-rust-link-c LANGUAGES C)
list(APPEND CMAKE_MODULE_PATH "@POLYORCH_LC_CMKEDIR@")
include(PolyOrchPixiHelpers)
include(PolyOrchRustHelpers)

polyorch_pixi_init(WORKDIR "@POLYORCH_LC_WS@" NAME t-rust-link-c VERSION 0.1.0
    CHANNELS conda-forge PLATFORMS "@POLYORCH_LC_PLATFORM@"
    ENVIRONMENTS_DIR "@POLYORCH_LC_ENVS@" IF_NOT_EXISTS)
polyorch_pixi_setup(MANIFEST "@POLYORCH_LC_WS@/pixi.toml" ENVIRONMENT rust)
polyorch_pixi_dependency(DEPENDS rust FEATURE rust NO_INSTALL)
polyorch_pixi_environment_add(NAME rust FEATURES rust)
polyorch_pixi_install(ENVIRONMENT rust)

# Probe ON (default): the STATIC interface this test asserts comes from it.
polyorch_rust_setup(FROM pixi REQUIRED)

# Evidence the probe actually ran and found the toolchain's system libs.
file(WRITE "${CMAKE_BINARY_DIR}/native_libs.txt" "${POLYORCH_RUST_NATIVE_LIBS}")

polyorch_rust_build(TARGET greet-lib PACKAGE probe_staticlib CRATE probe_staticlib
    STATIC MANIFEST "@POLYORCH_LC_CRATE@/Cargo.toml")
get_target_property(_iface greet-lib INTERFACE_LINK_LIBRARIES)
file(WRITE "${CMAKE_BINARY_DIR}/iface.txt" "${_iface}")

add_executable(capp "@POLYORCH_LC_PROJ@/main.c")
target_link_libraries(capp PRIVATE greet-lib)
file(GENERATE OUTPUT "${CMAKE_BINARY_DIR}/capp_path.txt" CONTENT "$<TARGET_FILE:capp>")
]==])
configure_file("${_r}/CMakeLists.in" "${POLYORCH_LC_PROJ}/CMakeLists.txt" @ONLY)

# --- configure: pixi solves rust, the probe builds its throwaway staticlib. --
execute_process(COMMAND "${CMAKE_COMMAND}" -S "${POLYORCH_LC_PROJ}" -B "${_r}/b"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "rust-link-c: child configure failed (${_rc})\n${_out}${_err}")
endif()

# The probe must have produced a non-empty system-lib list on this host and the
# STATIC import must carry it as its link interface.
file(READ "${_r}/b/native_libs.txt" _libs)
file(READ "${_r}/b/iface.txt" _iface)
message(STATUS "rust-link-c: probe native libs = [${_libs}]")
if(_libs STREQUAL "")
    message(FATAL_ERROR "rust-link-c: probe produced no native libs on this toolchain")
endif()
if(NOT _iface STREQUAL _libs)
    message(FATAL_ERROR "rust-link-c: STATIC interface [${_iface}] != probe libs [${_libs}]")
endif()
# libm must be in the set here: that is the symbol the C link cannot resolve
# without the interface (cc links libc but not libm implicitly).
if(NOT _libs MATCHES "(^|;)m($|;)")
    message(FATAL_ERROR "rust-link-c: probe libs [${_libs}] lack libm 'm' (pow test invalid)")
endif()

# --- build capp: runs the mediator (cargo build) via the auto-build edge, then
#     compiles + links the C consumer. A missing system-lib interface fails
#     here with an undefined-reference to pow(). -----------------------------
execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_r}/b" --target capp
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "rust-link-c: child build failed (${_rc})\n${_out}${_err}")
endif()

# The generated link command must carry a probe lib (-lm) and the static lib.
file(READ "${_r}/b/capp_path.txt" _capp)
file(GLOB _linktxt "${_r}/b/CMakeFiles/capp.dir/link.txt")
if(_linktxt)
    file(READ "${_linktxt}" _lt)
    string(STRIP "${_lt}" _lt)
    if(NOT _lt MATCHES "-lm")
        message(FATAL_ERROR "rust-link-c: capp link line lacks -lm from the probe:\n${_lt}")
    endif()
    if(NOT _lt MATCHES "probe_staticlib")
        message(FATAL_ERROR "rust-link-c: capp link line does not reference the staticlib:\n${_lt}")
    endif()
else()
    # Ninja generator has no link.txt; the successful build above is the proof.
    message(STATUS "rust-link-c: link.txt not present (non-Makefile generator); relying on build success")
endif()

# --- run: the linked binary executes and prints the marker. -----------------
ck_file("${_capp}")
file(SIZE "${_capp}" _sz)
ck(_sz GREATER 0)
execute_process(COMMAND "${_capp}"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
message(STATUS "rust-link-c: capp output: ${_out}")
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "rust-link-c: capp exited ${_rc}\n${_out}${_err}")
endif()
if(NOT _out MATCHES "POLYORCH_RUST_LINK_OK")
    message(FATAL_ERROR "rust-link-c: capp stdout lacks marker:\n${_out}${_err}")
endif()

message(STATUS "rust-link-c: OK (Rust staticlib linked + run by a C consumer; probe libs [${_libs}])")
