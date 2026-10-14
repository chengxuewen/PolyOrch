# _polyorch_vscode_debug_gate(FACE OUT) -- the read-time gate for the
# VSCode debug knob family (T-H7; ALL flipped to BOOLEAN per user
# adjudication 2026-10-14, the octk_option OR_CONDITION semantics).
#
# Family (namespace order: FEATURE_FACE, ALL boolean):
#   PolyOrch_VSCODE_DEBUG_ALL      composite, BOOL cache, default OFF
#                                  (declared in PolyOrchVSCodeDebugHelpers.cmake)
#   PolyOrch_VSCODE_DEBUG_<FACE>   per-face, option cache, default OFF
#                                  (FACES: RUST | NODE | PYTHON | NATIVE -- native is the
#                                  T-H8 c/cpp/qt CodeLLDB face; no legacy name exists)
#
# Semantics (pure OR):
#   ALL=ON              -> every face ON (the composite switch wins)
#   ALL=OFF/unset       -> the face knob rules
#   legacy name (one transition cycle) -> honored when the new knob is
#   unset; BOTH the new knob and the legacy name set -> FATAL (ambiguity
#   is loud). The legacy reads die via the T-H7 removal contract (the
#   consumer status.md Open Items gate: zero grep hits + one minor
#   cycle).
#
# WHY NOT A FULL octk_option PORT: the six keywords (DEPENDS/EMIT_IF/
# SET/VERIFY/INPUT_) have zero consumers across PolyOrch's eight flat
# knobs -- the house precedent is D9 (generate from the authority when
# needed, not port a drifted copy) and D31 (unconsumed surfaces retire).
# EXTRACTION ROADMAP: when a real DEPENDS/EMIT_IF need materializes,
# lift octk_evaluate_expression standalone from the corpus anchor
# (.refinfo/OpenCTK/cmake/OpenCTKOptionHelpers.cmake:40) -- the single
# function is self-contained.
#
# READ-TIME FORM (Momus, the add_subdirectory trap): called at EVERY
# consumption point; reads only cache-visible variables (a directory-
# scope set() inside PolyOrch's option blocks never propagates up past
# the embed boundary).

function(_polyorch_vscode_debug_gate FACE OUT)
    string(TOUPPER "${FACE}" _face)
    if(NOT _face MATCHES "^(RUST|NODE|PYTHON|NATIVE)$")
        message(FATAL_ERROR
            "_polyorch_vscode_debug_gate: unknown face '${FACE}' "
            "(RUST | NODE | PYTHON | NATIVE)")
    endif()

    # the composite switch: ON forces every face
    if(PolyOrch_VSCODE_DEBUG_ALL)
        set(${OUT} ON PARENT_SCOPE)
        return()
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
        set(_legacy_on "${${_legacy}}")
        if(_legacy_on)
            if("${${_new}}")
                message(FATAL_ERROR
                    "Both ${_new} and ${_legacy} are set -- the knob "
                    "family renamed (T-H7); keep only the new name.")
            endif()
            set(${OUT} ON PARENT_SCOPE)
            return()
        endif()
    endif()

    if(${${_new}})
        set(${OUT} ON PARENT_SCOPE)
    else()
        set(${OUT} OFF PARENT_SCOPE)
    endif()
endfunction()
