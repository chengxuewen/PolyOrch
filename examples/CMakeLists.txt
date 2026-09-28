# PolyOrch examples -- enable with -DPolyOrch_BUILD_EXAMPLES=ON.
#
# Each example also has a PolyOrchExample* target that runs it STANDALONE via
# its documented entry command, mirroring PolyOrchExamplePixiBootstrap. The
# add_subdirectory calls below still prove the nested-embedding path; the
# targets prove the plain `cmake -S`/`-P` entry points and are offline-safe.
# Route-group opt-ins, declared centrally (polyorch_option UI: cache type
# stamp + consistent help). The per-example files CONSUME these (plain if +
# return); they no longer declare their own options.
# Standalone configure support (cmake -S examples): the option helpers live
# in the library; embedded hosts include them before this file runs.
cmake_minimum_required(VERSION 3.22)   # standalone configure support (cmake -S examples)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../cmake")
include(PolyOrchCMakeHelpers)   # polyorch_option lives here (NOT OptionHelpers -- that is the expression helpers)

polyorch_option(PolyOrch_BUILD_RUST_EXAMPLES
    "Include the rust examples (build with the system cargo on PATH)" OFF)
polyorch_option(PolyOrch_BUILD_PIXI_EXAMPLES
    "Register the pixi-route example buttons (may solve; see PolyOrch_PIXI_MIRROR)" OFF)

add_subdirectory(pixi-configure)
add_subdirectory(pixi-workspace)

# Script-mode cold start. Build-time only: it may install pixi and reach the
# network, so it never runs during configure.
add_custom_target(PolyOrchExamplePixiBootstrap
    COMMAND ${CMAKE_COMMAND} -P "${CMAKE_CURRENT_SOURCE_DIR}/pixi-bootstrap/bootstrap.cmake"
    COMMENT "Running the pixi-bootstrap example (may reach the network)")
set_target_properties(PolyOrchExamplePixiBootstrap PROPERTIES FOLDER ${PROJECT_NAME}/examples)

# Read-only consumption during an ordinary configure. Isolated standalone/
# dir: re-configuring the add_subdirectory binary dir as a top-level build
# trips CMakeCache's CMAKE_HOME_DIRECTORY, so the target builds elsewhere.
add_custom_target(PolyOrchExamplePixiConfigure
    COMMAND ${CMAKE_COMMAND}
        -S "${CMAKE_CURRENT_SOURCE_DIR}/pixi-configure"
        -B "${CMAKE_CURRENT_BINARY_DIR}/standalone/pixi-configure"
    COMMENT "Configuring the pixi-configure example standalone (read-only)")
set_target_properties(PolyOrchExamplePixiConfigure PROPERTIES FOLDER ${PROJECT_NAME}/examples)

# Workspace created entirely from CMake args. IF_NOT_EXISTS keeps it
# idempotent across re-runs; it writes only into its own standalone/ build
# dir and reaches no network (install stays a separate explicit step).
add_custom_target(PolyOrchExamplePixiWorkspace
    COMMAND ${CMAKE_COMMAND}
        -S "${CMAKE_CURRENT_SOURCE_DIR}/pixi-workspace"
        -B "${CMAKE_CURRENT_BINARY_DIR}/standalone/pixi-workspace"
    COMMENT "Configuring the pixi-workspace example standalone (writes its build dir; needs pixi)")
set_target_properties(PolyOrchExamplePixiWorkspace PROPERTIES FOLDER ${PROJECT_NAME}/examples)

# Standalone configure + build: the example resolves cargo/rustc from PATH
# (system route, no network, no environment install), then the two build
# invocations compile and execute the artifact.
if(PolyOrch_BUILD_RUST_EXAMPLES AND PolyOrchExample_cargo)
add_custom_target(PolyOrchExampleRustBasic
    COMMAND ${CMAKE_COMMAND}
        -S "${CMAKE_CURRENT_SOURCE_DIR}/rust-basic"
        -B "${CMAKE_CURRENT_BINARY_DIR}/standalone/rust-basic"
    COMMAND ${CMAKE_COMMAND} --build
        "${CMAKE_CURRENT_BINARY_DIR}/standalone/rust-basic" --target cargo-build-greet
    COMMAND ${CMAKE_COMMAND} --build
        "${CMAKE_CURRENT_BINARY_DIR}/standalone/rust-basic" --target greet-run
    COMMENT "rust-basic: system-cargo configure -> cargo build -> run (offline)")
