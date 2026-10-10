# ===========================================================================
# PolyOrchPythonHelpers -- the python face (D32).
#
# Scope is deliberately tiny (the D29 precedent): setup + run. Python has no
# PolyOrch-orchestrated compile step; this face LOCATES an interpreter, runs
# scripts as graph buttons with an injected environment, and (T3) registers
# the run targets for VSCode debugpy generation through the shared
# PolyOrchVSCodeDebugHelpers machinery. build/import/test/wheel verbs are
# NOT here until a real consumer needs them.
# The run buttons also mount their source directory into IDE target
# trees (rust-face parity, display-only: _polyorch_python_mount_sources).
#
# Family idioms, copied before diverging:
#   - discovery tiers + CACHE/report shape      -> polyorch_node_setup (D29)
#   - run-target grammar <handle>-run           -> polyorch_rust_run  (WP11)
#   - prefix/caller-key mechanism               -> _polyorch_node_apply_prefix
# One deliberate deviation from node (D32 known-deviation 1): the tier-a
# knob WINS over PATH, as node's own comment promises; node's code has the
# order inverted -- python follows the contract, not the bug.
# ===========================================================================

option(PolyOrch_PYTHON_VSCODE_DEBUG
    "Generate .vscode debugpy launch configs for polyorch_python_run targets" OFF)
option(PolyOrch_PYTHON_SOURCES_PLAIN
    "Serve mounted python sources as plain entries (IDE header-fold escape)" OFF)

# _polyorch_python_apply_prefix(OUT <name>)
# Same caller-key grammar as node (A2): PolyOrch_PYTHON_TARGET_PREFIX is the
# python face's own knob; <PROJECT_NAME>_POLYORCH_TARGET_PREFIX (set by the
# examples fusion loop) wins over it; empty disables.
function(_polyorch_python_apply_prefix out name)
    set(_p "")
    if(DEFINED ${PROJECT_NAME}_POLYORCH_PYTHON_TARGET_PREFIX
            AND NOT "${${PROJECT_NAME}_POLYORCH_PYTHON_TARGET_PREFIX}" STREQUAL "")
        set(_p "${${PROJECT_NAME}_POLYORCH_PYTHON_TARGET_PREFIX}")
    elseif(PolyOrch_PYTHON_TARGET_PREFIX)
        set(_p "${PolyOrch_PYTHON_TARGET_PREFIX}")
    endif()
    if(_p)
        set(${out} "${_p}-${name}" PARENT_SCOPE)
    else()
        set(${out} "${name}" PARENT_SCOPE)
    endif()
endfunction()

# _polyorch_python_sanitize_name(OUT <name>)
# Run/label names are user identifiers, not npm specs: reject the debug-spec
# separator outright (a '|' in a name would corrupt the 7-field spec table,
# T3), reject '@' heads (add_custom_target refuses them, measured on the
# node face), pass everything else through.
function(_polyorch_python_sanitize_name out name)
    if(name MATCHES "\\|")
        message(FATAL_ERROR
            "polyorch_python: name '${name}' contains the reserved '|' character")
    endif()
    string(SUBSTRING "${name}" 0 1 _c)
    if(_c STREQUAL "@")
        message(FATAL_ERROR
            "polyorch_python: name '${name}' starts with '@' "
            "(add_custom_target rejects '@'-headed names)")
    endif()
    set(${out} "${name}" PARENT_SCOPE)
endfunction()

