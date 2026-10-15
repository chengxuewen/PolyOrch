# requires: sh
# t-example-run -- polyorch_example_run surface: button table (name,
# COMMAND argv shape), GUI probe chain embedded (display vars + X socket
# glob + argv forwarding), FOLDER default, unknown-arg / bad-target
# guards, the no-GUI bare-exec form, the WORKING_DIRECTORY native-kwarg
# cd prefix (both forms, chdir outermost ahead of the GUI env wrap), and
# USES_TERMINAL on ALL four edges (pool = console -- the knob has no
# Makefiles text, measured; the ninja child leg follows t-rust-knobs).
# Pin 7 is the LIVE leg: the GUI buttons are actually EXECUTED (the text-
#marker pins passed on the shipped defect -- every fragment of the ';'-
#split probe keeps its markers; only running the command catches the
#split: rc=2 shell syntax error, host E801 live catch).
cmake_policy(SET CMP0219 NEW)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")
_polyorch_pixi_scratch(_s)
set(_b "${_s}/example-run")

file(WRITE "${_s}/proj/CMakeLists.txt" [=[
cmake_minimum_required(VERSION 3.25)
project(exrun NONE)
include("${POLYORCH_CMAKE_DIR}/PolyOrchExampleRunHelpers.cmake")

foreach(_n app_plain app_gui app_deffold app_wdir app_wgui)
    add_executable(${_n} IMPORTED)
    set_target_properties(${_n} PROPERTIES IMPORTED_LOCATION "/bin/echo")
endforeach()

# no-GUI form: bare exec, args forwarded as a list
polyorch_example_run(TARGET app_plain ARGS "--frames;3" FOLDER "examples/c")

# GUI form: the probe chain rides the COMMAND
polyorch_example_run(TARGET app_gui GUI FOLDER "examples/c")

# default FOLDER falls back to the caller's relative dir
polyorch_example_run(TARGET app_deffold ARGS "x")

# WORKING_DIRECTORY legs: plain + GUI, both rooted at POLYORCH_TEST_WD
polyorch_example_run(TARGET app_wdir ARGS "--frames;3" WORKING_DIRECTORY "${POLYORCH_TEST_WD}")
polyorch_example_run(TARGET app_wgui GUI WORKING_DIRECTORY "${POLYORCH_TEST_WD}")
]=])

