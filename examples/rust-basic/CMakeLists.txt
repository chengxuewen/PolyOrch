# PolyOrch example: build and run a Rust package through the rust helpers.
#
# System route (since WP2): polyorch_rust_setup() takes cargo/rustc from
# PATH -- the toolchain is a runtime/environment concern, nothing here
# installs or pins it (the pixi route is a coverage route, not an example
# need). Configure reaches no network.
#
#   # standalone:
#   cmake -S examples/rust-basic -B build
#   cmake --build build --target greet-cargo     # cargo build  -> .../greet-cli
#   cmake --build build --target run-greet       # execute the artifact
#   cmake --build build --target greet-test      # cargo test
#
#   # embedded in a host that has PolyOrch_BUILD_EXAMPLES=ON:
#   cmake ... -DPolyOrch_RUST_EXAMPLES=ON        # otherwise this file returns early
cmake_minimum_required(VERSION 3.22)

# --- opt-in gate (runs before project()) -----------------------------------
# A host turning PolyOrch_BUILD_EXAMPLES=ON must NOT inherit a network-
# bootstrapping rust target in its list; the parent's add_subdirectory(rust-basic)
# becomes a no-op here unless the host explicitly opts in.  A direct
# `cmake -S examples/rust-basic` (CMAKE_SOURCE_DIR == this dir) always proceeds.
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    set(_rust_standalone TRUE)
else()
    set(_rust_standalone FALSE)
    option(PolyOrch_RUST_EXAMPLES
        "Include the rust-basic example (builds with the system cargo on PATH)" OFF)
endif()
if(NOT _rust_standalone AND NOT PolyOrch_RUST_EXAMPLES)
    return()
endif()

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
include(PolyOrchRustHelpers)

# [1/4] Locate the toolchain on PATH (system route, the default). A host
#         without cargo gets the REQUIRED FATAL naming exactly that fix --
#         pinning/switching the toolchain is an environment concern (a
#         rustup override, a shell, a pixi env), not this example's.
polyorch_rust_setup(REQUIRED)

# [2/4] Wrap cargo. The CMake imported target is named `greet` while the
#         built binary's file base name is `greet-cli` (the [[bin]] name).
#         They are kept DISTINCT on purpose: an IMPORTED target whose name
#         equals its artifact base name makes the Makefile generator silently
#         drop the rule that produces the binary (PIT-13). `greet-cargo`
#         (the mediator) is what you build; `greet` is what you link/inspect.
polyorch_rust_build(
    FOLDER  "${PROJECT_NAME}/examples/rust-basic"
    TARGET  greet
    PACKAGE greet-cli
    CRATE   greet-cli
    BINARY)

# [3/4] test + run wrappers for the same crate.
polyorch_rust_test(
    FOLDER "${PROJECT_NAME}/examples/rust-basic"
    PACKAGE greet-cli 
    NAME greet-test)
polyorch_rust_run(
    FOLDER "${PROJECT_NAME}/examples/rust-basic"
    TARGET greet)
