# ===========================================================================
# PolyOrchVSCodeDebugHelpers -- shared .vscode managed-region generator.
#
# Single writer, ONE region PER CONFIGURING TREE per file: language faces
# (rust WP11, python D32, native T-H8) contribute JSONC rows through their
# own pure *_vscode_rows functions and a GLOBAL PROPERTY spec table; the
# deferred end-of-configure generator concatenates all face rows and writes
# them into the region of ITS OWN tree -- the BEGIN marker carries a tree id
# (first 8 hex of SHA1(CMAKE_BINARY_DIR)), so two trees configuring the same
# source (the CLI bridge tree vs a CMake Tools preset tree) each rewrite
# only their own slice and never erase each other's rows
# (examples-ide-unification ruling 4; motivation: rust rows were stable only
# because exactly one tree generated them).
#
# Cross-tree duplicate rows (the same target registered by both trees --
# consumers pin artifact/script paths ABSOLUTE, so a row is byte-identical
# across trees and the task rows differ only in the build dir, which either
# tree builds to the same program): SKIP-ON-NAME. A row whose name/label
# already exists in ANOTHER tree's region is not written again; the first
# configuring tree holds it. Pinned by the t-native-debug two-tree legs.
#
# Face-specific regions in the same file would make the faces overwrite
# each other on every reconfigure -- merged rows under one marker pair per
# tree is the only correct shape (unchanged D32 finding, now per slice).
#
# Managed-region contract (inherited from the rust WP11 original, moved
# verbatim at D32 T1): the BEGIN/END comment lines sit at column 0 INSIDE
# the JSON array, generated rows live between them (every row comma-
# terminated -- VSCode parses trailing commas fine), user configs live ABOVE
# the BEGIN marker. A pre-existing file without ANY generated marker is
# never rewritten: the generated document lands beside it as
# <file>.polyorch-new for manual adoption.
#
# Marker texts: launch.json uses the COMBINED marker text (faces merged),
# tasks.json the rust-worded FROZEN text (byte-identical to the pre-D32
# string apart from the tree id inserted after BEGIN__; a node-only tree
# still lands in the region a rust user already has). One-shot legacy
# migration: a markerless-id BEGIN line (either the D32 combined text or
# the pre-D32 rust-only text) is RE-TITLED in place to this tree's id --
# the claiming tree rewrites its contents on the region_write below; the
# empty-region guard below says so loudly when the claiming tree registered
# zero rows (reconfigure the tree that owns the old rows to restore them).
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

# _polyorch_vscode_dedup_rows ROWS KIND OTHERS OUT
# Skip-on-name (examples-ide-unification ruling 4): drop every row block of
# ROWS whose "name"/"label" (KIND) already exists in OTHERS -- the file
# text with THIS tree's own region already removed (the caller computes it;
# comparing against the full file would self-cancel: our own previous rows
# carry the same names). Row blocks are the faces' fixed shape: each starts
# with the 8-space `        {` line. Blocks carry no ";" (JSONC), so the
# REPLACE-to-list split is safe.
function(_polyorch_vscode_dedup_rows ROWS KIND OTHERS OUT)
    if(NOT ROWS OR NOT OTHERS)
        set(${OUT} "${ROWS}" PARENT_SCOPE)
        return()
    endif()
    # split into row blocks (blocks are JSONC: no ";" inside)
    string(REPLACE "        {\n" "@@POLYORCH_B@@" _tmp "${ROWS}")
    string(REPLACE "@@POLYORCH_B@@" ";" _tmp "${_tmp}")
    set(_out "")
    foreach(_blk IN LISTS _tmp)
        if(NOT _blk)
            continue()
        endif()
        string(REGEX MATCH "\"${KIND}\": \"[^\"]+\"" _nm "${_blk}")
        set(_skip "")
        if(_nm)
            # literal FIND, not MATCHES: a label carries regex metacharacters
            # (the SEG parentheses) -- as a pattern it would never match
            string(FIND "${OTHERS}" "${_nm}" _at)
            if(_at GREATER -1)
                set(_skip 1)
            endif()
        endif()
        if(NOT _skip)
            string(APPEND _out "        {\n${_blk}")
        endif()
    endforeach()
    set(${OUT} "${_out}" PARENT_SCOPE)
