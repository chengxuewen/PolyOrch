# e2e: required
# requires: system-rust
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

# WP9 gap-5: custom-profiles command-layer proof (reference
# test/custom_profiles + basic_profiles). Four handles, one crate, four
# PROFILE spellings. Every leg asserts a PHYSICAL effect -- the artifact
# PATH (profile dir, incl. the dev -> debug normalization closed in WP9)
# plus the debug_assertions-flipped RUN MARKER -- and the argv form is
# pinned from the generated rule text (Makefiles cells; the Ninja sibling
# is the successful cargo invocation itself).
polyorch_requires(system-rust _req)
if(NOT _req)
    message(STATUS "t-rust-customprofiles : SKIP (no system cargo on PATH or in ~/.cargo/bin)")
    return()
endif()

set(_cfg "$ENV{POLYORCH_TEST_CONFIG}")
if(NOT _cfg)
    set(_cfg Debug)
endif()
_polyorch_pixi_scratch(_s)
set(_b "${_s}/b")

drv_run(_dlog _rc SKIP_VAR _skip
    FIXTURE "${CMAKE_CURRENT_LIST_DIR}/../fixtures/custom-profiles"
    BUILD "${_b}" CONFIG "${_cfg}" TARGETS cargo-build-cp-debug cargo-build-cp-release cargo-build-cp-nodbg cargo-build-cp-dev)
if(_skip)
    message(STATUS "t-rust-customprofiles : SKIP (fixture gate: capability absent at configure)")
    return()
endif()

# drv_get emits one line per artifact key written by the fixture.
drv_get(_dlog debug _p_debug)
drv_get(_dlog release _p_release)
drv_get(_dlog nodbg _p_nodbg)
drv_get(_dlog dev _p_dev)

# --- profile DIRECTORY + RUN MARKER per spelling -----------------------------
macro(pp_leg path want_dir want_mark)
    ck_file("${path}")
    string(FIND "${path}" "/${want_dir}/" _hit)
    if(_hit EQUAL -1)
        message(FATAL_ERROR "rust-customprofiles: ${path} not in a /${want_dir}/ profile dir")
    endif()
    execute_process(COMMAND "${path}"
        RESULT_VARIABLE _lrc OUTPUT_VARIABLE _lout ERROR_VARIABLE _lerr)
    if(NOT _lrc EQUAL 0 OR NOT _lout MATCHES "PROF:${want_mark}")
        message(FATAL_ERROR "rust-customprofiles: ${path} marker wrong (want PROF:${want_mark}, rc=${_lrc}): ${_lout}${_lerr}")
    endif()
endmacro()

# PROFILE debug -> debug dir, debug_assertions ON.
pp_leg("${_p_debug}" debug DBG)
# PROFILE release -> --release + release dir, debug_assertions OFF.
pp_leg("${_p_release}" release NODEBG)
# PROFILE nodbg -> its own dir, debug-assertions OFF (the [profile.nodbg]
# inherits=dev + debug-assertions=false toggle).
pp_leg("${_p_nodbg}" nodbg NODEBG)
# PROFILE dev -> debug dir (the WP9 mapping; a regression would look for
# .ct-dev/dev/ and find nothing -- ck_file above fails the whole leg).
pp_leg("${_p_dev}" debug DBG)
# Distinct paths: one crate, four handles, no shared artifact (RUN_SERIAL
# lesson made physical).
if(_p_debug STREQUAL _p_nodbg OR _p_dev STREQUAL _p_debug OR _p_release STREQUAL _p_dev)
    message(FATAL_ERROR "rust-customprofiles: profile handles collide on one path")
endif()

# --- argv pin (Makefiles cells): --profile dev / --profile nodbg in the rule -
if(EXISTS "${_b}/CMakeFiles/cargo-build-cp-nodbg.dir/build.make")
    file(READ "${_b}/CMakeFiles/cargo-build-cp-nodbg.dir/build.make" _mk1)
    file(READ "${_b}/CMakeFiles/cargo-build-cp-dev.dir/build.make" _mk2)
    file(READ "${_b}/CMakeFiles/cargo-build-cp-debug.dir/build.make" _mk3)
    if(NOT _mk1 MATCHES "%2D%2Dprofile nodbg|--profile nodbg")
        message(FATAL_ERROR "rust-customprofiles: nodbg rule lacks --profile nodbg")
    endif()
    if(NOT _mk2 MATCHES "%2D%2Dprofile dev|--profile dev")
        message(FATAL_ERROR "rust-customprofiles: dev rule lacks --profile dev")
    endif()
    if(_mk3 MATCHES "%2D%2Dprofile|--profile ")
        message(FATAL_ERROR "rust-customprofiles: PROFILE debug must emit NO --profile flag")
    endif()
else()
    message(STATUS "rust-customprofiles: non-Makefiles cell -- argv pins skipped")
endif()

message(STATUS "rust-customprofiles: OK (4 spellings x dir+marker physical; dev normalized to debug/)")
