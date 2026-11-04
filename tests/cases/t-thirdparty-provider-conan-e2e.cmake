# e2e: required
# The P7b conan lane against the REAL conan center: one network generate, a
# relocation consumption proof, an offline reuse, a changed-island refusal.
# Nothing has to be prepared on the host: the lane solves its own tool island
# (pkg-deps/conan-tool, pinned by the committed lock) into the anchor.
if(TP_LEG)
    # the changed-island leg: the island bytes moved, so the key moved, and a
    # new key has no pre-baked artifact -- strict refuses (no implicit fetch)
    include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchThirdPartyHelpers.cmake")
    polyorch_thirdparty_recipe(RECIPE "$ENV{TP_E2E_RECIPE}"
        WORK_DIR "$ENV{TP_E2E_WORK}" BUILD_TYPE Release
        PACKAGES_DIR "$ENV{TP_E2E_PACKAGES}")
    message(FATAL_ERROR "unreachable: the changed-island leg must refuse")
else()
    include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
    include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchThirdPartyHelpers.cmake")

    # a compiler must be stated (script mode carries no CMAKE_CXX_* facts); the
    # lane would rather skip than guess one
    set(_cxx "$ENV{CXX}")
    if(NOT _cxx)
        # unset first: find_program refuses to search when the variable is
        # already set -- even to the empty string (a trap this round has
        # bitten before, so the guard is spelled out here).
        unset(_cxx)
        find_program(_cxx NAMES c++ g++ PATHS /usr/bin /usr/local/bin)
    endif()
    if(NOT _cxx OR NOT EXISTS "${_cxx}")
        message(STATUS "t-thirdparty-provider-conan-e2e : SKIP (no compiler to state the profile with -- set CXX)")
        return()
    endif()
    set(PolyOrch_CONAN_COMPILER "${_cxx}")
    # the pixi package cache goes to the anchor when the caller set nothing
    # (an unset one would land in $HOME: global state, and unwritable in a
    # sandbox -- measured)
    if(NOT DEFINED ENV{PIXI_CACHE_DIR} OR "$ENV{PIXI_CACHE_DIR}" STREQUAL "")
        set(_pc "$ENV{TMPDIR}/tp-conan-pxcache")   # outside _work: it is wiped below
        file(MAKE_DIRECTORY "${_pc}")
        set(ENV{PIXI_CACHE_DIR} "${_pc}")
    endif()

    set(_fx "${CMAKE_CURRENT_LIST_DIR}/../fixtures/thirdparty-ecosystem")
    set(_work "$ENV{TMPDIR}/tp-conan-e2e")
    file(REMOVE_RECURSE "${_work}")
    file(COPY "${_fx}/pkg-deps-fmt.recipe.json" DESTINATION "${_work}")
    file(COPY "${_fx}/pkg-deps-fmt" DESTINATION "${_work}")
    set(_recipe "${_work}/pkg-deps-fmt.recipe.json")
    set(_island "${_work}/pkg-deps-fmt")
    set(_w "${_work}/w")
    set(_cache "${_work}/packages")

    # the fixture recipe is written for the vcpkg lane; switching provider is
    # the ONLY edit here -- same file, same pin_dir, same island directory, now
    # resolved by conan. That is the M5 promise under test, not a description
    # of it: the island carries both manifests precisely so this one line is
    # enough (r9a H2).
    file(READ "${_recipe}" _rj)
    string(REGEX REPLACE "\"provider\"[ ]*:[ ]*\"vcpkg\"" "\"provider\": \"conan\"" _rj2 "${_rj}")
    ck(NOT _rj2 STREQUAL "${_rj}")
    file(WRITE "${_recipe}" "${_rj2}")

    # ---- 1. generate (the ONE network step) ----
    polyorch_thirdparty_recipe(RECIPE "${_recipe}" WORK_DIR "${_w}" BUILD_TYPE Release
        PACKAGES_DIR "${_cache}" GENERATE_ECOSYSTEM
        INSTALL_DIR_OUT _i FINGERPRINT_OUT _k MANIFEST_OUT _mf PACKAGE_OUT _pkg
        FIND_PACKAGE_NAME_OUT _fpn TARGETS_OUT _tgts ALIAS_OUT _al)
    ck_file("${_i}/direct_deploy/fmt/lib/libfmt.a")
    ck_file("${_i}/direct_deploy/fmt/include/fmt/base.h")
    ck_file("${_i}/fmt-config.cmake")
    # free provenance the lane keeps (L2): the deployed package trees carry the
    # package's own manifest and settings snapshot
    file(GLOB _cv "${_i}/direct_deploy/fmt/conanmanifest.txt")
    ck(_cv)
    # no host path may ride into the package's textual surfaces (the toolchain
    # file is the one artifact that would; it is deliberately neither emitted
    # nor copied). Binaries are NOT scanned here on purpose: an object file can
    # carry build-time paths that no consumer reads, and the relocatability
    # contract is about what find_package executes (same scope as F5's gate).
    file(GLOB_RECURSE _txts "${_i}/*.cmake" "${_i}/*.txt" "${_i}/*.json" "${_i}/*.pc")
    foreach(_f IN LISTS _txts)
        file(READ "${_f}" _b LIMIT 200000)
        if(_b MATCHES "$ENV{HOME}")
            message(FATAL_ERROR "relocate hazard: ${_f} pins the host home")
        endif()
    endforeach()
    # provenance fields
    file(READ "${_mf}" _j)
    string(JSON _v GET "${_j}" key)
    ck_str("${_v}" "${_k}")
    string(JSON _v GET "${_j}" provider)
    ck_str("${_v}" "conan")
    string(JSON _tv GET "${_j}" ecosystemtoolversion)
    ck(_tv MATCHES "^[0-9]+[.][0-9]+")
    string(JSON _pv GET "${_j}" ecosystemprofilesha256)
    string(LENGTH "${_pv}" _pvl)
    ck(_pvl EQUAL 64)
    string(JSON _tt GET "${_j}" ecosystemtriplet)
    ck_str("${_tt}" "polyorch-release")
    string(JSON _v GET "${_j}" license)
    ck_str("${_v}" "MIT")
    ck_str("${_fpn}" "fmt")
    ck_str("${_tgts}" "fmt::fmt")
    ck_str("${_al}" "Consumer::Fmt")
    ck_file("${_pkg}")
    ck_file("${_pkg}.sha256")
    ck_file("${_pkg}.manifest.json")
    # zero intrusion: the in-repo islands hold only their declared files
    file(GLOB _dirty "${_island}/*")
    list(LENGTH _dirty _nd)
    ck(_nd EQUAL 3)
    file(GLOB _ti "${_w}/conan-tool/pixi.toml")
    ck(_ti)

    # ---- 2. the relocation proof: copy the prefix elsewhere and consume it ----
    set(_moved "${_work}/moved")
    file(REMOVE_RECURSE "${_moved}")
    file(MAKE_DIRECTORY "${_moved}")
    execute_process(COMMAND "${CMAKE_COMMAND}" -E copy_directory "${_i}" "${_moved}/prefix"
        RESULT_VARIABLE _rc)
    ck(_rc EQUAL 0)
    set(_proj "${_work}/consume")
    file(MAKE_DIRECTORY "${_proj}")
    # prove consumption the way a consumer does it -- compile and run, do not
    # interrogate properties: conan's CMakeDeps models a static fmt as an
    # INTERFACE library carrying INTERFACE_LINK_LIBRARIES (measured: no
    # IMPORTED_LOCATION at all), so an attribute probe would test the wrong
    # shape while proving nothing about usability.
    file(WRITE "${_proj}/main.cpp"
"#include <fmt/core.h>
int main() { auto s = fmt::format(\"CONSUME-RAN {}\", 6 * 7); puts(s.c_str()); return 0; }
")
    file(WRITE "${_proj}/CMakeLists.txt"
"cmake_minimum_required(VERSION 3.20)
project(consume CXX)
find_package(fmt CONFIG REQUIRED PATHS \"${_moved}/prefix\" NO_DEFAULT_PATH)
add_executable(uses main.cpp)
target_link_libraries(uses PRIVATE fmt::fmt)
")
    execute_process(COMMAND "${CMAKE_COMMAND}" -S "${_proj}" -B "${_proj}/b"
            -DCMAKE_BUILD_TYPE=Release
        RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
    if(NOT _rc EQUAL 0)
        message(FATAL_ERROR "the relocated prefix must still configure:\n${_out}${_err}")
    endif()
    execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_proj}/b" --config Release
        RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
    if(NOT _rc EQUAL 0)
        message(FATAL_ERROR "linking against the relocated fmt must build:\n${_out}${_err}")
    endif()
    # run it: the fmt library actually executes out of the moved tree
    file(GLOB_RECURSE _exe "${_proj}/b/uses" "${_proj}/b/Release/uses.exe" "${_proj}/b/uses.exe")
    list(GET _exe 0 _exe0)
    execute_process(COMMAND "${_exe0}"
        RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
    if(NOT _rc EQUAL 0 OR NOT _out MATCHES "CONSUME-RAN 42")
        message(FATAL_ERROR "the relocated fmt must run (got rc=${_rc} out='${_out}' err='${_err}')")
    endif()

    # ---- 3. offline reuse: prefix, conan home and tool island all deleted ----
    file(REMOVE_RECURSE "${_i}" "${_w}/conan-home" "${_w}/conan-tool")
    polyorch_thirdparty_recipe(RECIPE "${_recipe}" WORK_DIR "${_w}" BUILD_TYPE Release
        PACKAGES_DIR "${_cache}"
        INSTALL_DIR_OUT _i2 FINGERPRINT_OUT _k2 MANIFEST_OUT _mf2)
    ck_str("${_k2}" "${_k}")
    ck_file("${_i2}/direct_deploy/fmt/lib/libfmt.a")
    ck(NOT EXISTS "${_w}/conan-home")    # no conan ran to rebuild it
    ck(NOT EXISTS "${_w}/conan-tool")    # and no tool was even solved

    # ---- 4. provider tags must not collide: the two lanes name their packs ----
    _polyorch_tp_package_name(_vn "pkg-deps-fmt" "11.0.2" "x64-linux-static" "" "Release" "static" "aaaaaaaaaaaa" "tar.gz")
    _polyorch_tp_package_name(_cn "pkg-deps-fmt" "11.0.2" "polyorch-release" "" "Release" "static" "aaaaaaaaaaaa" "tar.gz")
    ck(NOT _vn STREQUAL "${_cn}")
    if(NOT _cn MATCHES "polyorch-release")
        message(FATAL_ERROR "conan pack name lost its triplet-slot identity: ${_cn}")
    endif()

    # ---- 5. a changed island is a different library: strict refusal ----
    file(APPEND "${_island}/conan.lock" "\n")
    execute_process(COMMAND "${CMAKE_COMMAND}" -E env
            "TP_E2E_RECIPE=${_recipe}"
            "TP_E2E_WORK=${_w}/changed"
            "TP_E2E_PACKAGES=${_cache}"
            "${CMAKE_COMMAND}" "-DTP_LEG=changed-island"
            # -D, not -E env: the lane reads CMake variables here (a cache
            # entry reaches the child), and an exported env var would be read
            # as "$ENV{...}" by nobody -- the leg would die on the profile
            # guard instead of the strict gate it is meant to exercise.
            "-DPolyOrch_CONAN_COMPILER=${_cxx}"
            -P "${CMAKE_CURRENT_LIST_FILE}"
        RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
    set(_txt "${_out}${_err}")
    if(_rc EQUAL 0)
        message(FATAL_ERROR "changed-island leg exited 0 -- expected strict refusal")
    endif()
    if(NOT _txt MATCHES "strict-first")
        message(FATAL_ERROR "changed-island leg wording missing:\n${_txt}")
    endif()

    message(STATUS "THIRD-PARTY-PROVIDER-CONAN-E2E-OK")
endif()
