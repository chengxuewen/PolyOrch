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