endfunction()

# _polyorch_vscode_region_write FILE BEGIN END ROWS SHELL OUT
# Per-tree slice writer (examples-ide-unification ruling 4). Out-var:
# CREATED | REPLACED | APPENDED | PLACED_NEW. The BEGIN text carries this
# tree's id, so the file may hold one region PER TREE; a tree whose region
# is absent APPENDS its slice after the LAST generated END (still inside
# the JSON array -- rows are comma-terminated, VSCode parses trailing
# commas). A file with NO generated marker at all is never rewritten:
# park beside it (the never-adopted-user-files contract).
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
    if(_b GREATER -1)
        # our slice exists -- replace it, touch nothing else. The END search
        # runs on the TAIL past our BEGIN (SUBSTRING slice, since string(FIND)
        # has no start argument): a naive first-END FIND would hit an earlier
        # tree's END and fall through to append, growing a duplicate slice
        # every reconfigure
        string(SUBSTRING "${_t}" "${_b}" -1 _tail)
        string(FIND "${_tail}" "${END}" _er)
        if(_er GREATER -1)
            math(EXPR _e "${_b} + ${_er}")
            string(LENGTH "${_t}" _len)
            string(LENGTH "${END}" _endlen)
            math(EXPR _e2 "${_e} + ${_endlen}")
            string(SUBSTRING "${_t}" 0 "${_b}" _pre)
            string(SUBSTRING "${_t}" "${_e2}" "${_len}" _post)
            set(_new "${_pre}${BEGIN}\n${ROWS}${END}${_post}")
            if(NOT _new STREQUAL _t)
                file(WRITE "${FILE}" "${_new}")
            endif()
            set(${OUT} "REPLACED" PARENT_SCOPE)
            return()
        endif()
        # BEGIN without END (hand-mangled): fall through to append -- never
        # silently eat a broken slice
    endif()
    # no slice of ours: append after the LAST generated END, if any
    # (REVERSE find = last occurrence in one call; string(FIND) has no
    # start argument -- a scan loop would spin forever on the first hit)
    string(FIND "${_t}" "${END}" _last_end REVERSE)
    if(_last_end LESS 0)
        # markers absent or hand-mangled (BEGIN without END): the file is
        # not ours to repair -- park beside it, never rewrite
        string(REPLACE "%ROWS%" "${BEGIN}\n${ROWS}${END}" _full "${SHELL}")
        file(WRITE "${FILE}.polyorch-new" "${_full}\n")
        set(${OUT} "PLACED_NEW" PARENT_SCOPE)
        return()
    endif()
    string(LENGTH "${END}" _endlen)
    math(EXPR _ins "${_last_end} + ${_endlen}")
    string(LENGTH "${_t}" _len)
    string(SUBSTRING "${_t}" 0 "${_ins}" _pre)
    string(SUBSTRING "${_t}" "${_ins}" "${_len}" _post)
    set(_new "${_pre}\n${BEGIN}\n${ROWS}${END}${_post}")
    if(NOT _new STREQUAL _t)
        file(WRITE "${FILE}" "${_new}")
    endif()
    set(${OUT} "APPENDED" PARENT_SCOPE)
endfunction()

