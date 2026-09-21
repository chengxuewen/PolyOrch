# PolyOrch Pixi helpers -- a checked CMake marshal over the pixi command line.
#
# Pixi owns the environment (pixi.toml + pixi.lock). This module only builds
# argument vectors, runs them, and reads pixi's own output back. Nothing here
# parses or edits TOML by hand: CMake has no TOML parser, and every manifest
# section that matters already has a pixi subcommand that writes it correctly.
#
# Two things CMake structurally cannot do, so the API does not pretend to:
#   * It cannot activate the caller's shell (it is a child process). Use
#     polyorch_pixi_activate_script() to hand a human a file to source, or
#     polyorch_pixi_env_paths() to inject the environment into this CMake run.
#   * It cannot install pixi as a side effect of configure: the cmake binary is
#     normally supplied by pixi, so an automatic call is a chicken-and-egg loop.
#     polyorch_pixi_tool_install() exists but must be invoked explicitly.
#
# Timing contract -- pick the wrong phase and a configure silently mutates the
# repository or reaches the network:
#   READ-ONLY, configure-safe : find, setup, env_paths, report, channel(list),
#                              mirror(list)
#   BUILD TIME, stamp target  : env_target (runs `pixi install`)
#   EXPLICIT ACTION ONLY      : init, dependency, task_add, environment_add,
#                              channel(add/remove), mirror(set/write), config_set,
#                              publish, tool_install, tool_ensure, scripts_install,
#                              bootstrap -- these write pixi.toml / pixi.lock /
#                              .pixi/config.toml or touch $HOME.
#                              A CI or configure step must use the frozen paths
#                              instead (install / env_target with FROZEN).
#
# CLI notes, each read off `pixi <cmd> --help` on the pinned pixi 0.78.0:
#   * -m/--manifest-path plus --config-file/--no-config (env PIXI_CONFIG_FILE,
#     PIXI_NO_CONFIG) are accepted by install/add/remove/lock/publish/info/
#     shell-hook/workspace ...; `init` and `config` are the exceptions, so calls
#     for those pass BARE.
#   * `pixi info --json` exposes global_info.env_dir and
#     project_info.manifest_path, but NOT a per-environment prefix -> the env
#     location is resolved by rule (<manifest dir>/.pixi/envs/<env>) with the
#     global env_dir as fallback, never hardcoded.
#   * default-channels only applies when the manifest declares no `channels`, so
#     mirroring an existing workspace needs channel(add/remove) or a template
#     regen, not default-channels.
#   * `workspace feature` has list/remove only; features appear as a side effect
#     of `add -f <feat>` / `task add -f <feat>` (measured: [feature.myfeat.tasks]
#     auto-created). There is no "create an empty feature" verb.
#   * `pixi add` has no --dry-run; `pixi lock` does have --check/--dry-run, so
#     preview belongs there.
#   * The PyPI package literally named "pixi" is an unrelated project (different
#     author), so tool_install() never uses pip. conda-forge does ship pixi.
#   * The verified knobs of https://pixi.sh/install.sh are PIXI_VERSION (L27),
#     PIXI_DOWNLOAD_URL (L67) and PIXI_HOME; the .ps1 knobs were not checked.
#
# Requires CMake >= 3.22 (string(JSON), cmake_parse_arguments(PARSE_ARGV)).

include_guard(GLOBAL)

# Register this directory so consumers can include(PolyOrchPixiHelpers) instead
# of hardcoding the path to this file.
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}")

set(PolyOrch_PIXI_EXECUTABLE "" CACHE FILEPATH
    "pixi binary; empty = search PATH and the default install locations")
set(PolyOrch_PIXI_MANIFEST "" CACHE FILEPATH
    "pixi.toml/pyproject.toml driving every call; empty = search upward")
set(PolyOrch_PIXI_ENVIRONMENT "default" CACHE STRING
    "pixi environment (feature set) used by every call")
set(PolyOrch_PIXI_CONFIG_FILE "" CACHE FILEPATH
    "pixi config file passed as --config-file; empty = pixi default search")
set(PolyOrch_PIXI_NO_CONFIG OFF CACHE BOOL
    "pass --no-config, ignoring user and system pixi configuration")

# ---------------------------------------------------------------- internals ---

# Internal: nearest pixi.toml / pyproject.toml at or above START.
function(_polyorch_pixi_search_manifest OUT START)
    set(_d "${START}")
    set(_found "")
    while(NOT _found AND NOT _d STREQUAL "")
        foreach(_name pixi.toml pyproject.toml)
            if(EXISTS "${_d}/${_name}")
                set(_found "${_d}/${_name}")
                break()
            endif()
        endforeach()
        if(_found)
            break()
        endif()
        get_filename_component(_d "${_d}" DIRECTORY)
    endwhile()
    set(${OUT} "${_found}" PARENT_SCOPE)
endfunction()

# Internal: assemble a pixi command line = binary + argv + context flags.
# BARE drops the -m / --config-file context (init and config reject it).
function(_polyorch_pixi_command OUT)
    if(NOT PolyOrch_PIXI_EXECUTABLE)
        message(FATAL_ERROR "PolyOrch_PIXI_EXECUTABLE is empty; call polyorch_pixi_find() first")
    endif()
    set(options BARE)
    cmake_parse_arguments(PARSE_ARGV 1 C "${options}" "" "")
    set(_cmd "${PolyOrch_PIXI_EXECUTABLE}")
    list(APPEND _cmd ${C_UNPARSED_ARGUMENTS})
    if(NOT C_BARE)
        if(PolyOrch_PIXI_MANIFEST)
            list(APPEND _cmd -m "${PolyOrch_PIXI_MANIFEST}")
        endif()
        if(PolyOrch_PIXI_CONFIG_FILE)
            list(APPEND _cmd --config-file "${PolyOrch_PIXI_CONFIG_FILE}")
        elseif(PolyOrch_PIXI_NO_CONFIG)
            list(APPEND _cmd --no-config)
        endif()
    endif()
    set(${OUT} "${_cmd}" PARENT_SCOPE)
endfunction()

# Internal: run pixi without failing.
# _polyorch_pixi_run(<rc> <stdout> <stderr> [BARE] <argv...>)
function(_polyorch_pixi_run RESULT OUT ERR)
    set(options BARE)
    cmake_parse_arguments(PARSE_ARGV 3 R "${options}" "" "")
    if(R_BARE)
        _polyorch_pixi_command(_cmd BARE ${R_UNPARSED_ARGUMENTS})
    else()
        _polyorch_pixi_command(_cmd ${R_UNPARSED_ARGUMENTS})
    endif()
    execute_process(COMMAND ${_cmd}
        RESULT_VARIABLE _rc
        OUTPUT_VARIABLE _o
        ERROR_VARIABLE _e)
    set(${RESULT} ${_rc} PARENT_SCOPE)
    set(${OUT} "${_o}" PARENT_SCOPE)
    set(${ERR} "${_e}" PARENT_SCOPE)
endfunction()

# Internal: run pixi, hard-fail with its own diagnostics when it exits non-zero.
# _polyorch_pixi_must([OUT <var>] [BARE] <argv...>)
function(_polyorch_pixi_must)
    set(options BARE)
    set(oneValueArgs OUT)
    cmake_parse_arguments(PARSE_ARGV 0 M "${options}" "${oneValueArgs}" "")
    # Forward the BARE marker: cmake_parse_arguments consumes it into M_BARE, so
    # dropping it here would silently re-add the -m/--config context to the very
    # subcommands that reject it (init, config).
    set(_flags "")
    if(M_BARE)
        set(_flags BARE)
    endif()
    if(M_UNPARSED_ARGUMENTS)
        _polyorch_pixi_run(_rc _out _err ${_flags} ${M_UNPARSED_ARGUMENTS})
    else()
        message(FATAL_ERROR "internal: _polyorch_pixi_must called with no argv")
    endif()
    list(JOIN M_UNPARSED_ARGUMENTS " " _shown)
    if(NOT _rc EQUAL 0)
        message(FATAL_ERROR
            "pixi exited ${_rc}: ${_shown}\n--- stdout ---\n${_out}--- stderr ---\n${_err}")
    endif()
    if(M_OUT)
        set(${M_OUT} "${_out}" PARENT_SCOPE)
    endif()
endfunction()

# Internal: mutations need a located binary and a resolved manifest.
function(_polyorch_pixi_require_context)
    if(NOT PolyOrch_PIXI_EXECUTABLE OR NOT PolyOrch_PIXI_MANIFEST)
        message(FATAL_ERROR
            "call polyorch_pixi_setup() first (or polyorch_pixi_find() plus "
            "-DPolyOrch_PIXI_MANIFEST=<path>)")
    endif()
endfunction()

# Internal: append `-e <env>` only when an environment is named; empty means
# "let pixi pick", which is what the flag-less form does anyway.
function(_polyorch_pixi_env_arg LIST_VAR ENVIRONMENT)
    if(ENVIRONMENT)
        set(${LIST_VAR} ${${LIST_VAR}} -e "${ENVIRONMENT}" PARENT_SCOPE)
    endif()
endfunction()

