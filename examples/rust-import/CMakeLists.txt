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
#   cmake --build build --target run-say-hi-exe         # build + run the binary
#
#   # embedded in a host that has PolyOrch_BUILD_EXAMPLES=ON:
#   gated by PolyOrch_RUST_EXAMPLES (same as rust-basic)
cmake_minimum_required(VERSION 3.22)

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    set(_rust_standalone TRUE)
else()
    set(_rust_standalone FALSE)
    option(PolyOrch_RUST_EXAMPLES
        "Include the rust examples (build with the system cargo on PATH)" OFF)
endif()
if(NOT _rust_standalone AND NOT PolyOrch_RUST_EXAMPLES)
    return()
endif()

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
include(PolyOrchRustHelpers)

# [1/3] System route: cargo/rustc from PATH (offline; no install, no pin).
polyorch_rust_setup(REQUIRED)

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
