# t-rust-installplan-versions -- SR5 P1/P2/P7 legs of the pure row planner
# (_polyorch_rust_install_plan): the version triple (RENAME tag + link legs),
# STUB_NAME routing, and the STRIP_TOOL CODE leg. The no-kw legacy row shape
# stays pinned by the untouched full-row locks in t-rust-installplan (the
# byte-stability negative). Guard legs re-exec this file (CK-child pattern of
# the sibling case). Helpers are FUNCTIONS on purpose: a macro would textual-
# substitute quoted needles and re-parse them (measured corruption).
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")

function(nfields row out)
    string(REPLACE "|" ";" _gf_parts "${${row}}")
    list(LENGTH _gf_parts _l)
    set(${out} "${_l}" PARENT_SCOPE)
endfunction()

function(getfield row idx out)
    string(REPLACE "|" ";" _gf_parts "${${row}}")
    list(GET _gf_parts ${idx} _v)
    set(${out} "${_v}" PARENT_SCOPE)
endfunction()

function(ck_has hay needle)
    string(FIND "${hay}" "${needle}" _at)
    if(_at LESS 0)
        message(FATAL_ERROR "check failed: [${needle}] not in:\n[${hay}]")
    endif()
endfunction()

# ------------------------------------------------- A: both VERSION+SOVERSION --
# cmake semantics: real file takes VERSION, the SOVERSION link exists because
# the two differ, the dev link always; the dev link chains to the intermediate.
_polyorch_rust_install_plan(TRIPLE x86_64-unknown-linux-gnu KIND shared
    HANDLE libx CRATE x SOVERSION 0 VERSION 0.1.2 OUT_ROWS _rows)
list(LENGTH _rows _n)
ck(${_n} EQUAL 3)
list(GET _rows 0 _r)
nfields(_r _nf)
ck(${_nf} EQUAL 7)
getfield(_r 6 _tag)
ck_str("${_tag}" "RENAME=libx.so.0.1.2")
getfield(_r 5 _sb)
ck_has("${_sb}" "IMPORTED_LOCATION     \"\${_POLYORCH_RUST_ROOT}/lib/libx.so.0.1.2\"")
list(GET _rows 1 _r)
getfield(_r 0 _name)
ck_str("${_name}" "libx.so.0")
getfield(_r 6 _tag)
string(SUBSTRING "${_tag}" 0 9 _pre)
ck_str("${_pre}" "LINKCODE=")
string(SUBSTRING "${_tag}" 9 -1 _code)
ck_has("${_code}" "get_filename_component(_polyorch_link_dir")
ck_has("${_code}" "CREATE_LINK \"libx.so.0.1.2\" \"\${_polyorch_link_dir}/libx.so.0\" SYMBOLIC")
list(GET _rows 2 _r)
getfield(_r 0 _name)
ck_str("${_name}" "libx.so")
getfield(_r 6 _tag)
ck_has("${_tag}" "CREATE_LINK \"libx.so.0\"")

# ------------------------------------------------------ B: SOVERSION only --
# missing VERSION takes SOVERSION's value -> real <name>.<M> + dev link only.
_polyorch_rust_install_plan(TRIPLE x86_64-unknown-linux-gnu KIND shared
    HANDLE libx CRATE x SOVERSION 2 OUT_ROWS _rows)
list(LENGTH _rows _n)
ck(${_n} EQUAL 2)
list(GET _rows 0 _r)
getfield(_r 6 _tag)
ck_str("${_tag}" "RENAME=libx.so.2")
list(GET _rows 1 _r)
getfield(_r 0 _name)
ck_str("${_name}" "libx.so")
getfield(_r 6 _tag)
ck_has("${_tag}" "CREATE_LINK \"libx.so.2\"")

# -------------------------------------------------------- C: VERSION only --
# missing SOVERSION takes VERSION's value -> no intermediate leg (M == V).
_polyorch_rust_install_plan(TRIPLE x86_64-unknown-linux-gnu KIND shared
    HANDLE libx CRATE x VERSION 3.4 OUT_ROWS _rows)
