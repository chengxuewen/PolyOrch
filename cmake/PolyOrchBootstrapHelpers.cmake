# ===========================================================================
# PolyOrchBootstrapHelpers -- configure-failure bootstrap guidance (D48).
#
# CMake Tools opens a workspace with ITS OWN cmake (desktop PATH) while the
# dev toolchain (cargo/rustc) lives in a pixi env: the first configure then
# dies in polyorch_rust_setup and NO success-path generator can ever fire
# (the settings file that would fix the failure is an INPUT to configure --
# the chicken-and-egg loop, C″ in the ide-bootstrap plan).
#
# polyorch_bootstrap_hint breaks the loop from the failure side: when a
# candidate cmake (typically the workspace pixi env's) exists and differs
# from the currently running CMAKE_COMMAND, write the workspace settings
# file synchronously (cmake_language(DEFER) never executes on a FATAL path
# -- measured) and print a two-step guidance block. The second configure
# then succeeds for a structural reason, not luck: find_program searches
# the cmake binary's OWN bin/ directory, so the pixi cmake finds its
# sibling cargo even under a stripped desktop PATH (lead A/B measurement
# 2026-10-26, B1). Settings contract reuses the VSCodeDebugHelpers managed
# region (user content above the BEGIN marker is never rewritten; a
# markerless pre-existing file is parked beside as .polyorch-new).
#
# Trigger discipline: this face NEVER fires when the workspace configures
# fine on the current toolchain -- the trigger itself is the "wrong line
# was picked" detector (the ide-bootstrap plan's failure-driven-correction
# posture). Everything English (consumer C51).
# ===========================================================================

include_guard(GLOBAL)

# Same directory knob as the debug face (empty = <CMAKE_SOURCE_DIR>/.vscode).
# Declared here too (include order varies by consumer); the debug module's
# cache declaration wins when both ran (same type+docstring = no churn).
set(PolyOrch_VSCODE_DIR "" CACHE PATH
    "Directory for generated .vscode files (empty = <CMAKE_SOURCE_DIR>/.vscode)")

# _polyorch_bootstrap_region_write -- synchronous twin of
# _polyorch_vscode_region_write (PolyOrchVSCodeDebugHelpers), copied verbatim
# and renamed: this module must stay self-contained (no include-chain drag),
# and the debug face's writer must not be INVOKED from here -- only its
# marker-pair SHAPE is shared (M1/M3). Keep the two bodies byte-equal except
# for the name. Out-var: CREATED | REPLACED | PLACED_NEW.
function(_polyorch_bootstrap_region_write FILE BEGIN END ROWS SHELL OUT)
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