# polyorch_python_setup()
# Three-tier interpreter discovery (the node doctrine): tier a explicit
# knob, tier b PATH (+ ~/.pixi/bin), tier c any pixi env's python3. Reports
# and caches; never FATALs -- absence degrades the verbs to STATUS lines.
function(polyorch_python_setup)
    cmake_parse_arguments(PARSE_ARGV 0 S "REQUIRED" "" "")
    if(POLYORCH_PYTHON_FOUND AND PolyOrchPython_EXECUTABLE)
        # idempotent: report what the cache already holds (node parity)
        message(STATUS
            "polyorch_python: interpreter (cached) ${PolyOrchPython_EXECUTABLE}")
        return()
    endif()
    # NO find_program pre-set: an already-defined (even empty) result var
    # short-circuits NO_CACHE searches -- measured footgun, CMake 4.4.3.
    if(PolyOrchPythonExe)                                   # tier a: knob wins
        set(_py "${PolyOrchPythonExe}")
    else()
        find_program(_py NAMES python3 python               # tier b: PATH
            HINTS "$ENV{HOME}/.pixi/bin" NO_CACHE)
    endif()
    if(NOT _py)                                            # tier c: pixi envs
        file(GLOB _g
            "$ENV{HOME}/.pixi/envs/*/bin/python3"
            "/tmp/opencode/*/.pixi/envs/default/bin/python3")
        list(LENGTH _g _n)
        if(_n GREATER 0)
            list(GET _g 0 _py)
        endif()
    endif()
    if(_py)
        set(PolyOrchPython_EXECUTABLE "${_py}" CACHE FILEPATH
            "python interpreter (tier a/b/c resolved)" FORCE)
        set(POLYORCH_PYTHON_FOUND TRUE CACHE BOOL
            "python toolchain located" FORCE)
        execute_process(COMMAND "${_py}" --version
            OUTPUT_VARIABLE _v ERROR_QUIET
            OUTPUT_STRIP_TRAILING_WHITESPACE)
        message(STATUS "polyorch_python: interpreter ${_py} (${_v})")
    else()
        set(POLYORCH_PYTHON_FOUND FALSE CACHE BOOL
            "python toolchain located" FORCE)
        if(S_REQUIRED)
            message(FATAL_ERROR
                "polyorch_python: REQUIRED but no interpreter found -- "
                "knobs: PolyOrchPythonExe, PATH, ~/.pixi/envs/*/bin")
        endif()
        message(STATUS
            "polyorch_python: no interpreter found -- knobs PolyOrchPythonExe, "
            "PATH, ~/.pixi/envs/*/bin; python verbs degraded")
    endif()
endfunction()

# _polyorch_python_mount_sources(TGT SRC_DIR [SOFT])
# Attach SRC_DIR's python sources (+ the manifest-equivalent files) to
# TGT's SOURCES so IDE target trees show and open them on the button.
# COSMETIC ONLY -- the rust face's argument copied: python owns the real
# inputs, a glob miss or stray hit never affects correctness (that is why
# the GLOB caution in the CMake docs does not apply here). CONFIGURE_DEPENDS
# re-globs on configure so newly added files appear. SOFT = display-only
# caller: a missing SRC_DIR skips the mount -- a display feature NEVER
# fails a configure (HARD is kept for a future build-side caller, rust's
# build/verb split).
function(_polyorch_python_mount_sources TGT SRC_DIR)
    cmake_parse_arguments(PARSE_ARGV 2 MM "SOFT" "" "")
    get_filename_component(_root "${SRC_DIR}" ABSOLUTE)
    if(NOT IS_DIRECTORY "${_root}")
        if(MM_SOFT)
            return()
        endif()
        message(FATAL_ERROR
            "_polyorch_python_mount_sources: source dir '${_root}' does not exist")
    endif()
    # Package subdirs join the display tree; vendor/derived dirs never do:
    # any path component named venv/env/build/site-packages/__pycache__ or
    # starting with '.' drops the file (vendor-tree explosion guard).
    file(GLOB_RECURSE _rel CONFIGURE_DEPENDS RELATIVE "${_root}" "${_root}/*.py")
    set(_files "")
    foreach(_f IN LISTS _rel)
        if(NOT _f MATCHES "(^|/)(\\.[^/]*|venv|env|build|site-packages|__pycache__)/")
            list(APPEND _files "${_root}/${_f}")
        endif()
    endforeach()
    # Manifest equivalents (the Cargo.toml/lock slot of the rust idiom):
    # project metadata + dependency pins, existence-gated.
    foreach(_m IN ITEMS pyproject.toml setup.py requirements.txt)
        if(EXISTS "${_root}/${_m}")
            list(APPEND _files "${_root}/${_m}")
        endif()
    endforeach()
    if(NOT _files)
        return()
    endif()
    list(REMOVE_DUPLICATES _files)
    # HEADER_FILE_ONLY marks them "not compiled here" for CMake; some IDE
    # versions fold header-class entries away in target trees, so
    # PolyOrch_PYTHON_SOURCES_PLAIN=ON serves them as plain sources -- the
    # same escape the rust face carries. Either way they are display-only.
    if(PolyOrch_PYTHON_SOURCES_PLAIN)
        set_source_files_properties(${_files} PROPERTIES HEADER_FILE_ONLY OFF)
    else()
        set_source_files_properties(${_files} PROPERTIES HEADER_FILE_ONLY ON)
    endif()
    set_property(TARGET "${TGT}" APPEND PROPERTY SOURCES ${_files})
