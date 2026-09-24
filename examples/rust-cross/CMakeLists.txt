# PolyOrch example: CROSS-COMPILING rust -- one configure, two destinations.
# (CMake TARGETs carry a -bin suffix on purpose: a TARGET named like its
# artifact base name trips the PIT-13 configure guard -- same lesson as the
# other examples.)
#
#   PolyOrch_RUST_CARGO_TARGET=x86_64-unknown-linux-musl routes EVERY rust
#   handle's cargo build through --target (artifacts nest under
#   .cargo-target/<triple>/), while polyorch_rust_set_hostbuild opts ONE
#   handle back OUT to the host layer -- the standard shape: cross binaries
#   for the device, host binaries for the build machine, one graph.
#
#   # standalone (the musl target must be installed ONCE):
#   rustup target add x86_64-unknown-linux-musl
#   cmake -S examples/rust-cross -B build \
#       -DPolyOrch_RUST_CARGO_TARGET=x86_64-unknown-linux-musl
#   cmake --build build --target cargo-build-musl-app-bin
#   file build/.cargo-target/x86_64-unknown-linux-musl/debug/musl-app  # ELF, statically linked
#   cmake --build build --target host-run-tool-bin                     # runs on THIS machine
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
            "rust-cross: needs cargo; not on PATH or in ~/.cargo/bin -- example skipped "
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
include(PolyOrchRustHelpers)

if(NOT PolyOrch_RUST_CARGO_TARGET)
    message(STATUS
        "rust-cross: set -DPolyOrch_RUST_CARGO_TARGET=<triple> to see the cross route "
        "(e.g. x86_64-unknown-linux-musl after `rustup target add <triple>`); "
        "configuring without one -- everything below is a host no-op by design")
endif()

polyorch_rust_setup(REQUIRED)

# The DEVICE binary: routed to the target triple (default when the cache var
# is set). Static musl output is the classic cross first-run.
polyorch_rust_build(
    TARGET musl-app-bin PACKAGE musl-app CRATE musl-app BINARY
    MANIFEST "${CMAKE_CURRENT_LIST_DIR}/crates/musl-app/Cargo.toml")

# The BUILD-MACHINE binary: opted back out of the cross route. While the
# route is active the setter suppresses --target for this handle only and
# its artifacts land in the host layer instead of the <triple> nesting.
polyorch_rust_build(
    TARGET host-tool-bin PACKAGE host-tool CRATE host-tool BINARY
    MANIFEST "${CMAKE_CURRENT_LIST_DIR}/crates/host-tool/Cargo.toml")
polyorch_rust_set_hostbuild(TARGET host-tool-bin)

polyorch_rust_run(TARGET host-tool-bin)
