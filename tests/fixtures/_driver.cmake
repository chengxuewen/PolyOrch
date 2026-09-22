# tests/fixtures/_driver.cmake -- external configure+build driver for the
# fixture projects under tests/fixtures/. Invoked by the thin e2e cases
# (tests/cases/t-rust-*.cmake) and usable standalone for debugging.
#
# Adapted from corrosion (MIT, commit c4786e7):
#   test/ConfigureAndBuild.cmake:70-120  (fresh-binary-dir remove, configure
#                                        with -G + pass-through -D args, then
#                                        build, each guarded by an rc check)
#   test/TestFileExists.cmake:11-26      (missing-artifact diagnosis walking up
#                                        to the nearest existing ancestor and
#                                        listing it)
#
# Invocation (all -D cache entries):
#   cmake -DFIXTURE=<abs dir> -DBUILD=<abs dir>
#         [-DGENERATOR=<gen>]            empty = default generator
#         [-DCONFIG=<Debug|Release>]     default Debug; -> -DCMAKE_BUILD_TYPE
#                                         (and -> --build --config <cfg> when
#                                          GENERATOR is a Multi-Config one)
#         [-DPASSTHROUGH=<a;b;c>]        ;-joined extra -D configure args
#         [-DTARGETS=<t1;t2>]            ;-joined build targets; empty = all
#        -P tests/fixtures/_driver.cmake
#
# Status-line contract (what the cases parse; message(STATUS) -> stderr):
#   DRIVER: configure rc=<n>
#   DRIVER: skip (<line>)                 only when the fixture's own
#                                         polyorch_requires gate skipped: the
#                                         configure output carried the contract
#                                         "<id> : SKIP (<reason>)" line, the
#                                         driver stops here and exits 0.
#   DRIVER: build rc=<n>
#   DRIVER: <key> <path>                  one per entry of
#                                         ${BUILD}/polyorch-fixture-artifacts.txt
#                                         (the fixture writes it at configure
#                                         time: lines "<key>=<abs path>",
#                                         configure-time values, never $<...>
#                                         genexes). The driver asserts each
#                                         path exists after the build.
# Any non-zero rc => FATAL_ERROR with the tail of the captured log (also
# persisted next to it as ${BUILD}/_configure.log / ${BUILD}/_build.log).

if(NOT FIXTURE OR NOT BUILD)
    message(FATAL_ERROR "_driver: FIXTURE and BUILD are both required (-D)")
endif()
if(NOT DEFINED CONFIG OR CONFIG STREQUAL "")
    set(CONFIG Debug)
endif()

# --- child-environment PATH composition --------------------------------------
# The tool (non-login) shell this driver runs under has neither ~/.cargo/bin
# nor ~/.pixi/bin on PATH (measured, WP0). The child configure/build steps may
# need both (pixi bootstrap, rust probes). We compose the CHILD ENVIRONMENT of
# those two execute_process calls only and deliberately never touch the env of
# this -P process: the capability probes of WP0 honesty
# (cases/_requires.cmake: `no-system-rust`, `system-rust`, `pixi`) run in the
# CALLING process tree, and if the driver mutated its own PATH the
# no-system-rust case would lie about the host. The parent stays truthful;
# only the fixture children see the augmented PATH.
set(_sep ":")
if(CMAKE_HOST_WIN32)
    set(_sep ";")
endif()
set(_cpath "$ENV{PATH}")
if(DEFINED ENV{HOME})
    foreach(_d "$ENV{HOME}/.cargo/bin" "$ENV{HOME}/.pixi/bin")
        if(EXISTS "${_d}")
            set(_cpath "${_d}${_sep}${_cpath}")
        endif()
    endforeach()
endif()
set(_cenv "PATH=${_cpath}")

# --- log-tail helper ----------------------------------------------------------
function(_drv_tail TEXT N OUT)
    string(REPLACE "\r" "" _t "${TEXT}")
    string(REPLACE "\n" ";" _ls "${_t}")
    list(LENGTH _ls _n)
    if(_n GREATER N)
        math(EXPR _start "${_n} - ${N}")
        list(SUBLIST _ls ${_start} ${N} _ls)
    endif()
    string(JOIN "\n" _out ${_ls})
    set(${OUT} "${_out}" PARENT_SCOPE)
endfunction()

# --- fresh build dir (ConfigureAndBuild.cmake:71-73 semantics) ---------------
file(REMOVE_RECURSE "${BUILD}")
file(MAKE_DIRECTORY "${BUILD}")

# --- configure ----------------------------------------------------------------
set(_cfg_args "${CMAKE_COMMAND}")
if(GENERATOR)
    list(APPEND _cfg_args "-G${GENERATOR}")