set(RUN_OUT "${_s}/run.out")
set(_cmd_dir "${CMAKE_CURRENT_LIST_DIR}/../../cmake")
set(_wd "${_s}/wd")
# PIT (this round): a MID-argument quote (-DVAR="${dir}") survives as a
# literal quote in execute_process argv -- quote the WHOLE -D argument.
execute_process(COMMAND ${CMAKE_COMMAND}
    -S "${_s}/proj" -B "${_b}"
    "-DPOLYORCH_CMAKE_DIR=${_cmd_dir}"
    "-DPOLYORCH_TEST_WD=${_wd}"
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

# pins 1+2: the five forms exist -- the generator's own target
# directory ledger is the authoritative list (glob from the case side
# races nothing and reads nothing generated after configure)
set(_tdl "${_b}/CMakeFiles/TargetDirectories.txt")
if(NOT EXISTS "${_tdl}")
    message(FATAL_ERROR "no TargetDirectories.txt; log: ${RUN_OUT}")
endif()
file(READ "${_tdl}" _td)
foreach(tg app_plain-run app_gui-run app_deffold-run app_wdir-run app_wgui-run)
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

# pin 5: WORKING_DIRECTORY rides the NATIVE add_custom_target kwarg --
# the house idiom of every run face (python, node, rust buttons). Both
# generators emit the "cd <dir> &&" prefix themselves; the -E chdir WRAP
# is the rust wasm-serve exception (that target CREATES its dir -- no
# such reason here). Makefiles recipe carries the cd.
file(READ "${_b}/CMakeFiles/app_wdir-run.dir/build.make" _wbody)
string(FIND "${_wbody}" "cd ${_wd} && /bin/echo" _p)
if(_p LESS 0)
    message(FATAL_ERROR "plain+WDIR form lacks the native cd prefix [line ${CMAKE_CURRENT_LIST_LINE}]")
endif()

# pin 5b: the GUI+WDIR form orders chdir OUTSIDE the env wrap (the cd
# precedes "-E env" on the same recipe line) and keeps the probe chain.
file(READ "${_b}/CMakeFiles/app_wgui-run.dir/build.make" _gbody)
string(FIND "${_gbody}" "cd ${_wd} &&" _p1)
string(FIND "${_gbody}" "-E env" _p2)
if(_p1 LESS 0 OR _p2 LESS 0 OR NOT _p1 LESS _p2)
    message(FATAL_ERROR "GUI+WDIR form: chdir must ride outermost ahead of -E env (${_p1}/${_p2}) [line ${CMAKE_CURRENT_LIST_LINE}]")
endif()
foreach(marker "WAYLAND_SOCKET" ".X11-unix" "DISPLAY=:0" "exec")
    if(NOT _gbody MATCHES "${marker}")
        message(FATAL_ERROR "GUI+WDIR form lost the probe chain: ${marker}")
    endif()
endforeach()

# pin 5c: leg C regression -- the no-WORKING_DIRECTORY forms carry no wd
# token and no chdir wrap anywhere in their recipes (unset = byte-shape
# of the pre-kwarg command, plus the deliberate USES_TERMINAL add).
foreach(_f app_plain-run app_gui-run app_deffold-run)
    file(READ "${_b}/CMakeFiles/${_f}.dir/build.make" _body0)
    if(_body0 MATCHES "chdir")
        message(FATAL_ERROR "${_f}: no-WDIR form carries an -E chdir wrap (deviation guard)")
    endif()
    string(FIND "${_body0}" "cd ${_wd}" _p0)
    if(NOT _p0 LESS 0)
        message(FATAL_ERROR "${_f}: no-WDIR form leaked the wd path")
    endif()
endforeach()

# pin 6: USES_TERMINAL has no Makefiles text (measured -- t-rust-knobs
# layer 3), so its polarity is asserted on a ninja child of the SAME
# source tree: pool = console on all four button edges, the cd token
# only on the WDIR pair, chdir-before-env on GUI+WDIR.
execute_process(COMMAND ${CMAKE_COMMAND} -G Ninja
    -S "${_s}/proj" -B "${_b}-nj"
    "-DPOLYORCH_CMAKE_DIR=${_cmd_dir}"
    "-DPOLYORCH_TEST_WD=${_wd}"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _o ERROR_VARIABLE _e)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "ninja configure failed (${_rc}):\n${_o}${_e}")
endif()
file(READ "${_b}-nj/build.ninja" _nj)

# window = from the anchored CUSTOM_COMMAND header to the next edge
# header, so a neighbouring edge's pool can never leak (nj_edge copy,
# t-rust-knobs:130).
function(er_nj_window file needle out)
    string(FIND "${file}" "${needle}" _i)
    if(_i LESS 0)
        message(FATAL_ERROR "er_nj_window: no [${needle}] edge -- line ${CMAKE_CURRENT_LIST_LINE}")
    endif()
    string(SUBSTRING "${file}" ${_i} -1 _rest)
    string(FIND "${_rest}" "\nbuild " _n)
    if(_n GREATER 0)
        string(SUBSTRING "${_rest}" 0 ${_n} _win)
    else()
        set(_win "${_rest}")
    endif()
    set(${out} "${_win}" PARENT_SCOPE)
endfunction()

foreach(tg app_plain-run app_gui-run app_wdir-run app_wgui-run)
    er_nj_window("${_nj}" "CMakeFiles/${tg}: CUSTOM_COMMAND" _w)
    if(NOT _w MATCHES "pool = console")
        message(FATAL_ERROR "${tg}: ninja edge lacks the console pool (USES_TERMINAL) -- line ${CMAKE_CURRENT_LIST_LINE}")
    endif()
endforeach()

foreach(tg app_wdir-run app_wgui-run)
    er_nj_window("${_nj}" "CMakeFiles/${tg}: CUSTOM_COMMAND" _w)
    if(NOT _w MATCHES "cd ${_wd} &&")
        message(FATAL_ERROR "${tg}: ninja edge lacks the cd <wd> prefix -- line ${CMAKE_CURRENT_LIST_LINE}")
    endif()
