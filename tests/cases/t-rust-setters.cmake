include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")

# Setter family (Task 3): polyorch_rust_set_features / set_env_vars /
# add_cargo_flags / add_rustflags. Keyed by the USER-FACING declared target
# name, mutating the cargo-build-<TARGET> mediator's POLYORCH_RUST_* props.
#
# Two assertion layers:
#  1. FATAL identities through ck_call_fail — same double-assert semantics as
#     the shared ck_child_fail (child exits non-zero AND its flattened output
#     matches the pinned phrase, while NOT reaching the sentinel that marks
#     "guard did not fire"). Deliberate deviation from ck_child_fail: it
#     re-execs the CASE file, so one case can pin exactly one FATAL; this
#     case pins five distinct validation phrases and therefore parameterizes
#     the child body instead of touching the shared preamble.
#  2. Generated-rule proof (the R-5 regression): a real child configure whose
#     setters run AFTER polyorch_rust_build() must still land their tokens in
#     build.make — property reads expand at generate time. Unix Makefiles is
#     forced so the rule text is greppable regardless of the matrix cell.

_polyorch_pixi_scratch(_s)

macro(ck_call_fail name rx)
    set(_cf_body "${ARGN}")
    string(REPLACE ";" "\n" _cf_body "${_cf_body}")
    file(WRITE "${_s}/${name}.cmake"
        "include(\"${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake\")\n${_cf_body}\nmessage(FATAL_ERROR \"GUARD-NOT-FIRED\")\n")
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

# --- validation-layer FATAL identities (pinned phrases, measured 2026-09-21) --
# Every call must name its own function (stable "polyorch_rust: ..." shape is
# shared with _polyorch_rust_must; per-function prefixes are the grep handle).
ck_call_fail(sf-no-selector
    "polyorch_rust_set_features: at least one selector"
    "polyorch_rust_set_features(TARGET nope-bin)")
ck_call_fail(sf-mutex
    "polyorch_rust_set_features: FEATURES and ALL_FEATURES are mutually exclusive"
    "polyorch_rust_set_features(TARGET nope-bin FEATURES a ALL_FEATURES)")
ck_call_fail(ev-badvar
    "polyorch_rust_set_env_vars: entries must be VAR=VALUE, got '3BAD=x'"
    "polyorch_rust_set_env_vars(TARGET nope-bin 3BAD=x)")
ck_call_fail(ac-no-target
    "polyorch_rust_add_cargo_flags: no target 'nope-bin'"
    "polyorch_rust_add_cargo_flags(TARGET nope-bin FLAGS --offline)")
ck_call_fail(ar-no-mediator-doc
    "polyorch_rust_add_rustflags: no target 'nope-lib'"
    "polyorch_rust_add_rustflags(TARGET nope-lib FLAGS -C opt-level=2)")
ck_call_fail(ev-no-target-name
    "polyorch_rust: missing required argument"
    "polyorch_rust_set_env_vars(FOO=bar)")

# --- child configure: setters after build() + write-through + append ---------
# Injection setup mirrors t-rust-collision: the guards read variables, so the
# rule can be GENERATED without any toolchain (nothing is executed offline).
set(_cmkedir "${CMAKE_CURRENT_LIST_DIR}/../../cmake")
macro(t_scf_write dir)
    file(WRITE "${dir}/CMakeLists.txt" [==[
cmake_minimum_required(VERSION 3.25)
project(polyorch-rust-setters LANGUAGES NONE)
list(APPEND CMAKE_MODULE_PATH "@_cmkedir@")
include(PolyOrchRustHelpers)
set(POLYORCH_RUST_FOUND TRUE CACHE INTERNAL "")
set(POLYORCH_RUST_CARGO "@_cmakecmd@" CACHE INTERNAL "")
set(POLYORCH_RUST_RUSTC "@_cmakecmd@" CACHE INTERNAL "")
set(POLYORCH_RUST_HOST_TARGET "x86_64-unknown-linux-gnu" CACHE INTERNAL "")
set(POLYORCH_RUST_VERSION "0.0.0-test" CACHE INTERNAL "")
set(POLYORCH_RUST_ROUTE "system" CACHE INTERNAL "")
set(POLYORCH_RUST_BIN_DIR "" CACHE INTERNAL "")

polyorch_rust_build(TARGET greet-bin PACKAGE greet CRATE greet-cli BINARY)
polyorch_rust_build(TARGET greet-lib PACKAGE greet CRATE greetlib STATIC)

# R-5 ordering regression: every setter runs AFTER the build() call.
polyorch_rust_set_features(TARGET greet-bin FEATURES alpha beta)
# write-through: the second call REPLACES all three feature props
polyorch_rust_set_features(TARGET greet-bin FEATURES zeta zeta2 NO_DEFAULT_FEATURES)
polyorch_rust_set_features(TARGET greet-lib ALL_FEATURES)
polyorch_rust_set_env_vars(TARGET greet-lib FOO=bar BAZ=qux)
polyorch_rust_add_cargo_flags(TARGET greet-lib FLAGS --offline)
# append semantics: both flags must be in the rule
polyorch_rust_add_cargo_flags(TARGET greet-lib FLAGS --timings)
# global RUSTFLAGS semantics: space-joined single KEY=VAL entry
polyorch_rust_add_rustflags(TARGET greet-lib FLAGS "-C target-cpu=x")
polyorch_rust_add_rustflags(TARGET greet-lib FLAGS "-Z build-std")
]==])
    configure_file("${dir}/CMakeLists.txt" "${dir}/CMakeLists.txt.tmp" @ONLY)
    file(RENAME "${dir}/CMakeLists.txt.tmp" "${dir}/CMakeLists.txt")
