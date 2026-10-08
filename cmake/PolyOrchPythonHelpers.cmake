# ===========================================================================
# PolyOrchPythonHelpers -- the python face (D32).
#
# Scope is deliberately tiny (the D29 precedent): setup + run. Python has no
# PolyOrch-orchestrated compile step; this face LOCATES an interpreter, runs
# scripts as graph buttons with an injected environment, and (T3) registers
# the run targets for VSCode debugpy generation through the shared
# PolyOrchVSCodeDebugHelpers machinery. build/import/test/wheel verbs are
# NOT here until a real consumer needs them.
#
# Family idioms, copied before diverging:
#   - discovery tiers + CACHE/report shape      -> polyorch_node_setup (D29)
#   - run-target grammar run-<handle>           -> polyorch_rust_run  (WP11)
#   - prefix/caller-key mechanism               -> _polyorch_node_apply_prefix
# One deliberate deviation from node (D32 known-deviation 1): the tier-a
# knob WINS over PATH, as node's own comment promises; node's code has the
# order inverted -- python follows the contract, not the bug.
# ===========================================================================

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
# separator outright (a '|' in a name would corrupt the 6-field spec table,
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
    set(_py "")
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

# polyorch_python_run(TARGET <t> SCRIPT <s> [NAME <label>] [ARGS <a>...]
#                     [ENVS <K=V>...] [WORKING_DIRECTORY <dir>])
# Registers the button run-<t> (prefixed through the D28 grammar):
#   cmake -E env <K=V>... <interp> <script> <args>
# WORKING_DIRECTORY defaults to the script's directory. ENVS flows through
# the command wrapper at BUILD time (the -E env line IS the injection
# point); no host-environment scrubbing here -- unlike cargo, python needs
# a normal environment (PATH/HOME/encodings) and the interpreter itself is
# pinned, which is the half that mattered (PIT-14's shape does not port).
function(polyorch_python_run)
    set(_one TARGET SCRIPT NAME WORKING_DIRECTORY)
    set(_multi ARGS ENVS)
    cmake_parse_arguments(PARSE_ARGV 0 R "" "${_one}" "${_multi}")
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
    _polyorch_python_apply_prefix(_rh "run-${_st}")
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
    # T3 seam: debug-spec registration lands here (gate-gated).
endfunction()
