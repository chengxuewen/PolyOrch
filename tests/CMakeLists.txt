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
#   "# requires: <cap>" by line 3     -> AFTER the expect/e2e markers. The
#     capability probe runs IN THE CASE (cases/_requires.cmake); the drivers
#     read the marker only to decide the SKIP contract below, never to
#     pre-gate -- so ctest and run.sh behave identically for free. A marked
#     case may print the contract skip line "<stem> : SKIP (<reason>)" and
#     exit 0 -> ctest reports Skipped (SKIP_REGULAR_EXPRESSION). An UNMARKED
#     want-pass case printing ": SKIP (" is a silent skip -> vetoed via
#     FAIL_REGULAR_EXPRESSION. Full contract: cases/_requires.cmake.
polyorch_option(PolyOrch_TEST_E2E "Register the e2e cases that solve a pixi environment" OFF)

# Script-mode scratch falls back to the environment temp; pin it into the
# build dir so a ctest run leaves nothing behind in /tmp (or the source tree).
set(_scratch "${CMAKE_CURRENT_BINARY_DIR}/scratch")
file(MAKE_DIRECTORY "${_scratch}")

file(GLOB _cases CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/cases/t-*.cmake")
list(SORT _cases)
foreach(_case IN LISTS _cases)
    get_filename_component(_name "${_case}" NAME_WE)
    # ctest namespace pilot (plan 2026-09-22-test-namespace.md): the ctest
    # view name is polyorch::<stem>; case file stems and the run.sh SKIP
    # contract lines stay bare. CMP0110 (3.19+) allows '::' in the name;
    # our floor is 3.22. Revert = delete this one line.
    set(_tname "polyorch::${_name}")
    file(READ "${_case}" _head LIMIT 400)

    if(_head MATCHES "^# e2e: required(\n|$)|^#[^\n]*\n# e2e: required(\n|$)")
        set(_is_e2e ON)
    else()
        set(_is_e2e OFF)
    endif()
    if(_is_e2e AND NOT PolyOrch_TEST_E2E)
        continue()
    endif()

    add_test(NAME "${_tname}" COMMAND ${CMAKE_COMMAND} -P "${_case}")
    set_tests_properties("${_tname}" PROPERTIES
        ENVIRONMENT "TMPDIR=${_scratch};TEMP=${_scratch}")
    if(_head MATCHES "^# expect: fail(\n|$)")
        set_tests_properties("${_tname}" PROPERTIES WILL_FAIL TRUE)
    else()
        # expect-log / expect-no-log: first line, optional second line.
        set(_fail_rx "")
        if(_head MATCHES "^# expect-log ([^\n]*)\n")
            set_tests_properties("${_tname}" PROPERTIES
                PASS_REGULAR_EXPRESSION "${CMAKE_MATCH_1}")
        endif()
        if(_head MATCHES "^#[^\n]*\n# expect-no-log ([^\n]*)\n")
            list(APPEND _fail_rx "${CMAKE_MATCH_1}")
        endif()
        # SKIP contract (see header): marked cases skip honestly (Skipped);
        # unmarked ones get the ": SKIP (" veto folded into the FAIL regex.
        # (CMake regex cannot quantify a group with {0,2} -- measured; the
        # three explicit line-position alternatives are the portable form.)
        # Route labels (dual-route testing, plan 2026-09-23): derive from the
        # requires TOKEN, not a raw string grep (a bare 'pixi' grep would
        # miss 'pixi-rust' family members). CMake regex: extract the token
        # after '# requires: ' from the same three line positions as above.
        set(_req_tok "")
        # 'requires:' appears exactly once per case header (driver contract);
        # an unanchored single match is the portable form (the three
        # line-position variants and \n escaping of the sibling blocks are
        # only needed for anchored validation, not for token extraction).
        if(_head MATCHES "# requires: ([a-z-]+)")
            set(_req_tok "${CMAKE_MATCH_1}")
        endif()
        set(_labels "")
        if(_req_tok MATCHES "^system-rust")
            list(APPEND _labels system)
        endif()
        if(_req_tok MATCHES "^pixi")
            list(APPEND _labels pixi)
        endif()
        if(_head MATCHES "^# requires: " OR _head MATCHES "^#[^\\n]*\\n# requires: " OR _head MATCHES "^#[^\\n]*\\n#[^\\n]*\\n# requires: ")
            set(_has_req ON)
        else()
            set(_has_req OFF)
        endif()
        if(_has_req)
            set_tests_properties("${_tname}" PROPERTIES
                SKIP_REGULAR_EXPRESSION ": SKIP \\(")
        else()
            list(APPEND _fail_rx ": SKIP \\(")
        endif()
        if(_fail_rx)
            set_tests_properties("${_tname}" PROPERTIES
                FAIL_REGULAR_EXPRESSION "${_fail_rx}")
        endif()
    endif()
    # Route labels ride every leg (dual-route plan WP1).
    if(_labels)
        set_tests_properties("${_tname}" PROPERTIES LABELS "${_labels}")
    endif()
    # Dual-route bud (WP2): cache -D wins, then the env var, so both the
    # ctest.sh env path and the matrix -D path light the same bud.
    set(_env "TMPDIR=${_scratch};TEMP=${_scratch}")
    if(PolyOrch_TEST_RUST_FROM)
        set(_from "${PolyOrch_TEST_RUST_FROM}")
    elseif(DEFINED ENV{POLYORCH_TEST_RUST_FROM})
        set(_from "$ENV{POLYORCH_TEST_RUST_FROM}")
    endif()
    if(_from)
        string(APPEND _env ";POLYORCH_TEST_RUST_FROM=${_from}")
    endif()
    if(_is_e2e)
        set_tests_properties("${_tname}" PROPERTIES ENVIRONMENT "${_env}" TIMEOUT 600)
    else()
        set_tests_properties("${_tname}" PROPERTIES ENVIRONMENT "${_env}" TIMEOUT 120)
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
# Per-route umbrellas (dual-route plan WP1): the ctest tree of THIS build
# dir was configured with ONE route, so the umbrellas filter by LABEL --
# no product-code coupling. Hyphen names: '::' is illegal in target names
# (alias syntax, measured); the ctest namespace keeps polyorch::t-*.
foreach(_route system pixi)
    add_custom_target(polyorch-tests-${_route}
        COMMAND ${CMAKE_CTEST_COMMAND}
            --test-dir "${CMAKE_CURRENT_BINARY_DIR}"
            --output-on-failure -L ${_route}
        COMMENT "PolyOrch tests: ${_route}-route legs via CTest")
    set_target_properties(polyorch-tests-${_route} PROPERTIES
        FOLDER ${PROJECT_NAME}/tests)
endforeach()
