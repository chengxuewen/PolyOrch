# t-rust-clean -- polyorch_rust_clean both forms. Whole face: the old-shape
# recipe pin (cmake -E rm -rf <td>, hard-negative against drift) + default
# NAME rust-clean. PACKAGE form: the registered recipe carries the sanctioned
# wrapper (six --unset strips + the positional argv clean --package P
# --manifest-path M --target-dir TD) behind the native WORKING_DIRECTORY
# `cd <manifest-parent> &&` prefix (cargo's .cargo/config.toml up-walk;
# corr per-target clean buttons, lib+bin deliberately share ONE -p command).
# One-sided keyword pair -> FATAL (POLYORCH_CHILD / _CHILD2 script-mode
# re-execs). Generator: Unix Makefiles pinned -- the COMMAND property is NOT
# readable on non-IMPORTED targets (measured, cmake 4.4.4), so the generator's
# own build.make recipe is the assert surface (t-example-run pin-5 idiom).
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")

# ---- FATAL legs (script mode; guards fire before any add_custom_target) ----
# Child branches MUST precede their spawns: a re-exec before its own
# termination check is infinite recursion (measured: first draft hung the
# driver exactly that way).
if(POLYORCH_CHILD)
    polyorch_rust_clean(PACKAGE lonely)
    message(FATAL_ERROR "expected PACKAGE to require MANIFEST")
endif()
if(POLYORCH_CHILD2)
    polyorch_rust_clean(MANIFEST "/x/Cargo.toml")
    message(FATAL_ERROR "expected MANIFEST to require PACKAGE")
endif()

ck_child_fail("polyorch_rust_clean: PACKAGE requires MANIFEST")

# ck_child_fail hardcodes POLYORCH_CHILD=1 -- the sibling leg inlines the
# same shape with its own switch.
execute_process(
    COMMAND "${CMAKE_COMMAND}" "-DPOLYORCH_CHILD2=1" -P "${CMAKE_CURRENT_LIST_FILE}"
    ENVIRONMENT "POLYORCH_CHILD2=1"
    RESULT_VARIABLE _c2_rc OUTPUT_VARIABLE _c2_o ERROR_VARIABLE _c2_e)
set(_c2_txt "${_c2_o}${_c2_e}")
string(REPLACE "\n" " " _c2_txt "${_c2_txt}")
if(_c2_rc EQUAL 0)
    message(FATAL_ERROR "MANIFEST-without-PACKAGE child exited 0")
endif()
if(NOT _c2_txt MATCHES "MANIFEST without PACKAGE is inert")
    message(FATAL_ERROR "MANIFEST-without-PACKAGE child rc=${_c2_rc} without the identity message:\n${_c2_txt}")
endif()

# ---- registration legs (configure child, stubbed system-route vars) ----
_polyorch_pixi_scratch(_s)
set(_proj "${_s}/proj")
set(_bld "${_s}/build")
set(_td "${_s}/td")
file(MAKE_DIRECTORY "${_proj}/crates/alpha")
file(WRITE "${_proj}/Cargo.toml" "[workspace]\n")
file(WRITE "${_proj}/CMakeLists.txt" [=[
cmake_minimum_required(VERSION 3.25)
project(rclean NONE)
include("${POLYORCH_CMAKE_DIR}/PolyOrchRustHelpers.cmake")
# Stub the polyorch_rust_setup results (system route, /bin/true cargo: the
# command is only REGISTERED here, never executed). Sibling shape:
# t-rust-crossplan.
set(POLYORCH_RUST_FOUND TRUE CACHE INTERNAL "")
set(POLYORCH_RUST_CARGO "/bin/true" CACHE INTERNAL "")
set(POLYORCH_RUST_RUSTC "/bin/true" CACHE INTERNAL "")
set(POLYORCH_RUST_HOST_TARGET "x86_64-unknown-linux-gnu" CACHE INTERNAL "")
set(POLYORCH_RUST_ROUTE "system" CACHE INTERNAL "")
set(POLYORCH_RUST_BIN_DIR "" CACHE INTERNAL "")

polyorch_rust_clean(NAME face-clean BASE_DIR "${POLYORCH_TEST_TD}" FOLDER x)
polyorch_rust_clean(NAME pkg-clean PACKAGE alpha
    MANIFEST "${POLYORCH_TEST_MANIFEST}" BASE_DIR "${POLYORCH_TEST_TD}" FOLDER x)
polyorch_rust_clean(BASE_DIR "${POLYORCH_TEST_TD}/d" FOLDER x)
]=])

