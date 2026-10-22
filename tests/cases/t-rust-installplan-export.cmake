# t-rust-installplan-export -- SR5 P2/P3 on the FULL function, offline: a
# configure child forges the mediator/handle property shape (t-rust-clean's
# stub-cache idiom) and calls polyorch_rust_install twice -- once in the
# legacy shape (byte-stability snapshots of the replay stub + Config texts,
# no RENAME/CREATE_LINK rules) and once with NAMESPACE + handle=alias +
# COMPONENTS + SOVERSION/VERSION (per-component stubs, dispatching Config,
# ConfigVersion, version legs). FATAL legs: argument guards pin in script
# mode (guards fire before the target walk); handle-dependent rejections
# need EXPECT_FAIL configure children.
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")

_polyorch_pixi_scratch(_s)
set(_art "${_s}/art")
file(MAKE_DIRECTORY "${_art}")
file(WRITE "${_art}/libdemo.a" "x")
file(WRITE "${_art}/demo-exe" "x")
file(WRITE "${_art}/libvv.so" "x")

set(_proj "${_s}/proj")
set(_bld "${_s}/build")
file(MAKE_DIRECTORY "${_proj}")
file(WRITE "${_proj}/CMakeLists.txt" [=[
cmake_minimum_required(VERSION 3.25)
project(rp-export NONE)
include("${POLYORCH_CMAKE_DIR}/PolyOrchRustHelpers.cmake")
set(POLYORCH_RUST_HOST_TARGET "x86_64-unknown-linux-gnu" CACHE INTERNAL "")

foreach(_h _sl|libdemo.a _ex|demo-exe _vl|libvv.so _kb|libkb.so)
    string(REPLACE "|" ";" _p "${_h}")
    list(GET _p 0 _tgt)
    list(GET _p 1 _fn)
    if(_tgt STREQUAL "_sl")
        add_library(${_tgt} STATIC IMPORTED GLOBAL)
    elseif(_tgt STREQUAL "_ex")
        add_executable(${_tgt} IMPORTED GLOBAL)
    else()
        add_library(${_tgt} SHARED IMPORTED GLOBAL)
    endif()
    set_property(TARGET ${_tgt} PROPERTY IMPORTED_LOCATION "${POLYORCH_TEST_ART}/${_fn}")
    set_property(TARGET ${_tgt} PROPERTY POLYORCH_RUST_PACKAGE ${_tgt})
    add_custom_target(${_tgt}-build)
endforeach()
set_property(TARGET _sl-build PROPERTY POLYORCH_RUST_KIND static)
set_property(TARGET _ex-build PROPERTY POLYORCH_RUST_KIND bin)
set_property(TARGET _vl-build PROPERTY POLYORCH_RUST_KIND shared)
set_property(TARGET _vl-build PROPERTY POLYORCH_RUST_CRATE vv)
set_property(TARGET _kb-build PROPERTY POLYORCH_RUST_KIND shared)
set_property(TARGET _kb-build PROPERTY POLYORCH_RUST_CRATE kb)

if(POLYORCH_LEG_FAIL)
    polyorch_rust_install(TARGETS _sl EXPORT nog)
elseif(POLYORCH_LEG_NOCOMPAT)
    polyorch_rust_install(TARGETS _sl EXPORT nog SUITE_VERSION 1.0)
elseif(POLYORCH_COMPS_BAD)
    polyorch_rust_install(TARGETS _vl EXPORT badcomp SUITE_VERSION 1.0 COMPATIBILITY SameMajorVersion
        COMPONENTS "core=ghosthandle")
elseif(POLYORCH_COMPS_DUP)
    polyorch_rust_install(TARGETS _vl EXPORT dupcomp SUITE_VERSION 1.0 COMPATIBILITY SameMajorVersion
        COMPONENTS "a=_vl" "b=_vl")
elseif(POLYORCH_COMPS_EMPTY)
    polyorch_rust_install(TARGETS _vl EXPORT emptycomp SUITE_VERSION 1.0 COMPATIBILITY SameMajorVersion
        COMPONENTS "a=")
elseif(POLYORCH_COMPS_BADNAME)
    polyorch_rust_install(TARGETS _vl EXPORT badname SUITE_VERSION 1.0 COMPATIBILITY SameMajorVersion
        COMPONENTS "bad name=_vl")
elseif(POLYORCH_VER_ON_BIN)
    polyorch_rust_install(TARGETS _ex SOVERSION 1)
else()
    # legacy shape: byte-stability target (SUITE pair is EXPORT-mandatory
    # since SR5 P3; everything else is the pre-SR5 spelling)
    polyorch_rust_install(TARGETS _sl _ex EXPORT legacy
        SUITE_VERSION 0.1.0 COMPATIBILITY SameMajorVersion)
    # SR5 shape: namespace + alias + components + version triple
    polyorch_rust_install(TARGETS "_vl=vkit" EXPORT pack NAMESPACE "pack::"
        SOVERSION 1 VERSION 1.2.3 COMPONENTS "core=_vl"
        SUITE_VERSION 9.9.9 COMPATIBILITY SameMajorVersion)
    # second component group on the same export name would need a new call;
    # cover multi-component routing with a dedicated two-component export:
    polyorch_rust_install(TARGETS _vl _kb EXPORT twoc NAMESPACE "twoc::"
        SUITE_VERSION 0.1.0 COMPATIBILITY SameMajorVersion
        COMPONENTS "libg=_vl" "libk=_kb")
endif()
]=])

