# e2e: required
# requires: system-rust
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

# WP9 gap-4: set_env_vars command-layer proof (reference test/envvar). The
# build script PANICS on a missing var, so a successful build is already
# evidence the env crossed the cmake -E env boundary; the run then asserts
# the EXACT baked values -- literal, generate-time genex value, and the
# configure-time cargo version token. The negative handle (no env at all)
# must fail on the build-script panic message, proving the channel is
# load-bearing and not ambient inheritance (PIT-14 strips the host env).
polyorch_requires(system-rust _req)
if(NOT _req)
    message(STATUS "t-rust-envvars : SKIP (no system cargo on PATH or in ~/.cargo/bin)")
    return()
endif()

set(_cfg "$ENV{POLYORCH_TEST_CONFIG}")
if(NOT _cfg)
    set(_cfg Debug)
endif()
_polyorch_pixi_scratch(_s)

set(_b "${_s}/pos")
drv_run(_dlog _rc SKIP_VAR _skip
    FIXTURE "${CMAKE_CURRENT_LIST_DIR}/../fixtures/env-var"
    BUILD "${_b}" CONFIG "${_cfg}" TARGETS cargo-build-ev-on)
if(_skip)
    message(STATUS "t-rust-envvars : SKIP (fixture gate: capability absent at configure)")
    return()
endif()

drv_get(_dlog evbin _eb)
ck_file("${_eb}")
execute_process(COMMAND "${_eb}"
    RESULT_VARIABLE _lrc OUTPUT_VARIABLE _lout ERROR_VARIABLE _lerr)
message(STATUS "rust-envvars: ev-probe output: ${_lout}")
if(NOT _lrc EQUAL 0 OR NOT _lout MATCHES "ENVVARS:EXPECTED_VALUE\|IND_VALUE\|VER_SEEN")
    message(FATAL_ERROR "rust-envvars: baked markers wrong (rc=${_lrc}): ${_lout}${_lerr}")
endif()

# --- negative: no env vars -> the build script panics ------------------------
set(_b2 "${_s}/neg")
set(_dargs2 "-DFIXTURE=${CMAKE_CURRENT_LIST_DIR}/../fixtures/env-var"
            "-DBUILD=${_b2}" "-DCONFIG=${_cfg}" "-DTARGETS=cargo-build-ev-off")
if("$ENV{POLYORCH_TEST_GENERATOR}")
    list(APPEND _dargs2 "-DGENERATOR=$ENV{POLYORCH_TEST_GENERATOR}")
endif()
execute_process(COMMAND "${CMAKE_COMMAND}" ${_dargs2}
    -P "${CMAKE_CURRENT_LIST_DIR}/../fixtures/_driver.cmake"
    RESULT_VARIABLE _nrc OUTPUT_VARIABLE _nout ERROR_VARIABLE _nerr)
set(_nlog "${_nout}${_nerr}")
if(_nlog MATCHES "DRIVER: skip")
    message(STATUS "t-rust-envvars : SKIP (fixture gate: capability absent at configure)")
    return()
endif()
if(_nrc EQUAL 0)
    message(FATAL_ERROR
        "rust-envvars: NEGATIVE leg passed -- build.rs ran without the env vars")
endif()
file(READ "${_b2}/_build.log" _bl)
if(NOT _bl MATCHES "POLYORCH_ENV_PROBE_NOT_SET")
    message(FATAL_ERROR
        "rust-envvars: negative build failed for the WRONG reason:\n${_bl}")
endif()

message(STATUS "rust-envvars: OK (literal + genex-valued + version-token envs baked through build.rs; no-env leg panicked)")
