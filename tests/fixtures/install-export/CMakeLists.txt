# tests/fixtures/install-export -- producer fixture for the WP8 consumer
# chain (cases/t-rust-install-export.cmake). One polyorch_rust_install call
# exercises the full keyword shape: a staticlib + bin, an EXPORT name
# (replay stub + generated <name>Config.cmake find_package entry point),
# a custom RUNTIME destination, a single component name stamped on every
# artifact rule, and a PUBLIC_HEADER sidecar installed flat under include/
# and re-attached as the static handle's INTERFACE_INCLUDE_DIRECTORIES.
# The consumer/ project below is a SECOND, unrelated C project that
# discovers everything through find_package(polyorch-demo CONFIG REQUIRED)
# with CMAKE_PREFIX_PATH pointed at the install stage -- no include() of
# the stub by hand, which is what distinguishes this chain from the
# install-e2e fixture.
cmake_minimum_required(VERSION 3.25)
project(polyorch-fixture-install-export LANGUAGES NONE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(PolyOrchRustHelpers)
include("${CMAKE_CURRENT_LIST_DIR}/../../cases/_requires.cmake")

# Same child-PATH convention as the install-e2e fixture (the driver
# composes ~/.cargo/bin into the child PATH -- tests/fixtures/_driver.cmake).
polyorch_requires(system-rust _req)
if(NOT _req)
    message(STATUS "polyorch-fixture-install-export : SKIP (no cargo on the child PATH)")
    return()
endif()

polyorch_rust_setup(REQUIRED)

set(_cws "${CMAKE_CURRENT_LIST_DIR}/rust-ws")

polyorch_rust_import(MANIFEST "${_cws}/Cargo.toml"
    CRATES demo;say IMPORTED_TARGETS _imps)
file(WRITE "${CMAKE_BINARY_DIR}/imported.txt" "${_imps}")

# The WP8 full-shape install. RUNTIME_DESTINATION moves the bin family to
# appbin/; COMPONENT demo lets the case prove per-component install
# filtering; PUBLIC_HEADER lands include/demo.h under <prefix>/include and
# the stub hands the directory to the consumer compile line.
polyorch_rust_install(TARGETS demo say-exe EXPORT polyorch-demo
    RUNTIME_DESTINATION appbin COMPONENT demo
    PUBLIC_HEADER "${CMAKE_CURRENT_LIST_DIR}/include/demo.h")

# Staged-name evidence from the resolved genexes (the case derives the
# staged paths from these, never re-spelling file names).
file(GENERATE OUTPUT "${CMAKE_BINARY_DIR}/name_static.txt" CONTENT "$<TARGET_FILE_NAME:demo>")
file(GENERATE OUTPUT "${CMAKE_BINARY_DIR}/name_bin.txt" CONTENT "$<TARGET_FILE_NAME:say-exe>")

# Pre-install evidence: the cargo-built artifacts exist once the build ran
# (same profile-mapping walk the install-e2e fixture takes).
string(TOLOWER "${CMAKE_BUILD_TYPE}" _bt)
if(_bt STREQUAL "" OR _bt STREQUAL "debug")
    set(_profile debug)
else()
    set(_profile release)
endif()
_polyorch_rust_artifact_names(TRIPLE "${POLYORCH_RUST_HOST_TARGET}"
    KIND static CRATE demo PROFILE "${_profile}" FILE_OUT _lf DIR_OUT _ld)
_polyorch_rust_artifact_names(TRIPLE "${POLYORCH_RUST_HOST_TARGET}"
    KIND bin CRATE say PROFILE "${_profile}" FILE_OUT _bf DIR_OUT _bd)

set(POLYORCH_FIXTURE_ARTIFACTS
    "static_lib=${_ld}/${_lf}"
    "bin=${_bd}/${_bf}")
string(JOIN "\n" _af ${POLYORCH_FIXTURE_ARTIFACTS})
file(WRITE "${CMAKE_BINARY_DIR}/polyorch-fixture-artifacts.txt" "${_af}\n")
