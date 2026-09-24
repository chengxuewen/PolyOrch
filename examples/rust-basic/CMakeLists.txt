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
#   cmake --build build --target greet-run       # execute the artifact
#   cmake --build build --target greet-test      # cargo test
#
#   # embedded in a host that has PolyOrch_BUILD_EXAMPLES=ON:
#   cmake ... -DPolyOrch_BUILD_RUST_EXAMPLES=ON        # otherwise this file returns early
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
endif()
if(NOT _rust_standalone AND NOT PolyOrch_BUILD_RUST_EXAMPLES)
    return()
endif()
# Opt-in ON but the tool unreachable in THIS configure's PATH (a GUI-launched
# IDE does not inherit the shell's ~/.cargo/bin): degrade to a note, never
# FATAL -- same philosophy as the umbrella registration layer. Standalone
# keeps setup(REQUIRED): the user explicitly ran THIS example, so a missing
# cargo is their environment's problem, with the fix in the message.
if(NOT _rust_standalone)
    # Probe what setup actually accepts: PATH *plus* the cargo-home
    # locations (find_program would union them anyway -- the mismatch was
    # that setup's system route in THIS configure sees a PATH without them;
    # the honest gate mirrors the umbrella: tool reachable at all?)
    find_program(PolyOrchExample_gate_cargo NAMES cargo
        PATHS "$ENV{HOME}/.cargo/bin" "$ENV{CARGO_HOME}/bin"
        NO_DEFAULT_PATH)
    if(NOT PolyOrchExample_gate_cargo)
        message(STATUS
            "rust-basic: needs cargo; not on PATH or in ~/.cargo/bin -- example skipped "
            "(standalone runs still get the loud REQUIRED error)")
        return()
    endif()
    # Found OUTSIDE PATH: feed setup the injection pair (WP2 knobs), because
    # the system route's own discovery only trusts PATH in this configure.
    get_filename_component(PolyOrchExample_gate_bin "${PolyOrchExample_gate_cargo}" DIRECTORY)
    # CACHE: setup() is a function -- plain variables are invisible there;
    # the injection pair is documented as cache entries anyway.
    set(PolyOrch_RUST_CARGO_EXECUTABLE "${PolyOrchExample_gate_cargo}" CACHE FILEPATH
        "example gate: cargo found outside PATH" FORCE)
    set(PolyOrch_RUSTC_EXECUTABLE "${PolyOrchExample_gate_bin}/rustc" CACHE FILEPATH
        "example gate: rustc beside the gated cargo" FORCE)
endif()

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
# F5 out of the box: generate VSCode debug configs for this example's run
# targets (WP11 surface; the library default stays OFF -- see the WP11 note in examples/README.md)
set(PolyOrch_RUST_VSCODE_DEBUG ON)
include(PolyOrchRustHelpers)

# [1/4] Locate the toolchain (system route, the default). In embedded mode
#         this writes the route into the HOST cache -- the fusion cost,
#         accepted by the opt-in knob.
polyorch_rust_setup(REQUIRED)

# [2/4] Wrap cargo. The CMake imported target is named `greet` while the
#         built binary's file base name is `greet-cli` (the [[bin]] name).
#         They are kept DISTINCT on purpose: an IMPORTED target whose name
#         equals its artifact base name makes the Makefile generator silently
#         drop the rule that produces the binary (PIT-13). `cargo-build-greet`
#         (the mediator) is what you build; `greet` is what you link/inspect.
#
#         EMBEDDED MODE = GRAPH FUSION (2026-09-23 pilot): when included by
#         the examples umbrella with the opt-in ON and the tool reachable,
#         these calls run RIGHT HERE -- cargo-build-greet / greet-test /
#         greet-run become real targets in the HOST build graph (clickable
#         individually, DEPENDS-able from host targets). The umbrella
#         PolyOrchExampleRustBasic target stays as the standalone-tree demo.
polyorch_rust_build(
    TARGET  greet
    PACKAGE greet-cli
    CRATE   greet-cli
    BINARY
    MANIFEST "${CMAKE_CURRENT_LIST_DIR}/Cargo.toml")

# [3/4] test + run wrappers for the same crate.
polyorch_rust_test(
    PACKAGE greet-cli
    NAME greet-test
    TARGET greet)
    
polyorch_rust_run(
    TARGET greet)
