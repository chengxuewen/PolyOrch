# e2e: required
# requires: system-rust
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

# WP9 gap-7: gensource command-layer proof (reference test/gensource,
# simplified to a cmake -P generator). Leg 1: a FRESH build succeeds and the
# run prints GENV1 -- physical evidence the generator ordered before cargo
# via PREBUILD (a missing include! file aborts rustc, not just a warning).
# Leg 2: flip the build-tree marker input to GENV2 and re-run the SAME build
# directory; the regenerated incl.rs must be the one compiled -- the run now
# prints GENV2. The stamping ceiling at the mediator rule is the fixture
# header's note: re-invocation triggers on the marker touch, and cargo's own
# fingerprint covers the incl.rs mtime.
polyorch_requires(system-rust _req)
if(NOT _req)
    message(STATUS "t-rust-gensource : SKIP (no system cargo on PATH or in ~/.cargo/bin)")
    return()
endif()

set(_cfg "$ENV{POLYORCH_TEST_CONFIG}")
if(NOT _cfg)
    set(_cfg Debug)
endif()
_polyorch_pixi_scratch(_s)
set(_b "${_s}/b")

set(_dargs "-DFIXTURE=${CMAKE_CURRENT_LIST_DIR}/../fixtures/gensource"
           "-DBUILD=${_b}" "-DCONFIG=${_cfg}" "-DTARGETS=cargo-build-gs-bin")
if("$ENV{POLYORCH_TEST_GENERATOR}")
    list(APPEND _dargs "-DGENERATOR=$ENV{POLYORCH_TEST_GENERATOR}")
endif()
execute_process(COMMAND "${CMAKE_COMMAND}" ${_dargs}
    -P "${CMAKE_CURRENT_LIST_DIR}/../fixtures/_driver.cmake"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
set(_dlog "${_out}${_err}")
drv_echo(_dlog)
if(_dlog MATCHES "DRIVER: skip")
    message(STATUS "t-rust-gensource : SKIP (fixture gate: capability absent at configure)")
    return()
endif()
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "rust-gensource: driver failed (${_rc})\n${_dlog}")
endif()

drv_get(_dlog gen _gen)
drv_get(_dlog bin _bin)
ck_file("${_gen}")
file(READ "${_gen}" _gs)
if(NOT _gs MATCHES "GENV1")
    message(FATAL_ERROR "rust-gensource: generated file holds the wrong marker:\n${_gs}")
endif()
execute_process(COMMAND "${_bin}"
    RESULT_VARIABLE _lrc OUTPUT_VARIABLE _lout ERROR_VARIABLE _lerr)
if(NOT _lrc EQUAL 0 OR NOT _lout MATCHES "GENSOURCE:GENV1")
    message(FATAL_ERROR "rust-gensource: run 1 wrong (rc=${_lrc}): ${_lout}${_lerr}")
endif()

# --- rebuild-on-change: flip the input, re-run the SAME build tree ----------
file(WRITE "${_b}/marker_in.txt" "GENV2\n")
# The stamped mediator re-invokes cargo when the artifact is missing (the
# reference's unstamped always-run shape would re-invoke on any build; the
# stamping deviation is ledgered). Removing the artifact keeps the leg
# physical: cargo MUST recompile, and only the regenerated incl.rs can
# supply the GENV2 marker.
file(REMOVE "${_bin}")
# The rebuild bypasses the driver, so compose the child PATH the same way
# (t-rust-profile-release precedent): the tool shell has no ~/.cargo/bin.
set(_rpath "$ENV{PATH}")
if(EXISTS "$ENV{HOME}/.cargo/bin")
    set(_rpath "$ENV{HOME}/.cargo/bin:${_rpath}")
endif()
execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_b}" --target cargo-build-gs-bin
    ENVIRONMENT "PATH=${_rpath}"
    RESULT_VARIABLE _r2 OUTPUT_VARIABLE _r2out ERROR_VARIABLE _r2err)
if(NOT _r2 EQUAL 0)
    message(FATAL_ERROR "rust-gensource: rebuild failed (${_r2}):\n${_r2out}${_r2err}")
endif()
file(READ "${_gen}" _gs2)
if(NOT _gs2 MATCHES "GENV2")
    message(FATAL_ERROR "rust-gensource: generator did not re-run on input change:\n${_gs2}")
endif()
execute_process(COMMAND "${_bin}"
    RESULT_VARIABLE _l2rc OUTPUT_VARIABLE _l2out ERROR_VARIABLE _l2err)
message(STATUS "rust-gensource: run 2 output: ${_l2out}")
if(NOT _l2rc EQUAL 0 OR NOT _l2out MATCHES "GENSOURCE:GENV2")
    message(FATAL_ERROR
        "rust-gensource: rebuild did not re-bake the new marker (rc=${_l2rc}): ${_l2out}${_l2err}")
endif()

message(STATUS "rust-gensource: OK (PREBUILD ordering physical + regen-on-change through the same build tree)")
