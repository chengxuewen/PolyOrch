# expect-log THIRD-PARTY-RECIPE-OK
# requires: cxx
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchThirdPartyHelpers.cmake")

polyorch_requires(cxx _ok)
if(NOT _ok)
    message(STATUS "t-thirdparty-recipe-e2e : SKIP (no c++ toolchain on PATH or the pixi dirs)")
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
set(_work "$ENV{TMPDIR}/tp-recipe")
file(REMOVE_RECURSE "${_work}")
file(COPY "${_fx}/payload/" DESTINATION "${_work}/pack/payload-1.2.3/")
execute_process(COMMAND "${CMAKE_COMMAND}" -E tar czf "${_work}/payload.tar.gz" payload-1.2.3
    WORKING_DIRECTORY "${_work}/pack" RESULT_VARIABLE _rc)
ck(_rc EQUAL 0)
file(SHA256 "${_work}/payload.tar.gz" _h)

# the recipe (written at run time: url + hash are run-computed)
file(WRITE "${_work}/recipe.json"
  "{\"schema_version\":1,\"name\":\"payload\",\"version\":\"1.2.3\",\"provider\":\"source\",\"license\":\"MIT\",\"url\":\"${_work}/payload.tar.gz\",\"url_hash\":\"${_h}\",\"link_mode\":\"static\",\"find_package\":{\"name\":\"tpdemo\",\"targets\":[\"tpdemo::tpdemo\"]},\"alias\":\"Demo::tpdemo\"}")

polyorch_thirdparty_recipe(RECIPE "${_work}/recipe.json" WORK_DIR "${_work}/w"
    BUILD_TYPE Debug GENERATOR "${_tp_gen}" PARALLEL 2
    INSTALL_DIR_OUT _i FINGERPRINT_OUT _k MANIFEST_OUT _mf
    FIND_PACKAGE_NAME_OUT _fpn TARGETS_OUT _tgts ALIAS_OUT _al SOURCE_DIR_OUT _sd)
string(LENGTH "${_k}" _klen)
ck(_klen EQUAL 64)
ck_str("${_fpn}" "tpdemo")
ck_str("${_tgts}" "tpdemo::tpdemo")
ck_str("${_al}" "Demo::tpdemo")
ck_file("${_i}/lib/cmake/tpdemo/tpdemoConfig.cmake")
ck_file("${_mf}")
ck_file("${_sd}/CMakeLists.txt")
# the sidecar's key equals the returned fingerprint; license rides along (L7)
file(READ "${_mf}" _j)
string(JSON _v GET "${_j}" key)
ck_str("${_v}" "${_k}")
string(JSON _v GET "${_j}" license)
ck_str("${_v}" "MIT")

# cache hit (manifest identity, NOT existence): same inputs again with the
# build tree DELETED and the source tree deleted -- a miss would rebuild
# build-Debug; only the manifest hit keeps it absent. (Acquire re-extracting
# a vanished source is correct and expected: the stamp is an inputs memo,
# never proof the outputs survived.)
file(REMOVE_RECURSE "${_work}/w/payload/build-Debug" "${_work}/w/payload/source")
polyorch_thirdparty_recipe(RECIPE "${_work}/recipe.json" WORK_DIR "${_work}/w"
    BUILD_TYPE Debug GENERATOR "${_tp_gen}" INSTALL_DIR_OUT _i2)
ck(_i2 STREQUAL _i)
ck(NOT EXISTS "${_work}/w/payload/build-Debug")
ck_file("${_work}/w/payload/source/CMakeLists.txt")

# O-3 leg: a different effective config is a DIFFERENT install prefix with
# its own manifest -- the multi-config collapse (r4 M2) has a regression
# guard on exactly this line. No wipe: install-Release carries no manifest,
# so the cache verdict is a guaranteed miss without touching Debug's tree.
polyorch_thirdparty_recipe(RECIPE "${_work}/recipe.json" WORK_DIR "${_work}/w"
    BUILD_TYPE Release GENERATOR "${_tp_gen}" INSTALL_DIR_OUT _ir)
ck(NOT _ir STREQUAL _i)
ck_file("${_ir}/polyorch-thirdparty-manifest.json")
ck_file("${_i}/lib/cmake/tpdemo/tpdemoConfig.cmake")

message(STATUS "THIRD-PARTY-RECIPE-OK")
