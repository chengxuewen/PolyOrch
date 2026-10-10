# rust-wasm -- "web frontends consume a rust crate via an npm package" (WP18).
#
# wasm-pack produces the STANDARD npm deliverable (pkg/: the .wasm, the ES
# module glue, .d.ts typings, package.json) -- what a web frontend
# `npm install`s. Two target flavors are produced here:
#   bundler -- for vite/webpack (the web default)
#   nodejs  -- synchronous require(), what the local demo runs
# The wasm32 target and the wasm-bindgen CLI version must pair (the crate
# pins 0.2.100; wasm-pack installs its own matching CLI when allowed).
cmake_minimum_required(VERSION 3.22)

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    set(_rwa_standalone TRUE)
else()
    set(_rwa_standalone FALSE)
endif()
if(NOT _rwa_standalone AND NOT PolyOrch_BUILD_RUST_EXAMPLES)
    return()
endif()
if(NOT _rwa_standalone)
    find_program(PolyOrchExample_gate_cargo NAMES cargo
        PATHS "$ENV{HOME}/.cargo/bin" "$ENV{CARGO_HOME}/bin"
        NO_DEFAULT_PATH)
    if(NOT PolyOrchExample_gate_cargo)
        message(STATUS
            "rust-wasm: needs cargo; not on PATH or in ~/.cargo/bin -- example skipped")
        return()
    endif()
    get_filename_component(PolyOrchExample_gate_bin "${PolyOrchExample_gate_cargo}" DIRECTORY)
    set(PolyOrch_RUST_CARGO_EXECUTABLE "${PolyOrchExample_gate_cargo}" CACHE FILEPATH
        "example gate: cargo found outside PATH" FORCE)
    set(PolyOrch_RUSTC_EXECUTABLE "${PolyOrchExample_gate_bin}/rustc" CACHE FILEPATH
        "example gate: rustc beside the gated cargo" FORCE)
endif()

project(rust-wasm LANGUAGES NONE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
include(PolyOrchRustHelpers)

polyorch_rust_setup(REQUIRED)

set(POLYORCH_FIXTURE_ARTIFACTS
    "manifest=${CMAKE_CURRENT_LIST_DIR}/crates/spine-wasm/Cargo.toml")
string(JOIN "\n" _af ${POLYORCH_FIXTURE_ARTIFACTS})
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/polyorch-fixture-artifacts.txt" "${_af}\n")

# prerequisites (all three are PATH-discovered, STATUS-degraded when absent):
#   1. wasm32-unknown-unknown target (rustup target add)
#   2. wasm-pack (cargo install wasm-pack) -- both rules pin
#      --mode no-install --dev: the PATH wasm-bindgen is used as-is,
#      --dev skips the wasm-opt pass, so nothing is ever fetched
#      (restricted egress; the pkg ships unoptimized; the demo asserts
#      values, not size).
#   3. wasm-bindgen CLI 0.2.100 on PATH (pairs with the crate pin).
set(_wbg_ver 0.2.100)
find_program(PolyOrchRustWasmPack wasm-pack)
if(NOT PolyOrchRustWasmPack)
    message(STATUS
        "rust-wasm: demo not registered -- no wasm-pack on PATH "
        "(cargo install wasm-pack)")
    return()
endif()
find_program(PolyOrchRustWasmBindgen wasm-bindgen)
if(NOT PolyOrchRustWasmBindgen)
    message(STATUS
        "rust-wasm: demo not registered -- no wasm-bindgen on PATH "
        "(cargo install wasm-bindgen-cli --locked --version ${_wbg_ver})")
    return()
endif()
execute_process(COMMAND rustup target list --installed
    OUTPUT_VARIABLE _rtgt ERROR_QUIET)
string(FIND "${_rtgt}" "wasm32-unknown-unknown" _haswasm)
if(_haswasm LESS 0)
    message(STATUS
        "rust-wasm: demo not registered -- wasm32-unknown-unknown not installed "
        "(rustup target add wasm32-unknown-unknown)")
    return()
endif()

if(PolyOrch_RUST_FOLDER_ROOT)
    set(_rwafold "${PolyOrch_RUST_FOLDER_ROOT}")
else()
    file(RELATIVE_PATH _rwafold
        "${CMAKE_SOURCE_DIR}"
        "${CMAKE_CURRENT_SOURCE_DIR}")
endif()

# [1/3] bundler flavor: the web deliverable (pkg/ under the build tree)
set(_pkg_web "${CMAKE_CURRENT_BINARY_DIR}/pkg-web")
add_custom_target(rust-wasm-pkg-bundler
    COMMAND "${PolyOrchRustWasmPack}" build --target bundler
        --mode no-install --dev
        --out-dir "${_pkg_web}" --out-name spine_wasm
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/crates/spine-wasm"
    BYPRODUCTS "${_pkg_web}/spine_wasm_bg.wasm"
    COMMENT "wasm-pack: bundler pkg/ (web deliverable)")
set_target_properties(rust-wasm-pkg-bundler PROPERTIES FOLDER "${_rwafold}")

# [2/3] nodejs flavor: synchronous require(), what the demo runs
set(_pkg_node "${CMAKE_CURRENT_BINARY_DIR}/pkg-node")
add_custom_target(rust-wasm-pkg-nodejs
    COMMAND "${PolyOrchRustWasmPack}" build --target nodejs
        --mode no-install --dev
        --out-dir "${_pkg_node}" --out-name spine_wasm
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/crates/spine-wasm"
    BYPRODUCTS "${_pkg_node}/spine_wasm_bg.wasm"
    COMMENT "wasm-pack: nodejs pkg/")
set_target_properties(rust-wasm-pkg-nodejs PROPERTIES FOLDER "${_rwafold}")

# [3/3] the demo: node imports the nodejs pkg and asserts the API
find_program(PolyOrchRustNodeExe node)
if(NOT PolyOrchRustNodeExe)
    file(GLOB PolyOrchRustNodeExe
        "/tmp/opencode/*/.pixi/envs/default/bin/node"
        "/tmp/opencode/*/pixi/envs/default/bin/node")
    list(LENGTH PolyOrchRustNodeExe _pn2)
    if(_pn2 GREATER 0)
        list(GET PolyOrchRustNodeExe 0 PolyOrchRustNodeExe)
    endif()
endif()
if(NOT PolyOrchRustNodeExe)
    message(STATUS
        "rust-wasm: demo not registered -- no node on PATH "
        "(pass -DPolyOrchRustNodeExe=<path>, e.g. a pixi env's bin/node)")
    return()
endif()
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/hello.mjs"
"import { add, greet } from \"./pkg-node/spine_wasm.js\";
const sum = add(19, 23);
if (sum !== 42) throw new Error(\"add(19,23) = \" + sum);
console.log(\"wasm:\", greet(\"consumer\"), \"| add(19,23) =\", sum);
")
add_custom_target(rust-wasm-demo
    COMMAND "${PolyOrchRustNodeExe}" "${CMAKE_CURRENT_BINARY_DIR}/hello.mjs"
    DEPENDS rust-wasm-pkg-nodejs
    WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
    COMMENT "wasm: node imports the nodejs pkg/ (add(19,23) == 42)")
set_target_properties(rust-wasm-demo PROPERTIES FOLDER "${_rwafold}")

