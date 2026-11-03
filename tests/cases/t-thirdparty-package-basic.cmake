# expect-log THIRD-PARTY-PACKAGE-OK
# requires: cxx
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchThirdPartyHelpers.cmake")

polyorch_requires(cxx _ok)
if(NOT _ok)
    message(STATUS "t-thirdparty-package-basic : SKIP (no c++ toolchain on PATH or the pixi dirs)")
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
set(_work "$ENV{TMPDIR}/tp-pkg-basic")
file(REMOVE_RECURSE "${_work}")
file(COPY "${_fx}/payload/" DESTINATION "${_work}/pack/payload-1.2.3/")
execute_process(COMMAND "${CMAKE_COMMAND}" -E tar czf "${_work}/payload.tar.gz" payload-1.2.3
    WORKING_DIRECTORY "${_work}/pack" RESULT_VARIABLE _rc)
ck(_rc EQUAL 0)
file(SHA256 "${_work}/payload.tar.gz" _h)
file(WRITE "${_work}/recipe.json"
  "{\"schema_version\":1,\"name\":\"payload\",\"version\":\"1.2.3\",\"provider\":\"source\",\"license\":\"MIT\",\"url\":\"${_work}/payload.tar.gz\",\"url_hash\":\"${_h}\",\"link_mode\":\"static\",\"find_package\":{\"name\":\"tpdemo\",\"targets\":[\"tpdemo::tpdemo\"]},\"alias\":\"Demo::tpdemo\"}")

# 1) first run: build + pack (P2). Name/sidecar layout is the §2.4 contract.
polyorch_thirdparty_recipe(RECIPE "${_work}/recipe.json" WORK_DIR "${_work}/w"
    BUILD_TYPE Debug GENERATOR "${_tp_gen}" PARALLEL 2
    PACKAGES_DIR "${_work}/pkgs" PACKAGE_OUT _pkg
    FINGERPRINT_OUT _k INSTALL_DIR_OUT _i)
ck_file("${_pkg}")
string(LENGTH "${_k}" _klen)
ck(_klen EQUAL 64)
get_filename_component(_pkgn "${_pkg}" NAME)
string(SUBSTRING "${_k}" 0 12 _k12)
ck_str("${_pkgn}" "payload-1.2.3-none-none-Debug-static-${_k12}.tar.gz")
ck_file("${_pkg}.sha256")
ck_file("${_pkg}.manifest.json")
# the sha sidecar is the actual digest (bare-hex contract, oxmgr precedent)
file(SHA256 "${_pkg}" _actual)
file(READ "${_pkg}.sha256" _recorded)
string(STRIP "${_recorded}" _recorded)
ck_str("${_recorded}" "${_actual}")
# the manifest sidecar carries the identity the unpack verdict compares
file(READ "${_pkg}.manifest.json" _sm)
string(JSON _skey GET "${_sm}" key)
ck_str("${_skey}" "${_k}")

# 2) zero-build leg: wipe install prefix AND build tree, same key again ->
#    the package unpacks and build-Debug must NOT reappear
file(REMOVE_RECURSE "${_i}" "${_work}/w/payload/build-Debug")
polyorch_thirdparty_recipe(RECIPE "${_work}/recipe.json" WORK_DIR "${_work}/w"
    BUILD_TYPE Debug GENERATOR "${_tp_gen}" PARALLEL 2
    PACKAGES_DIR "${_work}/pkgs" PACKAGE_OUT _pkg2 INSTALL_DIR_OUT _i2)
ck_str("${_i2}" "${_i}")
ck(NOT EXISTS "${_work}/w/payload/build-Debug")
ck_file("${_i}/lib/cmake/tpdemo/tpdemoConfig.cmake")
ck_file("${_i}/polyorch-thirdparty-manifest.json")
ck_str("${_pkg2}" "${_pkg}")
# idempotent pack: exactly one archive in the cache
file(GLOB _archives "${_work}/pkgs/*.tar.gz")
list(LENGTH _archives _na)
ck(_na EQUAL 1)

# 3) key-change leg: a different profile is a different identity -> new
#    package name AND a real rebuild (the old package is not reused)
file(WRITE "${_work}/recipe.json"
  "{\"schema_version\":1,\"name\":\"payload\",\"version\":\"1.2.3\",\"provider\":\"source\",\"license\":\"MIT\",\"url\":\"${_work}/payload.tar.gz\",\"url_hash\":\"${_h}\",\"link_mode\":\"static\",\"profiles\":{\"dbg\":{\"TP_EXTRA\":\"1\"}},\"find_package\":{\"name\":\"tpdemo\",\"targets\":[\"tpdemo::tpdemo\"]},\"alias\":\"Demo::tpdemo\"}")
polyorch_thirdparty_recipe(RECIPE "${_work}/recipe.json" WORK_DIR "${_work}/w"
    BUILD_TYPE Debug PROFILE dbg GENERATOR "${_tp_gen}" PARALLEL 2
    PACKAGES_DIR "${_work}/pkgs" PACKAGE_OUT _pkg3 FINGERPRINT_OUT _k3)
ck(NOT _k3 STREQUAL _k)
ck(NOT _pkg3 STREQUAL _pkg)
ck_file("${_pkg3}")
ck(EXISTS "${_work}/w/payload/build-Debug")
file(GLOB _archives "${_work}/pkgs/*.tar.gz")
list(LENGTH _archives _na2)
ck(_na2 EQUAL 2)

message(STATUS "THIRD-PARTY-PACKAGE-OK")
