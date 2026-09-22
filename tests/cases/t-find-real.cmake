# requires: pixi
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

# polyorch_pixi_find against a real pixi, when this machine has one.
# SKIPs (exit 0) otherwise, so the suite stays portable.
polyorch_requires(pixi _req)
if(NOT _req)
    message(STATUS "t-find-real : SKIP (no pixi on this machine)")
    return()
endif()
# No pre-set: an empty normal variable would shadow the find result on
# cmake 4.4.3 (PIT -- the pre-D15 shape of this case silently skipped here).
find_program(_real NAMES pixi PATHS "$ENV{HOME}/.pixi/bin" "$ENV{PIXI_HOME}/bin")
ck(_real)

polyorch_pixi_find(QUIET)
ck(PolyOrch_PIXI_EXECUTABLE)
ck(PolyOrch_PIXI_VERSION MATCHES ^[0-9]+[.][0-9]+[.][0-9]+$)

# An impossible pin must hard-fail. Run in a child cmake -P: a FATAL_ERROR
# here would abort the file on its own success path.
execute_process(COMMAND "${CMAKE_COMMAND}"
    "-DPolyOrch_PIXI_EXECUTABLE=${_real}"
    -P "${CMAKE_CURRENT_LIST_DIR}/_find_oldpin.cmake"
    RESULT_VARIABLE _rc)
ck_fail_rc(_rc)

message(STATUS "find-real: OK (${PolyOrch_PIXI_VERSION})")