set_target_properties(PolyOrchExampleRustBasic PROPERTIES FOLDER ${PROJECT_NAME}/examples)
else()
    message(STATUS "PolyOrch examples: PolyOrchExampleRustBasic not registered -- set PolyOrch_BUILD_RUST_EXAMPLES=ON (and have cargo on PATH)")
endif()

# P0 examples (dual-route/examples expansion, 2026-09-23): import an EXISTING
# workspace, and the mixed C<->Rust link. GATED registration (matrix pixi-cell
# philosophy): each route's button only exists when that route's toolchain is
# reachable -- a missing cargo/pixi degrades to a STATUS note, never a FATAL
# in the host's configure. The example dirs themselves keep setup(REQUIRED):
# a standalone `cmake -S` without the toolchain SHOULD fail loudly (the
# user's own environment, with the fix in the message).
# The pixi-route buttons materialize envs and may solve (network on first
# run) -- opt-in, symmetric with PolyOrch_BUILD_RUST_EXAMPLES. Registered only
# when this option is set AND the pixi tool is reachable.
option(PolyOrch_BUILD_PIXI_EXAMPLES
    "Register the pixi-route example buttons (PolyOrchExampleRust*Pixi, PixiEnvRun)" OFF)
find_program(PolyOrchExample_cargo NAMES cargo
    PATHS "$ENV{HOME}/.cargo/bin" "$ENV{CARGO_HOME}/bin")
find_program(PolyOrchExample_pixi NAMES pixi
    PATHS "$ENV{HOME}/.pixi/bin" "$ENV{PIXI_HOME}/bin")

# WP12 (2026-09-28, user ruling): system-route examples fuse into the HOST
# graph -- each registers its own verb targets (greet-build/-run/-test shape)
# instead of a remote-control button. Each subtree carries its own
# standalone/embedded gate (cargo probe + STATUS degradation + CACHE FORCE
# injection pair) and names its rust aggregate <example>-rust-all via
# PolyOrch_RUST_AGGREGATE_NAME so three fused subtrees cannot merge into one
# aggregate silently. Pixi-route buttons below stay remote: environment
# materialization (possible network solve) must never sit inside the host
# configure.
if(PolyOrch_BUILD_RUST_EXAMPLES AND PolyOrchExample_cargo)
    foreach(_fused "rust-basic" "rust-import" "rust-link-c" "rust-profile-features")
        # WP13 grammar (user ruling, literal form): handle families carry the
        # FULL directory name as prefix (rust-link-c-cli-user-tool-build),
        # aggregates are <directory>-all (rust-link-c-all) -- no stripped or
        # invented prefixes. Directory scope per iteration; rust-basic joins
        # the loop so its bare greet-* / default aggregate retire.
        set(PolyOrch_RUST_TARGET_PREFIX "${_fused}")
        set(PolyOrch_RUST_AGGREGATE_NAME "${_fused}-all")
        add_subdirectory(${_fused})
    endforeach()
    unset(PolyOrch_RUST_AGGREGATE_NAME)
    unset(PolyOrch_RUST_TARGET_PREFIX)
else()
    message(STATUS "PolyOrch examples: system-route rust examples not fused -- set PolyOrch_BUILD_RUST_EXAMPLES=ON (cargo reachable)")
endif()

# Pixi-route remote buttons (env isolation; see WP12 note above).
foreach(_pair "Import:rust-import:cargo-build-dash_ed:say-run-hi-exe"
              "LinkC:rust-link-c:app:cli-run-user-tool")
    string(REPLACE ":" ";" _p "${_pair}")
    list(GET _p 0 _name)
    list(GET _p 1 _dir)
    list(GET _p 2 _t1)
    list(GET _p 3 _t2)
    if(PolyOrchExample_pixi AND PolyOrch_BUILD_PIXI_EXAMPLES)
        add_custom_target(PolyOrchExampleRust${_name}Pixi
            COMMAND ${CMAKE_COMMAND}
                -S "${CMAKE_CURRENT_SOURCE_DIR}/${_dir}"
                -B "${CMAKE_CURRENT_BINARY_DIR}/standalone/${_dir}-pixi"
                -DPolyOrch_EXAMPLE_ROUTE=ON
            COMMAND ${CMAKE_COMMAND} --build
                "${CMAKE_CURRENT_BINARY_DIR}/standalone/${_dir}-pixi" --target "${_t1}"
            COMMAND ${CMAKE_COMMAND} --build
                "${CMAKE_CURRENT_BINARY_DIR}/standalone/${_dir}-pixi" --target "${_t2}"
            COMMENT "rust-${_name} (pixi route): materialize env -> build -> run (first run solves)")
        set_target_properties(PolyOrchExampleRust${_name}Pixi PROPERTIES
            FOLDER ${PROJECT_NAME}/examples)
    else()
        message(STATUS "PolyOrch examples: PolyOrchExampleRust${_name}Pixi not registered -- no pixi tool")
    endif()
