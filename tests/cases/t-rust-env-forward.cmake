include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")

# PIT-14 host-leak isolation: every generated cargo command must shed the
# inherited compiler / rust-flag environment (--unset=RUSTFLAGS,
# CARGO_ENCODED_RUSTFLAGS, CFLAGS, CXXFLAGS, CC, CXX) so a host conda or gcc
# activation leaking "-mcet" style flags can never reach cargo or its cc-rs
# build scripts. Semantics measured on cmake 4.4.3 (this suite's floor):
#   - `cmake -E env --unset=VAR` exists; the bare `--unset VAR` form is REJECTED;
#   - unsetting an absent variable is a no-op (rc 0);
#   - a LATER explicit VAR=val assignment after --unset=VAR WINS -- so every
#     assignment (pixi PATH, set_env_vars entries, the RUSTFLAGS= entry) must
#     trail the --unset block, which the ordering assertions below pin.
#
# Execution proof without any cargo: the command builder is pointed at
# `cmake -E environment` (POLYORCH_RUST_CARGO := cmake, SUBCOMMAND :=
# "-E environment"), so running the generated list dumps the CHILD environment
# the real cargo rule would have executed under.

set(_vars RUSTFLAGS CARGO_ENCODED_RUSTFLAGS CFLAGS CXXFLAGS CC CXX)
set(ENV{RUSTFLAGS} "-mcet-poison")
set(ENV{CARGO_ENCODED_RUSTFLAGS} "-mcet-poison")
set(ENV{CFLAGS} "-mcet-poison")
set(ENV{CXXFLAGS} "-mcet-poison")
set(ENV{CC} "host-cc-poison")
set(ENV{CXX} "host-cxx-poison")

_polyorch_pixi_scratch(_s)

# The command builder reads the setup result variables; inject them directly
# (t-rust-collision style) with cmake-as-cargo so the probes can EXECUTE the
# generated list and dump the resulting child environment.
set(POLYORCH_RUST_FOUND TRUE CACHE INTERNAL "")
set(POLYORCH_RUST_CARGO "${CMAKE_COMMAND}" CACHE INTERNAL "")
set(POLYORCH_RUST_HOST_TARGET "x86_64-unknown-linux-gnu" CACHE INTERNAL "")
set(POLYORCH_RUST_ROUTE "system" CACHE INTERNAL "")
set(POLYORCH_RUST_BIN_DIR "" CACHE INTERNAL "")

# --- system route: the strip is present, the bare-cargo fast path is gone -----
_polyorch_rust_command(_cmd SUBCOMMAND -E environment)
foreach(_v IN LISTS _vars)
    list(FIND _cmd "--unset=${_v}" _i)
    ck(NOT _i EQUAL -1)
