# D39 reuse-mode premise: a FOREIGN bare sentinel (same-named target, no
# properties, no modules) is cleanly detectable -- the root's first-wins guard
# skips the copy and the properties read NOTFOUND, which is exactly what a host
# shim's fallback branch must probe (tutorials 5.1). Child superbuild supplies
# the CXX identity; parent relays output for the drivers' expect-log.
# expect-log PASS-FOREIGN
cmake_policy(SET CMP0219 NEW)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")

_polyorch_pixi_scratch(_s)
set(_h "${_s}/embed-foreign")
file(MAKE_DIRECTORY "${_h}")
set(_po "${CMAKE_CURRENT_LIST_DIR}/../..")
file(WRITE "${_h}/CMakeLists.txt"
"cmake_minimum_required(VERSION 3.25)\n"
"project(embed-foreign LANGUAGES CXX)\n"
"# the foreign supplier: a bare sentinel registered BEFORE PolyOrch's dir\n"
"add_library(PolyOrch::PolyOrch INTERFACE IMPORTED GLOBAL)\n"
"set(_po \"${_po}\")\n"
"add_subdirectory(\${_po} _po1)\n"
"# the root skipped itself; the foreign sentinel still answers the probe\n"
"get_target_property(_d PolyOrch::PolyOrch INTERFACE_POLYORCH_CMAKE_DIR)\n"
"get_target_property(_v PolyOrch::PolyOrch INTERFACE_POLYORCH_VERSION)\n"
"if(NOT _d)\n"
"    message(STATUS \"PASS-FOREIGN dir-NOTFOUND clean\")\n"
"elseif(NOT _v)\n"
"    message(STATUS \"PASS-FOREIGN version-NOTFOUND clean\")\n"
"else()\n"
"    message(FATAL_ERROR \"unexpected: foreign sentinel carries properties \${_d} \${_v}\")\n"
"endif()\n"
"# and NO polyorch command leaked from the skipped copy\n"
"if(COMMAND polyorch_rust_build)\n"
"    message(FATAL_ERROR \"skipped copy leaked commands\")\n"
"endif()\n")

execute_process(
    COMMAND "${CMAKE_COMMAND}" -S "${_h}" -B "${_h}/b"
    RESULT_VARIABLE _rc
    OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
message("${_out}${_err}")
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "embed-foreign configure failed rc=${_rc}")
endif()
if(NOT _out MATCHES "PASS-FOREIGN")
    message(FATAL_ERROR "foreign-sentinel leg did not pass")
endif()
