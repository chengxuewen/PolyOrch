# tests/fixtures/cross-musl -- fixture for cases/t-rust-musl.cmake: the WP5
# REAL cross leg on the validation host (rustup target x86_64-unknown-linux-
# musl installed; musl links self-contained). Nothing stubbed: the driver
# passes -DPolyOrch_RUST_CARGO_TARGET=x86_64-unknown-linux-musl, setup
# consumes it (family gate passes), and three handles prove the three
# cross-layer behaviors at once:
#   m-bin   default cross build  -> .cargo-target/<tup>/<profile>/hello
#   m-st    cross staticlib      -> .cargo-target/<tup>/<profile>/libstm.a
#   hb-bin  hostbuild-flipped    -> falls back to .cargo-target/<profile>/hello
#           (the late finalize read of POLYORCH_RUST_HOST_BUILD; the distinct
#           directory honored is the WP5 no-fakery proof)
# The driver's artifact contract registers the two eager cross paths (what
# the default handles produce); the hostbuild location is asserted by the
# case itself from the tf-hb generate-time probe.
cmake_minimum_required(VERSION 3.25)
project(polyorch-fixture-cross-musl LANGUAGES NONE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(PolyOrchRustHelpers)
include("${CMAKE_CURRENT_LIST_DIR}/../../cases/_requires.cmake")

# Driver-composed child PATH (tests/fixtures/_driver.cmake) mirrors the
# case-side `# requires: system-rust` gate; the target-<tuple> capability
# itself is gated by the driving case (rustup is not needed to CONFIGURE a
# child -- only to build it, and the driver's build step is where that
# bites; the parent gate keeps the pair honest).
polyorch_requires(system-rust _req)
if(NOT _req)
    message(STATUS "polyorch-fixture-cross-musl : SKIP (no cargo on the child PATH)")
    return()
endif()

# NO_NATIVE_PROBE: this fixture links nothing into a C consumer; the probe
# leg for cross triples is covered by its own path in the WP5 ledger.
polyorch_rust_setup(REQUIRED NO_NATIVE_PROBE)

# Evidence the knob genuinely routed (the case asserts the value).
file(WRITE "${CMAKE_BINARY_DIR}/routed.txt" "${POLYORCH_RUST_CARGO_TARGET}")

set(_ws "${CMAKE_CURRENT_LIST_DIR}/rust-ws/Cargo.toml")
polyorch_rust_build(TARGET m-bin  PACKAGE hello CRATE hello BINARY
    MANIFEST "${_ws}")
polyorch_rust_build(TARGET m-st   PACKAGE stm   CRATE stm   STATIC
    MANIFEST "${_ws}")
polyorch_rust_build(TARGET hb-bin PACKAGE hello CRATE hello BINARY
    MANIFEST "${_ws}")
polyorch_rust_set_hostbuild(TARGET hb-bin)

# Generate-time probe of the LATE location (post-defer): must be the host
# layer. The parent case reads tf-hb.txt and asserts distinctness.
file(GENERATE OUTPUT "${CMAKE_BINARY_DIR}/tf-hb.txt"
    CONTENT "$<TARGET_FILE:hb-bin>")

# Driver contract: the eager locations of the two DEFAULT cross handles --
# identical to the late ones (no property flip on those), so the paths the
# driver checks after the build are the paths cargo must produce.
get_target_property(_xb m-bin IMPORTED_LOCATION)
get_target_property(_xs m-st IMPORTED_LOCATION)
set(POLYORCH_FIXTURE_ARTIFACTS
    "xbin=${_xb}"
    "xst=${_xs}")
string(JOIN "\n" _af ${POLYORCH_FIXTURE_ARTIFACTS})
file(WRITE "${CMAKE_BINARY_DIR}/polyorch-fixture-artifacts.txt" "${_af}\n")
