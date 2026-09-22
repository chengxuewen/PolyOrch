# expect-log knobs: all legs pass
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")

# WP6 import-time global defaults (PolyOrch_RUST_* cache knobs, corr shape:
# per-call COR_ALL_FEATURES/COR_NO_DEFAULT_FEATURES/COR_NO_USES_TERMINAL at
# corr:690-700 + the global CORROSION_VERBOSE_OUTPUT flag at corr:21,588-589,
# 891 -- ours are CACHE-LEVEL defaults folded into the SAME property-carrier
# genex chain, applied when the per-target knob is absent, never overrides).
#
# Assertion layers (all offline -- fake POLYORCH_RUST_* caches, cmake-as-cargo,
# nothing executes):
#  1. Unix Makefiles children: generated build.make text proves --verbose,
#     --all-features, --no-default-features and the global cargo flags reach
#     the rule, and a baseline child (no knobs set) proves the token absence
#     (the anti-false-green leg);
#  2. the non-leak leg: a per-target polyorch_rust_set_features call AFTER the
#     build REPLACES the defaulted properties -- the global --all-features /
#     --no-default-features must then be ABSENT from that rule while a sibling
#     rule without the setter still carries them (defaults, not overrides);
#  3. Ninja children: USES_TERMINAL has no Makefile text (measured), so the
#     NO_USES_TERMINAL inverse-polarity default (corr:696-700 kept exactly:
#     default = the cargo rules ask for the console; the knob removes it) is
#     asserted on the generated edge's "pool = console" attribute -- present
#     by default, gone with the knob, for the build-mediator artifact edge and
#     the cargo-test rule alike.
#  4. script-mode validation: build(FEATURES ...) + global ALL_FEATURES is the
#     same contradiction the setter rejects -> configure-time FATAL.

_polyorch_pixi_scratch(_s)
set(_cmkedir "${CMAKE_CURRENT_LIST_DIR}/../../cmake")

# --------------------------------------------------------- script-mode FATALs --
macro(ck_call_fail name rx)
    set(_cf_body "${ARGN}")
    string(REPLACE ";" "\n" _cf_body "${_cf_body}")
    file(WRITE "${_s}/${name}.cmake"
        "include(\"${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake\")\nset(PolyOrch_RUST_ALL_FEATURES ON)\n${_cf_body}\nmessage(FATAL_ERROR \"GUARD-NOT-FIRED\")\n")
    execute_process(
        COMMAND "${CMAKE_COMMAND}" -P "${_s}/${name}.cmake"
        RESULT_VARIABLE _cf_rc OUTPUT_VARIABLE _cf_o ERROR_VARIABLE _cf_e)
    string(REGEX REPLACE "[ \r\n\t]+" " " _cf_txt "${_cf_o}${_cf_e}")
    if(_cf_rc EQUAL 0)
        message(FATAL_ERROR "ck_call_fail(${name}): child exited 0, expected FATAL matching [${rx}]")
    endif()
    if(_cf_txt MATCHES "GUARD-NOT-FIRED")
        message(FATAL_ERROR "ck_call_fail(${name}): call passed validation (sentinel reached)")
    endif()
    if(NOT _cf_txt MATCHES "${rx}")
        message(FATAL_ERROR "ck_call_fail(${name}): rc=${_cf_rc} but output lacks [${rx}]: ${_cf_txt}")
    endif()
endmacro()

# FEATURES on the call + the global ALL_FEATURES default: cargo would receive
# both --features= and --all-features; rejected at configure like the setter
# rejects the pair (t-rust-setters precedent). Fires BEFORE any target is
# created, so script mode reaches the guard.
ck_call_fail(knobs-feat-vs-global
    "polyorch_rust_build: FEATURES and PolyOrch_RUST_ALL_FEATURES are mutually exclusive"
    "set(POLYORCH_RUST_FOUND TRUE CACHE INTERNAL \"\")"
    "set(POLYORCH_RUST_CARGO \"${CMAKE_COMMAND}\" CACHE INTERNAL \"\")"
    "set(POLYORCH_RUST_HOST_TARGET \"x86_64-unknown-linux-gnu\" CACHE INTERNAL \"\")"
    "set(POLYORCH_RUST_ROUTE \"system\" CACHE INTERNAL \"\")"
    "polyorch_rust_build(TARGET kn-fp PACKAGE krate CRATE kcrate BINARY FEATURES a)")

