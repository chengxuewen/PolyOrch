# tests/fixtures/cxxbridge -- fixture for cases/t-rust-cxxbridge.cmake (stub
# leg) and cases/t-rust-cxxbridge-e2e.cmake (live leg). It proves the whole
# polyorch_rust_cxxbridge wiring EXCEPT the tool's own parsing: the tool is
# either the deterministic stub from tool-stubs/ (offline: discovery via
# PREFIX, version gate via the pinned 1.0.131 banner, dummy-file
# generation, real C++ compilation of the dummy source into a real
# archive) or a real cxxbridge (live: # requires: cxxbridge-cmd, no
# PREFIX, VERSION discovered by the case). The bridge .rs files never
# enter the cargo module tree -- cxxbridge READS them as text, cargo never
# compiles them, so no crates.io dependency exists anywhere in here.
cmake_minimum_required(VERSION 3.25)
project(polyorch-fixture-cxxbridge LANGUAGES CXX)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(PolyOrchRustHelpers)
include("${CMAKE_CURRENT_LIST_DIR}/../../cases/_requires.cmake")

# The rust pair builds for real (the cxx library links it -- the
# reference's circular edge under test), so the child needs the toolchain.
polyorch_requires(system-rust _req)
if(NOT _req)
    message(STATUS "polyorch-fixture-cxxbridge : SKIP (no cargo on the child PATH)")
    return()
endif()

polyorch_rust_setup(REQUIRED)

# Kind-less dispatch -> bridge-lib-static + bridge-lib-shared exist and
# the cxx surface's dual link edges (corr:1912-1919) both fire; the pair
# handles carry POLYORCH_RUST_MANIFEST (the WP7 stamp) for the FILES
# src/ resolution.
polyorch_rust_build(TARGET bridge-lib PACKAGE bridge_fixture CRATE bridge_fixture
    MANIFEST "${CMAKE_CURRENT_LIST_DIR}/rust/Cargo.toml")

if(DEFINED POLYORCH_TEST_TOOL_PREFIX)
    # Offline leg: the fixture re-asserts the exec bit (checkout manners
    # vary) and pins discovery + version to the stub.
    set(_stub "${POLYORCH_TEST_TOOL_PREFIX}/bin/cxxbridge")
    file(CHMOD "${_stub}" PERMISSIONS
        OWNER_READ OWNER_WRITE OWNER_EXECUTE
        GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
    polyorch_rust_cxxbridge(TARGET bridge-lib
        FILES bridge.rs sub/nested.rs
        VERSION "${POLYORCH_TEST_TOOL_VERSION}"
        REGEN_TARGET regen-cxx
        PREFIX "${POLYORCH_TEST_TOOL_PREFIX}")
else()
    # Live leg: plain discovery (PATH + ~/.cargo/bin via the bootstrap),
    # version pinned by the case's own `cxxbridge --version` probe.
    polyorch_rust_cxxbridge(TARGET bridge-lib
        FILES bridge.rs sub/nested.rs
        VERSION "${POLYORCH_TEST_TOOL_VERSION}"
        REGEN_TARGET regen-cxx)
endif()

# Evidence the case reads after the build.
file(GENERATE OUTPUT "${CMAKE_BINARY_DIR}/cxx_iface.txt"
    CONTENT "$<TARGET_PROPERTY:bridge-lib-cxx,INTERFACE_INCLUDE_DIRECTORIES>")
file(WRITE "${CMAKE_BINARY_DIR}/host_triple.txt" "${POLYORCH_RUST_HOST_TARGET}\n")
get_target_property(_rs bridge-lib-static IMPORTED_LOCATION)
set(POLYORCH_FIXTURE_ARTIFACTS
    "cxxa=${CMAKE_CURRENT_BINARY_DIR}/libbridge-lib-cxx${CMAKE_STATIC_LIBRARY_SUFFIX}"
    "ruststatic=${_rs}")
string(JOIN "\n" _af ${POLYORCH_FIXTURE_ARTIFACTS})
file(WRITE "${CMAKE_BINARY_DIR}/polyorch-fixture-artifacts.txt" "${_af}\n")
