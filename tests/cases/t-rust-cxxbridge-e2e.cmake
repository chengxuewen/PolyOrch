# e2e: required
# requires: cxxbridge-cmd
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

# WP7 live leg: the REAL cxxbridge-cmd through the whole surface --
# discovery (PATH + ~/.cargo/bin via the bootstrap), version gate (pin =
# the tool's own --banner), generation from the fixture's #[cxx::bridge]
# files, and C++ compilation of the REAL generated bindings into the
# archive. The bridge_fixture crate stays dependency-free (the bridge .rs
# files are parsed by the tool, never compiled by cargo), so this leg
# needs crates.io for NOTHING once the tool binary exists -- tool
# acquisition itself (`cargo install cxxbridge-cmd`, the ALLOW_INSTALL
# branch) is the gated network/shared-state half, deferred with its own
# authorization at first live attempt (plan WP7 + R-10).
#
# Deviation registered on the port ledger: the reference derives the
# version pin by `cargo tree -i cxx` against a REAL cxx dependency
# (corr:1680-1726); this fixture must stay crates.io-free, so the pin is
# taken from the tool's own --version banner instead (the lock compare
# then verifies discovery, not crate-vs-tool agreement).

polyorch_requires(cxxbridge-cmd _req)
if(NOT _req)
    message(STATUS "t-rust-cxxbridge-e2e : SKIP (no cxxbridge on PATH or in ~/.cargo/bin)")
    return()
endif()

find_program(_cxxb NAMES cxxbridge)
if(NOT _cxxb)
    find_program(_cxxb NAMES cxxbridge PATHS "$ENV{HOME}/.cargo/bin")
endif()
execute_process(COMMAND "${_cxxb}" --version
    OUTPUT_VARIABLE _vo ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE)
if(NOT _vo MATCHES "([0-9]+\\.[0-9]+\\.[0-9]+)")
    message(STATUS "t-rust-cxxbridge-e2e : SKIP (unparsable version banner: ${_vo})")
    return()
endif()
set(_ver "${CMAKE_MATCH_1}")
message(STATUS "t-rust-cxxbridge-e2e: real cxxbridge ${_ver} at ${_cxxb}")

set(_cfg "$ENV{POLYORCH_TEST_CONFIG}")
if(NOT _cfg)
    set(_cfg Debug)
endif()
_polyorch_pixi_scratch(_s)
set(_b "${_s}/cbx")
set(_dargs "-DFIXTURE=${CMAKE_CURRENT_LIST_DIR}/../fixtures/cxxbridge"
           "-DBUILD=${_b}" "-DCONFIG=${_cfg}"
           "-DTARGETS=bridge-lib-cxx\\;cargo-build-bridge-lib-static"
           "-DPASSTHROUGH=-DPOLYORCH_TEST_TOOL_VERSION=${_ver}")
if("$ENV{POLYORCH_TEST_GENERATOR}")
    list(APPEND _dargs "-DGENERATOR=$ENV{POLYORCH_TEST_GENERATOR}")
endif()
execute_process(COMMAND "${CMAKE_COMMAND}" ${_dargs}
    -P "${CMAKE_CURRENT_LIST_DIR}/../fixtures/_driver.cmake"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
set(_dlog "${_out}${_err}")
drv_echo(_dlog)
if(_dlog MATCHES "DRIVER: skip")
    message(STATUS "t-rust-cxxbridge-e2e : SKIP (fixture gate: capability absent at configure)")
    return()
endif()
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "t-rust-cxxbridge-e2e: driver failed (${_rc})\n${_dlog}")
endif()

set(_g "${_b}/polyorch_generated/cxxbridge/bridge-lib-cxx")
ck_file("${_g}/include/rust/cxx.h")
file(READ "${_g}/include/rust/cxx.h" _cxxh)
# The cxx runtime header's own ABI guard family (stable across cxx 1.0.x).
ck(_cxxh MATCHES "CXXBRIDGE1_RUST")
file(READ "${_g}/include/bridge-lib-cxx/bridge.h" _bh)
ck(_bh MATCHES "hello_bridge")
ck(_bh MATCHES "#pragma once")
file(READ "${_g}/src/bridge.cpp" _bcpp)
ck(_bcpp MATCHES "extern \"C\"")
ck(_bcpp MATCHES "cxxbridge1")
ck(_bcpp MATCHES "bridge-lib-cxx/bridge[.]h")
file(READ "${_g}/include/bridge-lib-cxx/sub/nested.h" _nh)
ck(_nh MATCHES "nested_bridge")
ck_file("${_b}/libbridge-lib-cxx.a")
message(STATUS "t-rust-cxxbridge-e2e : OK (real cxxbridge ${_ver})")
