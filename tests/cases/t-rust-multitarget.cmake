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
drv_run(_dlog _rc SKIP_VAR _skip
    FIXTURE "${CMAKE_CURRENT_LIST_DIR}/../fixtures/multitarget"
    BUILD "${_b}" CONFIG "${_cfg}" TARGETS cargo-build-bin1-exe cargo-build-bin2-exe)
if(_skip)
    message(STATUS "t-rust-multitarget : SKIP (fixture gate: capability absent at configure)")
    return()
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
