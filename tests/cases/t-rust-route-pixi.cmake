# e2e: required
# requires: pixi
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

# Dual-route plan WP3: the pixi-route connectivity leg. The fixture
# materializes its own pixi env (setup + dependency + pixi_install), then
# polyorch_rust_setup(FROM pixi REQUIRED) builds a marker binary INSIDE the
# env; the run output names the route. Physical proof only. On hosts without
# the pixi tool the fixture's gate skips through the driver's contract line
# and this case skips with it.
set(_cfg "$ENV{POLYORCH_TEST_CONFIG}")
if(NOT _cfg)
    set(_cfg Debug)
endif()
_polyorch_pixi_scratch(_s)

set(_b "${_s}/rp")
set(_dargs "-DFIXTURE=${CMAKE_CURRENT_LIST_DIR}/../fixtures/route-pixi"
           "-DBUILD=${_b}" "-DCONFIG=${_cfg}"
           "-DTARGETS=cargo-build-rp-probe")
if("$ENV{POLYORCH_TEST_GENERATOR}")
    list(APPEND _dargs "-DGENERATOR=$ENV{POLYORCH_TEST_GENERATOR}")
endif()
execute_process(COMMAND "${CMAKE_COMMAND}" ${_dargs}
    -P "${CMAKE_CURRENT_LIST_DIR}/../fixtures/_driver.cmake"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
set(_dlog "${_out}${_err}")
drv_echo(_dlog)
if(_dlog MATCHES "DRIVER: skip")
    message(STATUS "t-rust-route-pixi : SKIP (fixture gate: no pixi tool)")
    return()
endif()
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "rust-route-pixi: driver failed (${_rc})\n${_dlog}")
endif()

drv_get(_dlog rpbin _bin)
ck_file("${_bin}")

# The run IS the assertion: env-built binary prints the route marker.
execute_process(COMMAND "${_bin}" RESULT_VARIABLE _rc
    OUTPUT_VARIABLE _o ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE)
ck(_rc EQUAL 0)
ck(_o MATCHES "POLYORCH_ROUTE_PIXI_OK")
message(STATUS "rust-route-pixi: OK (env binary answered the route marker)")
