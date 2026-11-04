# e2e: required
# The P7a vcpkg lane against the REAL registry: one network generate, then
# an offline reuse, then a changed-island refusal. Nothing has to be prepared
# on the host: the lane clones the registry at the pinned baseline and
# bootstraps the tool into that anchor-local root (the release tag+sha the
# baseline names fixes the tool, so this adds no drift). VCPKG_PROGRAM is
# optional -- pass it to exercise the explicit-tool rung instead.
#   POLYORCH_TEST_E2E=1 ./run.sh
if(TP_LEG)
    # the changed-island leg: same recipe, a mutated island -- a new pin hash
    # is a new library, and a new library has no pre-baked artifact
    include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchThirdPartyHelpers.cmake")
    polyorch_thirdparty_recipe(RECIPE "$ENV{TP_E2E_RECIPE}"
        WORK_DIR "$ENV{TP_E2E_WORK}" BUILD_TYPE Release
        PACKAGES_DIR "$ENV{TP_E2E_PACKAGES}")
    message(FATAL_ERROR "unreachable: the changed-island leg must refuse")
else()
    include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
    include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchThirdPartyHelpers.cmake")

    if(NOT DEFINED ENV{VCPKG_PROGRAM} OR "$ENV{VCPKG_PROGRAM}" STREQUAL "")
        message(STATUS "polyorch e2e: no VCPKG_PROGRAM -- the lane bootstraps the tool into the anchor (first run downloads it)")
    else()
        if(NOT EXISTS "$ENV{VCPKG_PROGRAM}")
            message(FATAL_ERROR "VCPKG_PROGRAM '$ENV{VCPKG_PROGRAM}' does not exist")
        endif()
    endif()
    find_program(_tp_git NAMES git)
    if(NOT _tp_git)
        message(STATUS "t-thirdparty-provider-vcpkg-e2e : SKIP (no git -- the registry root is a checkout at the pinned baseline)")
        return()
    endif()

    set(_fx "${CMAKE_CURRENT_LIST_DIR}/../fixtures/thirdparty-ecosystem")
    set(_work "$ENV{TMPDIR}/tp-eco-e2e")
    file(REMOVE_RECURSE "${_work}")
    file(COPY "${_fx}/pkg-deps-fmt.recipe.json" DESTINATION "${_work}")
    file(COPY "${_fx}/pkg-deps-fmt" DESTINATION "${_work}")

    set(_w "${_work}/w")
    set(_cache "${_work}/packages")
    set(_island "${_work}/pkg-deps-fmt")

    # ---- 1. generate (the ONE network step) ----
    polyorch_thirdparty_recipe(RECIPE "${_work}/pkg-deps-fmt.recipe.json"
        WORK_DIR "${_w}" BUILD_TYPE Release
        PACKAGES_DIR "${_cache}" GENERATE_ECOSYSTEM
        VCPKG_PROGRAM "$ENV{VCPKG_PROGRAM}" VCPKG_ROOT_DIR "${_w}/registry"
        INSTALL_DIR_OUT _i FINGERPRINT_OUT _k MANIFEST_OUT _mf PACKAGE_OUT _pkg
        FIND_PACKAGE_NAME_OUT _fpn TARGETS_OUT _tgts ALIAS_OUT _al)
    ck_file("${_i}/include/fmt/base.h")
    if(NOT EXISTS "${_i}/lib/libfmt.a")
        file(GLOB _libs "${_i}/lib/*.a" "${_i}/lib/*.so*")
        message(FATAL_ERROR "static triplet produced no libfmt.a; lib/ holds: ${_libs}")
    endif()
    # the prefix must carry a CONFIG for the import verb (F7=A consumes the
    # upstream config; this is exactly why zlib was swapped out -- its port
    # ships only a vcpkg wrapper plus the built-in FindZLIB module)
    ck_file("${_i}/share/fmt/fmt-config.cmake")
    # zero intrusion: the island the recipe points at is a read-only input
    # (manifest-mode install would write vcpkg_installed/ right into it)
    file(GLOB _dirty "${_island}/*")
    ck_str("${_dirty}" "${_island}/vcpkg.json")
    file(GLOB _dirty2 "${_fx}/pkg-deps-fmt/*")
    ck_str("${_dirty2}" "${_fx}/pkg-deps-fmt/vcpkg.json")
    # provenance: provider axis records vcpkg + the island hash + the triplet
    file(READ "${_mf}" _j)
    string(JSON _v GET "${_j}" key)
    ck_str("${_v}" "${_k}")
    string(JSON _v GET "${_j}" provider)
    ck_str("${_v}" "vcpkg")
    string(JSON _v GET "${_j}" ecosystempinsha256)
    string(LENGTH "${_v}" _vl)
    ck(_vl EQUAL 64)
    string(JSON _v GET "${_j}" ecosystemtriplet)
    ck(_v MATCHES "^(x64|arm64)-linux-static$")
    set(_eco_t "${_v}")
    string(JSON _v GET "${_j}" triplet)
    ck_str("${_v}" "${_eco_t}")   # manifest triplet = the supplier triplet
    string(JSON _v GET "${_j}" license)
    ck_str("${_v}" "MIT")
    ck_str("${_fpn}" "fmt")
    ck_str("${_tgts}" "fmt::fmt")
    ck_str("${_al}" "Consumer::Fmt")
    # the pack + its provenance sidecars
    ck_file("${_pkg}")
    ck_file("${_pkg}.sha256")
    ck_file("${_pkg}.manifest.json")
    file(SHA256 "${_pkg}" _actual)
    file(READ "${_pkg}.sha256" _recorded)
    string(STRIP "${_recorded}" _recorded)
    ck_str("${_actual}" "${_recorded}")

    # ---- 2. offline reuse: install dir AND registry root gone, no
    # GENERATE_ECOSYSTEM -- the package cache alone must reconstruct ----
    file(REMOVE_RECURSE "${_i}" "${_w}/registry" "${_w}/vcpkg-downloads")
    polyorch_thirdparty_recipe(RECIPE "${_work}/pkg-deps-fmt.recipe.json"
        WORK_DIR "${_w}" BUILD_TYPE Release
        PACKAGES_DIR "${_cache}"
        INSTALL_DIR_OUT _i2 FINGERPRINT_OUT _k2 MANIFEST_OUT _mf2)
    ck_str("${_k2}" "${_k}")            # same island, same key
    ck_file("${_i2}/include/fmt/base.h") # the prefix is back
    ck(NOT EXISTS "${_w}/registry")      # and NO vcpkg ran to rebuild it
    file(READ "${_mf2}" _j2)
    string(JSON _v GET "${_j2}" key)
    ck_str("${_v}" "${_k}")

    # ---- 3. a changed island is a different library: strict refusal ----
    # (child process -- the refusal is a FATAL)
    file(APPEND "${_island}/vcpkg.json" "\n")
    execute_process(COMMAND "${CMAKE_COMMAND}" -E env
            "TP_E2E_RECIPE=${_work}/pkg-deps-fmt.recipe.json"
            "TP_E2E_WORK=${_w}/changed"
            "TP_E2E_PACKAGES=${_cache}"
            "${CMAKE_COMMAND}" "-DTP_LEG=changed-island" -P "${CMAKE_CURRENT_LIST_FILE}"
        RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
    set(_txt "${_out}${_err}")
    string(REPLACE "\n" " " _txt "${_txt}")
    if(_rc EQUAL 0)
        message(FATAL_ERROR "changed-island leg exited 0 -- expected strict refusal")
    endif()
    if(NOT _txt MATCHES "strict-first")
        message(FATAL_ERROR "changed-island leg wording missing:\n${_txt}")
    endif()

    message(STATUS "THIRD-PARTY-PROVIDER-VCPKG-E2E-OK")
endif()
