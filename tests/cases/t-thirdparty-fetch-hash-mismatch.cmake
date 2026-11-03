# expect-log THIRD-PARTY-FETCH-HASH-OK
if(POLYORCH_CHILD)
    include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchThirdPartyHelpers.cmake")
    set(_fx "${CMAKE_CURRENT_LIST_DIR}/../fixtures/thirdparty-basic")
    set(_work "$ENV{TMPDIR}/tp-fhm")
    file(REMOVE_RECURSE "${_work}")
    file(COPY "${_fx}/payload/" DESTINATION "${_work}/pack/payload-1.2.3/")
    execute_process(COMMAND "${CMAKE_COMMAND}" -E tar czf "${_work}/payload.tar.gz" payload-1.2.3
        WORKING_DIRECTORY "${_work}/pack" RESULT_VARIABLE _rc)
    if(NOT _rc EQUAL 0)
        message(FATAL_ERROR "packing failed")
    endif()
    polyorch_thirdparty_fetch(NAME payload URL "${_work}/payload.tar.gz"
        URL_HASH "SHA256=0000000000000000000000000000000000000000000000000000000000000000"
        OUTPUT_DIR "${_work}/3rd" SOURCE_DIR_OUT _s)
    message(FATAL_ERROR "unreachable: the hash gate must refuse")
else()
    include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
    ck_child_fail("archive hash mismatch")
    # the refusal must also name the discipline (corrupt or substituted)
    ck_child_fail("Refusing to extract")
    message(STATUS "THIRD-PARTY-FETCH-HASH-OK")
endif()
