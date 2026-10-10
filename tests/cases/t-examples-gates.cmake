cmake_policy(SET CMP0219 NEW)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")

# t-examples-gates -- the family-gate symmetry contract (D33 rounds 2-3;
# the PIT-41 RECURRENCE pin, user-found 2026-10-08). Every fused examples
# entry rides its OWN PolyOrch_BUILD_*_EXAMPLES option:
#   leg 1  RUST=ON  NODE=OFF PYTHON=OFF => zero node-web/python-basic
#          targets EVEN with node+pm stubs present (the historical misfit
#          had node-web appearing whenever the rust gate opened -- and
#          vanishing whenever it closed, both wrong).
#   leg 2  RUST=OFF NODE=ON             => node-web targets present with no
#          rust flag and no cargo dependency (the decoupling half), while
#          python-basic stays absent under its own OFF flag.
#   leg 4  every `cmake --build build --target <name>` command printed in
#          examples/README.md names a target a pixi-equipped configure
#          actually registers (D36 escalation, same fossil class aimed at
#          the user's typing hand; negative proof observed 2026-10-09).
#   leg 3  every SOURCE_DIR/<seg> path reference in examples/CMakeLists.txt
#          names a real directory/file (adjudicated 2026-10-09, ruling 2-B:
#          the rename-sweep class shipped 6 remote buttons whose -S/-P paths
#          no longer existed; registration + STATUS legs cannot see it -- the
#          path is only evaluated at button-run time).
# Discovery determinism: tier-a knobs (PolyOrchNodeExe/Npm) win over PATH
# (the order fixed in the same round -- if that regression returns, leg 2
# flips and this case says so).
# Truth source: TargetDirectories.txt (no IDE needed, make-generator shape).

_polyorch_pixi_scratch(_s)
set(_ex "${CMAKE_CURRENT_LIST_DIR}/../../examples")

file(MAKE_DIRECTORY "${_s}/stubs")
file(WRITE "${_s}/stubs/node" "#!/bin/sh\necho v22\nexit 0\n")
file(WRITE "${_s}/stubs/npm"  "#!/bin/sh\nexit 0\n")
file(COPY "${_s}/stubs/node" "${_s}/stubs/npm" DESTINATION "${_s}/stubs"
     FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ WORLD_READ)

macro(hostcfg tag)
    file(MAKE_DIRECTORY "${_s}/h-${tag}")
    file(WRITE "${_s}/h-${tag}/CMakeLists.txt"
"cmake_minimum_required(VERSION 3.22)\n"
"project(gates-host LANGUAGES NONE)\n"
"add_subdirectory(\"${_ex}\" examples)\n")
    execute_process(
        COMMAND "${CMAKE_COMMAND}" -S "${_s}/h-${tag}" -B "${_s}/h-${tag}/b"
            "-DPolyOrch_BUILD_EXAMPLES=ON"
            "-DPolyOrchNodeExe=${_s}/stubs/node"
            "-DPolyOrchNodeNpm=${_s}/stubs/npm"
            ${ARGN}
        RESULT_VARIABLE _rc OUTPUT_QUIET ERROR_VARIABLE _err)
    if(NOT _rc EQUAL 0)
        message(FATAL_ERROR "hostcfg(${tag}) failed: ${_err}")
    endif()
    file(READ "${_s}/h-${tag}/b/CMakeFiles/TargetDirectories.txt" _td)
endmacro()

# ---- leg 1: rust gate open, node/python gates closed ----------------------
hostcfg("rust-only"
    "-DPolyOrch_BUILD_RUST_EXAMPLES=ON"
    "-DPolyOrch_BUILD_NODE_EXAMPLES=OFF"
    "-DPolyOrch_BUILD_PYTHON_EXAMPLES=OFF")
string(FIND "${_td}" "node-web" _h)
if(NOT _h LESS 0)
    message(FATAL_ERROR
        "check failed: node-web rode the RUST gate again (PIT-41 recurrence)")
endif()
string(FIND "${_td}" "node-basic" _h)
if(NOT _h LESS 0)
    message(FATAL_ERROR
        "check failed: node-basic rode the RUST gate (PIT-41 class)")
endif()
string(FIND "${_td}" "python-basic" _h)
if(NOT _h LESS 0)
    message(FATAL_ERROR "check failed: python-basic rode another family's gate")
endif()

# ---- leg 2: node gate open alone; no rust flag, no cargo assumption -------
hostcfg("node-only"
    "-DPolyOrch_BUILD_RUST_EXAMPLES=OFF"
    "-DPolyOrch_BUILD_NODE_EXAMPLES=ON")
string(FIND "${_td}" "polyorch-node-web-hello-ts-build.dir" _h)
if(_h LESS 0)
    message(FATAL_ERROR
        "check failed: node gate alone registered no node-web target")
endif()
string(FIND "${_td}" "polyorch-node-basic-node-basic-build.dir" _h)
if(_h LESS 0)
    message(FATAL_ERROR
        "check failed: node gate alone registered no node-basic target")
endif()
string(FIND "${_td}" "python-basic" _h)
if(NOT _h LESS 0)
    message(FATAL_ERROR "check failed: python-basic appeared under OFF gate")
endif()

# ---- leg 3: button path integrity (rename-sweep collateral gate) ------------
file(READ "${_ex}/CMakeLists.txt" _xsrc)
string(REGEX MATCHALL "\\$\\{CMAKE_CURRENT_SOURCE_DIR\\}/[A-Za-z0-9._/-]+" _xrefs "${_xsrc}")
if(NOT _xrefs)
    message(FATAL_ERROR "leg 3 vacuous: no SOURCE_DIR reference matched -- scanner or file format drifted")
endif()
foreach(_xr ${_xrefs})
    string(REPLACE "\${CMAKE_CURRENT_SOURCE_DIR}/" "" _seg "${_xr}")
    if(NOT EXISTS "${_ex}/${_seg}")
        message(FATAL_ERROR "examples/CMakeLists.txt references a missing path: ${_ex}/${_seg}")
    endif()
endforeach()

# ---- leg 4: README --target command names vs the registered target table ----
file(READ "${_ex}/README.md" _rmd)
string(REGEX MATCHALL "cmake --build build --target +[A-Za-z0-9._-]+" _cmds "${_rmd}")
if(NOT _cmds)
    message(FATAL_ERROR "leg 4 vacuous: examples/README.md carries no --target command (doc block lost or rewritten)")
endif()
find_program(_px pixi)
if(NOT _px)
    find_program(_px pixi PATHS "$ENV{HOME}/.pixi/bin")
endif()
if(_px)
    hostcfg("buttons"
        "-DPolyOrch_BUILD_PIXI_EXAMPLES=ON")
    foreach(_cm ${_cmds})
        string(REGEX REPLACE ".*--target +" "" _t "${_cm}")
        string(FIND "${_td}" "${_t}.dir" _h)
        if(_h LESS 0)
            message(FATAL_ERROR "examples/README.md --target '${_t}' names no registered target (fossil command)")
        endif()
    endforeach()
else()
    message(STATUS "t-examples-gates: leg 4 deferred (pixi absent -- buttons not registered)")
endif()

message(STATUS "t-examples-gates: OK (family-gate symmetry + path scan + README command pins)")
