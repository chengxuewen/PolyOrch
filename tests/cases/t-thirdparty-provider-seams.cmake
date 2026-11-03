# expect-log THIRD-PARTY-PROVIDER-SEAMS-OK
if(TP_LEG)
    # self-lock (the D48 lesson): the child dispatches on TP_LEG and dies in
    # the guard under test -- it never spawns further children
    include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchThirdPartyHelpers.cmake")
    set(_fx "${CMAKE_CURRENT_LIST_DIR}/../fixtures/thirdparty-basic/payload")
    set(_b "$ENV{TMPDIR}/tp-pseg-b")
    set(_i "$ENV{TMPDIR}/tp-pseg-i")
    if(TP_LEG STREQUAL "sysroot")
        polyorch_thirdparty_build(NAME x SOURCE_DIR "${_fx}" BUILD_DIR "${_b}"
            INSTALL_DIR "${_i}" BUILD_TYPE Debug GENERATOR "Unix Makefiles"
            DEPENDENCY_PROVIDER sysroot SYSROOT "$ENV{TMPDIR}/sr")
    elseif(TP_LEG STREQUAL "pixi-noenv")
        polyorch_thirdparty_build(NAME x SOURCE_DIR "${_fx}" BUILD_DIR "${_b}"
            INSTALL_DIR "${_i}" BUILD_TYPE Debug GENERATOR "Unix Makefiles"
            DEPENDENCY_PROVIDER pixi)
    elseif(TP_LEG STREQUAL "pixi-nocompiler")
        polyorch_thirdparty_build(NAME x SOURCE_DIR "${_fx}" BUILD_DIR "${_b}"
            INSTALL_DIR "${_i}" BUILD_TYPE Debug GENERATOR "Unix Makefiles"
            DEPENDENCY_PROVIDER pixi PIXI_ENVIRONMENT tpenv)
    endif()
    message(FATAL_ERROR "unreachable: leg ${TP_LEG} must refuse")
else()
    include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
    include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchThirdPartyHelpers.cmake")
    foreach(_leg IN ITEMS sysroot pixi-noenv pixi-nocompiler)
        execute_process(COMMAND "${CMAKE_COMMAND}" "-DTP_LEG=${_leg}" -P "${CMAKE_CURRENT_LIST_FILE}"
            RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
        set(_txt "${_out}${_err}")
        string(REPLACE "\n" " " _txt "${_txt}")
        while(_txt MATCHES "  ")
            string(REPLACE "  " " " _txt "${_txt}")
        endwhile()
        if(_rc EQUAL 0)
            message(FATAL_ERROR "provider seam leg '${_leg}' exited 0 -- expected a refusal")
        endif()
        if(_leg STREQUAL "sysroot" AND NOT _txt MATCHES "cross/device batch")
            message(FATAL_ERROR "sysroot leg wording missing:\n${_txt}")
        endif()
        if(_leg STREQUAL "pixi-noenv" AND NOT _txt MATCHES "requires PIXI_ENVIRONMENT")
            message(FATAL_ERROR "pixi-noenv leg wording missing:\n${_txt}")
        endif()
        if(_leg STREQUAL "pixi-nocompiler" AND NOT _txt MATCHES "explicit compiler")
            message(FATAL_ERROR "pixi-nocompiler leg wording missing:\n${_txt}")
        endif()
    endforeach()

    # runtime audit legs with a faked readelf under PATH we control
    set(_work "$ENV{TMPDIR}/tp-pseg")
    file(REMOVE_RECURSE "${_work}")
    file(MAKE_DIRECTORY "${_work}/inst" "${_work}/hitbin" "${_work}/missbin" "${_work}/emptybin")
    file(WRITE "${_work}/inst/fake.elf" "pretend-binary\n")
    file(WRITE "${_work}/hitbin/readelf" "#!/bin/sh\necho ' (RPATH) Library rpath: [$0]'\necho ' (RPATH) real: [/tp/px/lib]'\n")
    file(WRITE "${_work}/missbin/readelf" "#!/bin/sh\necho ' (NEEDED) Shared library: [libc.so.6]'\n")
    foreach(_d hitbin missbin)
        execute_process(COMMAND chmod +x "${_work}/${_d}/readelf")
    endforeach()
    # the audit verdicts come from a faked readelf under a PATH we control
    set(_oldpath "$ENV{PATH}")
    set(ENV{PATH} "${_work}/hitbin")
    _polyorch_tp_pixi_audit("${_work}/inst" "/tp/px" _ahit _dhit)
    ck(_ahit)
    if(NOT _dhit MATCHES "fake.elf")
        message(FATAL_ERROR "audit hit detail missing the file: ${_dhit}")
    endif()
    set(ENV{PATH} "${_work}/missbin")
    _polyorch_tp_pixi_audit("${_work}/inst" "/tp/px" _amiss _dmiss)
    ck(NOT _amiss)
    set(ENV{PATH} "${_work}/emptybin")
    _polyorch_tp_pixi_audit("${_work}/inst" "/tp/px" _anone _dnone)
    ck(NOT _anone)
    ck(_dnone MATCHES "no readelf")
    set(ENV{PATH} "${_oldpath}")

    # the manifest field round-trips
    string(RANDOM LENGTH 64 ALPHABET 1 RANDOM_SEED 22 _k64)
    polyorch_thirdparty_manifest_write(MANIFEST "${_work}/m.json" KEY "${_k64}"
        NAME q VERSION 1.0 LICENSE MIT PIXI_RUNTIME_REQUIRED)
    file(READ "${_work}/m.json" _j)
    string(JSON _v GET "${_j}" pixi_runtime_required)
    ck(_v)

    message(STATUS "THIRD-PARTY-PROVIDER-SEAMS-OK")
endif()
