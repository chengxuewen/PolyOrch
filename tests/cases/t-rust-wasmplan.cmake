# requires: system-rust
# T-G2 probes pinned as unit cases (2026-10-12): the wasm family's linker and
# test routing. Two fixes live-paired by the probe round, both one-line-class:
#   1. linker_plan: wasm joins msvc in the no-C-linker-plane branch (the elf
#      default-pick filled CARGO_TARGET_WASM32_*_LINKER with the host c++;
#      rustc answered "couldn't extract file stem from specified linker").
#   2. polyorch_rust_test: wasm triples test on the HOST (cargo test
#      --target=wasm32 builds .wasm harnesses then fails executing them;
#      os error 8, measured). Host routing keeps the web-lane mirror tests
#      (host node tests) reachable through the same button.
# Pure-table legs (no cargo needed beyond discovery); the e2e half lives in
# t-rust-wasm.cmake's stack-gated legs.
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")

polyorch_rust_setup(FROM system)
if(NOT POLYORCH_RUST_FOUND)
    message(STATUS "t-rust-wasmplan : SKIP (no system rust)")
    return()
endif()

# ---- leg 1: linker_plan refuses a linker plane for wasm families ----------
foreach(_tr wasm32-unknown-unknown wasm32-wasip1 wasm64-unknown-unknown)
    _polyorch_rust_linker_plan(TRIPLE "${_tr}"
        OUT_ENV_NAME _n OUT_VALUE _v OUT_WRAPPER _w OUT_WRAPPER_CONTENT _wc
        OUT_RUNNER _r)
    if(_n OR _v OR _w)
        message(FATAL_ERROR
            "t-rust-wasmplan: ${_tr} produced a linker plane (name=${_n} val=${_v} wrap=${_w}) -- the elf default-pick regression is back")
    endif()
endforeach()

# ---- leg 2: the msvc shape is unchanged (same branch, regression guard) ---
_polyorch_rust_linker_plan(TRIPLE x86_64-pc-windows-msvc
    OUT_ENV_NAME _n OUT_VALUE _v OUT_WRAPPER _w OUT_RUNNER _r)
if(_n OR _v OR _w)
    message(FATAL_ERROR "t-rust-wasmplan: msvc lost its no-linker-plane shape")
endif()

# ---- leg 3: elf cross still HAS a plane (the musl route must survive) -----
set(PolyOrch_RUST_LINKER_X86_64_UNKNOWN_LINUX_MUSL "/usr/bin/musl-gcc")
_polyorch_rust_linker_plan(TRIPLE x86_64-unknown-linux-musl
    OUT_ENV_NAME _n OUT_VALUE _v OUT_WRAPPER _w OUT_WRAPPER_CONTENT _wc
    OUT_RUNNER _r)
if(NOT _n MATCHES "CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_LINKER"
        OR NOT _v STREQUAL "/usr/bin/musl-gcc")
    message(FATAL_ERROR
        "t-rust-wasmplan: elf cross linker plane broken (n=${_n} v=${_v}) -- the wasm carve-out ate the musl route")
endif()
unset(PolyOrch_RUST_LINKER_X86_64_UNKNOWN_LINUX_MUSL)

# ---- leg 4: triple_family keeps classifying wasm (D29 shape unchanged) ----
foreach(_tr wasm32-unknown-unknown wasm32-wasip1 wasm64-unknown-unknown)
    set(_fam "")
    _polyorch_rust_triple_family("${_tr}" _fam)
    if(NOT _fam STREQUAL "wasm")
        message(FATAL_ERROR "t-rust-wasmplan: ${_tr} classified '${_fam}' (expected wasm)")
    endif()
endforeach()

message(STATUS "t-rust-wasmplan : all 4 legs green (wasm has no linker plane; elf route intact; msvc unchanged)")
