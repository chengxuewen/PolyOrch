# expect-log THIRD-PARTY-PACKAGE-CORRUPT-OK
# requires: cxx
if(POLYORCH_CHILD)
    include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchThirdPartyHelpers.cmake")
    find_program(_tp_ninja NAMES ninja)
    find_program(_tp_make NAMES make)
    if(_tp_ninja)
        set(_tp_gen "Ninja")
    elseif(_tp_make)
        set(_tp_gen "Unix Makefiles")
    else()
        message(FATAL_ERROR "neither ninja nor make found -- the build verb needs a generator")
    endif()
    # The archive bytes no longer match the sha sidecar -> the loader must
    # refuse BEFORE touching the install prefix (the sha gate precedes the
    # mkdir + extract).
    polyorch_thirdparty_recipe(RECIPE "$ENV{TMPDIR}/tp-pkg-corrupt/recipe.json"
        WORK_DIR "$ENV{TMPDIR}/tp-pkg-corrupt/w" BUILD_TYPE Debug GENERATOR "${_tp_gen}"
        PACKAGES_DIR "$ENV{TMPDIR}/tp-pkg-corrupt/pkgs")
    message(FATAL_ERROR "unreachable: the sha gate must fire first")
else()
    include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
    include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")
    include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchThirdPartyHelpers.cmake")
    polyorch_requires(cxx _ok)
    if(NOT _ok)
        message(STATUS "t-thirdparty-package-corrupt : SKIP (no c++ toolchain on PATH or the pixi dirs)")
        return()
    endif()
    find_program(_tp_ninja NAMES ninja)
    find_program(_tp_make NAMES make)
    if(_tp_ninja)
        set(_tp_gen "Ninja")
    elseif(_tp_make)
        set(_tp_gen "Unix Makefiles")
    else()
        message(FATAL_ERROR "neither ninja nor make found -- the build verb needs a generator")
    endif()

    set(_fx "${CMAKE_CURRENT_LIST_DIR}/../fixtures/thirdparty-basic")
    set(_work "$ENV{TMPDIR}/tp-pkg-corrupt")
    file(REMOVE_RECURSE "${_work}")
    file(COPY "${_fx}/payload/" DESTINATION "${_work}/pack/payload-1.2.3/")
    execute_process(COMMAND "${CMAKE_COMMAND}" -E tar czf "${_work}/payload.tar.gz" payload-1.2.3
        WORKING_DIRECTORY "${_work}/pack" RESULT_VARIABLE _rc)
    ck(_rc EQUAL 0)
    file(SHA256 "${_work}/payload.tar.gz" _h)
    file(WRITE "${_work}/recipe.json"
      "{\"schema_version\":1,\"name\":\"payload\",\"version\":\"1.2.3\",\"provider\":\"source\",\"license\":\"MIT\",\"url\":\"${_work}/payload.tar.gz\",\"url_hash\":\"${_h}\",\"link_mode\":\"static\",\"find_package\":{\"name\":\"tpdemo\",\"targets\":[\"tpdemo::tpdemo\"]},\"alias\":\"Demo::tpdemo\"}")
    polyorch_thirdparty_recipe(RECIPE "${_work}/recipe.json" WORK_DIR "${_work}/w"
        BUILD_TYPE Debug GENERATOR "${_tp_gen}" PARALLEL 2
        PACKAGES_DIR "${_work}/pkgs" PACKAGE_OUT _pkg)
    ck_file("${_pkg}")

    # corrupt one trailing byte: the archive keeps its name, the sidecar keeps
    # the old digest -- exactly the "package exists but is not what it claims"
    # state the verdict must reject
    file(APPEND "${_pkg}" "x")
    file(REMOVE_RECURSE "${_work}/w/payload/install-Debug" "${_work}/w/payload/build-Debug")
    ck_child_fail("refusing to unpack")
    # the child died before creating the install prefix
    ck(NOT EXISTS "${_work}/w/payload/install-Debug")
    message(STATUS "THIRD-PARTY-PACKAGE-CORRUPT-OK")
endif()
