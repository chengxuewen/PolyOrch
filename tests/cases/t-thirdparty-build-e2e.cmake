# expect-log THIRD-PARTY-BUILD-OK
# requires: cxx
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchThirdPartyHelpers.cmake")

polyorch_requires(cxx _ok)
if(NOT _ok)
    message(STATUS "t-thirdparty-build-e2e : SKIP (no c++ toolchain on PATH or the pixi dirs)")
    return()
endif()
find_program(_tp_cxx NAMES c++ g++ clang++ cl)
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
set(_work "$ENV{TMPDIR}/tp-build")
file(REMOVE_RECURSE "${_work}")
file(COPY "${_fx}/payload/" DESTINATION "${_work}/pack/payload-1.2.3/")
execute_process(COMMAND "${CMAKE_COMMAND}" -E tar czf "${_work}/payload.tar.gz" payload-1.2.3
    WORKING_DIRECTORY "${_work}/pack" RESULT_VARIABLE _rc)
ck(_rc EQUAL 0)
file(SHA256 "${_work}/payload.tar.gz" _h)

polyorch_thirdparty_fetch(NAME payload URL "${_work}/payload.tar.gz"
    URL_HASH "SHA256=${_h}" OUTPUT_DIR "${_work}/3rd"
    SOURCE_DIR_OUT _src ARCHIVE_SHA256_OUT _ah)

# the explicit verb: a fully separate CMake invocation, never a configure-
# time side effect (H2)
polyorch_thirdparty_build(NAME payload SOURCE_DIR "${_src}"
    BUILD_DIR "${_work}/b" INSTALL_DIR "${_work}/i" BUILD_TYPE Debug
    GENERATOR "${_tp_gen}" CMAKE_ARGS -DCMAKE_CXX_COMPILER=${_tp_cxx})

# install layout: static lib + header + the upstream's own config package
file(GLOB _tp_lib "${_work}/i/lib/libtpdemo.*")
ck(_tp_lib)
ck_file("${_work}/i/include/tpdemo.h")
ck_file("${_work}/i/lib/cmake/tpdemo/tpdemoConfig.cmake")
ck_file("${_work}/i/lib/cmake/tpdemo/tpdemoTargets.cmake")
# fail-loud logs land where the header comment promises
ck_file("${_work}/b/polyorch-thirdparty-payload-configure.log")
ck_file("${_work}/b/polyorch-thirdparty-payload-build.log")
ck_file("${_work}/b/polyorch-thirdparty-payload-install.log")

message(STATUS "THIRD-PARTY-BUILD-OK")
