# t-rust-installplan-stage -- SR5 P4/P5/P6/P7 on the FULL function, offline.
# A configure child forges one shared handle (t-rust-clean's stub-cache
# idiom) and installs it twice into separate build trees: the staged-shape
# call (GLOB_HEADERS + HEADERS_DIRECTORY + STALE_GLOB + STRIP) pins the
# generated cmake_install.cmake text (DIRECTORY leg, glob-expanded header
# rows, sweep-before-copy ordering, embedded keep-manifest, the
# CMAKE_INSTALL_DO_STRIP-gated leg); the no-kw negative pins that a plain
# call emits no CODE/DIRECTORY/sweep machinery at all.
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")

_polyorch_pixi_scratch(_s)
set(_art "${_s}/art")
file(MAKE_DIRECTORY "${_art}")
file(WRITE "${_art}/libkb.so" "x")
set(_inc "${_s}/inc")
file(MAKE_DIRECTORY "${_inc}/sub")
file(WRITE "${_inc}/a.h" "int a;")
file(WRITE "${_inc}/b.txt" "not a header")
file(WRITE "${_inc}/sub/c.hpp" "int c;")

set(_proj "${_s}/proj")
file(MAKE_DIRECTORY "${_proj}")
file(WRITE "${_proj}/CMakeLists.txt" [=[
cmake_minimum_required(VERSION 3.25)
project(rp-stage NONE)
include("${POLYORCH_CMAKE_DIR}/PolyOrchRustHelpers.cmake")
set(POLYORCH_RUST_HOST_TARGET "x86_64-unknown-linux-gnu" CACHE INTERNAL "")

add_library(kb SHARED IMPORTED GLOBAL)
set_property(TARGET kb PROPERTY IMPORTED_LOCATION "${POLYORCH_TEST_ART}/libkb.so")
set_property(TARGET kb PROPERTY POLYORCH_RUST_PACKAGE kb)
add_custom_target(kb-build)
set_property(TARGET kb-build PROPERTY POLYORCH_RUST_KIND shared)
set_property(TARGET kb-build PROPERTY POLYORCH_RUST_CRATE kb)

if(POLYORCH_STAGE_PLAIN)
    polyorch_rust_install(TARGETS kb)
else()
    polyorch_rust_install(TARGETS kb
        GLOB_HEADERS "${POLYORCH_TEST_INC}"
        HEADERS_DIRECTORY "${POLYORCH_TEST_INC}" DESTINATION include/tree
        STALE_GLOB "*.old" STRIP)
endif()
]=])

function(ck_has_all hay needle)
    string(FIND "${hay}" "${needle}" _a)
    if(_a LESS 0)
        message(FATAL_ERROR "check failed: [${needle}] not in generated install text")
    endif()
endfunction()

function(ck_absent hay needle)
    string(FIND "${hay}" "${needle}" _a)
    if(NOT _a LESS 0)
        message(FATAL_ERROR "check failed: [${needle}] unexpectedly in generated install text")
    endif()
endfunction()

macro(_cfg out_bld extra)
    set(_b "${_s}/${out_bld}")
    file(REMOVE_RECURSE "${_b}")
    execute_process(COMMAND ${CMAKE_COMMAND} -G "Unix Makefiles"
        -S "${_proj}" -B "${_b}" ${extra}
        "-DPOLYORCH_CMAKE_DIR=${CMAKE_CURRENT_LIST_DIR}/../../cmake"
        "-DPOLYORCH_TEST_ART=${_art}" "-DPOLYORCH_TEST_INC=${_inc}"
        RESULT_VARIABLE _rc OUTPUT_VARIABLE _o ERROR_VARIABLE _e)
    if(NOT _rc EQUAL 0)
        message(FATAL_ERROR "configure (${out_bld}) failed rc=${_rc}\n${_o}${_e}")
    endif()
    file(READ "${_b}/cmake_install.cmake" _inst_${out_bld})
    set(_log_${out_bld} "${_o}${_e}")
