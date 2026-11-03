# expect-log THIRD-PARTY-FETCH-PATCH-OK
if(POLYORCH_CHILD)
    include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchThirdPartyHelpers.cmake")
    set(_fx "${CMAKE_CURRENT_LIST_DIR}/../fixtures/thirdparty-basic")
    set(_work "$ENV{TMPDIR}/tp-fpm")
    file(REMOVE_RECURSE "${_work}")
    file(COPY "${_fx}/payload/" DESTINATION "${_work}/pack/payload-1.2.3/")
    execute_process(COMMAND "${CMAKE_COMMAND}" -E tar czf "${_work}/payload.tar.gz" payload-1.2.3
        WORKING_DIRECTORY "${_work}/pack" RESULT_VARIABLE _rc)
    if(NOT _rc EQUAL 0)
        message(FATAL_ERROR "packing failed")
    endif()
    file(SHA256 "${_work}/payload.tar.gz" _h)
    polyorch_thirdparty_fetch(NAME payload URL "${_work}/payload.tar.gz"
        URL_HASH "SHA256=${_h}"
        PATCHES "${_fx}/payload-patch/tpdemo.cpp"
        PATCH_SHA256 "0000000000000000000000000000000000000000000000000000000000000000"
        OUTPUT_DIR "${_work}/3rd" SOURCE_DIR_OUT _s)
    message(FATAL_ERROR "unreachable: the patch gate must refuse")
else()
    include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
    ck_child_fail("patch hash mismatch")
    ck_child_fail("Refusing to apply")
    # L6 order proof: verification precedes ANY tree mutation -- nothing was
    # ever extracted under the output root (the child runs idempotently, so
    # the second ck_child_fail leg re-ran the same refusal)
    ck(NOT EXISTS "$ENV{TMPDIR}/tp-fpm/3rd/payload/source")
    message(STATUS "THIRD-PARTY-FETCH-PATCH-OK")
endif()
