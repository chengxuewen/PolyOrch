# expect-log THIRD-PARTY-IMPORT-H2-OK
if(POLYORCH_CHILD)
    include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchThirdPartyHelpers.cmake")
    polyorch_thirdparty_import(NAME demo
        INSTALL_DIR "$ENV{TMPDIR}/tp-import-absent" FIND_PACKAGE_NAME tpdemo)
    message(FATAL_ERROR "unreachable: H2 forbids auto-building at import")
else()
    include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
    ck_child_fail("never auto-builds at import time")
    message(STATUS "THIRD-PARTY-IMPORT-H2-OK")
endif()
