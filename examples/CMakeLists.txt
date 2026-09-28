# PolyOrch examples -- enable with -DPolyOrch_BUILD_EXAMPLES=ON.
#
# ============================================================================
# How to read this file
# ============================================================================
# Two kinds of example surfaces live here:
#
#   FUSED  -- system-route rust examples join the HOST build graph. Each
#             subtree registers its own verb targets; no button exists.
#             Naming grammar (WP13, literal directory names):
#               handle family:  <directory>-<handle>-<verb>
#               aggregate:      <directory>-all
#             Example: rust-link-c-cli-user-tool-build / rust-link-c-all.
#
#   REMOTE -- a single PolyOrchExample* button that runs the example in its
#             OWN build dir (standalone/<name>), never inside the host
#             configure. Used when the example has side effects a host
#             configure must not absorb: pixi environment materialization
#             (may solve on first run = network), install/export staging,
#             or cross toolchain prerequisites.
#
# Gate idiom (uniform everywhere below):
#   if(<route option> AND <tool probe found>) register
#   else() one STATUS naming BOTH conditions
# Subtrees reached via add_subdirectory keep their own standalone/embedded
# gate (tool probe + STATUS degradation + CACHE FORCE injection pair).
#
# Standalone configure support (cmake -S examples): the option helpers live
# in the library; embedded hosts include them before this file runs.
# ============================================================================
cmake_minimum_required(VERSION 3.22)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../cmake")
include(PolyOrchCMakeHelpers)   # polyorch_option lives here (NOT OptionHelpers -- that is the expression helpers)

# ---- options (single declaration point) ------------------------------------
polyorch_option(PolyOrch_BUILD_RUST_EXAMPLES
    "Include the rust examples (build with the system cargo on PATH)" OFF)
polyorch_option(PolyOrch_BUILD_PIXI_EXAMPLES
    "Register the pixi-route example buttons (may solve; see PolyOrch_PIXI_MIRROR)" OFF)

# ---- tool probes (nothing above needs them) ---------------------------------
find_program(PolyOrchExample_cargo NAMES cargo
    PATHS "$ENV{HOME}/.cargo/bin" "$ENV{CARGO_HOME}/bin")
find_program(PolyOrchExample_pixi NAMES pixi
    PATHS "$ENV{HOME}/.pixi/bin" "$ENV{PIXI_HOME}/bin")

# ============================================================================
# FUSED -- system-route rust examples (in the host graph, no buttons)
# ============================================================================
if(PolyOrch_BUILD_RUST_EXAMPLES AND PolyOrchExample_cargo)
    foreach(_fused "rust-basic" "rust-import" "rust-link-c" "rust-profile-features")
        # WP13: full directory name as prefix, <directory>-all aggregates.
        # Directory scope per iteration.
        set(PolyOrch_RUST_TARGET_PREFIX "${_fused}")
        set(PolyOrch_RUST_AGGREGATE_NAME "${_fused}-all")
        add_subdirectory(${_fused})
    endforeach()
    unset(PolyOrch_RUST_AGGREGATE_NAME)
    unset(PolyOrch_RUST_TARGET_PREFIX)
else()
    message(STATUS
        "PolyOrch examples: system-route rust examples not fused "
        "-- set PolyOrch_BUILD_RUST_EXAMPLES=ON AND have cargo reachable "
        "(PATH or ~/.cargo/bin)")
endif()

# ============================================================================
# EMBEDDED MOUNTS -- pixi examples without a route-option gate
# ============================================================================
# These two consume pixi READ-ONLY at configure time (find + setup(REPORT))
# and degrade on tool absence themselves; PolyOrch_BUILD_PIXI_EXAMPLES does
# not apply to them (it gates buttons that materialize environments).
add_subdirectory(pixi-configure)
add_subdirectory(pixi-workspace)

# ============================================================================
# REMOTE BUTTONS -- one block per example (own build dir, never host-side)
# ============================================================================

# pixi-bootstrap: script-mode cold start. Build-time only: may install pixi
# and reach the network, so it never runs during configure.
if(PolyOrchExample_pixi)
    add_custom_target(PolyOrchExamplePixiBootstrap
        COMMAND ${CMAKE_COMMAND} -P "${CMAKE_CURRENT_SOURCE_DIR}/pixi-bootstrap/bootstrap.cmake"
        COMMENT "Running the pixi-bootstrap example (may reach the network)")
    set_target_properties(PolyOrchExamplePixiBootstrap PROPERTIES FOLDER ${PROJECT_NAME}/examples)
else()
    message(STATUS
        "PolyOrch examples: PolyOrchExamplePixiBootstrap not registered "
        "-- needs pixi (PATH or ~/.pixi/bin); option gate: PolyOrch_BUILD_PIXI_EXAMPLES")
