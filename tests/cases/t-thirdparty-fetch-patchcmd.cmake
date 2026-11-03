# expect-log THIRD-PARTY-FETCH-PATCHCMD-OK
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchThirdPartyHelpers.cmake")

set(_fx "${CMAKE_CURRENT_LIST_DIR}/../fixtures/thirdparty-basic")
set(_work "$ENV{TMPDIR}/tp-fetch-patchcmd")
file(REMOVE_RECURSE "${_work}")
file(COPY "${_fx}/payload/" DESTINATION "${_work}/pack/payload-1.2.3/")
execute_process(COMMAND "${CMAKE_COMMAND}" -E tar czf "${_work}/payload.tar.gz" payload-1.2.3
    WORKING_DIRECTORY "${_work}/pack" RESULT_VARIABLE _rc)
ck(_rc EQUAL 0)
file(SHA256 "${_work}/payload.tar.gz" _h)

# v1 guard script: idempotent, addresses the tree by relative path (CWD = source)
file(WRITE "${_work}/mark1.cmake"
  "file(READ \"tpdemo.h\" _c)\nif(NOT _c MATCHES \"PATCHCMD-ONE\")\n  file(APPEND \"tpdemo.h\" \"// PATCHCMD-ONE\\n\")\nendif()\n")

polyorch_thirdparty_fetch(NAME payload URL "${_work}/payload.tar.gz" URL_HASH "SHA256=${_h}"
    PATCH_COMMAND "${CMAKE_COMMAND}" -P "${_work}/mark1.cmake"
    OUTPUT_DIR "${_work}/w" SOURCE_DIR_OUT _src)
ck_file("${_src}/tpdemo.h")
file(READ "${_src}/tpdemo.h" _h1)
string(FIND "${_h1}" "PATCHCMD-ONE" _p1)
ck(NOT _p1 EQUAL -1)
# idempotent re-run: same command text -> stamp hit, tree untouched
polyorch_thirdparty_fetch(NAME payload URL "${_work}/payload.tar.gz" URL_HASH "SHA256=${_h}"
    PATCH_COMMAND "${CMAKE_COMMAND}" -P "${_work}/mark1.cmake"
    OUTPUT_DIR "${_work}/w" SOURCE_DIR_OUT _src2)
ck_str("${_src2}" "${_src}")
file(READ "${_src}/tpdemo.h" _h2)
ck_str("${_h2}" "${_h1}")
string(REGEX MATCHALL "PATCHCMD-ONE" _m1 "${_h2}")
list(LENGTH _m1 _n1)
ck(_n1 EQUAL 1)

# command text is a stamp input: a DIFFERENT command re-extracts (pristine
# archive) and re-patches -- v1's marker is gone, v2's present
file(WRITE "${_work}/mark2.cmake"
  "file(APPEND \"tpdemo.h\" \"// PATCHCMD-TWO\\n\")\n")
polyorch_thirdparty_fetch(NAME payload URL "${_work}/payload.tar.gz" URL_HASH "SHA256=${_h}"
    PATCH_COMMAND "${CMAKE_COMMAND}" -P "${_work}/mark2.cmake"
    OUTPUT_DIR "${_work}/w" SOURCE_DIR_OUT _src3)
file(READ "${_src3}/tpdemo.h" _h3)
string(FIND "${_h3}" "PATCHCMD-TWO" _p2)
ck(NOT _p2 EQUAL -1)
string(FIND "${_h3}" "PATCHCMD-ONE" _p3)
ck(_p3 EQUAL -1)

message(STATUS "THIRD-PARTY-FETCH-PATCHCMD-OK")
