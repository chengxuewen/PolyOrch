# e2e: required
# requires: system-rust
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

# WP9 gap-3: cargo-flags command-layer proof (reference test/cargo_flags).
# Positive: the cf-flags crate only COMPILES when the generate-time genex
# carrying --features=one,two,three reached cargo argv -- the run marker is
# the survivor of that compile gate. Second leg: --timings through the
# same channel must leave cargo-timing-*.html in the build tree (a physical
# effect that no property-text assertion can fake).
polyorch_requires(system-rust _req)
if(NOT _req)
    message(STATUS "t-rust-cargoflags : SKIP (no system cargo on PATH or in ~/.cargo/bin)")
    return()
endif()

set(_cfg "$ENV{POLYORCH_TEST_CONFIG}")
if(NOT _cfg)
    set(_cfg Debug)
endif()
_polyorch_pixi_scratch(_s)
set(_b "${_s}/b")

set(_dargs "-DFIXTURE=${CMAKE_CURRENT_LIST_DIR}/../fixtures/cargo-flags"
           "-DBUILD=${_b}" "-DCONFIG=${_cfg}"
           "-DTARGETS=cargo-build-cf-flags\\;cargo-build-cf-timings")
if("$ENV{POLYORCH_TEST_GENERATOR}")
    list(APPEND _dargs "-DGENERATOR=$ENV{POLYORCH_TEST_GENERATOR}")
endif()
execute_process(COMMAND "${CMAKE_COMMAND}" ${_dargs}
    -P "${CMAKE_CURRENT_LIST_DIR}/../fixtures/_driver.cmake"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
set(_dlog "${_out}${_err}")
drv_echo(_dlog)
if(_dlog MATCHES "DRIVER: skip")
    message(STATUS "t-rust-cargoflags : SKIP (fixture gate: capability absent at configure)")
    return()
endif()
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "rust-cargoflags: driver failed (${_rc})\n${_dlog}")
endif()

# --- leg 1: the genex-delivered feature flags compiled the crate ------------
drv_get(_dlog cfbin _cb)
ck_file("${_cb}")
execute_process(COMMAND "${_cb}"
    RESULT_VARIABLE _lrc OUTPUT_VARIABLE _lout ERROR_VARIABLE _lerr)
message(STATUS "rust-cargoflags: cf-probe output: ${_lout}")
if(NOT _lrc EQUAL 0 OR NOT _lout MATCHES "CARGOFLAGS:one,two,three")
    message(FATAL_ERROR "rust-cargoflags: run marker missing (rc=${_lrc}): ${_lout}${_lerr}")
endif()

# --- leg 2: --timings left a physical file in the cargo target dir ----------
drv_get(_dlog timbase _tb)
file(GLOB _tfiles "${_tb}/cargo-timing-*.html")
list(LENGTH _tfiles _nt)
if(_nt LESS 1)
    # cargo writes the timing report next to the target dir root; broaden once
    # before declaring failure so the diagnosis names what IS there.
    file(GLOB _tfiles "${_tb}/**/cargo-timing-*")
    list(LENGTH _tfiles _nt)
endif()
if(_nt LESS 1)
    file(GLOB _seen "${_tb}/*")
    message(FATAL_ERROR
        "rust-cargoflags: --timings produced no cargo-timing-* file under ${_tb} (saw: ${_seen})")
endif()
message(STATUS "rust-cargoflags: timings artifact ${_tfiles}")

# --- leg 3: the FEATURES-keyword sibling produced the same binary -----------
drv_get(_dlog cfbin2 _tb2)
ck_file("${_tb2}")

message(STATUS "rust-cargoflags: OK (genex-delivered flags compiled a feature-gated crate; --timings file physically present)")
