# Shared preamble for PolyOrch cmake test cases: loads the module under test
# and provides the assertion helpers.
#   ck(<bare condition tokens>)   e.g. ck(_x MATCHES ^a$), ck(${rc} EQUAL 0)
#                                 NEVER pre-quote the whole condition: after
#                                 expansion, embedded '"' become LITERAL chars
#                                 and EXISTS-style operators receive a quoted
#                                 (thus nonexistent) path. Measured on 4.4.3.
#   ck_file(<path>)               existence assertion, safe for paths w/ spaces
#   ck_str("actual" "expected")   exact equality, safe for embedded quotes
# FATAL_ERROR -> non-zero exit; run.sh / ctest compare against the verdict.
#
# Marker contract (full text in _requires.cmake; mirrored in the run.sh and
# CMakeLists.txt driver headers): line 1 carries the verdict marker
# (# expect: fail | # expect-log <re> | # e2e: required), line 2 the optional
# # expect-no-log <re> or # e2e: required, and by line 3 at the latest the
# optional # requires: <cap>. A requires-marked case probes
# polyorch_requires(<cap> _ok); on a miss it prints EXACTLY
#   <file stem> : SKIP (<reason>)
# and returns 0 -- an honest, counted SKIP. A case WITHOUT that marker must
# never print the contract skip substring -- both drivers veto it as a FAIL.
# Driver-level skip wording (SKIP <path> (...)) can never collide with the
# contract shape. Cases run through the drivers (TMPDIR exported), never a
# bare cmake -P, whenever a probe may touch the network.
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchPixiHelpers.cmake")

macro(ck)
    if(NOT (${ARGN}))
        message(FATAL_ERROR "check failed (line ${CMAKE_CURRENT_LIST_LINE}): ${ARGN}")
    endif()
endmacro()

macro(ck_file p)
    if(NOT EXISTS "${p}")
        # Diagnose: dump the contents of the nearest existing ancestor
        # directory (capped at 40) so a missing artifact names its neighborhood.
        set(_ckf_dir "${p}")
        set(_ckf_found "")
        while(_ckf_dir)
            if(EXISTS "${_ckf_dir}")
                set(_ckf_found "${_ckf_dir}")
                break()
            endif()
            get_filename_component(_ckf_dir "${_ckf_dir}" DIRECTORY)
        endwhile()
        set(_ckf_listing "<no existing ancestor>")
        if(_ckf_found)
            file(GLOB _ckf_items LIST_DIRECTORIES true "${_ckf_found}/*")
            list(SORT _ckf_items)
            set(_ckf_listing "")
            set(_ckf_n 0)
            foreach(_ckf_i IN LISTS _ckf_items)
                if(_ckf_n GREATER_EQUAL 40)
                    string(APPEND _ckf_listing "... (truncated)")
                    break()
                endif()
                string(APPEND _ckf_listing "\n    ${_ckf_i}")
                math(EXPR _ckf_n "${_ckf_n} + 1")
            endforeach()
            if(_ckf_listing STREQUAL "")
                set(_ckf_listing " <empty>")
            endif()
        endif()
        message(FATAL_ERROR "missing file (line ${CMAKE_CURRENT_LIST_LINE}): ${p}\n  nearest existing ancestor ${_ckf_found}/:${_ckf_listing}")
    endif()
endmacro()

# ck_child_fail("<regex>"): re-exec THIS case file as a `cmake -P` child with
# POLYORCH_CHILD=1 set both as a -D variable and as an environment variable
# (cases guard their expected-FATAL section behind `if(POLYORCH_CHILD)` so the
# recursion stops at depth 1). Asserts the child (a) exited non-zero AND
# (b) its combined stdout+stderr -- newlines flattened to single spaces, so
# the match is immune to message(FATAL_ERROR) display wrapping -- matches
# <regex>. Sets _ckc_rc/_ckc_out/_ckc_err/_ckc_txt in the caller's scope.
macro(ck_child_fail rx)
    execute_process(
        COMMAND "${CMAKE_COMMAND}" "-DPOLYORCH_CHILD=1" -P "${CMAKE_CURRENT_LIST_FILE}"
        ENVIRONMENT "POLYORCH_CHILD=1"
        RESULT_VARIABLE _ckc_rc OUTPUT_VARIABLE _ckc_out ERROR_VARIABLE _ckc_err)
    set(_ckc_txt "${_ckc_out}${_ckc_err}")
    string(REPLACE "\n" " " _ckc_txt "${_ckc_txt}")
    string(REPLACE "  " " " _ckc_txt "${_ckc_txt}")
    if(_ckc_rc EQUAL 0)
        message(FATAL_ERROR "ck_child_fail (line ${CMAKE_CURRENT_LIST_LINE}): child exited 0, expected failure matching [${rx}]")
    endif()
    if(NOT _ckc_txt MATCHES "${rx}")
        message(FATAL_ERROR "ck_child_fail (line ${CMAKE_CURRENT_LIST_LINE}): child rc=${_ckc_rc} but output does not contain [${rx}]:\n${_ckc_out}${_ckc_err}")
    endif()
endmacro()

macro(ck_str a b)
    string(COMPARE EQUAL "${a}" "${b}" _ck_ok)
    if(NOT _ck_ok)
        message(FATAL_ERROR
            "check failed (line ${CMAKE_CURRENT_LIST_LINE}): [${a}] != [${b}]")
    endif()
endmacro()

macro(ck_fail_rc v)
    if("${${v}}" EQUAL 0)
        message(FATAL_ERROR
            "expected non-zero result, got 0 (line ${CMAKE_CURRENT_LIST_LINE})")
    endif()
