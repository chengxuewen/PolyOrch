# expect-log THIRD-PARTY-PACKAGE-RELOCATE-OK
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchThirdPartyHelpers.cmake")

set(_work "$ENV{TMPDIR}/tp-pkg-reloc")
file(REMOVE_RECURSE "${_work}")
string(RANDOM LENGTH 64 ALPHABET 1 RANDOM_SEED 11 _k64)
file(MAKE_DIRECTORY "${_work}/inst/lib/cmake/foo")
polyorch_thirdparty_manifest_write(MANIFEST "${_work}/inst/polyorch-thirdparty-manifest.json"
    KEY "${_k64}" NAME foo VERSION 1.0 LICENSE MIT BUILD_TYPE Debug)
# the bad surface pins the build-host install path
file(WRITE "${_work}/inst/lib/cmake/foo/fooConfig.cmake" "set(FOO_LIB_DIR \"${_work}/inst/lib\")\n")

if(POLYORCH_CHILD)
    include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchThirdPartyHelpers.cmake")
    polyorch_thirdparty_package(NAME foo INSTALL_DIR "${_work}/inst" PACKAGE_DIR "${_work}/pkgs")
    message(FATAL_ERROR "unreachable: the relocate gate must fire first")
else()
    # direction 1: absolute-path-pinned prefix is refused
    ck_child_fail("not relocatable")
    # direction 2: the relativized twin packs (F5 criterion 10, both ways)
    file(WRITE "${_work}/inst/lib/cmake/foo/fooConfig.cmake" "set(FOO_LIB_DIR \"\${CMAKE_CURRENT_LIST_DIR}/../../lib\")\n")
    polyorch_thirdparty_package(NAME foo INSTALL_DIR "${_work}/inst" PACKAGE_DIR "${_work}/pkgs" PACKAGE_OUT _p)
    ck_file("${_p}")
    ck_file("${_p}.sha256")
    string(SUBSTRING "${_k64}" 0 12 _k12)
    get_filename_component(_pn "${_p}" NAME)
    ck_str("${_pn}" "foo-1.0-none-none-Debug-none-${_k12}.tar.gz")
    message(STATUS "THIRD-PARTY-PACKAGE-RELOCATE-OK")
endif()
