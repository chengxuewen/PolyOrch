# rust-bindings -- the flagship binding example (WP14).
#
# ONE rust crate (spine) with TWO foreign surfaces, consumed TWO ways:
#
#   C++ surface   #[cxx::bridge] in crates/spine/src/bridge.rs, generated
#                 by polyorch_rust_cxxbridge into <T>-cxx (static lib that
#                 COMPILES the generated .cpp) and consumed by the C++
#                 executable under cpp/ -- the repo's first real C++
#                 executable consumer.
#   C surface     #[no_mangle] extern "C" in c_abi.rs, documented by
#                 polyorch_rust_cbindgen into a C header, installed via
#                 polyorch_rust_install (PUBLIC_HEADER + replay stub) and
#                 consumed by a separate find_package project -- the
#                 installed-binding story.
#
# Also exercises two verbs no other example touches: polyorch_rust_clean
# and polyorch_rust_package_version (the version feeds the demo output).
cmake_minimum_required(VERSION 3.22)

# standalone/embedded gate: same shape as rust-basic (degrade to STATUS
# when embedded without cargo; REQUIRED when the user ran THIS dir).
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    set(_rb_standalone TRUE)
else()
    set(_rb_standalone FALSE)
endif()
if(NOT _rb_standalone AND NOT PolyOrch_BUILD_RUST_EXAMPLES)
    return()
endif()
if(NOT _rb_standalone)
    find_program(PolyOrchExample_gate_cargo NAMES cargo
        PATHS "$ENV{HOME}/.cargo/bin" "$ENV{CARGO_HOME}/bin"
        NO_DEFAULT_PATH)
    if(NOT PolyOrchExample_gate_cargo)
        message(STATUS
            "rust-bindings: needs cargo; not on PATH or in ~/.cargo/bin -- example skipped")
        return()
    endif()
    get_filename_component(PolyOrchExample_gate_bin "${PolyOrchExample_gate_cargo}" DIRECTORY)
    set(PolyOrch_RUST_CARGO_EXECUTABLE "${PolyOrchExample_gate_cargo}" CACHE FILEPATH
        "example gate: cargo found outside PATH" FORCE)
    set(PolyOrch_RUSTC_EXECUTABLE "${PolyOrchExample_gate_bin}/rustc" CACHE FILEPATH
        "example gate: rustc beside the gated cargo" FORCE)
endif()