endif()
list(APPEND _cfg_args "-DCMAKE_BUILD_TYPE=${CONFIG}")
foreach(_extra IN LISTS PASSTHROUGH)
    list(APPEND _cfg_args "${_extra}")
endforeach()
list(APPEND _cfg_args "-S" "${FIXTURE}" "-B" "${BUILD}")

execute_process(COMMAND ${_cfg_args}
    ENVIRONMENT "${_cenv}"
    RESULT_VARIABLE _crc OUTPUT_VARIABLE _cout ERROR_VARIABLE _cerr)
string(APPEND _cout "${_cerr}")
file(WRITE "${BUILD}/_configure.log" "${_cout}")
message(STATUS "DRIVER: configure rc=${_crc}")
if(NOT _crc EQUAL 0)
    _drv_tail("${_cout}" 60 _tail)
    message(FATAL_ERROR
        "_driver: configure failed (rc=${_crc}); full log: ${BUILD}/_configure.log\n--- tail ---\n${_tail}")
endif()

# Fixture-gate relay: the project's own polyorch_requires probe skipped.
# Stop honestly (exit 0) and surface WHY, without ever echoing the contract
# skip line itself into the driver's stdout/stderr (the " : SKIP (" shape
# belongs to the case layer; see cases/_requires.cmake).
string(REGEX MATCH "[^\r\n]* : SKIP \\([^\r\n]*" _skip "${_cout}")
if(_skip)
    string(STRIP _skip "${_skip}")
    message(STATUS "DRIVER: skip (${_skip})")
    return()
endif()

# --- build ---------------------------------------------------------------------
set(_b_args "${CMAKE_COMMAND}" "--build" "${BUILD}")
if(GENERATOR MATCHES "Multi-Config")
    # MC children select the built config at build time, not configure time.
    list(APPEND _b_args "--config" "${CONFIG}")
endif()
if(TARGETS)
    list(APPEND _b_args "--target" ${TARGETS})
endif()
execute_process(COMMAND ${_b_args}
    ENVIRONMENT "${_cenv}"
    RESULT_VARIABLE _brc OUTPUT_VARIABLE _bout ERROR_VARIABLE _berr)
string(APPEND _bout "${_berr}")
file(WRITE "${BUILD}/_build.log" "${_bout}")
message(STATUS "DRIVER: build rc=${_brc}")
if(NOT _brc EQUAL 0)
    _drv_tail("${_bout}" 80 _tail)
    message(FATAL_ERROR
        "_driver: build failed (rc=${_brc}); full log: ${BUILD}/_build.log\n--- tail ---\n${_tail}")
endif()

# --- artifact contract -----------------------------------------------------------
set(_af "${BUILD}/polyorch-fixture-artifacts.txt")
if(NOT EXISTS "${_af}")
    message(FATAL_ERROR
        "_driver: fixture ${FIXTURE} declared no artifacts (${_af} missing); "
        "every fixture must write POLYORCH_FIXTURE_ARTIFACTS at configure time")
endif()
file(STRINGS "${_af}" _entries)
foreach(_e IN LISTS _entries)
    if(NOT _e MATCHES "^([A-Za-z0-9_]+)=(.*)$")
        message(FATAL_ERROR "_driver: bad artifact entry '${_e}' (want key=path)")
    endif()
    set(_key "${CMAKE_MATCH_1}")
    set(_val "${CMAKE_MATCH_2}")
    if(NOT EXISTS "${_val}")
        # TestFileExists.cmake:11-26 mechanics: walk to the nearest existing
        # ancestor and list it, so a missing artifact names its neighborhood.
        set(_missing_msg "DRIVER: artifact '${_key}' missing: ${_val}")
        set(_dir "${_val}")
        while(NOT _dir STREQUAL "")
            if(EXISTS "${_dir}")
                file(GLOB _items LIST_DIRECTORIES true "${_dir}/*")
                list(SORT _items)
                list(LENGTH _items _n)
                if(_n GREATER 40)
                    list(SUBLIST _items 0 40 _items)
                    list(APPEND _items "... (truncated)")
                endif()
                string(JOIN "\n    " _listing ${_items})
                string(APPEND _missing_msg "\n  nearest existing ancestor ${_dir} contains:\n    ${_listing}")
                break()
            endif()
            get_filename_component(_dir "${_dir}" DIRECTORY)
        endwhile()
        message(FATAL_ERROR "${_missing_msg}")
    endif()
    message(STATUS "DRIVER: ${_key} ${_val}")
endforeach()
