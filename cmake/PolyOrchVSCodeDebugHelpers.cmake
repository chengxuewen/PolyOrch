# ===========================================================================
# PolyOrchVSCodeDebugHelpers -- shared .vscode managed-region generator.
#
# Single writer, ONE region per file: language faces (rust WP11, python D32)
# contribute JSONC rows through their own pure *_vscode_rows functions and a
# GLOBAL PROPERTY spec table; the deferred end-of-configure generator
# concatenates all face rows in rust-then-python order and writes them into
# one managed region per file. Face-specific regions in the same file would
# make the faces overwrite each other on every reconfigure -- merged rows
# under a single marker pair is the only correct shape.
#
# Managed-region contract (inherited from the rust WP11 original, moved
# verbatim at D32 T1): the BEGIN/END comment lines sit at column 0 INSIDE
# the JSON array, generated rows live between them (every row comma-
# terminated -- VSCode parses trailing commas fine), user configs live ABOVE
# the BEGIN marker. A pre-existing file without markers is never rewritten:
# the generated document lands beside it as <file>.polyorch-new for manual
# adoption.
#
# Marker texts: launch.json uses the COMBINED marker (faces merged); the
# one-shot legacy migration below converts pre-D32 rust-only markers in
# place. tasks.json is rust-only and its marker string is FROZEN byte-
# identical to the pre-D32 text -- changing it would orphan every existing
# user tasks.json (region_write finds no new marker -> PLACED_NEW).
# ===========================================================================

set(PolyOrch_VSCODE_DIR "" CACHE PATH
    "Directory for generated .vscode debug files (empty = <CMAKE_SOURCE_DIR>/.vscode)")

# _polyorch_vscode_region_write(FILE BEGIN END ROWS SHELL OUT)
# Body moved VERBATIM from _polyorch_rust_region_write (PolyOrchRustHelpers,
# WP11). Out-var: OK | REPLACED | CREATED | PLACED_NEW (the original four-
# state machine -- CREATED/REPLACED/PLACED_NEW; OK was never emitted).
function(_polyorch_vscode_region_write FILE BEGIN END ROWS SHELL OUT)
    if(NOT EXISTS "${FILE}")
        string(REPLACE "%ROWS%" "${BEGIN}\n${ROWS}${END}" _full "${SHELL}")
        get_filename_component(_par "${FILE}" DIRECTORY)
        file(MAKE_DIRECTORY "${_par}")
        file(WRITE "${FILE}" "${_full}\n")
        set(${OUT} "CREATED" PARENT_SCOPE)
        return()
    endif()
    file(READ "${FILE}" _t)
    string(FIND "${_t}" "${BEGIN}" _b)
    string(FIND "${_t}" "${END}" _e)
    if(_b GREATER -1 AND _e GREATER _b)
        string(LENGTH "${_t}" _len)
        string(SUBSTRING "${_t}" 0 "${_b}" _pre)
        string(LENGTH "${END}" _endlen)
        math(EXPR _e2 "${_e} + ${_endlen}")
        string(SUBSTRING "${_t}" "${_e2}" "${_len}" _post)
        set(_new "${_pre}${BEGIN}\n${ROWS}${END}${_post}")
        if(NOT _new STREQUAL _t)
            file(WRITE "${FILE}" "${_new}")
        endif()
        set(${OUT} "REPLACED" PARENT_SCOPE)
        return()
    endif()
    # no markers: never rewrite a file we do not own -- park beside it
    string(REPLACE "%ROWS%" "${BEGIN}\n${ROWS}${END}" _full "${SHELL}")
    file(WRITE "${FILE}.polyorch-new" "${_full}\n")
    set(${OUT} "PLACED_NEW" PARENT_SCOPE)
endfunction()

