# expect-log libplan: all legs pass
# R3 LIB kind cluster, offline legs (D40 exampleplan is the process template).
# Assertion layers:
#  1. pure naming table: lib rows for the host/cross/msvc/macho families --
#     rlib naming is platform-INVARIANT (lib<name>.rlib everywhere, the msvc
#     no-prefix strip does NOT apply; sysroot evidence + rustc naming rule
#     cited at the table's branch); directory = base/[<tup>/]<profile>, no
#     /examples segment;
#  2. the cargo argv: KIND lib -> bare --lib selector (no name argument; the
#     CRATE feeds the naming table, not argv); no --bin/--example leak;
#  3. the child harness (fake setup, Unix Makefiles, nothing executes): the
#     handle is INTERFACE_LIBRARY, carries POLYORCH_RUST_LIB on handle AND
#     mediator, has NO IMPORTED_LOCATION; the generated build.make carries
#     --lib + the PIT-14 env-strip (--unset=RUSTFLAGS) + the stamped rlib
#     OUTPUT -- the wrapper-isolation proof the feature exists for;
#  4. the guard cluster through EXPECT_FAIL children: run() on a LIB handle
#     FATALs (rlibs do not run), install() on one FATALs (rlibs ship
#     nowhere), the PIT-13 collision guard fires on TARGET libdemo_core;
#     the mutual-exclusion message now names LIB (child -P, script mode).
# The default-kinds-unchanged pin lives with its class: t-rust-defaultkinds
# child A proves knob-unset dispatches exactly pair-static/pair-shared (no
# bare handle => no INTERFACE member), plus its new dk-lib rejection leg.
cmake_policy(SET CMP0219 NEW)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")

_polyorch_pixi_scratch(_s)
set(ROOT "${CMAKE_CURRENT_LIST_DIR}/../..")   # uppercase: configure_file @ROOT@ token

# ------------------------------------------------------- pure naming table --
_polyorch_rust_artifact_names(TRIPLE x86_64-unknown-linux-gnu KIND lib
    CRATE demo_core PROFILE debug BASE_DIR BD FILE_OUT _f DIR_OUT _d)
ck_str("${_f}" "libdemo_core.rlib")
ck_str("${_d}" "BD/debug")
# cross nesting: one segment deeper, same file name
_polyorch_rust_artifact_names(TRIPLE aarch64-unknown-linux-musl KIND lib
    CRATE demo_core PROFILE release BASE_DIR BD TARGET aarch64-unknown-linux-musl
    FILE_OUT _f DIR_OUT _d)
ck_str("${_f}" "libdemo_core.rlib")
ck_str("${_d}" "BD/aarch64-unknown-linux-musl/release")
# msvc: NO prefix strip for rlibs (the .a/.lib/.dll strip rule is a PE/COFF
# rule; an rlib is rustc's own container -- libstd-<hash>.rlib lives in every
# msvc sysroot)
_polyorch_rust_artifact_names(TRIPLE x86_64-pc-windows-msvc KIND lib
    CRATE demo_core PROFILE release BASE_DIR BD FILE_OUT _f)
ck_str("${_f}" "libdemo_core.rlib")
_polyorch_rust_artifact_names(TRIPLE aarch64-apple-darwin KIND lib
    CRATE demo_core PROFILE debug BASE_DIR BD FILE_OUT _f)
ck_str("${_f}" "libdemo_core.rlib")
# the example segment did NOT leak into the lib row
_polyorch_rust_artifact_names(TRIPLE x86_64-unknown-linux-gnu KIND lib
    CRATE e PROFILE debug BASE_DIR BD FILE_OUT _f DIR_OUT _d)
if(_d MATCHES "examples")
    message(FATAL_ERROR "lib dir carries /examples: ${_d}")
endif()

# ----------------------------------------------------------------- argv -----
_polyorch_rust_cargo_args(PACKAGE lib-demo KIND lib CRATE demo_core ARGO_OUT _a)
list(JOIN _a " " _argv_s)
list(FIND _a "--lib" _li)
ck(_li GREATER -1)
if(_argv_s MATCHES "--bin" OR _argv_s MATCHES "--example")
    message(FATAL_ERROR "lib argv carries a bin/example selector: [${_argv_s}]")
