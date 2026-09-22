# PolyOrch examples -- enable with -DPolyOrch_BUILD_EXAMPLES=ON.
#
# Each example also has a PolyOrchExample* target that runs it STANDALONE via
# its documented entry command, mirroring PolyOrchExamplePixiBootstrap. The
# add_subdirectory calls below still prove the nested-embedding path; the
# targets prove the plain `cmake -S`/`-P` entry points and are offline-safe.
add_subdirectory(pixi-configure)
add_subdirectory(pixi-workspace)
add_subdirectory(rust-basic)

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
add_custom_target(PolyOrchExampleRustBasic
    COMMAND ${CMAKE_COMMAND}
        -S "${CMAKE_CURRENT_SOURCE_DIR}/rust-basic"
        -B "${CMAKE_CURRENT_BINARY_DIR}/standalone/rust-basic"
    COMMAND ${CMAKE_COMMAND} --build
        "${CMAKE_CURRENT_BINARY_DIR}/standalone/rust-basic" --target greet-cargo
    COMMAND ${CMAKE_COMMAND} --build
        "${CMAKE_CURRENT_BINARY_DIR}/standalone/rust-basic" --target run-greet
    COMMENT "rust-basic: system-cargo configure -> cargo build -> run (offline)")
set_target_properties(PolyOrchExampleRustBasic PROPERTIES FOLDER ${PROJECT_NAME}/examples/rust-basic)
