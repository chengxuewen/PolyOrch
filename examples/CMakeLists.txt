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
#   REMOTE -- a single pixi-*/<example-dir> button target that runs the example in its
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
    foreach(_fused "rust-basic" "rust-import" "rust-link-c" "rust-profile-features"
                   "rust-bindings" "rust-cpp-lib" "rust-pyext" "rust-nodejs"
                   "node-web" "python-basic")
        # D28: fused targets carry the polyorch- namespace (a bare
        # <dir>-... name in a host tree invites collisions). The prefix
        # is resolved HERE, at the loop entry, while PROJECT_NAME is
        # still the host's name: <HOST>_POLYORCH_TARGET_PREFIX wins if
        # defined (multi-checkout / nested-embedding override), else
        # the polyorch-<directory> default. The unset() moves INSIDE
        # the loop (Momus blocker 1): a one-shot trailing unset made
        # `if(NOT DEFINED)` true only for iteration 1 -- iterations 2+
        # would silently inherit iteration 1's prefix, and the
        # aggregate would silently merge via the helper's NOT-TARGET
        # guard. Empty string disables the prefix deliberately.
        if(NOT DEFINED _host_prefix)
            if(DEFINED ${PROJECT_NAME}_POLYORCH_TARGET_PREFIX)
                set(_host_prefix "${${PROJECT_NAME}_POLYORCH_TARGET_PREFIX}")
            else()
                set(_host_prefix "")
            endif()
        endif()
        if(_host_prefix STREQUAL "")
            set(PolyOrch_RUST_TARGET_PREFIX "polyorch-${_fused}")
            set(PolyOrch_RUST_AGGREGATE_NAME "polyorch-${_fused}-all")
            # A2 (D29): the node face has its OWN knob -- the name says NODE.
            # Same value, separate variable: neither surface's naming lies.
            set(PolyOrch_NODE_TARGET_PREFIX "polyorch-${_fused}")
            # D32: python face owns its knob too (A2 symmetry, node flavor).
            set(PolyOrch_PYTHON_TARGET_PREFIX "polyorch-${_fused}")
        else()
            set(PolyOrch_RUST_TARGET_PREFIX "${_host_prefix}-${_fused}")
            set(PolyOrch_RUST_AGGREGATE_NAME "${_host_prefix}-${_fused}-all")
            set(PolyOrch_NODE_TARGET_PREFIX "${_host_prefix}-${_fused}")
            set(PolyOrch_PYTHON_TARGET_PREFIX "${_host_prefix}-${_fused}")
        endif()
        # one IDE root for the whole fused family, under the buttons' group
        set(PolyOrch_RUST_FOLDER_ROOT "${PROJECT_NAME}/examples/${_fused}")
        add_subdirectory(${_fused})
        unset(PolyOrch_RUST_TARGET_PREFIX)
        unset(PolyOrch_NODE_TARGET_PREFIX)
        unset(PolyOrch_PYTHON_TARGET_PREFIX)
        unset(PolyOrch_RUST_AGGREGATE_NAME)
        unset(PolyOrch_RUST_FOLDER_ROOT)
    endforeach()
    unset(_host_prefix)
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

# polyorch-pixi-bootstrap: script-mode cold start. Build-time only: may install pixi
# and reach the network, so it never runs during configure.
if(PolyOrchExample_pixi)
    add_custom_target(polyorch-pixi-bootstrap
        COMMAND ${CMAKE_COMMAND} -P "${CMAKE_CURRENT_SOURCE_DIR}/polyorch-pixi-bootstrap/bootstrap.cmake"
        COMMENT "Running the polyorch-pixi-bootstrap example (may reach the network)")
    set_target_properties(polyorch-pixi-bootstrap PROPERTIES FOLDER ${PROJECT_NAME}/examples)
else()
    message(STATUS
        "PolyOrch examples: polyorch-pixi-bootstrap not registered "
        "-- needs pixi (PATH or ~/.pixi/bin); option gate: PolyOrch_BUILD_PIXI_EXAMPLES")
endif()

# polyorch-pixi-configure: read-only standalone configure.
if(PolyOrchExample_pixi)
    add_custom_target(polyorch-pixi-configure
        COMMAND ${CMAKE_COMMAND}
            -S "${CMAKE_CURRENT_SOURCE_DIR}/polyorch-pixi-configure"
            -B "${CMAKE_CURRENT_BINARY_DIR}/standalone/polyorch-pixi-configure"
        COMMENT "Configuring the polyorch-pixi-configure example standalone (read-only)")
    set_target_properties(polyorch-pixi-configure PROPERTIES FOLDER ${PROJECT_NAME}/examples)
else()
    message(STATUS
        "PolyOrch examples: polyorch-pixi-configure not registered "
        "-- needs pixi (PATH or ~/.pixi/bin); option gate: PolyOrch_BUILD_PIXI_EXAMPLES")
endif()