endif()
# CRATE is naming-table input, never argv for this kind:
if(_argv_s MATCHES "demo_core")
    message(FATAL_ERROR "lib argv leaked the crate name: [${_argv_s}]")
endif()
# profile plumbing identical:
_polyorch_rust_cargo_args(PACKAGE p KIND lib CRATE c PROFILE release ARGO_OUT _a2)
list(JOIN _a2 " " _a2s)
if(NOT _a2s MATCHES "--release --lib")
    message(FATAL_ERROR "lib argv lost its profile ordering: [${_a2s}]")
endif()

# ------------------------------------------------------------ child harness --
file(WRITE "${_s}/_libchild.in" [==[
cmake_minimum_required(VERSION 3.25)
project(polyorch-libplan LANGUAGES NONE)
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
@BUILD@
@POST@
]==])

set(_cmkedir "${ROOT}/cmake")
set(_mf "${ROOT}/tests/fixtures/rust-lib/rust-ws/Cargo.toml")

function(lp_child dir out_var)
    cmake_parse_arguments(PARSE_ARGV 2 D "EXPECT_FAIL" "PRE;BUILD;POST" "")
    file(MAKE_DIRECTORY "${dir}")
    file(READ "${_s}/_libchild.in" _tpl)
    string(REPLACE "@CMKEDIR@" "${_cmkedir}" _tpl "${_tpl}")
    string(REPLACE "@CMAKECMD@" "${CMAKE_COMMAND}" _tpl "${_tpl}")
    string(REPLACE "@PRE@" "${D_PRE}" _tpl "${_tpl}")
    string(REPLACE "@BUILD@" "${D_BUILD}" _tpl "${_tpl}")
    string(REPLACE "@POST@" "${D_POST}" _tpl "${_tpl}")
    file(WRITE "${dir}/CMakeLists.txt" "${_tpl}")
    execute_process(COMMAND "${CMAKE_COMMAND}" -G "Unix Makefiles"
        -S "${dir}" -B "${dir}/b"
        RESULT_VARIABLE _rc OUTPUT_VARIABLE _o ERROR_VARIABLE _e)
    set(${out_var}_rc "${_rc}" PARENT_SCOPE)
    set(${out_var}_out "${_o}${_e}" PARENT_SCOPE)
    if(NOT _rc EQUAL 0 AND NOT D_EXPECT_FAIL)
        message(FATAL_ERROR "libplan child ${dir} configure failed (${_rc}):\n${_o}${_e}")
    endif()
    if(_rc EQUAL 0 AND D_EXPECT_FAIL)
        message(FATAL_ERROR "libplan child ${dir}: expected FATAL, configure passed")
    endif()
endfunction()

set(_BUILD1 "polyorch_rust_build(TARGET demo PACKAGE lib-demo CRATE demo_core LIB NO_SOURCES MANIFEST \"${_mf}\")")

# ===== child R1: the happy LIB registration + generated rule text ============
set(_R1 "${_s}/lib-basic")
lp_child("${_R1}" _R1 BUILD "${_BUILD1}"
    POST [==[
get_target_property(_t demo TYPE)
message(STATUS "LP-TYPE ${_t}")
get_target_property(_lp demo POLYORCH_RUST_LIB)
message(STATUS "LP-LIB ${_lp}")
get_target_property(_mp demo-build POLYORCH_RUST_LIB)
message(STATUS "LP-MEDLIB ${_mp}")
get_target_property(_el demo IMPORTED_LOCATION)
if(NOT _el OR _el MATCHES "NOTFOUND")
    message(STATUS "LP-NOLOC OK")
endif()
]==])
string(FIND "${_R1_out}" "LP-TYPE INTERFACE_LIBRARY" _i1)
ck(_i1 GREATER -1)
set(_want_lib "${_R1}/b/.cargo-target/debug/libdemo_core.rlib")
string(FIND "${_R1_out}" "LP-LIB ${_want_lib}" _i2)
ck(_i2 GREATER -1)
string(FIND "${_R1_out}" "LP-MEDLIB ${_want_lib}" _i3)
ck(_i3 GREATER -1)
string(FIND "${_R1_out}" "LP-NOLOC OK" _i4)
ck(_i4 GREATER -1)
# The generated rule: --lib argv, the stamped rlib OUTPUT, and the PIT-14
# env-strip in FRONT of the cargo invocation (the wrapper is the point of
# this whole feature -- hand-rolled lanes leak RUSTFLAGS/CFLAGS).
set(_mk "${_R1}/b/CMakeFiles/demo-build.dir/build.make")
ck_file("${_mk}")
file(READ "${_mk}" _t1)
string(REPLACE "\\\n" " " _t1 "${_t1}")
foreach(_needle "--lib" "--unset=RUSTFLAGS" "--unset=CFLAGS" "--target-dir")
    string(FIND "${_t1}" "${_needle}" _p)
    if(_p LESS 0)
        message(FATAL_ERROR "generated lib rule lacks [${_needle}]")
    endif()
