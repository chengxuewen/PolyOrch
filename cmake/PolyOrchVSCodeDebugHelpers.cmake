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
# place. The tasks region carries rust-then-node rows and its marker string
# is FROZEN byte-identical to the pre-D32 text (rust-worded even when only
# node rows land -- intentional, so a node-only tree still lands in the
# region a rust user already has) -- changing it would orphan every existing
# user tasks.json (region_write finds no new marker -> PLACED_NEW).
# ===========================================================================

include_guard(GLOBAL)  # 2026-10-10 embed ruling: idempotent same-path re-include
# the family's composite switch: declared here because it belongs to NO
# single face (the three face knobs hang their OR_CONDITION off it).
polyorch_option(PolyOrch_VSCODE_DEBUG_ALL
    "Composite switch: ON forces every face's VSCode debug surface (the face knobs are ignored while ON)" OFF)
include("${CMAKE_CURRENT_LIST_DIR}/_polyorch_vscode_debug_gate.cmake")  # the read-time knob gate (T-H7)

# The native face knob (T-H8): c/cpp/qt add_executable targets debugged
# through CodeLLDB (embedded lldb -- no cpptools extension, no system
# gdb/lldb binary; the rust face already requires the extension).
polyorch_option(PolyOrch_VSCODE_DEBUG_NATIVE
    "Generate VSCode CodeLLDB launch/task rows for native (c/cpp/qt) executables" OFF
    OR_CONDITION PolyOrch_VSCODE_DEBUG_ALL)

set(PolyOrch_VSCODE_DIR "" CACHE PATH
    "Directory for generated .vscode debug files (empty = <CMAKE_SOURCE_DIR>/.vscode)")

# polyorch_native_debug(TARGET <exe-target> [SEG <display-seg>]
#                       [ARGS "a;b"] [CWD <dir>] [FOLDER <ide>])
#
# Register one native executable for the VSCode debug surface (T-H8,
# the fourth face after rust/node/python). The spec carries the FULL
# program path computed at registration time (the declaring directory
# sees its own CMAKE_RUNTIME_OUTPUT_DIRECTORY; the deferred generator
# runs at top scope and could not recover a subdir-set value):
# RUNTIME_OUTPUT_DIRECTORY(target) > CMAKE_RUNTIME_OUTPUT_DIRECTORY >
# CMAKE_CURRENT_BINARY_DIR, then OUTPUT_NAME-or-<target>, plus
# SUFFIX-or-CMAKE_EXECUTABLE_SUFFIX. Multi-config trees expand one
# row per config (the rust-face MC convention; V is single-config).
function(polyorch_native_debug)
    set(_one TARGET SEG CWD)
    set(_multi ARGS)
    cmake_parse_arguments(PARSE_ARGV 0 ND "" "${_one}" "${_multi}")
    if(ND_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "polyorch_native_debug: unknown args: ${ND_UNPARSED_ARGUMENTS}")
    endif()
    if(NOT ND_TARGET)
        message(FATAL_ERROR "polyorch_native_debug: TARGET is required")
    endif()
    if(NOT TARGET "${ND_TARGET}")
        message(FATAL_ERROR
            "polyorch_native_debug: no such target '${ND_TARGET}'")
    endif()
    get_target_property(_tt "${ND_TARGET}" TYPE)
    if(NOT _tt STREQUAL "EXECUTABLE")
        message(FATAL_ERROR
            "polyorch_native_debug: '${ND_TARGET}' is ${_tt}, not an executable")
    endif()
    set(_seg "${ND_SEG}")
    if(NOT _seg)
        set(_seg "debug/native")
    endif()
    set(_cwd "${ND_CWD}")
    if(NOT _cwd)
        set(_cwd "${CMAKE_CURRENT_BINARY_DIR}")
    endif()

    # output dir chain (see header)
    get_target_property(_od "${ND_TARGET}" RUNTIME_OUTPUT_DIRECTORY)
    if(NOT _od OR _od STREQUAL "NOTFOUND")
        if(CMAKE_RUNTIME_OUTPUT_DIRECTORY)
            set(_od "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}")
        else()
            set(_od "${CMAKE_CURRENT_BINARY_DIR}")
        endif()
    endif()
    get_target_property(_on "${ND_TARGET}" OUTPUT_NAME)
    if(NOT _on OR _on STREQUAL "NOTFOUND")
        set(_on "${ND_TARGET}")
    endif()
    get_target_property(_sfx "${ND_TARGET}" SUFFIX)
    if(NOT _sfx OR _sfx STREQUAL "NOTFOUND")
        set(_sfx "${CMAKE_EXECUTABLE_SUFFIX}")
    endif()
    # sanitize BEFORE the property: a quoted ARGS element can itself
    # carry ";" (C21's list-corruption class) -- every element becomes
    # @-joined, so no ";" ever reaches the spec string (measured in the
    # t-native-debug args leg: a ";" spec silently split into two rows
    # and the generator exploded on the fragments)
    set(_argsf "")
    foreach(_a ${ND_ARGS})
        string(REPLACE ";" "@" _a1 "${_a}")
        list(APPEND _argsf "${_a1}")
    endforeach()
    string(JOIN "@" _argsj ${_argsf})

    if(CMAKE_CONFIGURATION_TYPES)
        foreach(_cfg ${CMAKE_CONFIGURATION_TYPES})
            string(TOUPPER "${_cfg}" _cfgu)
            set(_dir "${_od}")
            get_target_property(_odcfg "${ND_TARGET}" RUNTIME_OUTPUT_DIRECTORY_${_cfgu})
            if(_odcfg AND NOT _odcfg STREQUAL "NOTFOUND")
                set(_dir "${_odcfg}")
            elseif(CMAKE_RUNTIME_OUTPUT_DIRECTORY_${_cfgu})
                set(_dir "${CMAKE_RUNTIME_OUTPUT_DIRECTORY_${_cfgu}}")
            else()
                set(_dir "${_od}/${_cfg}")
            endif()
            set_property(GLOBAL APPEND PROPERTY POLYORCH_NATIVE_DEBUG_SPECS
                "${ND_TARGET}|${_dir}/${_on}${_sfx}|${_cwd}|${_seg}|${_argsj}")
        endforeach()
    else()
        set_property(GLOBAL APPEND PROPERTY POLYORCH_NATIVE_DEBUG_SPECS
            "${ND_TARGET}|${_od}/${_on}${_sfx}|${_cwd}|${_seg}|${_argsj}")
    endif()
    message(STATUS "polyorch_native_debug: ${ND_TARGET} registered for F5")