list(LENGTH _rows _n)
ck(${_n} EQUAL 2)
list(GET _rows 1 _r)
getfield(_r 0 _name)
ck_str("${_name}" "libx.so")

# ------------------------------------------------------- D: macho family --
# cmake's dylib shape: real libfoo.<V>.dylib + libfoo.<M>.dylib + dev link.
_polyorch_rust_install_plan(TRIPLE x86_64-apple-darwin KIND shared
    HANDLE libx CRATE foo SOVERSION 1 VERSION 1.2.3 OUT_ROWS _rows)
list(LENGTH _rows _n)
ck(${_n} EQUAL 3)
list(GET _rows 0 _r)
getfield(_r 6 _tag)
ck_str("${_tag}" "RENAME=libfoo.1.2.3.dylib")
list(GET _rows 1 _r)
getfield(_r 0 _name)
ck_str("${_name}" "libfoo.1.dylib")
list(GET _rows 2 _r)
getfield(_r 0 _name)
ck_str("${_name}" "libfoo.dylib")

# ------------------------------------------- E: destination/prefix folds --
_polyorch_rust_install_plan(TRIPLE x86_64-unknown-linux-gnu KIND shared
    HANDLE libx CRATE x SOVERSION 7 PREFIX app/ LIBRARY_DESTINATION mylib
    OUT_ROWS _rows)
list(GET _rows 0 _r)
getfield(_r 1 _dest)
ck_str("${_dest}" "app/mylib")
list(GET _rows 1 _r)
getfield(_r 6 _tag)
ck_has("${_tag}" "CMAKE_INSTALL_PREFIX}/app/mylib")

# component + configurations stamp the CODE legs too (filter parity):
_polyorch_rust_install_plan(TRIPLE x86_64-unknown-linux-gnu KIND shared
    HANDLE libx CRATE x SOVERSION 1 COMPONENT runtime CONFIGURATIONS Release
    OUT_ROWS _rows)
list(GET _rows 1 _r)
getfield(_r 3 _comp)
getfield(_r 4 _cfgs)
ck_str("${_comp}" "runtime")
ck_str("${_cfgs}" "Release")

# ------------------------------------------------- F: STUB_NAME (P2 preview) --
# the stub registers STUB_NAME while the file-expr keeps the HANDLE.
_polyorch_rust_install_plan(TRIPLE x86_64-unknown-linux-gnu KIND static
    HANDLE libx STUB_NAME ns::widget OUT_ROWS _rows)
list(GET _rows 0 _r)
nfields(_r _nf)
ck(${_nf} EQUAL 6)
getfield(_r 5 _sb)
ck_has("${_sb}" "add_library(ns::widget STATIC IMPORTED GLOBAL)")
ck_has("${_sb}" "$<TARGET_FILE_NAME:libx>")
# no STUB_NAME -> legacy handle shape, 6 fields (hard negative):
_polyorch_rust_install_plan(TRIPLE x86_64-unknown-linux-gnu KIND static
    HANDLE libx OUT_ROWS _rows)
list(GET _rows 0 _r)
nfields(_r _nf)
ck(${_nf} EQUAL 6)
getfield(_r 5 _sb)
ck_has("${_sb}" "add_library(libx STATIC IMPORTED GLOBAL)")

# --------------------------------------------- G: STRIP_TOOL (P7 preview) --
_polyorch_rust_install_plan(TRIPLE x86_64-unknown-linux-gnu KIND shared
    HANDLE libx STRIP_TOOL /usr/bin/strip OUT_ROWS _rows)
list(LENGTH _rows _n)
ck(${_n} EQUAL 2)
list(GET _rows 1 _r)
getfield(_r 6 _tag)
string(SUBSTRING "${_tag}" 0 5 _pre)
ck_str("${_pre}" "CODE=")
ck_has("${_tag}" "CODE=if(CMAKE_INSTALL_DO_STRIP)")
ck_has("${_tag}" "--strip-unneeded")
ck_has("${_tag}" "$<TARGET_FILE_NAME:libx>")
# macho flag clause:
_polyorch_rust_install_plan(TRIPLE x86_64-apple-darwin KIND shared
    HANDLE libx STRIP_TOOL /usr/bin/strip OUT_ROWS _rows)
