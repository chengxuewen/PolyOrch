# expect-log THIRD-PARTY-SEAMS-OK
if(TP_LEG)
    # self-lock (the D48 lesson): the child dispatches on TP_LEG and dies in
    # the guard under test -- it never spawns further children
    include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchThirdPartyHelpers.cmake")
    set(_h "1111111111111111111111111111111111111111111111111111111111111111")
    if(TP_LEG STREQUAL "provider")
        # P7a: the vcpkg leg is a real ecosystem recipe now -- a pin island
        # (schema gate passes) that dies at the strict-first gate in the
        # verdict ring (no pre-baked artifact, no GENERATE_ECOSYSTEM)
        file(MAKE_DIRECTORY "$ENV{TMPDIR}/tp-seg-island")
        file(WRITE "$ENV{TMPDIR}/tp-seg-island/vcpkg.json"
  "{\"name\":\"x-island\",\"version\":\"1\",\"builtin-baseline\":\"${_h}\",\"dependencies\":[\"zlib\"]}")
        file(WRITE "$ENV{TMPDIR}/tp-seg.json"
  "{\"schema_version\":1,\"name\":\"x\",\"version\":\"1\",\"provider\":\"vcpkg\",\"license\":\"MIT\",\"pin_dir\":\"$ENV{TMPDIR}/tp-seg-island\"}")
    elseif(TP_LEG STREQUAL "conan")
        file(WRITE "$ENV{TMPDIR}/tp-seg.json"
  "{\"schema_version\":1,\"name\":\"x\",\"version\":\"1\",\"provider\":\"conan\",\"license\":\"MIT\"}")
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
    foreach(_leg IN ITEMS provider conan schema-missing schema-newer)
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
        if(_leg STREQUAL "provider")
            # strict-first: the full refusal text names the philosophy, the
            # explicit generate switch and the manual/off-ramp exits
            foreach(_w IN ITEMS "strict-first" "GENERATE_ECOSYSTEM" "no auto-fallback" "--x-manifest-root=" "--triplet=" "provider .source.")
                if(NOT _txt MATCHES "${_w}")
                    message(FATAL_ERROR "provider leg wording '${_w}' missing:\n${_txt}")
                endif()
            endforeach()
        endif()
        if(_leg STREQUAL "conan" AND NOT _txt MATCHES "P7b")
            message(FATAL_ERROR "conan leg wording missing:\n${_txt}")
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
