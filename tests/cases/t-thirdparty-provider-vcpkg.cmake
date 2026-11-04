# expect-log THIRD-PARTY-PROVIDER-VCPKG-OK
# The P7a vcpkg lane's offline gates, end to end: every leg below refuses
# LOUDLY (a child process per leg -- FATAL kills the script, so the parent
# collects rc + text). The generate leg itself (network) is the e2e case
# (t-thirdparty-provider-vcpkg-e2e.cmake); here nothing ever touches the net.
if(TP_LEG)
    # self-lock (the D48 lesson): the child dispatches on TP_LEG and dies in
    # the guard under test -- it never spawns further children
    include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchThirdPartyHelpers.cmake")
    set(_h "1111111111111111111111111111111111111111111111111111111111111111")
    set(_island "$ENV{TMPDIR}/tp-eco-island")
    file(REMOVE_RECURSE "${_island}")
    if(NOT TP_LEG STREQUAL "island-missing")
        file(MAKE_DIRECTORY "${_island}")
    endif()
    if(TP_LEG STREQUAL "strict")
        file(WRITE "${_island}/vcpkg.json"
  "{\"name\":\"x-island\",\"version\":\"1\",\"builtin-baseline\":\"${_h}\",\"dependencies\":[\"zlib\"]}")
        file(WRITE "$ENV{TMPDIR}/tp-eco.json"
  "{\"schema_version\":1,\"name\":\"x\",\"version\":\"1\",\"provider\":\"vcpkg\",\"license\":\"MIT\",\"pin_dir\":\"${_island}\"}")
        polyorch_thirdparty_recipe(RECIPE "$ENV{TMPDIR}/tp-eco.json"
            WORK_DIR "$ENV{TMPDIR}/tp-eco-w" BUILD_TYPE Debug)
    elseif(TP_LEG STREQUAL "o13-patches")
        file(WRITE "${_island}/vcpkg.json" "{\"name\":\"x-island\",\"version\":\"1\",\"builtin-baseline\":\"${_h}\"}")
        file(WRITE "$ENV{TMPDIR}/tp-eco.json"
  "{\"schema_version\":1,\"name\":\"x\",\"version\":\"1\",\"provider\":\"vcpkg\",\"license\":\"MIT\",\"pin_dir\":\"${_island}\",\"patches\":[{\"path\":\"/nonexistent.patch\",\"sha256\":\"${_h}\"}]}")
        polyorch_thirdparty_recipe(RECIPE "$ENV{TMPDIR}/tp-eco.json"
            WORK_DIR "$ENV{TMPDIR}/tp-eco-w" BUILD_TYPE Debug)
    elseif(TP_LEG STREQUAL "o13-patchcmd")
        file(WRITE "${_island}/vcpkg.json" "{\"name\":\"x-island\",\"version\":\"1\",\"builtin-baseline\":\"${_h}\"}")
        file(WRITE "$ENV{TMPDIR}/tp-eco.json"
  "{\"schema_version\":1,\"name\":\"x\",\"version\":\"1\",\"provider\":\"vcpkg\",\"license\":\"MIT\",\"pin_dir\":\"${_island}\",\"patch_command\":[\"sed\",\"-i\",\"s/a/b/\",\"x.c\"]}")
        polyorch_thirdparty_recipe(RECIPE "$ENV{TMPDIR}/tp-eco.json"
            WORK_DIR "$ENV{TMPDIR}/tp-eco-w" BUILD_TYPE Debug)
    elseif(TP_LEG STREQUAL "o13-green")
        # source + patches must sail PAST the O-13 gate (it is an ecosystem
        # gate, not a patch ban) -- this recipe dies at fetch, which is the
        # proof the gate did not fire
        file(WRITE "$ENV{TMPDIR}/tp-eco.json"
  "{\"schema_version\":1,\"name\":\"x\",\"version\":\"1\",\"provider\":\"source\",\"license\":\"MIT\",\"url\":\"/nonexistent.tar.gz\",\"url_hash\":\"${_h}\",\"patches\":[{\"path\":\"/nonexistent.patch\",\"sha256\":\"${_h}\"}]}")
        polyorch_thirdparty_recipe(RECIPE "$ENV{TMPDIR}/tp-eco.json"
            WORK_DIR "$ENV{TMPDIR}/tp-eco-w" BUILD_TYPE Debug)
    elseif(TP_LEG STREQUAL "schema-pin-missing")
        file(WRITE "$ENV{TMPDIR}/tp-eco.json"
  "{\"schema_version\":1,\"name\":\"x\",\"version\":\"1\",\"provider\":\"vcpkg\",\"license\":\"MIT\",\"url\":\"/nonexistent.tar.gz\",\"url_hash\":\"${_h}\"}")
        polyorch_thirdparty_recipe(RECIPE "$ENV{TMPDIR}/tp-eco.json"
            WORK_DIR "$ENV{TMPDIR}/tp-eco-w" BUILD_TYPE Debug)
    elseif(TP_LEG STREQUAL "island-missing")
        # pin_dir points nowhere: the island gate refuses before any hash
        file(WRITE "$ENV{TMPDIR}/tp-eco.json"
  "{\"schema_version\":1,\"name\":\"x\",\"version\":\"1\",\"provider\":\"vcpkg\",\"license\":\"MIT\",\"pin_dir\":\"${_island}\"}")
        polyorch_thirdparty_recipe(RECIPE "$ENV{TMPDIR}/tp-eco.json"
            WORK_DIR "$ENV{TMPDIR}/tp-eco-w" BUILD_TYPE Debug)
    elseif(TP_LEG STREQUAL "license-drift")
        file(WRITE "${_island}/vcpkg.json"
  "{\"name\":\"x-island\",\"version\":\"1\",\"builtin-baseline\":\"${_h}\",\"license\":\"Apache-2.0\"}")
        file(WRITE "$ENV{TMPDIR}/tp-eco.json"
  "{\"schema_version\":1,\"name\":\"x\",\"version\":\"1\",\"provider\":\"vcpkg\",\"license\":\"MIT\",\"pin_dir\":\"${_island}\"}")
        polyorch_thirdparty_recipe(RECIPE "$ENV{TMPDIR}/tp-eco.json"
            WORK_DIR "$ENV{TMPDIR}/tp-eco-w" BUILD_TYPE Debug)
    elseif(TP_LEG STREQUAL "fetchonly-eco")
        file(WRITE "${_island}/vcpkg.json" "{\"name\":\"x-island\",\"version\":\"1\",\"builtin-baseline\":\"${_h}\"}")
        file(WRITE "$ENV{TMPDIR}/tp-eco.json"
  "{\"schema_version\":1,\"name\":\"x\",\"version\":\"1\",\"provider\":\"vcpkg\",\"license\":\"MIT\",\"pin_dir\":\"${_island}\",\"fetch_only\":true}")
        polyorch_thirdparty_recipe(RECIPE "$ENV{TMPDIR}/tp-eco.json"
            WORK_DIR "$ENV{TMPDIR}/tp-eco-w" BUILD_TYPE Debug)
    elseif(TP_LEG STREQUAL "profile-eco")
        file(WRITE "${_island}/vcpkg.json" "{\"name\":\"x-island\",\"version\":\"1\",\"builtin-baseline\":\"${_h}\"}")
        file(WRITE "$ENV{TMPDIR}/tp-eco.json"
  "{\"schema_version\":1,\"name\":\"x\",\"version\":\"1\",\"provider\":\"vcpkg\",\"license\":\"MIT\",\"pin_dir\":\"${_island}\"}")
        polyorch_thirdparty_recipe(RECIPE "$ENV{TMPDIR}/tp-eco.json"
            WORK_DIR "$ENV{TMPDIR}/tp-eco-w" BUILD_TYPE Debug PROFILE release)
    elseif(TP_LEG STREQUAL "depprovider-eco")
        file(WRITE "${_island}/vcpkg.json" "{\"name\":\"x-island\",\"version\":\"1\",\"builtin-baseline\":\"${_h}\"}")
        file(WRITE "$ENV{TMPDIR}/tp-eco.json"
  "{\"schema_version\":1,\"name\":\"x\",\"version\":\"1\",\"provider\":\"vcpkg\",\"license\":\"MIT\",\"pin_dir\":\"${_island}\"}")
        polyorch_thirdparty_recipe(RECIPE "$ENV{TMPDIR}/tp-eco.json"
            WORK_DIR "$ENV{TMPDIR}/tp-eco-w" BUILD_TYPE Debug DEPENDENCY_PROVIDER pixi PIXI_ENVIRONMENT default)
    elseif(TP_LEG STREQUAL "knob-source")
        # the lane knobs belong to the ecosystem lane only
        file(WRITE "$ENV{TMPDIR}/tp-eco.json"
  "{\"schema_version\":1,\"name\":\"x\",\"version\":\"1\",\"provider\":\"source\",\"license\":\"MIT\",\"url\":\"/nonexistent.tar.gz\",\"url_hash\":\"${_h}\"}")
        polyorch_thirdparty_recipe(RECIPE "$ENV{TMPDIR}/tp-eco.json"
            WORK_DIR "$ENV{TMPDIR}/tp-eco-w" BUILD_TYPE Debug BINARY_CACHE on)
    elseif(TP_LEG STREQUAL "knob-badval")
        file(WRITE "${_island}/vcpkg.json" "{\"name\":\"x-island\",\"version\":\"1\",\"builtin-baseline\":\"${_h}\"}")
        file(WRITE "$ENV{TMPDIR}/tp-eco.json"
  "{\"schema_version\":1,\"name\":\"x\",\"version\":\"1\",\"provider\":\"vcpkg\",\"license\":\"MIT\",\"pin_dir\":\"${_island}\"}")
        polyorch_thirdparty_recipe(RECIPE "$ENV{TMPDIR}/tp-eco.json"
            WORK_DIR "$ENV{TMPDIR}/tp-eco-w" BUILD_TYPE Debug BINARY_CACHE maybe)
    elseif(TP_LEG STREQUAL "triplet-winstat")
        _polyorch_tp_ecosystem_triplet(_t "static" "x64-windows")
    elseif(TP_LEG STREQUAL "triplet-badproc")
        # script mode leaves the host variables empty; a child can seed them
        # to prove the vocabulary gate (sparc is in no vcpkg triplet)
        set(CMAKE_HOST_SYSTEM_PROCESSOR "sparc")
        _polyorch_tp_ecosystem_triplet(_t "" "")
    endif()
    message(FATAL_ERROR "unreachable: leg ${TP_LEG} must refuse")