# Internal: quoted JSON array literal from plain channel names/URLs. JSON (unlike
# TOML) forbids a trailing comma, so join rather than trim: string(SUBSTRING s
# 0 -1) means "to the end", not "drop the last character".
function(_polyorch_pixi_json_array OUT)
    if(NOT ARGN)
        message(FATAL_ERROR "no channel names/URLs given")
    endif()
    set(_items "")
    foreach(_item IN LISTS ARGN)
        if(_item MATCHES "\"" OR _item MATCHES ";")
            message(FATAL_ERROR "not a usable channel name/URL: ${_item}")
        endif()
        list(APPEND _items "\"${_item}\"")
    endforeach()
    list(JOIN _items "," _joined)
    set(${OUT} "[${_joined}]" PARENT_SCOPE)
endfunction()

# Internal: a unique writable scratch directory. In script mode (cmake -P),
# CMAKE_CURRENT_BINARY_DIR is the invocation cwd -- trusting it there would
# litter the source tree (measured), so a real build dir only wins outside
# script mode; otherwise the environment temp. Never the source tree.
function(_polyorch_pixi_scratch OUT)
    if(CMAKE_CURRENT_BINARY_DIR AND NOT CMAKE_SCRIPT_MODE_FILE)
        set(_base "${CMAKE_CURRENT_BINARY_DIR}")
    elseif(DEFINED ENV{TMPDIR} AND NOT "$ENV{TMPDIR}" STREQUAL "")
        set(_base "$ENV{TMPDIR}")
    elseif(DEFINED ENV{TEMP} AND NOT "$ENV{TEMP}" STREQUAL "")
        set(_base "$ENV{TEMP}")
    else()
        set(_base "/tmp")
    endif()
    string(RANDOM LENGTH 8 ALPHABET "0123456789abcdef" _rnd)
    set(_dir "${_base}/polyorch-${_rnd}")
    file(MAKE_DIRECTORY "${_dir}")
    set(${OUT} "${_dir}" PARENT_SCOPE)
endfunction()

# ------------------------------------------------------------------- locate ---

# polyorch_pixi_find([VERSION <x.y.z>] [REQUIRED] [QUIET])
# Locate pixi and record PolyOrch_PIXI_EXECUTABLE / PolyOrch_PIXI_VERSION.
# Never installs anything: on a miss it prints the exact command to run.
function(polyorch_pixi_find)
    set(options REQUIRED QUIET)
    set(oneValueArgs VERSION)
    cmake_parse_arguments(PARSE_ARGV 0 F "${options}" "${oneValueArgs}" "")
    if(F_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "polyorch_pixi_find: unknown args: ${F_UNPARSED_ARGUMENTS}")
    endif()

    if(NOT PolyOrch_PIXI_EXECUTABLE)
        set(_hints "$ENV{HOME}/.pixi/bin")
        if(DEFINED ENV{PIXI_HOME})
            list(APPEND _hints "$ENV{PIXI_HOME}/bin")
        endif()
        # Search under a scratch name first: find_program() silently refuses to
        # search when the named cache entry already exists with an empty value
        # (measured on CMake 4.4.3), and this file declares that entry above.
        find_program(_polyorch_pixi_progs NAMES pixi PATHS ${_hints})
        if(_polyorch_pixi_progs)
            set(PolyOrch_PIXI_EXECUTABLE "${_polyorch_pixi_progs}" CACHE FILEPATH
                "pixi binary; empty = search PATH and the default install locations" FORCE)
        endif()
    endif()

    if(NOT PolyOrch_PIXI_EXECUTABLE)
        set(_msg "pixi not found (searched PATH, ${_hints}).")
        string(CONCAT _fix
            "Install it, then re-run cmake:\n"
            "  curl -fsSL https://pixi.sh/install.sh | sh          # POSIX\n"
            "  iwr https://pixi.sh/install.ps1 -useb | iex         # Windows\n"
            "  <conda|micromamba|mamba> install -c conda-forge pixi\n"
            "or call polyorch_pixi_tool_install() explicitly.")
        if(F_REQUIRED)
            message(FATAL_ERROR "${_msg}\n${_fix}")
        elseif(NOT F_QUIET)
            message(WARNING "${_msg}\n${_fix}")
        endif()
        return()
    endif()

    execute_process(COMMAND "${PolyOrch_PIXI_EXECUTABLE}" --version
        RESULT_VARIABLE _rc
        OUTPUT_VARIABLE _out
        ERROR_VARIABLE _err)
    if(NOT _rc EQUAL 0)
        message(FATAL_ERROR
            "pixi at ${PolyOrch_PIXI_EXECUTABLE} does not run (exit ${_rc}): ${_err}")
    endif()
    string(REGEX MATCH "[0-9]+\\.[0-9]+\\.[0-9]+" _version "${_out}")
    set(PolyOrch_PIXI_VERSION "${_version}" CACHE STRING
        "pixi version reported by --version" FORCE)

    if(F_VERSION AND _version VERSION_LESS F_VERSION)
        message(FATAL_ERROR
            "pixi ${_version} is older than the required ${F_VERSION}\n"
            "fix: pixi self-update --version ${F_VERSION}")
    endif()
    if(NOT F_QUIET)
        message(STATUS "pixi ${_version} found: ${PolyOrch_PIXI_EXECUTABLE}")
    endif()
endfunction()

# polyorch_pixi_setup([MANIFEST <p>] [ENVIRONMENT <n>] [VERSION <x.y.z>]
#                     [INSTALL] [FROZEN] [LOCKED] [EXPORT_PREFIX] [PREFIX_OUT <v>]
#                     [ACTIVATE_SCRIPT <f>] [SHELL <s>] [COPY_SCRIPTS] [REPORT])
# One-call entry point: locate, resolve the manifest, then optionally install
# the environment, export its prefix into this CMake run, write an activation
# script, and print what was chosen.
function(polyorch_pixi_setup)
    set(options INSTALL FROZEN LOCKED EXPORT_PREFIX REPORT COPY_SCRIPTS)
    set(oneValueArgs MANIFEST ENVIRONMENT VERSION ACTIVATE_SCRIPT SHELL PREFIX_OUT)
    cmake_parse_arguments(PARSE_ARGV 0 S "${options}" "${oneValueArgs}" "")
    if(S_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "polyorch_pixi_setup: unknown args: ${S_UNPARSED_ARGUMENTS}")
    endif()
    if(S_FROZEN AND S_LOCKED)
        message(FATAL_ERROR "polyorch_pixi_setup: FROZEN and LOCKED are mutually exclusive")
    endif()

    if(S_VERSION)
        polyorch_pixi_find(REQUIRED VERSION "${S_VERSION}")
    else()
        polyorch_pixi_find(REQUIRED)
    endif()

    set(_manifest "${S_MANIFEST}")
    if(NOT _manifest)
        set(_manifest "${PolyOrch_PIXI_MANIFEST}")
    endif()
    if(NOT _manifest)
        _polyorch_pixi_search_manifest(_manifest "${CMAKE_CURRENT_SOURCE_DIR}")
    endif()
    if(NOT _manifest)
        message(FATAL_ERROR
            "no pixi.toml or pyproject.toml at or above ${CMAKE_CURRENT_SOURCE_DIR}\n"
            "fix: pass MANIFEST <path> or configure -DPolyOrch_PIXI_MANIFEST=<path>")
    endif()
    cmake_path(ABSOLUTE_PATH _manifest NORMALIZE)
    if(NOT EXISTS "${_manifest}")
        message(FATAL_ERROR "manifest does not exist: ${_manifest}")
    endif()
    set(PolyOrch_PIXI_MANIFEST "${_manifest}" CACHE FILEPATH
        "pixi.toml/pyproject.toml driving every call; empty = search upward" FORCE)
    if(S_ENVIRONMENT)
        set(PolyOrch_PIXI_ENVIRONMENT "${S_ENVIRONMENT}" CACHE STRING
            "pixi environment (feature set) used by every call" FORCE)
    endif()

    if(S_INSTALL)
        set(_install "")
        if(S_FROZEN)
            set(_install FROZEN)
        elseif(S_LOCKED)
            set(_install LOCKED)
        endif()
        polyorch_pixi_install(${_install} ENVIRONMENT "${PolyOrch_PIXI_ENVIRONMENT}")
    endif()

    if(S_ACTIVATE_SCRIPT)
        polyorch_pixi_activate_script(OUTPUT "${S_ACTIVATE_SCRIPT}"
            SHELL "${S_SHELL}" ENVIRONMENT "${PolyOrch_PIXI_ENVIRONMENT}")
    endif()

    if(S_COPY_SCRIPTS)
        polyorch_pixi_scripts_install()
    endif()

    if(S_EXPORT_PREFIX)
        polyorch_pixi_env_paths(ENVIRONMENT "${PolyOrch_PIXI_ENVIRONMENT}"
            PREFIX_OUT _prefix)
        if(S_PREFIX_OUT)
            set(${S_PREFIX_OUT} "${_prefix}" PARENT_SCOPE)
        endif()
    endif()

    if(S_REPORT)
        polyorch_pixi_report()
    endif()
endfunction()

# ------------------------------------------------------------------ install ---

