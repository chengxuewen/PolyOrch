#-----------------------------------------------------------------------------------------------------------------------
# PolyOrchThirdPartyHelpers.cmake -- the third-party dependency face (EXPERIMENTAL, D50).
#
# Scope of this first drop (P1 of the sr8 round):
#   * acquire-from-source: verified archive + verified file patches + stamp
#   * independent build/install (explicit verb -- NEVER auto-run at configure
#     time; H2: an IDE reconfigure must not trigger minutes of compilation)
#   * consume the upstream's own installed <Pkg>Config.cmake (NO_DEFAULT_PATH)
#     and hand the consumer an alias -- upstream target names stay untouched
#   * full-field cache fingerprint (M1: the recipe itself and its schema
#     version are key inputs; O-3: BUILD_TYPE is REQUIRED so a multi-config
#     generator can never collapse two configs into one key) + manifest
#     sidecar (L7: license is mandatory)
#   * declarative JSON recipe loader + schema gate
#
# Deliberate code-level seams (louder than any doc -- F2=A adjudication):
#   * provider vcpkg/conan        -> FATAL pointing at P7 / O-10
#   * provider prebuilt/system    -> FATAL pointing at the package-cache face (P2)
#   * DEPENDENCY_PROVIDER pixi/sysroot -> FATAL pointing at P4 / P6
# The dependency-provider rules that WILL apply once pixi lands (r4 C1):
#   only include/lib/pkgconfig sub-paths are ever injected -- never a bare
#   prefix carrying bin/ -- and the inner configure must receive explicit
#   compilers; a negative test asserts the inner compiler path never lives
#   under .pixi/envs. Nothing here may inject a compiler.
#
# Cross-compile forwarding contract (r4 H3): TOOLCHAIN_FILE is forwarded as
# -DCMAKE_TOOLCHAIN_FILE; a cross caller additionally passes the rest of the
# group (GENERATOR_PLATFORM / GENERATOR_TOOLSET / CMAKE_FIND_ROOT_PATH* / the
# explicit CMAKE_C(XX)_COMPILER pair) through CMAKE_ARGS. The full-group
# discipline belongs to the cross batch (P6); this face only refuses to
# forward a half group silently: passing TOOLCHAIN_FILE without a compiler
# pair in CMAKE_ARGS is rejected (better loud than silently host-tooled).
#
# Naming (D11): functions polyorch_thirdparty_*; cache/options
# PolyOrch_THIRDPARTY_*; imported handles a consumer may alias are the
# upstream's own (this face adds only consumer-side aliases).
#-----------------------------------------------------------------------------------------------------------------------
include_guard(GLOBAL)

# _polyorch_tp_is_hex64 -- cmake regexes carry NO {n} quantifier (POSIX-BRE
# class), so "exactly 64 hex chars" is LENGTH + character-class, never a
# brace quantifier (the first draft's [0-9a-f]{64} matched NOTHING --
# measured; every hash gate silently refused every real hash).
function(_polyorch_tp_is_hex64 value out)
    string(LENGTH "${value}" _tp_n)
    if(_tp_n EQUAL 64 AND "${value}" MATCHES "^[0-9a-f]+$")
        set(${out} TRUE PARENT_SCOPE)
    else()
        set(${out} FALSE PARENT_SCOPE)
    endif()
endfunction()

# _polyorch_tp_package_name -- <name>-<version>-<triplet>-<profile>-
# <buildtype>-<linkmode>-<key12>.<ext> (sr8 §2.4). Empty identity fields
# become "none": a bare "--" run would let two different identities
# collide in one file name.
function(_polyorch_tp_package_name out name version triplet profile buildtype linkmode key12 ext)
    foreach(_tp_v triplet profile linkmode)
        if("${${_tp_v}}" STREQUAL "")
            set(${_tp_v} "none")
        endif()
    endforeach()
    if("${version}" STREQUAL "")
        set(version "none")
    endif()
    set(${out} "${name}-${version}-${triplet}-${profile}-${buildtype}-${linkmode}-${key12}.${ext}" PARENT_SCOPE)
endfunction()

#-----------------------------------------------------------------------------------------------------------------------
# polyorch_thirdparty_fingerprint -- full-field cache key.
#
#   polyorch_thirdparty_fingerprint(<out-var>
#     ARCHIVE_SHA256 <hex>                 (required)
#     BUILD_TYPE <cfg>                     (required; O-3: multi-config collapse guard)
#     [PATCH_SHA256 <h1;h2...>] [VERSION <v>] [PROFILE <p>] [TRIPLET <t>]
#     [LINK_MODE <static|shared>] [OPTIONS <k=v;...>]
#     [TOOLCHAIN_FILE_SHA256 <h>] [COMPILER_ID <id>] [COMPILER_VERSION <v>]
#     [CMAKE_VERSION <v>] [DEPENDENCY_PROVIDER <p>] [PIXI_LOCK_SHA256 <h>]
#     [SYSROOT_ID <id>] [RECIPE_SHA256 <h>] [SCHEMA_VERSION <n>]
#     [HELPER_VERSION <v>])
#
# Sets <var> (64 hex) and <var>_SHORT12 (first 12 hex chars). OPTIONS are
# normalized: entries stripped and sorted, so key order / whitespace cannot
# produce a false-distinct key (F4=A "no false distinct" leg).
function(polyorch_thirdparty_fingerprint out)
    cmake_parse_arguments(arg ""
        "ARCHIVE_SHA256;BUILD_TYPE;VERSION;PROFILE;TRIPLET;LINK_MODE;TOOLCHAIN_FILE_SHA256;COMPILER_ID;COMPILER_VERSION;CMAKE_VERSION;DEPENDENCY_PROVIDER;PIXI_LOCK_SHA256;SYSROOT_ID;RECIPE_SHA256;SCHEMA_VERSION;HELPER_VERSION"
        "OPTIONS;PATCH_SHA256" ${ARGN})
    if(out STREQUAL "")
        message(FATAL_ERROR "polyorch_thirdparty_fingerprint: <out-var> is required")
    endif()
    if(NOT arg_ARCHIVE_SHA256)
        message(FATAL_ERROR "polyorch_thirdparty_fingerprint: ARCHIVE_SHA256 is required (a key without the artifact digest is a silent-reuse hazard)")
    endif()
    if(NOT arg_BUILD_TYPE)
        message(FATAL_ERROR "polyorch_thirdparty_fingerprint: BUILD_TYPE is required (O-3: an empty effective config under VS/Xcode would collapse every config into one key)")
    endif()
    if(NOT arg_HELPER_VERSION)
        set(arg_HELPER_VERSION "0.8.0-experimental")
    endif()

    # Normalize the option list: strip each entry, drop empties, sort.
    set(_tp_opts "")
    foreach(_tp_o IN LISTS arg_OPTIONS)
        string(STRIP "${_tp_o}" _tp_o)
        if(NOT _tp_o STREQUAL "")
            list(APPEND _tp_opts "${_tp_o}")
        endif()
    endforeach()
    if(_tp_opts)
        list(SORT _tp_opts)
        list(JOIN _tp_opts ";" _tp_opts_j)
    else()
        set(_tp_opts_j "-")
    endif()
    if(arg_PATCH_SHA256)
        list(SORT arg_PATCH_SHA256)
        list(JOIN arg_PATCH_SHA256 ";" _tp_patch_j)
    else()
        set(_tp_patch_j "-")
    endif()

    # Canonical field=value dossier; absent fields stay EMPTY (a fixed
    # ordering + fixed field set is what matters) so adding a field later
    # can never alias an old key.
    set(_tp_dossier "")
    foreach(_tp_f IN ITEMS
        "archive_sha256=${arg_ARCHIVE_SHA256}" "patch_sha256=${_tp_patch_j}"
        "version=${arg_VERSION}" "profile=${arg_PROFILE}" "triplet=${arg_TRIPLET}"
        "build_type=${arg_BUILD_TYPE}" "link_mode=${arg_LINK_MODE}"
        "options=${_tp_opts_j}" "toolchain_sha256=${arg_TOOLCHAIN_FILE_SHA256}"
        "compiler=${arg_COMPILER_ID}-${arg_COMPILER_VERSION}" "cmake=${arg_CMAKE_VERSION}"
        "dependency_provider=${arg_DEPENDENCY_PROVIDER}" "pixi_lock=${arg_PIXI_LOCK_SHA256}"
        "sysroot_id=${arg_SYSROOT_ID}" "recipe_sha256=${arg_RECIPE_SHA256}"
        "schema_version=${arg_SCHEMA_VERSION}" "helper_version=${arg_HELPER_VERSION}")
        string(APPEND _tp_dossier "${_tp_f}\n")
    endforeach()
    string(SHA256 _tp_key "${_tp_dossier}")
    string(SUBSTRING "${_tp_key}" 0 12 _tp_key12)
    set(${out} "${_tp_key}" PARENT_SCOPE)
    set(${out}_SHORT12 "${_tp_key12}" PARENT_SCOPE)
    set(${out}_DOSSIER "${_tp_dossier}" PARENT_SCOPE)