# polyorch-pixi-workspace: writes only into its own standalone/ build dir, no network.
if(PolyOrchExample_pixi)
    add_custom_target(polyorch-pixi-workspace
        COMMAND ${CMAKE_COMMAND}
            -S "${CMAKE_CURRENT_SOURCE_DIR}/polyorch-pixi-workspace"
            -B "${CMAKE_CURRENT_BINARY_DIR}/standalone/polyorch-pixi-workspace"
        COMMENT "Configuring the polyorch-pixi-workspace example standalone (writes its build dir; needs pixi)")
    set_target_properties(polyorch-pixi-workspace PROPERTIES FOLDER ${PROJECT_NAME}/examples)
else()
    message(STATUS
        "PolyOrch examples: polyorch-pixi-workspace not registered "
        "-- needs pixi (PATH or ~/.pixi/bin); option gate: PolyOrch_BUILD_PIXI_EXAMPLES")
endif()

# polyorch-pixi-env-run: "what pixi buys you" -- materialize an env, run its tools.
# Route value is the literal "pixi" (the examples gate on STREQUAL "pixi").
if(PolyOrchExample_pixi AND PolyOrch_BUILD_PIXI_EXAMPLES)
    add_custom_target(polyorch-pixi-env-run
        COMMAND ${CMAKE_COMMAND}
            -S "${CMAKE_CURRENT_SOURCE_DIR}/polyorch-pixi-env-run"
            -B "${CMAKE_CURRENT_BINARY_DIR}/standalone/polyorch-pixi-env-run"
            -DPolyOrch_EXAMPLE_ROUTE=pixi
        COMMAND ${CMAKE_COMMAND} --build
            "${CMAKE_CURRENT_BINARY_DIR}/standalone/polyorch-pixi-env-run" --target pixi-cmake-smoke
        COMMENT "polyorch-pixi-env-run: materialize env -> run env tools (first run solves)")
    set_target_properties(polyorch-pixi-env-run PROPERTIES FOLDER ${PROJECT_NAME}/examples)
else()
    message(STATUS
        "PolyOrch examples: polyorch-pixi-env-run not registered "
        "-- set PolyOrch_BUILD_PIXI_EXAMPLES=ON AND have pixi (PATH or ~/.pixi/bin)")
endif()

# rust-import, pixi route: import an EXISTING workspace from the env.
if(PolyOrchExample_pixi AND PolyOrch_BUILD_PIXI_EXAMPLES)
    add_custom_target(polyorch-rust-import-pixi
        COMMAND ${CMAKE_COMMAND}
            -S "${CMAKE_CURRENT_SOURCE_DIR}/rust-import"
            -B "${CMAKE_CURRENT_BINARY_DIR}/standalone/polyorch-rust-import-pixi"
            -DPolyOrch_EXAMPLE_ROUTE=pixi
        COMMAND ${CMAKE_COMMAND} --build
            "${CMAKE_CURRENT_BINARY_DIR}/standalone/polyorch-rust-import-pixi" --target dash_ed-build
        COMMAND ${CMAKE_COMMAND} --build
            "${CMAKE_CURRENT_BINARY_DIR}/standalone/polyorch-rust-import-pixi" --target say-hi-exe-run
        COMMENT "rust-import (pixi route): materialize env -> build -> run (first run solves)")
    set_target_properties(polyorch-rust-import-pixi PROPERTIES
        FOLDER ${PROJECT_NAME}/examples)
else()
    message(STATUS
        "PolyOrch examples: polyorch-rust-import-pixi not registered "
        "-- set PolyOrch_BUILD_PIXI_EXAMPLES=ON AND have pixi (PATH or ~/.pixi/bin)")
endif()

# rust-link-c, pixi route: the mixed C<->Rust link from the env.
if(PolyOrchExample_pixi AND PolyOrch_BUILD_PIXI_EXAMPLES)
    add_custom_target(polyorch-rust-link-c-pixi
        COMMAND ${CMAKE_COMMAND}
            -S "${CMAKE_CURRENT_SOURCE_DIR}/rust-link-c"
            -B "${CMAKE_CURRENT_BINARY_DIR}/standalone/polyorch-rust-link-c-pixi"
            -DPolyOrch_EXAMPLE_ROUTE=pixi
        COMMAND ${CMAKE_COMMAND} --build
            "${CMAKE_CURRENT_BINARY_DIR}/standalone/polyorch-rust-link-c-pixi" --target cli-user-tool-build
        COMMAND ${CMAKE_COMMAND} --build
            "${CMAKE_CURRENT_BINARY_DIR}/standalone/polyorch-rust-link-c-pixi" --target cli-user-tool-run
        COMMENT "rust-link-c (pixi route): materialize env -> build -> run (first run solves)")
    set_target_properties(polyorch-rust-link-c-pixi PROPERTIES
        FOLDER ${PROJECT_NAME}/examples)
else()
    message(STATUS
        "PolyOrch examples: polyorch-rust-link-c-pixi not registered "
        "-- set PolyOrch_BUILD_PIXI_EXAMPLES=ON AND have pixi (PATH or ~/.pixi/bin)")
endif()