endmacro()

set(_cmakecmd "${CMAKE_COMMAND}")
set(_ok "${_s}/setters-ok")
file(MAKE_DIRECTORY "${_ok}")
t_scf_write("${_ok}")
execute_process(COMMAND "${CMAKE_COMMAND}" -G "Unix Makefiles" -S "${_ok}" -B "${_ok}/b"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "setters-ok: child configure failed (${_rc})\n${_out}${_err}")
endif()

foreach(_t greet-bin greet-lib)
    set(_mk "${_ok}/b/CMakeFiles/cargo-build-${_t}.dir/build.make")
    ck_file("${_mk}")
    file(READ "${_mk}" _txt)
    # Make may fold long recipe lines with backslash continuations: rejoin.
    string(REPLACE "\\\n" " " _txt "${_txt}")
    string(REPLACE "-" "_" _t_v "${_t}")
    set("_mk_${_t_v}" "${_txt}")
endforeach()

macro(mk_has t tok)
    string(REPLACE "-" "_" _mkv "_mk_${t}")
    if(NOT "${${_mkv}}" MATCHES "${tok}")
        message(FATAL_ERROR "build.make of cargo-build-${t} lacks [${tok}]")
    endif()
endmacro()
macro(mk_lacks t tok)
    string(REPLACE "-" "_" _mkv "_mk_${t}")
    if("${${_mkv}}" MATCHES "${tok}")
        message(FATAL_ERROR "build.make of cargo-build-${t} must NOT contain [${tok}]")
    endif()
endmacro()

# equals-form feature list, last call only (write-through):
mk_has(greet-bin "--features=zeta,zeta2")
mk_lacks(greet-bin "--features=alpha")
mk_has(greet-bin "--no-default-features")
# ALL_FEATURES on the other mediator replaces its (never-set) FEATURES:
mk_has(greet-lib "--all-features")
mk_lacks(greet-lib "--features")
mk_lacks(greet-lib "no-default-features")
# env entries and appended flags each became their own argv token:
mk_has(greet-lib "FOO=bar")
mk_has(greet-lib "BAZ=qux")
mk_has(greet-lib "--offline")
mk_has(greet-lib "--timings")
# RUSTFLAGS string prop: space-joined into one KEY=VAL argument.
mk_has(greet-lib "RUSTFLAGS=-C target-cpu=x -Z build-std")

# --- no-mediator identity: the compat shim is NOT a setter key ---------------
set(_bad "${_s}/setters-nomed")
file(MAKE_DIRECTORY "${_bad}")
file(WRITE "${_bad}/CMakeLists.txt" [==[
cmake_minimum_required(VERSION 3.25)
project(polyorch-rust-setters-bad LANGUAGES NONE)
list(APPEND CMAKE_MODULE_PATH "@_cmkedir@")
include(PolyOrchRustHelpers)
set(POLYORCH_RUST_FOUND TRUE CACHE INTERNAL "")
set(POLYORCH_RUST_CARGO "@_cmakecmd@" CACHE INTERNAL "")
set(POLYORCH_RUST_HOST_TARGET "x86_64-unknown-linux-gnu" CACHE INTERNAL "")
set(POLYORCH_RUST_ROUTE "system" CACHE INTERNAL "")
set(POLYORCH_RUST_BIN_DIR "" CACHE INTERNAL "")
polyorch_rust_build(TARGET greet-bin PACKAGE greet CRATE greet-cli BINARY)
polyorch_rust_set_features(TARGET greet-bin-cargo FEATURES alpha)
]==])
configure_file("${_bad}/CMakeLists.txt" "${_bad}/CMakeLists.txt.tmp" @ONLY)
file(RENAME "${_bad}/CMakeLists.txt.tmp" "${_bad}/CMakeLists.txt")
execute_process(COMMAND "${CMAKE_COMMAND}" -S "${_bad}" -B "${_bad}/b"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
string(REGEX REPLACE "[ \r\n\t]+" " " _txt "${_out}${_err}")
if(_rc EQUAL 0)
    message(FATAL_ERROR "no-mediator probe: configure unexpectedly succeeded")
endif()
set(_rx "target 'greet-bin-cargo' was not declared by polyorch_rust_build")
if(NOT _txt MATCHES "${_rx}")
    message(FATAL_ERROR "no-mediator probe: output lacks [${_rx}]: ${_txt}")
endif()

message(STATUS "rust-setters: OK (six FATAL identities + generate-time setter proof)")