else()
    include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")

    # ---- child legs: rc!=0 + the exact refusal wording ----
    set(_legs strict o13-patches o13-patchcmd o13-green schema-pin-missing
        island-missing license-drift fetchonly-eco profile-eco depprovider-eco
        knob-source knob-badval triplet-winstat triplet-badproc)
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
            # the refusal is an OPERATOR MANUAL: philosophy, the explicit
            # generate switch, a copy-pasteable command with the pinned env,
            # the tool rungs, and the provider-source off-ramp
            foreach(_w IN ITEMS "strict-first" "no auto-fallback" "package cache miss"
                    "GENERATE_ECOSYSTEM" "--x-manifest-root=" "--triplet=" "--vcpkg-root="
                    "VCPKG_BINARY_SOURCES=clear" "VCPKG_DEFAULT_BINARY_CACHE="
                    "VCPKG_PROGRAM" "BOOTSTRAP_TOOL" "provider .source.")
                if(NOT _txt MATCHES "${_w}")
                    message(FATAL_ERROR "strict leg wording '${_w}' missing:\n${_txt}")
                endif()
            endforeach()
            # measured poison: forcing system binaries turns vcpkg's own
            # tool bootstrap into a hard host requirement (detect_compiler
            # dies on a box without ninja) -- it must never be printed
            if(_txt MATCHES "FORCE_SYSTEM_BINARIES")
                message(FATAL_ERROR "strict leg still advertises FORCE_SYSTEM_BINARIES:\n${_txt}")
            endif()
        elseif(_leg MATCHES "^o13-(patches|patchcmd)$")
            if(NOT _txt MATCHES "O-13")
                message(FATAL_ERROR "leg '${_leg}' wording missing:\n${_txt}")
            endif()
        elseif(_leg STREQUAL "o13-green")
            if(NOT _txt MATCHES "does not exist")
                message(FATAL_ERROR "o13-green leg should die at fetch, got:\n${_txt}")
            endif()
            if(_txt MATCHES "O-13")
                message(FATAL_ERROR "o13-green leg fired the ecosystem gate on a source recipe:\n${_txt}")
            endif()
        elseif(_leg STREQUAL "schema-pin-missing")
            if(NOT _txt MATCHES "required field .pin_dir.")
                message(FATAL_ERROR "schema-pin-missing leg wording missing:\n${_txt}")
            endif()
        elseif(_leg STREQUAL "island-missing")
            if(NOT _txt MATCHES "pin island")
                message(FATAL_ERROR "island-missing leg wording missing:\n${_txt}")
            endif()
        elseif(_leg STREQUAL "license-drift")
            if(NOT _txt MATCHES "license drift")
                message(FATAL_ERROR "license-drift leg wording missing:\n${_txt}")
            endif()
        elseif(_leg STREQUAL "fetchonly-eco")
            if(NOT _txt MATCHES "fetch_only is a source-lane concept")
                message(FATAL_ERROR "fetchonly-eco leg wording missing:\n${_txt}")
            endif()
        elseif(_leg STREQUAL "profile-eco")
            if(NOT _txt MATCHES "PROFILE is a source-lane concept")
                message(FATAL_ERROR "profile-eco leg wording missing:\n${_txt}")
            endif()
        elseif(_leg STREQUAL "depprovider-eco")
            if(NOT _txt MATCHES "DEPENDENCY_PROVIDER is a build-lane concept")
                message(FATAL_ERROR "depprovider-eco leg wording missing:\n${_txt}")
            endif()
        elseif(_leg STREQUAL "knob-source")
            if(NOT _txt MATCHES "ecosystem-lane knobs")
                message(FATAL_ERROR "knob-source leg wording missing:\n${_txt}")
            endif()
        elseif(_leg STREQUAL "knob-badval")
            if(NOT _txt MATCHES "BINARY_CACHE must be on..ff")
                message(FATAL_ERROR "knob-badval leg wording missing:\n${_txt}")
            endif()
        elseif(_leg STREQUAL "triplet-winstat")
            if(NOT _txt MATCHES "windows triplet is refused")
                message(FATAL_ERROR "triplet-winstat leg wording missing:\n${_txt}")
            endif()
        elseif(_leg STREQUAL "triplet-badproc")
            if(NOT _txt MATCHES "cannot map processor")
                message(FATAL_ERROR "triplet-badproc leg wording missing:\n${_txt}")
            endif()
        endif()
    endforeach()

    include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchThirdPartyHelpers.cmake")

    # ---- triplet derivation ladder (O-12=C), inline ----
    set(PolyOrch_VCPKG_TRIPLET "x64-linux-release")
    _polyorch_tp_ecosystem_triplet(_t "" "x64-linux-static")
    ck_str("${_t}" "x64-linux-static")      # 1. call-site override wins
    _polyorch_tp_ecosystem_triplet(_t "" "")
    ck_str("${_t}" "x64-linux-release")     # 2. platform face beats self-derivation
    unset(PolyOrch_VCPKG_TRIPLET)
    _polyorch_tp_ecosystem_triplet(_t "" "")
    ck(_t MATCHES "^(x64|arm64)-linux$")    # 3. self-derived (host-shaped)
    _polyorch_tp_ecosystem_triplet(_t "static" "")
    ck(_t MATCHES "^(x64|arm64)-linux-static$")  # static appends the overlay suffix
    _polyorch_tp_ecosystem_triplet(_t "static" "x64-linux-static")
    ck_str("${_t}" "x64-linux-static")      # already-static never doubles

    # ---- pinned env: every vcpkg child runs inside this exact box ----
    # five keys, and the poison key is gone (measured: VCPKG_FORCE_SYSTEM_BINARIES
    # makes the host responsible for cmake/ninja and detect_compiler dies
    # without ninja, while an uninjected install succeeds on the same box)
    set(_envw "$ENV{TMPDIR}/tp-eco-envw")
    file(REMOVE_RECURSE "${_envw}")
    _polyorch_tp_vcpkg_env("${_envw}" _env FALSE)
    list(LENGTH _env _n)
    ck(_n EQUAL 5)
    list(FIND _env "VCPKG_DOWNLOADS=${_envw}/vcpkg-downloads" _i)
    ck(NOT _i EQUAL -1)
    list(FIND _env "VCPKG_DEFAULT_BINARY_CACHE=${_envw}/vcpkg-binary" _i)
    ck(NOT _i EQUAL -1)
    list(FIND _env "VCPKG_BINARY_SOURCES=clear" _i)
    ck(NOT _i EQUAL -1)
    list(FIND _env "VCPKG_DISABLE_METRICS=1" _i)
    ck(NOT _i EQUAL -1)
    list(FIND _env "VCPKG_MAX_CONCURRENCY=2" _i)
    ck(NOT _i EQUAL -1)
    string(FIND "${_env}" "FORCE_SYSTEM_BINARIES" _p)
    ck(_p EQUAL -1)
    # vcpkg refuses a binary cache that is not an existing directory (measured:
    # "must be a directory") -- the helper creates both anchor directories
    ck(IS_DIRECTORY "${_envw}/vcpkg-binary")
    ck(IS_DIRECTORY "${_envw}/vcpkg-downloads")
    # the posture knob switches only the sources line: same directories,
    # same key count, nothing else moves
    _polyorch_tp_vcpkg_env("${_envw}" _env2 TRUE)
    list(LENGTH _env2 _n2)
    ck(_n2 EQUAL 5)
    list(FIND _env2 "VCPKG_BINARY_SOURCES=files,${_envw}/vcpkg-binary,readwrite" _i)
    ck(NOT _i EQUAL -1)
    list(REMOVE_ITEM _env2 "VCPKG_BINARY_SOURCES=files,${_envw}/vcpkg-binary,readwrite")
    list(REMOVE_ITEM _env "VCPKG_BINARY_SOURCES=clear")
    ck_str("${_env}" "${_env2}")

    # ---- pin hash: content-addressed, byte-sensitive, location-free ----
    set(_i1 "$ENV{TMPDIR}/tp-eco-h1")
    set(_i2 "$ENV{TMPDIR}/tp-eco-h2")
    set(_i3 "$ENV{TMPDIR}/tp-eco-h3")
    file(REMOVE_RECURSE "${_i1}" "${_i2}" "${_i3}")
    foreach(_d IN ITEMS _i1 _i2 _i3)
        file(MAKE_DIRECTORY "${${_d}}")
    endforeach()
    file(WRITE "${_i1}/vcpkg.json" "{\"name\":\"a\",\"version\":\"1\",\"builtin-baseline\":\"${_h}\"}")
    file(WRITE "${_i2}/vcpkg.json" "{\"name\":\"a\",\"version\":\"1\",\"builtin-baseline\":\"${_h}\"}")
    file(WRITE "${_i3}/vcpkg.json" "{\"name\":\"a\",\"version\":\"2\",\"builtin-baseline\":\"${_h}\"}")
    _polyorch_tp_pin_hash("${_i1}" vcpkg _h1)
    _polyorch_tp_pin_hash("${_i2}" vcpkg _h2)
    _polyorch_tp_pin_hash("${_i3}" vcpkg _h3)
    ck_str("${_h1}" "${_h2}")   # same bytes, different directory: same hash
    ck(NOT _h1 STREQUAL "${_h3}")  # one byte differs: a different library
    string(LENGTH "${_h1}" _hl)
    ck(_hl EQUAL 64)

    # ---- fingerprint: the ECOSYSTEM_* trio rides the key (O-10/O-11) ----
    polyorch_thirdparty_fingerprint(_k1 ARCHIVE_SHA256 "${_h1}" BUILD_TYPE Debug
        ECOSYSTEM_PROVIDER vcpkg ECOSYSTEM_PIN_SHA256 "${_h1}" ECOSYSTEM_TRIPLET x64-linux)
    polyorch_thirdparty_fingerprint(_k2 ARCHIVE_SHA256 "${_h1}" BUILD_TYPE Debug
        ECOSYSTEM_PROVIDER vcpkg ECOSYSTEM_PIN_SHA256 "${_h1}" ECOSYSTEM_TRIPLET arm64-linux)
    polyorch_thirdparty_fingerprint(_k3 ARCHIVE_SHA256 "${_h1}" BUILD_TYPE Debug)
    ck(NOT _k1 STREQUAL "${_k2}")  # a different triplet is a different artifact
    ck(NOT _k1 STREQUAL "${_k3}")  # ecosystem fields never alias a bare source key
    foreach(_row IN ITEMS "ecosystem_provider=vcpkg" "ecosystem_pin=${_h1}" "ecosystem_triplet=x64-linux")
        if(NOT _k1_DOSSIER MATCHES "(^|\n)${_row}(\n|$)")
            message(FATAL_ERROR "dossier row '${_row}' missing from:\n${_k1_DOSSIER}")
        endif()
    endforeach()

    message(STATUS "THIRD-PARTY-PROVIDER-VCPKG-OK")
endif()
