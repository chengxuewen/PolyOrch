# rust-cpp-lib -- "Rust wraps an EXISTING C++ library" (WP15).
#
# Sibling examples for orientation:
#   rust-bindings  -- cxx bridge with the C++ side living in the CONSUMER
#                     (host_scale inline); plus the installed-C-ABI story.
#   rust-link-c    -- the same link_libraries mechanism with a C library.
# THIS example: the C++ side is a REAL LIBRARY TARGET built by CMake and
# linked into the cargo build through polyorch_rust_link_libraries --
# the shape of wrapping a third-party C++ library you cannot edit.
#
# Layers:
#   cpp/libdemo  -- the "existing" C++ library (a class with state)
#   cpp/shim     -- hand-written glue the cxx bridge binds to (forwards
#                   into libdemo; a real project wraps a lib it can't edit)
#   crates/consumer -- the rust crate: #[cxx::bridge] declares Demo; its
#                   build.rs compiles the shim via cxx-build (which supplies
#                   rust/cxx.h); the LIBRARY ITSELF is linked by CMake
#                   through polyorch_rust_link_libraries -> the cargo link.
cmake_minimum_required(VERSION 3.22)

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    set(_rcl_standalone TRUE)
else()
    set(_rcl_standalone FALSE)
endif()
if(NOT _rcl_standalone AND NOT PolyOrch_BUILD_RUST_EXAMPLES)
    return()
endif()
if(NOT _rcl_standalone)
    find_program(PolyOrchExample_gate_cargo NAMES cargo
        PATHS "$ENV{HOME}/.cargo/bin" "$ENV{CARGO_HOME}/bin"
        NO_DEFAULT_PATH)
    if(NOT PolyOrchExample_gate_cargo)
        message(STATUS
            "rust-cpp-lib: needs cargo; not on PATH or in ~/.cargo/bin -- example skipped")
        return()
    endif()
    get_filename_component(PolyOrchExample_gate_bin "${PolyOrchExample_gate_cargo}" DIRECTORY)
    set(PolyOrch_RUST_CARGO_EXECUTABLE "${PolyOrchExample_gate_cargo}" CACHE FILEPATH
        "example gate: cargo found outside PATH" FORCE)
    set(PolyOrch_RUSTC_EXECUTABLE "${PolyOrchExample_gate_bin}/rustc" CACHE FILEPATH
        "example gate: rustc beside the gated cargo" FORCE)
endif()

project(rust-cpp-lib LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(PolyOrch_RUST_FOLDER_ROOT)
    set(_rcl_fold "${PolyOrch_RUST_FOLDER_ROOT}")
else()
    file(RELATIVE_PATH _rcl_fold
        "${CMAKE_SOURCE_DIR}"
        "${CMAKE_CURRENT_SOURCE_DIR}")
endif()

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
set(PolyOrch_RUST_VSCODE_DEBUG ON)
include(PolyOrchRustHelpers)

polyorch_rust_setup(REQUIRED)

# [1/3] The "existing" C++ library -- a plain CMake static lib target.
# D28: prefixed when fused (bare in the standalone tree), same idiom as
# the rust handles -- an unprefixed generic name invites host collisions.
if(PolyOrch_RUST_TARGET_PREFIX)
    set(_cpplib "${PolyOrch_RUST_TARGET_PREFIX}-rust-cpp-lib-cpplib")
else()
    set(_cpplib "rust-cpp-lib-cpplib")
endif()
add_library("${_cpplib}" STATIC
    cpp/libdemo/demo.cpp)
target_include_directories("${_cpplib}" PUBLIC
    "${CMAKE_CURRENT_SOURCE_DIR}/cpp/libdemo/include")
set_target_properties("${_cpplib}" PROPERTIES FOLDER "${_rcl_fold}")

# [2/3] The rust crate wrapping it. build.rs compiles the shim; the LIBRARY
# arrives through the link_libraries forwarding below.
polyorch_rust_build(
    TARGET  consumer-bin
    PACKAGE consumer
    CRATE   consumer
    BINARY
    MANIFEST "${CMAKE_CURRENT_LIST_DIR}/crates/consumer/Cargo.toml")
polyorch_rust_link_libraries(TARGET consumer-bin "${_cpplib}")
polyorch_rust_run(TARGET consumer-bin)

# [3/3] housekeeping verbs
if(PolyOrch_RUST_TARGET_PREFIX)
    polyorch_rust_clean(NAME "${PolyOrch_RUST_TARGET_PREFIX}-rust-cpp-lib-clean")
else()
    polyorch_rust_clean(NAME rust-cpp-lib-clean)
endif()

set(POLYORCH_FIXTURE_ARTIFACTS
    "manifest=${CMAKE_CURRENT_LIST_DIR}/crates/consumer/Cargo.toml")
string(JOIN "\n" _af ${POLYORCH_FIXTURE_ARTIFACTS})
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/polyorch-fixture-artifacts.txt" "${_af}\n")
