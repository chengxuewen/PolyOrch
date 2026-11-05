# e2e: required
# requires: system-rust
# t-rust-clean-preserves-artifacts -- directory-level clean vs a SHARED-style
# --target-dir on a REAL cargo toolchain: one cdylib lane through
# polyorch_rust_build, mediator built (stamp lands, .so produced), then
# `cmake --build --target clean` EXECUTED. Judge (the 2026-11-05 IDE-Clean
# regression): the cargo-owned libalpha.so SURVIVES the clean (BYPRODUCTS
# are exempt; as OUTPUT the clean wiped exactly this file while deps/ and
# the SONAME symlink survived), the stamp is removed, and the mediator
# rebuilds clean afterwards (cargo no-op + re-stamp).
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

polyorch_requires(system-rust _req)
if(NOT _req)
    message(STATUS "t-rust-clean-preserves : SKIP (no cargo on PATH)")
    return()
endif()
find_program(_cargo NAMES cargo)
if(NOT _cargo)
    find_program(_cargo NAMES cargo PATHS "$ENV{HOME}/.cargo/bin")
endif()

_polyorch_pixi_scratch(_s)
set(_ws "${_s}/ws")
set(_td "${_s}/td")
set(_bld "${_s}/build")
file(MAKE_DIRECTORY "${_ws}/alpha/src")
file(WRITE "${_ws}/alpha/Cargo.toml"
    "[package]\nname = \"alpha\"\nversion = \"0.1.0\"\nedition = \"2021\"\n\n[lib]\ncrate-type = [\"cdylib\"]\n")
file(WRITE "${_ws}/alpha/src/lib.rs"
    "pub fn who() -> &'static str { \"alpha\" }\n")
file(WRITE "${_ws}/Cargo.toml"
    "[workspace]\nmembers = [\"alpha\"]\nresolver = \"2\"\n")

file(WRITE "${_s}/proj/CMakeLists.txt" [=[
cmake_minimum_required(VERSION 3.25)
project(rclean-keep NONE)
include("${POLYORCH_CMAKE_DIR}/PolyOrchRustHelpers.cmake")
set(POLYORCH_RUST_FOUND TRUE CACHE INTERNAL "")
set(POLYORCH_RUST_CARGO "@CARGO@" CACHE INTERNAL "")
set(POLYORCH_RUST_RUSTC "@RUSTC@" CACHE INTERNAL "")
set(POLYORCH_RUST_HOST_TARGET "x86_64-unknown-linux-gnu" CACHE INTERNAL "")
set(POLYORCH_RUST_ROUTE "system" CACHE INTERNAL "")
set(POLYORCH_RUST_BIN_DIR "" CACHE INTERNAL "")
polyorch_rust_build(TARGET t-alpha PACKAGE alpha CRATE alpha SHARED
    MANIFEST "@WS@/Cargo.toml" BASE_DIR "@TD@" FOLDER x)
]=])
if(NOT DEFINED _rustc)
    find_program(_rustc NAMES rustc)
endif()
file(READ "${_s}/proj/CMakeLists.txt" _tpl)
string(REPLACE "@CARGO@" "${_cargo}" _tpl "${_tpl}")
string(REPLACE "@RUSTC@" "${_rustc}" _tpl "${_tpl}")
string(REPLACE "@WS@" "${_ws}" _tpl "${_tpl}")
string(REPLACE "@TD@" "${_td}" _tpl "${_tpl}")
file(WRITE "${_s}/proj/CMakeLists.txt" "${_tpl}")

execute_process(COMMAND ${CMAKE_COMMAND} -S "${_s}/proj" -B "${_bld}"
    "-DPOLYORCH_CMAKE_DIR=${CMAKE_CURRENT_LIST_DIR}/../../cmake"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _o ERROR_VARIABLE _e)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "configure failed rc=${_rc}\n${_o}\n${_e}")
endif()

# build the mediator: runs cargo (real build) and lands the stamp
execute_process(COMMAND ${CMAKE_COMMAND} --build "${_bld}" --target t-alpha-build
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _o ERROR_VARIABLE _e)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "t-alpha-build failed rc=${_rc}\n${_o}\n${_e}")
endif()
set(_lib "${_td}/debug/libalpha.so")
if(NOT EXISTS "${_lib}")
    message(FATAL_ERROR "precondition: cargo artifact missing after build: ${_lib}")
endif()
file(GLOB _stamps "${_bld}/.polyorch-rust-stamps/*.stamp")
if(NOT _stamps)
    message(FATAL_ERROR "precondition: no stamp landed under ${_bld}/.polyorch-rust-stamps")
endif()

# THE regression probe: a directory-level clean must NOT delete cargo output
execute_process(COMMAND ${CMAKE_COMMAND} --build "${_bld}" --target clean
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _o ERROR_VARIABLE _e)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "clean failed rc=${_rc}\n${_o}\n${_e}")
endif()
if(NOT EXISTS "${_lib}")
    message(FATAL_ERROR "REGRESSION: cmake clean deleted the cargo artifact ${_lib}")
endif()
file(GLOB _stamps2 "${_bld}/.polyorch-rust-stamps/*.stamp")
if(_stamps2)
    message(FATAL_ERROR "clean did not remove the stamp(s): ${_stamps2}")
endif()

# rebuild after clean: cargo re-runs (fingerprint no-op) and re-stamps
execute_process(COMMAND ${CMAKE_COMMAND} --build "${_bld}" --target t-alpha-build
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _o ERROR_VARIABLE _e)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "post-clean rebuild failed rc=${_rc}\n${_o}\n${_e}")
endif()
file(GLOB _stamps3 "${_bld}/.polyorch-rust-stamps/*.stamp")
if(NOT _stamps3)
    message(FATAL_ERROR "post-clean rebuild did not re-stamp")
endif()
if(NOT EXISTS "${_lib}")
    message(FATAL_ERROR "post-clean rebuild lost the artifact")
endif()

message(STATUS "t-rust-clean-preserves: OK (artifact survived clean, stamp cycle honest)")
