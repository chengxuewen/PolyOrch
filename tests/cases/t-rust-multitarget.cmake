# e2e: required
# requires: system-rust
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

# WP9 gap-6: multitarget command-layer proof (reference test/multitarget).
# One package -> two distinct bin mediators and two DISTINCT artifact paths
# (the fixture itself FATALs on a collapse); this case drives both bin
# mediators through one build and runs each binary, asserting its own C-lib
# marker -- bin1 and bin2 print different names through the SAME clib_mt, so
# the per-handle -L/-l routing and the two --bin rules are separated
# physically, not by text.
polyorch_requires(system-rust _req)
if(NOT _req)
    message(STATUS "t-rust-multitarget : SKIP (no system cargo on PATH or in ~/.cargo/bin)")
    return()
endif()

set(_cfg "$ENV{POLYORCH_TEST_CONFIG}")
if(NOT _cfg)
    set(_cfg Debug)
endif()
_polyorch_pixi_scratch(_s)
set(_b "${_s}/b")

# Single driver build of BOTH bin mediators: cargo serializes on the shared
# target-dir lock (the reference's RUN_SERIAL concern shows up here as
# waiting, not corruption).
set(_dargs "-DFIXTURE=${CMAKE_CURRENT_LIST_DIR}/../fixtures/multitarget"
           "-DBUILD=${_b}" "-DCONFIG=${_cfg}"
           "-DTARGETS=cargo-build-bin1-exe\\;cargo-build-bin2-exe")
if("$ENV{POLYORCH_TEST_GENERATOR}")
    list(APPEND _dargs "-DGENERATOR=$ENV{POLYORCH_TEST_GENERATOR}")
endif()
execute_process(COMMAND "${CMAKE_COMMAND}" ${_dargs}
    -P "${CMAKE_CURRENT_LIST_DIR}/../fixtures/_driver.cmake"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
set(_dlog "${_out}${_err}")
drv_echo(_dlog)
if(_dlog MATCHES "DRIVER: skip")
    message(STATUS "t-rust-multitarget : SKIP (fixture gate: capability absent at configure)")
    return()
endif()
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "rust-multitarget: driver failed (${_rc})\n${_dlog}")
endif()

drv_get(_dlog bin1 _p1)
drv_get(_dlog bin2 _p2)
ck_file("${_p1}")
ck_file("${_p2}")
if(_p1 STREQUAL _p2)
    message(FATAL_ERROR "rust-multitarget: bins collapsed onto ${_p1}")
endif()

foreach(_pair "${_p1}|bin1" "${_p2}|bin2")
    string(REPLACE "|" ";" _pp "${_pair}")
    list(GET _pp 0 _path)
    list(GET _pp 1 _want)
    execute_process(COMMAND "${_path}"
        RESULT_VARIABLE _lrc OUTPUT_VARIABLE _lout ERROR_VARIABLE _lerr)
    message(STATUS "rust-multitarget: ${_want} output: ${_lout}")
    if(NOT _lrc EQUAL 0)
        message(FATAL_ERROR "rust-multitarget: ${_want} exited ${_lrc}: ${_lout}${_lerr}")
    endif()
    if(NOT _lout MATCHES "Hello, world!" OR NOT _lout MATCHES "Hello, ${_want}! I'm C!")
        message(FATAL_ERROR "rust-multitarget: ${_want} markers wrong: ${_lout}")
    endif()
endforeach()

message(STATUS "rust-multitarget: OK (one package, two bin mediators, two paths, two runs through a shared C staticlib)")
