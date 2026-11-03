# expect-log THIRD-PARTY-FETCH-OK
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchThirdPartyHelpers.cmake")

set(_fx "${CMAKE_CURRENT_LIST_DIR}/../fixtures/thirdparty-basic")
set(_work "$ENV{TMPDIR}/tp-fetch")
file(REMOVE_RECURSE "${_work}")

# Pack the payload at run time (hash computed this run -- no binary fixture
# committed; tar bytes may drift, the verdict never does).
file(COPY "${_fx}/payload/" DESTINATION "${_work}/pack/payload-1.2.3/")
execute_process(COMMAND "${CMAKE_COMMAND}" -E tar czf "${_work}/payload.tar.gz" payload-1.2.3
    WORKING_DIRECTORY "${_work}/pack" RESULT_VARIABLE _rc)
ck(_rc EQUAL 0)
file(SHA256 "${_work}/payload.tar.gz" _h)

# 1) verified acquire: extraction flattens the single top dir into source/
polyorch_thirdparty_fetch(NAME payload URL "${_work}/payload.tar.gz"
    URL_HASH "SHA256=${_h}" OUTPUT_DIR "${_work}/3rd"
    SOURCE_DIR_OUT _src ARCHIVE_SHA256_OUT _ah)
ck_str("${_ah}" "${_h}")
ck_file("${_src}/CMakeLists.txt")
file(READ "${_src}/tpdemo.cpp" _c)
ck(_c MATCHES "42")

# 2) stamp reuse: identical inputs are a no-op
polyorch_thirdparty_fetch(NAME payload URL "${_work}/payload.tar.gz"
    URL_HASH "SHA256=${_h}" OUTPUT_DIR "${_work}/3rd"
    SOURCE_DIR_OUT _src2 ARCHIVE_SHA256_OUT _ah2)
ck(_src2 STREQUAL _src)

# 3) verified overlay leg: a patch file with the target's basename replaces
# it under the archive root (L6: verify FIRST, then apply)
file(SHA256 "${_fx}/payload-patch/tpdemo.cpp" _ph)
polyorch_thirdparty_fetch(NAME payload URL "${_work}/payload.tar.gz"
    URL_HASH "SHA256=${_h}" PATCHES "${_fx}/payload-patch/tpdemo.cpp"
    PATCH_SHA256 "${_ph}" OUTPUT_DIR "${_work}/3rdp" SOURCE_DIR_OUT _psrc)
file(READ "${_psrc}/tpdemo.cpp" _pc)
ck(_pc MATCHES "43")

message(STATUS "THIRD-PARTY-FETCH-OK")
