# expect-log THIRD-PARTY-HALFGROUP-OK
if(POLYORCH_CHILD)
    include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchThirdPartyHelpers.cmake")
    # TOOLCHAIN_FILE without the explicit compiler pair in CMAKE_ARGS must be
    # refused BEFORE anything spawns: a half-forwarded cross group silently
    # builds with the host toolchain (H3). The payload fixture is a real
    # CMake-shaped source tree, so this reaches exactly the guard under test.
    polyorch_thirdparty_build(NAME x
        SOURCE_DIR "${CMAKE_CURRENT_LIST_DIR}/../fixtures/thirdparty-basic/payload"
        BUILD_DIR "$ENV{TMPDIR}/tp-hg-b" INSTALL_DIR "$ENV{TMPDIR}/tp-hg-i"
        BUILD_TYPE Debug TOOLCHAIN_FILE "/nonexistent/toolchain.cmake")
    message(FATAL_ERROR "unreachable: the half-group guard must refuse")
else()
    include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
    ck_child_fail("half-forwarded cross group")
    message(STATUS "THIRD-PARTY-HALFGROUP-OK")
endif()
