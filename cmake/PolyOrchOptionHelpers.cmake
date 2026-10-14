# PolyOrchOptionHelpers.cmake -- the option declaration surface.
#
# polyorch_option: the full octk_option semantics port (OpenCTK's
# cmake/OpenCTKOptionHelpers.cmake, user-adjudicated full port after
# the thin-sugar version bit us -- the OR_CONDITION FORCE half-skip
# produced a cache that SHOWED OFF while the gate behaved ON; display
# and effect must never diverge). Keywords:
#
#   DEPENDS <expr>          the option lives only when expr holds;
#                           otherwise forced OFF STRING with a marker
#                           suffix + WARNING when the default would
#                           have been ON
#   EMIT_IF <expr>          when false: a user-provided value warns
#                           (the option is not emitted)
#   OR_CONDITION <expr>     when true: the option is forced ON (cache
#                           FORCE -- display = effect)
#   SET <vars>...           mirror the option's value into vars
#   SET_NEGATE <vars>...    mirror the inverted value into vars
#   VERIFY <expr>           checked at declaration: a false VERIFY is a
#                           FATAL (octk's doc comment lists the keyword
#                           but its body never consumed it -- the port
#                           makes it real)
#
# Expressions: NOT / AND / OR / parentheses / STREQUAL 'quoted' /
# EXISTS / TARGET, evaluated by _polyorch_evaluate_expression (the
# octk_evaluate_expression semantics port, short-circuiting).
#
# The INPUT_<variable> environment override rides along (the octk
# mechanism): INPUT_<var>=ON/OFF wins over everything but is itself
# subject to EMIT_IF/DEPENDS.

include_guard(GLOBAL)

# _polyorch_evaluate_to_boolean(var): normalize a truthy/falsy value in
# var to ON/OFF in the PARENT_SCOPE.
function(_polyorch_evaluate_to_boolean expression_var)
    if(${${expression_var}})
        set(${expression_var} ON PARENT_SCOPE)
    else()
        set(${expression_var} OFF PARENT_SCOPE)
    endif()
endfunction()

# _polyorch_evaluate_expression(<result_var> [expression ...])
# The octk_evaluate_expression semantics: a whitespace-separated token
# stream evaluated left-to-right with short-circuit AND/OR, parentheses
# grouping, NOT, EXISTS <path>, TARGET <name>, and STREQUAL 'lhs' 'rhs'
# (single-quoted operands compare as strings; bare operands resolve as
# variable names first, then literals). An empty final result means ON
# (octk: an expression that consumed everything truthy-ly is ON).
function(_polyorch_evaluate_expression result_var)
    set(result "")
    set(nesting_level 0)
    set(skip_next OFF)
    set(expression "${ARGN}")
    list(LENGTH expression length)

    if(0 EQUAL length)
        message(FATAL_ERROR "_polyorch_evaluate_expression: expression cannot be empty")
    elseif(1 EQUAL length)
        set(result ${expression})
    else()
        math(EXPR last_index "${length} - 1")
        foreach(member_index RANGE ${last_index})
            if(${skip_next})
                set(skip_next OFF)
                continue()
            endif()

            list(GET expression ${member_index} member)
            if("${member}" STREQUAL "(")
                if(${nesting_level} GREATER 0)
                    list(APPEND result ${member})
                endif()
                math(EXPR nesting_level "${nesting_level} + 1")
                continue()
            elseif("${member}" STREQUAL ")")
                math(EXPR nesting_level "${nesting_level} - 1")
                if(nesting_level LESS 0)
                    break()
                endif()
                if(${nesting_level} EQUAL 0)
                    _polyorch_evaluate_expression(result ${result})
                else()
                    list(APPEND result ${member})
                endif()
                continue()
            elseif(${nesting_level} GREATER 0)
                list(APPEND result ${member})
                continue()
            elseif("${member}" STREQUAL "NOT")
                list(APPEND result ${member})
                continue()
            elseif("${member}" STREQUAL "EXISTS")
                math(EXPR next_index "${member_index} + 1")
                list(GET expression ${next_index} next_member)
                list(APPEND result EXISTS "${next_member}")
                set(skip_next ON)
                continue()
            elseif("${member}" STREQUAL "TARGET")
                math(EXPR next_index "${member_index} + 1")
                list(GET expression ${next_index} next_member)
                list(APPEND result TARGET "${next_member}")
                set(skip_next ON)
                continue()
            elseif("${member}" STREQUAL "AND")
                _polyorch_evaluate_to_boolean(result)
                if(NOT ${result})
                    break()
                endif()
                set(result "")
            elseif("${member}" STREQUAL "OR")
                _polyorch_evaluate_to_boolean(result)
                if(${result})
                    break()
                endif()
                set(result "")
            elseif("${member}" STREQUAL "STREQUAL")
                # if() STREQUAL semantics break when the RHS is an empty
                # string arriving through a variable -- octk's convention:
                # quote the empty operand with single quotes, compare here.
                list(LENGTH result lhsIndex)
                math(EXPR lhsIndex "${lhsIndex}-1")
                list(GET result ${lhsIndex} lhs)
                list(REMOVE_AT result ${lhsIndex})
                set(lhs "${${lhs}}")

                math(EXPR rhsIndex "${member_index}+1")
                set(rhs "")
                list(GET expression ${rhsIndex} rhs)
                set(skip_next ON)

                string(REGEX REPLACE "'(.*)'" "\\1" lhs "${lhs}")
                string(REGEX REPLACE "'(.*)'" "\\1" rhs "${rhs}")

                string(COMPARE EQUAL "${lhs}" "${rhs}" string_compare_result)
                list(APPEND result ${string_compare_result})
            else()
                if(DEFINED "${member}")
                    list(APPEND result ${member})
                endif()
            endif()
        endforeach()
    endif()

    if("${result}" STREQUAL "")
        set(result ON)
    else()
        _polyorch_evaluate_to_boolean(result)
    endif()

    set(${result_var} ${result} PARENT_SCOPE)
