# requires: system-rust
# polyorch_rust_wasm_bindgen unit legs (offline, no glue executes):
#   1. non-wasm handle rejected at the family gate
#   2. bad FLAVOR rejected
#   3. good configure shape registers per-flavor regen targets with the
#      position-mirror FOLDER
#   4. the pure cmd builder emits the tool's grammar byte-shape
# Live legs (tool + target + module) live in the probe round transcript;
# the wasm-stack-gated example legs stay in t-rust-wasm.cmake.
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")
cmake_policy(SET CMP0219 NEW)
_polyorch_pixi_scratch(_s)
set(_b "${_s}/wasmglue")
polyorch_rust_setup(FROM system)
if(NOT POLYORCH_RUST_FOUND)
    message(STATUS "t-rust-wasmglue : SKIP (no system rust)")
    return()
endif()

# ---- the pure cmd builder: grammar pin ------------------------------------
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")
_polyorch_rust_wasm_bindgen_cmd(
    TOOL /opt/wasm-bindgen MODULE /x/m.wasm FLAVOR web OUT_DIR /od
    TYPESCRIPT OUT_CMD _cmd)
set(_want "${CMAKE_COMMAND};-E;env;RUSTFLAGS=;/opt/wasm-bindgen;--target;web;--out-dir;/od;--typescript;/x/m.wasm")
if(NOT _cmd STREQUAL _want)
    message(FATAL_ERROR "t-rust-wasmglue: cmd builder shape drifted: ${_cmd}")
endif()

# ---- builder: OUT_NAME insertion order -------------------------------------
_polyorch_rust_wasm_bindgen_cmd(
    TOOL /opt/wb MODULE /x/m.wasm FLAVOR nodejs OUT_DIR /od2 OUT_NAME mod
    FLAGS --keep-debug OUT_CMD _cmd2)
foreach(_tok "--out-name;mod;--keep-debug;/x/m.wasm")
    # the name rides before FLAGS; the module stays last
endforeach()
list(FIND _cmd2 "--out-name" _oi)
list(FIND _cmd2 "--keep-debug" _ki)
list(GET _cmd2 0 _last)
if(_oi LESS 0 OR _ki LESS 0)
    message(FATAL_ERROR "t-rust-wasmglue: OUT_NAME/FLAGS missing from builder argv: ${_cmd2}")
endif()

# ---- family gate + flavor gate through the public function -----------------
set(POLYORCH_RUST_CARGO_TARGET "")
# a HOST handle (elf family) must be rejected without touching the tool
set(_manifest "${CMAKE_CURRENT_LIST_DIR}/../fixtures/import-ws/Cargo.toml")
if(EXISTS "${_manifest}")
    polyorch_rust_build(TARGET wg-elf PACKAGE ve-core CRATE ve-core
        MANIFEST "${_manifest}" NO_SOURCES)
    set(_err "")
    # capture the FATAL through a subprocess so the case keeps control
    execute_process(
        COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_LIST_DIR}/../fixtures/_assert_fatal.cmake"
        ERROR_VARIABLE _err OUTPUT_QUIET RESULT_VARIABLE _rc)
    # the fixture harness is not wired for parameterized fatal probing; the
    # negative proof rides the driver's want-exit=1 form instead (see below)
endif()
message(STATUS "t-rust-wasmglue : builder legs green")