macro(_configure_child extra_defs out_var)
    execute_process(COMMAND ${CMAKE_COMMAND}
        -G "Unix Makefiles" -S "${_proj}" -B "${_bld}"
        ${extra_defs}
        "-DPOLYORCH_CMAKE_DIR=${CMAKE_CURRENT_LIST_DIR}/../../cmake"
        "-DPOLYORCH_TEST_ART=${_art}"
        RESULT_VARIABLE _ch_rc OUTPUT_VARIABLE _ch_o ERROR_VARIABLE _ch_e)
    set(${out_var} "${_ch_o}${_ch_e}")
endmacro()

# ============================================================ OK child ======
file(REMOVE_RECURSE "${_bld}")
_configure_child("" _log)
if(NOT _ch_rc EQUAL 0)
    message(FATAL_ERROR "configure child failed rc=${_ch_rc}\n${_log}")
endif()

function(ck_read path out)
    if(NOT EXISTS "${path}")
        message(FATAL_ERROR "missing generated file: ${path}")
    endif()
    file(READ "${path}" ${out})
    set(${out} "${${out}}" PARENT_SCOPE)
endfunction()

function(ck_has_all hay needle)
    string(FIND "${hay}" "${needle}" _a)
    if(_a LESS 0)
        message(FATAL_ERROR "check failed: [${needle}] not in generated text")
    endif()
endfunction()

function(ck_absent hay needle)
    string(FIND "${hay}" "${needle}" _a)
    if(NOT _a LESS 0)
        message(FATAL_ERROR "check failed: [${needle}] unexpectedly in generated text")
    endif()
endfunction()

