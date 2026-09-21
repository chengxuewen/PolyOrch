# PolyOrch CMake test cases -- each cases/t-*.cmake is a `cmake -P` script
# whose verdict is its exit code, mirroring tests/run.sh. The in-file markers
# are the single source of truth shared by both runners:
#   first line "# expect: fail"      -> the case MUST FATAL_ERROR (WILL_FAIL)
#   first line "# expect-log <re>"   -> case must exit 0 AND its output must
#     MATCH <re> (PASS_REGULAR_EXPRESSION); an optional SECOND line
#     "# expect-no-log <re>" adds FAIL_REGULAR_EXPRESSION. run.sh mirrors this
#     by grepping the captured log; keep case regexes portable across both
#     engines (plain phrases work; ctest matches its OWN capture of the
#     process output, which for cmake -P includes stderr passthrough).
#   "# e2e: required" in lines 1-2   -> solves a real environment (may reach
#                                       -DPolyOrch_TEST_E2E=ON
polyorch_option(PolyOrch_TEST_E2E "Register the e2e cases that solve a pixi environment" OFF)

# Script-mode scratch falls back to the environment temp; pin it into the
# build dir so a ctest run leaves nothing behind in /tmp (or the source tree).
set(_scratch "${CMAKE_CURRENT_BINARY_DIR}/scratch")
file(MAKE_DIRECTORY "${_scratch}")

file(GLOB _cases CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/cases/t-*.cmake")
list(SORT _cases)
foreach(_case IN LISTS _cases)
    get_filename_component(_name "${_case}" NAME_WE)
    file(READ "${_case}" _head LIMIT 200)

    if(_head MATCHES "^# e2e: required(\n|$)|^#[^\n]*\n# e2e: required(\n|$)")
        set(_is_e2e ON)
    else()
        set(_is_e2e OFF)
    endif()
    if(_is_e2e AND NOT PolyOrch_TEST_E2E)
        continue()
    endif()

    add_test(NAME "${_name}" COMMAND ${CMAKE_COMMAND} -P "${_case}")
    set_tests_properties("${_name}" PROPERTIES
        ENVIRONMENT "TMPDIR=${_scratch};TEMP=${_scratch}")
    if(_head MATCHES "^# expect: fail(\n|$)")
        set_tests_properties("${_name}" PROPERTIES WILL_FAIL TRUE)
    else()
        # expect-log / expect-no-log: first line, optional second line.
        if(_head MATCHES "^# expect-log ([^\n]*)\n")
            set_tests_properties("${_name}" PROPERTIES
                PASS_REGULAR_EXPRESSION "${CMAKE_MATCH_1}")
        endif()
        if(_head MATCHES "^#[^\n]*\n# expect-no-log ([^\n]*)\n")
            set_tests_properties("${_name}" PROPERTIES
                FAIL_REGULAR_EXPRESSION "${CMAKE_MATCH_1}")
        endif()
    endif()
    if(_is_e2e)
        set_tests_properties("${_name}" PROPERTIES LABELS e2e TIMEOUT 600)
    else()
        set_tests_properties("${_name}" PROPERTIES TIMEOUT 120)
    endif()
endforeach()


# The generator's built-in `test` target is directory-scoped, so it is
# invisible to project-target UIs (CMakeTools build dropdown, CMake outline).
# A project-level umbrella target makes running the suite a first-class
# operation in exactly those UIs, next to the PolyOrchExample* targets.
add_custom_target(PolyOrchTest
    COMMAND ${CMAKE_CTEST_COMMAND}
        --test-dir "${CMAKE_CURRENT_BINARY_DIR}"
        --output-on-failure
    COMMENT "Running the PolyOrch cmake -P test suite via CTest")
set_target_properties(PolyOrchTest PROPERTIES FOLDER ${PROJECT_NAME}/tests)