function(polyorch_bootstrap_hint)
    cmake_parse_arguments(PARSE_ARGV 0 BH "" "CANDIDATE_CMAKE;SOURCE_HINT" "")
    if(NOT BH_CANDIDATE_CMAKE)
        message(FATAL_ERROR
            "polyorch_bootstrap_hint: CANDIDATE_CMAKE is required")
    endif()

    if(EXISTS "${BH_CANDIDATE_CMAKE}"
            AND NOT CMAKE_COMMAND STREQUAL BH_CANDIDATE_CMAKE)
        # candidate paths (may be relative): normalize for display + write.
        get_filename_component(_bh_cand "${BH_CANDIDATE_CMAKE}" ABSOLUTE)

        # settings target: PolyOrch_VSCODE_DIR overrides (caller-scope normal
        # variable: read via DEFINED so a plain set() from the caller wins --
        # function scope sees caller locals; the debug face's CACHE-only
        # semantics do not apply to this knob), else the source root's
        # .vscode (the workspace the IDE opened).
        set(_bh_dir "")
        if(DEFINED PolyOrch_VSCODE_DIR AND NOT "${PolyOrch_VSCODE_DIR}" STREQUAL "")
            set(_bh_dir "${PolyOrch_VSCODE_DIR}")
        endif()
        if(NOT _bh_dir)
            set(_bh_dir "${CMAKE_SOURCE_DIR}/.vscode")
        endif()
        set(_bh_file "${_bh_dir}/settings.json")

        # relative path from the source root to the candidate -> the written
        # row carries the ${workspaceFolder} LITERAL (never an absolute path:
        # settings.json can end up in the repo, and a machine-specific path
        # would be the pointing-at-air failure all over again).
        file(RELATIVE_PATH _bh_rel "${CMAKE_SOURCE_DIR}" "${_bh_cand}")
        if(_bh_rel MATCHES "^\\.\\.")
            # candidate outside the workspace: fall back to the absolute path
            # (still portable via the literal prefix rule below, which now
            # cannot apply; portability is the workspace-relative case).
            set(_bh_row "\"cmake.cmakePath\": \"${_bh_cand}\"")
        else()
            set(_bh_row
                "\"cmake.cmakePath\": \"\${workspaceFolder}/${_bh_rel}\"")
        endif()

        set(_bh_begin "// __POLYORCH_GENERATED_BEGIN__ (PolyOrch bootstrap cmake path; keep this block last, regenerate via reconfigure)")
        set(_bh_end   "// __POLYORCH_GENERATED_END__")
        # object-form SHELL: rows are comma-terminated key/value pairs
        # (VSCode JSONC tolerates trailing commas in objects, same as arrays).
        # single string, not a list: a set() with two args joins on ";"
        # at expansion and the separator lands in the written file (measured).
        set(_bh_rows "    ${_bh_row},\n")
        string(APPEND _bh_rows "    \"cmake.configureOnOpen\": true,\n")
        # cmake.environment PATH prepend (D49 companion): configure-side
        # find_program gets the sibling hit, but BUILD-stage cargo children
        # (rustc, and bindgen's libclang probe) resolve via PATH/LIBCLANG_PATH
        # -- the env block covers both faces from the IDE surface. The bin
        # dir is derived from the already-computed relative candidate path
        # (filename dropped), and LIBCLANG_PATH points at the env's lib/
        # sibling of that bin dir (bindgen's probe target).
        get_filename_component(_bh_bindir "${_bh_cand}" DIRECTORY)
        file(RELATIVE_PATH _bh_bindir_rel "${CMAKE_SOURCE_DIR}" "${_bh_bindir}")
        set(_bh_env_path "${_bh_bindir_rel}")
        set(_bh_env_lib "${_bh_bindir_rel}/../lib")
        if(_bh_bindir_rel MATCHES "^[.][.]")
            # out-of-workspace candidate: absolute forms (workspaceFolder
            # cannot express outside paths)
            set(_bh_env_path "${_bh_bindir}")
            set(_bh_env_lib "${_bh_bindir}/../lib")
        endif()
        set(_bh_dollar "$")
        set(_bh_rows_all
            "    \"cmake.environment\": {\n"
            "        \"PATH\": \"\${workspaceFolder}/${_bh_env_path}:${_bh_dollar}{env:PATH}\",\n"
            "        \"LIBCLANG_PATH\": \"\${workspaceFolder}/${_bh_env_lib}\"\n"
            "    },\n")
        if(_bh_bindir_rel MATCHES "^[.][.]")
            set(_bh_rows_all
                "    \"cmake.environment\": {\n"
                "        \"PATH\": \"${_bh_env_path}:${_bh_dollar}{env:PATH}\",\n"
                "        \"LIBCLANG_PATH\": \"${_bh_env_lib}\"\n"
                "    },\n")
        endif()
        string(APPEND _bh_rows "${_bh_rows_all}")
        _polyorch_bootstrap_region_write("${_bh_file}"
            "${_bh_begin}" "${_bh_end}" "${_bh_rows}"
            "{\n%ROWS%\n}" _bh_st)

        if(_bh_st STREQUAL "PLACED_NEW")
            set(_bh_note
                "   (an existing settings.json had no PolyOrch managed region; "
                "the generated document was parked beside it as settings.json.polyorch-new "
                "-- merge manually, the original was NOT touched)")
        elseif(_bh_st STREQUAL "REPLACED")
            set(_bh_note "(managed region updated in the existing settings.json)")
        else()
            set(_bh_note "(created)")
        endif()

        message(STATUS
            "polyorch_bootstrap_hint: wrote ${_bh_file} ${_bh_note}")

        message(WARNING
"=====================================================================
This configure ran with cmake: ${CMAKE_COMMAND}
but this workspace's toolchain cmake is: ${_bh_cand}
${BH_SOURCE_HINT}
A bootstrap settings file has been written for you:
  ${_bh_file}
  -> sets cmake.cmakePath to \${workspaceFolder}/${_bh_rel}
Finish in TWO steps:
  1. Run the command 'CMake: Delete Cache and Reconfigure'
     (or reload the VS Code window, then reconfigure).
  2. The reconfigure will run the toolchain cmake, which finds its
     sibling cargo automatically (a cmake binary always searches its
     own bin/ directory first).
No further action is needed after the reconfigure turns green.
=====================================================================")
    elseif(NOT EXISTS "${BH_CANDIDATE_CMAKE}")
        # Candidate absent = the pixi env itself is missing (fresh clone
        # before msrtc.sh init): write nothing, point at the bootstrap.
        message(WARNING
"=====================================================================
No toolchain cmake found at: ${BH_CANDIDATE_CMAKE}
${BH_SOURCE_HINT}
This workspace needs its dev environment bootstrapped first.
Fix: run the workspace bootstrap (parent shell: ./msrtc.sh init,
or 'git submodule update --init --recursive' + the environment
bootstrap script) so the pixi environment materializes, then
reconfigure.
=====================================================================")
    endif()
    # candidate exists AND equals CMAKE_COMMAND: the running cmake IS the
    # toolchain cmake -- a caller invoking the hint from that side gets
    # silence (never a self-referential guidance loop).
endfunction()
