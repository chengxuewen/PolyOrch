# expect-log THIRD-PARTY-RECIPE-FETCHONLY-OK
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchThirdPartyHelpers.cmake")

set(_fx "${CMAKE_CURRENT_LIST_DIR}/../fixtures/thirdparty-basic")
set(_work "$ENV{TMPDIR}/tp-recipe-fetchonly")
file(REMOVE_RECURSE "${_work}")
file(COPY "${_fx}/payload/" DESTINATION "${_work}/pack/payload-1.2.3/")
execute_process(COMMAND "${CMAKE_COMMAND}" -E tar czf "${_work}/payload.tar.gz" payload-1.2.3
    WORKING_DIRECTORY "${_work}/pack" RESULT_VARIABLE _rc)
ck(_rc EQUAL 0)
file(SHA256 "${_work}/payload.tar.gz" _h)

# the patch script sits beside the recipe: a RELATIVE element in patch_command
# must resolve against the recipe base (the command runs in the source tree)
file(WRITE "${_work}/mark.cmake" "file(APPEND \"tpdemo.h\" \"// FETCHONLY-MARK\\n\")\n")
file(WRITE "${_work}/recipe.json"
  "{\"schema_version\":1,\"name\":\"imgsrc\",\"version\":\"1.0\",\"provider\":\"source\",\"license\":\"MIT\",\"url\":\"payload.tar.gz\",\"url_hash\":\"${_h}\",\"fetch_only\":true,\"patch_command\":[\"${CMAKE_COMMAND}\",\"-P\",\"mark.cmake\"]}")

polyorch_thirdparty_recipe(RECIPE "${_work}/recipe.json" WORK_DIR "${_work}/w"
    BUILD_TYPE Debug SOURCE_DIR_OUT _src FINGERPRINT_OUT _k INSTALL_DIR_OUT _i)
ck_file("${_src}/tpdemo.h")
file(READ "${_src}/tpdemo.h" _hdr)
string(FIND "${_hdr}" "FETCHONLY-MARK" _p)
ck(NOT _p EQUAL -1)
# fetch-only: no key, no build tree, no install prefix (F8: wrappers never
# build/install/cache)
string(LENGTH "${_k}" _kl)
ck(_kl EQUAL 0)
ck(NOT EXISTS "${_work}/w/imgsrc/build-Debug")
ck(NOT EXISTS "${_i}")

message(STATUS "THIRD-PARTY-RECIPE-FETCHONLY-OK")