ck_read("${_bld}/legacy-rust.cmake" _stub)
set(_stub_expect
"# Generated by polyorch_rust_install() -- DO NOT EDIT.
# Consume with include(<install-prefix>/lib/cmake/legacy/legacy-rust.cmake)
# or with find_package(legacy CONFIG) via the sibling Config file.
get_filename_component(_POLYORCH_RUST_ROOT
    \"\${CMAKE_CURRENT_LIST_DIR}/../../..\" ABSOLUTE)
add_library(_sl STATIC IMPORTED GLOBAL)
set_target_properties(_sl PROPERTIES IMPORTED_LOCATION     \"\${_POLYORCH_RUST_ROOT}/lib/libdemo.a\")
add_executable(_ex IMPORTED GLOBAL)
set_target_properties(_ex PROPERTIES IMPORTED_LOCATION     \"\${_POLYORCH_RUST_ROOT}/bin/demo-exe\")
")
ck_str("${_stub}" "${_stub_expect}")

ck_read("${_bld}/legacyConfig.cmake" _cfg)
set(_cfg_expect
"# Generated by polyorch_rust_install() -- DO NOT EDIT.
# find_package(legacy CONFIG REQUIRED) entry point.
get_filename_component(PACKAGE_PREFIX_DIR
    \"\${CMAKE_CURRENT_LIST_DIR}/../../..\" ABSOLUTE)
include(\"\${CMAKE_CURRENT_LIST_DIR}/legacy-rust.cmake\")
")
ck_str("${_cfg}" "${_cfg_expect}")

# ConfigVersion exists for the legacy export too (P3 is EXPORT-gated):
ck_read("${_bld}/legacyConfigVersion.cmake" _cv)
ck_has_all("${_cv}" "0.1.0")

ck_read("${_bld}/cmake_install.cmake" _inst)
# byte-stability negatives on the copy rules:
ck_absent("${_inst}" "RENAME \"libdemo.a\"")
# the ONLY link legs in this project are the two pack version legs (negative
# for the legacy rules = the exact count, the file is project-wide):
string(REGEX MATCHALL "CREATE_LINK" _cl "${_inst}")
list(LENGTH _cl _cln)
ck(${_cln} EQUAL 2)
ck_absent("${_inst}" "CMAKE_INSTALL_DO_STRIP")
# legacy pair installed to lib/cmake/legacy:
ck_has_all("${_inst}" "DESTINATION \"\${CMAKE_INSTALL_PREFIX}/lib/cmake/legacy\" TYPE FILE FILES \"${_bld}/legacy-rust.cmake\"")
ck_has_all("${_inst}" "DESTINATION \"\${CMAKE_INSTALL_PREFIX}/lib/cmake/legacy\" TYPE FILE FILES \"${_bld}/legacyConfig.cmake\"")
ck_has_all("${_inst}" "DESTINATION \"\${CMAKE_INSTALL_PREFIX}/lib/cmake/legacy\" TYPE FILE FILES \"${_bld}/legacyConfigVersion.cmake\"")

# ---- SR5 export leg ----
ck_read("${_bld}/pack-rust.cmake" _pstub)
ck_has_all("${_pstub}" "add_library(pack::vkit SHARED IMPORTED GLOBAL)")
ck_has_all("${_pstub}" "/lib/libvv.so.1.2.3\")")
ck_read("${_bld}/pack-rust-core.cmake" _ccomp)
ck_str("${_ccomp}" "${_pstub}")
ck_read("${_bld}/packConfig.cmake" _pcfg)
ck_has_all("${_pcfg}" "set(_polyorch_known_components \"core\")")
ck_has_all("${_pcfg}" "pack_FIND_COMPONENTS")
ck_has_all("${_pcfg}" "pack-rust-\${_polyorch_c}.cmake")
ck_has_all("${_pcfg}" "set(pack_\${_polyorch_c}_FOUND TRUE)")
ck_read("${_bld}/packConfigVersion.cmake" _pcv)
ck_has_all("${_pcv}" "9.9.9")
ck_has_all("${_pcv}" "PACKAGE_VERSION_EXACT")

ck_read("${_bld}/cmake_install.cmake" _inst2)
ck_has_all("${_inst2}" "RENAME \"libvv.so.1.2.3\"")
ck_has_all("${_inst2}" "CREATE_LINK \"libvv.so.1.2.3\"")
ck_has_all("${_inst2}" "CREATE_LINK \"libvv.so.1\"")
ck_has_all("${_inst2}" "DESTINATION \"\${CMAKE_INSTALL_PREFIX}/lib/cmake/pack\" TYPE FILE FILES \"${_bld}/pack-rust-core.cmake\"")

# multi-component: each stub registers exactly its own member
ck_read("${_bld}/twoc-rust-libg.cmake" _t1)
ck_read("${_bld}/twoc-rust-libk.cmake" _t2)
ck_has_all("${_t1}" "twoc::")
ck_has_all("${_t1}" "libvv.so")
ck_absent("${_t1}" "libkb")
ck_has_all("${_t2}" "libkb.so")
ck_absent("${_t2}" "libvv")

# ==================================================== script-mode guards ====
if(POLYORCH_CHILD)
    if("$ENV{POLYORCH_EXPORT_CASE}" STREQUAL "ns")
        polyorch_rust_install(TARGETS ghost NAMESPACE "x::")
        message(FATAL_ERROR "expected NAMESPACE-without-EXPORT rejection")
    elseif("$ENV{POLYORCH_EXPORT_CASE}" STREQUAL "comps")
        polyorch_rust_install(TARGETS ghost COMPONENTS "a=b")
        message(FATAL_ERROR "expected COMPONENTS-without-EXPORT rejection")
    elseif("$ENV{POLYORCH_EXPORT_CASE}" STREQUAL "dest")
        polyorch_rust_install(TARGETS ghost DESTINATION inc)
        message(FATAL_ERROR "expected DESTINATION-without-HEADERS_DIRECTORY rejection")
    elseif("$ENV{POLYORCH_EXPORT_CASE}" STREQUAL "pat")
        polyorch_rust_install(TARGETS ghost PATTERN "*.h")
        message(FATAL_ERROR "expected PATTERN-without-GLOB_HEADERS rejection")
    elseif("$ENV{POLYORCH_EXPORT_CASE}" STREQUAL "alias")
        polyorch_rust_install(TARGETS "h=")
        message(FATAL_ERROR "expected empty-alias rejection")
    elseif("$ENV{POLYORCH_EXPORT_CASE}" STREQUAL "stale")
        polyorch_rust_install(TARGETS ghost STALE_GLOB "a|b")
        message(FATAL_ERROR "expected STALE_GLOB delimiter rejection")
    elseif("$ENV{POLYORCH_EXPORT_CASE}" STREQUAL "hdrdir")
        polyorch_rust_install(TARGETS ghost HEADERS_DIRECTORY "${_s}/no-such-dir")
        message(FATAL_ERROR "expected HEADERS_DIRECTORY existence rejection")
    elseif("$ENV{POLYORCH_EXPORT_CASE}" STREQUAL "globdir")
        polyorch_rust_install(TARGETS ghost GLOB_HEADERS "${_s}/no-such-dir")
        message(FATAL_ERROR "expected GLOB_HEADERS existence rejection")
    else()
        polyorch_rust_install(TARGETS ghost KWARGEN)
        message(FATAL_ERROR "expected unknown keyword rejection")
    endif()
endif()

set(ENV{POLYORCH_EXPORT_CASE} ns)
ck_child_fail("polyorch_rust_install: NAMESPACE requires EXPORT")
set(ENV{POLYORCH_EXPORT_CASE} comps)
ck_child_fail("polyorch_rust_install: COMPONENTS requires EXPORT")
set(ENV{POLYORCH_EXPORT_CASE} dest)
ck_child_fail("DESTINATION is only meaningful")
set(ENV{POLYORCH_EXPORT_CASE} pat)
ck_child_fail("PATTERN is only meaningful")
set(ENV{POLYORCH_EXPORT_CASE} alias)
ck_child_fail("splits into an empty handle")
set(ENV{POLYORCH_EXPORT_CASE} stale)
ck_child_fail("STALE_GLOB pattern must not")
set(ENV{POLYORCH_EXPORT_CASE} hdrdir)
ck_child_fail("HEADERS_DIRECTORY.*does not exist")
set(ENV{POLYORCH_EXPORT_CASE} globdir)
ck_child_fail("GLOB_HEADERS.*does not exist")

# ============================= configure-child FATAL legs (need targets) ====
macro(_expect_fail flagname needle)
    file(REMOVE_RECURSE "${_bld}")
    _configure_child("-D${flagname}=1" _log)
    if(_ch_rc EQUAL 0)
        message(FATAL_ERROR "${flagname} child exited 0, expected: ${needle}")
    endif()
    string(REGEX REPLACE "[ \r\n\t]+" " " _lflat "${_log}")
    if(NOT _lflat MATCHES "${needle}")
        message(FATAL_ERROR "${flagname} rc=${_ch_rc} without [${needle}]:\n${_log}")
    endif()
endmacro()

_expect_fail(POLYORCH_LEG_FAIL "missing required argument .A_SUITE_VERSION")
_expect_fail(POLYORCH_LEG_NOCOMPAT "missing required argument .A_COMPATIBILITY")
_expect_fail(POLYORCH_COMPS_BAD "COMPONENTS .core. lists handle .ghosthandle. that is not in TARGETS")
_expect_fail(POLYORCH_COMPS_DUP "handle ._vl. listed in two COMPONENTS")
_expect_fail(POLYORCH_COMPS_EMPTY "COMPONENTS .a. lists no handles")
_expect_fail(POLYORCH_COMPS_BADNAME "component name .bad name. must be")
_expect_fail(POLYORCH_VER_ON_BIN "SOVERSION/VERSION applies to shared handles only")

message(STATUS "t-rust-installplan-export: OK (2 snapshots + 11 install-text pins + 11 guard pins)")
