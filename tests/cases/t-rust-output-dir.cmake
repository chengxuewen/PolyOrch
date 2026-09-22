# e2e: required
# requires: system-rust
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")

# Output-directory / staging / multiconfig machinery (WP4; reference
# "test/output directory" group adapted, corr:130-376). Legs:
#   1. tp  single-config targetprop -- RUNTIME/LIBRARY/ARCHIVE_OUTPUT_
#      DIRECTORY set AFTER polyorch_rust_build; the deferred finalize must
#      late-read them: $<TARGET_FILE> resolves INTO those dirs (tf probe)
#      and the staged files exist (driver contract check). Build dir and
#      dest dirs carry literal spaces (the reference's free space trick,
#      corr:347).
#   2. cv  single-config cachevar -- CMAKE_*_OUTPUT_DIRECTORY set BEFORE
#      creation (corr:2313 property-initialisation leg).
#   3. mcd/mcr  Ninja Multi-Config Debug+Release (behind the generator-mc
#      probe -- skipped legs, visible in the OK line; the single legs still
#      gate the case): per-config cargo profile dir, per-CFG
#      IMPORTED_LOCATION selection via the tf-$<CONFIG> probes, staged
#      copies in <dest>/<Config>/, and the wrong-profile dir absent.

polyorch_requires(system-rust _req)
if(NOT _req)
    message(STATUS "t-rust-output-dir : SKIP (no system cargo on PATH or in ~/.cargo/bin)")
    return()
endif()

set(_cfg "$ENV{POLYORCH_TEST_CONFIG}")
if(NOT _cfg)
    set(_cfg Debug)
endif()
set(_singen "$ENV{POLYORCH_TEST_GENERATOR}")
if(_singen STREQUAL "Ninja Multi-Config")
    set(_singen "Unix Makefiles")   # single legs never drive an MC child
endif()

_polyorch_pixi_scratch(_s)
set(_fx "${CMAKE_CURRENT_LIST_DIR}/../fixtures/output-dir")
set(_drv "${CMAKE_CURRENT_LIST_DIR}/../fixtures/_driver.cmake")
set(_tg "od-bin-cargo;od-static-cargo;od-shared-cargo")

# Host triple (same mapping as t-rust-profile-release) for the naming table.
if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Darwin")
    set(_tri aarch64-apple-darwin)
    if(CMAKE_HOST_SYSTEM_PROCESSOR STREQUAL "x86_64")
        set(_tri x86_64-apple-darwin)
    endif()