endforeach()

foreach(tg app_plain-run app_gui-run)
    er_nj_window("${_nj}" "CMakeFiles/${tg}: CUSTOM_COMMAND" _w)
    if(_w MATCHES "chdir" OR _w MATCHES "cd ${_wd}")
        message(FATAL_ERROR "${tg}: no-WDIR ninja edge leaked wd/chdir -- line ${CMAKE_CURRENT_LIST_LINE}")
    endif()
endforeach()

# GUI+WDIR ordering inside the edge command line (chdir outermost).
er_nj_window("${_nj}" "CMakeFiles/app_wgui-run: CUSTOM_COMMAND" _wgw)
string(FIND "${_wgw}" "cd ${_wd}" _q1)
string(FIND "${_wgw}" "-E env" _q2)
if(NOT _q1 LESS _q2)
    message(FATAL_ERROR "GUI+WDIR ninja edge: cd must precede -E env (${_q1}/${_q2}) [line ${CMAKE_CURRENT_LIST_LINE}]")
endif()

# pin 7: LIVE EXECUTION of the real button recipe (the anti-decoration
# leg, C0). The configure scratch ${_b} (default generator) is built and
# the -run target RUNS: the probe must reach sh -c as ONE argument. The
# shipped set(_cmd ... "${probe}") + COMMAND ${_cmd} two-step split it at
# every ';' -- sh executed only the first fragment and died rc=2
# "Syntax error" while every marker pin above stayed green (host E801
# live catch). DISPLAY/WAYLAND vars are forced EMPTY through
# execute_process ENVIRONMENT (empty == unset for the probe's -z tests),
# so on a host WITH an X socket the fallback branch is the one taken and
# its stderr announcement is the proof the whole script parsed and ran;
# a host WITHOUT sockets keeps the rc=0 assertion (the split is
# generator-independent) and says so out loud instead of silently
# passing the sub-assert.
# the wdir recipe cds into ${_wd}: the dir must exist for the build
# to run the command at all (no marker pin ever executed it).
file(MAKE_DIRECTORY "${_wd}")
if(EXISTS "/bin/echo")
    foreach(tg app_gui-run app_wgui-run)
        execute_process(COMMAND ${CMAKE_COMMAND} --build "${_b}" --target "${tg}"
            # ENVIRONMENT trap (measured): ONE quoted "A=;B=" string is
            # consumed as a single NAME=VALUE pair -- DISPLAY literally
            # became ";B=" and the probe took the display-present branch.
            # One quoted entry per variable, as here.
            ENVIRONMENT "DISPLAY=" "WAYLAND_DISPLAY=" "WAYLAND_SOCKET="
            RESULT_VARIABLE _lrc OUTPUT_VARIABLE _lo ERROR_VARIABLE _le
            TIMEOUT 10)
        if(NOT _lrc EQUAL 0)
            message(FATAL_ERROR "live GUI leg ${tg}: button rc=${_lrc} -- the probe reached sh split at ';' (syntax error). output:\n${_lo}${_le} [line ${CMAKE_CURRENT_LIST_LINE}]")
        endif()
        file(GLOB _xs "/tmp/.X11-unix/X*")
        if(_xs)
            string(FIND "${_lo}${_le}" "falling back to DISPLAY=:0" _ap)
            if(_ap LESS 0)
                message(FATAL_ERROR "live GUI leg ${tg}: X sockets on host but no fallback announcement -- probe did not run whole [line ${CMAKE_CURRENT_LIST_LINE}]")
            endif()
        else()
            message(STATUS "live GUI leg ${tg}: no /tmp/.X11-unix sockets on host; fallback-announcement sub-assert skipped (rc=0 exec leg enforced)")
        endif()
    endforeach()
else()
    message(STATUS "t-example-run: no /bin/echo on host -- live GUI legs not executed (rc=0 leg needs the trivial payload)")
endif()

message(STATUS "t-example-run: button table + GUI probe chain + WORKING_DIRECTORY cd (native kwarg, both trees) + USES_TERMINAL pool on all four edges + LIVE exec (probe one-argument, fallback announcement) PASS")
