# rust-nodejs -- "Node.js consumes a rust addon" (WP17).
#
# A napi-rs cdylib: N-API's stable ABI means NO node headers and NO node
# library link -- the crate is a plain cargo build. The artifact is
# renamed to the node addon convention (spine-node.node) by the demo
# target locally and by install's LANGUAGE_PRODUCT node permanently.
# Node itself comes from the system PATH when available.
cmake_minimum_required(VERSION 3.22)

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    set(_rnj_standalone TRUE)
else()
    set(_rnj_standalone FALSE)
endif()
if(NOT _rnj_standalone AND NOT PolyOrch_BUILD_RUST_EXAMPLES)
    return()
endif()
if(NOT _rnj_standalone)
    find_program(PolyOrchExample_gate_cargo NAMES cargo
        PATHS "$ENV{HOME}/.cargo/bin" "$ENV{CARGO_HOME}/bin"
        NO_DEFAULT_PATH)
    if(NOT PolyOrchExample_gate_cargo)
        message(STATUS
            "rust-nodejs: needs cargo; not on PATH or in ~/.cargo/bin -- example skipped")
        return()
    endif()
    get_filename_component(PolyOrchExample_gate_bin "${PolyOrchExample_gate_cargo}" DIRECTORY)
    set(PolyOrch_RUST_CARGO_EXECUTABLE "${PolyOrchExample_gate_cargo}" CACHE FILEPATH
        "example gate: cargo found outside PATH" FORCE)
    set(PolyOrch_RUSTC_EXECUTABLE "${PolyOrchExample_gate_bin}/rustc" CACHE FILEPATH
        "example gate: rustc beside the gated cargo" FORCE)
endif()

project(rust-nodejs LANGUAGES NONE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
include(PolyOrchRustHelpers)

polyorch_rust_setup(REQUIRED)

polyorch_rust_build(
    TARGET  spine-node
    PACKAGE spine-node
    CRATE   spine_node   # the [lib] name -- drives the .so artifact name
    SHARED
    MANIFEST "${CMAKE_CURRENT_LIST_DIR}/crates/spine-node/Cargo.toml")

# node presence is a DEMO concern (the crate builds and installs fine
# without it). Discovery order: system PATH, then ~/.pixi/bin's envs are
# NOT auto-probed -- pass NodeExe explicitly (a pixi env bin/node) when
# node only lives there. The demo stages the .node addon beside hello.mjs
# (node addon naming: no lib prefix, .node suffix).
set(PolyOrchRustNodeExe "" CACHE FILEPATH "node executable for the rust-nodejs demo")
if(NOT PolyOrchRustNodeExe)
    find_program(PolyOrchRustNodeExe node)
endif()
if(PolyOrchRustNodeExe)
    # demo follows the directory grammar: prefixed when fused (standalone,
    # PolyOrch_RUST_TARGET_PREFIX is empty -> bare name)
    if(PolyOrch_RUST_TARGET_PREFIX)
        set(_demo "${PolyOrch_RUST_TARGET_PREFIX}-spine-node-demo")
    else()
        set(_demo "spine-node-demo")
    endif()
    add_custom_target("${_demo}"
        COMMAND ${CMAKE_COMMAND} -E copy
            "$<TARGET_FILE:spine-node>"
            "${CMAKE_CURRENT_SOURCE_DIR}/consumer/spine-node.node"
        COMMAND "${PolyOrchRustNodeExe}" "${CMAKE_CURRENT_SOURCE_DIR}/consumer/hello.mjs"
        DEPENDS spine-node-build
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/consumer"
        COMMENT "node: require spine-node (consumer/hello.mjs)")
    set_target_properties("${_demo}" PROPERTIES FOLDER
        "${PolyOrch_RUST_FOLDER_ROOT}")
else()
    message(STATUS
        "rust-nodejs: demo not registered -- no node on PATH "
        "(pass -DPolyOrchRustNodeExe=<path>, e.g. a pixi env's bin/node)")
endif()

polyorch_rust_clean(NAME rust-nodejs-clean)

set(POLYORCH_FIXTURE_ARTIFACTS
    "manifest=${CMAKE_CURRENT_LIST_DIR}/crates/spine-node/Cargo.toml")
string(JOIN "\n" _af ${POLYORCH_FIXTURE_ARTIFACTS})
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/polyorch-fixture-artifacts.txt" "${_af}\n")