endfunction()

# _polyorch_native_vscode_rows SPECS LAUNCH_OUT TASKS_OUT
# CodeLLDB rows (the rust rows' shape, program-first): the task builds
# the target ITSELF (native add_executable has no -build mediator --
# the face grammar is per-face, not copied from rust).
function(_polyorch_native_vscode_rows SPECS LAUNCH_OUT TASKS_OUT)
    set(_L "")
    set(_K "")
    foreach(_row ${SPECS})
        string(REPLACE "|" ";" _f "${_row}")
        list(GET _f 0 _h)
        list(GET _f 1 _prog)
        list(GET _f 2 _cwd)
        list(GET _f 3 _seg)
        list(GET _f 4 _argsj)
        set(_nm "PolyOrch: ${_h} (${_seg})")
        set(_ja "")
        if(_argsj)
            string(REPLACE "@" ";" _al "${_argsj}")
            set(_q "")
            foreach(_a ${_al})
                list(APPEND _q "\"${_a}\"")
            endforeach()
            string(JOIN ", " _ja ${_q})   # -2 was an invalid SUBSTRING length (measured)
        endif()
        string(APPEND _L
"        {\n"
"            \"name\": \"${_nm}\",\n"
"            \"type\": \"lldb\",\n"
"            \"request\": \"launch\",\n"
"            \"program\": \"${_prog}\",\n"
"            \"cwd\": \"${_cwd}\",\n"
"            \"args\": [${_ja}],\n"
"            \"preLaunchTask\": \"${_nm}\"\n"
"        },\n")
        string(APPEND _K
"        {\n"
"            \"label\": \"${_nm}\",\n"
"            \"type\": \"shell\",\n"
"            \"command\": \"cmake\",\n"
"            \"args\": [\"--build\", \"${CMAKE_BINARY_DIR}\", \"--target\", \"${_h}\"],\n"
"            \"problemMatcher\": []\n"
"        },\n")
    endforeach()
    set(${LAUNCH_OUT} "${_L}" PARENT_SCOPE)
    set(${TASKS_OUT} "${_K}" PARENT_SCOPE)
