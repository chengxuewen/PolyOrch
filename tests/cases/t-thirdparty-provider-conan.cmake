# expect-log THIRD-PARTY-PROVIDER-CONAN-OK
# The P7b conan lane's offline gates. Nothing here talks to conan center: the
# refusal legs fire before any tool is needed, the generate leg is the separate
# e2e case (t-thirdparty-provider-conan-e2e.cmake).
if(TP_LEG)
    # self-lock (the D48 lesson): the child dispatches on TP_LEG and dies in
    # the guard under test -- it never spawns further children
    include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchThirdPartyHelpers.cmake")
    set(_h "1111111111111111111111111111111111111111111111111111111111111111")
    set(_isl "$ENV{TMPDIR}/tp-ccon-island")
    file(REMOVE_RECURSE "${_isl}")
    file(MAKE_DIRECTORY "${_isl}")
    set(_rec "$ENV{TMPDIR}/tp-ccon.json")
    set(_eco "{\"schema_version\":1,\"name\":\"x\",\"version\":\"1\",\"provider\":\"conan\",\"license\":\"MIT\",\"pin_dir\":\"${_isl}\"}")
    set(_cok "[requires]\nfmt/11.0.2\n")
    set(_lk50 "{\"version\":\"0.5\",\"requires\":[]}\n")
    # the compiler has to be stated: script mode carries no CMAKE_CXX_COMPILER_*
    # facts, and a lane that guessed one would key artifacts on a toolchain
    # nobody chose (O-12=C).
    set(PolyOrch_CONAN_COMPILER "/usr/bin/c++")

    if(TP_LEG STREQUAL "strict")
        file(WRITE "${_isl}/conanfile.txt" "${_cok}")
        file(WRITE "${_isl}/conan.lock" "{\"version\":\"0.5\",\"requires\":[\"fmt/11.0.2#${_h}%1.0\"],\"build_requires\":[],\"python_requires\":[],\"config_requires\":[]}\n")
        file(WRITE "${_rec}" "${_eco}")
        polyorch_thirdparty_recipe(RECIPE "${_rec}"
            WORK_DIR "$ENV{TMPDIR}/tp-ccon-w" BUILD_TYPE Release)
    elseif(TP_LEG STREQUAL "no-compiler")
        unset(PolyOrch_CONAN_COMPILER)
        file(WRITE "${_isl}/conanfile.txt" "${_cok}")
        file(WRITE "${_isl}/conan.lock" "${_lk50}")
        file(WRITE "${_rec}" "${_eco}")
        polyorch_thirdparty_recipe(RECIPE "${_rec}"
            WORK_DIR "$ENV{TMPDIR}/tp-ccon-w" BUILD_TYPE Release)
    elseif(TP_LEG STREQUAL "badarch")
        set(CMAKE_HOST_SYSTEM_PROCESSOR "sparc")
        file(WRITE "${_isl}/conanfile.txt" "${_cok}")
        file(WRITE "${_isl}/conan.lock" "${_lk50}")
        file(WRITE "${_rec}" "${_eco}")
        polyorch_thirdparty_recipe(RECIPE "${_rec}"
            WORK_DIR "$ENV{TMPDIR}/tp-ccon-w" BUILD_TYPE Release)
    elseif(TP_LEG STREQUAL "mac-libcxx")
        # macOS needs an explicit libcxx: the lane will not assume libc++ over
        # libstdc++ for a caller it cannot see
        set(CMAKE_HOST_SYSTEM_NAME "Darwin")
        set(PolyOrch_CONAN_COMPILER_ID "clang")
        set(PolyOrch_CONAN_COMPILER_VERSION "15")
        file(WRITE "${_isl}/conanfile.txt" "${_cok}")
        file(WRITE "${_isl}/conan.lock" "${_lk50}")
        file(WRITE "${_rec}" "${_eco}")
        polyorch_thirdparty_recipe(RECIPE "${_rec}"
            WORK_DIR "$ENV{TMPDIR}/tp-ccon-w" BUILD_TYPE Release)
    elseif(TP_LEG STREQUAL "o13")
        file(WRITE "${_isl}/conanfile.txt" "${_cok}")
        file(WRITE "${_isl}/conan.lock" "${_lk50}")
        file(WRITE "${_rec}"
  "{\"schema_version\":1,\"name\":\"x\",\"version\":\"1\",\"provider\":\"conan\",\"license\":\"MIT\",\"pin_dir\":\"${_isl}\",\"patches\":[{\"path\":\"/nonexistent.patch\",\"sha256\":\"${_h}\"}]}")
        polyorch_thirdparty_recipe(RECIPE "${_rec}"
            WORK_DIR "$ENV{TMPDIR}/tp-ccon-w" BUILD_TYPE Release)
    elseif(TP_LEG STREQUAL "profile-knob")
        file(WRITE "${_isl}/conanfile.txt" "${_cok}")
        file(WRITE "${_isl}/conan.lock" "${_lk50}")
        file(WRITE "${_rec}" "${_eco}")
        polyorch_thirdparty_recipe(RECIPE "${_rec}"
            WORK_DIR "$ENV{TMPDIR}/tp-ccon-w" BUILD_TYPE Release PROFILE release)
    elseif(TP_LEG STREQUAL "lock-missing")
        # a conan island without its lock has no pin at all
        file(WRITE "${_isl}/conanfile.txt" "${_cok}")
        file(WRITE "${_rec}" "${_eco}")
        polyorch_thirdparty_recipe(RECIPE "${_rec}"
            WORK_DIR "$ENV{TMPDIR}/tp-ccon-w" BUILD_TYPE Release)
    elseif(TP_LEG STREQUAL "island-missing")
        file(WRITE "${_rec}"
  "{\"schema_version\":1,\"name\":\"x\",\"version\":\"1\",\"provider\":\"conan\",\"license\":\"MIT\",\"pin_dir\":\"$ENV{TMPDIR}/tp-ccon-nowhere\"}")
        polyorch_thirdparty_recipe(RECIPE "${_rec}"
            WORK_DIR "$ENV{TMPDIR}/tp-ccon-w" BUILD_TYPE Release)
    elseif(TP_LEG STREQUAL "license-drift")
        file(WRITE "${_isl}/conanfile.py" "from conan import ConanFile\nclass X(ConanFile):\n    name = \"x\"\n    license = \"GPL-2.0-only\"\n")
        file(WRITE "${_isl}/conan.lock" "${_lk50}")
        file(WRITE "${_rec}" "${_eco}")
        polyorch_thirdparty_recipe(RECIPE "${_rec}"
            WORK_DIR "$ENV{TMPDIR}/tp-ccon-w" BUILD_TYPE Release)
    elseif(TP_LEG STREQUAL "tool-mismatch")
        # a conan reporting another version than the island pins must refuse
        # before it produces anything the key would misdescribe
        file(WRITE "$ENV{TMPDIR}/fake-conan.sh" "#!/bin/sh\necho 'Conan version 9.9.9'\n")
        # file(WRITE) creates the script non-executable; without the bit the
        # leg would fail as "no parsable version" and prove nothing about the
        # mismatch guard it is meant to exercise.
        execute_process(COMMAND chmod 755 "$ENV{TMPDIR}/fake-conan.sh")
        file(WRITE "${_isl}/conanfile.txt" "${_cok}")
        file(WRITE "${_isl}/conan.lock" "${_lk50}")
        file(WRITE "${_rec}" "${_eco}")
        polyorch_thirdparty_recipe(RECIPE "${_rec}"
            WORK_DIR "$ENV{TMPDIR}/tp-ccon-w" BUILD_TYPE Release
            GENERATE_ECOSYSTEM CONAN_PROGRAM "$ENV{TMPDIR}/fake-conan.sh")
    elseif(TP_LEG STREQUAL "no-bootstrap")
        file(WRITE "${_isl}/conanfile.txt" "${_cok}")
        file(WRITE "${_isl}/conan.lock" "${_lk50}")
        file(WRITE "${_rec}" "${_eco}")
        polyorch_thirdparty_recipe(RECIPE "${_rec}"
            WORK_DIR "$ENV{TMPDIR}/tp-ccon-nb" BUILD_TYPE Release
            GENERATE_ECOSYSTEM BOOTSTRAP_TOOL off)
    elseif(TP_LEG STREQUAL "knob-badval")
        file(WRITE "${_isl}/conanfile.txt" "${_cok}")
        file(WRITE "${_isl}/conan.lock" "${_lk50}")
        file(WRITE "${_rec}" "${_eco}")
        polyorch_thirdparty_recipe(RECIPE "${_rec}"
            WORK_DIR "$ENV{TMPDIR}/tp-ccon-w" BUILD_TYPE Release BOOTSTRAP_TOOL perhaps)
    elseif(TP_LEG STREQUAL "fetchonly-eco")
        file(WRITE "${_isl}/conanfile.txt" "${_cok}")
        file(WRITE "${_isl}/conan.lock" "${_lk50}")
        file(WRITE "${_rec}"
  "{\"schema_version\":1,\"name\":\"x\",\"version\":\"1\",\"provider\":\"conan\",\"license\":\"MIT\",\"pin_dir\":\"${_isl}\",\"fetch_only\":true}")
        polyorch_thirdparty_recipe(RECIPE "${_rec}"
            WORK_DIR "$ENV{TMPDIR}/tp-ccon-w" BUILD_TYPE Release)
    endif()
    message(FATAL_ERROR "unreachable: leg ${TP_LEG} must refuse")