endif()

# pixi-configure: read-only standalone configure.
if(PolyOrchExample_pixi)
    add_custom_target(PolyOrchExamplePixiConfigure
        COMMAND ${CMAKE_COMMAND}
            -S "${CMAKE_CURRENT_SOURCE_DIR}/pixi-configure"
            -B "${CMAKE_CURRENT_BINARY_DIR}/standalone/pixi-configure"
        COMMENT "Configuring the pixi-configure example standalone (read-only)")
    set_target_properties(PolyOrchExamplePixiConfigure PROPERTIES FOLDER ${PROJECT_NAME}/examples)
else()
    message(STATUS
        "PolyOrch examples: PolyOrchExamplePixiConfigure not registered "
        "-- needs pixi (PATH or ~/.pixi/bin); option gate: PolyOrch_BUILD_PIXI_EXAMPLES")
endif()

# pixi-workspace: writes only into its own standalone/ build dir, no network.
if(PolyOrchExample_pixi)
    add_custom_target(PolyOrchExamplePixiWorkspace
        COMMAND ${CMAKE_COMMAND}
            -S "${CMAKE_CURRENT_SOURCE_DIR}/pixi-workspace"
            -B "${CMAKE_CURRENT_BINARY_DIR}/standalone/pixi-workspace"
        COMMENT "Configuring the pixi-workspace example standalone (writes its build dir; needs pixi)")
    set_target_properties(PolyOrchExamplePixiWorkspace PROPERTIES FOLDER ${PROJECT_NAME}/examples)
else()
    message(STATUS
        "PolyOrch examples: PolyOrchExamplePixiWorkspace not registered "
        "-- needs pixi (PATH or ~/.pixi/bin); option gate: PolyOrch_BUILD_PIXI_EXAMPLES")
endif()

# pixi-env-run: "what pixi buys you" -- materialize an env, run its tools.
# Route value is the literal "pixi" (the examples gate on STREQUAL "pixi").
if(PolyOrchExample_pixi AND PolyOrch_BUILD_PIXI_EXAMPLES)
    add_custom_target(PolyOrchExamplePixiEnvRun
        COMMAND ${CMAKE_COMMAND}
            -S "${CMAKE_CURRENT_SOURCE_DIR}/pixi-env-run"
            -B "${CMAKE_CURRENT_BINARY_DIR}/standalone/pixi-env-run"
            -DPolyOrch_EXAMPLE_ROUTE=pixi
        COMMAND ${CMAKE_COMMAND} --build
            "${CMAKE_CURRENT_BINARY_DIR}/standalone/pixi-env-run" --target pixi-cmake-smoke
        COMMENT "pixi-env-run: materialize env -> run env tools (first run solves)")
    set_target_properties(PolyOrchExamplePixiEnvRun PROPERTIES FOLDER ${PROJECT_NAME}/examples)
else()
    message(STATUS
        "PolyOrch examples: PolyOrchExamplePixiEnvRun not registered "
        "-- set PolyOrch_BUILD_PIXI_EXAMPLES=ON AND have pixi (PATH or ~/.pixi/bin)")
endif()

# rust-import, pixi route: import an EXISTING workspace from the env.
if(PolyOrchExample_pixi AND PolyOrch_BUILD_PIXI_EXAMPLES)
    add_custom_target(PolyOrchExampleRustImportPixi
        COMMAND ${CMAKE_COMMAND}
            -S "${CMAKE_CURRENT_SOURCE_DIR}/rust-import"
            -B "${CMAKE_CURRENT_BINARY_DIR}/standalone/rust-import-pixi"
            -DPolyOrch_EXAMPLE_ROUTE=pixi
        COMMAND ${CMAKE_COMMAND} --build
            "${CMAKE_CURRENT_BINARY_DIR}/standalone/rust-import-pixi" --target dash_ed-build
        COMMAND ${CMAKE_COMMAND} --build
            "${CMAKE_CURRENT_BINARY_DIR}/standalone/rust-import-pixi" --target say-hi-exe-run
        COMMENT "rust-import (pixi route): materialize env -> build -> run (first run solves)")
    set_target_properties(PolyOrchExampleRustImportPixi PROPERTIES
        FOLDER ${PROJECT_NAME}/examples)
else()
    message(STATUS
        "PolyOrch examples: PolyOrchExampleRustImportPixi not registered "
        "-- set PolyOrch_BUILD_PIXI_EXAMPLES=ON AND have pixi (PATH or ~/.pixi/bin)")
endif()

