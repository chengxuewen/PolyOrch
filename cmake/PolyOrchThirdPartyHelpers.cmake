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
#   * provider prebuilt/system    -> FATAL pointing at the package-cache face (P2)
#   * DEPENDENCY_PROVIDER sysroot -> FATAL pointing at P6
# Ecosystem providers LANDED: vcpkg (P7a -- pin island + strict-first gate +
# an opt-in GENERATE_ECOSYSTEM generate) and conan (P7b -- same shape: island
# of conanfile+lock, a profile GENERATED from cmake facts, the tool island
# solved into the anchor, direct_deploy consumed through the upstream's own
# CMake config). Both are still behind the strict gate: without a pre-baked
# artifact nothing is downloaded unless the caller asks for it.
# (r8/r9: the header used to list provider vcpkg/conan as FATAL seams; that
# drifted while the lanes landed -- the listing IS the contract, keep it true.)
# Dependency providers (P4): none (no injection at all), system (sanitize
#   only), pixi (NO-ACTIVATION: the environment's include/lib/pkgconfig
#   SUB-paths are injected into the child env only -- never a bare prefix
#   carrying bin/, r4 C1; the inner configure must receive an explicit
#   compiler or a toolchain file; CPATH/C_INCLUDE_PATH/CPLUS_INCLUDE_PATH/
#   LIBRARY_PATH/COMPILER_PATH/CONDA_PREFIX are unset in the child; the
#   pixi.lock hash rides the cache key; installed binaries get a readelf -d
#   audit because static linking is NOT runtime independence). Nothing in
#   this face may pick a compiler behind the caller's back.
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

# _polyorch_tp_module_dir -- the repository root this face's own data lives in
# (the pkg-deps/ tool islands).
# CMake variable scope is DYNAMIC: inside a function CMAKE_CURRENT_LIST_DIR is
# the file being processed -- the caller's -P script, not this module (PIT-10,
# re-hit in the conan stroke; measured again on 4.4.3 in script mode: LIST_DIR
# = the caller's directory, FUNCTION_LIST_DIR = the defining file's). Use
# CMAKE_CURRENT_FUNCTION_LIST_DIR, which is exactly the defining file's
# directory -- no global state and no dependence on include order. A call-site
# override stays available for unusual layouts.
function(_polyorch_tp_module_dir out)
    set(_tp_root "${PolyOrch_THIRDPARTY_ROOT}")
    if(NOT _tp_root)
        get_filename_component(_tp_root "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/.." ABSOLUTE)
    endif()
    if(NOT IS_DIRECTORY "${_tp_root}/pkg-deps")
        message(FATAL_ERROR "_polyorch_tp_module_dir: no pkg-deps/ under '${_tp_root}' -- this module's own location cannot be resolved (set PolyOrch_THIRDPARTY_ROOT for an unusual layout)")
    endif()
    set(${out} "${_tp_root}" PARENT_SCOPE)
endfunction()

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
# _polyorch_tp_pin_hash -- content fingerprint of a per-library pin island
# (O-10=A): the island IS the reproducibility anchor, so its bytes ride the
# cache key. A vcpkg island carries vcpkg.json (the baseline INSIDE it -- the
# official builtin-baseline field; a separate baseline file would be a second
# copy that can drift); a conan island carries conanfile.txt (or conanfile.py)
# PLUS conan.lock -- without the lock the versions float and every run may
# resolve differently, so the lock is mandatory here (P7b). Fixed file order:
# the hash must be stable across runs/hosts. An island MAY hold both providers'
# files (r9a H2): the file set is selected by provider and the other lane's
# files stay unread, so a recipe switches provider by editing one line while
# pin_dir keeps pointing at the same directory.
function(_polyorch_tp_pin_hash pin_dir provider out)
    set(_tp_files "")
    if(provider STREQUAL "vcpkg")
        set(_tp_files "vcpkg.json")
    elseif(provider STREQUAL "conan")
        if(EXISTS "${pin_dir}/conanfile.py")
            set(_tp_files "conanfile.py")
        else()
            set(_tp_files "conanfile.txt")
        endif()
        list(APPEND _tp_files "conan.lock")
    else()
        message(FATAL_ERROR "_polyorch_tp_pin_hash: unknown ecosystem provider '${provider}' (vcpkg, conan)")
    endif()
    set(_tp_cat "")
    foreach(_tp_f IN LISTS _tp_files)
        if(NOT EXISTS "${pin_dir}/${_tp_f}")
            set(_tp_hint "a vcpkg island = one vcpkg.json with the builtin-baseline embedded")
            if(provider STREQUAL "conan")
                set(_tp_hint "a conan island = conanfile.txt (or conanfile.py) plus conan.lock -- generate the lock once (conan lock create ...) and commit it; an island without it resolves floating versions per run")
            endif()
            message(FATAL_ERROR "_polyorch_tp_pin_hash: pin island '${pin_dir}' misses '${_tp_f}' (${_tp_hint}; commit it beside the recipe)")
        endif()
        file(READ "${pin_dir}/${_tp_f}" _tp_c)
        string(APPEND _tp_cat "=== ${_tp_f} ===\n${_tp_c}\n")
    endforeach()
    string(SHA256 _tp_h "${_tp_cat}")
    set(${out} "${_tp_h}" PARENT_SCOPE)
endfunction()

#-----------------------------------------------------------------------------------------------------------------------
# _polyorch_tp_ecosystem_triplet -- supplier-derived triplet (O-12=C):
# call-site TRIPLET override > PolyOrch_VCPKG_TRIPLET (when the platform
# face is loaded) > self-derived from the host facts. Script mode (cmake -P)
# never initializes CMAKE_SYSTEM_* (measured on 4.4: empty until a project()
# runs) -- the derivation chain falls back to CMAKE_HOST_* and finally
# uname -m, the same source cmake itself asks. The static link mode appends
# "-static" (an overlay triplet the generate step writes); static-on-windows
# is refused (vcpkg guidance: static CRT).
function(_polyorch_tp_ecosystem_triplet out link_mode override)
    set(_tp_t "${override}")
    if(NOT _tp_t AND DEFINED PolyOrch_VCPKG_TRIPLET)
        set(_tp_t "${PolyOrch_VCPKG_TRIPLET}")
    endif()
    if(NOT _tp_t)
        set(_tp_proc "${CMAKE_SYSTEM_PROCESSOR}")
        if(NOT _tp_proc)
            set(_tp_proc "${CMAKE_HOST_SYSTEM_PROCESSOR}")
        endif()
        if(NOT _tp_proc AND UNIX)
            execute_process(COMMAND uname -m OUTPUT_VARIABLE _tp_uname OUTPUT_STRIP_TRAILING_WHITESPACE)
            set(_tp_proc "${_tp_uname}")
        endif()
        string(TOLOWER "${_tp_proc}" _tp_proc)
        if(_tp_proc MATCHES "^(x86_64|amd64)$")
            set(_tp_proc "x64")
        elseif(_tp_proc MATCHES "^(aarch64|arm64)$")
            set(_tp_proc "arm64")
        else()
            message(FATAL_ERROR "_polyorch_tp_ecosystem_triplet: cannot map processor '${_tp_proc}' into the vcpkg vocabulary -- pass TRIPLET explicitly")
        endif()
        set(_tp_sys "${CMAKE_SYSTEM_NAME}")
        if(NOT _tp_sys)
            set(_tp_sys "${CMAKE_HOST_SYSTEM_NAME}")
        endif()
        if(_tp_sys STREQUAL "Linux")
            set(_tp_sys "linux")
        elseif(_tp_sys STREQUAL "Darwin")
            set(_tp_sys "osx")
        elseif(_tp_sys MATCHES "Windows" OR WIN32)
            set(_tp_sys "windows")
        else()
            message(FATAL_ERROR "_polyorch_tp_ecosystem_triplet: unsupported system name '${_tp_sys}' -- pass TRIPLET explicitly")
        endif()
        set(_tp_t "${_tp_proc}-${_tp_sys}")
    endif()
    if("${link_mode}" STREQUAL "static")
        if(_tp_t MATCHES "windows$")
            message(FATAL_ERROR "_polyorch_tp_ecosystem_triplet: static link_mode on a windows triplet is refused (vcpkg guidance: static CRT) -- use dynamic or an explicit TRIPLET override")
        endif()
        if(NOT _tp_t MATCHES "-static$")
            string(APPEND _tp_t "-static")
        endif()
    endif()
    set(${out} "${_tp_t}" PARENT_SCOPE)
endfunction()

#-----------------------------------------------------------------------------------------------------------------------
# _polyorch_tp_vcpkg_env -- the pinned environment for every vcpkg child
# process (O-11=A discipline 3): downloads and the binary cache live INSIDE
# the work anchor as ephemeral acceleration -- never keyed, never the verdict.
#
# Two measured facts shape this list:
#  * VCPKG_FORCE_SYSTEM_BINARIES is NOT set. It converts vcpkg's normal
#    self-sufficiency (it fetches its own cmake/ninja, verified by tag+sha)
#    into a hard host requirement -- on a box without ninja the compiler
#    detection dies outright (measured: detect_compiler rc!=0, while the same
#    install with no injection succeeds). None of QExt/CxxKit/OpenCTK sets it.
#  * VCPKG_DEFAULT_BINARY_CACHE must point at an EXISTING directory (measured:
#    "must be a directory"), so both anchor directories are created here --
#    the strict gate prints these very assignments as a copy-paste command and
#    that command has to run as printed.
#
# binary_cache controls only HOW FAST, never WHAT: off (default) keeps
# VCPKG_BINARY_SOURCES=clear (pure source build per generate); on points the
# files cache at the anchor. Stale-hit safety is vcpkg's own problem -- its
# cache entries are keyed by compiler hash + port version (measured: cache
# submissions name zlib:x64-linux@1.3.2#2), so an upgraded compiler misses.
function(_polyorch_tp_vcpkg_env work_dir out binary_cache)
    set(_tp_dl "${work_dir}/vcpkg-downloads")
    set(_tp_bc "${work_dir}/vcpkg-binary")
    file(MAKE_DIRECTORY "${_tp_dl}" "${_tp_bc}")
    set(_tp_src "clear")
    if(binary_cache)
        set(_tp_src "files,${_tp_bc},readwrite")
    endif()
    set(${out}
        "VCPKG_DOWNLOADS=${_tp_dl}"
        "VCPKG_DEFAULT_BINARY_CACHE=${_tp_bc}"
        "VCPKG_BINARY_SOURCES=${_tp_src}"
        "VCPKG_DISABLE_METRICS=1"
        "VCPKG_MAX_CONCURRENCY=2"
        PARENT_SCOPE)
endfunction()