endfunction()

# polyorch_python_run(TARGET <t> SCRIPT <s> [NAME <label>] [ARGS <a>...]
#                     [ENVS <K=V>...] [WORKING_DIRECTORY <dir>] [FOLDER <ide>]
#                     [JUST_MY_CODE ON|OFF] [NO_SOURCES])
# Registers the button <t>-run (the rust face's grammar; prefixed
# through the D28 grammar): cmake -E env <K=V>... <interp> <script> <args>
# WORKING_DIRECTORY defaults to the script's directory. ENVS flows through
# the command wrapper at BUILD time (the -E env line IS the injection
# point); no host-environment scrubbing here -- unlike cargo, python needs
# a normal environment (PATH/HOME/encodings) and the interpreter itself is
# pinned, which is the half that mattered (PIT-14's shape does not port).
function(polyorch_python_run)
    set(_opts NO_SOURCES)
    set(_one TARGET SCRIPT NAME WORKING_DIRECTORY FOLDER JUST_MY_CODE)
    set(_multi ARGS ENVS)
    cmake_parse_arguments(PARSE_ARGV 0 R "${_opts}" "${_one}" "${_multi}")
    if(NOT R_TARGET OR NOT R_SCRIPT)
        message(FATAL_ERROR "polyorch_python_run: TARGET and SCRIPT are required")
    endif()
    if(NOT POLYORCH_PYTHON_FOUND)
        polyorch_python_setup()
    endif()
    if(NOT POLYORCH_PYTHON_FOUND)
        message(STATUS
            "polyorch_python_run(${R_TARGET}): skipped -- no interpreter "
            "(see polyorch_python: STATUS above)")
        return()
    endif()
    _polyorch_python_sanitize_name(_st "${R_TARGET}")
    if(NOT R_NAME)
        set(_nm "${R_TARGET}")
    else()
        _polyorch_python_sanitize_name(_nm "${R_NAME}")
    endif()
    foreach(_kv IN LISTS R_ENVS)
        if(NOT _kv MATCHES "^[A-Za-z_][A-Za-z0-9_]*=")
            message(FATAL_ERROR
                "polyorch_python_run: ENVS entry '${_kv}' is not NAME=VALUE")
        endif()
        if(_kv MATCHES "\\|")
            message(FATAL_ERROR
                "polyorch_python_run: ENVS entry '${_kv}' contains reserved '|'")
        endif()
    endforeach()
    if(R_SCRIPT MATCHES "\\|" OR R_WORKING_DIRECTORY MATCHES "\\|")
        message(FATAL_ERROR
            "polyorch_python_run: path contains the reserved '|' (debug-spec separator)")
    endif()
    _polyorch_python_apply_prefix(_rh "${_st}-run")
    # Debug-row label default = the PREFIXED handle (host-contact parity
    # 2026-10-08: the rust face labels its rows with the namespaced handle
    # -- "PolyOrch: polyorch-rust-basic-greet (debug)" -- a bare "greet"
    # collides across packages in a fused host; no verb suffix on the label
    # (a debug config debugs the script, not the button)). Explicit NAME wins.
    _polyorch_python_apply_prefix(_lh "${_st}")
    if(R_WORKING_DIRECTORY)
        set(_cwd "${R_WORKING_DIRECTORY}")
    else()
        get_filename_component(_cwd "${R_SCRIPT}" DIRECTORY)
    endif()
    set(_envargv "")
    foreach(_kv IN LISTS R_ENVS)
        list(APPEND _envargv "${_kv}")
    endforeach()
    add_custom_target("${_rh}"
        COMMAND "${CMAKE_COMMAND}" -E env ${_envargv}
            "${PolyOrchPython_EXECUTABLE}" "${R_SCRIPT}" ${R_ARGS}
        WORKING_DIRECTORY "${_cwd}"
        USES_TERMINAL
        COMMENT "python: ${_nm} (${_rh})")
    # IDE folder: explicit FOLDER wins; default = the fusion loop's shared
    # per-example root (PolyOrch_RUST_FOLDER_ROOT -- the rust helper's
    # idiom, consumed by node's example too). Standalone leaves it unset.
    if(NOT R_FOLDER)
        set(R_FOLDER "${PolyOrch_RUST_FOLDER_ROOT}")
    endif()
    if(R_FOLDER)
        set_target_properties("${_rh}" PROPERTIES FOLDER "${R_FOLDER}")
    endif()
    # IDE source mount (rust-face parity): the button's directory tree rides
    # the target as HEADER_FILE_ONLY display entries. Root = the caller's
    # WORKING_DIRECTORY when set, else this caller dir -- python has no
    # metadata authority, WDIR is the closest analogue of the crate dir.
    # Display-only caller: SOFT, a missing root must never fail a configure.
    if(NOT R_NO_SOURCES)
        if(R_WORKING_DIRECTORY)
            _polyorch_python_mount_sources("${_rh}" "${R_WORKING_DIRECTORY}" SOFT)
        else()
            _polyorch_python_mount_sources("${_rh}" "${CMAKE_CURRENT_SOURCE_DIR}" SOFT)
        endif()
    endif()

    # T3: debug-spec registration (gate OFF -> zero footprint).
    if(PolyOrch_PYTHON_VSCODE_DEBUG)
        string(REPLACE ";" "," _argsj "${R_ARGS}")
        string(REPLACE ";" "," _envsj "${R_ENVS}")
        if(R_NAME)
            set(_lbl "${_nm}")
        else()
            set(_lbl "${_lh}")
        endif()
        # JUST_MY_CODE knob: unset/empty/invalid -> ON (the debugpy default;
        # unknown values take the default silently, the house idiom). Only the
        # literal OFF reaches the rows renderer as a flip signal -- it lets
        # debugpy stop in library/stdlib code, not just the launched tree.
        set(_jmc "ON")
        if(DEFINED R_JUST_MY_CODE AND NOT R_JUST_MY_CODE STREQUAL "")
            set(_jmc "${R_JUST_MY_CODE}")
        endif()
        set_property(GLOBAL APPEND PROPERTY POLYORCH_PYTHON_DEBUG_SPECS
            "${_lbl}|${PolyOrchPython_EXECUTABLE}|${R_SCRIPT}|${_cwd}|${_argsj}|${_envsj}|${_jmc}")
    endif()