# polyorch_pixi_install([ENVIRONMENT <n>] [ALL] [FROZEN] [LOCKED])
# Solve + install now (configure time). Needs network unless FROZEN. Prefer
# polyorch_pixi_env_target() for anything that should stay incremental.
function(polyorch_pixi_install)
    set(options ALL FROZEN LOCKED)
    set(oneValueArgs ENVIRONMENT)
    cmake_parse_arguments(PARSE_ARGV 0 I "${options}" "${oneValueArgs}" "")
    if(I_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "polyorch_pixi_install: unknown args: ${I_UNPARSED_ARGUMENTS}")
    endif()
    if(I_FROZEN AND I_LOCKED)
        message(FATAL_ERROR "polyorch_pixi_install: FROZEN and LOCKED are mutually exclusive")
    endif()
    if(I_ALL AND I_ENVIRONMENT)
        message(FATAL_ERROR "polyorch_pixi_install: ALL and ENVIRONMENT are mutually exclusive")
    endif()
    _polyorch_pixi_require_context()

    set(_args install)
    if(NOT I_ALL)
        _polyorch_pixi_env_arg(_args "${I_ENVIRONMENT}")
    endif()
    if(I_ALL)
        list(APPEND _args --all)
    elseif(I_FROZEN)
        list(APPEND _args --frozen)
    elseif(I_LOCKED)
        list(APPEND _args --locked)
    endif()

    message(STATUS "pixi ${_args} (this can take minutes on a cold cache)")
    _polyorch_pixi_must(${_args})
endfunction()

# polyorch_pixi_env_target(NAME <t> [ENVIRONMENT <n>] [ALL] [FROZEN] [LOCKED]
#                          [DEPENDS <files...>] [COMMENT <c>])
# Put `pixi install` on the build graph behind a stamp, so a rebuild happens
# only when the manifest or the lock changes. Keep exactly one such target per
# manifest: concurrent installs of one workspace contend on pixi's file locks.
# Steady state wants FROZEN or LOCKED; a plain install may rewrite pixi.lock and
# then look dirty on every build.
function(polyorch_pixi_env_target)
    set(options ALL FROZEN LOCKED)
    set(oneValueArgs NAME ENVIRONMENT COMMENT)
    set(multiValueArgs DEPENDS)
    cmake_parse_arguments(PARSE_ARGV 0 T "${options}" "${oneValueArgs}" "${multiValueArgs}")
    if(T_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "polyorch_pixi_env_target: unknown args: ${T_UNPARSED_ARGUMENTS}")
    endif()
    if(NOT T_NAME)
        message(FATAL_ERROR "polyorch_pixi_env_target: NAME is required")
    endif()
    if(T_FROZEN AND T_LOCKED)
        message(FATAL_ERROR "polyorch_pixi_env_target: FROZEN and LOCKED are mutually exclusive")
    endif()
    _polyorch_pixi_require_context()

    set(_cmd "${PolyOrch_PIXI_EXECUTABLE}" install)
    if(T_ALL)
        list(APPEND _cmd --all)
    else()
        set(_env "${T_ENVIRONMENT}")
        if(NOT _env)
            set(_env "${PolyOrch_PIXI_ENVIRONMENT}")
        endif()
        _polyorch_pixi_env_arg(_cmd "${_env}")
        if(T_FROZEN)
            list(APPEND _cmd --frozen)
        elseif(T_LOCKED)
            list(APPEND _cmd --locked)
        endif()
    endif()
    list(APPEND _cmd -m "${PolyOrch_PIXI_MANIFEST}")

    set(_deps ${T_DEPENDS})
    if(NOT _deps)
        list(APPEND _deps "${PolyOrch_PIXI_MANIFEST}")
        cmake_path(GET PolyOrch_PIXI_MANIFEST PARENT_PATH _mdir)
        if(EXISTS "${_mdir}/pixi.lock")
            list(APPEND _deps "${_mdir}/pixi.lock")
        endif()
    endif()

    if(T_COMMENT)
        set(_comment "${T_COMMENT}")
    else()
        set(_comment "pixi install (${T_NAME})")
    endif()

    set(_stamp "${CMAKE_CURRENT_BINARY_DIR}/polyorch-pixi-env-${T_NAME}.stamp")
    add_custom_command(OUTPUT "${_stamp}"
        COMMAND ${_cmd}
        COMMAND "${CMAKE_COMMAND}" -E touch "${_stamp}"
        DEPENDS ${_deps}
        COMMENT "${_comment}"
        VERBATIM)
    add_custom_target(${T_NAME} DEPENDS "${_stamp}")
endfunction()

# polyorch_pixi_lock_check([QUIET])
# Assert pixi.lock matches pixi.toml without solving for real changes
# (`pixi lock --check`). Non-zero exit is a hard error: this is the CI gate that
# catches a committed manifest with a stale lock.
function(polyorch_pixi_lock_check)
    set(options QUIET)
    cmake_parse_arguments(PARSE_ARGV 0 L "${options}" "" "")
    if(L_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "polyorch_pixi_lock_check: unknown args: ${L_UNPARSED_ARGUMENTS}")
    endif()
    _polyorch_pixi_require_context()
    if(NOT L_QUIET)
        message(STATUS "pixi lock --check: ${PolyOrch_PIXI_MANIFEST}")
    endif()
    _polyorch_pixi_must(lock --check)
endfunction()

# ------------------------------------------------------------------- paths ---

# polyorch_pixi_env_paths([ENVIRONMENT <n>] [PREFIX_OUT <v>] [BIN_OUT <v>]
#                         [TOOLS <name...>] [TOOL_TARGET_PREFIX <p>]
#                         [NO_PREFIX_PATH])
# Resolve an installed environment's prefix, append it to CMAKE_PREFIX_PATH in
# the calling scope, and optionally declare imported executables for tools that
# live inside it. This is the no-activation path: find_package and custom
# commands can then reach the pinned toolchain without anyone sourcing anything.
# The location is asked from pixi / derived by rule; detached-environments setups
# move it, so it must never be hardcoded.
function(polyorch_pixi_env_paths)
    set(options NO_PREFIX_PATH)
    set(oneValueArgs ENVIRONMENT PREFIX_OUT BIN_OUT TOOL_TARGET_PREFIX)
    set(multiValueArgs TOOLS)
    cmake_parse_arguments(PARSE_ARGV 0 P "${options}" "${oneValueArgs}" "${multiValueArgs}")
    if(P_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "polyorch_pixi_env_paths: unknown args: ${P_UNPARSED_ARGUMENTS}")
    endif()
    _polyorch_pixi_require_context()

    set(_env "${P_ENVIRONMENT}")
    if(NOT _env)
        set(_env "${PolyOrch_PIXI_ENVIRONMENT}")
    endif()

    set(_candidates "")
    cmake_path(GET PolyOrch_PIXI_MANIFEST PARENT_PATH _mdir)
    list(APPEND _candidates "${_mdir}/.pixi/envs/${_env}")
    _polyorch_pixi_run(_rc _out _err info --json)
    if(_rc EQUAL 0)
        string(JSON _gdir ERROR_VARIABLE _jerr GET "${_out}" "global_info" "env_dir")
        if(NOT _jerr AND _gdir)
            list(APPEND _candidates "${_gdir}/${_env}")
        endif()
    endif()

    set(_prefix "")
    foreach(_c IN LISTS _candidates)
        if(IS_DIRECTORY "${_c}")
            set(_prefix "${_c}")
            break()
        endif()
    endforeach()
    if(NOT _prefix)
        # --no-install is mandatory here: without it shell-hook installs the
        # environment as a side effect (measured: with the flag .pixi/envs stays
        # absent, without it pixi creates it), and a prefix query must not write.
        # The -e is mandatory too: asking about a misspelled environment must
        # fail, not silently return the default environment's prefix.
        set(_hook shell-hook --json --no-install)
        _polyorch_pixi_env_arg(_hook "${_env}")
        _polyorch_pixi_run(_rc _out _err ${_hook})
        if(_rc EQUAL 0)
            string(JSON _cp ERROR_VARIABLE _jerr GET "${_out}"
                "environment_variables" "CONDA_PREFIX")
            if(NOT _jerr AND _cp AND IS_DIRECTORY "${_cp}")
                set(_prefix "${_cp}")
            endif()
        else()
            string(STRIP "${_err}" _pixierr)
            string(REPLACE "\n" " " _pixierr "${_pixierr}")
        endif()
    endif()
    if(NOT _prefix)
        string(REPLACE ";" "\n  " _shown "${_candidates}")
        set(_why "")
        if(_pixierr)
            set(_why "\npixi said: ${_pixierr}")
        endif()
        message(FATAL_ERROR
            "pixi environment '${_env}' is not installed (or pixi.toml is newer than "
            "pixi.lock, which blocks it). Looked in:\n  ${_shown}${_why}\n"
            "fix: polyorch_pixi_install(ENVIRONMENT ${_env})")
    endif()

    if(NOT P_NO_PREFIX_PATH)
        list(APPEND CMAKE_PREFIX_PATH "${_prefix}")
        list(REMOVE_DUPLICATES CMAKE_PREFIX_PATH)
        set(CMAKE_PREFIX_PATH "${CMAKE_PREFIX_PATH}" PARENT_SCOPE)
    endif()

    # conda layouts put executables in different subdirectories per platform.
    set(_bins "${_prefix}/bin")
    if(WIN32)
        list(APPEND _bins "${_prefix}/Library/bin" "${_prefix}/Scripts" "${_prefix}")
    endif()

    if(P_PREFIX_OUT)
        set(${P_PREFIX_OUT} "${_prefix}" PARENT_SCOPE)
    endif()
    if(P_BIN_OUT)
        list(GET _bins 0 _first_bin)
        set(${P_BIN_OUT} "${_first_bin}" PARENT_SCOPE)
    endif()

    foreach(_tool IN LISTS P_TOOLS)
        # Local result: a cached NOTFOUND would never re-search after the
        # environment gets installed.
        find_program(_tool_path NAMES ${_tool} PATHS ${_bins} NO_DEFAULT_PATH)
        if(NOT _tool_path)
            message(AUTHOR_WARNING
                "pixi environment '${_env}' has no '${_tool}' (prefix ${_prefix})")
            continue()
        endif()
        if(P_TOOL_TARGET_PREFIX)
            add_executable("${P_TOOL_TARGET_PREFIX}${_tool}" IMPORTED GLOBAL)
            set_property(TARGET "${P_TOOL_TARGET_PREFIX}${_tool}"
                PROPERTY IMPORTED_LOCATION "${_tool_path}")
        endif()
    endforeach()