endmacro()

# Helpers for the fixture-driver cases (tests/fixtures/_driver.cmake).
# The driver reports on "DRIVER: ..." STATUS lines; the contract is documented
# in the driver header. drv_echo re-prints them so run.sh logs and ctest -V
# show the child's progress; drv_get extracts one "DRIVER: <key> <value>".
macro(drv_echo text)
    string(REPLACE "\r" "" _de_t "${${text}}")
    string(REPLACE "\n" ";" _de_ls "${_de_t}")
    foreach(_de_l IN LISTS _de_ls)
        string(REGEX REPLACE "^-- " "" _de_l "${_de_l}")
        if(_de_l MATCHES "^DRIVER: ")
            message(STATUS "${_de_l}")
        endif()
    endforeach()
endmacro()

macro(drv_get text key out)
    string(REGEX MATCH "DRIVER: ${key} ([^\r\n]+)" _drv_m "${${text}}")
    string(STRIP "${CMAKE_MATCH_1}" ${out})
    if("${${out}}" STREQUAL "")
        message(FATAL_ERROR "drv_get: no 'DRIVER: ${key} <value>' line in driver output")
    endif()
endmacro()

# drv_run(<out_log_var> <out_rc_var> [SKIP_VAR <var>] [EXPECT_FAIL]
#         FIXTURE <dir> BUILD <dir> [CONFIG <cfg>] [GENERATOR <gen>]
#         [TARGETS <t1;t2>] [PASSTHROUGH <raw-list>])
#
# One-call replacement for the per-case driver-invocation boilerplate
# (P1 plan 2026-09-23-driver-macro; Momus + impl-reviewer conditioned PASS).
#   1. Assemble -D args: FIXTURE/BUILD REQUIRED; CONFIG three-level
#      (GIVEN -> $ENV{POLYORCH_TEST_CONFIG} -> Debug); GENERATOR dual
#      semantics (GIVEN = forced literal, else the env probe); TARGETS;
#      PASSTHROUGH RAW list, ';' escaped INSIDE.
#   2-4. execute_process + drv_echo + SKIP_VAR + EXPECT_FAIL contract.
# Internals carry the _drv_ prefix (macros share the caller's scope).
macro(drv_run _drv_out_log _drv_out_rc)
    cmake_parse_arguments(_drv "EXPECT_FAIL" "SKIP_VAR;FIXTURE;BUILD;CONFIG;GENERATOR" "TARGETS;PASSTHROUGH" ${ARGN})
    if(_drv_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "drv_run: unknown args: ${_drv_UNPARSED_ARGUMENTS}")
    endif()
    set(_drv_dargs "-DFIXTURE=${_drv_FIXTURE}" "-DBUILD=${_drv_BUILD}")
    if(_drv_CONFIG)
        set(_drv_cfg "${_drv_CONFIG}")
    elseif(DEFINED ENV{POLYORCH_TEST_CONFIG})
        set(_drv_cfg "$ENV{POLYORCH_TEST_CONFIG}")
    else()
        set(_drv_cfg Debug)
    endif()
    list(APPEND _drv_dargs "-DCONFIG=${_drv_cfg}")
    if(_drv_GENERATOR)
        list(APPEND _drv_dargs "-DGENERATOR=${_drv_GENERATOR}")
    elseif(DEFINED ENV{POLYORCH_TEST_GENERATOR})
        list(APPEND _drv_dargs "-DGENERATOR=$ENV{POLYORCH_TEST_GENERATOR}")
    endif()
    # TARGETS/PASSTHROUGH carry REAL semicolons; appending "-DK=${v}" to a
    # list SPLITS at them (measured: list(APPEND "-DT=a;b") stores two
    # elements). Escape BEFORE appending -- the old boilerplate avoided this
    # by passing pre-escaped quoted literals.
    if(_drv_TARGETS)
        set(_drv_t "${_drv_TARGETS}")
        string(REPLACE ";" "\\;" _drv_t "${_drv_t}")
        list(APPEND _drv_dargs "-DTARGETS=${_drv_t}")
    endif()
    if(_drv_PASSTHROUGH)
        set(_drv_pt "${_drv_PASSTHROUGH}")
        string(REPLACE ";" "\\;" _drv_pt "${_drv_pt}")
        list(APPEND _drv_dargs "-DPASSTHROUGH=${_drv_pt}")
    endif()
    execute_process(COMMAND "${CMAKE_COMMAND}" ${_drv_dargs}
        -P "${CMAKE_CURRENT_LIST_DIR}/../fixtures/_driver.cmake"
        RESULT_VARIABLE ${_drv_out_rc}
        OUTPUT_VARIABLE ${_drv_out_log}
        ERROR_VARIABLE ${_drv_out_log})
    drv_echo(${_drv_out_log})
    if(_drv_SKIP_VAR)
        if("${${_drv_out_log}}" MATCHES "DRIVER: skip")
            set(${_drv_SKIP_VAR} TRUE)
        endif()
    endif()
    if(_drv_EXPECT_FAIL)
        if(${_drv_out_rc} EQUAL 0)
            message(FATAL_ERROR
                "expected the driver to fail, got rc=0\n${${_drv_out_log}}")
        endif()
    else()
        if(NOT ${_drv_out_rc} EQUAL 0)
            message(FATAL_ERROR "driver failed (rc=${${_drv_out_rc}})\n${${_drv_out_log}}")
        endif()
    endif()
endmacro()
