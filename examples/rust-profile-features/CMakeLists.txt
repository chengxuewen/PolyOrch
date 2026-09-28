# PolyOrch example: steer ONE Rust package from CMake -- profile, features,
# env vars, rustflags, cargo flags. All five knobs, one graph, offline.
#
#   # standalone:
#   cmake -S examples/rust-profile-features -B build
#   cmake --build build --target demo-debug     # no features, env var, debug
#   cmake --build build --target demo-run-debug     # -> profile=debug env=hey
#   cmake --build build --target demo-release   # --release + feature + rustflag
#   ./build/.cargo-target-release/release/feature-demo
cmake_minimum_required(VERSION 3.22)

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
            "rust-profile-features: needs cargo; not on PATH or in ~/.cargo/bin -- example skipped "
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

polyorch_rust_setup(REQUIRED)
set(_fl "${PROJECT_NAME}/examples/rust-profile-features")

# --- handle A: the kitchen-sink debug build ---------------------------------
polyorch_rust_build( TARGET demo PACKAGE feature-demo CRATE feature-demo
    BINARY PROFILE debug
    MANIFEST "${CMAKE_CURRENT_LIST_DIR}/crate/Cargo.toml")

# FEATURES: opt-in cfg arms. NO_DEFAULT_FEATURES would strip the implicit set.
polyorch_rust_set_features(TARGET demo FEATURES greet-loud greet-formal)

# ENV VARS: write-through -- each call REPLACES the whole set (a call with
# nothing clears it), entries must spell VAR=VALUE.
polyorch_rust_set_env_vars(TARGET demo POLYORCH_DEMO_GREETING=hey)

# --- handle B: the release build, rustflags + cargo flags -------------------
polyorch_rust_build( TARGET demo-rel PACKAGE feature-demo CRATE feature-demo
    BINARY PROFILE release
    MANIFEST "${CMAKE_CURRENT_LIST_DIR}/crate/Cargo.toml")

# RUSTFLAGS: raw rustc flags on every compile of this handle.
# ENV VARS on this handle too (env! bakes at compile time: a handle WITHOUT
# the var FAILS TO COMPILE -- the channel is real, not ambient).
polyorch_rust_set_env_vars(TARGET demo-rel POLYORCH_DEMO_GREETING=fast)
polyorch_rust_add_rustflags(TARGET demo-rel FLAGS -C debuginfo=0)
# CARGO_FLAGS: extra cargo command-line flags on this handle's builds.
polyorch_rust_add_cargo_flags(TARGET demo-rel FLAGS --quiet)

polyorch_rust_run(TARGET demo)
polyorch_rust_run(TARGET demo-rel)
