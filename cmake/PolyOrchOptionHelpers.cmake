
include_guard(GLOBAL)  # 2026-10-10 embed ruling: idempotent same-path re-include

function(polyorch_parse_all_arguments prefix type options one_value_args multi_value_args)
    # Mirrors polyorch macro: (result type options oneValueArgs multiValueArgs)
    cmake_parse_arguments(${prefix} "${options}" "${one_value_args}" "${multi_value_args}" ${ARGN})
    set(${prefix}_UNPARSED_ARGUMENTS "${${prefix}_UNPARSED_ARGUMENTS}" PARENT_SCOPE)
    foreach(option ${options})
        set(${prefix}_${option} "${${prefix}_${option}}" PARENT_SCOPE)
    endforeach()
    foreach(multi_option ${multi_value_args})
        set(${prefix}_${multi_option} "${${prefix}_${multi_option}}" PARENT_SCOPE)
    endforeach()
    foreach(single_option ${one_value_args})
        set(${prefix}_${single_option} "${${prefix}_${single_option}}" PARENT_SCOPE)
    endforeach()
endfunction()


# polyorch_option(variable description value [OR_CONDITION <var>])
#
# The thin declaration sugar (the octk_option OR row only -- the other
# five keywords have no consumers; see _polyorch_vscode_debug_gate.cmake
# for the extraction roadmap). OR_CONDITION is DECLARATION DOCUMENTATION
# plus a directory-scope courtesy ON: the authoritative read is always
# the read-time gate (a set() here never propagates past the embed
# boundary -- Momus, T-H7).
function(polyorch_option variable description value)
    cmake_parse_arguments(PO "" "OR_CONDITION" "" ${ARGN})
    if(PO_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR
            "polyorch_option: unsupported keywords: ${PO_UNPARSED_ARGUMENTS} "
            "(the extraction roadmap lives in _polyorch_vscode_debug_gate.cmake)")
    endif()
    option(${variable} "${description}" ${value})
    if(PO_OR_CONDITION AND "${${PO_OR_CONDITION}}")
        set(${variable} ON PARENT_SCOPE)
    endif()
endfunction()
