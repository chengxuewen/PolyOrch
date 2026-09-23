# PolyOrch example: steer ONE Rust package from CMake -- profile, features,
# env vars, rustflags, cargo flags. All five knobs, one graph, offline.
#
#   # standalone:
#   cmake -S examples/rust-profile-features -B build
#   cmake --build build --target demo-debug     # no features, env var, debug
#   cmake --build build --target run-demo-debug     # -> profile=debug env=hey
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

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
include(PolyOrchRustHelpers)

polyorch_rust_setup(REQUIRED)
set(_fl "${PROJECT_NAME}/examples/rust-profile-features")

# --- handle A: the kitchen-sink debug build ---------------------------------
polyorch_rust_build(
    FOLDER ${_fl} TARGET demo PACKAGE feature-demo CRATE feature-demo
    BINARY PROFILE debug
    MANIFEST "${CMAKE_CURRENT_LIST_DIR}/crate/Cargo.toml")

# FEATURES: opt-in cfg arms. NO_DEFAULT_FEATURES would strip the implicit set.
polyorch_rust_set_features(TARGET demo FEATURES greet-loud greet-formal)

# ENV VARS: write-through -- each call REPLACES the whole set (a call with
# nothing clears it), entries must spell VAR=VALUE.
polyorch_rust_set_env_vars(TARGET demo POLYORCH_DEMO_GREETING=hey)

# --- handle B: the release build, rustflags + cargo flags -------------------
polyorch_rust_build(
    FOLDER ${_fl} TARGET demo-rel PACKAGE feature-demo CRATE feature-demo
    BINARY PROFILE release
    MANIFEST "${CMAKE_CURRENT_LIST_DIR}/crate/Cargo.toml")

# RUSTFLAGS: raw rustc flags on every compile of this handle.
# ENV VARS on this handle too (env! bakes at compile time: a handle WITHOUT
# the var FAILS TO COMPILE -- the channel is real, not ambient).
polyorch_rust_set_env_vars(TARGET demo-rel POLYORCH_DEMO_GREETING=fast)
polyorch_rust_add_rustflags(TARGET demo-rel FLAGS -C debuginfo=0)
# CARGO_FLAGS: extra cargo command-line flags on this handle's builds.
polyorch_rust_add_cargo_flags(TARGET demo-rel FLAGS --quiet)

polyorch_rust_run(FOLDER ${_fl} TARGET demo)
polyorch_rust_run(FOLDER ${_fl} TARGET demo-rel)