# End-of-configure deferred generator (hooked at include time by EACH face;
# collapse to once per tree via POLYORCH_VSCODE_HOOKED). Reads every face's
# spec property, asks that face's rows function, writes the combined
# launch.json region and the rust-only tasks.json region.
function(_polyorch_vscode_debug_generate)
    get_property(_rspecs GLOBAL PROPERTY POLYORCH_RUST_DEBUG_SPECS)
    get_property(_pspecs GLOBAL PROPERTY POLYORCH_PYTHON_DEBUG_SPECS)
    get_property(_nspecs GLOBAL PROPERTY POLYORCH_NODE_DEBUG_SPECS)
    set(_dir "${PolyOrch_VSCODE_DIR}")
    if(NOT _dir)
        set(_dir "${PolyOrch_RUST_VSCODE_DIR}")      # legacy knob honored
    endif()
    if(NOT _dir)
        set(_dir "${CMAKE_SOURCE_DIR}/.vscode")
    endif()
    if(EXISTS "${_dir}" AND NOT IS_DIRECTORY "${_dir}")
        # a FILE squatting on the directory path: skip loudly, never unlink
        message(WARNING
            "PolyOrch_VSCODE_DIR: '${_dir}' exists as a file -- "
            "debug config surface skipped")
        return()
    endif()
    set(_launch "")
    if(_rspecs)
        _polyorch_rust_vscode_rows("${_rspecs}" _rl "")
        string(APPEND _launch "${_rl}")
    endif()
    if(_pspecs AND COMMAND _polyorch_python_vscode_rows)
        _polyorch_python_vscode_rows("${_pspecs}" _pl)
        string(APPEND _launch "${_pl}")
    endif()
    if(_nspecs AND COMMAND _polyorch_node_vscode_rows)
        _polyorch_node_vscode_rows("${_nspecs}" _nl)
        string(APPEND _launch "${_nl}")
    endif()
    set(_begin "// __POLYORCH_GENERATED_BEGIN__ (PolyOrch debug configs; keep this block last, regenerate via reconfigure)")
    set(_end "// __POLYORCH_GENERATED_END__")
    set(_old_begin "// __POLYORCH_GENERATED_BEGIN__ (PolyOrch rust debug configs; keep this block last, regenerate via reconfigure)")
    set(_f "${_dir}/launch.json")
    # one-shot legacy-region migration: convert the pre-D32 rust-only BEGIN
    # line to the combined one IN PLACE (contents are replaced by the
    # region_write below anyway; touching only the marker keeps the
    # never-rewrite rule honest for markerless user files)
    if(EXISTS "${_f}")
        file(READ "${_f}" _t)
        string(FIND "${_t}" "${_begin}" _nb)
        string(FIND "${_t}" "${_old_begin}" _ob)
        if(_nb LESS 0 AND _ob GREATER -1)
            string(REPLACE "${_old_begin}" "${_begin}" _t "${_t}")
            file(WRITE "${_f}" "${_t}")
        endif()
    endif()
    set(_st "")
    _polyorch_vscode_region_write("${_f}" "${_begin}" "${_end}" "${_launch}"
        "{\n    \"version\": \"0.2.0\",\n    \"configurations\": [\n%ROWS%\n    ]\n}"
        _st)
    # tasks.json: rust face only (python needs no preLaunchTask).
    # MARKER FROZEN -- byte-identical to the pre-D32 string (see header).
    if(_rspecs)
        _polyorch_rust_vscode_rows("${_rspecs}" _dummy _tasks)
        set(_st2 "")
        _polyorch_vscode_region_write("${_dir}/tasks.json"
            "// __POLYORCH_GENERATED_BEGIN__ (PolyOrch rust build tasks; keep this block last, regenerate via reconfigure)"
            "// __POLYORCH_GENERATED_END__"
            "${_tasks}"
            "{\n    \"version\": \"2.0.0\",\n    \"tasks\": [\n%ROWS%\n    ]\n}"
            _st2)
    endif()
    list(LENGTH _rspecs _nr)
    list(LENGTH _pspecs _np)
    list(LENGTH _nspecs _nn)
    string(TIMESTAMP _ts "%H:%M:%S")
    set(_ext "CodeLLDB (rust) and/or Python Debugger (debugpy)")
    if(NOT _pspecs AND NOT _rspecs AND _nspecs)
        # node-only tree: js-debug is VSCode built-in -- naming CodeLLDB
        # here would be flatly wrong (Oracle M-2; no test pinned the old
        # text, verified at authoring).
        set(_ext "js-debug (node) -- VSCode built-in, no extension install")
    elseif(NOT _pspecs)
        set(_ext "CodeLLDB extension required")
    elseif(_nspecs)
        string(APPEND _ext " + js-debug (node, built-in)")
    endif()
    message(STATUS
        "PolyOrch: debug configs -> ${_dir} at ${_ts} "
        "(launch ${_st}; rust ${_nr}, python ${_np}, node ${_nn} run target(s); ${_ext})")
endfunction()