endforeach()
execute_process(COMMAND ${_cmd} RESULT_VARIABLE _rc
    OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
ck(_rc EQUAL 0)
string(REGEX REPLACE "[\r\n]+" "\n" _out "${_out}${_err}")
foreach(_v IN LISTS _vars)
    if(_out MATCHES "^${v}=")
        message(FATAL_ERROR "leak: ${v} survived the wrapper")
    endif()
endforeach()

# --- an explicit assignment after --unset must win -----------------------------
_polyorch_rust_command(_cmd SUBCOMMAND -E environment ENV "CC=kept-cc" "EXTRA=1")
list(FIND _cmd "--unset=CC" _ui)
list(FIND _cmd "CC=kept-cc" _ai)
ck(NOT _ui EQUAL -1)
ck(NOT _ai EQUAL -1)
ck(_ai GREATER _ui)
execute_process(COMMAND ${_cmd} RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_QUIET)
ck(_rc EQUAL 0)
ck(_out MATCHES "CC=kept-cc")
if(_out MATCHES "host-cc-poison")
    message(FATAL_ERROR "poisoned CC leaked despite the explicit override")
endif()

# --- pixi route: the --unset block precedes the PATH assignment ----------------
set(POLYORCH_RUST_ROUTE "pixi" CACHE INTERNAL "")
set(POLYORCH_RUST_BIN_DIR "${_s}/bin" CACHE INTERNAL "")
_polyorch_rust_command(_cmd SUBCOMMAND -E environment ENV "RUSTFLAGS=-C kept")
string(JOIN "|" _flat "${_cmd}")
ck(_flat MATCHES "--unset=RUSTFLAGS")
ck(_flat MATCHES "PATH=")
list(FIND _cmd "--unset=RUSTFLAGS" _ui)
set(_pi -1)
set(_n -1)
foreach(_e IN LISTS _cmd)
    math(EXPR _n "${_n} + 1")
    if(_pi EQUAL -1 AND _e MATCHES "^PATH=")
        set(_pi ${_n})
    endif()
endforeach()
ck(_pi GREATER _ui)
list(FIND _cmd "RUSTFLAGS=-C kept" _ri)
ck(_ri GREATER _ui)

# --- generated-rule text: a poisoned parent configure must not touch the rule --
set(_cmkedir "${CMAKE_CURRENT_LIST_DIR}/../../cmake")
set(_cmakecmd "${CMAKE_COMMAND}")
set(_src "${_s}/fwd")
file(MAKE_DIRECTORY "${_src}")
file(WRITE "${_src}/CMakeLists.txt" [==[
cmake_minimum_required(VERSION 3.25)
project(polyorch-rust-envfwd LANGUAGES NONE)
list(APPEND CMAKE_MODULE_PATH "@_cmkedir@")
include(PolyOrchRustHelpers)
set(POLYORCH_RUST_FOUND TRUE CACHE INTERNAL "")
set(POLYORCH_RUST_CARGO "@_cmakecmd@" CACHE INTERNAL "")
set(POLYORCH_RUST_HOST_TARGET "x86_64-unknown-linux-gnu" CACHE INTERNAL "")
set(POLYORCH_RUST_ROUTE "system" CACHE INTERNAL "")
set(POLYORCH_RUST_BIN_DIR "" CACHE INTERNAL "")
polyorch_rust_build(TARGET greet-bin PACKAGE greet CRATE greet-cli BINARY)
polyorch_rust_add_rustflags(TARGET greet-bin FLAGS "-C target-cpu=x")
]==])
configure_file("${_src}/CMakeLists.txt" "${_src}/CMakeLists.txt.tmp" @ONLY)
file(RENAME "${_src}/CMakeLists.txt.tmp" "${_src}/CMakeLists.txt")
execute_process(COMMAND "${CMAKE_COMMAND}" -G "Unix Makefiles"
    -S "${_src}" -B "${_src}/b"
    ENVIRONMENT "CFLAGS=-mcet-poison;RUSTFLAGS=-mcet-poison"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "envfwd child configure failed (${_rc})\n${_out}${_err}")
endif()
set(_mk "${_src}/b/CMakeFiles/cargo-build-greet-bin.dir/build.make")
ck_file("${_mk}")
file(READ "${_mk}" _txt)
string(REPLACE "\\\n" " " _txt "${_txt}")
string(REGEX REPLACE "[\r\n]+" " " _txt "${_txt}")
# line folds sit at " \<newline><TAB>" boundaries and can fall INSIDE a
# quoted argument: flatten TABs, then collapse whitespace runs so the
# fixed-string FINDs below match regardless of fold positions.
string(REPLACE "\t" " " _txt "${_txt}")
string(REGEX REPLACE " +" " " _txt "${_txt}")
foreach(_v IN LISTS _vars)
    if(NOT _txt MATCHES "--unset=${_v}")
        message(FATAL_ERROR "build.make lacks --unset=${_v}")
    endif()
endforeach()
# the inherited poison value must appear nowhere in the rule text:
if(_txt MATCHES "mcet-poison")
    message(FATAL_ERROR "poisoned parent CFLAGS/RUSTFLAGS bled into the rule text")
endif()
# ordering inside the generated recipe: the explicit RUSTFLAGS= assignment (from
# the setter) must trail --unset=RUSTFLAGS so it survives.
string(FIND "${_txt}" "--unset=RUSTFLAGS" _ui)
string(FIND "${_txt}" "RUSTFLAGS=-C target-cpu=x" _ri)
ck(NOT _ri EQUAL -1)
ck(_ri GREATER _ui)

message(STATUS "rust-env-forward: OK (host-flag leak isolated on both routes)")