# ---------------------------------------------------------- child harness ----
file(WRITE "${_s}/_knobs.in" [==[
cmake_minimum_required(VERSION 3.25)
project(polyorch-knobs LANGUAGES NONE)
list(APPEND CMAKE_MODULE_PATH "@CMKEDIR@")
include(PolyOrchRustHelpers)
set(POLYORCH_RUST_FOUND TRUE CACHE INTERNAL "")
set(POLYORCH_RUST_CARGO "@CMAKECMD@" CACHE INTERNAL "")
set(POLYORCH_RUST_RUSTC "@CMAKECMD@" CACHE INTERNAL "")
set(POLYORCH_RUST_HOST_TARGET "x86_64-unknown-linux-gnu" CACHE INTERNAL "")
set(POLYORCH_RUST_ROUTE "system" CACHE INTERNAL "")
set(POLYORCH_RUST_BIN_DIR "" CACHE INTERNAL "")
set(POLYORCH_RUST_CARGO_TARGET "" CACHE INTERNAL "")
polyorch_rust_build(TARGET k-bin PACKAGE krate CRATE kcrate BINARY)
polyorch_rust_build(TARGET k-lib PACKAGE krate CRATE kcrate STATIC)
polyorch_rust_test(PACKAGE krate NAME k-test)
if(@SKF@)
    polyorch_rust_set_features(TARGET k-bin FEATURES zz)
endif()
]==])

function(knobs_make dir gen skf)
    file(MAKE_DIRECTORY "${dir}")
    file(READ "${_s}/_knobs.in" _tpl)
    string(REPLACE "@CMKEDIR@" "${_cmkedir}" _tpl "${_tpl}")
    string(REPLACE "@CMAKECMD@" "${CMAKE_COMMAND}" _tpl "${_tpl}")
    string(REPLACE "@SKF@" "${skf}" _tpl "${_tpl}")
    file(WRITE "${dir}/CMakeLists.txt" "${_tpl}")
    cmake_parse_arguments(PARSE_ARGV 3 K "" "" "DEFINES")
    set(_dargs "")
    foreach(_d IN LISTS K_DEFINES)
        list(APPEND _dargs "-D${_d}")
    endforeach()
    execute_process(COMMAND "${CMAKE_COMMAND}" -G "${gen}"
        -S "${dir}" -B "${dir}/b" ${_dargs}
        RESULT_VARIABLE _rc OUTPUT_VARIABLE _o ERROR_VARIABLE _e)
    if(NOT _rc EQUAL 0)
        message(FATAL_ERROR "knobs child ${dir} (${gen}) configure failed (${_rc}):\n${_o}${_e}")
    endif()
endfunction()

macro(knobs_mk_read dir tgt out)
    set(_mkf "${dir}/b/CMakeFiles/cargo-build-${tgt}.dir/build.make")
    ck_file("${_mkf}")
    file(READ "${_mkf}" _mkt)
    string(REPLACE "\\\n" " " _mkt "${_mkt}")   # rejoin folded recipe lines
    set(${out} "${_mkt}")
endmacro()

# The build.make of the cargo-test rule of a named target.
macro(knobs_test_mk_read dir tgt out)
    set(_mkf "${dir}/b/CMakeFiles/${tgt}.dir/build.make")
    ck_file("${_mkf}")
    file(READ "${_mkf}" _mkt)
    string(REPLACE "\\\n" " " _mkt "${_mkt}")
    set(${out} "${_mkt}")
endmacro()

# ---------------------------------------------------------------- ninja pool --
# USES_TERMINAL on a ninja CUSTOM_COMMAND edge materializes as a
# "pool = console" attribute. One edge window = from the anchored
# "build ...: CUSTOM_COMMAND" header to the next "\nbuild " statement,
# so a neighbouring edge's pool can never leak into the assertion.
function(nj_edge file needle out)
    file(READ "${file}" _nj)
    string(FIND "${_nj}" "${needle}" _i)
    if(_i LESS 0)
        message(FATAL_ERROR "nj_edge: no [${needle}] in ${file}")
    endif()
    string(SUBSTRING "${_nj}" ${_i} -1 _rest)
    string(FIND "${_rest}" "\nbuild " _n)
    if(_n GREATER 0)
        string(SUBSTRING "${_rest}" 0 ${_n} _win)
    else()
        set(_win "${_rest}")
    endif()
    set(${out} "${_win}" PARENT_SCOPE)
endfunction()

macro(ck_pool win want)
    if("${want}" STREQUAL "yes" AND NOT "${${win}}" MATCHES "pool = console")
        message(FATAL_ERROR "ninja edge lacks the console pool (USES_TERMINAL default) [line ${CMAKE_CURRENT_LIST_LINE}]")
    endif()
    if("${want}" STREQUAL "no" AND "${${win}}" MATCHES "pool = console")
        message(FATAL_ERROR "ninja edge carries the console pool despite NO_USES_TERMINAL [line ${CMAKE_CURRENT_LIST_LINE}]")
    endif()
endmacro()

# =============================== layer 1: global knobs -> rule text ==========
# Child A: baseline, no knobs set. The ANTI-false-green leg: none of the
# tokens may appear (the knobs are what make child B's text, not luck).
set(_A "${_s}/kn-base")
knobs_make("${_A}" "Unix Makefiles" FALSE)
knobs_mk_read("${_A}" k-bin _mkA)
knobs_mk_read("${_A}" k-lib _mkA2)
knobs_test_mk_read("${_A}" k-test _mkAT)
foreach(_tok --verbose --all-features --no-default-features --offline)
    if("${_mkA}" MATCHES "${_tok}")
        message(FATAL_ERROR "baseline k-bin rule unexpectedly carries [${_tok}]")
    endif()
