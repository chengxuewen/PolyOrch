# e2e: required
# requires: system-rust
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

# The systemic PIT-13 net, fixture-driver edition: proves the producing rule
# SURVIVES generation. Drives tests/fixtures/rule-wiring through
# tests/fixtures/_driver.cmake (configure + build of the legacy mediator name
# greet-cargo -- the rename to cargo-build-<T> must not break it) and asserts
# the contract-anchored artifact the driver verified: the naming-table path
# exists and is non-empty. CMAKE_BUILD_TYPE follows
# $ENV{POLYORCH_TEST_CONFIG} (unset => Debug), so the matrix cells drive this
# case through the matching cargo profile directory.

polyorch_requires(system-rust _req)
if(NOT _req)
    message(STATUS "t-rust-rule-wiring : SKIP (no system cargo on PATH or in ~/.cargo/bin)")
    return()
endif()

set(_cfg "$ENV{POLYORCH_TEST_CONFIG}")
if(NOT _cfg)
    set(_cfg Debug)
endif()
_polyorch_pixi_scratch(_s)

drv_run(_dlog _rc SKIP_VAR _skip
    FIXTURE "${CMAKE_CURRENT_LIST_DIR}/../fixtures/rule-wiring"
    BUILD "${_s}/b" CONFIG "${_cfg}" TARGETS greet-cargo)
if(_skip)
    message(STATUS "t-rust-rule-wiring : SKIP (fixture gate: capability absent at configure)")
    return()
endif()

drv_get(_dlog greet _art)
# The artifact must sit in the profile directory the config demands.
string(TOLOWER "${_cfg}" _cl)
if(_cl STREQUAL "debug")
    set(_want debug)
else()
    set(_want release)
endif()
if(NOT _art MATCHES "/\\.cargo-target/${_want}/")
    message(FATAL_ERROR "rust-rule-wiring: artifact ${_art} not under .cargo-target/${_want}/ (CONFIG=${_cfg})")
endif()
ck_file("${_art}")
file(SIZE "${_art}" _len)
ck(_len GREATER 0)

message(STATUS "rust-rule-wiring: OK (producing rule survived generation: ${_art}, ${_len} bytes)")
