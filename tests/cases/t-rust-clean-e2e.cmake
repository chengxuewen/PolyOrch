# e2e: required
# requires: system-rust
# t-rust-clean-e2e -- the PACKAGE clean form on a REAL cargo toolchain:
# two zero-dependency workspace members built into ONE shared target-dir,
# then the registered <pkg>-clean custom target EXECUTED through
# `cmake --build --target`. Judge (cargo-fingerprint truth, not guesses):
# the cleaned package's artifacts vanish from the shared tree while the
# SIBLING package's artifacts survive -- the exact property F17-D needs
# (per-crate clean must never annihilate the gate cache).
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

polyorch_requires(system-rust _req)
if(NOT _req)
    message(STATUS "t-rust-clean-e2e : SKIP (no cargo on PATH)")
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
foreach(_p alpha beta)
    file(MAKE_DIRECTORY "${_ws}/${_p}/src")
    file(WRITE "${_ws}/${_p}/Cargo.toml"
        "[package]\nname = \"${_p}\"\nversion = \"0.1.0\"\nedition = \"2021\"\n")
    file(WRITE "${_ws}/${_p}/src/lib.rs" "pub fn who() -> &'static str { \"${_p}\" }\n")
endforeach()
file(WRITE "${_ws}/Cargo.toml"
    "[workspace]\nmembers = [\"alpha\", \"beta\"]\nresolver = \"2\"\n")

# real build of BOTH packages into the shared --target-dir
execute_process(COMMAND "${_cargo}" build --manifest-path "${_ws}/Cargo.toml"
    --target-dir "${_td}"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _o ERROR_VARIABLE _e)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "cargo build failed rc=${_rc}\n${_o}\n${_e}")
endif()
file(GLOB _a0 "${_td}/debug/deps/libalpha-*")
file(GLOB _b0 "${_td}/debug/deps/libbeta-*")
if(NOT _a0 OR NOT _b0)
    message(FATAL_ERROR "precondition: both artifacts must exist before clean (alpha=[${_a0}] beta=[${_b0}])")
endif()

# the clean registration rides the real toolchain via the same stub shape
file(WRITE "${_s}/proj/CMakeLists.txt" [=[
cmake_minimum_required(VERSION 3.25)
project(rclean-e2e NONE)
include("${POLYORCH_CMAKE_DIR}/PolyOrchRustHelpers.cmake")
set(POLYORCH_RUST_FOUND TRUE CACHE INTERNAL "")
set(POLYORCH_RUST_CARGO "@CARGO@" CACHE INTERNAL "")
set(POLYORCH_RUST_RUSTC "@RUSTC@" CACHE INTERNAL "")
set(POLYORCH_RUST_HOST_TARGET "x86_64-unknown-linux-gnu" CACHE INTERNAL "")
set(POLYORCH_RUST_ROUTE "system" CACHE INTERNAL "")
set(POLYORCH_RUST_BIN_DIR "" CACHE INTERNAL "")
polyorch_rust_clean(NAME alpha-clean PACKAGE alpha
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

# EXECUTE the registered button (the cmake target is the product surface --
# not a hand-rolled cargo call)
execute_process(COMMAND ${CMAKE_COMMAND} --build "${_bld}" --target alpha-clean
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _o ERROR_VARIABLE _e)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "alpha-clean target failed rc=${_rc}\n${_o}\n${_e}")
endif()

file(GLOB _a1 "${_td}/debug/deps/libalpha-*")
file(GLOB _b1 "${_td}/debug/deps/libbeta-*")
if(_a1)
    message(FATAL_ERROR "clean -p alpha left alpha artifacts: ${_a1}")
endif()
if(NOT _b1)
    message(FATAL_ERROR "clean -p alpha COLLATERALIZED the sibling beta artifacts")
endif()

# and the cleaned package rebuilds clean afterwards (fingerprint honest)
execute_process(COMMAND "${_cargo}" build --manifest-path "${_ws}/Cargo.toml"
    --package alpha --target-dir "${_td}"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _o ERROR_VARIABLE _e)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "alpha did not rebuild after clean rc=${_rc}\n${_o}\n${_e}")
endif()

message(STATUS "t-rust-clean-e2e: OK (sibling survived, cleaned rebuilt)")