#-----------------------------------------------------------------------------------------------------------------------
# _polyorch_tp_conan_profile -- the conan profile is GENERATED from cmake
# facts (O-12=C), never from `conan profile detect`: detect answers "what is
# this machine", this lane needs "what did this build decide" -- the two can
# disagree (a compiler detect found next to the one the caller chose), and a
# silent disagreement is exactly the drift this face refuses.
#
# The emitted shape mirrors what detect produces on this host (measured with
# 2.32: os/arch/build_type/compiler/compiler.version/compiler.libcxx and a
# compiler.cppstd line). Vocabulary is conan's, not cmake's (measured): gcc is
# "gcc", macOS is "Mac", arm64 is "armv8".
#
# Two deliberate abstentions:
#  * compiler.cppstd is written ONLY when the caller states it
#    (PolyOrch_CONAN_CPPSTD). Guessing a compiler's default standard would be
#    fake precision, and conan already falls back to the compiler default when
#    the setting is absent -- the honest default is "unset", not "gnu17".
#  * compiler.libcxx defaults to libstdc++11 for gcc/clang on Linux (the
#    measured detect value) and is overridable; any other combination is
#    refused instead of assumed. msvc has no libcxx setting, so none is
#    written for it.
# Script mode leaves CMAKE_SYSTEM_*/CMAKE_CXX_COMPILER_* empty (measured, the
# P7a triplet lesson), so every fact falls back: explicit argument/cache
# variable > cmake variable > probe the compiler binary -- and refuses loudly
# when nothing can answer.
function(_polyorch_tp_conan_profile out_file out_name out_hash work_dir build_type)
    set(_tp_name "polyorch-${build_type}")
    string(TOLOWER "${_tp_name}" _tp_name)

    # ---- os / arch (conan vocabulary, host facts with script-mode fallback) ----
    set(_tp_proc "${CMAKE_SYSTEM_PROCESSOR}")
    if(NOT _tp_proc)
        set(_tp_proc "${CMAKE_HOST_SYSTEM_PROCESSOR}")
    endif()
    if(NOT _tp_proc AND UNIX)
        execute_process(COMMAND uname -m OUTPUT_VARIABLE _tp_u OUTPUT_STRIP_TRAILING_WHITESPACE)
        set(_tp_proc "${_tp_u}")
    endif()
    string(TOLOWER "${_tp_proc}" _tp_proc)
    if(_tp_proc MATCHES "^(x86_64|amd64)$")
        set(_tp_arch "x86_64")
    elseif(_tp_proc MATCHES "^(aarch64|arm64)$")
        set(_tp_arch "armv8")
    else()
        message(FATAL_ERROR "_polyorch_tp_conan_profile: cannot map processor '${_tp_proc}' into conan's vocabulary (x86_64/armv8) -- the lane will not guess a cross target")
    endif()
    set(_tp_sys "${CMAKE_SYSTEM_NAME}")
    if(NOT _tp_sys)
        set(_tp_sys "${CMAKE_HOST_SYSTEM_NAME}")
    endif()
    if(_tp_sys STREQUAL "Linux")
        set(_tp_os "Linux")
    elseif(_tp_sys STREQUAL "Darwin")
        set(_tp_os "Mac")
    elseif(_tp_sys MATCHES "Windows" OR WIN32)
        set(_tp_os "Windows")
    else()
        message(FATAL_ERROR "_polyorch_tp_conan_profile: unsupported system '${_tp_sys}' for conan (Linux/Mac/Windows)")
    endif()

    # ---- compiler id / version / path ----
    set(_tp_cid "${PolyOrch_CONAN_COMPILER_ID}")
    if(NOT _tp_cid AND CMAKE_CXX_COMPILER_ID)
        set(_tp_cid "${CMAKE_CXX_COMPILER_ID}")
    endif()
    set(_tp_cxx "${PolyOrch_CONAN_COMPILER}")
    if(NOT _tp_cxx AND CMAKE_CXX_COMPILER)
        set(_tp_cxx "${CMAKE_CXX_COMPILER}")
    endif()
    if(NOT _tp_cid)
        if(NOT _tp_cxx)
            message(FATAL_ERROR "_polyorch_tp_conan_profile: no compiler to derive the profile from -- cmake reports no CMAKE_CXX_COMPILER_ID (script mode) and PolyOrch_CONAN_COMPILER is unset. Pass PolyOrch_CONAN_COMPILER <path> (and optionally PolyOrch_CONAN_COMPILER_ID/_VERSION): this lane never picks a compiler behind the caller's back.")
        endif()
        # Ask the binary; do not read its name. The commonest
        # CMAKE_CXX_COMPILER value is literally "c++" -- a symlink to g++ on
        # Debian/Ubuntu and to clang++ on macOS -- so name-based inference
        # mislabels exactly the default case (measured: /usr/bin/c++
        # --version reports GCC 11.4.0, while the name matches neither
        # g++/gcc nor clang).
        execute_process(COMMAND "${_tp_cxx}" --version OUTPUT_VARIABLE _tp_vv ERROR_QUIET)
        if(_tp_vv MATCHES "clang")
            set(_tp_cid "clang")
            if(_tp_os STREQUAL "Mac")
                set(_tp_cid "apple-clang")
            endif()
        elseif(_tp_vv MATCHES "GNU|gcc|g\\+\\+|Free Software Foundation")
            # the FSF copyright line is not decoration: invoked through the
            # plain "c++" symlink the output carries NO GNU/gcc/g++ token at
            # all (measured: "c++ (Ubuntu 11.4.0-1ubuntu1~22.04.3) 11.4.0"),
            # so matching only the familiar words silently fails on the
            # commonest compiler path on Linux.
            set(_tp_cid "gcc")
        else()
            message(FATAL_ERROR "_polyorch_tp_conan_profile: cannot name a conan compiler id from '${_tp_cxx} --version' output -- set PolyOrch_CONAN_COMPILER_ID (gcc/clang/apple-clang/msvc); guessing a compiler is not this lane's job")
        endif()
    endif()
    set(_tp_map "")
    if(_tp_cid STREQUAL "GNU")
        set(_tp_map "gcc")
    elseif(_tp_cid STREQUAL "Clang")
        set(_tp_map "clang")
    elseif(_tp_cid STREQUAL "AppleClang")
        set(_tp_map "apple-clang")
    elseif(_tp_cid STREQUAL "MSVC")
        set(_tp_map "msvc")
    elseif(_tp_cid MATCHES "^(gcc|clang|apple-clang|msvc)$")
        set(_tp_map "${_tp_cid}")
    else()
        message(FATAL_ERROR "_polyorch_tp_conan_profile: compiler id '${_tp_cid}' has no conan counterpart (gcc/clang/apple-clang/msvc)")
    endif()
    set(_tp_cver "${PolyOrch_CONAN_COMPILER_VERSION}")
    if(NOT _tp_cver AND CMAKE_CXX_COMPILER_VERSION)
        set(_tp_cver "${CMAKE_CXX_COMPILER_VERSION}")
    endif()
    if(NOT _tp_cver)
        if(NOT _tp_cxx OR NOT EXISTS "${_tp_cxx}")
            message(FATAL_ERROR "_polyorch_tp_conan_profile: cannot determine the compiler version and no compiler binary to ask -- set PolyOrch_CONAN_COMPILER_VERSION")
        endif()
        execute_process(COMMAND "${_tp_cxx}" --version OUTPUT_VARIABLE _tp_vv ERROR_QUIET)
        string(REGEX MATCH "[0-9][0-9]*\\.[0-9]" _tp_vv "${_tp_vv}")
        if(NOT _tp_vv)
            message(FATAL_ERROR "_polyorch_tp_conan_profile: '${_tp_cxx} --version' yielded no parsable version")
        endif()
        string(REGEX MATCH "^[0-9]*" _tp_cver "${_tp_vv}")
    endif()

    # ---- the INI ----
    set(_tp_ini "[settings]\n")
    string(APPEND _tp_ini "os=${_tp_os}\narch=${_tp_arch}\nbuild_type=${build_type}\n")
    string(APPEND _tp_ini "compiler=${_tp_map}\ncompiler.version=${_tp_cver}\n")
    if(NOT _tp_map STREQUAL "msvc")
        set(_tp_libcxx "${PolyOrch_CONAN_LIBCXX}")
        if(NOT _tp_libcxx)
            if(_tp_os STREQUAL "Linux")
                set(_tp_libcxx "libstdc++11")
            else()
                message(FATAL_ERROR "_polyorch_tp_conan_profile: compiler.libcxx is required for ${_tp_map} on ${_tp_os} and this lane will not assume it -- set PolyOrch_CONAN_LIBCXX (e.g. libc++ on macOS)")
            endif()
        endif()
        string(APPEND _tp_ini "compiler.libcxx=${_tp_libcxx}\n")
    endif()
    if(PolyOrch_CONAN_CPPSTD)
        string(APPEND _tp_ini "compiler.cppstd=${PolyOrch_CONAN_CPPSTD}\n")
    endif()

    set(_tp_file "${work_dir}/profiles/${_tp_name}.ini")
    file(MAKE_DIRECTORY "${work_dir}/profiles")
    file(WRITE "${_tp_file}" "${_tp_ini}")
    string(SHA256 _tp_h "${_tp_ini}")
    set(${out_file} "${_tp_file}" PARENT_SCOPE)
    set(${out_name} "${_tp_name}" PARENT_SCOPE)
    set(${out_hash} "${_tp_h}" PARENT_SCOPE)
endfunction()

#-----------------------------------------------------------------------------------------------------------------------
# _polyorch_tp_conan_tool -- the conan executable, four rungs, plus its
# version (the version is what rides the cache key; the resolved pixi.lock
# hash does NOT, because a lock embeds host virtual packages and would bind
# artifact identity to this machine -- r9/r9a).
#
# C1 discipline: this NEVER calls polyorch_pixi_setup / polyorch_pixi_env_paths
# -- those bind the single-value PolyOrch_PIXI_MANIFEST cache and setup would
# overwrite the consumer's manifest, i.e. swapping the project's pixi context
# out from under it. The tool island solves in the anchor and its env path is
# assembled by rule, then verified (no guessing at detached env directories).
# The vcpkg poison (VCPKG_FORCE_SYSTEM_BINARIES) has no analogue here, but the
# cache rule does: pixi writes its package cache to $HOME by default, which is
# both global state and unwritable in sandboxes (measured: "no writable layers
# to cache package to"). An externally set PIXI_CACHE_DIR is respected (the
# entry script exports a project-scoped one by adjudication); otherwise it goes
# into the anchor.
function(_polyorch_tp_conan_tool out_exe out_version work_dir allow_bootstrap explicit_program)
    set(_tp_conan "${explicit_program}")
    if(NOT _tp_conan)
        set(_tp_conan "${PolyOrch_CONAN_PROGRAM}")
    endif()
    if(_tp_conan AND NOT EXISTS "${_tp_conan}")
        message(FATAL_ERROR "_polyorch_tp_conan_tool: CONAN_PROGRAM '${_tp_conan}' does not exist")
    endif()
    if(NOT _tp_conan)
        # the empty variable must be removed before asking find_program: it
        # refuses to search when the name is already defined, even to "" (the
        # same trap bites twice in one round -- see the e2e case's compiler
        # discovery), and here it would silently disable the tools/bin rung.
        unset(_tp_conan)
        # unlike the vcpkg lane, this rung may consult PATH: a stray vcpkg
        # brings its own root (it derives root from the executable's directory
        # and ignores VCPKG_ROOT -- measured), whereas conan is self-contained
        # here because CONAN_HOME is set by this lane and any version that is
        # not the pinned one is refused below. The version gate, not the
        # search path, is what protects the key.
        find_program(_tp_conan NAMES conan
            PATHS "${work_dir}/tools/bin" "${work_dir}/bin")
    endif()
    if(NOT _tp_conan AND NOT allow_bootstrap)
        message(FATAL_ERROR "polyorch_thirdparty_recipe: no conan tool found and BOOTSTRAP_TOOL is off (no download) -- pass CONAN_PROGRAM <path>, place a conan in <WORK_DIR>/tools/bin, or drop BOOTSTRAP_TOOL to let the lane solve pkg-deps/conan-tool/pixi.toml into the anchor")
    endif()
    if(NOT _tp_conan)
        set(_tp_pixi "${PolyOrch_PIXI_PROGRAM}")
        if(_tp_pixi)
            if(NOT EXISTS "${_tp_pixi}")
                message(FATAL_ERROR "_polyorch_tp_conan_tool: PolyOrch_PIXI_PROGRAM '${_tp_pixi}' does not exist")
            endif()
        else()
            unset(_tp_pixi)
            find_program(_tp_pixi NAMES pixi PATHS "$ENV{HOME}/.pixi/bin" /usr/local/bin)
        endif()
        if(NOT _tp_pixi)
            message(FATAL_ERROR "polyorch_thirdparty_recipe: bootstrapping the conan tool needs pixi (not found on PATH or in ~/.pixi/bin) -- pass CONAN_PROGRAM <path> or PolyOrch_PIXI_PROGRAM <path>")
        endif()
        set(_tp_ti "${work_dir}/conan-tool")
        # the island ships WITH this module, resolved through
        # _polyorch_tp_module_dir() -- never from a cache variable and never
        # from CMAKE_CURRENT_LIST_DIR inside the function (that names the file
        # being processed, not the defining module; measured in script mode).
        _polyorch_tp_module_dir(_tp_repo)
        set(_tp_src "${_tp_repo}/pkg-deps/conan-tool")
        if(NOT EXISTS "${_tp_src}/pixi.lock")
            message(FATAL_ERROR "polyorch_thirdparty_recipe: the conan tool island is incomplete at ${_tp_src} (pixi.toml + pixi.lock must both be committed -- the lock is the tool pin)")
        endif()
        if(NOT EXISTS "${_tp_ti}/.pixi/envs/default/bin/conan")
            execute_process(COMMAND "${CMAKE_COMMAND}" -E copy_directory "${_tp_src}" "${_tp_ti}"
                RESULT_VARIABLE _tp_rc ERROR_VARIABLE _tp_e)
            if(NOT _tp_rc EQUAL 0)
                message(FATAL_ERROR "polyorch_thirdparty_recipe: copying the conan tool island into the anchor failed rc=${_tp_rc}: ${_tp_e}")
            endif()
            set(_tp_cenv "")
            if(NOT DEFINED ENV{PIXI_CACHE_DIR} OR "$ENV{PIXI_CACHE_DIR}" STREQUAL "")
                file(MAKE_DIRECTORY "${work_dir}/pixi-cache")
                set(_tp_cenv "PIXI_CACHE_DIR=${work_dir}/pixi-cache")
            endif()
            message(STATUS "polyorch thirdparty: solving the conan tool island into ${_tp_ti} (pixi; one network step, the committed lock fixes the version)")
            execute_process(COMMAND "${CMAKE_COMMAND}" -E env ${_tp_cenv}
                    "${_tp_pixi}" install --manifest-path "${_tp_ti}/pixi.toml"
                RESULT_VARIABLE _tp_rc OUTPUT_VARIABLE _tp_o ERROR_VARIABLE _tp_e)
            if(NOT _tp_rc EQUAL 0)
                message(FATAL_ERROR "polyorch_thirdparty_recipe: solving the conan tool island failed rc=${_tp_rc}:\n${_tp_o}${_tp_e}")
            endif()
        endif()
        set(_tp_conan "${_tp_ti}/.pixi/envs/default/bin/conan")
        if(NOT EXISTS "${_tp_conan}")
            message(FATAL_ERROR "polyorch_thirdparty_recipe: pixi solved the tool island but no conan at ${_tp_conan} -- this lane refuses to guess a relocated env directory (a detached-environments setup must pass CONAN_PROGRAM explicitly)")
        endif()
    endif()
    execute_process(COMMAND "${_tp_conan}" --version OUTPUT_VARIABLE _tp_vv ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE)
    string(REGEX MATCH "[0-9]+\\.[0-9]+[^ \t\n]*" _tp_ver "${_tp_vv}")
    if(NOT _tp_ver)
        message(FATAL_ERROR "polyorch_thirdparty_recipe: cannot parse a conan version from '${_tp_vv}'")
    endif()
    set(${out_exe} "${_tp_conan}" PARENT_SCOPE)
    set(${out_version} "${_tp_ver}" PARENT_SCOPE)
