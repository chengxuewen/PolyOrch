# expect-log THIRD-PARTY-SEAMS-OK
if(TP_LEG)
    # self-lock (the D48 lesson): the child dispatches on TP_LEG and dies in
    # the guard under test -- it never spawns further children
    include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchThirdPartyHelpers.cmake")
    set(_h "1111111111111111111111111111111111111111111111111111111111111111")
    if(TP_LEG STREQUAL "provider")
        file(WRITE "$ENV{TMPDIR}/tp-seg.json"
  "{\"schema_version\":1,\"name\":\"x\",\"version\":\"1\",\"provider\":\"vcpkg\",\"license\":\"MIT\",\"url\":\"/nonexistent.tar.gz\",\"url_hash\":\"${_h}\"}")
    elseif(TP_LEG STREQUAL "schema-missing")
        file(WRITE "$ENV{TMPDIR}/tp-seg.json"
  "{\"schema_version\":1,\"name\":\"x\",\"version\":\"1\",\"provider\":\"source\",\"license\":\"MIT\",\"url\":\"/nonexistent.tar.gz\"}")
    elseif(TP_LEG STREQUAL "schema-newer")
        file(WRITE "$ENV{TMPDIR}/tp-seg.json"
  "{\"schema_version\":2,\"name\":\"x\",\"version\":\"1\",\"provider\":\"source\",\"license\":\"MIT\",\"url\":\"/nonexistent.tar.gz\",\"url_hash\":\"${_h}\"}")
    endif()
    polyorch_thirdparty_recipe(RECIPE "$ENV{TMPDIR}/tp-seg.json"
        WORK_DIR "$ENV{TMPDIR}/tp-seg-w" BUILD_TYPE Debug)
    message(FATAL_ERROR "unreachable: leg ${TP_LEG} must refuse")
else()
    include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
    foreach(_leg IN ITEMS provider schema-missing schema-newer)
        execute_process(COMMAND "${CMAKE_COMMAND}" "-DTP_LEG=${_leg}" -P "${CMAKE_CURRENT_LIST_FILE}"
            RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
        set(_txt "${_out}${_err}")
        string(REPLACE "\n" " " _txt "${_txt}")
        while(_txt MATCHES "  ")
            string(REPLACE "  " " " _txt "${_txt}")
        endwhile()
        if(_rc EQUAL 0)
            message(FATAL_ERROR "seam leg '${_leg}' exited 0 -- expected a refusal")
        endif()
        if(_leg STREQUAL "provider" AND NOT _txt MATCHES "P7 provider face")
            message(FATAL_ERROR "provider leg wording missing:\n${_txt}")
        endif()
        if(_leg STREQUAL "schema-missing" AND NOT _txt MATCHES "required field")
            message(FATAL_ERROR "schema-missing leg wording missing:\n${_txt}")
        endif()
        if(_leg STREQUAL "schema-newer" AND NOT _txt MATCHES "newer than this[ ]+loader")
            message(FATAL_ERROR "schema-newer leg wording missing:\n${_txt}")
        endif()
    endforeach()
    message(STATUS "THIRD-PARTY-SEAMS-OK")
endif()