list(GET _rows 1 _r)
getfield(_r 6 _tag)
ck_has("${_tag}" "\" -x \"")
# a bin handle never gets strip legs (shared-only posture):
_polyorch_rust_install_plan(TRIPLE x86_64-unknown-linux-gnu KIND bin
    HANDLE app STRIP_TOOL /usr/bin/strip OUT_ROWS _rows)
list(LENGTH _rows _n)
ck(${_n} EQUAL 1)

# ------------------------------------------------------- H: guard legs ----
if(POLYORCH_CHILD)
    if("$ENV{POLYORCH_VERSIONS_CASE}" STREQUAL "kindbin")
        _polyorch_rust_install_plan(TRIPLE x86_64-unknown-linux-gnu KIND bin
            HANDLE app SOVERSION 1 OUT_ROWS _o)
        message(FATAL_ERROR "expected rejection of SOVERSION on a bin handle")
    elseif("$ENV{POLYORCH_VERSIONS_CASE}" STREQUAL "family")
        _polyorch_rust_install_plan(TRIPLE x86_64-pc-windows-msvc KIND shared
            HANDLE libx CRATE x SOVERSION 1 OUT_ROWS _o)
        message(FATAL_ERROR "expected rejection of versioning on the msvc family")
    elseif("$ENV{POLYORCH_VERSIONS_CASE}" STREQUAL "regex")
        _polyorch_rust_install_plan(TRIPLE x86_64-unknown-linux-gnu KIND shared
            HANDLE libx CRATE x VERSION "v1.2" OUT_ROWS _o)
        message(FATAL_ERROR "expected rejection of a non-numeric version")
    elseif("$ENV{POLYORCH_VERSIONS_CASE}" STREQUAL "crate")
        _polyorch_rust_install_plan(TRIPLE x86_64-unknown-linux-gnu KIND shared
            HANDLE libx SOVERSION 1 OUT_ROWS _o)
        message(FATAL_ERROR "expected rejection of versioning without CRATE")
    elseif("$ENV{POLYORCH_VERSIONS_CASE}" STREQUAL "zero")
        # cmake truthiness trap: the literal value 0 must still version.
        _polyorch_rust_install_plan(TRIPLE x86_64-unknown-linux-gnu KIND shared
            HANDLE libx CRATE x SOVERSION 0 OUT_ROWS _o)
        list(LENGTH _o _on)
        if(_on EQUAL 1)
            message(FATAL_ERROR "SOVERSION 0 was swallowed by keyword truthiness")
        endif()
        message(FATAL_ERROR "zero-sentinel legs passed")
    else()
        _polyorch_rust_install_plan(TRIPLE x86_64-unknown-linux-gnu KIND shared
            HANDLE libx CRATE x KWARGEN OUT_ROWS _o)
        message(FATAL_ERROR "expected rejection of unknown keyword KWARGEN")
    endif()
endif()

set(ENV{POLYORCH_VERSIONS_CASE} kindbin)
ck_child_fail("install-plan SOVERSION/VERSION requires KIND shared, +got.*'bin'")
set(ENV{POLYORCH_VERSIONS_CASE} family)
ck_child_fail("SOVERSION/VERSION supports elf.macho only.*family 'msvc' has no soname chain")
set(ENV{POLYORCH_VERSIONS_CASE} regex)
ck_child_fail("install-plan version 'v1.2' is not.*digits-and-dots")
set(ENV{POLYORCH_VERSIONS_CASE} crate)
ck_child_fail("SOVERSION/VERSION needs CRATE")
set(ENV{POLYORCH_VERSIONS_CASE} zero)
ck_child_fail("zero-sentinel legs passed")
set(ENV{POLYORCH_VERSIONS_CASE} unknown)
ck_child_fail("_polyorch_rust_install_plan unknown args")

message(STATUS "t-rust-installplan-versions: OK (7 table legs + 6 guard pins)")
