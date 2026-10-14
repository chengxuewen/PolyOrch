# _polyorch_vscode_debug_gate(FACE) -> sets <OUT_VAR> to ON/OFF
# (the read-time gate for the VSCode debug knob family, T-H7).
#
# Family (namespace order: FEATURE_FACE):
#   PolyOrch_VSCODE_DEBUG_ALL      composite, STRING cache, default ""
#   PolyOrch_VSCODE_DEBUG_<FACE>   per-face, option cache, default OFF
#
# Semantics (dictator form, user-adjudicated 2026-10-14):
#   ALL == ""     -> the face knob rules (backward-compatible world)
#   ALL == RUST | NODE | PYTHON -> exactly that face ON, others OFF
#   ALL == ALL    -> every face ON
#   other ALL     -> FATAL (the typo dies at configure)
#   BOTH the new face knob and its legacy name set -> FATAL (ambiguity
#   is loud; two sources of truth for a debug gate is debugging hell)
#
# Legacy transition (the VSCODE_DIR absorption is the house style):
#   PolyOrch_RUST_VSCODE_DEBUG / PolyOrch_NODE_VSCODE_DEBUG /
#   PolyOrch_PYTHON_VSCODE_DEBUG are honored ONE cycle when their new
#   name is unset (one-shot STATUS), removed by the T-H7 removal gate
#   (.agents/memorys/status.md, the consumer repo's copy is the
#   sibling checkout's status.md -- zero grep hits + one minor cycle).
#
# READ-TIME FORM (Momus, the add_subdirectory trap): this function is
# called at EVERY consumption point and reads only cache-visible
# variables -- a directory-scope set() inside PolyOrch's option blocks
# never propagates up to a host's root scope, so the gate must not
# write; it evaluates. ALL is a cache STRING, the face knobs are
# option caches: both resolve identically from any scope.

function(_polyorch_vscode_debug_gate FACE OUT)
    string(TOUPPER "${FACE}" _face)
    if(NOT _face MATCHES "^(RUST|NODE|PYTHON)$")
        message(FATAL_ERROR
            "_polyorch_vscode_debug_gate: unknown face '${FACE}' "
            "(RUST | NODE | PYTHON)")
    endif()

    # the composite knob: dictator when non-empty
    if(PolyOrch_VSCODE_DEBUG_ALL)
        if(PolyOrch_VSCODE_DEBUG_ALL STREQUAL "ALL")
            set(${OUT} ON PARENT_SCOPE)
            return()
        elseif(PolyOrch_VSCODE_DEBUG_ALL STREQUAL _face)
            set(${OUT} ON PARENT_SCOPE)
            return()
        elseif(PolyOrch_VSCODE_DEBUG_ALL MATCHES "^(RUST|NODE|PYTHON)$")
            # a REAL face value, just not this face
            set(${OUT} OFF PARENT_SCOPE)
            return()
        else()
            message(FATAL_ERROR
                "PolyOrch_VSCODE_DEBUG_ALL: '${PolyOrch_VSCODE_DEBUG_ALL}' "
                "is not one of \"\" | RUST | NODE | PYTHON | ALL")
        endif()
    endif()

    # legacy names, one transition cycle
    set(_legacy "")
    if(_face STREQUAL "RUST" AND DEFINED PolyOrch_RUST_VSCODE_DEBUG)
        set(_legacy PolyOrch_RUST_VSCODE_DEBUG)
    elseif(_face STREQUAL "NODE" AND DEFINED PolyOrch_NODE_VSCODE_DEBUG)
        set(_legacy PolyOrch_NODE_VSCODE_DEBUG)
    elseif(_face STREQUAL "PYTHON" AND DEFINED PolyOrch_PYTHON_VSCODE_DEBUG)
        set(_legacy PolyOrch_PYTHON_VSCODE_DEBUG)
    endif()
    set(_new "PolyOrch_VSCODE_DEBUG_${_face}")
    if(_legacy)
        # DEFINED is true for an option's default too; "the caller set it"
        # = the value differs from OFF-or-empty (an explicit OFF matches
        # the new default and needs no transition path)
        set(_legacy_on "${${_legacy}}")
        if(_legacy_on)
            if("${${_new}}")
                message(FATAL_ERROR
                    "Both ${_new} and ${_legacy} are set -- the knob "
                    "family renamed (T-H7); keep only the new name.")
            endif()
            set(${OUT} "${_legacy_on}" PARENT_SCOPE)
            return()
        endif()
    endif()

    if(${${_new}})
        set(${OUT} ON PARENT_SCOPE)
    else()
        set(${OUT} OFF PARENT_SCOPE)
    endif()
endfunction()
