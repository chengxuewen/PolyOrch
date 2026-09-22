# expect-log defaultkinds: all legs pass
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")

# WP6 default kind pair: a kind-less polyorch_rust_build consults the
# PolyOrch_RUST_DEFAULT_KINDS cache (default STATIC;SHARED) and dispatches
# through the SAME single-kind machinery per entry, handles
# <TARGET>-static / -shared / -exe (the import dual-kind pairing convention,
# so the PIT-13 collision guard keeps its meaning per dispatched handle). An
# EXPLICITLY EMPTY list opts out and restores the historical
# "pick exactly one of BINARY, STATIC, SHARED" FATAL. Unknown entries FATAL
# naming the accepted set BEFORE anything is created.
# Deviation from the reference (ledgered): corrosion has no build-time
# default-kind surface -- its BUILD_SHARED_LIBS gate (corr:539-548) chooses
# which EXISTING pair member the umbrella links, not which kinds to build.

_polyorch_pixi_scratch(_s)
set(_cmkedir "${CMAKE_CURRENT_LIST_DIR}/../../cmake")

# --------------------------------------------------------- script-mode FATALs --
# Body-level injection is unnecessary: the kind block (and its validation)
# runs BEFORE the setup guard, so a bare call reaches every guard.
macro(ck_dk_fail name rx prelude)
    file(WRITE "${_s}/${name}.cmake"
        "include(\"${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake\")\n${prelude}\nmessage(FATAL_ERROR \"GUARD-NOT-FIRED\")\n")
    execute_process(
        COMMAND "${CMAKE_COMMAND}" -P "${_s}/${name}.cmake"
        RESULT_VARIABLE _dk_rc OUTPUT_VARIABLE _dk_o ERROR_VARIABLE _dk_e)
    string(REGEX REPLACE "[ \r\n\t]+" " " _dk_txt "${_dk_o}${_dk_e}")
    if(_dk_rc EQUAL 0)
        message(FATAL_ERROR "ck_dk_fail(${name}): child exited 0, expected FATAL [${rx}]")
    endif()
    if(_dk_txt MATCHES "GUARD-NOT-FIRED")
        message(FATAL_ERROR "ck_dk_fail(${name}): call passed validation (sentinel reached)")
    endif()
    if(NOT _dk_txt MATCHES "${rx}")
        message(FATAL_ERROR "ck_dk_fail(${name}): rc=${_dk_rc} but output lacks [${rx}]: ${_dk_txt}")
    endif()
endmacro()

set(_call "polyorch_rust_build(TARGET pair PACKAGE hello CRATE pair)")

# (1) explicit empty list = opt-out: the historical FATAL survives.
ck_dk_fail(dk-optout "pick exactly one of BINARY, STATIC, SHARED"
    "set(PolyOrch_RUST_DEFAULT_KINDS \"\" CACHE INTERNAL \"\")\n${_call}")

# (2) unknown kind in the list: FATAL names the knob and the accepted set,
#     with NO half-dispatch behind it (validation precedes the loop).
ck_dk_fail(dk-badkind "PolyOrch_RUST_DEFAULT_KINDS.*'weird'.*bin[|]static[|]shared"
    "set(PolyOrch_RUST_DEFAULT_KINDS \"static;weird\" CACHE INTERNAL \"\")\n${_call}")

# ---------------------------------------------------------- child harness ----
file(WRITE "${_s}/_dkinds.in" [==[
cmake_minimum_required(VERSION 3.25)
project(polyorch-dkinds LANGUAGES NONE)
list(APPEND CMAKE_MODULE_PATH "@CMKEDIR@")
include(PolyOrchRustHelpers)
set(POLYORCH_RUST_FOUND TRUE CACHE INTERNAL "")
set(POLYORCH_RUST_CARGO "@CMAKECMD@" CACHE INTERNAL "")
set(POLYORCH_RUST_RUSTC "@CMAKECMD@" CACHE INTERNAL "")
set(POLYORCH_RUST_HOST_TARGET "x86_64-unknown-linux-gnu" CACHE INTERNAL "")
set(POLYORCH_RUST_ROUTE "system" CACHE INTERNAL "")
set(POLYORCH_RUST_BIN_DIR "" CACHE INTERNAL "")
set(POLYORCH_RUST_CARGO_TARGET "" CACHE INTERNAL "")
@PRE@
polyorch_rust_build(TARGET pair PACKAGE hello CRATE pair)
foreach(h @HANDLES@)
    if(TARGET ${h} AND TARGET cargo-build-${h} AND TARGET ${h}-cargo)
        message(STATUS "KIND ${h} OK")
    endif()
endforeach()
if(NOT TARGET pair)
    message(STATUS "NOBARE OK")
endif()
]==])