else()
    include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
    include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchThirdPartyHelpers.cmake")
    set(_h "1111111111111111111111111111111111111111111111111111111111111111")

    set(_legs strict no-compiler badarch mac-libcxx o13 profile-knob
        lock-missing island-missing license-drift tool-mismatch no-bootstrap
        knob-badval fetchonly-eco)
    foreach(_leg IN LISTS _legs)
        execute_process(COMMAND "${CMAKE_COMMAND}" "-DTP_LEG=${_leg}" -P "${CMAKE_CURRENT_LIST_FILE}"
            RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
        set(_txt "${_out}${_err}")
        string(REPLACE "\n" " " _txt "${_txt}")
        while(_txt MATCHES "  ")
            string(REPLACE "  " " " _txt "${_txt}")
        endwhile()
        if(_rc EQUAL 0)
            message(FATAL_ERROR "leg '${_leg}' exited 0 -- expected a refusal")
        endif()
        if(_leg STREQUAL "strict")
            # the manual must name conan's own tool, env and command, and must
            # not hand out a vcpkg recipe for a conan miss
            foreach(_w IN ITEMS "strict-first" "CONAN_HOME=" "--deployer=direct_deploy"
                    "-pr=" "--build=missing" "CONAN_PROGRAM" "BOOTSTRAP_TOOL"
                    "GENERATE_ECOSYSTEM" "no auto-fallback" "provider .source.")
                if(NOT _txt MATCHES "${_w}")
                    message(FATAL_ERROR "strict leg wording '${_w}' missing:\n${_txt}")
                endif()
            endforeach()
            if(_txt MATCHES "VCPKG_BINARY_SOURCES")
                message(FATAL_ERROR "conan strict leg printed the vcpkg env:\n${_txt}")
            endif()
        elseif(_leg STREQUAL "no-compiler")
            if(NOT _txt MATCHES "no compiler to derive the profile from")
                message(FATAL_ERROR "no-compiler leg wording missing:\n${_txt}")
            endif()
        elseif(_leg STREQUAL "badarch")
            if(NOT _txt MATCHES "cannot map processor")
                message(FATAL_ERROR "badarch leg wording missing:\n${_txt}")
            endif()
        elseif(_leg STREQUAL "mac-libcxx")
            if(NOT _txt MATCHES "compiler.libcxx is required for clang on Mac")
                message(FATAL_ERROR "mac-libcxx leg wording missing:\n${_txt}")
            endif()
        elseif(_leg STREQUAL "o13")
            if(NOT _txt MATCHES "O-13")
                message(FATAL_ERROR "o13 leg wording missing:\n${_txt}")
            endif()
        elseif(_leg STREQUAL "profile-knob")
            # conan DOES have a profile -- the wording must say it is generated,
            # not borrow the source-lane sentence (r9a M4)
            if(NOT _txt MATCHES "GENERATES the profile")
                message(FATAL_ERROR "profile-knob leg wording missing:\n${_txt}")
            endif()
            if(_txt MATCHES "source-lane concept")
                message(FATAL_ERROR "profile-knob leg used the vcpkg wording:\n${_txt}")
            endif()
        elseif(_leg STREQUAL "lock-missing")
            if(NOT _txt MATCHES "misses .conan\.lock.")
                message(FATAL_ERROR "lock-missing leg wording missing:\n${_txt}")
            endif()
        elseif(_leg STREQUAL "island-missing")
            if(NOT _txt MATCHES "pin island")
                message(FATAL_ERROR "island-missing leg wording missing:\n${_txt}")
            endif()
        elseif(_leg STREQUAL "license-drift")
            if(NOT _txt MATCHES "license drift")
                message(FATAL_ERROR "license-drift leg wording missing:\n${_txt}")
            endif()
        elseif(_leg STREQUAL "tool-mismatch")
            if(NOT _txt MATCHES "conan tool mismatch")
                message(FATAL_ERROR "tool-mismatch leg wording missing:\n${_txt}")
            endif()
        elseif(_leg STREQUAL "no-bootstrap")
            if(NOT _txt MATCHES "BOOTSTRAP_TOOL is off")
                message(FATAL_ERROR "no-bootstrap leg wording missing:\n${_txt}")
            endif()
        elseif(_leg STREQUAL "knob-badval")
            if(NOT _txt MATCHES "BOOTSTRAP_TOOL must be on.off")
                message(FATAL_ERROR "knob-badval leg wording missing:\n${_txt}")
            endif()
        elseif(_leg STREQUAL "fetchonly-eco")
            if(NOT _txt MATCHES "fetch_only is a source-lane concept")
                message(FATAL_ERROR "fetchonly-eco leg wording missing:\n${_txt}")
            endif()
        endif()
    endforeach()

    # ---- profile generator, inline ----
    set(_pw "$ENV{TMPDIR}/tp-ccon-prof")
    file(REMOVE_RECURSE "${_pw}")
    set(PolyOrch_CONAN_COMPILER "/usr/bin/c++")
    unset(PolyOrch_CONAN_CPPSTD)
    _polyorch_tp_conan_profile(_pf _pn _ph "${_pw}" "Release")
    ck_file("${_pf}")
    file(READ "${_pf}" _pc)
    # conan's own vocabulary, the field set a working profile needs. NOTE the
    # (^|\n) groups: in CMake MATCHES, ^ anchors the WHOLE string, not a line
    # (POSIX BRE, no multiline flag) -- "^os=" would never match past the
    # [settings] header line (measured).
    foreach(_f IN ITEMS "os=" "arch=" "build_type=Release" "compiler="
            "compiler.version=" "compiler.libcxx=")
        if(NOT _pc MATCHES "(^|\n)${_f}")
            message(FATAL_ERROR "profile field '${_f}' missing from:\n${_pc}")
        endif()
    endforeach()
    string(FIND "${_pc}" "cppstd" _cppf)
    ck(_cppf EQUAL -1)              # absent means "compiler default", not our guess
    ck_str("${_pn}" "polyorch-release")
    # stable for equal facts, different for changed facts (it rides the key)
    _polyorch_tp_conan_profile(_pf2 _pn2 _ph2 "${_pw}" "Release")
    ck_str("${_ph2}" "${_ph}")
    set(PolyOrch_CONAN_CPPSTD "gnu17")
    _polyorch_tp_conan_profile(_pf3 _pn3 _ph3 "${_pw}" "Release")
    ck(NOT _ph3 STREQUAL "${_ph}")
    _polyorch_tp_conan_profile(_pf4 _pn4 _ph4 "${_pw}" "Debug")
    ck(NOT _ph4 STREQUAL "${_ph3}")
    ck(NOT _pn4 STREQUAL "${_pn3}")   # the name carries the config: no collisions

    # ---- tool pin: the VERSION rides the key, the lock's host bytes do not ----
    _polyorch_tp_module_dir(_repo)
    ck_file("${_repo}/pkg-deps/conan-tool/pixi.lock")
    _polyorch_tp_conan_pinned_version(_pv)
    ck(_pv MATCHES "^[0-9]+[.][0-9]+")
    # criterion 16's anti-host-binding proof: mutate ONLY the virtual packages
    # in a copy of the tool island and the resolved version must stand --
    # otherwise every machine would mint its own key for the same artifact
    set(_prb "$ENV{TMPDIR}/tp-ccon-root")
    file(REMOVE_RECURSE "${_prb}")
    file(MAKE_DIRECTORY "${_prb}/pkg-deps/conan-tool")
    file(READ "${_repo}/pkg-deps/conan-tool/pixi.lock" _lk)
    string(REGEX REPLACE "__glibc=[0-9.]+" "__glibc=99.99" _lk2 "${_lk}")
    ck(NOT _lk2 STREQUAL "${_lk}")       # the mutation really landed
    file(WRITE "${_prb}/pkg-deps/conan-tool/pixi.lock" "${_lk2}")
    file(READ "${_repo}/pkg-deps/conan-tool/pixi.toml" _tm)
    file(WRITE "${_prb}/pkg-deps/conan-tool/pixi.toml" "${_tm}")
    set(PolyOrch_THIRDPARTY_ROOT "${_prb}")
    _polyorch_tp_conan_pinned_version(_pv2)
    ck_str("${_pv2}" "${_pv}")
    unset(PolyOrch_THIRDPARTY_ROOT)

    # ---- one island, two providers: switching lanes must not cross-pin ----
    set(_isl2 "${CMAKE_CURRENT_LIST_DIR}/../fixtures/thirdparty-ecosystem/pkg-deps-fmt")
    _polyorch_tp_pin_hash("${_isl2}" vcpkg _hv)
    _polyorch_tp_pin_hash("${_isl2}" conan _hc)
    ck(NOT _hv STREQUAL "${_hc}")        # each lane reads its own manifest
    set(_tmpisl "$ENV{TMPDIR}/tp-ccon-shared")
    file(REMOVE_RECURSE "${_tmpisl}")
    file(COPY "${_isl2}" DESTINATION "${_tmpisl}")
    _polyorch_tp_pin_hash("${_tmpisl}/pkg-deps-fmt" vcpkg _hv0)
    file(APPEND "${_tmpisl}/pkg-deps-fmt/conan.lock" "\n")
    _polyorch_tp_pin_hash("${_tmpisl}/pkg-deps-fmt" vcpkg _hv1)
    ck_str("${_hv1}" "${_hv0}")          # conan-side bytes cannot age a vcpkg artifact
    _polyorch_tp_pin_hash("${_tmpisl}/pkg-deps-fmt" conan _hc1)
    file(APPEND "${_tmpisl}/pkg-deps-fmt/conan.lock" "\n")
    _polyorch_tp_pin_hash("${_tmpisl}/pkg-deps-fmt" conan _hc2)
    ck(NOT _hc2 STREQUAL "${_hc1}")      # ... while the conan lane does see them

    # ---- the two new fields must actually ride the key ----
    polyorch_thirdparty_fingerprint(_k1 ARCHIVE_SHA256 "${_h}" BUILD_TYPE Release
        ECOSYSTEM_PROVIDER conan ECOSYSTEM_PIN_SHA256 "${_h}"
        ECOSYSTEM_TRIPLET polyorch-release ECOSYSTEM_TOOL_VERSION "2.32.0"
        ECOSYSTEM_PROFILE_SHA256 "${_ph}")
    polyorch_thirdparty_fingerprint(_k2 ARCHIVE_SHA256 "${_h}" BUILD_TYPE Release
        ECOSYSTEM_PROVIDER conan ECOSYSTEM_PIN_SHA256 "${_h}"
        ECOSYSTEM_TRIPLET polyorch-release ECOSYSTEM_TOOL_VERSION "2.33.0"
        ECOSYSTEM_PROFILE_SHA256 "${_ph}")
    polyorch_thirdparty_fingerprint(_k3 ARCHIVE_SHA256 "${_h}" BUILD_TYPE Release
        ECOSYSTEM_PROVIDER conan ECOSYSTEM_PIN_SHA256 "${_h}"
        ECOSYSTEM_TRIPLET polyorch-release ECOSYSTEM_TOOL_VERSION "2.32.0"
        ECOSYSTEM_PROFILE_SHA256 "${_ph3}")
    ck(NOT _k1 STREQUAL "${_k2}")        # a tool upgrade is a different artifact
    ck(NOT _k1 STREQUAL "${_k3}")        # a profile change is a different artifact
    foreach(_row IN ITEMS "ecosystem_tool_version=2.32.0" "ecosystem_profile=${_ph}")
        if(NOT _k1_DOSSIER MATCHES "(^|\n)${_row}(\n|$)")
            message(FATAL_ERROR "dossier row '${_row}' missing from:\n${_k1_DOSSIER}")
        endif()
    endforeach()

    message(STATUS "THIRD-PARTY-PROVIDER-CONAN-OK")
endif()