# polyorch-rust-install-export: the producer/consumer chain via install(EXPORT).
if(PolyOrch_BUILD_RUST_EXAMPLES AND PolyOrchExample_cargo)
    add_custom_target(polyorch-rust-install-export
        COMMAND ${CMAKE_COMMAND}
            -S "${CMAKE_CURRENT_SOURCE_DIR}/polyorch-rust-install-export/producer"
            -B "${CMAKE_CURRENT_BINARY_DIR}/standalone/polyorch-rust-install-export"
        COMMAND ${CMAKE_COMMAND} --build
            "${CMAKE_CURRENT_BINARY_DIR}/standalone/polyorch-rust-install-export" --target mathkit-build
        COMMAND ${CMAKE_COMMAND} --install
            "${CMAKE_CURRENT_BINARY_DIR}/standalone/polyorch-rust-install-export"
            --prefix "${CMAKE_CURRENT_BINARY_DIR}/standalone/polyorch-rust-install-export-stage"
        COMMAND ${CMAKE_COMMAND}
            -S "${CMAKE_CURRENT_SOURCE_DIR}/polyorch-rust-install-export/consumer"
            -B "${CMAKE_CURRENT_BINARY_DIR}/standalone/polyorch-rust-install-export-consumer"
            -DCMAKE_PREFIX_PATH=${CMAKE_CURRENT_BINARY_DIR}/standalone/polyorch-rust-install-export-stage
        COMMAND ${CMAKE_COMMAND} --build
            "${CMAKE_CURRENT_BINARY_DIR}/standalone/polyorch-rust-install-export-consumer"
        COMMENT "polyorch-rust-install-export: build -> install(EXPORT) -> find_package consumer (offline)")
    set_target_properties(polyorch-rust-install-export PROPERTIES FOLDER ${PROJECT_NAME}/examples)
else()
    message(STATUS
        "PolyOrch examples: polyorch-rust-install-export not registered "
        "-- set PolyOrch_BUILD_RUST_EXAMPLES=ON AND have cargo reachable "
        "(PATH or ~/.cargo/bin)")
endif()

# polyorch-rust-cross: cross route + hostbuild escape. Stays REMOTE by design: the
# musl artifacts cannot run on the build machine (no run verb), and the
# configure needs the musl target installed -- a prerequisite a host
# configure must not inherit.
if(PolyOrch_BUILD_RUST_EXAMPLES AND PolyOrchExample_cargo)
    add_custom_target(polyorch-rust-cross
        COMMAND ${CMAKE_COMMAND}
            -S "${CMAKE_CURRENT_SOURCE_DIR}/polyorch-rust-cross"
            -B "${CMAKE_CURRENT_BINARY_DIR}/standalone/polyorch-rust-cross"
            -DPolyOrch_RUST_CARGO_TARGET=x86_64-unknown-linux-musl
        COMMAND ${CMAKE_COMMAND} --build
            "${CMAKE_CURRENT_BINARY_DIR}/standalone/polyorch-rust-cross" --target musl-app-bin-build
        COMMAND ${CMAKE_COMMAND} --build
            "${CMAKE_CURRENT_BINARY_DIR}/standalone/polyorch-rust-cross" --target host-tool-bin-run
        COMMENT "polyorch-rust-cross: --target musl route + hostbuild escape (needs the musl target installed)")
    set_target_properties(polyorch-rust-cross PROPERTIES FOLDER ${PROJECT_NAME}/examples)
else()
    message(STATUS
        "PolyOrch examples: polyorch-rust-cross not registered "
        "-- set PolyOrch_BUILD_RUST_EXAMPLES=ON AND have cargo reachable "
        "(PATH or ~/.cargo/bin)")
endif()

# rust-bindings: the flagship binding example's full chain -- fused verb
# targets already exist in this tree; this button additionally runs the
# install(EXPORT) -> find_package consumer story end to end.
if(PolyOrch_BUILD_RUST_EXAMPLES AND PolyOrchExample_cargo)
    add_custom_target(polyorch-rust-bindings-standalone
        COMMAND ${CMAKE_COMMAND}
            -S "${CMAKE_CURRENT_SOURCE_DIR}/rust-bindings"
            -B "${CMAKE_CURRENT_BINARY_DIR}/standalone/rust-bindings"
        COMMAND ${CMAKE_COMMAND} --build
            "${CMAKE_CURRENT_BINARY_DIR}/standalone/rust-bindings" --target rust-bindings-app
        COMMAND ${CMAKE_COMMAND} --build
            "${CMAKE_CURRENT_BINARY_DIR}/standalone/rust-bindings" --target rust-bindings-consumer
        COMMENT "rust-bindings: cxx bridge + cbindgen + install(EXPORT) -> find_package consumer")
    set_target_properties(polyorch-rust-bindings-standalone PROPERTIES FOLDER ${PROJECT_NAME}/examples)
else()
    message(STATUS
        "PolyOrch examples: polyorch-rust-bindings-standalone not registered "
        "-- set PolyOrch_BUILD_RUST_EXAMPLES=ON AND have cargo reachable "
        "(PATH or ~/.cargo/bin)")
endif()