endfunction()

# _polyorch_parse_all_arguments: cmake_parse_arguments + unknown-keyword
# FATAL (the octk_parse_all_arguments semantics; a macro so the parsed
# prefix vars land in the CALLER's scope).
macro(_polyorch_parse_all_arguments result type options oneValueArgs multiValueArgs)
    cmake_parse_arguments(${result} "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    if(DEFINED ${result}_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR
            "Unknown arguments were passed to ${type} (${${result}_UNPARSED_ARGUMENTS}).")
    endif()
endmacro()

function(polyorch_option variable description value)
    _polyorch_parse_all_arguments(arg polyorch_option
        "" ""
        "DEPENDS;EMIT_IF;SET;SET_NEGATE;OR_CONDITION;VERIFY" ${ARGN})

    _polyorch_evaluate_expression(result ${value})

    if("${arg_EMIT_IF}" STREQUAL "")
        set(emit_if ON)
    else()
        _polyorch_evaluate_expression(emit_if ${arg_EMIT_IF})
    endif()

    if("${arg_OR_CONDITION}" STREQUAL "")
        set(or_condition OFF)
    else()
        _polyorch_evaluate_expression(or_condition ${arg_OR_CONDITION})
    endif()

    # VERIFY: the declaration-time contract (the octk doc comment lists
    # the keyword; its body never consumed it -- the port makes it real:
    # a declaration that contradicts its own precondition must not
    # configure).
    if(NOT "${arg_VERIFY}" STREQUAL "")
        _polyorch_evaluate_expression(verify_ok ${arg_VERIFY})
        if(NOT verify_ok)
            message(FATAL_ERROR
                "polyorch_option(${variable}): VERIFY failed (${arg_VERIFY})")
        endif()
    endif()

    set(input OFF)
    # INPUT_<variable>: the environment-style override (the octk
    # mechanism) -- a non-empty, non-"undefined" INPUT_ var wins.
    if((DEFINED "INPUT_${variable}")
            AND (NOT "${INPUT_${variable}}" STREQUAL "undefined")
            AND (NOT "${INPUT_${variable}}" STREQUAL ""))
        set(input ON)
        if(INPUT_${variable})
            set(input_result ON)
        else()
            set(input_result OFF)
        endif()
    elseif(or_condition)
        set(input ON)
        set(input_result ON)
    endif()

    # a value provided for an option that is not emitted: warn (the octk
    # contract) -- the user typed a -D the system asked them not to.
    if(input)
        if(emit_if)
            set(result ${input_result})
        else()
            message(WARNING
                "Option ${variable} is not emitted, but the user explicitly provided a value for it.")
        endif()
    endif()

    # DEPENDS: the option lives only while the expression holds
    if("${arg_DEPENDS}" STREQUAL "")
        set(depends_result ON)
    else()
        _polyorch_evaluate_expression(depends_result ${arg_DEPENDS})
    endif()

    if(${depends_result})
        if(input AND emit_if)
            # the effective value is authoritative: the cache SHOWS it
            # (the thin-sugar lesson -- display must never diverge from
            # effect; STRING type = the "forced" marker shape)
            unset(${variable} CACHE)
            set(${variable} "${result}" CACHE STRING "${description}" FORCE)
            set(_polyorch_option_string_type_cache_${variable} ON CACHE INTERNAL "${description}" FORCE)
        else()
            if(${_polyorch_option_string_type_cache_${variable}})
                unset(${variable} CACHE)
            endif()
            set(${variable} ${result} CACHE BOOL "${description}")
            set(_polyorch_option_string_type_cache_${variable} OFF CACHE INTERNAL "${description}" FORCE)
        endif()
    else()
        if(${result})
            message(WARNING
                "Option ${variable} is depends on ${arg_DEPENDS}.")
        endif()
        set(${variable} "OFF" CACHE STRING "${description} depends on ${arg_DEPENDS}!" FORCE)
        set(_polyorch_option_string_type_cache_${variable} ON CACHE INTERNAL "${description}" FORCE)
    endif()

    foreach(set ${arg_SET})
        if(${${variable}})
            set(${set} ON PARENT_SCOPE)
        else()
            set(${set} OFF PARENT_SCOPE)
        endif()
    endforeach()

    foreach(set ${arg_SET_NEGATE})
        if(${${variable}})
            set(${set} OFF PARENT_SCOPE)
        else()
            set(${set} ON PARENT_SCOPE)
        endif()
    endforeach()
endfunction()
