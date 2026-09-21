# e2e: required
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")

# Task 5 acceptance: polyorch_rust_import over a REAL cargo workspace with a
# real pixi rust toolchain -- `cargo metadata` runs for real (the offline
# half, the parser table, is t-rust-metadata.cmake). Two members exercise the
# naming contract end to end:
#   dash-ed  [lib] crate-type=staticlib  -> handle dash_ed, artifact libdash_ed.a
#   say-hi   bin                        -> handle say-hi-exe, runs, prints marker
# IMPORTED_TARGETS is asserted as an EXACT set (P4: a stray or missing handle
# fails). The negative leg re-enters cargo metadata with CRATES ghost-pkg and
# pins the FATAL phrase naming the available packages.
# Needs pixi; skips cleanly without it.

polyorch_pixi_find(QUIET)
if(NOT PolyOrch_PIXI_EXECUTABLE)
    message(STATUS "rust-import-ws: SKIP (no pixi; batch import not exercised)")
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
    message(STATUS "rust-import-ws: SKIP (no pixi platform for ${CMAKE_HOST_SYSTEM_NAME})")
    return()
endif()

_polyorch_pixi_scratch(_r)
set(POLYORCH_IW_CMKEDIR "${CMAKE_CURRENT_LIST_DIR}/../../cmake")
set(POLYORCH_IW_WS "${_r}/ws")
set(POLYORCH_IW_ENVS "${_r}/pixi-envs")
set(POLYORCH_IW_CWS "${_r}/cws")
set(POLYORCH_IW_PLATFORM "${_plat}")

# --- real 2-member cargo workspace (zero external deps, no network) ---------
file(WRITE "${POLYORCH_IW_CWS}/Cargo.toml" [==[
[workspace]
members = ["dash-ed", "say-hi"]
]==])
file(WRITE "${POLYORCH_IW_CWS}/dash-ed/Cargo.toml" [==[
[package]
name = "dash-ed"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["staticlib"]
]==])
file(WRITE "${POLYORCH_IW_CWS}/dash-ed/src/lib.rs" [==[
pub fn marker() -> String {
    String::from("DASH_ED_STATIC")
}
]==])
file(WRITE "${POLYORCH_IW_CWS}/say-hi/Cargo.toml" [==[
[package]
name = "say-hi"
version = "0.1.0"
edition = "2021"
]==])
file(WRITE "${POLYORCH_IW_CWS}/say-hi/src/main.rs" [==[
fn main() {
    println!("IMPORT_WS_OK");
}
]==])

# --- child project (positive leg): import the workspace whole. Bracket
#     literal: ${} survives to the child; only @..@ is substituted here. -----
file(WRITE "${_r}/CMakeLists.in" [==[
cmake_minimum_required(VERSION 3.25)
project(polyorch-rust-import-ws LANGUAGES NONE)
list(APPEND CMAKE_MODULE_PATH "@POLYORCH_IW_CMKEDIR@")
include(PolyOrchPixiHelpers)
include(PolyOrchRustHelpers)

polyorch_pixi_init(WORKDIR "@POLYORCH_IW_WS@" NAME t-rust-import-ws VERSION 0.1.0
    CHANNELS conda-forge PLATFORMS "@POLYORCH_IW_PLATFORM@"
    ENVIRONMENTS_DIR "@POLYORCH_IW_ENVS@" IF_NOT_EXISTS)
polyorch_pixi_setup(MANIFEST "@POLYORCH_IW_WS@/pixi.toml" ENVIRONMENT rust)
polyorch_pixi_dependency(DEPENDS rust FEATURE rust NO_INSTALL)
polyorch_pixi_environment_add(NAME rust FEATURES rust)
polyorch_pixi_install(ENVIRONMENT rust)

# NO_NATIVE_PROBE: the link interface is t-rust-link-c's subject; this case
# is about the import registry itself.
polyorch_rust_setup(FROM pixi REQUIRED NO_NATIVE_PROBE)

polyorch_rust_import(MANIFEST "@POLYORCH_IW_CWS@/Cargo.toml"
    IMPORTED_TARGETS _imps SKIPPED_TARGETS _skips FOLDER "polyorch-import")

file(WRITE "${CMAKE_BINARY_DIR}/imported.txt" "${_imps}")
file(WRITE "${CMAKE_BINARY_DIR}/skipped.txt" "${_skips}")

# P4 exact-set discipline, child side: no plausible-but-wrong handle may exist.
foreach(_x dash-ed say-hi dash_ed-exe dash-ed-exe lib_a)
    if(TARGET "${_x}")
        message(FATAL_ERROR "import: unexpected handle '${_x}' exists")
    endif()
endforeach()
if(NOT TARGET dash_ed-cargo OR NOT TARGET say-hi-exe-cargo)
    message(FATAL_ERROR "import: mediators dash_ed-cargo / say-hi-exe-cargo missing")
endif()

# Registry property + FOLDER pass-through evidence.
get_target_property(_pkg dash_ed POLYORCH_RUST_PACKAGE)
get_target_property(_fld say-hi-exe FOLDER)
file(WRITE "${CMAKE_BINARY_DIR}/pkg.txt" "${_pkg}")
file(WRITE "${CMAKE_BINARY_DIR}/fld.txt" "${_fld}")

# Artifact path per the frozen naming contract (underscored staticlib).
_polyorch_rust_artifact_names(TRIPLE "${POLYORCH_RUST_HOST_TARGET}"
    KIND static CRATE dash_ed FILE_OUT _lf DIR_OUT _ld)
file(WRITE "${CMAKE_BINARY_DIR}/lib_path.txt" "${_ld}/${_lf}")
file(GENERATE OUTPUT "${CMAKE_BINARY_DIR}/bin_path.txt" CONTENT "$<TARGET_FILE:say-hi-exe>")
]==])
configure_file("${_r}/CMakeLists.in" "${_r}/proj/CMakeLists.txt" @ONLY)

