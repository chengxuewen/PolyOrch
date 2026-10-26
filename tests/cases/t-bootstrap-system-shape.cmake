# t-bootstrap-system-shape -- D48 T2 (+T5): the trigger discipline.
# (1) A MISSING candidate (system-toolchain box, no pixi env) writes NOTHING
# anywhere and exits 0 -- a hint must never fail the configure that invoked
# it; its guidance points at the environment bootstrap instead (child leg,
# marker judged on the combined stream: STATUS rides stdout under capture,
# the WARNING rides stderr -- measured). (2) The self case
# (candidate == CMAKE_COMMAND) writes nothing: the toolchain-side invocation
# stays silent (never a self-referential guidance loop). (3) The absent
# branch writes nothing even when PolyOrch_VSCODE_DIR pre-exists.
cmake_policy(SET CMP0219 NEW)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchBootstrapHelpers.cmake")

_polyorch_pixi_scratch(_s)

# ---- child leg: absent-candidate guidance exits 0 ---------------------------
if(POLYORCH_BOOT_CHILD)
    polyorch_bootstrap_hint(CANDIDATE_CMAKE "${CMAKE_CURRENT_LIST_DIR}/no-such-cmake")
    message(STATUS "BOOT-CHILD-PASS")
    return()
endif()
execute_process(COMMAND "${CMAKE_COMMAND}" "-DPOLYORCH_BOOT_CHILD=1"
    -P "${CMAKE_CURRENT_LIST_FILE}" RESULT_VARIABLE _rc
    OUTPUT_VARIABLE _o ERROR_VARIABLE _e)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "child must exit 0 on the absent branch, rc=${_rc}: ${_e}")
endif()
string(JOIN "\n" _t "${_o}" "${_e}")
if(NOT _t MATCHES "BOOT-CHILD-PASS")
    message(FATAL_ERROR "child did not reach its pass marker: ${_t}")
endif()
if(NOT _t MATCHES "needs its dev environment bootstrapped")
    message(FATAL_ERROR "init guidance absent: ${_t}")
endif()

# ---- in-process: nothing is written on the absent branch --------------------
set(_ws "${_s}/wsroot")
set(PolyOrch_VSCODE_DIR "${_ws}/.vscode")
polyorch_bootstrap_hint(CANDIDATE_CMAKE "${_s}/missing/bin/cmake")
if(EXISTS "${_ws}")
    message(FATAL_ERROR "the absent branch wrote under the workspace")
endif()

# ---- self case: candidate == cmake -> silence -------------------------------
set(_ws5 "${_s}/wsroot5")
set(PolyOrch_VSCODE_DIR "${_ws5}/.vscode")
polyorch_bootstrap_hint(CANDIDATE_CMAKE "${CMAKE_COMMAND}")
if(EXISTS "${_ws5}")
    message(FATAL_ERROR "self case must not write anything")
endif()

message(STATUS "t-bootstrap-system-shape: OK (absent branch: no write + exit 0 + init guidance; self case: silence)")
