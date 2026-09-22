# e2e: required
# requires: pixi-rust
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

# Full rust path on a real toolchain: pixi-provided rust -> polyorch_rust_setup
# (FROM pixi) -> polyorch_rust_build of a scratch crate -> the built binary
# exists and is non-empty. The child project is configured + built for real
# (custom commands never run in `cmake -P`), so the contract anchor
# ${CMAKE_BINARY_DIR}/.cargo-target/<profile>/<file> is exercised as specified.
# polyorch_rust_test is only asserted as a registered target, never executed.
# THE pixi-rust coverage keeper (WP2 ruling): every other rust case moved to
# the system route, so this heredoc case is the only proof the FROM pixi
# setup route works -- the line-2 marker names that capability. Since
# rust-basic dropped its pixi env there is no materialized store left to
# pre-gate on, and gating on one could never pass on a clean host: this
# case IS the materializer. The gate is therefore the pixi TOOL probe; the
# solve + install below run on every execution (the R-12 conda-index flake
# lives here now, nowhere else). No tool => honest contract skip.
polyorch_requires(pixi _req)
if(NOT _req)
    message(STATUS "t-rust-e2e : SKIP (no pixi tool on this host)")
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
    message(STATUS "t-rust-e2e : SKIP (no pixi platform for ${CMAKE_HOST_SYSTEM_NAME})")
    return()
endif()

_polyorch_pixi_scratch(_r)
set(POLYORCH_E2E_CMKEDIR "${CMAKE_CURRENT_LIST_DIR}/../../cmake")
set(POLYORCH_E2E_WS "${_r}/ws")
set(POLYORCH_E2E_ENVS "${_r}/pixi-envs")
set(POLYORCH_E2E_CRATE "${_r}/proj/crate")
set(POLYORCH_E2E_PLATFORM "${_plat}")

# --- mini crate: staticlib + rlib + bin, zero external dependencies ----------
file(WRITE "${POLYORCH_E2E_CRATE}/Cargo.toml" [==[
[package]
name = "greet"
version = "0.1.0"
edition = "2021"

# isolated from any enclosing cargo workspace (host monorepos may wrap us)
[workspace]

[lib]
name = "greet"
crate-type = ["staticlib", "rlib"]
]==])
file(WRITE "${POLYORCH_E2E_CRATE}/src/lib.rs" [==[
pub fn greet() -> String {
    String::from("hello from rust")
}

#[cfg(test)]
mod tests {
    #[test]
    fn greets() {
        assert_eq!(super::greet(), "hello from rust");
    }
}
]==])
file(WRITE "${POLYORCH_E2E_CRATE}/src/main.rs" [==[
fn main() {
    println!("{}", greet::greet());
}
]==])

# --- child project: every helper is exercised at real configure/build time --
# Bracket literal: ${} must survive to the child; only @..@ is substituted here.
file(WRITE "${_r}/CMakeLists.in" [==[
cmake_minimum_required(VERSION 3.25)
project(polyorch-rust-e2e LANGUAGES NONE)
list(APPEND CMAKE_MODULE_PATH "@POLYORCH_E2E_CMKEDIR@")
include(PolyOrchPixiHelpers)
include(PolyOrchRustHelpers)

polyorch_pixi_init(WORKDIR "@POLYORCH_E2E_WS@" NAME t-rust-e2e VERSION 0.1.0
    CHANNELS conda-forge PLATFORMS "@POLYORCH_E2E_PLATFORM@"
    ENVIRONMENTS_DIR "@POLYORCH_E2E_ENVS@" IF_NOT_EXISTS)
polyorch_pixi_setup(MANIFEST "@POLYORCH_E2E_WS@/pixi.toml" ENVIRONMENT rust)
polyorch_pixi_dependency(DEPENDS rust FEATURE rust NO_INSTALL)
polyorch_pixi_environment_add(NAME rust FEATURES rust)
polyorch_pixi_install(ENVIRONMENT rust)

polyorch_rust_setup(FROM pixi REQUIRED)
if(NOT POLYORCH_RUST_CARGO)
    message(FATAL_ERROR "e2e: POLYORCH_RUST_CARGO empty after setup(FROM pixi)")
endif()
if(NOT POLYORCH_RUST_RUSTC)
    message(FATAL_ERROR "e2e: POLYORCH_RUST_RUSTC empty after setup(FROM pixi)")
endif()
if(NOT POLYORCH_RUST_VERSION MATCHES "[0-9]+[.][0-9]+")
    message(FATAL_ERROR "e2e: POLYORCH_RUST_VERSION not a version: [${POLYORCH_RUST_VERSION}]")
endif()
if(NOT POLYORCH_RUST_HOST_TARGET MATCHES ".*-.*")
    message(FATAL_ERROR "e2e: POLYORCH_RUST_HOST_TARGET not a triple: [${POLYORCH_RUST_HOST_TARGET}]")
endif()

polyorch_rust_build(TARGET greet-bin PACKAGE greet CRATE greet BINARY
    MANIFEST "@POLYORCH_E2E_CRATE@/Cargo.toml")
if(NOT TARGET greet-bin)
    message(FATAL_ERROR "e2e: polyorch_rust_build created no IMPORTED target greet-bin")
endif()
if(NOT TARGET greet-bin-cargo)
    message(FATAL_ERROR "e2e: no <TARGET>-cargo mediator target to build")
endif()

polyorch_rust_test(PACKAGE greet NAME greet-rusttest)
if(NOT TARGET greet-rusttest)
    message(FATAL_ERROR "e2e: polyorch_rust_test registered no target greet-rusttest")
endif()

_polyorch_rust_artifact_names(TRIPLE "${POLYORCH_RUST_HOST_TARGET}"
    KIND bin CRATE greet FILE_OUT _f)
file(WRITE "${CMAKE_BINARY_DIR}/artifact.txt"
    "${CMAKE_BINARY_DIR}/.cargo-target/debug/${_f}")
]==])
configure_file("${_r}/CMakeLists.in" "${_r}/proj/CMakeLists.txt" @ONLY)

execute_process(COMMAND "${CMAKE_COMMAND}" -S "${_r}/proj" -B "${_r}/b"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "rust-e2e: child configure failed (${_rc})\n${_out}${_err}")
endif()

execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_r}/b"
    --target greet-bin-cargo
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "rust-e2e: child build failed (${_rc})\n${_out}${_err}")
endif()

# Artifact evidence: path per the frozen contract anchor, present, non-empty.
file(READ "${_r}/b/artifact.txt" _art)
ck_file("${_art}")
file(SIZE "${_art}" _len)
ck(_len GREATER 0)

message(STATUS "rust-e2e: OK (artifact ${_art}, ${_len} bytes)")
