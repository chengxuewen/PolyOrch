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
        message(FATAL_ERROR "missing file (line ${CMAKE_CURRENT_LIST_LINE}): ${p}")
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