# rust-link-c, pixi route: the mixed C<->Rust link from the env.
if(PolyOrchExample_pixi AND PolyOrch_BUILD_PIXI_EXAMPLES)
    add_custom_target(PolyOrchExampleRustLinkCPixi
        COMMAND ${CMAKE_COMMAND}
            -S "${CMAKE_CURRENT_SOURCE_DIR}/rust-link-c"
            -B "${CMAKE_CURRENT_BINARY_DIR}/standalone/rust-link-c-pixi"
            -DPolyOrch_EXAMPLE_ROUTE=pixi
        COMMAND ${CMAKE_COMMAND} --build
            "${CMAKE_CURRENT_BINARY_DIR}/standalone/rust-link-c-pixi" --target cli-user-tool-build
        COMMAND ${CMAKE_COMMAND} --build
            "${CMAKE_CURRENT_BINARY_DIR}/standalone/rust-link-c-pixi" --target cli-user-tool-run
        COMMENT "rust-link-c (pixi route): materialize env -> build -> run (first run solves)")
    set_target_properties(PolyOrchExampleRustLinkCPixi PROPERTIES
        FOLDER ${PROJECT_NAME}/examples)
else()
    message(STATUS
        "PolyOrch examples: PolyOrchExampleRustLinkCPixi not registered "
        "-- set PolyOrch_BUILD_PIXI_EXAMPLES=ON AND have pixi (PATH or ~/.pixi/bin)")
endif()

# rust-install-export: the producer/consumer chain via install(EXPORT).
if(PolyOrch_BUILD_RUST_EXAMPLES AND PolyOrchExample_cargo)
    add_custom_target(PolyOrchExampleRustInstallExport
        COMMAND ${CMAKE_COMMAND}
            -S "${CMAKE_CURRENT_SOURCE_DIR}/rust-install-export/producer"
            -B "${CMAKE_CURRENT_BINARY_DIR}/standalone/rust-install-export"
        COMMAND ${CMAKE_COMMAND} --build
            "${CMAKE_CURRENT_BINARY_DIR}/standalone/rust-install-export" --target mathkit-build
        COMMAND ${CMAKE_COMMAND} --install
            "${CMAKE_CURRENT_BINARY_DIR}/standalone/rust-install-export"
            --prefix "${CMAKE_CURRENT_BINARY_DIR}/standalone/rust-install-export-stage"
        COMMAND ${CMAKE_COMMAND}
            -S "${CMAKE_CURRENT_SOURCE_DIR}/rust-install-export/consumer"
            -B "${CMAKE_CURRENT_BINARY_DIR}/standalone/rust-install-export-consumer"
            -DCMAKE_PREFIX_PATH=${CMAKE_CURRENT_BINARY_DIR}/standalone/rust-install-export-stage
        COMMAND ${CMAKE_COMMAND} --build
            "${CMAKE_CURRENT_BINARY_DIR}/standalone/rust-install-export-consumer"
        COMMENT "rust-install-export: build -> install(EXPORT) -> find_package consumer (offline)")
    set_target_properties(PolyOrchExampleRustInstallExport PROPERTIES FOLDER ${PROJECT_NAME}/examples)
else()
    message(STATUS
        "PolyOrch examples: PolyOrchExampleRustInstallExport not registered "
        "-- set PolyOrch_BUILD_RUST_EXAMPLES=ON AND have cargo reachable "
        "(PATH or ~/.cargo/bin)")
endif()

# rust-cross: cross route + hostbuild escape. Stays REMOTE by design: the
# musl artifacts cannot run on the build machine (no run verb), and the
# configure needs the musl target installed -- a prerequisite a host
# configure must not inherit.
if(PolyOrch_BUILD_RUST_EXAMPLES AND PolyOrchExample_cargo)
    add_custom_target(PolyOrchExampleRustCross
        COMMAND ${CMAKE_COMMAND}
            -S "${CMAKE_CURRENT_SOURCE_DIR}/rust-cross"
            -B "${CMAKE_CURRENT_BINARY_DIR}/standalone/rust-cross"
            -DPolyOrch_RUST_CARGO_TARGET=x86_64-unknown-linux-musl
        COMMAND ${CMAKE_COMMAND} --build
            "${CMAKE_CURRENT_BINARY_DIR}/standalone/rust-cross" --target musl-app-bin-build
        COMMAND ${CMAKE_COMMAND} --build
            "${CMAKE_CURRENT_BINARY_DIR}/standalone/rust-cross" --target host-tool-bin-run
        COMMENT "rust-cross: --target musl route + hostbuild escape (needs the musl target installed)")
    set_target_properties(PolyOrchExampleRustCross PROPERTIES FOLDER ${PROJECT_NAME}/examples)
else()
    message(STATUS
        "PolyOrch examples: PolyOrchExampleRustCross not registered "
        "-- set PolyOrch_BUILD_RUST_EXAMPLES=ON AND have cargo reachable "
        "(PATH or ~/.cargo/bin)")
endif()
