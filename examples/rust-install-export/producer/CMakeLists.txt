# The PRODUCER: build a Rust staticlib, then polyorch_rust_install stages it
# with a header and an EXPORT name -- generating <prefix>/lib/cmake/mathkit-demo/
# {mathkit-demo-rust.cmake, mathkit-demoConfig.cmake}, so ANY downstream CMake
# project can `find_package(mathkit-demo CONFIG REQUIRED)`.
cmake_minimum_required(VERSION 3.22)
project(mathkit-producer LANGUAGES C)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(PolyOrchRustHelpers)

polyorch_rust_setup(REQUIRED)

polyorch_rust_build(
    TARGET mathkit PACKAGE mathkit CRATE mathkit STATIC
    MANIFEST "${CMAKE_CURRENT_LIST_DIR}/rs/Cargo.toml")

polyorch_rust_install(TARGETS mathkit EXPORT mathkit-demo
    PUBLIC_HEADER "${CMAKE_CURRENT_LIST_DIR}/mathkit.h")
message(STATUS "mathkit staged: install later with 'cmake --install . --prefix <dir>'")