function(dk_make dir out_var)
    cmake_parse_arguments(PARSE_ARGV 2 D "EXPECT_FAIL" "PRE;HANDLES" "DEFINES")
    file(MAKE_DIRECTORY "${dir}")
    file(READ "${_s}/_dkinds.in" _tpl)
    string(REPLACE "@CMKEDIR@" "${_cmkedir}" _tpl "${_tpl}")
    string(REPLACE "@CMAKECMD@" "${CMAKE_COMMAND}" _tpl "${_tpl}")
    string(REPLACE "@PRE@" "${D_PRE}" _tpl "${_tpl}")
    string(REPLACE "@HANDLES@" "${D_HANDLES}" _tpl "${_tpl}")
    file(WRITE "${dir}/CMakeLists.txt" "${_tpl}")
    set(_dargs "")
    foreach(_d IN LISTS D_DEFINES)
        list(APPEND _dargs "-D${_d}")
    endforeach()
    execute_process(COMMAND "${CMAKE_COMMAND}" -G "Unix Makefiles"
        -S "${dir}" -B "${dir}/b" ${_dargs}
        RESULT_VARIABLE _rc OUTPUT_VARIABLE _o ERROR_VARIABLE _e)
    set(${out_var}_rc "${_rc}" PARENT_SCOPE)
    set(${out_var}_out "${_o}${_e}" PARENT_SCOPE)
    if(NOT _rc EQUAL 0 AND NOT D_EXPECT_FAIL)
        message(FATAL_ERROR "dkinds child ${dir} configure failed (${_rc}):\n${_o}${_e}")
    endif()
endfunction()

# ===== child A: knob unset -> the STATIC;SHARED pair, suffixed handles ======
set(_A "${_s}/dk-default")
dk_make("${_A}" _A HANDLES "pair-static pair-shared")
string(FIND "${_A_out}" "KIND pair-static OK" _i1)
string(FIND "${_A_out}" "KIND pair-shared OK" _i2)
string(FIND "${_A_out}" "NOBARE OK" _i3)
ck(_i1 GREATER -1)
ck(_i2 GREATER -1)
ck(_i3 GREATER -1)
# the handles own distinct mediators with their own generated rules; the
# staticlib/shared distinction is the artifact naming, not extra cargo flags
# (same shape as an explicit STATIC/SHARED call).
set(_mkA1 "${_A}/b/CMakeFiles/cargo-build-pair-static.dir/build.make")
set(_mkA2 "${_A}/b/CMakeFiles/cargo-build-pair-shared.dir/build.make")
ck_file("${_mkA1}")
ck_file("${_mkA2}")
file(READ "${_mkA1}" _t1)
string(REPLACE "\\\n" " " _t1 "${_t1}")
if(NOT _t1 MATCHES "--package hello")
    message(FATAL_ERROR "pair-static rule lost its cargo identity")
endif()
if(_t1 MATCHES "--bin")
    message(FATAL_ERROR "a lib-kind rule carries --bin")
endif()
# the pair names are not artifact bases (libpair.a / libpair.so), so the
# dispatched builds passed the PIT-13 guard by construction -- the handles
# existing (STATUS above) is the proof the guard never mis-fired on 'pair'.

# ===== child B: knob = BIN -> single -exe handle, --bin in the rule =========
set(_B "${_s}/dk-bin")
dk_make("${_B}" _B HANDLES "pair-exe"
    DEFINES "PolyOrch_RUST_DEFAULT_KINDS=BIN")
string(FIND "${_B_out}" "KIND pair-exe OK" _j1)
ck(_j1 GREATER -1)
if(NOT "${_B_out}" MATCHES "NOBARE OK")
    message(FATAL_ERROR "child B kept a bare 'pair' target")
endif()
set(_mkB "${_B}/b/CMakeFiles/cargo-build-pair-exe.dir/build.make")
ck_file("${_mkB}")
file(READ "${_mkB}" _tB)
string(REPLACE "\\\n" " " _tB "${_tB}")
if(NOT _tB MATCHES "--bin pair")
    message(FATAL_ERROR "pair-exe rule lacks the --bin selector")
endif()
if(EXISTS "${_B}/b/CMakeFiles/cargo-build-pair-static.dir")
    message(FATAL_ERROR "child B produced a static handle despite the knob")
endif()

# ===== child C: dispatched handles join the GLOBAL namespace guard =========
# A pre-existing target occupying the mediator name must make the dispatch
# fail loudly (collision semantics preserved through the indirection).
set(_C "${_s}/dk-clash")
dk_make("${_C}" _C HANDLES "pair-static" EXPECT_FAIL
    PRE "add_custom_target(cargo-build-pair-static)")
if(_C_rc EQUAL 0)
    message(FATAL_ERROR "child C: mediator clash unexpectedly configured clean")
endif()
if(NOT _C_out MATCHES "cargo-build-pair-static")
    message(FATAL_ERROR "child C: clash output lacks the mediator name: ${_C_out}")
endif()

message(STATUS "defaultkinds: all legs pass")
