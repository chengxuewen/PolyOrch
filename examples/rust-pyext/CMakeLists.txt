# rust-pyext -- "python consumes a rust extension module" (WP16).
#
# ONE cdylib crate exposing #[pymodule] functions; the module is installed
# under its python import name (LANGUAGE_PRODUCT python strips cargo's
# lib prefix), and a demo target runs the consumer script against it.
# PyO3 with abi3-py38 needs no libpython link and no interpreter headers;
# the interpreter (system or a pixi env's) only drives pyo3's version
# checks -- wired here via polyorch_rust_pyext's PYO3_PYTHON env.
cmake_minimum_required(VERSION 3.22)

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    set(_rpx_standalone TRUE)
else()
    set(_rpx_standalone FALSE)
endif()
if(NOT _rpx_standalone AND NOT PolyOrch_BUILD_RUST_EXAMPLES)
    return()
endif()
if(NOT _rpx_standalone)
    find_program(PolyOrchExample_gate_cargo NAMES cargo
        PATHS "$ENV{HOME}/.cargo/bin" "$ENV{CARGO_HOME}/bin"
        NO_DEFAULT_PATH)
    if(NOT PolyOrchExample_gate_cargo)
        message(STATUS
            "rust-pyext: needs cargo; not on PATH or in ~/.cargo/bin -- example skipped")
        return()
    endif()
    get_filename_component(PolyOrchExample_gate_bin "${PolyOrchExample_gate_cargo}" DIRECTORY)
    set(PolyOrch_RUST_CARGO_EXECUTABLE "${PolyOrchExample_gate_cargo}" CACHE FILEPATH
        "example gate: cargo found outside PATH" FORCE)
    set(PolyOrch_RUSTC_EXECUTABLE "${PolyOrchExample_gate_bin}/rustc" CACHE FILEPATH
        "example gate: rustc beside the gated cargo" FORCE)
endif()

project(rust-pyext LANGUAGES NONE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
include(PolyOrchRustHelpers)

polyorch_rust_setup(REQUIRED)

polyorch_rust_build(
    TARGET  spine-py
    PACKAGE spine-py
    CRATE   spine_py   # the [lib] name -- drives the .so artifact name
    SHARED
    MANIFEST "${CMAKE_CURRENT_LIST_DIR}/crates/spine-py/Cargo.toml")

# system-route demo (python3 from PATH); a pixi env's python can be passed
# via PIXI_ENV (WP16 polyorch_rust_pyext resolves env bin/python).
polyorch_rust_pyext(TARGET spine-py MODULE spine_py)   # MODULE = the python import name
polyorch_rust_clean(NAME rust-pyext-clean)

set(POLYORCH_FIXTURE_ARTIFACTS
    "manifest=${CMAKE_CURRENT_LIST_DIR}/crates/spine-py/Cargo.toml")
string(JOIN "\n" _af ${POLYORCH_FIXTURE_ARTIFACTS})
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/polyorch-fixture-artifacts.txt" "${_af}\n")