endfunction()

# _polyorch_python_vscode_rows(SPECS LAUNCH_OUT)
# Pure spec-table -> JSONC region text (the rust rows function's sibling;
# no tasks rows -- debugpy launches need no preLaunchTask). Spec row shape:
# NAME|INTERP|SCRIPT|CWD|ARGS|ENVS|JUST_MY_CODE  (exactly six '|'; ARGS/ENVS
# comma-joined; empty trailing fields still serialize the pipes; a legacy
# five-pipe row renders the justMyCode default true). Values with
# embedded double-quotes are unescaped -- same known-deviation 2 class as
# the rust rows (paths with \\ inside JSON; revisit only if a consumer
# ever needs it).
function(_polyorch_python_vscode_rows SPECS LAUNCH_OUT)
    set(_L "")
    foreach(_row ${SPECS})
        string(REPLACE "|" ";" _f "${_row}")
        list(GET _f 0 _nm)
        list(GET _f 1 _py)
        list(GET _f 2 _script)
        list(GET _f 3 _cwd)
        list(GET _f 4 _args)
        list(GET _f 5 _envs)
        # 7th field, optional (legacy rows carry six). list(GET) out of range
        # is FATAL, so the length guard is mandatory, not stylistic.
        list(LENGTH _f _fn)
        set(_jmc "ON")
        if(_fn GREATER 6)
            list(GET _f 6 _jmc)
        endif()
        set(_jmcv true)
        if(_jmc STREQUAL "OFF")
            set(_jmcv false)
        endif()
        string(APPEND _L
"        {\n"
"            \"name\": \"PolyOrch: ${_nm}\",\n"
"            \"type\": \"debugpy\",\n"
"            \"request\": \"launch\",\n"
"            \"program\": \"${_script}\",\n"
"            \"python\": \"${_py}\",\n"
"            \"cwd\": \"${_cwd}\",\n"
"            \"console\": \"integratedTerminal\",\n"
"            \"justMyCode\": ${_jmcv}")
        if(NOT _args STREQUAL "")
            string(REPLACE "," ";" _al "${_args}")
            set(_aj "")
            foreach(_a ${_al})
                string(APPEND _aj "\"${_a}\", ")
            endforeach()
            string(APPEND _L ",\n            \"args\": [${_aj}]")
        endif()
        if(NOT _envs STREQUAL "")
            string(REPLACE "," ";" _el "${_envs}")
            set(_eo "")
            foreach(_kv ${_el})
                string(FIND "${_kv}" "=" _eq)
                string(SUBSTRING "${_kv}" 0 "${_eq}" _k)
                math(EXPR _v1 "${_eq} + 1")
                string(SUBSTRING "${_kv}" "${_v1}" -1 _v)
                string(APPEND _eo "\"${_k}\": \"${_v}\", ")
            endforeach()
            string(APPEND _L ",\n            \"env\": {${_eo}}")
        endif()
        string(APPEND _L "\n        },\n")
    endforeach()
    set(${LAUNCH_OUT} "${_L}" PARENT_SCOPE)