execute_process(COMMAND ${CMAKE_COMMAND}
    -G "Unix Makefiles"
    -S "${_proj}" -B "${_bld}"
    "-DPOLYORCH_CMAKE_DIR=${CMAKE_CURRENT_LIST_DIR}/../../cmake"
    "-DPOLYORCH_TEST_TD=${_td}"
    "-DPOLYORCH_TEST_MANIFEST=${_proj}/Cargo.toml"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _o ERROR_VARIABLE _e)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "configure child failed rc=${_rc}\n${_o}\n---stderr---\n${_e}")
endif()

# helper: read one recipe body
macro(_recipe out tg)
    set(_rp "${_bld}/CMakeFiles/${tg}.dir/build.make")
    if(NOT EXISTS "${_rp}")
        message(FATAL_ERROR "no build.make for ${tg} (configure log:\n${_o}\n${_e})")
    endif()
    file(READ "${_rp}" ${out})
endmacro()

# pin c (old-shape hard-negative): whole face stays the bare rm -rf
_recipe(_face face-clean)
if(NOT _face MATCHES "-E rm -rf")
    message(FATAL_ERROR "whole-face recipe lost the rm -rf form:\n${_face}")
endif()
string(FIND "${_face}" "${_td}" _pt)
if(_pt LESS 0)
    message(FATAL_ERROR "whole-face recipe lost the BASE_DIR resolution")
endif()

# pin d (default NAME): rust-clean registered the same whole-face shape
_recipe(_dflt rust-clean)
if(NOT _dflt MATCHES "-E rm -rf")
    message(FATAL_ERROR "default-NAME (rust-clean) recipe wrong:\n${_dflt}")
endif()

# pin a (PACKAGE form): wrapper + positional argv in the recipe
_recipe(_pkg pkg-clean)
foreach(needle "--unset=RUSTFLAGS" "--unset=CARGO_ENCODED_RUSTFLAGS"
        "--unset=CFLAGS" "--unset=CXXFLAGS" "--unset=CC" "--unset=CXX"
        "clean --package alpha")
    if(NOT _pkg MATCHES "${needle}")
        message(FATAL_ERROR "pkg-clean recipe missing [${needle}]")
    endif()
endforeach()
foreach(needle "--manifest-path ${_proj}/Cargo.toml" "--target-dir ${_td}")
    string(FIND "${_pkg}" "${needle}" _pn)
    if(_pn LESS 0)
        message(FATAL_ERROR "pkg-clean recipe missing [${needle}]")
    endif()
endforeach()

# pin b (WORKING_DIRECTORY): the Makefiles generator emits the native
# `cd <dir> &&` prefix -- must be the MANIFEST PARENT, not the caller dir,
# not empty. (Cargo discovers the workspace .cargo/config.toml by walking up
# from CWD -- corr's explicit comment on the same choice.)
string(FIND "${_pkg}" "cd ${_proj} &&" _pp)
if(_pp LESS 0)
    message(FATAL_ERROR "pkg-clean recipe lacks the manifest-parent cd prefix")
endif()

# pin e (never-automatic): no clean target may hook the default 'all' rule
file(READ "${_bld}/CMakeFiles/Makefile2" _m2)
if(_m2 MATCHES "all:[^\n]*(face-clean|pkg-clean|rust-clean)")
    message(FATAL_ERROR "a clean target leaked into an all rule")
endif()

message(STATUS "t-rust-clean: OK")
