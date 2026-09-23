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
#     polyorch_rust_link_libraries(cli-user c_triple) converts the CMake
#     static library target into -L/-l on the cargo link line -- the Rust
#     binary's `extern "C"` declarations resolve against it.
#
#   # standalone:
#   cmake -S examples/rust-link-c -B build
#   cmake --build build --target app            # C exe <- Rust staticlib
#   ./build/app
#   cmake --build build --target run-cli-user   # Rust bin <- C staticlib
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

project(rust-link-c LANGUAGES C)   # the C half is a first-class citizen here

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
include(PolyOrchRustHelpers)

polyorch_rust_setup(REQUIRED)

# --- direction 1: Rust staticlib -> C executable ---------------------------
polyorch_rust_build(
    FOLDER  "${PROJECT_NAME}/examples/rust-link-c"
    TARGET  geometry
    PACKAGE geometry
    CRATE   geometry
    STATIC
    MANIFEST "${CMAKE_CURRENT_LIST_DIR}/rs/Cargo.toml")

add_executable(app app.c)
target_link_libraries(app PRIVATE geometry)   # + the probed system libs, automatically

# --- direction 2: C staticlib -> Rust binary -------------------------------
add_library(c_triple STATIC c_fn.c)
# NOTE: the CMake TARGET (`cli-user-tool`) deliberately differs from the
# artifact base name (`cli-user`, the [[package]] name): an IMPORTED target
# named like its output file makes the Makefile generator silently swallow
# the producing rule (PIT-13 -- the configure FATALs to teach this).
polyorch_rust_build(
    FOLDER  "${PROJECT_NAME}/examples/rust-link-c"
    TARGET  cli-user-tool
    PACKAGE cli-user
    CRATE   cli-user
    BINARY
    MANIFEST "${CMAKE_CURRENT_LIST_DIR}/rs/bin/Cargo.toml")
polyorch_rust_link_libraries(TARGET cli-user-tool c_triple)
polyorch_rust_run(FOLDER "${PROJECT_NAME}/examples/rust-link-c" TARGET cli-user-tool)