endforeach()
# The staticlib native-libs guard and the host-layer shape stay intact
# regardless of knobs (regression smoke on the same text).
if(NOT "${_mkA2}" MATCHES "--package krate")
    message(FATAL_ERROR "baseline k-lib rule lost its cargo identity")
endif()
# VERBOSE mirrors the reference (corr:891: the cargo-BUILD command only), so
# the cargo-test rule must NOT carry --verbose even under the knob -> proven
# by the VERBOSE child's test rule below staying flag-free.

# Child B: all four content knobs ON.
set(_B "${_s}/kn-on")
knobs_make("${_B}" "Unix Makefiles" FALSE
    DEFINES
        "PolyOrch_RUST_VERBOSE=ON"
        "PolyOrch_RUST_ALL_FEATURES=ON"
        "PolyOrch_RUST_NO_DEFAULT_FEATURES=ON"
        "PolyOrch_RUST_CARGO_FLAGS=--offline\;--timings")
knobs_mk_read("${_B}" k-bin _mkB)
knobs_mk_read("${_B}" k-lib _mkB2)
knobs_test_mk_read("${_B}" k-test _mkBT)
foreach(_tok "--verbose" "--all-features" "--no-default-features" "--offline" "--timings")
    if(NOT "${_mkB}" MATCHES "${_tok}")
        message(FATAL_ERROR "knobs-on k-bin rule lacks [${_tok}]")
    endif()
endforeach()
if(NOT "${_mkB2}" MATCHES "--all-features")
    message(FATAL_ERROR "knobs-on k-lib rule lacks --all-features")
endif()
# VERBOSE mirror boundary: the cargo-test rule carries no --verbose (the
# reference sets the flag on the build command only).
if("${_mkBT}" MATCHES "--verbose")
    message(FATAL_ERROR "the cargo-test rule must not carry --verbose (corr:891 build-command-only mirror)")
endif()
# The test rule is cargo-free of the feature knobs too (they are build-rule
# inputs in this architecture; no silent spread).
if("${_mkBT}" MATCHES "--all-features")
    message(FATAL_ERROR "the cargo-test rule unexpectedly carries --all-features")
endif()
if(NOT "${_mkBT}" MATCHES "--package krate")
    message(FATAL_ERROR "the cargo-test rule lost its cargo identity")
endif()

# =============== layer 2: defaults must NOT override a per-target knob =======
# Child C: same globals, plus a per-target set_features(FEATURES zz) on
# k-bin AFTER the build. The setter is write-through: it replaces all three
# feature properties, so k-bin must show --features=zz and NONE of the
# defaulted selectors, while k-lib (no setter) keeps the defaults intact.
set(_C "${_s}/kn-override")
knobs_make("${_C}" "Unix Makefiles" TRUE
    DEFINES
        "PolyOrch_RUST_ALL_FEATURES=ON"
        "PolyOrch_RUST_NO_DEFAULT_FEATURES=ON")
knobs_mk_read("${_C}" k-bin _mkC)
knobs_mk_read("${_C}" k-lib _mkC2)
if(NOT "${_mkC}" MATCHES "--features=zz")
    message(FATAL_ERROR "override child: k-bin lacks the per-target --features=zz")
endif()
foreach(_tok "--all-features" "--no-default-features")
    if("${_mkC}" MATCHES "${_tok}")
        message(FATAL_ERROR "override child: the global default [${_tok}] leaked into the setter-overridden k-bin rule")
    endif()
endforeach()
if(NOT "${_mkC2}" MATCHES "--all-features" OR NOT "${_mkC2}" MATCHES "--no-default-features")
    message(FATAL_ERROR "override child: k-lib lost the global defaults (siblings of a setter-overridden target keep them)")
endif()

# ================== layer 3: USES_TERMINAL polarity on generated ninja =======
# Child D: default (knob unset) -> every cargo-carrying ninja edge has the
# console pool. Child E: NO_USES_TERMINAL=ON -> gone on both edges.
set(_D "${_s}/kn-uterm-def")
knobs_make("${_D}" "Ninja" FALSE)
nj_edge("${_D}/b/build.ninja" "libkcrate.a: CUSTOM_COMMAND" _eD1)
ck_pool(_eD1 yes)
nj_edge("${_D}/b/build.ninja" "CMakeFiles/k-test: CUSTOM_COMMAND" _eD2)
ck_pool(_eD2 yes)

set(_E "${_s}/kn-uterm-off")
knobs_make("${_E}" "Ninja" FALSE DEFINES "PolyOrch_RUST_NO_USES_TERMINAL=ON")
nj_edge("${_E}/b/build.ninja" "libkcrate.a: CUSTOM_COMMAND" _eE1)
ck_pool(_eE1 no)
nj_edge("${_E}/b/build.ninja" "CMakeFiles/k-test: CUSTOM_COMMAND" _eE2)
ck_pool(_eE2 no)

message(STATUS "knobs: all legs pass")