endforeach()

# P1: install/export producer-consumer chain.
if(PolyOrch_BUILD_RUST_EXAMPLES AND PolyOrchExample_cargo)
add_custom_target(PolyOrchExampleRustInstallExport
    COMMAND ${CMAKE_COMMAND}
        -S "${CMAKE_CURRENT_SOURCE_DIR}/rust-install-export/producer"
        -B "${CMAKE_CURRENT_BINARY_DIR}/standalone/rust-install-export"
    COMMAND ${CMAKE_COMMAND} --build
        "${CMAKE_CURRENT_BINARY_DIR}/standalone/rust-install-export" --target cargo-build-mathkit
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
    message(STATUS "PolyOrch examples: PolyOrchExampleRustInstallExport not registered -- set PolyOrch_BUILD_RUST_EXAMPLES=ON (cargo on PATH)")
endif()

# P1: the "what pixi buys you" demo -- materialize an env, run its tools.
if(NOT PolyOrch_BUILD_PIXI_EXAMPLES)
    message(STATUS "PolyOrch examples: PolyOrchExamplePixiEnvRun not registered -- set PolyOrch_BUILD_PIXI_EXAMPLES=ON")
elseif(NOT PolyOrchExample_pixi)
    message(STATUS "PolyOrch examples: PolyOrchExamplePixiEnvRun not registered -- no pixi tool")
else()
add_custom_target(PolyOrchExamplePixiEnvRun
    COMMAND ${CMAKE_COMMAND}
        -S "${CMAKE_CURRENT_SOURCE_DIR}/pixi-env-run"
        -B "${CMAKE_CURRENT_BINARY_DIR}/standalone/pixi-env-run"
        -DPolyOrch_EXAMPLE_ROUTE=ON
    COMMAND ${CMAKE_COMMAND} --build
        "${CMAKE_CURRENT_BINARY_DIR}/standalone/pixi-env-run" --target pixi-cmake-smoke
    COMMENT "pixi-env-run: materialize env -> run env tools (first run solves)")
set_target_properties(PolyOrchExamplePixiEnvRun PROPERTIES FOLDER ${PROJECT_NAME}/examples)
endif()

# P1: the cross-compilation example. Registered ONLY when the demo musl
# target is installed (rustup target list) -- otherwise the note explains.
if(PolyOrch_BUILD_RUST_EXAMPLES AND PolyOrchExample_cargo)
add_custom_target(PolyOrchExampleRustCross
    COMMAND ${CMAKE_COMMAND}
        -S "${CMAKE_CURRENT_SOURCE_DIR}/rust-cross"
        -B "${CMAKE_CURRENT_BINARY_DIR}/standalone/rust-cross"
        -DPolyOrch_RUST_CARGO_TARGET=x86_64-unknown-linux-musl
    COMMAND ${CMAKE_COMMAND} --build
        "${CMAKE_CURRENT_BINARY_DIR}/standalone/rust-cross" --target cargo-build-musl-app-bin
    COMMAND ${CMAKE_COMMAND} --build
        "${CMAKE_CURRENT_BINARY_DIR}/standalone/rust-cross" --target host-run-tool-bin
    COMMENT "rust-cross: --target musl route + hostbuild escape (needs the musl target installed)")
set_target_properties(PolyOrchExampleRustCross PROPERTIES FOLDER ${PROJECT_NAME}/examples)
else()
    message(STATUS "PolyOrch examples: PolyOrchExampleRustCross not registered -- set PolyOrch_BUILD_RUST_EXAMPLES=ON (cargo on PATH)")
endif()
