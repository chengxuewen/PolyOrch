# PolyOrch example: import an EXISTING cargo workspace and drive it from CMake.
#
# The most common starting point: you already have Rust code (a workspace
# with a staticlib member and a bin member) and want CMake to build and
# consume it without changing it. polyorch_rust_import reads the workspace
# with `cargo metadata`, creates one imported handle per member following
# the naming contract (dashes -> underscores for libs, "-exe" for bins),
# and wires mediators you can add to any build graph.
#
#   # standalone:
#   cmake -S examples/rust-import -B build
#   cmake --build build --target cargo-build-dash_ed    # build the staticlib member
#   cmake --build build --target cargo-build-say-hi-exe # build the bin member
#   cmake --build build --target say-run-hi-exe         # build + run the binary
#
#   # embedded in a host that has PolyOrch_BUILD_EXAMPLES=ON:
#   gated by PolyOrch_BUILD_RUST_EXAMPLES (same as rust-basic)
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
            "rust-import: needs cargo; not on PATH or in ~/.cargo/bin -- example skipped "
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
include(PolyOrchPixiHelpers)
include(PolyOrchRustHelpers)

# Route selection (dual-route examples, 2026-09-23): the SAME 30 lines of
# build logic below run on EITHER route -- the mode is a single option.
#   default        system route: cargo/rustc from PATH (offline, no install)
#   EXAMPLE_PIXI=ON pixi route: this manifest declares rust; the env is
#                  materialized HERE (explicit, may reach the network once)
# Domestic network? add -DPolyOrch_PIXI_MIRROR=cn (TUNA conda-forge mirror)
set(PolyOrch_EXAMPLE_ROUTE "" CACHE STRING
    "example toolchain route: empty/'system' = system PATH, 'pixi' = pixi env (domestic network: also -DPolyOrch_PIXI_MIRROR=cn)")
    # note: set() inside the example would shadow the user's -D; use the cache
    # value directly -- empty means system.
    if(PolyOrch_EXAMPLE_ROUTE STREQUAL "pixi")
    set(POLYORCH_PIXI_ENVIRONMENTS_DIR "${CMAKE_BINARY_DIR}/pixi-envs")
    polyorch_pixi_setup(MANIFEST "${CMAKE_CURRENT_LIST_DIR}/pixi.toml" ENVIRONMENT rust)
    polyorch_pixi_dependency(DEPENDS rust FEATURE rust NO_INSTALL)
    polyorch_pixi_install(ENVIRONMENT rust)
    polyorch_rust_setup(FROM pixi REQUIRED)
else()
    polyorch_rust_setup(REQUIRED)
endif()

# [2/3] Import the whole workspace. Handles:
#         dash-ed  staticlib -> imported target `dash_ed`   (+ cargo-build-dash_ed mediator)
#         say-hi   bin       -> imported target `say-hi-exe` (+ cargo-build-say-hi-exe mediator)
#       SKIPPED_TARGETS catches members polyorch cannot map (e.g. plain libs
#       with no C-ABI) so one odd member never breaks the import.
polyorch_rust_import(
    FOLDER "${PROJECT_NAME}/examples/rust-import"
    MANIFEST "${CMAKE_CURRENT_LIST_DIR}/ws-rs/Cargo.toml"
    IMPORTED_TARGETS imported_handles
    SKIPPED_TARGETS skipped_handles)

# Show what the import created (visible in the configure log):
message(STATUS "rust-import: handles = ${imported_handles}")
message(STATUS "rust-import: skipped = ${skipped_handles}")

# [3/3] Consume like any CMake target: polyorch_rust_run registers the
#         `run-<handle>` wrapper (build + execute), the lib links by name.
polyorch_rust_run(FOLDER "${PROJECT_NAME}/examples/rust-import" TARGET say-hi-exe)
