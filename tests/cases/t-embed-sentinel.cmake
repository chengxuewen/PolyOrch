# D39 embed contract: the root delivers the COMPLETE face set and a sentinel
# carrying INTERFACE_POLYORCH_CMAKE_DIR/VERSION; a second add is a STATUS skip.
# Two-layer harness: a -P parent cannot add_subdirectory (not scriptable), so
# the parent spawns a child superbuild (project LANGUAGES CXX supplies the CXX
# identity PlatformSupport's mkspec probe needs) and relays its output -- the
# drivers grep PARENT output for expect-log. No capability requirement: the
# child needs no tools beyond cmake itself (faces are function definitions).
# expect-log PASS-PROPERTIES
# expect-log PolyOrch: sentinel already registered
cmake_policy(SET CMP0219 NEW)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")

_polyorch_pixi_scratch(_s)
set(_h "${_s}/embed-host")
file(MAKE_DIRECTORY "${_h}")
set(_po "${CMAKE_CURRENT_LIST_DIR}/../..")
file(WRITE "${_h}/CMakeLists.txt"
"cmake_minimum_required(VERSION 3.25)\n"
"project(embed-host LANGUAGES CXX)\n"
"set(_po \"${_po}\")\n"
"add_subdirectory(\${_po} _po1)\n"
"# complete face set: every polyorch_* command a host shim would probe\n"
"foreach(_c polyorch_option polyorch_ensure_define_variable polyorch_set01\n"
"           polyorch_rust_build polyorch_pixi_setup polyorch_node_debug\n"
"           polyorch_node_setup polyorch_python_setup polyorch_python_run)\n"
"    if(NOT COMMAND \${_c})\n"
"        message(FATAL_ERROR \"MISSING command: \${_c}\")\n"
"    endif()\n"
"endforeach()\n"
"# sentinel carries the winning copy's location + version\n"
"get_target_property(_d PolyOrch::PolyOrch INTERFACE_POLYORCH_CMAKE_DIR)\n"
"get_target_property(_v PolyOrch::PolyOrch INTERFACE_POLYORCH_VERSION)\n"
"if(NOT _v STREQUAL \"0.7.0\")\n"
"    message(FATAL_ERROR \"version property wrong: \${_v}\")\n"
"endif()\n"
"get_filename_component(_po_real \"${_po}\" ABSOLUTE)\n"
"if(NOT _d STREQUAL \"\${_po_real}/cmake\")\n"
"    message(FATAL_ERROR \"dir property wrong: \${_d}\")\n"
"endif()\n"
"message(STATUS \"PASS-PROPERTIES \${_d} \${_v}\")\n"
"# first-wins: the second add prints the STATUS skip and returns\n"
"add_subdirectory(\${_po} _po2)\n"
"message(STATUS \"PASS-SECOND-ADD\")\n")

execute_process(
    COMMAND "${CMAKE_COMMAND}" -S "${_h}" -B "${_h}/b"
    RESULT_VARIABLE _rc
    OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
message("${_out}${_err}")
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "embed-host configure failed rc=${_rc}")
endif()
if(NOT _out MATCHES "PASS-PROPERTIES")
    message(FATAL_ERROR "properties leg did not pass")
endif()
if(NOT _out MATCHES "sentinel already registered")
    message(FATAL_ERROR "second-add skip line absent")
endif()
if(_out MATCHES ": SKIP \\(")
    message(FATAL_ERROR "self-lock veto: STATUS wording collides with the skip contract")
endif()