endforeach()
string(FIND "${_t1}" "libdemo_core.rlib" _p)
ck(_p GREATER -1)
if(_t1 MATCHES "--bin" OR _t1 MATCHES "--example")
    message(FATAL_ERROR "generated lib rule carries a bin/example selector")
endif()
# strip-before-forward order (the wrapper contract): --unset=RUSTFLAGS must
# precede the cargo argv -- one command line, the strip is its head. (The
# rule's COMMENT echo carries the package name early; --lib only ever
# appears inside the cargo argv, so it is the right comparator.)
string(FIND "${_t1}" "--unset=RUSTFLAGS" _su)
string(FIND "${_t1}" "--lib" _sp)
ck(_su LESS _sp)

# ===== child R2: run() rejects a LIB handle ==================================
set(_R2 "${_s}/lib-run")
lp_child("${_R2}" _R2 BUILD "${_BUILD1}" EXPECT_FAIL
    POST "polyorch_rust_run(TARGET demo)")
string(REGEX REPLACE "[ \r\n\t]+" " " _R2_out "${_R2_out}")
if(NOT _R2_out MATCHES "rlib \\(LIB\\) handle")
    message(FATAL_ERROR "run() guard phrase missing: ${_R2_out}")
endif()

# ===== child R3: install() rejects a LIB handle ===============================
set(_R3 "${_s}/lib-install")
lp_child("${_R3}" _R3 BUILD "${_BUILD1}" EXPECT_FAIL
    POST "polyorch_rust_install(TARGETS demo)")
string(REGEX REPLACE "[ \r\n\t]+" " " _R3_out "${_R3_out}")
if(NOT _R3_out MATCHES "is an rlib \\(LIB\\) handle")
    message(FATAL_ERROR "install() guard phrase missing: ${_R3_out}")
endif()

# ===== child R4: PIT-13 collision guard on the rlib base name ================
lp_child("${_s}/lib-collide" _R4 EXPECT_FAIL
    BUILD "polyorch_rust_build(TARGET libdemo_core PACKAGE lib-demo CRATE demo_core LIB NO_SOURCES MANIFEST \"${_mf}\")")
string(REGEX REPLACE "[ \r\n\t]+" " " _R4_out "${_R4_out}")
if(NOT _R4_out MATCHES "collides with the artifact base name")
    message(FATAL_ERROR "collision guard phrase missing: ${_R4_out}")
endif()

# ===== child R5: mediator-name clash (PIT-13 global-namespace shape) =========
lp_child("${_s}/lib-clash" _R5 EXPECT_FAIL
    PRE "add_custom_target(demo-build)"
    BUILD "${_BUILD1}")
string(REGEX REPLACE "[ \r\n\t]+" " " _R5_out "${_R5_out}")
if(NOT _R5_out MATCHES "demo-build")
    message(FATAL_ERROR "clash output lacks the mediator name: ${_R5_out}")
endif()

# ===== script-mode: STATIC + LIB mutual exclusion names LIB ==================
configure_file("${CMAKE_CURRENT_LIST_DIR}/_lib_child_excl.in"
    "${_s}/excl.cmake" @ONLY)
execute_process(
    COMMAND "${CMAKE_COMMAND}" -P "${_s}/excl.cmake"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _o ERROR_VARIABLE _o)
if(_rc EQUAL 0)
    message(FATAL_ERROR "expected FATAL from excl child: ${_o}")
endif()
string(REGEX REPLACE "[ \n]+" " " _o "${_o}")
if(NOT _o MATCHES "BINARY, STATIC, SHARED, EXAMPLE and LIB are mutually exclusive")
    message(FATAL_ERROR "exclusion message does not name LIB: ${_o}")
endif()

message(STATUS "libplan: all legs pass")
