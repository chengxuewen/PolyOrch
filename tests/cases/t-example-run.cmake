# requires: sh
# t-example-run -- polyorch_example_run surface: button table (name,
# COMMAND argv shape), GUI probe chain embedded (display vars + X socket
# glob + argv forwarding), FOLDER default, unknown-arg / bad-target
# guards, and the no-GUI bare-exec form.
cmake_policy(SET CMP0219 NEW)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")
_polyorch_pixi_scratch(_s)
set(_b "${_s}/example-run")

file(WRITE "${_s}/proj/CMakeLists.txt" [=[
cmake_minimum_required(VERSION 3.25)
project(exrun NONE)
include("${POLYORCH_CMAKE_DIR}/PolyOrchExampleRunHelpers.cmake")

foreach(_n app_plain app_gui app_deffold)
    add_executable(${_n} IMPORTED)
    set_target_properties(${_n} PROPERTIES IMPORTED_LOCATION "/bin/echo")
endforeach()

# no-GUI form: bare exec, args forwarded as a list
polyorch_example_run(TARGET app_plain ARGS "--frames;3" FOLDER "examples/c")

# GUI form: the probe chain rides the COMMAND
polyorch_example_run(TARGET app_gui GUI FOLDER "examples/c")

# default FOLDER falls back to the caller's relative dir
polyorch_example_run(TARGET app_deffold ARGS "x")
]=])

set(RUN_OUT "${_s}/run.out")
set(_cmd_dir "${CMAKE_CURRENT_LIST_DIR}/../../cmake")
# PIT (this round): a MID-argument quote (-DVAR="${dir}") survives as a
# literal quote in execute_process argv -- quote the WHOLE -D argument.
execute_process(COMMAND ${CMAKE_COMMAND}
    -S "${_s}/proj" -B "${_b}"
    "-DPOLYORCH_CMAKE_DIR=${_cmd_dir}"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _o ERROR_VARIABLE _e)
file(WRITE "${RUN_OUT}" "${_o}\n---stderr---\n${_e}")
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "configure failed; log: ${RUN_OUT}")
endif()

set(BM "${_b}/build.make")
foreach(f Ninja Makefile)
    if(EXISTS "${_b}/${f}")
        break()
    endif()
endforeach()

# pins 1+2: the three forms exist -- the generator's own target
# directory ledger is the authoritative list (glob from the case side
# races nothing and reads nothing generated after configure)
set(_tdl "${_b}/CMakeFiles/TargetDirectories.txt")
if(NOT EXISTS "${_tdl}")
    message(FATAL_ERROR "no TargetDirectories.txt; log: ${RUN_OUT}")
endif()
file(READ "${_tdl}" _td)
foreach(tg app_plain-run app_gui-run app_deffold-run)
    if(NOT _td MATCHES "${tg}")
        message(FATAL_ERROR "missing target ${tg}; log: ${RUN_OUT}")
    endif()
endforeach()

# pin 3: the GUI build.make carries the probe chain markers
set(_bm "${_b}/CMakeFiles/app_gui-run.dir/build.make")
if(NOT EXISTS "${_bm}")
    message(FATAL_ERROR "no build.make for app_gui-run")
endif()
file(READ "${_bm}" _body)
foreach(marker "WAYLAND_SOCKET" ".X11-unix" "DISPLAY=:0" "exec")
    if(NOT _body MATCHES "${marker}")
        message(FATAL_ERROR "GUI form missing probe marker: ${marker}")
    endif()
endforeach()
# pin 3b: the non-GUI form must NOT carry the probe
file(READ "${_b}/CMakeFiles/app_plain-run.dir/build.make" _plain)
if(_plain MATCHES "WAYLAND_SOCKET")
    message(FATAL_ERROR "non-GUI form leaked the probe chain")
endif()

# pin 4: both run targets live in the IDE folder layer (FOLDER prop in
# the project's cmake files -- visible via the target file we already
# read for the GUI pins; folder rides the same body through CMakeConfig)
message(STATUS "t-example-run: button table + GUI probe chain pins PASS")
