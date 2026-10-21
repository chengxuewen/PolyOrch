# t-node-pnpmws -- SR1 legs: (1) the packageManager field probes PM=pnpm,
# (2) polyorch_node_import enumerates members from pnpm-workspace.yaml when
# the root package.json has no workspaces field, (3) the historic hard error
# stays hard for the non-pnpm shape. Offline deterministic: the node-exe knob
# points at cmake itself (a harmless --version answerer), the PM goes through
# the checked-in pnpm stub -- no real toolchain, no capability gate.
cmake_policy(SET CMP0219 NEW)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")

_polyorch_pixi_scratch(_s)
get_filename_component(_fx
    "${CMAKE_CURRENT_LIST_DIR}/../fixtures/node-pnpm-ws" ABSOLUTE)
set(_pnpm "${CMAKE_CURRENT_LIST_DIR}/../fixtures/tool-stubs/bin/pnpm")

# ---- ON polarity: yaml enumeration + PM probe ------------------------------
execute_process(
    COMMAND "${CMAKE_COMMAND}" -S "${_fx}" -B "${_s}/on"
        "-DPolyOrchNodeExe=${CMAKE_COMMAND}"
        "-DPolyOrchNodePnpm=${_pnpm}"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
string(JOIN "\n" _all "${_out}" "${_err}")
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "pnpmws ON-leg configure failed (rc=${_rc}):\n${_all}")
endif()
string(FIND "${_all}" "PASS-PNPMWS" _hit)
ck(NOT _hit LESS 0)
# (the fixture FATALs unless the probe selected pnpm — the ON-leg rc already
# proves it; no second assertion needed here.)

# ---- OFF polarity: no workspaces, no yaml under a NON-pnpm probe -----------
# A root manifest WITHOUT packageManager (npm default) and WITHOUT the
# workspaces field must keep the historic FATAL (SR1 must not soften it).
set(_pcd "${CMAKE_CURRENT_LIST_DIR}/../../cmake")
set(_neg "${_s}/neg")
file(MAKE_DIRECTORY "${_neg}")
file(WRITE "${_neg}/package.json"
    "{\n  \"name\": \"neg-root\",\n  \"private\": true\n}\n")
file(WRITE "${_neg}/CMakeLists.txt"
    "cmake_minimum_required(VERSION 3.25)\n"
    "project(polyorch-neg-node-pnpmws LANGUAGES NONE)\n"
    "list(APPEND CMAKE_MODULE_PATH \"${_pcd}\")\n"
    "include(PolyOrchNodeHelpers)\n"
    "polyorch_node_setup()\n"
    "polyorch_node_import(ROOT \"\${CMAKE_CURRENT_SOURCE_DIR}/package.json\")\n")
execute_process(
    COMMAND "${CMAKE_COMMAND}" -S "${_neg}" -B "${_neg}/b"
        "-DPolyOrchNodeExe=${CMAKE_COMMAND}"
        "-DPolyOrchNodeNpm=/bin/echo"
    RESULT_VARIABLE _rc2 OUTPUT_VARIABLE _out2 ERROR_VARIABLE _err2)
ck(NOT _rc2 EQUAL 0)
string(JOIN "\n" _all2 "${_out2}" "${_err2}")
string(FIND "${_all2}" "has no workspaces field" _hit3)
ck(NOT _hit3 LESS 0)

message(STATUS "t-node-pnpmws: OK (probe + yaml enumeration + hard-error polarity)")