elseif(CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
    set(_tri x86_64-pc-windows-msvc)
else()
    set(_tri x86_64-unknown-linux-gnu)
endif()
_polyorch_rust_artifact_names(TRIPLE "${_tri}" KIND bin    CRATE greet-cli FILE_OUT _nbin)
_polyorch_rust_artifact_names(TRIPLE "${_tri}" KIND static CRATE st_greet  FILE_OUT _nst)
_polyorch_rust_artifact_names(TRIPLE "${_tri}" KIND shared CRATE sh_greet  FILE_OUT _nsh)

# od_drive(<label> <build-var> <gen-var> <cfg-var> <extra-var>): one driver round.
macro(od_drive label bvar gvar cvar extra)
    string(REPLACE ";" "\\;" _tge "${_tg}")   # survive ${_dargs} re-splitting
    set(_dargs "-DFIXTURE=${_fx}" "-DBUILD=${${bvar}}" "-DCONFIG=${${cvar}}"
               "-DTARGETS=${_tge}")
    if(${gvar})
        list(APPEND _dargs "-DGENERATOR=${${gvar}}")
    endif()
    if(DEFINED ${extra} AND NOT "${${extra}}" STREQUAL "")
        string(REPLACE ";" "\\;" _esc "${${extra}}")
        list(APPEND _dargs "-DPASSTHROUGH=${_esc}")
    endif()
    execute_process(COMMAND "${CMAKE_COMMAND}" ${_dargs} -P "${_drv}"
        RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
    set(_dlog "${_out}${_err}")
    drv_echo(_dlog)
    if(_dlog MATCHES "DRIVER: skip")
        message(STATUS "t-rust-output-dir : SKIP (fixture gate: capability absent at configure)")
        return()
    endif()
    if(NOT _rc EQUAL 0)
        message(FATAL_ERROR "rust-output-dir[${label}]: driver failed (${_rc})\n${_dlog}")
    endif()
    drv_get(_dlog bin _obin_${label})
    drv_get(_dlog static_lib _ost_${label})
    drv_get(_dlog shared _osh_${label})
    drv_get(_dlog cargo_bin _ocar_${label})
endmacro()

macro(ck_notfound what p)
    if(EXISTS "${p}")
        message(FATAL_ERROR "rust-output-dir[${what}]: must NOT exist: ${p}")
    endif()
endmacro()

# --- legs 1-2: single-config targetprop (spaces) vs cachevar -----------------
set(_b_tp "${_s}/od tp")
set(_b_cv "${_s}/od cv")
set(_g_tp "${_singen}")
set(_g_cv "${_singen}")
set(_c_tp "${_cfg}")
set(_c_cv "${_cfg}")
set(_x_cv "-DOD_MODE=cachevar")
od_drive(tp _b_tp _g_tp _c_tp _x_none)
od_drive(cv _b_cv _g_cv _c_cv _x_cv)

string(TOLOWER "${_cfg}" _cl)
if(_cl STREQUAL "debug")
    set(_prof debug)
else()
    set(_prof release)
endif()
foreach(_leg tp cv)
    set(_b "${_b_${_leg}}")
    # Staged destinations: exactly the property dirs (no config subdir
    # single-config), file names from the frozen table.
    ck_str("${_obin_${_leg}}" "${_b}/out bin/${_nbin}")
    ck_str("${_ost_${_leg}}" "${_b}/out arc/libst_greet.a")
    ck_str("${_osh_${_leg}}" "${_b}/out lib/libsh_greet.so")
    # $<TARGET_FILE> reference shape: resolves into the late-set dirs.
    ck_file("${_b}/tf-${_cfg}.txt")
    file(READ "${_b}/tf-${_cfg}.txt" _tf)
    ck_str("${_tf}" "${_obin_${_leg}}|${_ost_${_leg}}|${_osh_${_leg}}")
    # The in-place cargo artifact still exists (OUTPUT path unchanged).
    ck_str("${_ocar_${_leg}}" "${_b}/.cargo-target/${_prof}/${_nbin}")
    # No stray <Config> subdirs under single-config staging.
    ck_notfound(${_leg} "${_b}/out bin/Debug/${_nbin}")
    ck_notfound(${_leg} "${_b}/out bin/Release/${_nbin}")
endforeach()
message(STATUS "rust-output-dir: single OK (${_cfg} -> .cargo-target/${_prof}, staged targetprop+cachevar)")

# --- legs 3-4: Ninja Multi-Config (ninja-gated, skipped legs) ----------------
polyorch_requires(generator-mc _mcok)
set(_mcl "skipped(no-ninja)")
if(_mcok)
    set(_mcl "Debug+Release")
    foreach(_mcfg Debug Release)
        if(_mcfg STREQUAL "Debug")
            set(_mprof debug)
            set(_mwrong release)
        else()
            set(_mprof release)
            set(_mwrong debug)
        endif()
        set(_bb "${_s}/od mc ${_mcfg}")
        set(_mg "Ninja Multi-Config")
        set(_mkw "-DOD_MODE=targetprop;-DOD_MC=1;-DOD_CFG=${_mcfg}")
        od_drive("mc${_mcfg}" _bb _mg _mcfg _mkw)
        # Per-config cargo profile dir (corr:762 mapping); the wrong profile
        # must be absent in this fresh tree (right-reason guard).
        ck_str("${_ocar_mc${_mcfg}}" "${_bb}/.cargo-target/${_mprof}/${_nbin}")
        ck_notfound("mc-${_mcfg}" "${_bb}/.cargo-target/${_mwrong}/${_nbin}")
        # Staged copies land in <dest>/<Config>/ (the reference append rule).
        ck_str("${_obin_mc${_mcfg}}" "${_bb}/out bin/${_mcfg}/${_nbin}")
        ck_str("${_ost_mc${_mcfg}}" "${_bb}/out arc/${_mcfg}/libst_greet.a")
        ck_str("${_osh_mc${_mcfg}}" "${_bb}/out lib/${_mcfg}/libsh_greet.so")
        ck_notfound("mc-${_mcfg}" "${_bb}/out bin/${_nbin}")
        # Per-CFG IMPORTED_LOCATION: the generate-time probe for THIS config
        # resolved into the staged paths (proves LOCATION_<CFG> selection).
        ck_file("${_bb}/tf-${_mcfg}.txt")
        file(READ "${_bb}/tf-${_mcfg}.txt" _mtf)
        ck_str("${_mtf}" "${_obin_mc${_mcfg}}|${_ost_mc${_mcfg}}|${_osh_mc${_mcfg}}")
        message(STATUS "rust-output-dir: MC-${_mcfg} cargo=${_ocar_mc${_mcfg}} staged=${_obin_mc${_mcfg}}")
    endforeach()
endif()
message(STATUS "rust-output-dir: OK (targetprop+cachevar ${_cfg}; MC ${_mcl})")
