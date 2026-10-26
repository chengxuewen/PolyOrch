# t-node-strip-scopes -- D47 legs: (1) strip ON: '@mediaservo/*' collapses to
# the bare member name ('admin', 'client') and the bare package keeps its own
# name; (2) strip OFF: byte-identical legacy forms ('mediaservo-admin',
# 'mediaservo-client'); (3) scope-form normalization: "@mediaservo",
# "mediaservo", "mediaservo/" all match the same scope; (4) collision FATAL
# preserved: stripping must not silently merge two members onto one handle --
# a scoped 'x/a' beside a bare 'x' still FATALs under an ON list. Offline
# deterministic: node-exe knob = cmake itself, PM knob = /bin/echo; the
# -build mediators exist but never run. The fixture's import asserts handles
# exactly (PASS-STRIP line lists them).
cmake_policy(SET CMP0219 NEW)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")

_polyorch_pixi_scratch(_s)
get_filename_component(_fx
    "${CMAKE_CURRENT_LIST_DIR}/../fixtures/node-strip-scopes" ABSOLUTE)

# ---- ON polarity + (3) scope-form normalization ----------------------------
# Three configure passes, three spellings of the same scope; all must yield
# the identical stripped+prefixed handle set.
foreach(_form "@mediaservo" "mediaservo" "mediaservo/")
    execute_process(
        COMMAND "${CMAKE_COMMAND}" -S "${_fx}" -B "${_s}/on-${_form}"
            "-DPolyOrchNodeExe=${CMAKE_COMMAND}"
            "-DPolyOrchNodeNpm=/bin/echo"
            "-DPolyOrch_NODE_TARGET_PREFIX=px"
            "-DPolyOrch_NODE_STRIP_SCOPES=${_form}"
        RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
    string(JOIN "\n" _all "${_out}" "${_err}")
    if(NOT _rc EQUAL 0)
        message(FATAL_ERROR
            "strip ON (scope form '${_form}') configure failed (rc=${_rc}):\n${_all}")
    endif()
    string(FIND "${_all}" "PASS-STRIP [px-admin;px-client;px-client-legacy]" _hit2)
    ck(NOT _hit2 LESS 0)
endforeach()

# ---- OFF polarity: byte-identical legacy forms -----------------------------
execute_process(
    COMMAND "${CMAKE_COMMAND}" -S "${_fx}" -B "${_s}/off"
        "-DPolyOrchNodeExe=${CMAKE_COMMAND}"
        "-DPolyOrchNodeNpm=/bin/echo"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
string(JOIN "\n" _allo "${_out}" "${_err}")
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "strip OFF configure failed (rc=${_rc}):\n${_allo}")
endif()
string(FIND "${_allo}" "PASS-STRIP [mediaservo-admin;mediaservo-client;client-legacy]" _hit4)
ck(NOT _hit4 LESS 0)
# no prefixed handle may exist when no prefix was given
string(FIND "${_allo}" "px-" _bait)
ck(_bait LESS 0)

# ---- collision FATAL preserved ---------------------------------------------
set(_pcd "${CMAKE_CURRENT_LIST_DIR}/../../cmake")
set(_neg "${_s}/neg")
file(MAKE_DIRECTORY "${_neg}/a")
file(WRITE "${_neg}/package.json"
    "{\n  \"name\": \"neg-root\",\n  \"private\": true,\n"
    "  \"workspaces\": [\"a/*\"]\n}\n")
file(WRITE "${_neg}/a/scoped/package.json"
    "{\n  \"name\": \"@x/a\",\n  \"version\": \"0.0.0\", \"private\": true\n}\n")
file(WRITE "${_neg}/a/bare/package.json"
    "{\n  \"name\": \"a\",\n  \"version\": \"0.0.0\", \"private\": true\n}\n")
file(WRITE "${_neg}/CMakeLists.txt"
    "cmake_minimum_required(VERSION 3.25)\n"
    "project(polyorch-neg-strip LANGUAGES NONE)\n"
    "list(APPEND CMAKE_MODULE_PATH \"${_pcd}\")\n"
    "include(PolyOrchNodeHelpers)\n"
    "polyorch_node_setup()\n"
    "polyorch_node_import(ROOT \"\${CMAKE_CURRENT_SOURCE_DIR}/package.json\")\n")
execute_process(
    COMMAND "${CMAKE_COMMAND}" -S "${_neg}" -B "${_neg}/b"
        "-DPolyOrchNodeExe=${CMAKE_COMMAND}"
        "-DPolyOrchNodeNpm=/bin/echo"
        "-DPolyOrch_NODE_STRIP_SCOPES=x"
    RESULT_VARIABLE _rc2 OUTPUT_VARIABLE _out2 ERROR_VARIABLE _err2)
ck(NOT _rc2 EQUAL 0)
string(JOIN "\n" _all2 "${_out2}" "${_err2}")
string(FIND "${_all2}" "duplicate sanitized handle" _hit5)
ck(NOT _hit5 LESS 0)

message(STATUS "t-node-strip-scopes: OK (strip on/off + scope forms + collision FATAL)")
