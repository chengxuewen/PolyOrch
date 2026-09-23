# e2e: required
# requires: system-rust
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

# WP9 gap-1: features command-layer proof (reference test/features). Positive
# leg: set_features(one + genex(two,three) + NO_DEFAULT_FEATURES) must drive
# the REAL build -- the crate cannot compile on defaults (compile-breakage)
# and the RUN prints exactly the three enabled names. Negative leg: the
# untouched handle must FAIL the build with that very compile_error -- the
# flag channel is proven live in both directions, never just rule text.
polyorch_requires(system-rust _req)
if(NOT _req)
    message(STATUS "t-rust-features : SKIP (no system cargo on PATH or in ~/.cargo/bin)")
    return()
endif()

set(_cfg "$ENV{POLYORCH_TEST_CONFIG}")
if(NOT _cfg)
    set(_cfg Debug)
endif()
_polyorch_pixi_scratch(_s)

# --- positive: build + run ---------------------------------------------------
set(_b "${_s}/pos")
drv_run(_dlog _rc SKIP_VAR _skip
    FIXTURE "${CMAKE_CURRENT_LIST_DIR}/../fixtures/features"
    BUILD "${_b}" CONFIG "${_cfg}" TARGETS cargo-build-feat-on)
if(_skip)
    message(STATUS "t-rust-features : SKIP (fixture gate: capability absent at configure)")
    return()
endif()

drv_get(_dlog featbin _fb)
ck_file("${_fb}")
# The negative handle's base dir must NOT have produced a binary: it was
# never built, and its compile would have failed anyway (asserted below).
execute_process(COMMAND "${_fb}"
    RESULT_VARIABLE _lrc OUTPUT_VARIABLE _lout ERROR_VARIABLE _lerr)
message(STATUS "rust-features: feat-probe output: ${_lout}")
if(NOT _lrc EQUAL 0 OR NOT _lout MATCHES "FEATURES:one,two,three")
    message(FATAL_ERROR "rust-features: run lacks the full marker (rc=${_lrc}): ${_lout}${_lerr}")
endif()

# --- negative: defaults left ON must break the build --------------------------
set(_b2 "${_s}/neg")
set(_dargs2 "-DFIXTURE=${CMAKE_CURRENT_LIST_DIR}/../fixtures/features"
            "-DBUILD=${_b2}" "-DCONFIG=${_cfg}" "-DTARGETS=cargo-build-feat-off")
if("$ENV{POLYORCH_TEST_GENERATOR}")
    list(APPEND _dargs2 "-DGENERATOR=$ENV{POLYORCH_TEST_GENERATOR}")
endif()
execute_process(COMMAND "${CMAKE_COMMAND}" ${_dargs2}
    -P "${CMAKE_CURRENT_LIST_DIR}/../fixtures/_driver.cmake"
    RESULT_VARIABLE _nrc OUTPUT_VARIABLE _nout ERROR_VARIABLE _nerr)
set(_nlog "${_nout}${_nerr}")
if(_nlog MATCHES "DRIVER: skip")
    message(STATUS "t-rust-features : SKIP (fixture gate: capability absent at configure)")
    return()
endif()
if(_nrc EQUAL 0)
    message(FATAL_ERROR
        "rust-features: NEGATIVE leg passed -- the default-feature compile_error did not fire")
endif()
file(READ "${_b2}/_build.log" _bl)
if(NOT _bl MATCHES "POLYORCH_FEATURE_BREAKAGE")
    message(FATAL_ERROR
        "rust-features: negative build failed for the WRONG reason (expected the compile-breakage error):\n${_bl}")
endif()

message(STATUS "rust-features: OK (features drove a real cfg build; defaults-on leg broke on the compile-breakage error)")