# --- child project (negative leg): CRATES ghost-pkg must FATAL the configure.
file(WRITE "${_r}/CMakeLists.neg.in" [==[
cmake_minimum_required(VERSION 3.25)
project(polyorch-rust-import-ws-neg LANGUAGES NONE)
list(APPEND CMAKE_MODULE_PATH "@POLYORCH_IW_CMKEDIR@")
include(PolyOrchPixiHelpers)
include(PolyOrchRustHelpers)
polyorch_pixi_init(WORKDIR "@POLYORCH_IW_WS@" NAME t-rust-import-ws VERSION 0.1.0
    CHANNELS conda-forge PLATFORMS "@POLYORCH_IW_PLATFORM@"
    ENVIRONMENTS_DIR "@POLYORCH_IW_ENVS@" IF_NOT_EXISTS)
polyorch_pixi_setup(MANIFEST "@POLYORCH_IW_WS@/pixi.toml" ENVIRONMENT rust)
polyorch_rust_setup(FROM pixi REQUIRED NO_NATIVE_PROBE)
polyorch_rust_import(MANIFEST "@POLYORCH_IW_CWS@/Cargo.toml"
    CRATES ghost-pkg IMPORTED_TARGETS _x)
message(FATAL_ERROR "neg: ghost CRATES entry was accepted")
]==])
configure_file("${_r}/CMakeLists.neg.in" "${_r}/proj-neg/CMakeLists.txt" @ONLY)

# --- configure (positive): cargo metadata runs for real here. ---------------
execute_process(COMMAND "${CMAKE_COMMAND}" -S "${_r}/proj" -B "${_r}/b"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "rust-import-ws: child configure failed (${_rc})\n${_out}${_err}")
endif()

file(READ "${_r}/b/imported.txt" _imps)
ck_str("${_imps}" "dash_ed;say-hi-exe")
file(READ "${_r}/b/skipped.txt" _skips)
ck_str("${_skips}" "")
file(READ "${_r}/b/pkg.txt" _pkg)
ck_str("${_pkg}" "dash-ed")
file(READ "${_r}/b/fld.txt" _fld)
ck_str("${_fld}" "polyorch-import")

# --- build BOTH mediators through the aggregate; measured (PIT-9). ----------
string(TIMESTAMP _t0 "%s")
execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_r}/b"
    --target polyorch-rust-all
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
string(TIMESTAMP _t1 "%s")
math(EXPR _dt "${_t1} - ${_t0}")
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "rust-import-ws: child build failed (${_rc})\n${_out}${_err}")
endif()

# Staticlib evidence: underscored file name per the naming table, non-empty.
file(READ "${_r}/b/lib_path.txt" _libp)
if(NOT _libp MATCHES "libdash_ed[.]a$")
    message(FATAL_ERROR "rust-import-ws: lib artifact path not underscored: ${_libp}")
endif()
ck_file("${_libp}")
file(SIZE "${_libp}" _lsz)
ck(_lsz GREATER 0)

# Binary evidence: the imported exe runs and prints the marker.
file(READ "${_r}/b/bin_path.txt" _binp)
ck_file("${_binp}")
execute_process(COMMAND "${_binp}"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "rust-import-ws: say-hi-exe exited ${_rc}\n${_out}${_err}")
endif()
if(NOT _out MATCHES "IMPORT_WS_OK")
    message(FATAL_ERROR "rust-import-ws: bin stdout lacks marker:\n${_out}")
endif()

# --- negative leg: unknown CRATES package names the available ones. ---------
execute_process(COMMAND "${CMAKE_COMMAND}" -S "${_r}/proj-neg" -B "${_r}/b-neg"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(_rc EQUAL 0)
    message(FATAL_ERROR "rust-import-ws: ghost CRATES configure exited 0, expected FATAL")
endif()
string(REPLACE "\n" " " _flat "${_out}${_err}")
if(NOT _flat MATCHES "no package 'ghost-pkg'")
    message(FATAL_ERROR "rust-import-ws: ghost CRATES rc=${_rc} but output lacks the phrase:\n${_out}${_err}")
endif()
if(NOT _flat MATCHES "available: dash-ed, say-hi")
    message(FATAL_ERROR "rust-import-ws: ghost CRATES message lacks the available list:\n${_out}${_err}")
endif()

message(STATUS "rust-import-ws: OK (import exact-set, libdash_ed.a + IMPORT_WS_OK run, ghost FATAL; build ${_dt}s)")