endfunction()

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
# launch.json region and the merged rust-then-node tasks.json region.
function(_polyorch_vscode_debug_generate)
    get_property(_rspecs GLOBAL PROPERTY POLYORCH_RUST_DEBUG_SPECS)
    get_property(_pspecs GLOBAL PROPERTY POLYORCH_PYTHON_DEBUG_SPECS)
    get_property(_nspecs GLOBAL PROPERTY POLYORCH_NODE_DEBUG_SPECS)
    get_property(_natspecs GLOBAL PROPERTY POLYORCH_NATIVE_DEBUG_SPECS)
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
    set(_tasks "")
    if(_rspecs)
        _polyorch_rust_vscode_rows("${_rspecs}" _rl _tasks)
        string(APPEND _launch "${_rl}")
    endif()
    if(_pspecs AND COMMAND _polyorch_python_vscode_rows)
        _polyorch_python_vscode_rows("${_pspecs}" _pl)
        string(APPEND _launch "${_pl}")
    endif()
    if(_nspecs AND COMMAND _polyorch_node_vscode_rows)
        _polyorch_node_vscode_rows("${_nspecs}" _nl _nt)
        string(APPEND _launch "${_nl}")
        string(APPEND _tasks "${_nt}")
    endif()
    if(_natspecs)
        _polyorch_native_vscode_rows("${_natspecs}" _natl _natt)
        string(APPEND _launch "${_natl}")
        string(APPEND _tasks "${_natt}")
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
    # empty-over-nonempty is the preset-switch signature (the debug preset
    # inherits default's binaryDir): dropping 29 rows silently is how F5
    # breaks invisibly -- say it once, loudly (T-H7.4 4b, Momus).
    if(NOT _launch AND EXISTS "${_f}")
        file(READ "${_f}" _prev)
        string(REGEX MATCHALL "__POLYORCH_GENERATED_BEGIN__" _prev_blocks "${_prev}")
        if(_prev_blocks)
            string(REGEX MATCH "\"name\"[ \t]*:[ \t]*\"[^\"]+\"" _probe "${_prev}")
            if(_probe AND _prev MATCHES "__POLYORCH_GENERATED_BEGIN__")
                # the previous region carried rows (a name survived in the file)
                message(STATUS
                    "PolyOrch VSCode debug: this configure registered ZERO launch rows "
                    "-- writing an empty launch region (the debug gate is OFF; preset "
                    "switched? reconfigure with the debug knob family to restore F5)")
            endif()
        endif()
    endif()
    _polyorch_vscode_region_write("${_f}" "${_begin}" "${_end}" "${_launch}"
        "{\n    \"version\": \"0.2.0\",\n    \"configurations\": [\n%ROWS%\n    ]\n}"
        _st)
    # tasks.json: rust+node rows merged (python needs no preLaunchTask).
    # MARKER FROZEN -- byte-identical to the pre-D32 string (see header).
    if(_tasks)
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
    list(LENGTH _natspecs _nnat)
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
    if(_nnat)
        # native rows are lldb-type too -- the CodeLLDB naming above
        # already covers them; only the count line needs the face.
        string(APPEND _ext " + native (${_nnat})")
    endif()
    message(STATUS
        "PolyOrch: debug configs -> ${_dir} at ${_ts} "
        "(launch ${_st}; rust ${_nr}, python ${_np}, node ${_nn} run target(s); ${_ext})")
endfunction()

# End-of-configure hook, native-face edition (T-H8): same collapse flag,
# same top-level-defer rule as the rust/node/python face hooks (their
# comments carry the why). The native face lives IN this module, so the
# hook lives here too.
_polyorch_vscode_debug_gate(NATIVE _nat_defer_on)
get_property(_polyorch_vscode_hooked GLOBAL PROPERTY POLYORCH_VSCODE_HOOKED)
if(_nat_defer_on AND NOT _polyorch_vscode_hooked)
    set_property(GLOBAL PROPERTY POLYORCH_VSCODE_HOOKED TRUE)
    cmake_language(DEFER DIRECTORY "${CMAKE_SOURCE_DIR}"
        CALL _polyorch_vscode_debug_generate)
endif()
