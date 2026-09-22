# e2e: required
# requires: pixi-rust
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

polyorch_requires(pixi-rust _req)
if(NOT _req)
    message(STATUS "t-rust-rule-wiring : SKIP (no pixi env materialized with a cargo)")
    return()
endif()

# examples-free since the fixture move, but the pixi platform floor is the
# fixture manifest's: the five platforms it names.
if(NOT CMAKE_HOST_SYSTEM_NAME MATCHES "^(Linux|Darwin|Windows)$")
    message(STATUS "t-rust-rule-wiring : SKIP (no pixi platform for ${CMAKE_HOST_SYSTEM_NAME})")
    return()
endif()

set(_cfg "$ENV{POLYORCH_TEST_CONFIG}")
if(NOT _cfg)
    set(_cfg Debug)
endif()
_polyorch_pixi_scratch(_s)

set(_dargs "-DFIXTURE=${CMAKE_CURRENT_LIST_DIR}/../fixtures/rule-wiring"
           "-DBUILD=${_s}/b" "-DCONFIG=${_cfg}" "-DTARGETS=greet-cargo")
if("$ENV{POLYORCH_TEST_GENERATOR}")
    list(APPEND _dargs "-DGENERATOR=$ENV{POLYORCH_TEST_GENERATOR}")
endif()

execute_process(COMMAND "${CMAKE_COMMAND}" ${_dargs}
    -P "${CMAKE_CURRENT_LIST_DIR}/../fixtures/_driver.cmake"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
set(_dlog "${_out}${_err}")
drv_echo(_dlog)
if(_dlog MATCHES "DRIVER: skip")
    message(STATUS "t-rust-rule-wiring : SKIP (fixture gate: capability absent at configure)")
    return()
endif()
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "rust-rule-wiring: driver failed (${_rc})\n${_dlog}")
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