endfunction()

#-----------------------------------------------------------------------------------------------------------------------
# polyorch_thirdparty_fetch -- verified acquire from a local source archive.
#
#   polyorch_thirdparty_fetch(NAME <n> URL <archive|dir> URL_HASH SHA256=<hex>
#     [PATCHES <f...>] [PATCH_SHA256 <h...>]      (parallel lists, both or neither)
#     [OUTPUT_DIR <d>]                            (default: CMAKE_CURRENT_BINARY_DIR/3rdparty)
#     SOURCE_DIR_OUT <var> [ARCHIVE_SHA256_OUT <var>])
#
# URL_HASH is mandatory (an unverified artifact is unkeyable). Patches are
# verified sha256 FIRST and only then applied (L6) -- a file patch is applied
# as a verbatim copy over the extracted tree, relative to the archive root;
# command-shaped patches stay the recipe's PATCH_COMMAND business (applied by
# the caller after fetch). The stamp records the dossier, not a timestamp:
# changing any input rebuilds the tree; identical inputs are a no-op.
function(polyorch_thirdparty_fetch)
    cmake_parse_arguments(arg ""
        "NAME;URL;URL_HASH;OUTPUT_DIR;SOURCE_DIR_OUT;ARCHIVE_SHA256_OUT" "PATCHES;PATCH_SHA256" ${ARGN})
    if(NOT arg_NAME OR NOT arg_URL OR NOT arg_URL_HASH OR NOT arg_SOURCE_DIR_OUT)
        message(FATAL_ERROR "polyorch_thirdparty_fetch: NAME, URL, URL_HASH and SOURCE_DIR_OUT are required")
    endif()
    string(REGEX REPLACE "^SHA256=" "" _tp_want "${arg_URL_HASH}")
    string(TOLOWER "${_tp_want}" _tp_want)
    _polyorch_tp_is_hex64("${_tp_want}" _tp_hash_ok)
    if(NOT _tp_hash_ok)
        message(FATAL_ERROR "polyorch_thirdparty_fetch: URL_HASH must look like SHA256=<64 hex>, got '${arg_URL_HASH}'")
    endif()
    if(arg_PATCHES AND NOT arg_PATCH_SHA256)
        message(FATAL_ERROR "polyorch_thirdparty_fetch: PATCHES requires the parallel PATCH_SHA256 list (verify-before-apply, L6)")
    endif()
    if(arg_PATCH_SHA256 AND NOT arg_PATCHES)
        message(FATAL_ERROR "polyorch_thirdparty_fetch: PATCH_SHA256 requires the parallel PATCHES list")
    endif()
    list(LENGTH arg_PATCHES _tp_np)
    list(LENGTH arg_PATCH_SHA256 _tp_ns)
    if(NOT _tp_np EQUAL _tp_ns)
        message(FATAL_ERROR "polyorch_thirdparty_fetch: PATCHES (${_tp_np}) and PATCH_SHA256 (${_tp_ns}) must be the same length")
    endif()

    if(NOT EXISTS "${arg_URL}")
        message(FATAL_ERROR "polyorch_thirdparty_fetch: URL '${arg_URL}' does not exist (P1 is zero-network: ship the archive in-repo)")
    endif()
    if(NOT arg_OUTPUT_DIR)
        if(NOT CMAKE_CURRENT_BINARY_DIR)
            message(FATAL_ERROR "polyorch_thirdparty_fetch: OUTPUT_DIR is required in script mode (cmake -P has no CMAKE_CURRENT_BINARY_DIR -- a silent '/3rdparty' root write is refused)")
        endif()
        set(arg_OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/3rdparty")
    endif()

    # Digest the artifact once; URL_HASH is the gate (hash mismatch = FATAL).
    if(IS_DIRECTORY "${arg_URL}")
        message(FATAL_ERROR "polyorch_thirdparty_fetch: directory URLs are not digests; ship an archive (got a directory: ${arg_URL})")
    endif()
    file(SHA256 "${arg_URL}" _tp_arch_hash)
    string(TOLOWER "${_tp_arch_hash}" _tp_arch_hash)
    if(NOT _tp_arch_hash STREQUAL _tp_want)
        message(FATAL_ERROR "polyorch_thirdparty_fetch: archive hash mismatch for ${arg_URL}\n  expected ${_tp_want}\n  actual   ${_tp_arch_hash}\nRefusing to extract (corrupt or substituted artifact).")
    endif()

    # Verify every patch BEFORE touching the extracted tree (L6).
    set(_tp_patch_dossier "")
    set(_tp_i 0)
    foreach(_tp_p IN LISTS arg_PATCHES)
        list(GET arg_PATCH_SHA256 ${_tp_i} _tp_ps)
        if(NOT EXISTS "${_tp_p}")
            message(FATAL_ERROR "polyorch_thirdparty_fetch: patch '${_tp_p}' does not exist")
        endif()
        file(SHA256 "${_tp_p}" _tp_ph)
        string(TOLOWER "${_tp_ph}" _tp_ph)
        string(TOLOWER "${_tp_ps}" _tp_ps)
        if(NOT _tp_ph STREQUAL _tp_ps)
            message(FATAL_ERROR "polyorch_thirdparty_fetch: patch hash mismatch for ${_tp_p}\n  expected ${_tp_ps}\n  actual   ${_tp_ph}\nRefusing to apply (verify-before-apply, L6).")
        endif()
        string(APPEND _tp_patch_dossier "${_tp_ph}\n")
        math(EXPR _tp_i "${_tp_i} + 1")
    endforeach()
    string(SHA256 _tp_patch_combined "${_tp_patch_dossier}")

    set(_tp_root "${arg_OUTPUT_DIR}/${arg_NAME}")
    set(_tp_src "${_tp_root}/source")
    set(_tp_stamp "${_tp_root}/fetch-stamp.txt")
    # Stamp key = artifact + patches only (fetch is config-independent; the
    # full-field cache key is the recipe face's business, not extraction's).
    string(SHA256 _tp_fetch_key "archive=${_tp_arch_hash}\npatches=${_tp_patch_combined}\n")
    if(EXISTS "${_tp_stamp}")
        file(READ "${_tp_stamp}" _tp_old)
        if(_tp_old STREQUAL "${_tp_fetch_key}" AND EXISTS "${_tp_src}")
            set(${arg_SOURCE_DIR_OUT} "${_tp_src}" PARENT_SCOPE)
            if(arg_ARCHIVE_SHA256_OUT)
                set(${arg_ARCHIVE_SHA256_OUT} "${_tp_arch_hash}" PARENT_SCOPE)
            endif()
            return()
        endif()
        # Inputs changed, or the tree vanished: a stamp is a memo of the
        # INPUTS, never proof the outputs survived (a deleted source must
        # re-extract, not hand the caller a dead path). The sweep deletes
        # ONLY this verb's own outputs (source/extract/stamp) -- sibling
        # build-<cfg>/install-<cfg> dirs the recipe face owns under the same
        # root must survive a re-acquire.
        file(REMOVE_RECURSE "${_tp_src}" "${_tp_root}/extract" "${_tp_stamp}")
    endif()

    file(REMOVE_RECURSE "${_tp_src}")
    file(MAKE_DIRECTORY "${_tp_root}/extract")
    execute_process(COMMAND "${CMAKE_COMMAND}" -E tar xf "${arg_URL}"
        WORKING_DIRECTORY "${_tp_root}/extract"
        RESULT_VARIABLE _tp_rc)
    if(NOT _tp_rc EQUAL 0)
        message(FATAL_ERROR "polyorch_thirdparty_fetch: extracting ${arg_URL} failed (rc=${_tp_rc})")
    endif()
    # Flatten: exactly one top directory and zero top files -> that dir
    # becomes source/; anything else (multi-root archives, top-level files)
    # keeps the extract root AS the source tree. Kind-testing uses
    # IS_DIRECTORY explicitly -- GLOB's trailing-slash behavior differs
    # across cmake versions and must not be load-bearing (measured: the
    # first draft's list(FILTER REGEX "/[^/]+$") excluded EVERYTHING).
    file(GLOB _tp_entries LIST_DIRECTORIES true "${_tp_root}/extract/*")
    set(_tp_dirs "")
    set(_tp_others "")
    foreach(_tp_e IN LISTS _tp_entries)
        string(REGEX REPLACE "/$" "" _tp_e "${_tp_e}")
        if(IS_DIRECTORY "${_tp_e}")
            list(APPEND _tp_dirs "${_tp_e}")
        else()
            list(APPEND _tp_others "${_tp_e}")
        endif()
    endforeach()
    list(LENGTH _tp_dirs _tp_nd)
    list(LENGTH _tp_others _tp_no)
    if(_tp_nd EQUAL 1 AND _tp_no EQUAL 0)
        list(GET _tp_dirs 0 _tp_real)
    else()
        set(_tp_real "${_tp_root}/extract")
    endif()
    file(RENAME "${_tp_real}" "${_tp_src}")
    file(REMOVE_RECURSE "${_tp_root}/extract")

    set(_tp_i 0)
    foreach(_tp_p IN LISTS arg_PATCHES)
        # File patches are verbatim overlays, archive-root relative.
        cmake_path(GET _tp_p FILENAME _tp_pname)
        file(COPY_FILE "${_tp_p}" "${_tp_src}/${_tp_pname}" ONLY_IF_DIFFERENT)
        math(EXPR _tp_i "${_tp_i} + 1")
    endforeach()

    file(WRITE "${_tp_stamp}" "${_tp_fetch_key}")
    set(${arg_SOURCE_DIR_OUT} "${_tp_src}" PARENT_SCOPE)
    if(arg_ARCHIVE_SHA256_OUT)
        set(${arg_ARCHIVE_SHA256_OUT} "${_tp_arch_hash}" PARENT_SCOPE)
    endif()
endfunction()

#-----------------------------------------------------------------------------------------------------------------------
# polyorch_thirdparty_build -- independent configure/build/install (EXPLICIT verb).
#
#   polyorch_thirdparty_build(NAME <n> SOURCE_DIR <d> BUILD_DIR <d> INSTALL_DIR <d>
#     BUILD_TYPE <cfg>                      (required; O-3)
#     [CMAKE_ARGS <...>] [TOOLCHAIN_FILE <f>] [GENERATOR <g>] [PARALLEL <n>])
#
# Runs a fully separate CMake invocation (execute_process), so the wrapped
# project's targets never join the caller's graph. Full logs land at
# <BUILD_DIR>/polyorch-thirdparty-<name>-configure|build|install.log and a
# failure is a hard FATAL naming the log (error model: fail loud, never
# degrade). Cross callers: TOOLCHAIN_FILE is forwarded as
# -DCMAKE_TOOLCHAIN_FILE and CMAKE_ARGS must carry the explicit compiler
# pair; TOOLCHAIN_FILE without a compiler pair is rejected (H3: refusing a
# half-forwarded group beats silently host-tooling a cross build).
# Environment: this face never injects CMAKE_PREFIX_PATH or a compiler into
# the child (r4 C1); callers reach for the dependency-provider batch (P4).
function(polyorch_thirdparty_build)
    cmake_parse_arguments(arg ""
        "NAME;SOURCE_DIR;BUILD_DIR;INSTALL_DIR;BUILD_TYPE;GENERATOR;TOOLCHAIN_FILE;PARALLEL" "CMAKE_ARGS" ${ARGN})
    foreach(_tp_req IN ITEMS NAME SOURCE_DIR BUILD_DIR INSTALL_DIR BUILD_TYPE)
        if(NOT arg_${_tp_req})
            message(FATAL_ERROR "polyorch_thirdparty_build: ${_tp_req} is required")
        endif()
    endforeach()
    if(NOT EXISTS "${arg_SOURCE_DIR}/CMakeLists.txt")
        message(FATAL_ERROR "polyorch_thirdparty_build: ${arg_SOURCE_DIR} has no CMakeLists.txt (not a CMake-shaped source tree?)")
    endif()
    set(_tp_fwd "")
    if(arg_TOOLCHAIN_FILE)
        if(NOT arg_CMAKE_ARGS MATCHES "CMAKE_C_COMPILER|CMAKE_CXX_COMPILER")
            message(FATAL_ERROR "polyorch_thirdparty_build: TOOLCHAIN_FILE given but CMAKE_ARGS carries no explicit CMAKE_C(XX)_COMPILER pair (H3: a half-forwarded cross group silently builds with the host toolchain -- pass the compilers or drop the toolchain file)")
        endif()
        list(APPEND _tp_fwd "-DCMAKE_TOOLCHAIN_FILE=${arg_TOOLCHAIN_FILE}")
    endif()
    if(NOT arg_GENERATOR)
        if(CMAKE_GENERATOR)
            set(arg_GENERATOR "${CMAKE_GENERATOR}")
        else()
            message(FATAL_ERROR "polyorch_thirdparty_build: GENERATOR is required (script mode has no default generator)")
        endif()
    endif()

    file(MAKE_DIRECTORY "${arg_BUILD_DIR}")
    set(_tp_log_cfg "${arg_BUILD_DIR}/polyorch-thirdparty-${arg_NAME}-configure.log")
    set(_tp_log_bld "${arg_BUILD_DIR}/polyorch-thirdparty-${arg_NAME}-build.log")
    set(_tp_log_ins "${arg_BUILD_DIR}/polyorch-thirdparty-${arg_NAME}-install.log")

    set(_tp_cmd "${CMAKE_COMMAND}" -S "${arg_SOURCE_DIR}" -B "${arg_BUILD_DIR}" -G "${arg_GENERATOR}"
        -DCMAKE_BUILD_TYPE=${arg_BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${arg_INSTALL_DIR} ${_tp_fwd} ${arg_CMAKE_ARGS})
    execute_process(COMMAND ${_tp_cmd} OUTPUT_FILE "${_tp_log_cfg}" ERROR_FILE "${_tp_log_cfg}" RESULT_VARIABLE _tp_rc)
    if(NOT _tp_rc EQUAL 0)
        message(FATAL_ERROR "polyorch_thirdparty_build: configure failed for ${arg_NAME} (rc=${_tp_rc}); full log: ${_tp_log_cfg}")
    endif()

    set(_tp_build "${CMAKE_COMMAND}" --build "${arg_BUILD_DIR}" --config "${arg_BUILD_TYPE}")
    if(arg_PARALLEL)
        list(APPEND _tp_build "--parallel" "${arg_PARALLEL}")
    endif()
    execute_process(COMMAND ${_tp_build} OUTPUT_FILE "${_tp_log_bld}" ERROR_FILE "${_tp_log_bld}" RESULT_VARIABLE _tp_rc)
    if(NOT _tp_rc EQUAL 0)
        message(FATAL_ERROR "polyorch_thirdparty_build: build failed for ${arg_NAME} (rc=${_tp_rc}); full log: ${_tp_log_bld}")
    endif()

    execute_process(COMMAND "${CMAKE_COMMAND}" --install "${arg_BUILD_DIR}" --config "${arg_BUILD_TYPE}"
        OUTPUT_FILE "${_tp_log_ins}" ERROR_FILE "${_tp_log_ins}" RESULT_VARIABLE _tp_rc)
    if(NOT _tp_rc EQUAL 0)
        message(FATAL_ERROR "polyorch_thirdparty_build: install failed for ${arg_NAME} (rc=${_tp_rc}); full log: ${_tp_log_ins}")
    endif()
endfunction()

#-----------------------------------------------------------------------------------------------------------------------
# polyorch_thirdparty_manifest_write -- provenance sidecar (P1: file form;
# the pack/unpack face (P2) reuses the same fields).
#
#   polyorch_thirdparty_manifest_write(MANIFEST <file> KEY <64hex> NAME <n>
#     [VERSION <v>] [LICENSE <spdx>] [PROVIDER <p>] [PROFILE <p>] [TRIPLET <t>]
#     [BUILD_TYPE <cfg>] [LINK_MODE <m>] [OPTIONS <k=v;...>] [ARCHIVE_SHA256 <h>]
#     [RECIPE_SHA256 <h>] [SCHEMA_VERSION <n>] [DEPENDENCY_PROVIDER <p>])
#
# LICENSE is mandatory (L7: zlib/MIT-class obligations ride the artifact).
function(polyorch_thirdparty_manifest_write)
    cmake_parse_arguments(arg ""
        "MANIFEST;KEY;NAME;VERSION;LICENSE;PROVIDER;PROFILE;TRIPLET;BUILD_TYPE;LINK_MODE;ARCHIVE_SHA256;RECIPE_SHA256;SCHEMA_VERSION;DEPENDENCY_PROVIDER" "OPTIONS" ${ARGN})
    if(NOT arg_MANIFEST OR NOT arg_KEY OR NOT arg_NAME)
        message(FATAL_ERROR "polyorch_thirdparty_manifest_write: MANIFEST, KEY and NAME are required")
    endif()
    if(NOT arg_LICENSE)
        message(FATAL_ERROR "polyorch_thirdparty_manifest_write: LICENSE is required for '${arg_NAME}' (L7: redistribution obligations ride the manifest; SDL=zlib, ImGui=MIT class)")
    endif()
    _polyorch_tp_is_hex64("${arg_KEY}" _tp_key_ok)
    if(NOT _tp_key_ok)
        message(FATAL_ERROR "polyorch_thirdparty_manifest_write: KEY must be 64 lowercase hex")
    endif()
    string(JSON _tp_m SET "{}" "name" "\"${arg_NAME}\"")
    string(JSON _tp_m SET "${_tp_m}" "key" "\"${arg_KEY}\"")
    string(SUBSTRING "${arg_KEY}" 0 12 _tp_k12)
    string(JSON _tp_m SET "${_tp_m}" "key12" "\"${_tp_k12}\"")
    foreach(_tp_f IN ITEMS VERSION PROVIDER PROFILE TRIPLET BUILD_TYPE LINK_MODE ARCHIVE_SHA256 RECIPE_SHA256 SCHEMA_VERSION DEPENDENCY_PROVIDER)
        if(arg_${_tp_f})
            string(TOLOWER "${_tp_f}" _tp_jf)
            string(REPLACE "_" "" _tp_jf "${_tp_jf}")
            string(JSON _tp_m SET "${_tp_m}" "${_tp_jf}" "\"${arg_${_tp_f}}\"")
        endif()
    endforeach()
    string(JSON _tp_m SET "${_tp_m}" "license" "\"${arg_LICENSE}\"")
    if(arg_OPTIONS)
        string(JSON _tp_m SET "${_tp_m}" "options" "[]")
        set(_tp_oi 0)
        foreach(_tp_o IN LISTS arg_OPTIONS)
            string(STRIP "${_tp_o}" _tp_o)
            string(JSON _tp_m SET "${_tp_m}" "options" ${_tp_oi} "\"${_tp_o}\"")
            math(EXPR _tp_oi "${_tp_oi} + 1")
        endforeach()
    endif()
    string(TIMESTAMP _tp_now UTC)
    string(JSON _tp_m SET "${_tp_m}" "created_utc" "\"${_tp_now}\"")
    file(WRITE "${arg_MANIFEST}" "${_tp_m}\n")
endfunction()

#-----------------------------------------------------------------------------------------------------------------------
# _polyorch_tp_relocate_audit -- heuristic relocatability gate for the pack
# face (F5=A criterion 10, both directions). Scans the textual config
# surfaces (*.cmake / *.pc / *.pri) for absolute path literals that would
# pin the artifact to the build host. System prefixes are allowed (they are
# environment facts, not build-host leaks). The first offending file+token
# is reported; the caller refuses to pack.
#
# Deliberately a heuristic (O-2 stays open for a heavier method): the
# guarantee is behavioural -- the paired tests prove "absolute prefix
# refused / relativized prefix accepted".
function(_polyorch_tp_relocate_audit install_dir out_ok out_why)
    file(GLOB_RECURSE _tp_cfg
        "${install_dir}/*.cmake" "${install_dir}/*.pc" "${install_dir}/*.pri")
    set(_tp_ok TRUE)
    set(_tp_why "")
    foreach(_tp_f IN LISTS _tp_cfg)
        file(READ "${_tp_f}" _tp_txt)
        # cmake regexes carry no {n} and no \s; "at least two segments"
        # keeps ${_IMPORT_PREFIX}/lib-style tokens out (the character before
        # the slash is "}", not in the lead class).
        string(REGEX MATCHALL "(^|[ \t\"'(=:])(/[A-Za-z0-9_.+-]+(/[A-Za-z0-9_.+-]+)+)" _tp_hits "${_tp_txt}")
        foreach(_tp_h IN LISTS _tp_hits)
            string(REGEX REPLACE "^[ \t\"'(=:]" "" _tp_tok "${_tp_h}")
            if(_tp_tok MATCHES "^(/usr|/lib|/lib64|/opt/homebrew|/System|/Library|/bin)(/|$)")
                continue()
            endif()
            set(_tp_ok FALSE)
            set(_tp_why "${_tp_f}: absolute path '${_tp_tok}'")
            break()
        endforeach()
        if(NOT _tp_ok)
            break()
        endif()
    endforeach()
    set(${out_ok} ${_tp_ok} PARENT_SCOPE)
    set(${out_why} "${_tp_why}" PARENT_SCOPE)
endfunction()

#-----------------------------------------------------------------------------------------------------------------------
# polyorch_thirdparty_package -- pack an installed prefix into the shared
# package cache (P2; an empty caller-side PACKAGES_DIR means this verb never
# runs -- QExt "empty = no packing" semantics).
#
#   polyorch_thirdparty_package(NAME <n> INSTALL_DIR <d> PACKAGE_DIR <d>
#     [MANIFEST <f>] [FORMAT tar.gz] [TRIPLET <t>] [REFRESH]
#     [PACKAGE_OUT <var>])
#
# Name and sidecars (sr8 §2.4): <name>-<version>-<triplet>-<profile>-
# <buildtype>-<linkmode>-<key12>.<ext>, beside it <pkg>.sha256 (bare hex,
# oxmgr precedent) and <pkg>.manifest.json. The unpack verdict compares the
# sidecar manifest key -- a present file is never the verdict.
#
# FORMAT seam: F5 declares tar.gz (default) with 7zip/zip optional. This
# packer is `cmake -E tar`, and CMake 4.4 dropped --format there (measured:
# zip/7zip extensions silently produce a POSIX tar). They are
# declared-but-refused until a real packer lands -- loud, never wrong bytes.
function(polyorch_thirdparty_package)
    cmake_parse_arguments(arg "REFRESH"
        "NAME;INSTALL_DIR;PACKAGE_DIR;MANIFEST;FORMAT;TRIPLET;PACKAGE_OUT" "" ${ARGN})
    foreach(_tp_req IN ITEMS NAME INSTALL_DIR PACKAGE_DIR)
        if(NOT arg_${_tp_req})
            message(FATAL_ERROR "polyorch_thirdparty_package: ${_tp_req} is required")
        endif()
    endforeach()
    if(NOT EXISTS "${arg_INSTALL_DIR}")
        message(FATAL_ERROR "polyorch_thirdparty_package: INSTALL_DIR '${arg_INSTALL_DIR}' does not exist -- build first (H2)")
    endif()
    if(NOT arg_FORMAT)
        set(arg_FORMAT "tar.gz")
    endif()
    if(NOT arg_FORMAT STREQUAL "tar.gz")
        message(FATAL_ERROR "polyorch_thirdparty_package: FORMAT '${arg_FORMAT}' is declared (F5) but not writable by this packer: `cmake -E tar` on CMake 4.4 has no --format (measured), and a zip/7zip name over tar bytes would be a mis-labeled archive. Use tar.gz; a 7zip/zip packer is a seam, not silently wrong bytes.")
    endif()
    if(NOT arg_MANIFEST)
        set(arg_MANIFEST "${arg_INSTALL_DIR}/polyorch-thirdparty-manifest.json")
    endif()
    if(NOT EXISTS "${arg_MANIFEST}")
        message(FATAL_ERROR "polyorch_thirdparty_package: no manifest at '${arg_MANIFEST}' -- packing without identity is refused (the unpack verdict is manifest identity, not file existence)")
    endif()
    file(READ "${arg_MANIFEST}" _tp_m)
    string(JSON _tp_key GET "${_tp_m}" key)
    _polyorch_tp_is_hex64("${_tp_key}" _tp_key_ok)
    if(NOT _tp_key_ok)
        message(FATAL_ERROR "polyorch_thirdparty_package: manifest key is not 64 lowercase hex")
    endif()
    # Optional manifest members: probe the raw text first (string(JSON) GET
    # on a missing member is a HARD error, measured in P1).
    set(_tp_version "")
    set(_tp_profile "")
    set(_tp_buildtype "")
    set(_tp_linkmode "")
    set(_tp_triplet "${arg_TRIPLET}")
    foreach(_tp_f IN ITEMS version profile buildtype linkmode triplet)
        if("${_tp_m}" MATCHES "\"${_tp_f}\"[ ]*:")
            string(JSON _tp_v GET "${_tp_m}" "${_tp_f}")
            set(_tp_${_tp_f} "${_tp_v}")
        endif()
    endforeach()
    string(SUBSTRING "${_tp_key}" 0 12 _tp_k12)
    _polyorch_tp_package_name(_tp_pkgname "${arg_NAME}" "${_tp_version}" "${_tp_triplet}" "${_tp_profile}" "${_tp_buildtype}" "${_tp_linkmode}" "${_tp_k12}" "${arg_FORMAT}")
    file(MAKE_DIRECTORY "${arg_PACKAGE_DIR}")
    set(_tp_pkgfile "${arg_PACKAGE_DIR}/${_tp_pkgname}")
    set(_tp_sha_file "${_tp_pkgfile}.sha256")
    set(_tp_side_mf "${_tp_pkgfile}.manifest.json")

    # Idempotency = sidecar identity, not existence: a byte-equal archive
    # whose sidecar disagrees is repacked, never trusted.
    if(EXISTS "${_tp_pkgfile}" AND EXISTS "${_tp_sha_file}" AND EXISTS "${_tp_side_mf}" AND NOT arg_REFRESH)
        file(SHA256 "${_tp_pkgfile}" _tp_actual)
        file(READ "${_tp_sha_file}" _tp_recorded)
        string(STRIP "${_tp_recorded}" _tp_recorded)
        file(READ "${_tp_side_mf}" _tp_sm)
        set(_tp_skey "")
        if("${_tp_sm}" MATCHES "\"key\"[ ]*:")
            string(JSON _tp_skey GET "${_tp_sm}" key)
        endif()
        if(_tp_actual STREQUAL "${_tp_recorded}" AND _tp_skey STREQUAL "${_tp_key}")
            message(STATUS "polyorch thirdparty: ${arg_NAME} package up to date (${_tp_pkgname})")
            if(arg_PACKAGE_OUT)
                set(${arg_PACKAGE_OUT} "${_tp_pkgfile}" PARENT_SCOPE)
            endif()
            return()
        endif()
        message(STATUS "polyorch thirdparty: ${arg_NAME} stale package artifacts present -- repacking")
    endif()

    # Relocate gate: refuse to write a build-host-pinned prefix into the
    # shared cache (F5 criterion 10).
    _polyorch_tp_relocate_audit("${arg_INSTALL_DIR}" _tp_reloc_ok _tp_reloc_why)
    if(NOT _tp_reloc_ok)
        message(FATAL_ERROR "polyorch_thirdparty_package: '${arg_NAME}' is not relocatable -- ${_tp_reloc_why}. Refusing to write an absolute-path-pinned prefix into the shared package cache (F5 criterion 10; relativize the install tree, or keep the artifact local until O-2 lands).")
    endif()

    # Sidecar-first removal: a crash after pack but before sidecar rewrite must
    # leave an unverifiable pair, not a stale "verified" one.
    file(REMOVE "${_tp_sha_file}" "${_tp_side_mf}")
    execute_process(COMMAND "${CMAKE_COMMAND}" -E tar czf "${_tp_pkgfile}" .
        WORKING_DIRECTORY "${arg_INSTALL_DIR}" RESULT_VARIABLE _tp_rc)
    if(NOT _tp_rc EQUAL 0)
        message(FATAL_ERROR "polyorch_thirdparty_package: packing ${arg_NAME} failed (rc=${_tp_rc})")
    endif()
    file(SHA256 "${_tp_pkgfile}" _tp_sha)
    file(WRITE "${_tp_sha_file}" "${_tp_sha}\n")
    file(WRITE "${_tp_side_mf}" "${_tp_m}")
    message(STATUS "polyorch thirdparty: ${arg_NAME} packed -> ${_tp_pkgname}")
    if(arg_PACKAGE_OUT)
        set(${arg_PACKAGE_OUT} "${_tp_pkgfile}" PARENT_SCOPE)
    endif()
endfunction()

#-----------------------------------------------------------------------------------------------------------------------
# polyorch_thirdparty_import -- consume the upstream's installed config.
#
#   polyorch_thirdparty_import(NAME <n> INSTALL_DIR <d> FIND_PACKAGE_NAME <Pkg>
#     [COMPONENTS <c...>] [PROVIDED_TARGETS <t...>] [ALIAS <Consumer::Name>])
#
# The upstream keeps its own target names (C-D9: SDL3:: stays SDL3::); the
# consumer gets an ALIAS. NO_DEFAULT_PATH is the FIXED posture here (an
# in-repo install prefix must not leak into system finds). A MACRO on
# purpose: find_package(CONFIG) defines imported targets in the scope of
# its caller -- inside a function they would evaporate at return, taking
# the consumer alias with them. Prefix discipline: internals carry _tpi_
# (macros share the caller's scope).
macro(polyorch_thirdparty_import)
    cmake_parse_arguments(_tpi ""
        "NAME;INSTALL_DIR;FIND_PACKAGE_NAME;ALIAS" "COMPONENTS;PROVIDED_TARGETS" ${ARGN})
    if(NOT _tpi_NAME OR NOT _tpi_INSTALL_DIR OR NOT _tpi_FIND_PACKAGE_NAME)
        message(FATAL_ERROR "polyorch_thirdparty_import: NAME, INSTALL_DIR and FIND_PACKAGE_NAME are required")
    endif()
    if(NOT EXISTS "${_tpi_INSTALL_DIR}")
        message(FATAL_ERROR "polyorch_thirdparty_import: INSTALL_DIR '${_tpi_INSTALL_DIR}' does not exist -- build first (this face never auto-builds at import time, H2)")
    endif()
    if(_tpi_COMPONENTS)
        find_package("${_tpi_FIND_PACKAGE_NAME}" COMPONENTS ${_tpi_COMPONENTS} CONFIG REQUIRED
            PATHS "${_tpi_INSTALL_DIR}" NO_DEFAULT_PATH)
    else()
        find_package("${_tpi_FIND_PACKAGE_NAME}" CONFIG REQUIRED
            PATHS "${_tpi_INSTALL_DIR}" NO_DEFAULT_PATH)
    endif()
    if(_tpi_PROVIDED_TARGETS)
        foreach(_tpi_t IN LISTS _tpi_PROVIDED_TARGETS)
            if(NOT TARGET "${_tpi_t}")
                message(FATAL_ERROR "polyorch_thirdparty_import: upstream promised target '${_tpi_t}' but find_package(${_tpi_FIND_PACKAGE_NAME}) did not define it (stale install prefix?)")
            endif()
        endforeach()
    endif()
    if(_tpi_ALIAS)
        if(NOT _tpi_PROVIDED_TARGETS)
            message(FATAL_ERROR "polyorch_thirdparty_import: ALIAS requires PROVIDED_TARGETS (the alias shadows the first provided target)")
        endif()
        list(GET _tpi_PROVIDED_TARGETS 0 _tpi_t0)
        add_library("${_tpi_ALIAS}" ALIAS "${_tpi_t0}")
        message(STATUS "polyorch thirdparty: ${_tpi_NAME} -> alias ${_tpi_ALIAS} (upstream ${_tpi_t0} untouched)")
    endif()
endmacro()

#-----------------------------------------------------------------------------------------------------------------------
# polyorch_thirdparty_recipe -- declarative JSON recipe loader (F11=A).
#
#   polyorch_thirdparty_recipe(RECIPE <file.json> [RECIPE_BASE <dir>]
#     WORK_DIR <d> BUILD_TYPE <cfg> [PROFILE <p>] [TRIPLET <t>]
#     [GENERATOR <g>] [PARALLEL <n>]
#     [PACKAGES_DIR <d>] [PACKAGE_FORMAT tar.gz]    (P2; empty dir = no packing)
#     [SOURCE_DIR_OUT <var>] [INSTALL_DIR_OUT <var>] [FINGERPRINT_OUT <var>]
#     [MANIFEST_OUT <var>] [PACKAGE_OUT <var>]
#     [FIND_PACKAGE_NAME_OUT <var>] [ALIAS_OUT <var>]
#     [COMPONENTS_OUT <var>] [TARGETS_OUT <var>])
#
# JSON carries static facts only (version/url/hashes/patches/profile option
# tables/find_package/alias/license); dynamic decisions ("probe the system,
# then pick a profile") stay at the consumer call site -- never in the
# loader. Schema v1 required fields: schema_version(==1), name, version,
# provider, license, url, url_hash; optional: patches[{path,sha256}],
# profiles{<p>{<OPT>:<v>}}, link_mode, find_package{name,components,targets},
# alias. Import stays a separate verb (this loader returns the wiring).
function(polyorch_thirdparty_recipe)
    cmake_parse_arguments(arg ""
        "RECIPE;RECIPE_BASE;WORK_DIR;BUILD_TYPE;PROFILE;TRIPLET;GENERATOR;PARALLEL;PACKAGES_DIR;PACKAGE_FORMAT;SOURCE_DIR_OUT;INSTALL_DIR_OUT;FINGERPRINT_OUT;MANIFEST_OUT;PACKAGE_OUT;FIND_PACKAGE_NAME_OUT;ALIAS_OUT;COMPONENTS_OUT;TARGETS_OUT" "" ${ARGN})
    if(NOT arg_RECIPE OR NOT arg_WORK_DIR OR NOT arg_BUILD_TYPE)
        message(FATAL_ERROR "polyorch_thirdparty_recipe: RECIPE, WORK_DIR and BUILD_TYPE are required (BUILD_TYPE explicit: O-3)")
    endif()
    if(NOT arg_RECIPE_BASE)
        cmake_path(GET arg_RECIPE PARENT_PATH arg_RECIPE_BASE)
    endif()
    if(NOT EXISTS "${arg_RECIPE}")
        message(FATAL_ERROR "polyorch_thirdparty_recipe: recipe '${arg_RECIPE}' does not exist")
    endif()
    file(READ "${arg_RECIPE}" _tp_json)

    # ---- schema gate (v1) ----
    # NOTE: string(JSON)'s ERROR_VARIABLE only catches JSON *parse* errors;
    # a missing member is a HARD error that kills the script (measured), so
    # presence is probed on the raw text first and only present members are
    # ever read. Cmake regexes carry no {n} and no \s: the key probe is
    # "key"[ ]*: (a real JSON key never has a newline between key and colon).
    foreach(_tp_f IN ITEMS schema_version name version provider license url url_hash)
        if(NOT "${_tp_json}" MATCHES "\"${_tp_f}\"[ ]*:")
            message(FATAL_ERROR "polyorch_thirdparty_recipe: schema violation in ${arg_RECIPE}: required field '${_tp_f}' missing")
        endif()
    endforeach()
    string(JSON _tp_schema GET "${_tp_json}" schema_version)
    if(NOT _tp_schema VERSION_EQUAL 1)
        message(FATAL_ERROR "polyorch_thirdparty_recipe: recipe schema_version ${_tp_schema} is newer than this loader (knows v1) -- upgrade PolyOrch")
    endif()
    string(JSON _tp_name GET "${_tp_json}" name)
    string(JSON _tp_version GET "${_tp_json}" version)
    string(JSON _tp_provider GET "${_tp_json}" provider)
    string(JSON _tp_license GET "${_tp_json}" license)
    string(JSON _tp_url GET "${_tp_json}" url)
    string(JSON _tp_urlhash GET "${_tp_json}" url_hash)

    # ---- provider seams (code-level, F2=A) ----
    if(_tp_provider STREQUAL "vcpkg" OR _tp_provider STREQUAL "conan")
        message(FATAL_ERROR "polyorch_thirdparty_recipe: provider '${_tp_provider}' is reserved but not implemented -- it lands with the P7 provider face; prerequisites: O-10 (in-repo pinning) + O-11 (single cache truth) + PolyOrch O4. Until then ship the library as a pinned source archive (provider \"source\").")
    endif()
    if(_tp_provider STREQUAL "prebuilt" OR _tp_provider STREQUAL "system")
        message(FATAL_ERROR "polyorch_thirdparty_recipe: provider '${_tp_provider}' is not a source recipe -- package caching for source builds is PACKAGES_DIR (P2); direct prebuilt/system intake arrives with the consumer lanes (P3+)")
    endif()
    if(NOT _tp_provider STREQUAL "source")
        message(FATAL_ERROR "polyorch_thirdparty_recipe: unknown provider '${_tp_provider}' (schema v1: source; vcpkg/conan = P7 seam; prebuilt/system = P3+ seam)")
    endif()

    file(SHA256 "${arg_RECIPE}" _tp_recipe_hash)

    # ---- patches ----
    set(_tp_patches "")
    set(_tp_patch_shas "")
    if("${_tp_json}" MATCHES "\"patches\"[ ]*:")
        string(JSON _tp_np LENGTH "${_tp_json}" patches)
        math(EXPR _tp_i "0" OUTPUT_FORMAT DECIMAL)
        while(_tp_i LESS _tp_np)
            string(JSON _tp_ppath GET "${_tp_json}" patches ${_tp_i} path)
            string(JSON _tp_psha GET "${_tp_json}" patches ${_tp_i} sha256)
            if(NOT IS_ABSOLUTE "${_tp_ppath}")
                set(_tp_ppath "${arg_RECIPE_BASE}/${_tp_ppath}")
            endif()
            list(APPEND _tp_patches "${_tp_ppath}")
            list(APPEND _tp_patch_shas "${_tp_psha}")
            math(EXPR _tp_i "${_tp_i} + 1" OUTPUT_FORMAT DECIMAL)
        endwhile()
    endif()

    # ---- profile options ----
    set(_tp_opts "")
    if(arg_PROFILE)
        if(NOT "${_tp_json}" MATCHES "\"profiles\"[ ]*:")
            message(FATAL_ERROR "polyorch_thirdparty_recipe: PROFILE '${arg_PROFILE}' requested but the recipe has no profiles table")
        endif()
        if(NOT "${_tp_json}" MATCHES "\"${arg_PROFILE}\"[ ]*:")
            message(FATAL_ERROR "polyorch_thirdparty_recipe: recipe has no profile '${arg_PROFILE}' (known: see recipe JSON)")
        endif()
        # member enumeration: object-length + MEMBER(<index>) walk
        # (v1 recipes are small; no reflection beyond the pair).
        string(JSON _tp_nprof LENGTH "${_tp_json}" "profiles" "${arg_PROFILE}")
        set(_tp_mi 0)
        while(_tp_mi LESS _tp_nprof)
            string(JSON _tp_mk MEMBER "${_tp_json}" "profiles" "${arg_PROFILE}" ${_tp_mi})
            string(JSON _tp_mv GET "${_tp_json}" "profiles" "${arg_PROFILE}" "${_tp_mk}")
            list(APPEND _tp_opts "${_tp_mk}=${_tp_mv}")
            math(EXPR _tp_mi "${_tp_mi} + 1" OUTPUT_FORMAT DECIMAL)
        endwhile()
    endif()

    # ---- acquire (verified) ----
    if(NOT IS_ABSOLUTE "${_tp_url}")
        set(_tp_url "${arg_RECIPE_BASE}/${_tp_url}")
    endif()
    polyorch_thirdparty_fetch(NAME "${_tp_name}" URL "${_tp_url}" URL_HASH "SHA256=${_tp_urlhash}"
        PATCHES ${_tp_patches} PATCH_SHA256 ${_tp_patch_shas}
        OUTPUT_DIR "${arg_WORK_DIR}"
        SOURCE_DIR_OUT _tp_src ARCHIVE_SHA256_OUT _tp_arch_hash)

    # ---- fingerprint (recipe itself is a key input, M1) ----
    set(_tp_link "")
    if("${_tp_json}" MATCHES "\"link_mode\"[ ]*:")
        string(JSON _tp_link GET "${_tp_json}" link_mode)
    endif()
    polyorch_thirdparty_fingerprint(_tp_key
        ARCHIVE_SHA256 "${_tp_arch_hash}" BUILD_TYPE "${arg_BUILD_TYPE}"
        VERSION "${_tp_version}" PROFILE "${arg_PROFILE}" TRIPLET "${arg_TRIPLET}" LINK_MODE "${_tp_link}"
        OPTIONS ${_tp_opts} RECIPE_SHA256 "${_tp_recipe_hash}" SCHEMA_VERSION "${_tp_schema}")

    # ---- layout + cache verdict (manifest identity, NOT existence -- the
    # QExt/CxxKit stamp check upgraded here; same key -> same content at the
    # manifest level, r4 L8) ----
    set(_tp_builddir "${arg_WORK_DIR}/${_tp_name}/build-${arg_BUILD_TYPE}")
    set(_tp_installdir "${arg_WORK_DIR}/${_tp_name}/install-${arg_BUILD_TYPE}")
    set(_tp_manifest "${_tp_installdir}/polyorch-thirdparty-manifest.json")
    set(_tp_hit FALSE)
    if(EXISTS "${_tp_manifest}")
        file(READ "${_tp_manifest}" _tp_mold)
        string(JSON _tp_oldkey ERROR_VARIABLE _tp_e GET "${_tp_mold}" key)
        if(_tp_oldkey STREQUAL "${_tp_key}")
            set(_tp_hit TRUE)
        endif()
    endif()
    if(_tp_hit)
        message(STATUS "polyorch thirdparty: ${_tp_name} cache hit key=${_tp_key_SHORT12} build_type=${arg_BUILD_TYPE} -- acquire/build skipped (manifest identity)")
    else()
        # ---- package cache (P2): unpack beats build; verdict = sidecar
        # identity (sha256 pair + manifest key), never file existence ----
        set(_tp_pkgfile "")
        set(_tp_pkg_hit FALSE)
        set(_tp_pkgfmt "tar.gz")
        if(arg_PACKAGE_FORMAT)
            set(_tp_pkgfmt "${arg_PACKAGE_FORMAT}")
        endif()
        if(arg_PACKAGES_DIR)
            _polyorch_tp_package_name(_tp_pkgname "${_tp_name}" "${_tp_version}" "${arg_TRIPLET}" "${arg_PROFILE}" "${arg_BUILD_TYPE}" "${_tp_link}" "${_tp_key_SHORT12}" "${_tp_pkgfmt}")
            set(_tp_pkgfile "${arg_PACKAGES_DIR}/${_tp_pkgname}")
            if(EXISTS "${_tp_pkgfile}")
                set(_tp_sha_file "${_tp_pkgfile}.sha256")
                set(_tp_side_mf "${_tp_pkgfile}.manifest.json")
                if(NOT EXISTS "${_tp_sha_file}" OR NOT EXISTS "${_tp_side_mf}")
                    message(FATAL_ERROR "polyorch_thirdparty_recipe: package '${_tp_pkgname}' has no sidecar pair (.sha256 + .manifest.json) -- a package without provenance cannot be trusted")
                endif()
                file(SHA256 "${_tp_pkgfile}" _tp_actual)
                file(READ "${_tp_sha_file}" _tp_recorded)
                string(STRIP "${_tp_recorded}" _tp_recorded)
                if(NOT _tp_actual STREQUAL "${_tp_recorded}")
                    message(FATAL_ERROR "polyorch_thirdparty_recipe: package '${_tp_pkgname}' sha256 mismatch (recorded '${_tp_recorded}', actual '${_tp_actual}') -- refusing to unpack")
                endif()
                file(READ "${_tp_side_mf}" _tp_sm)
                if(NOT "${_tp_sm}" MATCHES "\"key\"[ ]*:")
                    message(FATAL_ERROR "polyorch_thirdparty_recipe: sidecar manifest of '${_tp_pkgname}' carries no key -- refusing to unpack")
                endif()
                string(JSON _tp_skey GET "${_tp_sm}" key)
                if(NOT _tp_skey STREQUAL "${_tp_key}")
                    message(FATAL_ERROR "polyorch_thirdparty_recipe: package '${_tp_pkgname}' sidecar key '${_tp_skey}' != current key '${_tp_key}' -- refusing to unpack")
                endif()
                file(MAKE_DIRECTORY "${_tp_installdir}")
                execute_process(COMMAND "${CMAKE_COMMAND}" -E tar xzf "${_tp_pkgfile}"
                    WORKING_DIRECTORY "${_tp_installdir}" RESULT_VARIABLE _tp_urc)
                if(NOT _tp_urc EQUAL 0)
                    message(FATAL_ERROR "polyorch_thirdparty_recipe: unpacking '${_tp_pkgname}' failed (rc=${_tp_urc})")
                endif()
                if(NOT EXISTS "${_tp_manifest}")
                    message(FATAL_ERROR "polyorch_thirdparty_recipe: package '${_tp_pkgname}' extracted but carries no install manifest -- corrupt package")
                endif()
                set(_tp_pkg_hit TRUE)
                message(STATUS "polyorch thirdparty: ${_tp_name} package cache hit key=${_tp_key_SHORT12} build_type=${arg_BUILD_TYPE} -- zero build")
            endif()
        endif()
        if(NOT _tp_pkg_hit)
            # ---- build (explicit verb, H2) ----
            set(_tp_cmake_args "")
            foreach(_tp_o IN LISTS _tp_opts)
                list(APPEND _tp_cmake_args "-D${_tp_o}")
            endforeach()
            polyorch_thirdparty_build(NAME "${_tp_name}" SOURCE_DIR "${_tp_src}"
                BUILD_DIR "${_tp_builddir}" INSTALL_DIR "${_tp_installdir}"
                BUILD_TYPE "${arg_BUILD_TYPE}" GENERATOR "${arg_GENERATOR}"
                PARALLEL "${arg_PARALLEL}" CMAKE_ARGS ${_tp_cmake_args})

            # ---- manifest ----
            polyorch_thirdparty_manifest_write(MANIFEST "${_tp_manifest}" KEY "${_tp_key}"
                NAME "${_tp_name}" VERSION "${_tp_version}" LICENSE "${_tp_license}"
                PROVIDER "${_tp_provider}" PROFILE "${arg_PROFILE}" TRIPLET "${arg_TRIPLET}"
                BUILD_TYPE "${arg_BUILD_TYPE}"
                LINK_MODE "${_tp_link}" OPTIONS ${_tp_opts} ARCHIVE_SHA256 "${_tp_arch_hash}"
                RECIPE_SHA256 "${_tp_recipe_hash}" SCHEMA_VERSION "${_tp_schema}")

            # ---- pack into the shared cache (P2; empty dir = no-op) ----
            if(arg_PACKAGES_DIR)
                polyorch_thirdparty_package(NAME "${_tp_name}" INSTALL_DIR "${_tp_installdir}"
                    PACKAGE_DIR "${arg_PACKAGES_DIR}" MANIFEST "${_tp_manifest}"
                    FORMAT "${_tp_pkgfmt}" TRIPLET "${arg_TRIPLET}" PACKAGE_OUT _tp_pkgfile)
            endif()
        endif()
    endif()

    # ---- wiring out (import stays a separate verb) ----
    if(arg_SOURCE_DIR_OUT)
        set(${arg_SOURCE_DIR_OUT} "${_tp_src}" PARENT_SCOPE)
    endif()
    if(arg_INSTALL_DIR_OUT)
        set(${arg_INSTALL_DIR_OUT} "${_tp_installdir}" PARENT_SCOPE)
    endif()
    if(arg_FINGERPRINT_OUT)
        set(${arg_FINGERPRINT_OUT} "${_tp_key}" PARENT_SCOPE)
    endif()
    if(arg_MANIFEST_OUT)
        set(${arg_MANIFEST_OUT} "${_tp_manifest}" PARENT_SCOPE)
    endif()
    if(arg_PACKAGE_OUT)
        set(${arg_PACKAGE_OUT} "${_tp_pkgfile}" PARENT_SCOPE)
    endif()
    set(_tp_fp_name "")
    set(_tp_fp_comps "")
    set(_tp_fp_targets "")
    if("${_tp_json}" MATCHES "\"find_package\"[ ]*:")
        string(JSON _tp_fp_name GET "${_tp_json}" find_package name)
        if("${_tp_json}" MATCHES "\"components\"[ ]*:")
            string(JSON _tp_nc LENGTH "${_tp_json}" find_package components)
            if(NOT _tp_nc EQUAL 0)
                set(_tp_ci 0)
                while(_tp_ci LESS _tp_nc)
                    string(JSON _tp_c GET "${_tp_json}" find_package components ${_tp_ci})
                    list(APPEND _tp_fp_comps "${_tp_c}")
                    math(EXPR _tp_ci "${_tp_ci} + 1" OUTPUT_FORMAT DECIMAL)
                endwhile()
            endif()
        endif()
        if("${_tp_json}" MATCHES "\"targets\"[ ]*:")
            string(JSON _tp_nt LENGTH "${_tp_json}" find_package targets)
            if(NOT _tp_nt EQUAL 0)
                set(_tp_ti 0)
                while(_tp_ti LESS _tp_nt)
                    string(JSON _tp_t GET "${_tp_json}" find_package targets ${_tp_ti})
                    list(APPEND _tp_fp_targets "${_tp_t}")
                    math(EXPR _tp_ti "${_tp_ti} + 1" OUTPUT_FORMAT DECIMAL)
                endwhile()
            endif()
        endif()
    endif()
    if(arg_FIND_PACKAGE_NAME_OUT)
        set(${arg_FIND_PACKAGE_NAME_OUT} "${_tp_fp_name}" PARENT_SCOPE)
    endif()
    if(arg_COMPONENTS_OUT)
        set(${arg_COMPONENTS_OUT} "${_tp_fp_comps}" PARENT_SCOPE)
    endif()
    if(arg_TARGETS_OUT)
        set(${arg_TARGETS_OUT} "${_tp_fp_targets}" PARENT_SCOPE)
    endif()
    if(arg_ALIAS_OUT)
        set(_tp_alias "")
        if("${_tp_json}" MATCHES "\"alias\"[ ]*:")
            string(JSON _tp_alias GET "${_tp_json}" alias)
        endif()
        set(${arg_ALIAS_OUT} "${_tp_alias}" PARENT_SCOPE)
    endif()
endfunction()