# End-of-configure deferred generator (hooked at include time by EACH face;
# collapse to once per tree via POLYORCH_VSCODE_HOOKED). Reads every face's
# spec property, asks that face's rows function, writes this tree's
# combined launch.json region and its slice of the merged rust-then-node
# tasks.json region.
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
    # tree id: stable digest of the binary dir (short enough for a comment)
    string(SHA1 _tid "${CMAKE_BINARY_DIR}")
    string(SUBSTRING "${_tid}" 0 8 _tid)
    set(_begin "// __POLYORCH_GENERATED_BEGIN__ ${_tid} (PolyOrch debug configs; keep this block last, regenerate via reconfigure)")
    set(_end "// __POLYORCH_GENERATED_END__")
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
    set(_f "${_dir}/launch.json")
    # one-shot legacy migration: the D32 combined marker and the pre-D32
    # rust-only marker carry NO tree id -- re-title either to THIS tree's id
    # in place (contents are replaced by the region_write below anyway;
    # touching only the marker keeps the never-rewrite rule honest for
    # markerless user files). Markerless-id form = "BEGIN__ (" (the id sits
    # between "__" and " (" on titled markers).
    if(EXISTS "${_f}")
        file(READ "${_f}" _t)
        string(REGEX MATCH "// __POLYORCH_GENERATED_BEGIN__ \\(" _lg "${_t}")
        if(_lg)
            string(REPLACE "${_lg}"
                "// __POLYORCH_GENERATED_BEGIN__ ${_tid} (PolyOrch debug configs; keep this block last, regenerate via reconfigure)"
                _t "${_t}")
            file(WRITE "${_f}" "${_t}")
        endif()
    endif()
    # skip-on-name dedup: compare against the file WITHOUT our own slice
    # (our previous rows carry the same names -- comparing against the full
    # file would cancel every row and silently empty our region).
    set(_others "")
    if(EXISTS "${_f}")
        file(READ "${_f}" _t)
        string(FIND "${_t}" "${_begin}" _b)
        if(_b GREATER -1)
            string(FIND "${_t}" "${_end}" _e)
            string(LENGTH "${_end}" _endlen)
            math(EXPR _e2 "${_e} + ${_endlen}")
            string(LENGTH "${_t}" _len)
            string(SUBSTRING "${_t}" 0 "${_b}" _o1)
            string(SUBSTRING "${_t}" "${_e2}" "${_len}" _o2)
            set(_others "${_o1}${_o2}")
        else()
            set(_others "${_t}")
        endif()
    endif()
    _polyorch_vscode_dedup_rows("${_launch}" "name" "${_others}" _launch)
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
                    "-- writing an empty ${_tid} region (the debug gate is OFF; preset "
                    "switched? reconfigure with the debug knob family to restore F5)")
            endif()
        endif()
    endif()
    _polyorch_vscode_region_write("${_f}" "${_begin}" "${_end}" "${_launch}"
        "{\n    \"version\": \"0.2.0\",\n    \"configurations\": [\n%ROWS%\n    ]\n}"
        _st)
    # tasks.json: rust+node rows merged (python needs no preLaunchTask).
    # The tasks BEGIN text is the FROZEN rust-worded string (see header) --
    # the tree id slots in after "BEGIN__"; the legacy markerless form is
    # re-titled exactly like launch.json above.
    if(_tasks)
        set(_tbegin "// __POLYORCH_GENERATED_BEGIN__ ${_tid} (PolyOrch rust build tasks; keep this block last, regenerate via reconfigure)")
        set(_tf "${_dir}/tasks.json")
        if(EXISTS "${_tf}")
            file(READ "${_tf}" _tt)
            string(REGEX MATCH "// __POLYORCH_GENERATED_BEGIN__ \\(" _lg2 "${_tt}")
            if(_lg2)
                string(REPLACE "${_lg2}"
                    "// __POLYORCH_GENERATED_BEGIN__ ${_tid} (PolyOrch rust build tasks; keep this block last, regenerate via reconfigure)"
                    _tt "${_tt}")
                file(WRITE "${_tf}" "${_tt}")
            endif()
        endif()
        set(_tothers "")
        if(EXISTS "${_tf}")
            file(READ "${_tf}" _tt)
            string(FIND "${_tt}" "${_tbegin}" _b)
            if(_b GREATER -1)
                string(FIND "${_tt}" "${_end}" _e)
                string(LENGTH "${_end}" _endlen)
                math(EXPR _e2 "${_e} + ${_endlen}")
                string(LENGTH "${_tt}" _len)
                string(SUBSTRING "${_tt}" 0 "${_b}" _o1)
                string(SUBSTRING "${_tt}" "${_e2}" "${_len}" _o2)
                set(_tothers "${_o1}${_o2}")
            else()
                set(_tothers "${_tt}")
            endif()
        endif()
        _polyorch_vscode_dedup_rows("${_tasks}" "label" "${_tothers}" _tasks)
        set(_st2 "")
        _polyorch_vscode_region_write("${_tf}"
            "${_tbegin}"
            "${_end}"
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
        "PolyOrch: debug configs -> ${_dir} at ${_ts} tree ${_tid} "
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
