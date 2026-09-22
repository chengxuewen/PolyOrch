# e2e: required
# requires: system-rust
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

# WP9 gap-2: rustflags command-layer proof (reference test/rustflags). The
# positive run must show EVERY cfg flavor reached rustc -- plain, key="value"
# (cargo shell-splits the RUSTFLAGS env, measured), the global scope (the
# dependency compiled at all), and the generate-time $<CONFIG> genex (the
# mode marker is debug|release, never `none` -- the reference's own regex
# accepts either for the same reason). The negative leg proves the channel
# is load-bearing: without the flags the dependency cannot compile.
polyorch_requires(system-rust _req)
if(NOT _req)
    message(STATUS "t-rust-rustflags : SKIP (no system cargo on PATH or in ~/.cargo/bin)")
    return()
endif()

set(_cfg "$ENV{POLYORCH_TEST_CONFIG}")
if(NOT _cfg)
    set(_cfg Debug)
endif()
_polyorch_pixi_scratch(_s)

set(_b "${_s}/pos")
set(_dargs "-DFIXTURE=${CMAKE_CURRENT_LIST_DIR}/../fixtures/rustflags"
           "-DBUILD=${_b}" "-DCONFIG=${_cfg}" "-DTARGETS=cargo-build-rf-on")
if("$ENV{POLYORCH_TEST_GENERATOR}")
    list(APPEND _dargs "-DGENERATOR=$ENV{POLYORCH_TEST_GENERATOR}")
endif()
execute_process(COMMAND "${CMAKE_COMMAND}" ${_dargs}
    -P "${CMAKE_CURRENT_LIST_DIR}/../fixtures/_driver.cmake"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
set(_dlog "${_out}${_err}")
drv_echo(_dlog)
if(_dlog MATCHES "DRIVER: skip")
    message(STATUS "t-rust-rustflags : SKIP (fixture gate: capability absent at configure)")
    return()
endif()
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "rust-rustflags: positive driver failed (${_rc})\n${_dlog}")
endif()

drv_get(_dlog rfbin _rb)
ck_file("${_rb}")
execute_process(COMMAND "${_rb}"
    RESULT_VARIABLE _lrc OUTPUT_VARIABLE _lout ERROR_VARIABLE _lerr)
message(STATUS "rust-rustflags: rf-probe output: ${_lout}")
if(NOT _lrc EQUAL 0 OR NOT _lout MATCHES "RUSTFLAGS:ONE,TWO,DEP\|MODE:(debug|release)")
    message(FATAL_ERROR "rust-rustflags: run markers incomplete (rc=${_lrc}): ${_lout}${_lerr}")
endif()

# --- negative: no rustflags -> the dependency guard error ------------------
set(_b2 "${_s}/neg")
set(_dargs2 "-DFIXTURE=${CMAKE_CURRENT_LIST_DIR}/../fixtures/rustflags"
            "-DBUILD=${_b2}" "-DCONFIG=${_cfg}" "-DTARGETS=cargo-build-rf-off")
if("$ENV{POLYORCH_TEST_GENERATOR}")
    list(APPEND _dargs2 "-DGENERATOR=$ENV{POLYORCH_TEST_GENERATOR}")
endif()
execute_process(COMMAND "${CMAKE_COMMAND}" ${_dargs2}
    -P "${CMAKE_CURRENT_LIST_DIR}/../fixtures/_driver.cmake"
    RESULT_VARIABLE _nrc OUTPUT_VARIABLE _nout ERROR_VARIABLE _nerr)
set(_nlog "${_nout}${_nerr}")
if(_nlog MATCHES "DRIVER: skip")
    message(STATUS "t-rust-rustflags : SKIP (fixture gate: capability absent at configure)")
    return()
endif()
if(_nrc EQUAL 0)
    message(FATAL_ERROR
        "rust-rustflags: NEGATIVE leg passed -- the dependency compiled without the flags")
endif()
file(READ "${_b2}/_build.log" _bl)
if(NOT _bl MATCHES "POLYORCH_RUSTFLAGS_DEP_NOT_SEEN")
    message(FATAL_ERROR
        "rust-rustflags: negative build failed for the WRONG reason:\n${_bl}")
endif()

message(STATUS "rust-rustflags: OK (plain/key=value/genex cfgs + dep scope all live; flags-off leg failed)")
