# expect-log downloaded from file://
# B8 acquisition resolution, leg 3+4: the download cache and the network
# fetch behind DOWNLOAD on. url_online is the only network source and it is
# admitted by the SAME url_hash gate before anything touches the cache (the
# .part temp is hash-verified, then atomically renamed to
# <cache>/<name>-<url_hash>). The zero-network replay proof is BEHAVIORAL:
# the second acquire points url_online at a dead path -- if the cache leg
# were broken the loader would really download and FATAL, so exit 0 pins the
# cache hit. file:// keeps the whole leg offline.
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchThirdPartyHelpers.cmake")

set(_work "$ENV{TMPDIR}/tp-download")
file(REMOVE_RECURSE "${_work}")
file(COPY "${CMAKE_CURRENT_LIST_DIR}/../fixtures/thirdparty-basic/payload/" DESTINATION "${_work}/pack/payload-1.2.3/")
file(MAKE_DIRECTORY "${_work}/upstream")
execute_process(COMMAND "${CMAKE_COMMAND}" -E tar czf "${_work}/upstream/payload.tar.gz" payload-1.2.3
    WORKING_DIRECTORY "${_work}/pack" RESULT_VARIABLE _rc)
ck(_rc EQUAL 0)
file(SHA256 "${_work}/upstream/payload.tar.gz" _h)

# The recipe carries a bare url that resolves nowhere (archive layer moved)
# plus the upstream network twin; DOWNLOAD on + an explicit cache anchor.
file(WRITE "${_work}/recipe.json"
  "{\"schema_version\":1,\"name\":\"payload\",\"version\":\"1.2.3\",\"provider\":\"source\",\"license\":\"MIT\",\"url\":\"payload.tar.gz\",\"url_hash\":\"${_h}\",\"url_online\":\"file://${_work}/upstream/payload.tar.gz\",\"fetch_only\":true}")

polyorch_thirdparty_recipe(RECIPE "${_work}/recipe.json" WORK_DIR "${_work}/w1"
    BUILD_TYPE Debug DOWNLOAD on DOWNLOAD_CACHE_DIR "${_work}/cache"
    SOURCE_DIR_OUT _sd1)
ck_file("${_sd1}/CMakeLists.txt")
# the cache holds <name>-<hash> (human-readable, hash-keyed), no .part residue
ck_file("${_work}/cache/payload-${_h}")
ck(NOT EXISTS "${_work}/cache/payload-${_h}.part")

# second acquire: FRESH work dir, url_online now DEAD. Only a genuine cache
# hit explains a green exit; touching the network would FATAL on the dead
# path. Same bytes -> same stamp key -> the extraction is fresh here but the
# artifact is identical to w1's.
file(WRITE "${_work}/recipe-dead.json"
  "{\"schema_version\":1,\"name\":\"payload\",\"version\":\"1.2.3\",\"provider\":\"source\",\"license\":\"MIT\",\"url\":\"payload.tar.gz\",\"url_hash\":\"${_h}\",\"url_online\":\"file:///nonexistent/payload-does-not-exist.tar.gz\",\"fetch_only\":true}")
polyorch_thirdparty_recipe(RECIPE "${_work}/recipe-dead.json" WORK_DIR "${_work}/w2"
    BUILD_TYPE Debug DOWNLOAD on DOWNLOAD_CACHE_DIR "${_work}/cache"
    SOURCE_DIR_OUT _sd2)
ck_file("${_sd2}/CMakeLists.txt")
file(SHA256 "${_sd1}/CMakeLists.txt" _h1)
file(SHA256 "${_sd2}/CMakeLists.txt" _h2)
ck_str("${_h1}" "${_h2}")
message(STATUS "THIRD-PARTY-DOWNLOAD-OK")
