# B8 download leg refusals. Two child re-execs (POLYORCH_DL_CASE selects):
#   hashred -- downloaded bytes that fail the url_hash gate are refused
#              BEFORE the cache was touched: no cache entry, no .part residue;
#   dl-off  -- a declared url_online does NOT license a download: without
#              DOWNLOAD on the loader refuses (strict-first), and if the
#              refusal were broken the child would really fetch (and succeed
#              on the live file:// source) -- rc=0 there is itself the red.
# The parent additionally pins the cache-cleanliness invariant.
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchThirdPartyHelpers.cmake")

set(_work "$ENV{TMPDIR}/tp-dl-red")
file(REMOVE_RECURSE "${_work}")
file(COPY "${CMAKE_CURRENT_LIST_DIR}/../fixtures/thirdparty-basic/payload/" DESTINATION "${_work}/pack/payload-1.2.3/")
file(MAKE_DIRECTORY "${_work}/upstream")
execute_process(COMMAND "${CMAKE_COMMAND}" -E tar czf "${_work}/upstream/payload.tar.gz" payload-1.2.3
    WORKING_DIRECTORY "${_work}/pack" RESULT_VARIABLE _rc)
ck(_rc EQUAL 0)
file(SHA256 "${_work}/upstream/payload.tar.gz" _h)
file(WRITE "${_work}/upstream/bad.tar.gz" "this is not an archive -- substituted bytes")

file(WRITE "${_work}/recipe-dl.json"
  "{\"schema_version\":1,\"name\":\"payload\",\"version\":\"1.2.3\",\"provider\":\"source\",\"license\":\"MIT\",\"url\":\"payload.tar.gz\",\"url_hash\":\"${_h}\",\"url_online\":\"file://${_work}/upstream/payload.tar.gz\",\"fetch_only\":true}")
file(WRITE "${_work}/recipe-hashred.json"
  "{\"schema_version\":1,\"name\":\"payload\",\"version\":\"1.2.3\",\"provider\":\"source\",\"license\":\"MIT\",\"url\":\"payload.tar.gz\",\"url_hash\":\"${_h}\",\"url_online\":\"file://${_work}/upstream/bad.tar.gz\",\"fetch_only\":true}")

if(NOT POLYORCH_CHILD)
    set(ENV{POLYORCH_DL_CASE} hashred)
ck_child_fail("downloaded[ ]+bytes[ ]+do[ ]+not[ ]+match[ ]+url_hash")
    # the gate ran BEFORE the cache: no entry was minted for bad bytes
    # (ck with a bare variable: a quoted "${_res}" would unravel to empty
    # tokens and leave STREQUAL comparing nothing -- _inc.cmake header rule)
    file(GLOB _res LIST_DIRECTORIES true "${_work}/cache-red/*")
    ck(NOT _res)
    set(ENV{POLYORCH_DL_CASE} dl-off)
ck_child_fail("strict-first[ ]+keeps[ ]+the[ ]+network[ ]+off")
    message(STATUS "THIRD-PARTY-DOWNLOAD-REFUSALS-OK")
    return()
endif()
if("$ENV{POLYORCH_DL_CASE}" STREQUAL "hashred")
    polyorch_thirdparty_recipe(RECIPE "${_work}/recipe-hashred.json" WORK_DIR "${_work}/w-red"
        BUILD_TYPE Debug DOWNLOAD on DOWNLOAD_CACHE_DIR "${_work}/cache-red"
        SOURCE_DIR_OUT _x)
    message(FATAL_ERROR "unreachable: the pre-cache hash gate must refuse the downloaded bytes")
endif()
if("$ENV{POLYORCH_DL_CASE}" STREQUAL "dl-off")
    polyorch_thirdparty_recipe(RECIPE "${_work}/recipe-dl.json" WORK_DIR "${_work}/w-off"
        BUILD_TYPE Debug SOURCE_DIR_OUT _x)
    message(FATAL_ERROR "unreachable: DOWNLOAD off must refuse despite a declared url_online")
endif()
message(FATAL_ERROR "unknown POLYORCH_DL_CASE '$ENV{POLYORCH_DL_CASE}'")
