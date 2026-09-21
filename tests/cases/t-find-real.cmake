include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")

# polyorch_pixi_find against a real pixi, when this machine has one.
# SKIPs (exit 0) otherwise, so the suite stays portable.
set(_real "")
find_program(_real NAMES pixi PATHS "$ENV{HOME}/.pixi/bin" "$ENV{PIXI_HOME}/bin")
if(NOT _real)
    message(STATUS "find-real: SKIP (no pixi on this machine)")
    return()
endif()

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
