# e2e: required
# requires: system-rust
# t-rust-ctest-e2e -- the CTEST kw end-to-end on a real toolchain: fixture
# crate with two #[test] fns, registered through polyorch_rust_test(CTEST),
# then `ctest -R` EXECUTED. Judge: ctest reports the crate's tests passing
# via the cargo harness (the entry's exit code is cargo's -- the point of
# SKIP_RETURN_CODE posture is exercised by the consumer, not the supplier).
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

polyorch_requires(system-rust _req)
if(NOT _req)
    message(STATUS "t-rust-ctest-e2e : SKIP (no cargo on PATH)")
    return()
endif()
find_program(_cargo NAMES cargo)
if(NOT _cargo)
    find_program(_cargo NAMES cargo PATHS "$ENV{HOME}/.cargo/bin")
endif()
find_program(_rustc NAMES rustc)
if(NOT _rustc)
    find_program(_rustc NAMES rustc PATHS "$ENV{HOME}/.cargo/bin")
endif()

_polyorch_pixi_scratch(_s)
set(_fx "${_s}/fx")
file(MAKE_DIRECTORY "${_fx}/src")
file(WRITE "${_fx}/Cargo.toml"
    "[package]\nname = \"ctestfx\"\nversion = \"0.1.0\"\nedition = \"2021\"\n")
file(WRITE "${_fx}/src/lib.rs" [=[
pub fn add(a: i32, b: i32) -> i32 { a + b }
#[cfg(test)]
mod tests {
    use super::add;
    #[test] fn adds_two() { assert_eq!(add(2, 2), 4); }
    #[test] fn adds_zero() { assert_eq!(add(0, 1), 1); }
}
]=])
file(WRITE "${_fx}/CMakeLists.txt" [=[
cmake_minimum_required(VERSION 3.25)
project(rctest-e2e NONE)
enable_testing()
include("${POLYORCH_CMAKE_DIR}/PolyOrchRustHelpers.cmake")
set(POLYORCH_RUST_FOUND TRUE CACHE INTERNAL "")
set(POLYORCH_RUST_CARGO "@CARGO@" CACHE INTERNAL "")
set(POLYORCH_RUST_RUSTC "@RUSTC@" CACHE INTERNAL "")
set(POLYORCH_RUST_HOST_TARGET "x86_64-unknown-linux-gnu" CACHE INTERNAL "")
set(POLYORCH_RUST_ROUTE "system" CACHE INTERNAL "")
set(POLYORCH_RUST_BIN_DIR "" CACHE INTERNAL "")
polyorch_rust_test(PACKAGE ctestfx
    MANIFEST "@FX@/Cargo.toml" BASE_DIR "@TD@" FOLDER x
    CTEST CTEST_LABELS "rust;e2e")
]=])
file(READ "${_fx}/CMakeLists.txt" _tpl)
string(REPLACE "@CARGO@" "${_cargo}" _tpl "${_tpl}")
string(REPLACE "@RUSTC@" "${_rustc}" _tpl "${_tpl}")
string(REPLACE "@FX@" "${_fx}" _tpl "${_tpl}")
string(REPLACE "@TD@" "${_s}/td" _tpl "${_tpl}")
file(WRITE "${_fx}/CMakeLists.txt" "${_tpl}")

execute_process(COMMAND ${CMAKE_COMMAND} -S "${_fx}" -B "${_s}/b"
    "-DPOLYORCH_CMAKE_DIR=${CMAKE_CURRENT_LIST_DIR}/../../cmake"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _o ERROR_VARIABLE _e)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "configure failed rc=${_rc}\n${_o}\n${_e}")
endif()

# run the registered entry (ctest builds nothing itself; cargo compiles the
# harness within the entry's own command)
execute_process(COMMAND ${CMAKE_COMMAND} -E env "PATH=$ENV{PATH}"
    ctest --test-dir "${_s}/b" -R "ctestfx-test" --output-on-failure
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _o ERROR_VARIABLE _e)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "ctest -R failed rc=${_rc}\n${_o}\n${_e}")
endif()
# ctest swallows command output on PASS -- the verdict surface is ctest's
# own summary line ("1 test passed" + the Passed row).
if(NOT _o MATCHES "ctestfx-test[^
]*Passed")
    message(FATAL_ERROR "ctest summary lacks the Passed row:\n${_o}")
endif()
if(NOT _o MATCHES "100% tests passed out of 1")
    message(FATAL_ERROR "ctest summary count wrong:\n${_o}")
endif()

message(STATUS "t-rust-ctest-e2e: OK (cargo harness ran through the ctest entry)")
