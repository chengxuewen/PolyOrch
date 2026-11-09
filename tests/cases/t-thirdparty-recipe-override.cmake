# expect-log artifact from override dir
# B8 acquisition resolution, leg 1: LOCAL_ARCHIVE_DIR. The recipe's url is a
# bare filename resolved against RECIPE_BASE (= the recipe's dir) where the
# archive does NOT exist (the archive layer moved out of the recipe tree), so
# the override dir is the only live source. The loader resolves it, announces
# it on STATUS and hands fetch the override path. fetch_only keeps this off
# the toolchain (the F8 wrapper shape -- ImGui rides exactly this).
# The strict refusal that guards the leg (nothing anywhere) runs as a child
# re-exec below.
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchThirdPartyHelpers.cmake")

set(_work "$ENV{TMPDIR}/tp-override")
file(REMOVE_RECURSE "${_work}")
file(COPY "${CMAKE_CURRENT_LIST_DIR}/../fixtures/thirdparty-basic/payload/" DESTINATION "${_work}/pack/payload-1.2.3/")
file(MAKE_DIRECTORY "${_work}/override")
execute_process(COMMAND "${CMAKE_COMMAND}" -E tar czf "${_work}/override/payload.tar.gz" payload-1.2.3
    WORKING_DIRECTORY "${_work}/pack" RESULT_VARIABLE _rc)
ck(_rc EQUAL 0)
file(SHA256 "${_work}/override/payload.tar.gz" _h)

file(WRITE "${_work}/recipe.json"
  "{\"schema_version\":1,\"name\":\"payload\",\"version\":\"1.2.3\",\"provider\":\"source\",\"license\":\"MIT\",\"url\":\"payload.tar.gz\",\"url_hash\":\"${_h}\",\"fetch_only\":true}")

polyorch_thirdparty_recipe(RECIPE "${_work}/recipe.json" WORK_DIR "${_work}/w"
    BUILD_TYPE Debug LOCAL_ARCHIVE_DIR "${_work}/override"
    SOURCE_DIR_OUT _sd)
ck_file("${_sd}/CMakeLists.txt")
message(STATUS "THIRD-PARTY-OVERRIDE-OK")

# ---- strict refusal (child re-exec): recipe url missing, no override, no
# url_online, DOWNLOAD not passed -> the loader must FATAL naming every
# missed exit instead of falling through anywhere.
if(NOT POLYORCH_CHILD)
    ck_child_fail("no cached[ ]+download[ ]+and[ ]+no[ ]+url_online")
    message(STATUS "THIRD-PARTY-OVERRIDE-GUARDS-OK")
    return()
endif()
polyorch_thirdparty_recipe(RECIPE "${_work}/recipe.json" WORK_DIR "${_work}/w2"
    BUILD_TYPE Debug SOURCE_DIR_OUT _x)
message(FATAL_ERROR "unreachable: the no-source refusal must fire")