project(rust-bindings LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
set(PolyOrch_RUST_VSCODE_DEBUG ON)
include(PolyOrchRustHelpers)

polyorch_rust_setup(REQUIRED)

set(SPINE_MANIFEST "${CMAKE_CURRENT_LIST_DIR}/crates/spine/Cargo.toml")

# The crate's version, printed by the demo (package_version exposure).
polyorch_rust_package_version(PACKAGE spine MANIFEST "${SPINE_MANIFEST}" OUT_VAR SPINE_VERSION)
message(STATUS "rust-bindings: spine v${SPINE_VERSION}")

# [1/4] The two handles: staticlib (linked by the C++ app) + the runner bin.
polyorch_rust_build(
    TARGET  spine-static
    PACKAGE spine
    CRATE   spine
    STATIC
    MANIFEST "${SPINE_MANIFEST}")
polyorch_rust_build(
    TARGET  spine-run-bin
    PACKAGE spine
    CRATE   spine
    BINARY
    MANIFEST "${SPINE_MANIFEST}")

# [2/4] C++ bindings: generate the bridge trampolines into spine-static-cxx
# (a static lib that compiles the generated .cpp) and expose the REGEN
# target for the docs' touch-rerun story.
if(PolyOrch_RUST_TARGET_PREFIX)
    set(_regen "${PolyOrch_RUST_TARGET_PREFIX}-rust-bindings-cxx-regen")
else()
    set(_regen "rust-bindings-cxx-regen")
endif()
polyorch_rust_cxxbridge(TARGET spine-static
    FILES bridge.rs   # manifest-src-relative (the surface resolves against <manifest>/src)
    REGEN_TARGET "${_regen}")

# [3/4] The C++ executable consumer: links the generated archive AND the
# rust staticlib, includes the generated bridge header, and implements the
# C++-side bridge function (host_scale).
if(PolyOrch_RUST_TARGET_PREFIX)
    set(_app "${PolyOrch_RUST_TARGET_PREFIX}-rust-bindings-app")
else()
    set(_app "rust-bindings-app")
endif()
add_executable("${_app}" cpp/app/main.cpp)
target_compile_features("${_app}" PRIVATE cxx_std_17)
if(PolyOrch_RUST_FOLDER_ROOT)
    set(_rbfold "${PolyOrch_RUST_FOLDER_ROOT}")
else()
    set(_rbfold "rust-bindings")
endif()
set_target_properties("${_app}" "${_regen}"
    PROPERTIES FOLDER "${_rbfold}")
# the bridge include!("spine/bridge_impl.h") pulls the hand-written
# header into the GENERATED .cpp too -- teach the generated archive where
# it lives (the cxxbridge surface has no include-dir knob; this is the
# crate's own layout)
if(PolyOrch_RUST_TARGET_PREFIX)
    set(_h "${PolyOrch_RUST_TARGET_PREFIX}-spine-static")
    set(_hbin "${PolyOrch_RUST_TARGET_PREFIX}-spine-run-bin")
else()
    set(_h "spine-static")
    set(_hbin "spine-run-bin")
endif()
set(_hcxx "${_h}-cxx")
target_include_directories("${_hcxx}" PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/crates/spine/include")
target_link_libraries("${_app}" PRIVATE "${_hcxx}" "${_h}")
target_include_directories("${_app}" PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/cpp/app"
    # the generated bridge header carries the include!("spine/bridge_impl.h")
    # pull-in, so the consumer needs the crate's include dir too
    "${CMAKE_CURRENT_SOURCE_DIR}/crates/spine/include")
# the generated tree root carries the fusion prefix when fused; spell the
# header's include path from CMake (via the ${_hcxx} target's own include
# dirs) instead of hardcoding it in the source
# the generated tree root is <base>/polyorch_generated/cxxbridge/<_hcxx>;
# the cxxbridge surface's INTERFACE_INCLUDE_DIRECTORIES already points at
# .../include, so add the .../include/<_hcxx> layer for the header
set(_gen_root "${CMAKE_CURRENT_BINARY_DIR}/polyorch_generated/cxxbridge/${_hcxx}/include")
target_include_directories("${_app}" PRIVATE
    "${_gen_root}" "${_gen_root}/${_hcxx}")

# [4/4] The C surface: cbindgen documents the extern "C" plane; install
# stages lib + header + replay stub for the find_package consumer below.
polyorch_rust_cbindgen(TARGET spine-static HEADER_NAME spine.h)
# install the GENERATED header: cbindgen auto mode writes
# polyorch_generated/cbindgen/spine-static/include/spine.h (build-tree
# path -- resolved at install time through the generator expressions the
# cbindgen surface attaches to the handle)
polyorch_rust_install(TARGETS spine-static spine-run-bin
    EXPORT spine-demo
    PUBLIC_HEADER "$<TARGET_PROPERTY:${_h},INTERFACE_INCLUDE_DIRECTORIES>/spine.h"
    ARCHIVE_DESTINATION lib/spine)
if(PolyOrch_RUST_TARGET_PREFIX)
    polyorch_rust_clean(NAME "${PolyOrch_RUST_TARGET_PREFIX}-rust-bindings-clean")
else()
    polyorch_rust_clean(NAME rust-bindings-clean)
endif()

# test-driver artifact contract: declare the artifacts the driver asserts
# NOTE: only config-independent paths here (the driver EXISTS-checks the
# literal at test time; a multi-config binary dir nests Debug/ release/)
set(POLYORCH_FIXTURE_ARTIFACTS
    "manifest=${SPINE_MANIFEST}")
string(JOIN "\n" _af ${POLYORCH_FIXTURE_ARTIFACTS})
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/polyorch-fixture-artifacts.txt" "${_af}\n")

# Self-consumption: a separate consumer project finds the installed
# spine-demo package, compiles against the installed cbindgen header, and
# links the installed static lib -- the installed-binding story.
set(_stage "${CMAKE_CURRENT_BINARY_DIR}/stage")
if(PolyOrch_RUST_TARGET_PREFIX)
    set(_consumer "${PolyOrch_RUST_TARGET_PREFIX}-rust-bindings-consumer")
else()
    set(_consumer "rust-bindings-consumer")
endif()
add_custom_target("${_consumer}"
    # the install copies the built artifacts: build both mediators first
    # (the custom target has no automatic dependency on them)
    COMMAND ${CMAKE_COMMAND} --build "${CMAKE_BINARY_DIR}"
        --target "${_h}-build"
    COMMAND ${CMAKE_COMMAND} --build "${CMAKE_BINARY_DIR}"
        --target "${_hbin}-build"
    COMMAND ${CMAKE_COMMAND} --install "${CMAKE_BINARY_DIR}"
        --prefix "${_stage}"
    COMMAND ${CMAKE_COMMAND}
        -S "${CMAKE_CURRENT_SOURCE_DIR}/consumer"
        -B "${CMAKE_CURRENT_BINARY_DIR}/consumer-build"
        -DCMAKE_PREFIX_PATH=${_stage}
        -DSPINE_LIB=${_h}
    COMMAND ${CMAKE_COMMAND} --build
        "${CMAKE_CURRENT_BINARY_DIR}/consumer-build"
    COMMAND "${CMAKE_CURRENT_BINARY_DIR}/consumer-build/consumer"
    COMMENT "rust-bindings: install(EXPORT) -> find_package consumer -> run")
set_target_properties("${_consumer}" PROPERTIES FOLDER "${_rbfold}")