endfunction()

# polyorch_pixi_activate_script(OUTPUT <file> [SHELL <s>] [ENVIRONMENT <n>])
# Write pixi's own activation script (`pixi shell-hook -s <s>`) to a file for a
# human to source. CMake cannot activate the shell that launched it. Default
# shell: bash on POSIX, powershell on Windows; accepted values are bash, zsh,
# xonsh, cmd, powershell, fish, nushell. The script overwrites PATH without
# restoring it, so start a subshell first and exit it to undo.
function(polyorch_pixi_activate_script)
    set(options)
    set(oneValueArgs OUTPUT SHELL ENVIRONMENT)
    cmake_parse_arguments(PARSE_ARGV 0 A "${options}" "${oneValueArgs}" "")
    if(A_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "polyorch_pixi_activate_script: unknown args: ${A_UNPARSED_ARGUMENTS}")
    endif()
    if(NOT A_OUTPUT)
        message(FATAL_ERROR "polyorch_pixi_activate_script: OUTPUT is required")
    endif()
    _polyorch_pixi_require_context()

    set(_shell "${A_SHELL}")
    if(NOT _shell)
        if(WIN32)
            set(_shell powershell)
        else()
            set(_shell bash)
        endif()
    endif()

    set(_args shell-hook -s "${_shell}")
    _polyorch_pixi_env_arg(_args "${A_ENVIRONMENT}")
    _polyorch_pixi_must(OUT _hook ${_args})

    if(_shell STREQUAL "cmd")
        set(_head "@echo off\r\n")
    elseif(_shell STREQUAL "powershell")
        set(_head "# PolyOrch: run this file, or start powershell and dot-source it.\r\n")
    else()
        string(CONCAT _head
            "#!/usr/bin/env bash\n"
            "# PolyOrch: source this from a subshell; exiting restores your env.\n")
    endif()
    file(WRITE "${A_OUTPUT}" "${_head}${_hook}")
    if(NOT _shell STREQUAL "cmd" AND NOT _shell STREQUAL "powershell")
        file(CHMOD "${A_OUTPUT}" PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE
            GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
    endif()
    message(STATUS "pixi activation script (${_shell}): ${A_OUTPUT}")
endfunction()

# polyorch_pixi_scripts_install([WORKDIR <dir>])
# Install the PolyOrch activation scripts (pixi.sh / pixi.bat / pixi.ps1) next
# to a workspace -- exactly where .pixi/ lives and where pixi.toml sits, because
# the scripts resolve their manifest from their own directory. After this, a
# human in any terminal activates without CMake:
#   bash/zsh:   source ./pixi.sh       cmd:  pixi.bat (child shell)   pwsh:  . ./pixi.ps1
# vs polyorch_pixi_activate_script(): that renders pixi's OWN shell-hook output
# for one chosen shell at one path; these are the universal trio shipped by the
# repo. Managed files: existing copies are overwritten -- single source of truth
# is PolyOrch/scripts/. Default WORKDIR: the resolved manifest's directory.
function(polyorch_pixi_scripts_install)
    set(options)
    set(oneValueArgs WORKDIR)
    cmake_parse_arguments(PARSE_ARGV 0 I "${options}" "${oneValueArgs}" "")
    if(I_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "polyorch_pixi_scripts_install: unknown args: ${I_UNPARSED_ARGUMENTS}")
    endif()

    set(_dir "${I_WORKDIR}")
    if(NOT _dir)
        # Depends on the MANIFEST only -- copying scripts never runs pixi, so a
        # located binary must not be a precondition here.
        if(NOT PolyOrch_PIXI_MANIFEST)
            message(FATAL_ERROR
                "polyorch_pixi_scripts_install: pass WORKDIR or resolve the "
                "manifest first (polyorch_pixi_setup / -DPolyOrch_PIXI_MANIFEST)")
        endif()
        cmake_path(GET PolyOrch_PIXI_MANIFEST PARENT_PATH _dir)
    endif()

    # CMAKE_CURRENT_FUNCTION_LIST_DIR (3.17+) = dir where THIS function is defined,
    # regardless of the caller's dynamic scope. CMAKE_CURRENT_LIST_DIR here would
    # wrongly resolve to the *calling* file's directory (measured).
    set(_src "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../scripts")
    set(_files "")
    foreach(_f pixi.sh pixi.bat pixi.ps1)
        if(NOT EXISTS "${_src}/${_f}")
            message(FATAL_ERROR "polyorch_pixi_scripts_install: missing ${_src}/${_f}")
        endif()
        list(APPEND _files "${_src}/${_f}")
    endforeach()

    file(MAKE_DIRECTORY "${_dir}")
    file(COPY ${_files} DESTINATION "${_dir}"
        FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE
        GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
    message(STATUS "pixi scripts: pixi.sh / pixi.bat / pixi.ps1 installed into ${_dir}")
endfunction()


# ------------------------------------------------------------------- report ---

# polyorch_pixi_report([ENVIRONMENT <n>])
# One STATUS block describing what this CMake run will actually use: binary,
# version, manifest, environment, channels and installed prefixes. Read-only.
function(polyorch_pixi_report)
    set(options)
    set(oneValueArgs ENVIRONMENT)
    cmake_parse_arguments(PARSE_ARGV 0 Q "${options}" "${oneValueArgs}" "")
    if(Q_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "polyorch_pixi_report: unknown args: ${Q_UNPARSED_ARGUMENTS}")
    endif()
    _polyorch_pixi_require_context()

    set(_env "${Q_ENVIRONMENT}")
    if(NOT _env)
        set(_env "${PolyOrch_PIXI_ENVIRONMENT}")
    endif()

    message(STATUS "pixi: exe=${PolyOrch_PIXI_EXECUTABLE} version=${PolyOrch_PIXI_VERSION}")
    message(STATUS "pixi: manifest=${PolyOrch_PIXI_MANIFEST} environment=${_env}")
    if(PolyOrch_PIXI_CONFIG_FILE)
        set(_cfg "${PolyOrch_PIXI_CONFIG_FILE}")
    elseif(PolyOrch_PIXI_NO_CONFIG)
        set(_cfg "no-config")
    else()
        set(_cfg "default search")
    endif()
    message(STATUS "pixi: config=${_cfg}")

    _polyorch_pixi_run(_rc _out _err workspace channel list --urls)
    if(_rc EQUAL 0)
        string(STRIP "${_out}" _out)
        string(REPLACE "\n" " " _out "${_out}")
        message(STATUS "pixi: channels=${_out}")
    endif()

    _polyorch_pixi_run(_rc _out _err workspace environment list)
    if(_rc EQUAL 0)
        string(STRIP "${_out}" _out)
        string(REPLACE "\n" " " _out "${_out}")
        message(STATUS "pixi: environments=${_out}")
    endif()

    cmake_path(GET PolyOrch_PIXI_MANIFEST PARENT_PATH _mdir)
    if(IS_DIRECTORY "${_mdir}/.pixi/envs/${_env}")
        set(_state "installed")
    else()
        set(_state "NOT installed")
    endif()
    message(STATUS "pixi: environment ${_env} is ${_state}")

endfunction()

# ============================================================== workspace actions
# The mutating half of this module: everything below writes pixi.toml,
# pixi.lock, .pixi/config.toml, reaches the network, or installs the pixi binary.
# None of it belongs in an ordinary CI configure step.

# ------------------------------------------------- explicit manifest actions ---
# Everything below writes pixi.toml / pixi.lock / config files, or downloads.
# Call them from a dedicated action, never from an ordinary configure.

# polyorch_pixi_config_set(KEY <k> VALUE <v> [SCOPE local|global|system] [UNSET])
# Thin wrapper over `pixi config set|unset`. Scope decides which file is written:
# local -> <project>/.pixi/config.toml, global -> the user config, system -> the
# system config. `init` and `config` reject --config-file, hence the BARE call
# plus an explicit -m for the local scope.
function(polyorch_pixi_config_set)
    set(options UNSET)
    set(oneValueArgs KEY VALUE SCOPE)
    cmake_parse_arguments(PARSE_ARGV 0 C "${options}" "${oneValueArgs}" "")
    if(C_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "polyorch_pixi_config_set: unknown args: ${C_UNPARSED_ARGUMENTS}")
    endif()
    if(NOT C_KEY)
        message(FATAL_ERROR "polyorch_pixi_config_set: KEY is required")
    endif()
    if(NOT C_SCOPE)
        set(C_SCOPE local)
    endif()
    if(C_SCOPE STREQUAL "local")
        set(_scope --local)
    elseif(C_SCOPE STREQUAL "global")
        set(_scope --global)
    elseif(C_SCOPE STREQUAL "system")
        set(_scope --system)
    else()
        message(FATAL_ERROR "polyorch_pixi_config_set: SCOPE must be local, global or system")
    endif()
    if(NOT C_UNSET AND C_VALUE STREQUAL "")
        # STREQUAL, not if(NOT C_VALUE): false / off / 0 / no are legitimate pixi
        # config values and CMake reads those words as false.
        message(FATAL_ERROR "polyorch_pixi_config_set: VALUE is required unless UNSET")
    endif()
    _polyorch_pixi_require_context()

    set(_args config)
    if(C_UNSET)
        list(APPEND _args unset ${_scope} "${C_KEY}")
    else()
        list(APPEND _args set ${_scope} "${C_KEY}" "${C_VALUE}")
    endif()
    if(C_SCOPE STREQUAL "local")
        list(APPEND _args -m "${PolyOrch_PIXI_MANIFEST}")
    endif()
    _polyorch_pixi_must(BARE ${_args})
    message(STATUS "pixi config: ${C_KEY} -> ${C_VALUE} (${C_SCOPE})")
endfunction()

# polyorch_pixi_mirror(SET <url...> [SCOPE local|global])
# polyorch_pixi_mirror(WRITE_CONFIG <file> CHANNELS <url...> [EXTRA <lines...>])
# polyorch_pixi_mirror(LIST_OUT <var>)
# Domestic mirror handling has three honest landing spots, all exposed here:
#   SET          - `pixi config set default-channels '[...]'`. Only applies to a
#                  workspace that declares no `channels` of its own, so it is a
#                  machine-wide knob, not a per-repo one.
#   WRITE_CONFIG - generate a standalone pixi config file and pass it as
#                  --config-file (or -DPolyOrch_PIXI_CONFIG_FILE). Zero repo
#                  churn, and CI can override it; this is the per-build knob.
#   LIST_OUT     - what pixi actually resolves for this manifest.
# It deliberately never edits `channels` inside pixi.toml: that is committed
# workspace data and belongs to polyorch_pixi_channel(ADD/REMOVE).
function(polyorch_pixi_mirror)
    set(oneValueArgs WRITE_CONFIG LIST_OUT SCOPE)
    set(multiValueArgs SET CHANNELS EXTRA)
    cmake_parse_arguments(PARSE_ARGV 0 M "" "${oneValueArgs}" "${multiValueArgs}")
    if(M_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "polyorch_pixi_mirror: unknown args: ${M_UNPARSED_ARGUMENTS}")
    endif()

    set(_channels ${M_SET})
    if(NOT _channels)
        set(_channels ${M_CHANNELS})
    endif()

    if(M_LIST_OUT)
        _polyorch_pixi_require_context()
        _polyorch_pixi_must(OUT _out workspace channel list --urls)
        string(STRIP "${_out}" _out)
        string(REPLACE "\n" ";" _list "${_out}")
        set(${M_LIST_OUT} "${_list}" PARENT_SCOPE)
        return()
    endif()

    if(NOT _channels)
        message(FATAL_ERROR "polyorch_pixi_mirror: SET/CHANNELS, WRITE_CONFIG or LIST_OUT is required")
    endif()

    if(M_WRITE_CONFIG)
        _polyorch_pixi_json_array(_toml ${_channels})
        # Same array syntax for TOML and JSON, so one builder serves both.
        set(_text "default-channels = ${_toml}\n")
        foreach(_line IN LISTS M_EXTRA)
            string(APPEND _text "${_line}\n")
        endforeach()
        get_filename_component(_dir "${M_WRITE_CONFIG}" DIRECTORY)
        file(MAKE_DIRECTORY "${_dir}")
        file(WRITE "${M_WRITE_CONFIG}" "${_text}")
        message(STATUS "pixi mirror: wrote ${M_WRITE_CONFIG}")
        message(STATUS "pixi mirror: use -DPolyOrch_PIXI_CONFIG_FILE=${M_WRITE_CONFIG}")
        return()
    endif()

    _polyorch_pixi_json_array(_json ${_channels})
    if(M_SCOPE)
        set(_scope "${M_SCOPE}")
    else()
        set(_scope global)
    endif()
    polyorch_pixi_config_set(KEY default-channels VALUE "${_json}" SCOPE "${_scope}")
endfunction()

# polyorch_pixi_channel([ADD <url...> | REMOVE <url...> | LIST_OUT <var>]
#                       [PREPEND] [FEATURE <f>] [ENVIRONMENT <n>] [NO_INSTALL])
# Edit the manifest's own channel list (writes pixi.toml and re-solves the lock,
# unless NO_INSTALL limits it to the lock file). This is the per-workspace
# mirror switch; `add`/`remove` are documented as lock-updating.
function(polyorch_pixi_channel)
    set(options ADD REMOVE PREPEND NO_INSTALL)
    set(oneValueArgs LIST_OUT FEATURE ENVIRONMENT)
    cmake_parse_arguments(PARSE_ARGV 0 K "${options}" "${oneValueArgs}" "")
    if(K_LIST_OUT)
        _polyorch_pixi_require_context()
        _polyorch_pixi_must(OUT _out workspace channel list --urls)
        string(STRIP "${_out}" _out)
        string(REPLACE "\n" ";" _list "${_out}")
        set(${K_LIST_OUT} "${_list}" PARENT_SCOPE)
        return()
    endif()
    if(K_ADD AND K_REMOVE)
        message(FATAL_ERROR "polyorch_pixi_channel: ADD and REMOVE are mutually exclusive")
    endif()
    if(NOT K_ADD AND NOT K_REMOVE)
        message(FATAL_ERROR
            "polyorch_pixi_channel: pick one form --"
            " polyorch_pixi_channel(ADD <url...>) / (REMOVE <url...>) /"
            " (LIST_OUT <var>)")
    endif()
    if(NOT K_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "polyorch_pixi_channel: no channel URLs given")
    endif()
    _polyorch_pixi_require_context()

    if(K_ADD)
        set(_args workspace channel add)
    else()
        set(_args workspace channel remove)
    endif()
    if(K_PREPEND)
        list(APPEND _args --prepend)
    endif()
    if(K_FEATURE)
        list(APPEND _args -f "${K_FEATURE}")
    endif()
    _polyorch_pixi_env_arg(_args "${K_ENVIRONMENT}")
    if(K_NO_INSTALL)
        list(APPEND _args --no-install)
    endif()
    list(APPEND _args ${K_UNPARSED_ARGUMENTS})
    _polyorch_pixi_must(${_args})
endfunction()

# polyorch_pixi_init(WORKDIR <dir> [NAME <n>] [VERSION <x.y.z>] [CHANNELS <url...>]
#                    [PLATFORMS <p...>] [FORMAT pixi|pyproject]
#                    [IMPORT <environment.yml>] [TEMPLATE <file>]
#                    [ENVIRONMENTS_DIR <dir>] [COPY_SCRIPTS] [IF_NOT_EXISTS] [FORCE])
# Create a workspace in WORKDIR entirely from CMake args -- no external pixi.toml
# is required. Either let pixi generate the stock manifest, or expand a CMake
# template (TEMPLATE, @ONLY) when the workspace needs features, tasks or pinned
# versions that `pixi init` cannot express. NAME/VERSION go through
# `workspace <name|version> set`; with TEMPLATE the name belongs in the template.
# ENVIRONMENTS_DIR points pixi's per-env storage at a fixed (or shared) absolute
# path instead of <workspace>/.pixi/envs: it sets detached-environments +
# cache.detached-environments locally, so the multi-GB envs land there while
# .pixi/ keeps only config.toml in the workspace (measured on pixi 0.78.0).
# When the manifest already exists: default hard-fails, FORCE deletes and
# recreates it, IF_NOT_EXISTS keeps it and refreshes only the properties below
# -- the shape a reconfigure-safe call wants.
function(polyorch_pixi_init)
    set(options FORCE IF_NOT_EXISTS COPY_SCRIPTS)
    set(oneValueArgs WORKDIR NAME VERSION FORMAT IMPORT TEMPLATE ENVIRONMENTS_DIR)
    set(multiValueArgs CHANNELS PLATFORMS)
    cmake_parse_arguments(PARSE_ARGV 0 N "${options}" "${oneValueArgs}" "${multiValueArgs}")
    if(N_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "polyorch_pixi_init: unknown args: ${N_UNPARSED_ARGUMENTS}")
    endif()
    if(NOT N_WORKDIR)
        message(FATAL_ERROR "polyorch_pixi_init: WORKDIR is required")
    endif()
    if(N_TEMPLATE AND N_NAME)
        message(FATAL_ERROR "polyorch_pixi_init: NAME with TEMPLATE sets the name twice")
    endif()
    polyorch_pixi_find(REQUIRED)

    cmake_path(ABSOLUTE_PATH N_WORKDIR NORMALIZE)
    set(_manifest "${N_WORKDIR}/pixi.toml")
    if(N_FORMAT)
        set(_format "${N_FORMAT}")
    else()
        set(_format pixi)
    endif()
    if(_format STREQUAL "pyproject")
        set(_manifest "${N_WORKDIR}/pyproject.toml")
    endif()
    if(N_FORCE AND N_IF_NOT_EXISTS)
        message(FATAL_ERROR
            "polyorch_pixi_init: FORCE and IF_NOT_EXISTS are mutually exclusive")
    endif()
    set(_keep OFF)
    if(EXISTS "${_manifest}")
        if(NOT N_FORCE)
            if(NOT N_IF_NOT_EXISTS)
                message(FATAL_ERROR
                    "${_manifest} already exists; pass FORCE to replace it, or "
                    "IF_NOT_EXISTS to keep it and refresh only the properties")
            endif()
            set(_keep ON)
            message(STATUS "pixi init: keeping ${_manifest}, refreshing properties")
        else()
            file(REMOVE "${_manifest}")
        endif()
    endif()
    file(MAKE_DIRECTORY "${N_WORKDIR}")

    if(_keep)
        # IF_NOT_EXISTS hit: the creation (and CHANNELS/PLATFORMS, which only
        # init takes) is skipped; NAME/VERSION/ENVIRONMENTS_DIR below still run.
    elseif(N_TEMPLATE)
        configure_file("${N_TEMPLATE}" "${_manifest}" @ONLY)
        message(STATUS "pixi init: template ${N_TEMPLATE} -> ${_manifest}")
    else()
        set(_args init --format "${_format}")
        foreach(_c IN LISTS N_CHANNELS)
            list(APPEND _args -c "${_c}")
        endforeach()
        foreach(_p IN LISTS N_PLATFORMS)
            list(APPEND _args -p "${_p}")
        endforeach()
        if(N_IMPORT)
            list(APPEND _args --import "${N_IMPORT}")
        endif()
        list(APPEND _args "${N_WORKDIR}")
        _polyorch_pixi_must(BARE ${_args})
    endif()

    if(N_NAME)
        _polyorch_pixi_must(BARE workspace name set "${N_NAME}" -m "${_manifest}")
    endif()
    if(N_VERSION)
        _polyorch_pixi_must(BARE workspace version set "${N_VERSION}" -m "${_manifest}")
    endif()
    if(N_ENVIRONMENTS_DIR)
        cmake_path(ABSOLUTE_PATH N_ENVIRONMENTS_DIR NORMALIZE)
        file(MAKE_DIRECTORY "${N_ENVIRONMENTS_DIR}")
        # Argument shape mirrors polyorch_pixi_config_set's local-scope route
        # (config rejects --config-file, hence BARE + explicit -m). Values are
        # passed bare: pixi wants `true` for the toggle and an unquoted absolute
        # path for the location -- quoting the path is rejected.
        _polyorch_pixi_must(BARE config set --local detached-environments true
            -m "${N_WORKDIR}")
        _polyorch_pixi_must(BARE config set --local cache.detached-environments
            "${N_ENVIRONMENTS_DIR}" -m "${N_WORKDIR}")
        message(STATUS "pixi init: envs redirect -> ${N_ENVIRONMENTS_DIR}")
    endif()
    if(N_COPY_SCRIPTS)
        polyorch_pixi_scripts_install(WORKDIR "${N_WORKDIR}")
    endif()
    message(STATUS "pixi init: workspace manifest ${_manifest}")
endfunction()

# polyorch_pixi_dependency(DEPENDS <spec...> [REMOVE] [FEATURE <f>]
#                          [ENVIRONMENT <n>] [PLATFORM <p...>] [PYPI]
#                          [NO_INSTALL] [BUILD|HOST] [EDITABLE] [PINNING <s>])
# Add or remove dependencies in the manifest (`pixi add` / `pixi remove`).
# Both re-solve and write pixi.lock unless NO_INSTALL keeps it to the lock file;
# neither has a dry run, so preview means a VCS diff or `pixi lock --check`.
function(polyorch_pixi_dependency)
    set(options REMOVE PYPI NO_INSTALL BUILD HOST EDITABLE)
    set(oneValueArgs FEATURE ENVIRONMENT PINNING)
    set(multiValueArgs DEPENDS PLATFORM)
    cmake_parse_arguments(PARSE_ARGV 0 D "${options}" "${oneValueArgs}" "${multiValueArgs}")
    if(D_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "polyorch_pixi_dependency: unknown args: ${D_UNPARSED_ARGUMENTS}")
    endif()
    if(NOT D_DEPENDS)
        message(FATAL_ERROR "polyorch_pixi_dependency: DEPENDS is required")
    endif()
    if(D_BUILD AND D_HOST)
        message(FATAL_ERROR "polyorch_pixi_dependency: BUILD and HOST are mutually exclusive")
    endif()
    if(D_REMOVE AND (D_BUILD OR D_HOST OR D_EDITABLE OR D_PINNING))
        message(FATAL_ERROR
            "polyorch_pixi_dependency: REMOVE does not accept BUILD/HOST/EDITABLE/PINNING")
    endif()
    _polyorch_pixi_require_context()

    if(D_REMOVE)
        set(_args remove)
    else()
        set(_args add)
    endif()
    if(D_PYPI)
        list(APPEND _args --pypi)
    endif()
    foreach(_p IN LISTS D_PLATFORM)
        list(APPEND _args -p "${_p}")
    endforeach()
    if(D_FEATURE)
        list(APPEND _args -f "${D_FEATURE}")
    endif()
    _polyorch_pixi_env_arg(_args "${D_ENVIRONMENT}")
    if(D_NO_INSTALL)
        list(APPEND _args --no-install)
    endif()
    if(NOT D_REMOVE)
        if(D_BUILD)
            list(APPEND _args --build)
        elseif(D_HOST)
            list(APPEND _args --host)
        endif()
        if(D_EDITABLE)
            list(APPEND _args --editable)
        endif()
        if(D_PINNING)
            list(APPEND _args --pinning-strategy "${D_PINNING}")
        endif()
    endif()
    list(APPEND _args ${D_DEPENDS})
    _polyorch_pixi_must(${_args})
endfunction()

# polyorch_pixi_environment_add(NAME <n> [FEATURES <f...>] [SOLVE_GROUP <g>]
#                               [NO_DEFAULT_FEATURE] [FORCE])
# Declare an environment (a named feature set) in the manifest. Manifest-only
# write; no solve, no network.
function(polyorch_pixi_environment_add)
    set(options NO_DEFAULT_FEATURE FORCE)
    set(oneValueArgs NAME SOLVE_GROUP)
    set(multiValueArgs FEATURES)
    cmake_parse_arguments(PARSE_ARGV 0 E "${options}" "${oneValueArgs}" "${multiValueArgs}")
    if(E_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "polyorch_pixi_environment_add: unknown args: ${E_UNPARSED_ARGUMENTS}")
    endif()
    if(NOT E_NAME)
        message(FATAL_ERROR "polyorch_pixi_environment_add: NAME is required")
    endif()
    _polyorch_pixi_require_context()

    set(_args workspace environment add "${E_NAME}")
    foreach(_f IN LISTS E_FEATURES)
        list(APPEND _args -f "${_f}")
    endforeach()
    if(E_SOLVE_GROUP)
        list(APPEND _args --solve-group "${E_SOLVE_GROUP}")
    endif()
    if(E_NO_DEFAULT_FEATURE)
        list(APPEND _args --no-default-feature)
    endif()
    if(E_FORCE)
        list(APPEND _args --force)
    endif()
    _polyorch_pixi_must(${_args})
endfunction()

# polyorch_pixi_task_add(NAME <n> COMMAND <cmd...> [FEATURE <f>] [ENVIRONMENT <n>]
#                        [PLATFORM <p>] [CWD <d>] [DESCRIPTION <d>]
#                        [DEPENDS_ON <task...>] [ENV_VARS <k=v...>] [CLEAN_ENV])
# Define a workspace task in the manifest. pixi has no task "remove-or-replace"
# verb here, so re-running with a different command is a hard error by design;
# remove it with `pixi task remove` before calling again.
function(polyorch_pixi_task_add)
    set(options CLEAN_ENV)
    set(oneValueArgs NAME FEATURE ENVIRONMENT PLATFORM CWD DESCRIPTION)
    set(multiValueArgs COMMAND DEPENDS_ON ENV_VARS)
    cmake_parse_arguments(PARSE_ARGV 0 K "${options}" "${oneValueArgs}" "${multiValueArgs}")
    if(K_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "polyorch_pixi_task_add: unknown args: ${K_UNPARSED_ARGUMENTS}")
    endif()
    if(NOT K_NAME OR NOT K_COMMAND)
        message(FATAL_ERROR "polyorch_pixi_task_add: NAME and COMMAND are required")
    endif()
    _polyorch_pixi_require_context()

    set(_args task add)
    if(K_DEPENDS_ON)
        foreach(_t IN LISTS K_DEPENDS_ON)
            list(APPEND _args --depends-on "${_t}")
        endforeach()
    endif()
    if(K_PLATFORM)
        list(APPEND _args -p "${K_PLATFORM}")
    endif()
    if(K_FEATURE)
        list(APPEND _args -f "${K_FEATURE}")
    endif()
    _polyorch_pixi_env_arg(_args "${K_ENVIRONMENT}")
    if(K_CWD)
        list(APPEND _args --cwd "${K_CWD}")
    endif()
    foreach(_v IN LISTS K_ENV_VARS)
        list(APPEND _args --env "${_v}")
    endforeach()
    if(K_DESCRIPTION)
        list(APPEND _args --description "${K_DESCRIPTION}")
    endif()
    if(K_CLEAN_ENV)
        list(APPEND _args --clean-env)
    endif()
    list(APPEND _args "${K_NAME}")
    list(APPEND _args ${K_COMMAND})
    _polyorch_pixi_must(${_args})
endfunction()

# polyorch_pixi_publish(TARGET_DIR <dir> | CHANNEL <url> [PATH <p>]
#                       [TARGET_PLATFORM <pl>] [BUILD_PLATFORM <pl>])
# Build conda packages of the workspace. `pixi publish` only builds packages that
# opt in with `publish = true` in their `[package]` section. TARGET_DIR copies
# artifacts into a directory; CHANNEL builds a channel (file:// works offline).
function(polyorch_pixi_publish)
    set(options)
    set(oneValueArgs TARGET_DIR CHANNEL PATH TARGET_PLATFORM BUILD_PLATFORM)
    cmake_parse_arguments(PARSE_ARGV 0 B "${options}" "${oneValueArgs}" "")
    if(B_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "polyorch_pixi_publish: unknown args: ${B_UNPARSED_ARGUMENTS}")
    endif()
    if(B_TARGET_DIR AND B_CHANNEL)
        message(FATAL_ERROR "polyorch_pixi_publish: TARGET_DIR and CHANNEL are mutually exclusive")
    endif()
    if(NOT B_TARGET_DIR AND NOT B_CHANNEL)
        message(FATAL_ERROR "polyorch_pixi_publish: TARGET_DIR or CHANNEL is required")
    endif()
    _polyorch_pixi_require_context()

    set(_args publish)
    if(B_TARGET_DIR)
        list(APPEND _args --target-dir "${B_TARGET_DIR}")
    else()
        list(APPEND _args --target-channel "${B_CHANNEL}")
    endif()
    if(B_PATH)
        list(APPEND _args --path "${B_PATH}")
    endif()
    if(B_TARGET_PLATFORM)
        list(APPEND _args -t "${B_TARGET_PLATFORM}")
    endif()
    if(B_BUILD_PLATFORM)
        list(APPEND _args --build-platform "${B_BUILD_PLATFORM}")
    endif()
    _polyorch_pixi_must(${_args})
endfunction()

# polyorch_pixi_tool_install([VERSION <x.y.z>] [HOME <dir>] [URL <installer-url>]
#                            [HASH <ALGO=digest>] [CONDA] [FORCE] [MANAGER <p>])
# Install or replace the pixi binary itself. EXPLICIT ACTION ONLY: it writes
# $HOME, which no lock file covers, and it cannot be a configure step when cmake
# itself comes from pixi. Run it as `cmake -P` or by hand.
#   default route: download the installer script (POSIX: https://pixi.sh/install.sh)
#                  and run it with PIXI_VERSION / PIXI_HOME set.
#   CONDA route:   <micromamba|mamba|conda> install -c conda-forge pixi[=VERSION],
#                  the only route that also works where PowerShell is absent.
#   existing pixi: `pixi self-update --version V` (add FORCE to replace an equal
#                  version); URL maps to --from-url for a mirror.
# pip is never used: the PyPI package named "pixi" is an unrelated project.
function(polyorch_pixi_tool_install)
    set(options CONDA FORCE)
    set(oneValueArgs VERSION HOME URL HASH MANAGER)
    cmake_parse_arguments(PARSE_ARGV 0 Z "${options}" "${oneValueArgs}" "")
    if(Z_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "polyorch_pixi_tool_install: unknown args: ${Z_UNPARSED_ARGUMENTS}")
    endif()

    if(PolyOrch_PIXI_EXECUTABLE AND Z_FORCE)
        set(_args self-update)
        if(Z_VERSION)
            list(APPEND _args --version "${Z_VERSION}")
        endif()
        if(Z_URL)
            list(APPEND _args --from-url "${Z_URL}")
        endif()
        list(APPEND _args --force)
        _polyorch_pixi_must(BARE ${_args})
    elseif(Z_CONDA)
        if(Z_MANAGER)
            set(_mgr "${Z_MANAGER}")
        else()
            find_program(_mgr NAMES micromamba mamba conda)
        endif()
        if(NOT _mgr)
            message(FATAL_ERROR
                "polyorch_pixi_tool_install(CONDA): no micromamba/mamba/conda found;"
                " pass MANAGER <path>")
        endif()
        set(_pkg pixi)
        if(Z_VERSION)
            set(_pkg "pixi=${Z_VERSION}")
        endif()
        _polyorch_pixi_must(BARE "${_mgr}" install -y -c conda-forge "${_pkg}")
    else()
        set(_url "${Z_URL}")
        if(NOT _url)
            if(UNIX)
                set(_url "https://pixi.sh/install.sh")
            else()
                set(_url "https://pixi.sh/install.ps1")
            endif()
        endif()
        if(NOT Z_HASH)
            message(AUTHOR_WARNING
                "polyorch_pixi_tool_install: downloading ${_url} without HASH."
                " Pass HASH SHA256=<digest> for anything reproducible.")
        endif()
        _polyorch_pixi_scratch(_tmp)
        set(_tmp "${_tmp}/pixi-installer")
        file(MAKE_DIRECTORY "${_tmp}")
        # Fixed local name: the URL is a path with a scheme, and its basename is
        # not worth parsing (install.sh on POSIX, install.ps1 on Windows).
        if(UNIX)
            set(_dl "${_tmp}/install.sh")
        else()
            set(_dl "${_tmp}/install.ps1")
        endif()
        set(_hash_opt "")
        if(Z_HASH)
            set(_hash_opt EXPECTED_HASH ${Z_HASH})
        endif()
        file(DOWNLOAD "${_url}" "${_dl}" ${_hash_opt} STATUS _st SHOW_PROGRESS)
        list(GET _st 0 _rc)
        if(NOT _rc EQUAL 0)
            list(GET _st 1 _msg)
            message(FATAL_ERROR "could not download ${_url}: ${_msg}")
        endif()
        set(_saved_HOME "$ENV{PIXI_HOME}")
        set(_saved_VERSION "$ENV{PIXI_VERSION}")
        if(Z_HOME)
            set(ENV{PIXI_HOME} "${Z_HOME}")
        endif()
        if(Z_VERSION)
            set(ENV{PIXI_VERSION} "${Z_VERSION}")
        endif()
        if(UNIX)
            execute_process(COMMAND sh "${_dl}" RESULT_VARIABLE _rc
                OUTPUT_VARIABLE _o ERROR_VARIABLE _e)
        else()
            execute_process(COMMAND powershell -ExecutionPolicy Bypass -File "${_dl}"
                RESULT_VARIABLE _rc OUTPUT_VARIABLE _o ERROR_VARIABLE _e)
        endif()
        if(Z_HOME)
            set(ENV{PIXI_HOME} "${_saved_HOME}")
        else()
            unset(ENV{PIXI_HOME})
        endif()
        if(Z_VERSION)
            set(ENV{PIXI_VERSION} "${_saved_VERSION}")
        else()
            unset(ENV{PIXI_VERSION})
        endif()
        if(NOT _rc EQUAL 0)
            message(FATAL_ERROR "pixi installer failed (exit ${_rc}):\n${_o}${_e}")
        endif()
    endif()

    # Re-locate under a scratch name (an existing empty cache entry makes
    # find_program a no-op) and publish it, honouring an explicit HOME.
    set(_hints "$ENV{HOME}/.pixi/bin")
    if(Z_HOME)
        set(_hints "${Z_HOME}/bin")
    endif()
    find_program(_polyorch_pixi_new NAMES pixi PATHS ${_hints})
    if(NOT _polyorch_pixi_new)
        message(FATAL_ERROR
            "pixi ran the installer but no binary is reachable from ${_hints};"
            " pass HOME <dir> to match the installer's PIXI_HOME")
    endif()
    set(PolyOrch_PIXI_EXECUTABLE "${_polyorch_pixi_new}" CACHE FILEPATH
        "pixi binary; empty = search PATH and the default install locations" FORCE)
    polyorch_pixi_find()
endfunction()

# --------------------------------------------------------------- tool ensure ---

# polyorch_pixi_tool_ensure([VERSION <x.y.z>] [URL <installer-url>]
#                           [HASH <ALGO=digest>] [NO_PRECHECK] [QUIET])
# The pixi BINARY only: locate it; when absent or older than VERSION, precheck
# conda-forge (unless NO_PRECHECK) and install via polyorch_pixi_tool_install()
# (POSIX installer on sh, install.ps1 on Windows); finally assert the pin.
# Touches $HOME and may reach the network, but never reads a manifest, a lock
# file or an environment -- the tool-only half of the split, for provisioning
# machines that receive environments by other means (archives, shared stores).
function(polyorch_pixi_tool_ensure)
    set(options NO_PRECHECK QUIET)
    set(oneValueArgs VERSION URL HASH)
    cmake_parse_arguments(PARSE_ARGV 0 E "${options}" "${oneValueArgs}" "")
    if(E_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "polyorch_pixi_tool_ensure: unknown args: ${E_UNPARSED_ARGUMENTS}")
    endif()

    polyorch_pixi_find(QUIET)
    set(_old "")
    if(PolyOrch_PIXI_EXECUTABLE AND E_VERSION
       AND PolyOrch_PIXI_VERSION VERSION_LESS E_VERSION)
        set(_old "${PolyOrch_PIXI_VERSION}")
    endif()
    if(NOT PolyOrch_PIXI_EXECUTABLE OR _old)
        if(_old AND NOT E_QUIET)
            message(STATUS "pixi ${_old} is older than ${E_VERSION} -- reinstalling")
        endif()
        if(NOT E_NO_PRECHECK)
            _polyorch_pixi_scratch(_pcdir)
            file(DOWNLOAD
                "https://conda.anaconda.org/conda-forge/noarch/repodata.json"
                "${_pcdir}/probe" RANGE 0 0 INACTIVITY_TIMEOUT 10 STATUS _pst)
            list(GET _pst 0 _prc)
            if(NOT _prc EQUAL 0)
                list(GET _pst 1 _pmsg)
                message(FATAL_ERROR
                    "pixi precheck: conda-forge unreachable (${_pmsg}).\n"
                    "fix: point pixi at a mirror (polyorch_pixi_mirror), or pass NO_PRECHECK.")
            endif()
        endif()
        set(_ti "")
        if(E_VERSION)
            list(APPEND _ti VERSION "${E_VERSION}")
        endif()
        if(E_URL)
            list(APPEND _ti URL "${E_URL}")
        endif()
        if(E_HASH)
            list(APPEND _ti HASH "${E_HASH}")
        endif()
        # tool_install ends by re-locating the binary and refreshing the version.
        polyorch_pixi_tool_install(${_ti})
    endif()
    if(E_VERSION AND PolyOrch_PIXI_VERSION VERSION_LESS E_VERSION)
        message(FATAL_ERROR
            "pixi version assert failed: got ${PolyOrch_PIXI_VERSION}, "
            "want >= ${E_VERSION}")
    endif()
    if(NOT E_QUIET)
        message(STATUS "pixi ${PolyOrch_PIXI_VERSION} ensured: ${PolyOrch_PIXI_EXECUTABLE}")
    endif()
endfunction()



# ----------------------------------------------------------------- bootstrap ---

# polyorch_pixi_bootstrap([VERSION <x.y.z>] [MANIFEST <p>] [ENVIRONMENT <n>]
#                         [TASK <name>] [URL <installer-url>] [HASH <ALGO=digest>]
#                         [NO_PRECHECK] [COPY_SCRIPTS] [QUIET])
# The cold-start path in one idempotent call, usable straight from `cmake -P`:
#   [1/3] polyorch_pixi_tool_ensure(): locate pixi; absent or older than
#         VERSION -> (precheck conda-forge, then) install and assert the pin.
#   [2/3] pixi install; on a solver failure, regenerate the lock with
#         `pixi update` and retry install once (lock-drift recovery).
#   [3/3] optional `pixi run <TASK>` smoke.
# COPY_SCRIPTS then installs the activation trio (pixi.sh/.bat/.ps1) beside the
# manifest -- the human's next step after a cold start is `source ./pixi.sh`.
# The version pin, manifest path and smoke task are caller policy; this module
# ships the mechanism only. Writes pixi.lock, activation scripts, and $HOME --
# explicit action, not an ordinary configure step.
function(polyorch_pixi_bootstrap)
    set(options NO_PRECHECK QUIET COPY_SCRIPTS)
    set(oneValueArgs VERSION MANIFEST ENVIRONMENT TASK URL HASH)
    cmake_parse_arguments(PARSE_ARGV 0 P "${options}" "${oneValueArgs}" "")
    if(P_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "polyorch_pixi_bootstrap: unknown args: ${P_UNPARSED_ARGUMENTS}")
    endif()

    # [1/3] ensure the binary itself (locate -> install -> assert); manifest-free.
    set(_en "")
    if(P_VERSION)
        list(APPEND _en VERSION "${P_VERSION}")
    endif()
    if(P_URL)
        list(APPEND _en URL "${P_URL}")
    endif()
    if(P_HASH)
        list(APPEND _en HASH "${P_HASH}")
    endif()
    if(P_NO_PRECHECK)
        list(APPEND _en NO_PRECHECK)
    endif()
    if(P_QUIET)
        list(APPEND _en QUIET)
    endif()
    polyorch_pixi_tool_ensure(${_en})

    # Manifest resolution mirrors polyorch_pixi_setup(): arg, cache, upward search.
    set(_manifest "${P_MANIFEST}")
    if(NOT _manifest)
        set(_manifest "${PolyOrch_PIXI_MANIFEST}")
    endif()
    if(NOT _manifest AND CMAKE_CURRENT_SOURCE_DIR)
        _polyorch_pixi_search_manifest(_manifest "${CMAKE_CURRENT_SOURCE_DIR}")
    endif()
    if(NOT _manifest)
        _polyorch_pixi_search_manifest(_manifest "${CMAKE_CURRENT_LIST_DIR}")
    endif()
    if(NOT _manifest)
        message(FATAL_ERROR "polyorch_pixi_bootstrap: no pixi.toml found; pass MANIFEST <path>")
    endif()
    cmake_path(ABSOLUTE_PATH _manifest NORMALIZE)
    if(NOT EXISTS "${_manifest}")
        message(FATAL_ERROR "manifest does not exist: ${_manifest}")
    endif()
    set(PolyOrch_PIXI_MANIFEST "${_manifest}" CACHE FILEPATH
        "pixi.toml/pyproject.toml driving every call; empty = search upward" FORCE)
    if(P_ENVIRONMENT)
        set(PolyOrch_PIXI_ENVIRONMENT "${P_ENVIRONMENT}" CACHE STRING
            "pixi environment (feature set) used by every call" FORCE)
    endif()

    # [2/3] solve + install, with one lock-drift recovery.
    set(_envargs "")
    _polyorch_pixi_env_arg(_envargs "${P_ENVIRONMENT}")
    if(NOT P_QUIET)
        message(STATUS "pixi install (a cold solve can take minutes)...")
    endif()
    _polyorch_pixi_run(_rc _out _err install ${_envargs})
    if(NOT _rc EQUAL 0)
        message(STATUS
            "pixi install failed (exit ${_rc}) -- regenerating the lock with "
            "'pixi update' and retrying once")
        _polyorch_pixi_must(update)
        _polyorch_pixi_must(install ${_envargs})
    endif()

    # [3/3] optional smoke. `pixi run` forwards everything after the task name to
    # the task itself, so the context flags must precede it: build the command by
    # hand instead of via _polyorch_pixi_command (which appends them last).
    if(P_TASK)
        if(NOT P_QUIET)
            message(STATUS "pixi run ${P_TASK} (smoke)...")
        endif()
        set(_run "${PolyOrch_PIXI_EXECUTABLE}" run -m "${PolyOrch_PIXI_MANIFEST}")
        if(PolyOrch_PIXI_CONFIG_FILE)
            list(APPEND _run --config-file "${PolyOrch_PIXI_CONFIG_FILE}")
        elseif(PolyOrch_PIXI_NO_CONFIG)
            list(APPEND _run --no-config)
        endif()
        list(APPEND _run ${_envargs} "${P_TASK}")
        execute_process(COMMAND ${_run} RESULT_VARIABLE _rc
            OUTPUT_VARIABLE _o ERROR_VARIABLE _e)
        if(NOT _rc EQUAL 0)
            message(FATAL_ERROR
                "bootstrap smoke failed: pixi run ${P_TASK} (exit ${_rc})\n"
                "${_o}${_e}")
        endif()
    endif()
    if(P_COPY_SCRIPTS)
        # Default WORKDIR = the manifest directory bootstrap just resolved.
        polyorch_pixi_scripts_install()
    endif()
    if(NOT P_QUIET)
        message(STATUS "pixi ${PolyOrch_PIXI_VERSION} ready: ${PolyOrch_PIXI_EXECUTABLE}")
        message(STATUS "manifest: ${PolyOrch_PIXI_MANIFEST}")
    endif()
endfunction()