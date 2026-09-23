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
drv_run(_dlog _rc SKIP_VAR _skip
    FIXTURE "${CMAKE_CURRENT_LIST_DIR}/../fixtures/route-pixi"
    BUILD "${_b}" CONFIG "${_cfg}" TARGETS cargo-build-rp-probe)
if(_skip)
    message(STATUS "t-rust-route-pixi : SKIP (fixture gate: no pixi tool)")
    return()
endif()

drv_get(_dlog rpbin _bin)
ck_file("${_bin}")

# The run IS the assertion: env-built binary prints the route marker.
execute_process(COMMAND "${_bin}" RESULT_VARIABLE _rc
    OUTPUT_VARIABLE _o ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE)
ck(_rc EQUAL 0)
ck(_o MATCHES "POLYORCH_ROUTE_PIXI_OK")
message(STATUS "rust-route-pixi: OK (env binary answered the route marker)")