endmacro()

_cfg(staged "" _X)
set(_inst "${_inst_staged}")

# P5: the glob expanded to a.h only (non-recursive, default *.h* also takes
# b.txt? no -- b.txt matches *.h*? "b.txt" does NOT contain ".h"... c.hpp is
# under sub/ (excluded by non-recursive); a.h present, b.txt/c.hpp absent:
ck_has_all("${_inst}" "FILES \"${_inc}/a.h\"")
ck_absent("${_inst}" "b.txt")
ck_absent("${_inst}" "c.hpp")

# P4: one install(DIRECTORY) leg, tree preserved, DESTINATION honored:
ck_has_all("${_inst}" "DESTINATION \"\${CMAKE_INSTALL_PREFIX}/include/tree\" TYPE DIRECTORY FILES \"${_inc}/\"")

# P6: sweep legs run BEFORE the copy legs (registration order in the
# generated script); one per destination touched by file-shape rows, with
# the keep-manifest embedded:
string(FIND "${_inst}" "set(_polyorch_base" _swpos)
ck(NOT _swpos LESS 0)
string(FIND "${_inst}" "DESTINATION \"\${CMAKE_INSTALL_PREFIX}/lib\" TYPE FILE" _cppos)
ck(NOT _cppos LESS 0)
ck(_swpos LESS _cppos)
ck_has_all("${_inst}" "DESTINATION \"\${CMAKE_INSTALL_PREFIX}/include\" TYPE FILE")
string(REGEX MATCHALL "set\\(_polyorch_base" _swn "${_inst}")
list(LENGTH _swn _swcount)
ck(${_swcount} EQUAL 2)
ck_has_all("${_inst}" "set(_polyorch_keep \"libkb.so\")")
ck_has_all("${_inst}" "set(_polyorch_keep \"a.h\")")
ck_has_all("${_inst}" "\${_polyorch_base}/*.old")
ck_has_all("${_inst}" "if(NOT _polyorch_hit IN_LIST _polyorch_keep)")

# P7: STRIP emits the flag-gated leg after the copy row (tool resolved at
# configure time -- assert only if a strip binary is discoverable, the same
# contract the executor promises; the warning polarity covers its absence):
find_program(_strip_here NAMES strip)
if(_strip_here)
    ck_has_all("${_inst}" "if(CMAKE_INSTALL_DO_STRIP)")
    ck_has_all("${_inst}" "--strip-unneeded")
    ck_has_all("${_inst}" "\${_polyorch_strip_dir}/libkb.so")
    # strip leg sits AFTER the copy leg:
    string(FIND "${_inst}" "DESTINATION \"\${CMAKE_INSTALL_PREFIX}/lib\" TYPE FILE" _cp2)
    string(FIND "${_inst}" "if(CMAKE_INSTALL_DO_STRIP)" _st2)
    ck(_st2 GREATER _cp2)
else()
    ck_absent("${_inst}" "if(CMAKE_INSTALL_DO_STRIP)")
    string(REPLACE "\n" " " _lg "${_log_staged}")
    if(NOT _lg MATCHES "no strip tool found")
        message(FATAL_ERROR "missing-strip WARNING not loud:\n${_lg}")
    endif()
endif()

# negative leg: a plain call carries none of this machinery
_cfg(plain "-DPOLYORCH_STAGE_PLAIN=1" _X)
ck_absent("${_inst_plain}" "_polyorch_base")
ck_absent("${_inst_plain}" "_polyorch_strip")
ck_absent("${_inst_plain}" "CMAKE_INSTALL_DO_STRIP")
ck_absent("${_inst_plain}" "TYPE DIRECTORY")

message(STATUS "t-rust-installplan-stage: OK (P4/P5 rows + sweep ordering + keep-manifest + strip posture + plain negative)")