endfunction()

#-----------------------------------------------------------------------------------------------------------------------
# _polyorch_tp_conan_pinned_version -- the conan tool version the repository
# pins, read as TEXT from the tool island's committed pixi.lock (measured
# form: .../noarch/conan-2.32.0-pyhd8ed1ab_0.conda). Why the lock and not
# `conan --version`: the tool version rides the cache key, and the key must be
# computable on the STRICT refusal path too -- asking the binary would make a
# recipe that only wants to hear "no artifact yet" depend on having a conan
# installed (the vcpkg lane gets this for free: its tool version is implied by
# the pinned baseline inside the island, which already rides the key).
# The lock's full hash deliberately does NOT enter the key: it embeds host
# virtual packages (__glibc/__linux/__archspec, measured), and a host fact in
# the key would bind artifact identity to this machine (criterion 16).
function(_polyorch_tp_conan_pinned_version out)
    _polyorch_tp_module_dir(_tp_repo)
    set(_tp_lk "${_tp_repo}/pkg-deps/conan-tool/pixi.lock")
    if(NOT EXISTS "${_tp_lk}")
        message(FATAL_ERROR "_polyorch_tp_conan_pinned_version: the conan tool island has no committed lock at ${_tp_lk} -- the lock IS the tool pin (run pixi lock/install there once and commit the result)")
    endif()
    file(READ "${_tp_lk}" _tp_txt)
    if(NOT _tp_txt MATCHES "conan-([0-9][0-9.]*)-")
        message(FATAL_ERROR "_polyorch_tp_conan_pinned_version: no conan package entry parseable in ${_tp_lk} (expected .../conan-<version>-<build>.conda)")
    endif()
    set(${out} "${CMAKE_MATCH_1}" PARENT_SCOPE)
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
#     [PIXI_ENVIRONMENT <e>] [SYSROOT_ID <id>] [RECIPE_SHA256 <h>] [SCHEMA_VERSION <n>]
#     [ECOSYSTEM_PROVIDER <p>] [ECOSYSTEM_PIN_SHA256 <h>] [ECOSYSTEM_TRIPLET <t>]
#     [ECOSYSTEM_TOOL_VERSION <v>] [ECOSYSTEM_PROFILE_SHA256 <h>]
#     [HELPER_VERSION <v>])
#
# Sets <var> (64 hex) and <var>_SHORT12 (first 12 hex chars). OPTIONS are
# normalized: entries stripped and sorted, so key order / whitespace cannot
# produce a false-distinct key (F4=A "no false distinct" leg).
function(polyorch_thirdparty_fingerprint out)
    cmake_parse_arguments(arg ""
        "ARCHIVE_SHA256;BUILD_TYPE;VERSION;PROFILE;TRIPLET;LINK_MODE;TOOLCHAIN_FILE_SHA256;COMPILER_ID;COMPILER_VERSION;CMAKE_VERSION;DEPENDENCY_PROVIDER;PIXI_LOCK_SHA256;PIXI_ENVIRONMENT;SYSROOT_ID;RECIPE_SHA256;SCHEMA_VERSION;HELPER_VERSION;ECOSYSTEM_PROVIDER;ECOSYSTEM_PIN_SHA256;ECOSYSTEM_TRIPLET;ECOSYSTEM_TOOL_VERSION;ECOSYSTEM_PROFILE_SHA256"
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
        "pixi_env=${arg_PIXI_ENVIRONMENT}"
        "sysroot_id=${arg_SYSROOT_ID}" "recipe_sha256=${arg_RECIPE_SHA256}"
        "ecosystem_provider=${arg_ECOSYSTEM_PROVIDER}" "ecosystem_pin=${arg_ECOSYSTEM_PIN_SHA256}"
        "ecosystem_triplet=${arg_ECOSYSTEM_TRIPLET}"
        "ecosystem_tool_version=${arg_ECOSYSTEM_TOOL_VERSION}"
        "ecosystem_profile=${arg_ECOSYSTEM_PROFILE_SHA256}"
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
#     [PATCH_COMMAND <cmd...>]                    (runs with CWD = the source tree)
#     [OUTPUT_DIR <d>]                            (default: CMAKE_CURRENT_BINARY_DIR/3rdparty)
#     SOURCE_DIR_OUT <var> [ARCHIVE_SHA256_OUT <var>])
#
# URL_HASH is mandatory (an unverified artifact is unkeyable). Patches are
# verified sha256 FIRST and only then applied (L6) -- a file patch is applied
# as a verbatim copy over the extracted tree, relative to the archive root;
# command-shaped patches (SDL's Xwayland guard script class) run through
# PATCH_COMMAND after the overlays, with the extracted tree as CWD and their
# command text in the stamp dossier (a changed command re-acquires and
# re-patches; the archive itself is immutable). The stamp records the dossier,
# not a timestamp: changing any input rebuilds the tree; identical inputs are
# a no-op.
function(polyorch_thirdparty_fetch)
    cmake_parse_arguments(arg ""
        "NAME;URL;URL_HASH;OUTPUT_DIR;SOURCE_DIR_OUT;ARCHIVE_SHA256_OUT" "PATCHES;PATCH_SHA256;PATCH_COMMAND" ${ARGN})
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
    # Stamp key = artifact + patches + the command text (fetch is config-
    # independent; the full-field cache key is the recipe face's business,
    # not extraction's).
    string(SHA256 _tp_fetch_key "archive=${_tp_arch_hash}\npatches=${_tp_patch_combined}\npatch_command=${arg_PATCH_COMMAND}\n")
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

    # Command-shaped patch: runs inside the extracted tree (the SDL guard
    # scripts address sources by relative path and are idempotent per site).
    if(arg_PATCH_COMMAND)
        execute_process(COMMAND ${arg_PATCH_COMMAND}
            WORKING_DIRECTORY "${_tp_src}" RESULT_VARIABLE _tp_prc)
        if(NOT _tp_prc EQUAL 0)
            message(FATAL_ERROR "polyorch_thirdparty_fetch: PATCH_COMMAND failed for ${arg_NAME} (rc=${_tp_prc}); command: ${arg_PATCH_COMMAND} (cwd: ${_tp_src})")
        endif()
    endif()

    file(WRITE "${_tp_stamp}" "${_tp_fetch_key}")
    set(${arg_SOURCE_DIR_OUT} "${_tp_src}" PARENT_SCOPE)
    if(arg_ARCHIVE_SHA256_OUT)
        set(${arg_ARCHIVE_SHA256_OUT} "${_tp_arch_hash}" PARENT_SCOPE)
    endif()
endfunction()

#-----------------------------------------------------------------------------------------------------------------------
# _polyorch_tp_pixi_subpaths -- the C1-disciplined view of an installed pixi
# environment: ONLY the include/lib/pkgconfig sub-paths, NEVER the bare
# prefix (CMAKE_PREFIX_PATH is searched by find_program; a prefix carrying
# bin/ would let the conda compilers hijack the inner build silently).
# Requires the pixi face context (polyorch_pixi_setup or the -DPolyOrch_PIXI_*
# pair) for polyorch_pixi_env_paths.
function(_polyorch_tp_pixi_subpaths environment prefix_out subs_out pkgcfg_out)
    if(NOT COMMAND polyorch_pixi_env_paths)
        message(FATAL_ERROR "thirdparty pixi provider: the PolyOrch pixi face is not loaded -- include PolyOrchPixiHelpers.cmake first")
    endif()
    # NO_PREFIX_PATH is load-bearing: the default form appends the bare prefix
    # to CMAKE_PREFIX_PATH, which is exactly the hijack shape this provider
    # exists to forbid.
    polyorch_pixi_env_paths(ENVIRONMENT "${environment}" NO_PREFIX_PATH PREFIX_OUT _tp_px_prefix)
    if(NOT _tp_px_prefix OR NOT IS_DIRECTORY "${_tp_px_prefix}")
        message(FATAL_ERROR "thirdparty pixi provider: environment '${environment}' has no installed prefix")
    endif()
    set(_tp_subs "")
    set(_tp_pkgcfg "")
    foreach(_d "include" "lib")
        if(IS_DIRECTORY "${_tp_px_prefix}/${_d}")
            list(APPEND _tp_subs "${_tp_px_prefix}/${_d}")
        endif()
    endforeach()
    foreach(_d "lib/pkgconfig" "share/pkgconfig")
        if(IS_DIRECTORY "${_tp_px_prefix}/${_d}")
            list(APPEND _tp_pkgcfg "${_tp_px_prefix}/${_d}")
        endif()
    endforeach()
    # The guard the discipline demands: every injected path is a strict
    # sub-path; the bare prefix never enters the injection list.
    foreach(_p IN LISTS _tp_subs _tp_pkgcfg)
        if(_p STREQUAL _tp_px_prefix)
            message(FATAL_ERROR "thirdparty pixi provider: refusing to inject the bare prefix (bin/ would enter the program search -- r4 C1)")
        endif()
    endforeach()
    set(${prefix_out} "${_tp_px_prefix}" PARENT_SCOPE)
    set(${subs_out} "${_tp_subs}" PARENT_SCOPE)
    set(${pkgcfg_out} "${_tp_pkgcfg}" PARENT_SCOPE)
endfunction()

#-----------------------------------------------------------------------------------------------------------------------
# _polyorch_tp_pixi_audit -- static linking is NOT runtime independence
# (pixi discipline 4): scan the install tree's ELF outputs with readelf -d
# and flag any RUNPATH/RPATH pointing inside the pixi prefix -- such an
# artifact needs the pixi runtime at load time and must not be shipped as a
# standalone release piece. Non-ELF files are skipped silently (readelf
# exits non-zero on them); a MISSING readelf degrades with a warning and
# reports "not audited", never a silent pass.
function(_polyorch_tp_pixi_audit install_dir pixi_prefix out_flag out_detail)
    # PATH-only discovery, deliberately: the audit must follow the SAME readelf
    # the caller's environment selects (a test fakes it via PATH; a build box
    # without readelf in PATH must hit the degrade branch, not pick up a
    # system-default binary the runtime would never see).
    # No pre-set of the result variable (an empty value counts as "already
    # defined" and silently skips the search) and the CACHE entry is dropped
    # per call (a repeated audit under a different PATH must re-search).
    unset(_tp_reef CACHE)
    find_program(_tp_reef NAMES readelf PATHS ENV PATH NO_DEFAULT_PATH)
    if(NOT _tp_reef)
        message(WARNING "polyorch thirdparty: readelf not found -- the pixi runtime audit is NOT performed; the artifact is not proven runtime-independent")
        set(${out_flag} FALSE PARENT_SCOPE)
        set(${out_detail} "audit not performed: no readelf" PARENT_SCOPE)
        return()
    endif()
    file(GLOB_RECURSE _tp_files LIST_DIRECTORIES false "${install_dir}/*")
    set(_tp_hits "")
    set(_tp_checked 0)
    foreach(_tf IN LISTS _tp_files)
        execute_process(COMMAND "${_tp_reef}" -d "${_tf}" ERROR_QUIET
            OUTPUT_VARIABLE _tp_ro RESULT_VARIABLE _tp_rc)
        if(_tp_rc EQUAL 0)
            math(EXPR _tp_checked "${_tp_checked} + 1" OUTPUT_FORMAT DECIMAL)
            string(FIND "${_tp_ro}" "${pixi_prefix}" _tp_at)
            if(NOT _tp_at EQUAL -1)
                list(APPEND _tp_hits "${_tf}")
            endif()
        endif()
    endforeach()
    if(_tp_hits)
        list(JOIN _tp_hits ", " _tp_hj)
        set(${out_flag} TRUE PARENT_SCOPE)
        set(${out_detail} "pixi-prefixed RUNPATH/RPATH found in: ${_tp_hj}" PARENT_SCOPE)
    else()
        set(${out_flag} FALSE PARENT_SCOPE)
        set(${out_detail} "audited ${_tp_checked} ELF output(s): no path into ${pixi_prefix}" PARENT_SCOPE)
    endif()
endfunction()

#-----------------------------------------------------------------------------------------------------------------------
# polyorch_thirdparty_build -- independent configure/build/install (EXPLICIT verb).
#
#   polyorch_thirdparty_build(NAME <n> SOURCE_DIR <d> BUILD_DIR <d> INSTALL_DIR <d>
#     BUILD_TYPE <cfg>                      (required; O-3)
#   [CMAKE_ARGS <...>] [TOOLCHAIN_FILE <f>] [GENERATOR <g>] [MAKE_PROGRAM <f>]
#   [DEPENDENCY_PROVIDER none|system|pixi|sysroot] [PIXI_ENVIRONMENT <e>]
#   [SYSROOT <d>] [SANITIZE_ENV] [PARALLEL <n>])
#
# Runs a fully separate CMake invocation (execute_process), so the wrapped
# project's targets never join the caller's graph. Full logs land at
# <BUILD_DIR>/polyorch-thirdparty-<name>-configure|build|install.log and a
# failure is a hard FATAL naming the log (error model: fail loud, never
# degrade). Cross callers: TOOLCHAIN_FILE is forwarded as
# -DCMAKE_TOOLCHAIN_FILE and CMAKE_ARGS must carry the explicit compiler
# pair; TOOLCHAIN_FILE without a compiler pair is rejected (H3: refusing a
# half-forwarded group beats silently host-tooling a cross build).
# Environment: with no provider (the default) this face injects neither
# CMAKE_PREFIX_PATH nor a compiler into the child (r4 C1). The providers
# (P4): system/SANITIZE_ENV only clean the compiler-direct-read vars from the
# child; pixi additionally injects the environment's include/lib/pkgconfig
# SUB-paths (never the bare prefix) and REQUIRES an explicit compiler at the
# call site. sysroot is the P6 seam.
function(polyorch_thirdparty_build)
    cmake_parse_arguments(arg "SANITIZE_ENV"
        "NAME;SOURCE_DIR;BUILD_DIR;INSTALL_DIR;BUILD_TYPE;GENERATOR;TOOLCHAIN_FILE;PARALLEL;MAKE_PROGRAM;DEPENDENCY_PROVIDER;PIXI_ENVIRONMENT;SYSROOT" "CMAKE_ARGS" ${ARGN})
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
    # MAKE_PROGRAM: the child configure runs under the caller's sanitized PATH
    # (F25 sends the system constitution); a ninja that only lives in an
    # activated env would otherwise vanish and project() would die with a
    # misleading "CMAKE_C_COMPILER not set". Pin the tool's absolute path.
    if(arg_MAKE_PROGRAM)
        list(APPEND _tp_fwd "-DCMAKE_MAKE_PROGRAM=${arg_MAKE_PROGRAM}")
    endif()
    if(NOT arg_GENERATOR)
        if(CMAKE_GENERATOR)
            set(arg_GENERATOR "${CMAKE_GENERATOR}")
        else()
            message(FATAL_ERROR "polyorch_thirdparty_build: GENERATOR is required (script mode has no default generator)")
        endif()
    endif()

    # ---- dependency provider (P4) ----
    set(_tp_provider "${arg_DEPENDENCY_PROVIDER}")
    if(_tp_provider STREQUAL "")
        set(_tp_provider "none")
    endif()
    if(NOT _tp_provider MATCHES "^(none|system|pixi|sysroot)$")
        message(FATAL_ERROR "polyorch_thirdparty_build: unknown DEPENDENCY_PROVIDER '${_tp_provider}' (none|system|pixi; sysroot lands with the cross batch P6)")
    endif()
    if(_tp_provider STREQUAL "sysroot")
        message(FATAL_ERROR "polyorch_thirdparty_build: DEPENDENCY_PROVIDER sysroot arrives with the cross/device batch (P6, O-5); P4 ships none/system/pixi")
    endif()
    if(_tp_provider STREQUAL "pixi")
        if(NOT arg_PIXI_ENVIRONMENT)
            message(FATAL_ERROR "polyorch_thirdparty_build: DEPENDENCY_PROVIDER pixi requires PIXI_ENVIRONMENT (an unnamed environment is an unbounded dependency set)")
        endif()
        # C1: the prefix's bin/ never enters the search set, so the compiler
        # is never left to ambient discovery -- the call site states it.
        if(NOT arg_TOOLCHAIN_FILE AND NOT arg_CMAKE_ARGS MATCHES "CMAKE_C_COMPILER|CMAKE_CXX_COMPILER")
            message(FATAL_ERROR "polyorch_thirdparty_build: DEPENDENCY_PROVIDER pixi requires an explicit compiler at the call site (CMAKE_ARGS carrying CMAKE_C_COMPILER/CMAKE_CXX_COMPILER, or TOOLCHAIN_FILE) -- the compiler-hijack trap this provider exists to close (r4 C1)")
        endif()
    endif()
    # The env wrapper (discipline 2: no-activation, explicit child env). The
    # assignments TRAIL the --unset block because a later VAR=val wins under
    # `cmake -E env` (measured ordering, the t-rust-env-forward family).
    set(_tp_envpre "")
    set(_tp_pixi_prefix "")
    if(_tp_provider STREQUAL "pixi")
        _polyorch_tp_pixi_subpaths("${arg_PIXI_ENVIRONMENT}" _tp_pixi_prefix _tp_px_subs _tp_px_pc)
        list(JOIN _tp_px_subs ":" _tp_px_subs_j)
        list(JOIN _tp_px_pc ":" _tp_px_pc_j)
        set(_tp_envpre "${CMAKE_COMMAND}" -E env
            --unset=CPATH --unset=C_INCLUDE_PATH --unset=CPLUS_INCLUDE_PATH
            --unset=LIBRARY_PATH --unset=COMPILER_PATH --unset=CONDA_PREFIX
            "CMAKE_PREFIX_PATH=${_tp_px_subs_j}"
            "PKG_CONFIG_PATH=${_tp_px_pc_j}")
        message(STATUS "polyorch thirdparty: pixi provider for ${arg_NAME} -- prefix sub-paths only (${_tp_px_subs_j}; pkgconfig ${_tp_px_pc_j})")
    elseif(_tp_provider STREQUAL "system" OR arg_SANITIZE_ENV)
        set(_tp_envpre "${CMAKE_COMMAND}" -E env
            --unset=CPATH --unset=C_INCLUDE_PATH --unset=CPLUS_INCLUDE_PATH
            --unset=LIBRARY_PATH --unset=COMPILER_PATH --unset=CONDA_PREFIX)
    endif()

    file(MAKE_DIRECTORY "${arg_BUILD_DIR}")
    set(_tp_log_cfg "${arg_BUILD_DIR}/polyorch-thirdparty-${arg_NAME}-configure.log")
    set(_tp_log_bld "${arg_BUILD_DIR}/polyorch-thirdparty-${arg_NAME}-build.log")
    set(_tp_log_ins "${arg_BUILD_DIR}/polyorch-thirdparty-${arg_NAME}-install.log")

    set(_tp_cmd "${CMAKE_COMMAND}" -S "${arg_SOURCE_DIR}" -B "${arg_BUILD_DIR}" -G "${arg_GENERATOR}"
        -DCMAKE_BUILD_TYPE=${arg_BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${arg_INSTALL_DIR} ${_tp_fwd} ${arg_CMAKE_ARGS})
    execute_process(COMMAND ${_tp_envpre} ${_tp_cmd} OUTPUT_FILE "${_tp_log_cfg}" ERROR_FILE "${_tp_log_cfg}" RESULT_VARIABLE _tp_rc)
    if(NOT _tp_rc EQUAL 0)
        message(FATAL_ERROR "polyorch_thirdparty_build: configure failed for ${arg_NAME} (rc=${_tp_rc}); full log: ${_tp_log_cfg}")
    endif()

    set(_tp_build "${CMAKE_COMMAND}" --build "${arg_BUILD_DIR}" --config "${arg_BUILD_TYPE}")
    if(arg_PARALLEL)
        list(APPEND _tp_build "--parallel" "${arg_PARALLEL}")
    endif()
    execute_process(COMMAND ${_tp_envpre} ${_tp_build} OUTPUT_FILE "${_tp_log_bld}" ERROR_FILE "${_tp_log_bld}" RESULT_VARIABLE _tp_rc)
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
#     [RECIPE_SHA256 <h>] [SCHEMA_VERSION <n>] [DEPENDENCY_PROVIDER <p>]
#     [PIXI_RUNTIME_REQUIRED])
#
# LICENSE is mandatory (L7: zlib/MIT-class obligations ride the artifact).
function(polyorch_thirdparty_manifest_write)
    cmake_parse_arguments(arg "PIXI_RUNTIME_REQUIRED"
        "MANIFEST;KEY;NAME;VERSION;LICENSE;PROVIDER;PROFILE;TRIPLET;BUILD_TYPE;LINK_MODE;ARCHIVE_SHA256;RECIPE_SHA256;SCHEMA_VERSION;DEPENDENCY_PROVIDER;ECOSYSTEM_PIN_SHA256;ECOSYSTEM_TRIPLET;ECOSYSTEM_TOOL_VERSION;ECOSYSTEM_PROFILE_SHA256" "OPTIONS" ${ARGN})
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
    foreach(_tp_f IN ITEMS VERSION PROVIDER PROFILE TRIPLET BUILD_TYPE LINK_MODE ARCHIVE_SHA256 RECIPE_SHA256 SCHEMA_VERSION DEPENDENCY_PROVIDER ECOSYSTEM_PIN_SHA256 ECOSYSTEM_TRIPLET ECOSYSTEM_TOOL_VERSION ECOSYSTEM_PROFILE_SHA256)
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
    if(arg_PIXI_RUNTIME_REQUIRED)
        string(JSON _tp_m SET "${_tp_m}" "pixi_runtime_required" "true")
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
#     [DEPENDENCY_PROVIDER none|system|pixi] [PIXI_ENVIRONMENT <e>]  (P4)
#     [MAKE_PROGRAM <f>] [TRIPLET <t>]
#     [CMAKE_ARGS <...>]   (call-site dynamic args: the provider compilers
#                          are explicit per r4 C1 and never live in the JSON)
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
# patch_command[<argv...>] (relative path elements resolve against the recipe
# base; the command runs with CWD = the extracted source tree), fetch_only
# (F8 source-wrapper recipes: acquire + patch, then return the source dir --
# no build/install/manifest/cache), profiles{<p>{<OPT>:<v>}}, link_mode,
# find_package{name,components,targets}, alias. Import stays a separate verb
# (this loader returns the wiring).
function(polyorch_thirdparty_recipe)
    cmake_parse_arguments(arg "GENERATE_ECOSYSTEM"
        "RECIPE;RECIPE_BASE;WORK_DIR;BUILD_TYPE;PROFILE;TRIPLET;GENERATOR;PARALLEL;PACKAGES_DIR;PACKAGE_FORMAT;MAKE_PROGRAM;DEPENDENCY_PROVIDER;PIXI_ENVIRONMENT;VCPKG_PROGRAM;VCPKG_ROOT_DIR;CONAN_PROGRAM;BINARY_CACHE;BOOTSTRAP_TOOL;SOURCE_DIR_OUT;INSTALL_DIR_OUT;FINGERPRINT_OUT;MANIFEST_OUT;PACKAGE_OUT;FIND_PACKAGE_NAME_OUT;ALIAS_OUT;COMPONENTS_OUT;TARGETS_OUT"
        "CMAKE_ARGS" ${ARGN})
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
    # The required set is provider-shaped (P7a): source recipes carry the
    # artifact pair (url/url_hash); ecosystem recipes carry the pin island
    # (pin_dir) instead -- the island IS the artifact anchor.
    foreach(_tp_f IN ITEMS schema_version name version provider license)
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
    set(_tp_eco FALSE)
    set(_tp_pindir "")
    set(_tp_pin_hash "")
    set(_tp_eco_triplet "")
    set(_tp_url "")
    set(_tp_urlhash "")
    if(_tp_provider STREQUAL "source")
        foreach(_tp_f IN ITEMS url url_hash)
            if(NOT "${_tp_json}" MATCHES "\"${_tp_f}\"[ ]*:")
                message(FATAL_ERROR "polyorch_thirdparty_recipe: schema violation in ${arg_RECIPE}: required field '${_tp_f}' missing")
            endif()
        endforeach()
        string(JSON _tp_url GET "${_tp_json}" url)
        string(JSON _tp_urlhash GET "${_tp_json}" url_hash)
    elseif(_tp_provider STREQUAL "vcpkg")
        set(_tp_eco TRUE)
        foreach(_tp_f IN ITEMS pin_dir)
            if(NOT "${_tp_json}" MATCHES "\"${_tp_f}\"[ ]*:")
                message(FATAL_ERROR "polyorch_thirdparty_recipe: schema violation in ${arg_RECIPE}: required field '${_tp_f}' missing (ecosystem recipes pin through the island, not url/url_hash)")
            endif()
        endforeach()
    elseif(_tp_provider STREQUAL "conan")
        set(_tp_eco TRUE)
        foreach(_tp_f IN ITEMS pin_dir)
            if(NOT "${_tp_json}" MATCHES "\"${_tp_f}\"[ ]*:")
                message(FATAL_ERROR "polyorch_thirdparty_recipe: schema violation in ${arg_RECIPE}: required field '${_tp_f}' missing (ecosystem recipes pin through the island, not url/url_hash)")
            endif()
        endforeach()
    elseif(_tp_provider STREQUAL "prebuilt" OR _tp_provider STREQUAL "system")
        message(FATAL_ERROR "polyorch_thirdparty_recipe: provider '${_tp_provider}' is not a source recipe -- package caching for source builds is PACKAGES_DIR (P2); direct prebuilt/system intake arrives with the consumer lanes (P3+)")
    else()
        message(FATAL_ERROR "polyorch_thirdparty_recipe: unknown provider '${_tp_provider}' (schema v1: source, vcpkg, conan; prebuilt/system = P3+ seam)")
    endif()

    # ---- link mode is lane-shared (the ecosystem triplet derives from it) ----
    set(_tp_link "")
    if("${_tp_json}" MATCHES "\"link_mode\"[ ]*:")
        string(JSON _tp_link GET "${_tp_json}" link_mode)
    endif()

    if(_tp_eco)
        # ---- lane postures: call-site ONLY, never recipe fields ----
        # Both knobs change HOW FAST a generate runs, not WHAT it produces, so
        # neither may enter the recipe JSON: the recipe hash is a key input
        # (M1), and a pure speed switch must never mint a fresh cache identity.
        # Defaults: no vcpkg binary cache (clear), tool bootstrap allowed.
        set(_tp_bincache FALSE)
        if(DEFINED arg_BINARY_CACHE AND NOT arg_BINARY_CACHE STREQUAL "")
            if(arg_BINARY_CACHE MATCHES "^(on|ON|true|TRUE|1)$")
                set(_tp_bincache TRUE)
            elseif(NOT arg_BINARY_CACHE MATCHES "^(off|OFF|false|FALSE|0)$")
                message(FATAL_ERROR "polyorch_thirdparty_recipe: BINARY_CACHE must be on|off, got '${arg_BINARY_CACHE}'")
            endif()
        elseif(PolyOrch_VCPKG_BINARY_CACHE)
            set(_tp_bincache TRUE)
        endif()
        set(_tp_boot TRUE)
        if(DEFINED arg_BOOTSTRAP_TOOL AND NOT arg_BOOTSTRAP_TOOL STREQUAL "")
            if(arg_BOOTSTRAP_TOOL MATCHES "^(off|OFF|false|FALSE|0)$")
                set(_tp_boot FALSE)
            elseif(NOT arg_BOOTSTRAP_TOOL MATCHES "^(on|ON|true|TRUE|1)$")
                message(FATAL_ERROR "polyorch_thirdparty_recipe: BOOTSTRAP_TOOL must be on|off, got '${arg_BOOTSTRAP_TOOL}'")
            endif()
        elseif(DEFINED PolyOrch_VCPKG_NO_BOOTSTRAP AND PolyOrch_VCPKG_NO_BOOTSTRAP)
            set(_tp_boot FALSE)
        endif()

        # ---- O-13=C gate: patched libraries never ride the ecosystem lane ----
        set(_tp_has_patch FALSE)
        if("${_tp_json}" MATCHES "\"patches\"[ ]*:")
            string(JSON _tp_npatch LENGTH "${_tp_json}" patches)
            if(NOT _tp_npatch EQUAL 0)
                set(_tp_has_patch TRUE)
            endif()
        endif()
        if("${_tp_json}" MATCHES "\"patch_command\"[ ]*:")
            set(_tp_has_patch TRUE)
        endif()
        if(_tp_has_patch)
            message(FATAL_ERROR "polyorch_thirdparty_recipe: '${_tp_name}' has patches but provider '${_tp_provider}' (O-13): patched libraries stay on provider \"source\"; the overlay-port lane is a conditional entry -- bring a real candidate and open a ruling")
        endif()
        # contradictory inputs are refused loudly, never ignored
        if(arg_PROFILE)
            if(_tp_provider STREQUAL "conan")
                # r9a M4: conan DOES have a profile -- it is GENERATED here
                # from cmake facts, which is exactly why the call site must not
                # hand one in (a passed profile is a second source of truth for
                # the compiler settings that ride the key).
                message(FATAL_ERROR "polyorch_thirdparty_recipe: PROFILE is not accepted on the conan lane -- the lane GENERATES the profile from cmake facts (O-12=C, PolyOrch_CONAN_COMPILER*/CPPSTD/LIBCXX); a caller-supplied profile would be a second truth for the settings that ride the key -- remove PROFILE")
            else()
                message(FATAL_ERROR "polyorch_thirdparty_recipe: PROFILE is a source-lane concept (per-profile option tables); the ecosystem lane pins through the island -- remove PROFILE or switch the recipe to provider \"source\"")
            endif()
        endif()
        if(arg_DEPENDENCY_PROVIDER AND NOT arg_DEPENDENCY_PROVIDER STREQUAL "none")
            message(FATAL_ERROR "polyorch_thirdparty_recipe: DEPENDENCY_PROVIDER is a build-lane concept (our build verb's child env); the '${_tp_provider}' lane builds inside the ecosystem tool -- remove it or switch to provider \"source\"")
        endif()

        # ---- pin island (O-10=A) ----
        string(JSON _tp_pindir GET "${_tp_json}" pin_dir)
        if(NOT IS_ABSOLUTE "${_tp_pindir}")
            set(_tp_pindir "${arg_RECIPE_BASE}/${_tp_pindir}")
        endif()
        _polyorch_tp_pin_hash("${_tp_pindir}" "${_tp_provider}" _tp_pin_hash)

        # ---- license dual-source consistency (M3): the recipe is the truth,
        # a diverging island license is recipe drift, not a choice ----
        # vcpkg islands carry a "license" field; a conan CONSUMER island
        # (conanfile.txt) has none at all -- the license lives in the upstream
        # recipe -- so only a conanfile.py that states one is compared.
        if(_tp_provider STREQUAL "vcpkg")
            file(READ "${_tp_pindir}/vcpkg.json" _tp_island_json)
            if("${_tp_island_json}" MATCHES "\"license\"[ ]*:")
                string(JSON _tp_island_lic GET "${_tp_island_json}" license)
                if(NOT _tp_island_lic STREQUAL "${_tp_license}")
                    message(FATAL_ERROR "polyorch_thirdparty_recipe: '${_tp_name}' license drift -- recipe says '${_tp_license}' but the pin island says '${_tp_island_lic}'; reconcile them (the recipe field is the recorded truth)")
                endif()
            endif()
        elseif(EXISTS "${_tp_pindir}/conanfile.py")
            file(READ "${_tp_pindir}/conanfile.py" _tp_cfile)
            if("${_tp_cfile}" MATCHES "license[ ]*=[ ]*\"([^\"]+)\"")
                if(NOT CMAKE_MATCH_1 STREQUAL "${_tp_license}")
                    message(FATAL_ERROR "polyorch_thirdparty_recipe: '${_tp_name}' license drift -- recipe says '${_tp_license}' but the island's conanfile.py says '${CMAKE_MATCH_1}'; reconcile them (the recipe field is the recorded truth)")
                endif()
            endif()
        endif()

        # ---- the lane's identity axis: a triplet (vcpkg) or a GENERATED
        # profile (conan); both ride the key ----
        set(_tp_profile_file "")
        set(_tp_profile_name "")
        set(_tp_profile_hash "")
        set(_tp_tool_version "")
        if(_tp_provider STREQUAL "vcpkg")
            # triplet (O-12=C): call-site override > platform face > self-derived
            _polyorch_tp_ecosystem_triplet(_tp_eco_triplet "${_tp_link}" "${arg_TRIPLET}")
        else()
            _polyorch_tp_conan_pinned_version(_tp_tool_version)
            _polyorch_tp_conan_profile(_tp_profile_file _tp_profile_name _tp_profile_hash
                "${arg_WORK_DIR}" "${arg_BUILD_TYPE}")
            # r9a M2: conan has no triplet, yet the package name and the
            # dossier both carry that slot -- it takes the profile name. The
            # settings' real identity rides ECOSYSTEM_PROFILE_SHA256; leaving
            # the slot empty would print "none" in the file name and collide
            # with a source recipe's look, and inventing a vcpkg-style token
            # here would be a fake vocabulary.
            set(_tp_eco_triplet "${_tp_profile_name}")
        endif()
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

    # ---- command-shaped patch + fetch-only mode (P3 consumer lane) ----
    # patch_command elements that name an existing path relative to the
    # recipe base are made absolute: the command's CWD is the extracted
    # source tree, so a relative "patches/x.py" would miss.
    set(_tp_patch_cmd "")
    if("${_tp_json}" MATCHES "\"patch_command\"[ ]*:")
        string(JSON _tp_npc LENGTH "${_tp_json}" patch_command)
        set(_tp_pci 0)
        while(_tp_pci LESS _tp_npc)
            string(JSON _tp_pe GET "${_tp_json}" patch_command ${_tp_pci})
            if(NOT IS_ABSOLUTE "${_tp_pe}" AND EXISTS "${arg_RECIPE_BASE}/${_tp_pe}")
                set(_tp_pe "${arg_RECIPE_BASE}/${_tp_pe}")
            endif()
            list(APPEND _tp_patch_cmd "${_tp_pe}")
            math(EXPR _tp_pci "${_tp_pci} + 1" OUTPUT_FORMAT DECIMAL)
        endwhile()
    endif()
    set(_tp_fetch_only FALSE)
    if("${_tp_json}" MATCHES "\"fetch_only\"[ ]*:")
        string(JSON _tp_fo GET "${_tp_json}" fetch_only)
        if(_tp_fo)
            set(_tp_fetch_only TRUE)
        endif()
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

    # ---- acquire (verified; source lane only -- the ecosystem lane has no
    # source archive, its identity anchor is the pin island) ----
    if(_tp_eco AND _tp_fetch_only)
        message(FATAL_ERROR "polyorch_thirdparty_recipe: fetch_only is a source-lane concept (F8 wrapper); ecosystem provider '${_tp_provider}' has nothing to fetch -- remove fetch_only")
    endif()
    if(NOT _tp_eco AND (DEFINED arg_BINARY_CACHE OR DEFINED arg_BOOTSTRAP_TOOL))
        message(FATAL_ERROR "polyorch_thirdparty_recipe: BINARY_CACHE/BOOTSTRAP_TOOL are ecosystem-lane knobs (vcpkg's own cache and tool); provider '${_tp_provider}' has nothing to bootstrap -- drop them or switch to provider \"vcpkg\"")
    endif()
    if(NOT _tp_eco)
        if(NOT IS_ABSOLUTE "${_tp_url}")
            set(_tp_url "${arg_RECIPE_BASE}/${_tp_url}")
        endif()
        polyorch_thirdparty_fetch(NAME "${_tp_name}" URL "${_tp_url}" URL_HASH "SHA256=${_tp_urlhash}"
            PATCHES ${_tp_patches} PATCH_SHA256 ${_tp_patch_shas}
            PATCH_COMMAND ${_tp_patch_cmd}
            OUTPUT_DIR "${arg_WORK_DIR}"
            SOURCE_DIR_OUT _tp_src ARCHIVE_SHA256_OUT _tp_arch_hash)
    endif()

    if(_tp_fetch_only)
        if(arg_SOURCE_DIR_OUT)
            set(${arg_SOURCE_DIR_OUT} "${_tp_src}" PARENT_SCOPE)
        endif()
        message(STATUS "polyorch thirdparty: ${_tp_name} fetch-only recipe (F8 source wrapper) -- source at ${_tp_src}; no build/install/manifest/cache")
        return()
    endif()

    # ---- fingerprint (recipe itself is a key input, M1) ----
    # NOTE: two provider axes never share a variable again (P7a): the
    # ACQUIRE axis rides the recipe JSON (source/vcpkg/conan); the BUILD
    # dependency axis is the caller's DEPENDENCY_PROVIDER (none/system/pixi).
    # The ecosystem lane has no source archive -- the pin hash is its
    # artifact-identity anchor and rides ARCHIVE_SHA256 plus the explicit
    # ECOSYSTEM_* fields (O-10/O-11 adjudications).
    set(_tp_depprovider "${arg_DEPENDENCY_PROVIDER}")
    if(_tp_depprovider STREQUAL "")
        set(_tp_depprovider "none")
    endif()
    if(_tp_eco)
        set(_tp_arch_hash "${_tp_pin_hash}")
        polyorch_thirdparty_fingerprint(_tp_key
            ARCHIVE_SHA256 "${_tp_arch_hash}" BUILD_TYPE "${arg_BUILD_TYPE}"
            VERSION "${_tp_version}" TRIPLET "${_tp_eco_triplet}" LINK_MODE "${_tp_link}"
            RECIPE_SHA256 "${_tp_recipe_hash}" SCHEMA_VERSION "${_tp_schema}"
            ECOSYSTEM_PROVIDER "${_tp_provider}" ECOSYSTEM_PIN_SHA256 "${_tp_pin_hash}"
            ECOSYSTEM_TRIPLET "${_tp_eco_triplet}"
            ECOSYSTEM_TOOL_VERSION "${_tp_tool_version}"
            ECOSYSTEM_PROFILE_SHA256 "${_tp_profile_hash}")
    else()
        # pixi provider inputs (P4): the lockfile is the reproducibility anchor --
        # its hash rides the key (discipline 3), and the environment name is
        # already carried by DEPENDENCY_PROVIDER + the injection itself.
        set(_tp_pixi_lock "")
        if(_tp_depprovider STREQUAL "pixi")
            if(NOT arg_PIXI_ENVIRONMENT)
                message(FATAL_ERROR "polyorch_thirdparty_recipe: DEPENDENCY_PROVIDER pixi requires PIXI_ENVIRONMENT")
            endif()
            if(NOT PolyOrch_PIXI_MANIFEST)
                message(FATAL_ERROR "polyorch_thirdparty_recipe: DEPENDENCY_PROVIDER pixi requires the pixi face context (polyorch_pixi_setup / PolyOrch_PIXI_MANIFEST)")
            endif()
            cmake_path(GET PolyOrch_PIXI_MANIFEST PARENT_PATH _tp_pdir)
            if(NOT EXISTS "${_tp_pdir}/pixi.lock")
                message(FATAL_ERROR "polyorch_thirdparty_recipe: pixi provider without pixi.lock beside the manifest -- the lockfile hash is the key input (discipline 3); resolve it first")
            endif()
            file(SHA256 "${_tp_pdir}/pixi.lock" _tp_pixi_lock)
        endif()
        polyorch_thirdparty_fingerprint(_tp_key
            ARCHIVE_SHA256 "${_tp_arch_hash}" BUILD_TYPE "${arg_BUILD_TYPE}"
            VERSION "${_tp_version}" PROFILE "${arg_PROFILE}" TRIPLET "${arg_TRIPLET}" LINK_MODE "${_tp_link}"
            OPTIONS ${_tp_opts} RECIPE_SHA256 "${_tp_recipe_hash}" SCHEMA_VERSION "${_tp_schema}"
            DEPENDENCY_PROVIDER "${_tp_depprovider}" PIXI_LOCK_SHA256 "${_tp_pixi_lock}"
            PIXI_ENVIRONMENT "${arg_PIXI_ENVIRONMENT}")
    endif()

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
            # the pack face names packages by TRIPLET; the ecosystem lane
            # pins its own supplier triplet (arg_TRIPLET stays empty there
            # -- two names would mean cache lookups can never find the pack)
            set(_tp_pkgtriplet "${arg_TRIPLET}")
            if(_tp_eco)
                set(_tp_pkgtriplet "${_tp_eco_triplet}")
            endif()
            _polyorch_tp_package_name(_tp_pkgname "${_tp_name}" "${_tp_version}" "${_tp_pkgtriplet}" "${arg_PROFILE}" "${arg_BUILD_TYPE}" "${_tp_link}" "${_tp_key_SHORT12}" "${_tp_pkgfmt}")
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
            if(_tp_eco)
                # registry root: anchor-local, disposable (O-11=A discipline 3).
                # Computed before the strict gate because the refusal text prints
                # it as part of a copy-pasteable command.
                set(_tp_root "${arg_VCPKG_ROOT_DIR}")
                if(NOT _tp_root)
                    set(_tp_root "${arg_WORK_DIR}/vcpkg-root")
                endif()
                # ---- ecosystem lane (P7a): strict-first (r6 adjudication, the
                # CxxKit NO_FALLBACK philosophy) -- the lane only consumes
                # PRE-BAKED artifacts; with none, it never silently falls
                # back to source and never implicitly fetches the registry ----
                if(NOT arg_GENERATE_ECOSYSTEM)
                    # the refusal is an operator manual, and the manual has to
                    # name THIS provider's tool, env and command -- printing a
                    # vcpkg recipe for a conan miss would send the reader off to
                    # do the wrong thing loudly.
                    if(_tp_provider STREQUAL "conan")
                        set(_tp_tool_hint "pass CONAN_PROGRAM <path>, place a conan in <WORK_DIR>/tools/bin, or let the lane solve the committed pkg-deps/conan-tool island into the anchor with pixi (BOOTSTRAP_TOOL off refuses to download)")
                        set(_tp_manual "  ${CMAKE_COMMAND} -E env CONAN_HOME=${arg_WORK_DIR}/conan-home <conan> install ${_tp_pindir}/conanfile.txt --output-folder=<anchor dir> --deployer=direct_deploy -pr=${_tp_profile_file} -g CMakeDeps --build=missing")
                    else()
                        _polyorch_tp_vcpkg_env("${arg_WORK_DIR}" _tp_strict_env ${_tp_bincache})
                        string(JOIN " " _tp_strict_env_j ${_tp_strict_env})
                        set(_tp_tool_hint "pass VCPKG_PROGRAM <path>, keep a vcpkg already in the registry root, or let the lane bootstrap it into the anchor-local root (BOOTSTRAP_TOOL off refuses to download)")
                        set(_tp_manual "  ${CMAKE_COMMAND} -E env ${_tp_strict_env_j} <vcpkg> --vcpkg-root=${_tp_root} install --x-manifest-root=${_tp_pindir} --triplet=${_tp_eco_triplet}")
                    endif()
                    message(FATAL_ERROR
"polyorch_thirdparty_recipe: ecosystem provider '${_tp_provider}' for '${_tp_name}' has no pre-baked artifact (package cache miss) -- strict-first (P7a/P7b): no auto-fallback to source, no implicit registry fetch.
Generate once (the one network step); every later run is an offline cache hit:
  re-run this same call with GENERATE_ECOSYSTEM ON -- the lane makes a tool available (${_tp_tool_hint}), installs a COPY of the pin island (the in-repo island is never written) and packs the result into PACKAGES_DIR
Or drive the tool yourself with the lane's env:
${_tp_manual}
Or keep this library on provider \"source\" (edit the recipe).")
                endif()
                if(_tp_provider STREQUAL "conan")
                    # ---- conan generate (P7b) ----
                    # four rungs to get the tool, then the version the lock
                    # pins must be the version that runs: a different binary is
                    # not the artifact the key says it is.
                    _polyorch_tp_conan_tool(_tp_conan _tp_conan_ver "${arg_WORK_DIR}" ${_tp_boot} "${arg_CONAN_PROGRAM}")
                    if(NOT _tp_conan_ver STREQUAL "${_tp_tool_version}")
                        message(FATAL_ERROR "polyorch_thirdparty_recipe: conan tool mismatch for '${_tp_name}' -- pkg-deps/conan-tool/pixi.lock pins ${_tp_tool_version} but '${_tp_conan}' reports ${_tp_conan_ver}. Re-solve the island (pixi lock, commit the result) or point CONAN_PROGRAM at the pinned binary; a silent swap would pack bytes the cache key does not describe.")
                    endif()
                    # the island is used through a copy: conan writes presets
                    # and build folders next to the consumer file it is handed
                    # (the same zero-intrusion reason the vcpkg lane copies for
                    # -- that one is measured, this one is prevented).
                    set(_tp_cpin "${arg_WORK_DIR}/${_tp_name}/pin")
                    file(REMOVE_RECURSE "${_tp_cpin}")
                    file(MAKE_DIRECTORY "${_tp_cpin}")
                    execute_process(COMMAND "${CMAKE_COMMAND}" -E copy_directory "${_tp_pindir}" "${_tp_cpin}"
                        RESULT_VARIABLE _tp_rc ERROR_VARIABLE _tp_e)
                    if(NOT _tp_rc EQUAL 0)
                        message(FATAL_ERROR "polyorch_thirdparty_recipe: copying the conan pin island '${_tp_pindir}' into the anchor failed rc=${_tp_rc}: ${_tp_e}")
                    endif()
                    set(_tp_cfile "${_tp_cpin}/conanfile.txt")
                    if(EXISTS "${_tp_cpin}/conanfile.py")
                        set(_tp_cfile "${_tp_cpin}/conanfile.py")
                    endif()
                    set(_tp_chome "${arg_WORK_DIR}/conan-home")
                    file(MAKE_DIRECTORY "${_tp_chome}")
                    set(_tp_dep "${arg_WORK_DIR}/${_tp_name}/deploy-${arg_BUILD_TYPE}")
                    file(REMOVE_RECURSE "${_tp_dep}")
                    # CMakeDeps only, no CMakeToolchain: the toolchain file is
                    # the one generated artifact that pins the host absolute
                    # path (measured), it is not needed to consume a prefix, and
                    # not emitting it is a cheaper guarantee than filtering it
                    # out later. --deployer=direct_deploy is what actually puts
                    # files on disk: without a deployer the output folder holds
                    # generators only and the libraries stay in CONAN_HOME
                    # (measured), which is exactly what a relocatable package
                    # must not depend on. --lockfile is passed EXPLICITLY: an
                    # island that merely contains conan.lock does not make conan
                    # read it, and an unread lock is a pin that silently does
                    # nothing while the key claims it is pinned (measured form:
                    # fmt/11.0.2#<recipe revision>%<timestamp>).
                    execute_process(COMMAND "${CMAKE_COMMAND}" -E env
                            --unset=CPATH --unset=C_INCLUDE_PATH --unset=CPLUS_INCLUDE_PATH
                            --unset=LIBRARY_PATH --unset=COMPILER_PATH --unset=CONDA_PREFIX
                            "CONAN_HOME=${_tp_chome}"
                            "${_tp_conan}" install "${_tp_cfile}"
                            "--output-folder=${_tp_dep}"
                            "--deployer=direct_deploy"
                            "-pr=${_tp_profile_file}"
                            # both slots, explicitly: conan asks for a BUILD
                            # profile as well, and with CONAN_HOME anchored
                            # (empty) it would otherwise demand
                            # `conan profile detect` -- the very fallback this
                            # lane refuses. Same profile for build and host is
                            # the correct statement for a native generate;
                            # cross builds split the two and land in P6.
                            "-pr:b=${_tp_profile_file}"
                            "--lockfile=${_tp_cpin}/conan.lock"
                            "-g" "CMakeDeps"
                            "--build=missing"
                        RESULT_VARIABLE _tp_rc OUTPUT_VARIABLE _tp_o ERROR_VARIABLE _tp_e)
                    if(NOT _tp_rc EQUAL 0)
                        message(FATAL_ERROR "polyorch_thirdparty_recipe: conan install for '${_tp_name}' failed rc=${_tp_rc}:\n${_tp_o}${_tp_e}")
                    endif()
                    file(GLOB _tp_pkgs "${_tp_dep}/direct_deploy/*")
                    if(NOT _tp_pkgs)
                        message(FATAL_ERROR "polyorch_thirdparty_recipe: the conan generate delivered no packages under ${_tp_dep}/direct_deploy -- strict about layout, never silent (profile ${_tp_profile_name})")
                    endif()
                    # curated copy, layout preserved: the CMakeDeps configs
                    # resolve the package trees through
                    # ${CMAKE_CURRENT_LIST_DIR}/direct_deploy/<pkg> (measured),
                    # so the configs and the trees travel together or not at all
                    # -- and that is what makes the prefix survive relocation.
                    file(MAKE_DIRECTORY "${_tp_installdir}")
                    file(GLOB _tp_cfgs "${_tp_dep}/*.cmake")
                    foreach(_tp_c IN LISTS _tp_cfgs)
                        get_filename_component(_tp_cb "${_tp_c}" NAME)
                        if(_tp_cb STREQUAL "conan_toolchain.cmake")
                            continue()
                        endif()
                        file(COPY "${_tp_c}" DESTINATION "${_tp_installdir}")
                    endforeach()
                    execute_process(COMMAND "${CMAKE_COMMAND}" -E copy_directory
                            "${_tp_dep}/direct_deploy" "${_tp_installdir}/direct_deploy"
                        RESULT_VARIABLE _tp_rc ERROR_VARIABLE _tp_e)
                    if(NOT _tp_rc EQUAL 0)
                        message(FATAL_ERROR "polyorch_thirdparty_recipe: copying the deployed packages into ${_tp_installdir} failed: ${_tp_e}")
                    endif()
                    # relocate gate (F5): no exemption for ecosystem output
                    _polyorch_tp_relocate_audit("${_tp_installdir}" _tp_rel_ok _tp_rel_why)
                    if(NOT _tp_rel_ok)
                        message(FATAL_ERROR "polyorch_thirdparty_recipe: conan output for '${_tp_name}' fails the relocate gate -- ${_tp_rel_why} (relativize the file or keep the package local; no silent exemption)")
                    endif()
                    polyorch_thirdparty_manifest_write(MANIFEST "${_tp_manifest}" KEY "${_tp_key}"
                        NAME "${_tp_name}" VERSION "${_tp_version}" LICENSE "${_tp_license}"
                        PROVIDER "${_tp_provider}" TRIPLET "${_tp_eco_triplet}"
                        BUILD_TYPE "${arg_BUILD_TYPE}"
                        LINK_MODE "${_tp_link}" ARCHIVE_SHA256 "${_tp_arch_hash}"
                        RECIPE_SHA256 "${_tp_recipe_hash}" SCHEMA_VERSION "${_tp_schema}"
                        ECOSYSTEM_PIN_SHA256 "${_tp_pin_hash}" ECOSYSTEM_TRIPLET "${_tp_eco_triplet}"
                        ECOSYSTEM_TOOL_VERSION "${_tp_tool_version}"
                        ECOSYSTEM_PROFILE_SHA256 "${_tp_profile_hash}")
                    if(arg_PACKAGES_DIR)
                        polyorch_thirdparty_package(NAME "${_tp_name}" INSTALL_DIR "${_tp_installdir}"
                            PACKAGE_DIR "${arg_PACKAGES_DIR}" MANIFEST "${_tp_manifest}"
                            FORMAT "${_tp_pkgfmt}" TRIPLET "${_tp_eco_triplet}" PACKAGE_OUT _tp_pkgfile)
                    endif()
                    message(STATUS "polyorch thirdparty: ${_tp_name} ecosystem generate (${_tp_provider}/${_tp_eco_triplet}) key=${_tp_key_SHORT12} conan=${_tp_tool_version} -- packed into the cache")
                else()
                # ---- GENERATE_ECOSYSTEM: the one explicit network step ----
                find_program(_tp_git NAMES git)
                if(NOT _tp_git)
                    message(FATAL_ERROR "polyorch_thirdparty_recipe: GENERATE_ECOSYSTEM needs git (the registry root is a checkout at the pinned baseline)")
                endif()
                if(NOT EXISTS "${_tp_root}/.git")
                    execute_process(COMMAND "${_tp_git}" clone --filter=tree:0 --no-checkout
                            https://github.com/microsoft/vcpkg.git "${_tp_root}"
                        RESULT_VARIABLE _tp_rc OUTPUT_VARIABLE _tp_o ERROR_VARIABLE _tp_e)
                    if(NOT _tp_rc EQUAL 0)
                        message(FATAL_ERROR "polyorch_thirdparty_recipe: cloning the vcpkg registry (treeless) failed rc=${_tp_rc}: ${_tp_e}")
                    endif()
                endif()
                # checkout the pinned baseline (a treeless clone fetches the
                # missing commit on demand; two tries, then loud). NOTE: no
                # --depth 1 -- CxxKit measured that a shallow clone cannot
                # check out baseline trees ('failed to unpack tree object').
                if(NOT "${_tp_island_json}" MATCHES "\"builtin-baseline\"[ ]*:")
                    message(FATAL_ERROR "polyorch_thirdparty_recipe: pin island '${_tp_pindir}/vcpkg.json' carries no builtin-baseline -- an unpinned registry is exactly what O-10 refuses")
                endif()
                string(JSON _tp_baseline GET "${_tp_island_json}" builtin-baseline)
                execute_process(COMMAND "${_tp_git}" -C "${_tp_root}" checkout "${_tp_baseline}"
                    RESULT_VARIABLE _tp_rc OUTPUT_VARIABLE _tp_o ERROR_VARIABLE _tp_e)
                if(NOT _tp_rc EQUAL 0)
                    execute_process(COMMAND "${_tp_git}" -C "${_tp_root}" fetch origin "${_tp_baseline}"
                        RESULT_VARIABLE _tp_rc OUTPUT_VARIABLE _tp_o ERROR_VARIABLE _tp_e)
                    if(NOT _tp_rc EQUAL 0)
                        message(FATAL_ERROR "polyorch_thirdparty_recipe: fetching baseline ${_tp_baseline} into the registry root failed rc=${_tp_rc}: ${_tp_e}")
                    endif()
                    execute_process(COMMAND "${_tp_git}" -C "${_tp_root}" checkout "${_tp_baseline}"
                        RESULT_VARIABLE _tp_rc OUTPUT_VARIABLE _tp_o ERROR_VARIABLE _tp_e)
                    if(NOT _tp_rc EQUAL 0)
                        message(FATAL_ERROR "polyorch_thirdparty_recipe: checkout of baseline ${_tp_baseline} failed rc=${_tp_rc}: ${_tp_e}")
                    endif()
                endif()
                # ---- tool, four rungs (PATH is never searched silently) ----
                # 1 explicit call-site path; 2 a vcpkg already in the root (the
                # user cloned+bootstrapped, or our own bootstrap below); 3 the
                # anchor's tool island (the O4=A vendored form); 4 bootstrap
                # INTO the root -- the release tag+sha the pinned baseline names
                # makes the tool a derivation of the pin, so no new drift enters
                # the picture; BOOTSTRAP_TOOL off stops at the refusal.
                # Why the root and not anywhere: measured -- vcpkg derives its
                # root from the executable's own directory and IGNORES
                # VCPKG_ROOT when the two disagree, so an external tool writes
                # its buildtrees next to itself (outside the anchor, often
                # unwritable). --vcpkg-root is passed explicitly on every call.
                set(_tp_vcpkg_exe "${arg_VCPKG_PROGRAM}")
                if(NOT _tp_vcpkg_exe AND EXISTS "${_tp_root}/vcpkg")
                    set(_tp_vcpkg_exe "${_tp_root}/vcpkg")
                endif()
                if(NOT _tp_vcpkg_exe)
                    find_program(_tp_vcpkg_exe NAMES vcpkg
                        PATHS "${arg_WORK_DIR}/tools/bin" "${arg_WORK_DIR}/bin"
                        NO_DEFAULT_PATH)
                endif()
                if(NOT _tp_vcpkg_exe)
                    if(NOT _tp_boot)
                        message(FATAL_ERROR "polyorch_thirdparty_recipe: GENERATE_ECOSYSTEM for '${_tp_name}' found no vcpkg tool and BOOTSTRAP_TOOL is off (no download) -- pass VCPKG_PROGRAM <path>, place a vcpkg at ${_tp_root}/vcpkg or in <WORK_DIR>/tools/bin, or drop BOOTSTRAP_TOOL to let the lane bootstrap ${_tp_root}/bootstrap-vcpkg.sh")
                    endif()
                    set(_tp_bs "${_tp_root}/bootstrap-vcpkg.sh")
                    if(WIN32)
                        set(_tp_bs "${_tp_root}/bootstrap-vcpkg.bat")
                    endif()
                    if(NOT EXISTS "${_tp_bs}")
                        message(FATAL_ERROR "polyorch_thirdparty_recipe: no vcpkg tool and no bootstrap script at ${_tp_bs} (registry root ${_tp_root} is not a vcpkg checkout at ${_tp_baseline})")
                    endif()
                    message(STATUS "polyorch thirdparty: bootstrapping the vcpkg tool into ${_tp_root} (release tag+sha named by baseline ${_tp_baseline})")
                    execute_process(COMMAND "${CMAKE_COMMAND}" -E env "VCPKG_DISABLE_METRICS=1" "${_tp_bs}" -disableMetrics
                        WORKING_DIRECTORY "${_tp_root}"
                        RESULT_VARIABLE _tp_rc OUTPUT_VARIABLE _tp_o ERROR_VARIABLE _tp_e)
                    if(NOT _tp_rc EQUAL 0 OR NOT EXISTS "${_tp_root}/vcpkg")
                        message(FATAL_ERROR "polyorch_thirdparty_recipe: bootstrapping vcpkg in ${_tp_root} failed rc=${_tp_rc}:\n${_tp_o}${_tp_e}")
                    endif()
                    set(_tp_vcpkg_exe "${_tp_root}/vcpkg")
                endif()
                # static triplet variants are OURS to write (O-12=C): a tiny
                # overlay triplet beside the anchor, never inside the root
                set(_tp_overlay_args "")
                if(_tp_eco_triplet MATCHES "^([a-z0-9]+)-(linux|osx)-static$")
                    string(REGEX REPLACE "^([a-z0-9]+)-(linux|osx)-static$" "\\1" _tp_tri_arch "${_tp_eco_triplet}")
                    string(REGEX REPLACE "^([a-z0-9]+)-(linux|osx)-static$" "\\2" _tp_tri_sys "${_tp_eco_triplet}")
                    if(_tp_tri_sys STREQUAL "linux")
                        set(_tp_tri_cmake_sys "Linux")
                    else()
                        set(_tp_tri_cmake_sys "Darwin")
                    endif()
                    file(WRITE "${arg_WORK_DIR}/triplets/${_tp_eco_triplet}.cmake"
"# Generated by PolyOrch (P7a ecosystem lane) -- static-library overlay.
set(VCPKG_TARGET_ARCHITECTURE ${_tp_tri_arch})
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)
set(VCPKG_CMAKE_SYSTEM_NAME ${_tp_tri_cmake_sys})
set(VCPKG_BUILD_TYPE release)
")
                    set(_tp_overlay_args "--overlay-triplets=${arg_WORK_DIR}/triplets")
                elseif(_tp_eco_triplet MATCHES "-static$")
                    message(FATAL_ERROR "polyorch_thirdparty_recipe: triplet '${_tp_eco_triplet}' needs an overlay triplet this lane does not generate -- pass a TRIPLET the lane knows (x64/arm64 linux/osx) or extend the generator")
                endif()
                # ---- the island is a read-only input: install a copy ----
                # measured: manifest-mode install writes vcpkg_installed/ INTO
                # the manifest root, and that root is the in-repo pin island --
                # zero-intrusion forbids polluting it.
                set(_tp_pincopy "${arg_WORK_DIR}/${_tp_name}/pin")
                file(REMOVE_RECURSE "${_tp_pincopy}")
                file(MAKE_DIRECTORY "${_tp_pincopy}")
                execute_process(COMMAND "${CMAKE_COMMAND}" -E copy_directory "${_tp_pindir}" "${_tp_pincopy}"
                    RESULT_VARIABLE _tp_rc OUTPUT_VARIABLE _tp_o ERROR_VARIABLE _tp_e)
                if(NOT _tp_rc EQUAL 0)
                    message(FATAL_ERROR "polyorch_thirdparty_recipe: copying the pin island '${_tp_pindir}' into the anchor failed rc=${_tp_rc}: ${_tp_e}")
                endif()
                _polyorch_tp_vcpkg_env("${arg_WORK_DIR}" _tp_envlist ${_tp_bincache})
                # install into the ephemeral root (never the verdict source)
                execute_process(COMMAND "${CMAKE_COMMAND}" -E env
                        --unset=CPATH --unset=C_INCLUDE_PATH --unset=CPLUS_INCLUDE_PATH
                        --unset=LIBRARY_PATH --unset=COMPILER_PATH --unset=CONDA_PREFIX
                        ${_tp_envlist}
                        "${_tp_vcpkg_exe}" "--vcpkg-root=${_tp_root}" install
                        "--x-manifest-root=${_tp_pincopy}"
                        "--triplet=${_tp_eco_triplet}" ${_tp_overlay_args}
                    WORKING_DIRECTORY "${_tp_root}"
                    RESULT_VARIABLE _tp_rc OUTPUT_VARIABLE _tp_o ERROR_VARIABLE _tp_e)
                if(NOT _tp_rc EQUAL 0)
                    message(FATAL_ERROR "polyorch_thirdparty_recipe: vcpkg install for '${_tp_name}' (${_tp_eco_triplet}) failed rc=${_tp_rc}:\n${_tp_o}${_tp_e}")
                endif()
                # manifest mode already produced the flat prefix:
                # <island copy>/vcpkg_installed/<triplet>/{include,lib,share}.
                # No export --raw step: measured, it needs every port named
                # explicitly (it exports zero packages otherwise) and it only
                # repacks a tree this lane can consume directly.
                set(_tp_exp "${_tp_pincopy}/vcpkg_installed/${_tp_eco_triplet}")
                if(NOT EXISTS "${_tp_exp}")
                    message(FATAL_ERROR "polyorch_thirdparty_recipe: vcpkg installed no '${_tp_eco_triplet}' tree under ${_tp_pincopy}/vcpkg_installed -- the generate did not produce the prefix (baseline ${_tp_baseline})")
                endif()
                # relocate gate (F5): ecosystem output earns no exemption --
                # a pc/config pinning the generate host refuses to pack
                _polyorch_tp_relocate_audit("${_tp_exp}" _tp_rel_ok _tp_rel_why)
                if(NOT _tp_rel_ok)
                    message(FATAL_ERROR "polyorch_thirdparty_recipe: ecosystem output for '${_tp_name}' fails the relocate gate -- ${_tp_rel_why} (relativize the file or keep the package local; no silent exemption)")
                endif()
                file(MAKE_DIRECTORY "${_tp_installdir}")
                execute_process(COMMAND "${CMAKE_COMMAND}" -E copy_directory "${_tp_exp}" "${_tp_installdir}"
                    RESULT_VARIABLE _tp_rc OUTPUT_VARIABLE _tp_o ERROR_VARIABLE _tp_e)
                if(NOT _tp_rc EQUAL 0)
                    message(FATAL_ERROR "polyorch_thirdparty_recipe: copying the generated prefix into ${_tp_installdir} failed rc=${_tp_rc}: ${_tp_e}")
                endif()
                polyorch_thirdparty_manifest_write(MANIFEST "${_tp_manifest}" KEY "${_tp_key}"
                    NAME "${_tp_name}" VERSION "${_tp_version}" LICENSE "${_tp_license}"
                    PROVIDER "${_tp_provider}" TRIPLET "${_tp_eco_triplet}"
                    BUILD_TYPE "${arg_BUILD_TYPE}"
                    LINK_MODE "${_tp_link}" ARCHIVE_SHA256 "${_tp_arch_hash}"
                    RECIPE_SHA256 "${_tp_recipe_hash}" SCHEMA_VERSION "${_tp_schema}"
                    ECOSYSTEM_PIN_SHA256 "${_tp_pin_hash}" ECOSYSTEM_TRIPLET "${_tp_eco_triplet}")
                if(arg_PACKAGES_DIR)
                    polyorch_thirdparty_package(NAME "${_tp_name}" INSTALL_DIR "${_tp_installdir}"
                        PACKAGE_DIR "${arg_PACKAGES_DIR}" MANIFEST "${_tp_manifest}"
                        FORMAT "${_tp_pkgfmt}" TRIPLET "${_tp_eco_triplet}" PACKAGE_OUT _tp_pkgfile)
                endif()
                message(STATUS "polyorch thirdparty: ${_tp_name} ecosystem generate (${_tp_provider}/${_tp_eco_triplet}) key=${_tp_key_SHORT12} -- packed into the cache")
                endif()
            else()
            # ---- build (explicit verb, H2) ----
            set(_tp_cmake_args "")
            foreach(_tp_o IN LISTS _tp_opts)
                list(APPEND _tp_cmake_args "-D${_tp_o}")
            endforeach()
            # static recipe options first, then the call-site dynamic args
            # (provider compilers ride this channel -- r4 C1 keeps them out
            # of the JSON because choosing a compiler is a decision, not a
            # fact about the artifact)
            list(APPEND _tp_cmake_args ${arg_CMAKE_ARGS})
            polyorch_thirdparty_build(NAME "${_tp_name}" SOURCE_DIR "${_tp_src}"
                BUILD_DIR "${_tp_builddir}" INSTALL_DIR "${_tp_installdir}"
                BUILD_TYPE "${arg_BUILD_TYPE}" GENERATOR "${arg_GENERATOR}"
                MAKE_PROGRAM "${arg_MAKE_PROGRAM}"
                DEPENDENCY_PROVIDER "${arg_DEPENDENCY_PROVIDER}" PIXI_ENVIRONMENT "${arg_PIXI_ENVIRONMENT}"
                PARALLEL "${arg_PARALLEL}" CMAKE_ARGS ${_tp_cmake_args})

            # ---- pixi runtime audit (discipline 4): static linking is not
            # runtime independence; a pixi-prefixed RUNPATH marks the manifest
            # instead of silently shipping ----
            set(_tp_pr_flag "")
            if(_tp_depprovider STREQUAL "pixi")
                _polyorch_tp_pixi_subpaths("${arg_PIXI_ENVIRONMENT}" _tp_aprefix _tp_asubs _tp_apc)
                _polyorch_tp_pixi_audit("${_tp_installdir}" "${_tp_aprefix}" _tp_needs _tp_adetail)
                if(_tp_needs)
                    message(WARNING "polyorch thirdparty: ${_tp_name} NEEDS THE PIXI RUNTIME at load time -- ${_tp_adetail} (not a standalone release piece)")
                    set(_tp_pr_flag PIXI_RUNTIME_REQUIRED)
                else()
                    message(STATUS "polyorch thirdparty: ${_tp_name} pixi audit -- ${_tp_adetail}")
                endif()
            endif()

            # ---- manifest ----
            polyorch_thirdparty_manifest_write(MANIFEST "${_tp_manifest}" KEY "${_tp_key}"
                NAME "${_tp_name}" VERSION "${_tp_version}" LICENSE "${_tp_license}"
                PROVIDER "${_tp_provider}" PROFILE "${arg_PROFILE}" TRIPLET "${arg_TRIPLET}"
                BUILD_TYPE "${arg_BUILD_TYPE}"
                LINK_MODE "${_tp_link}" OPTIONS ${_tp_opts} ARCHIVE_SHA256 "${_tp_arch_hash}"
                RECIPE_SHA256 "${_tp_recipe_hash}" SCHEMA_VERSION "${_tp_schema}"
                DEPENDENCY_PROVIDER "${_tp_depprovider}" ${_tp_pr_flag})

            # ---- pack into the shared cache (P2; empty dir = no-op) ----
            if(arg_PACKAGES_DIR)
                polyorch_thirdparty_package(NAME "${_tp_name}" INSTALL_DIR "${_tp_installdir}"
                    PACKAGE_DIR "${arg_PACKAGES_DIR}" MANIFEST "${_tp_manifest}"
                    FORMAT "${_tp_pkgfmt}" TRIPLET "${arg_TRIPLET}" PACKAGE_OUT _tp_pkgfile)
            endif()
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