endfunction()

# ===========================================================================
# Per-round include hook: register the SHARED end-of-configure generator
# ONCE per tree while this face's gate is ON (collapses with the rust face's
# identical hook via the shared POLYORCH_VSCODE_HOOKED flag -- single writer,
# one region, both faces' rows merged; see PolyOrchVSCodeDebugHelpers).
# ===========================================================================
include("${CMAKE_CURRENT_LIST_DIR}/PolyOrchVSCodeDebugHelpers.cmake")
get_property(_polyorch_pyv_hooked GLOBAL PROPERTY POLYORCH_VSCODE_HOOKED)
if(PolyOrch_PYTHON_VSCODE_DEBUG AND NOT _polyorch_pyv_hooked)
    set_property(GLOBAL PROPERTY POLYORCH_VSCODE_HOOKED TRUE)
    # DEFER TO THE TOP-LEVEL DIRECTORY'S END, not the including
    # directory's: faces opted in by LATER sibling subdirs must have
    # registered their specs before the single writer runs (measured
    # defect 2026-10-08: python-first subdirectory fired the generator
    # with "node 0" and the later node rows were orphaned forever).
    cmake_language(DEFER DIRECTORY "${CMAKE_SOURCE_DIR}"
        CALL _polyorch_vscode_debug_generate)
endif()
