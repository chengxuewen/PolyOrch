# PolyOrch example: a MIXED project -- CMake C code and Rust code linking
# each other, both directions, one build graph.
#
#   direction 1 (Rust lib consumed by C):
#     polyorch_rust_build(... STATIC) builds `geometry` into a C-ABI static
#     library. The setup()'s native-static-libs probe attaches the Rust
#     toolchain's system libs (libm etc.) to the imported target's link
#     INTERFACE -- so the plain `target_link_libraries(app geometry)` just
#     works, no manual system-lib list.
#   direction 2 (C lib consumed by Rust):
#     polyorch_rust_link_libraries(cli-user <c-lib-target>) converts the CMake
#     static library target into -L/-l on the cargo link line -- the Rust
#     binary's `extern "C"` declarations resolve against it.
#
#   # standalone:
#   cmake -S examples/rust-link-c -B build
#   cmake --build build --target app            # C exe <- Rust staticlib
#   ./build/app
#   cmake --build build --target cli-run-user   # Rust bin <- C staticlib
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
            "rust-link-c: needs cargo; not on PATH or in ~/.cargo/bin -- example skipped "
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

project(rust-link-c LANGUAGES C)   # the C half is a first-class citizen here

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
include(PolyOrchPixiHelpers)
# F5 out of the box: generate VSCode debug configs for this example's run
# targets (WP11 surface; the library default stays OFF -- see the WP11 note in examples/README.md)
set(PolyOrch_RUST_VSCODE_DEBUG ON)
include(PolyOrchRustHelpers)

# Route selection: same build graph on either route (see rust-import for the
# long form). system = default (PATH); EXAMPLE_PIXI=ON materializes the pixi
# env declared in pixi.toml and switches the route (explicit, once).
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

# --- direction 1: Rust staticlib -> C executable ---------------------------
polyorch_rust_build(
    TARGET  geometry
    PACKAGE geometry
    CRATE   geometry
    STATIC
    MANIFEST "${CMAKE_CURRENT_LIST_DIR}/rs/Cargo.toml")

# add_executable(app app.c)
# target_link_libraries(app PRIVATE geometry)   # + the probed system libs, automatically

# --- direction 2: C staticlib -> Rust binary -------------------------------
# Hand-written targets in a FUSED subtree follow the same grammar as the
# rust ones (WP13): <directory>-<semantic-name>, plus an explicit FOLDER --
# an unprefixed bare name can collide with the host's own targets, and a
# missing FOLDER leaves the node floating outside the family in the IDE tree.
add_library(rust-link-c-cfn STATIC c_fn.c)   # the rust side links this by name below
file(RELATIVE_PATH CURRENT_DIR_REL
     "${CMAKE_SOURCE_DIR}"
     "${CMAKE_CURRENT_SOURCE_DIR}")
set_target_properties(rust-link-c-cfn PROPERTIES FOLDER ${CURRENT_DIR_REL})
# NOTE: the CMake TARGET (`cli-user-tool`) deliberately differs from the
# artifact base name (`cli-user`, the [[package]] name): an IMPORTED target
# named like its output file makes the Makefile generator silently swallow
# the producing rule (PIT-13 -- the configure FATALs to teach this).
polyorch_rust_build(
    TARGET  cli-user-tool
    PACKAGE cli-user
    CRATE   cli-user
    BINARY
    MANIFEST "${CMAKE_CURRENT_LIST_DIR}/rs/bin/Cargo.toml")
polyorch_rust_link_libraries(TARGET cli-user-tool rust-link-c-cfn)
polyorch_rust_run(TARGET cli-user-tool)
