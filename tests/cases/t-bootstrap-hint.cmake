# t-bootstrap-hint -- D48 T1: the pixi-shape trigger. A candidate cmake that
# EXISTS and differs from the running CMAKE_COMMAND must produce, in one
# synchronous failure-path call: a settings.json whose cmakePath row carries
# the ${workspaceFolder} LITERAL (never an absolute path) + managed region
# markers + configureOnOpen, and a two-step guidance block (Delete Cache and
# Reconfigure / reload window + reconfigure). The ${workspaceFolder} leg runs
# as a CHILD CONFIGURE because script mode's CMAKE_SOURCE_DIR is this case's
# directory (a /tmp candidate would be outside the source root, where the
# writer honestly falls back to the absolute form). Also pins the V2 update
# semantics offline: an idempotent re-run is byte-stable, a relocated
# candidate updates the row in place, and user content above the BEGIN marker
# survives untouched.
cmake_policy(SET CMP0219 NEW)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchBootstrapHelpers.cmake")

# ---- FATAL leg (guard-first: argument validation) --------------------------
# The guard MUST check ck_child_fail's own switch (POLYORCH_CHILD): a private
# name leaves the child's ck_child_fail line unguarded -> unbounded re-exec
# recursion (measured: the first draft hung the driver exactly that way).
if(POLYORCH_CHILD)
    polyorch_bootstrap_hint()
    message(FATAL_ERROR "expected the CANDIDATE_CMAKE guard to fire")
endif()
ck_child_fail("polyorch_bootstrap_hint: CANDIDATE_CMAKE is required")

_polyorch_pixi_scratch(_s)

# ---- T1: pixi-shape child configure (project mode) -------------------------
set(_ws "${_s}/wsroot")
file(MAKE_DIRECTORY "${_ws}/.pixi/bin")
file(WRITE "${_ws}/.pixi/bin/cmake" "#!/bin/sh\n")
file(WRITE "${_ws}/CMakeLists.txt"
"cmake_minimum_required(VERSION 3.25)\n"
"project(bootws LANGUAGES NONE)\n"
"list(APPEND CMAKE_MODULE_PATH \"${CMAKE_CURRENT_LIST_DIR}/../../cmake\")\n"
"include(PolyOrchBootstrapHelpers)\n"
"polyorch_bootstrap_hint(CANDIDATE_CMAKE \"\${CMAKE_SOURCE_DIR}/.pixi/bin/cmake\")\n")
execute_process(COMMAND "${CMAKE_COMMAND}" -S "${_ws}" -B "${_ws}/b"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
string(JOIN "\n" _all "${_out}" "${_err}")
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "T1 child configure failed rc=${_rc}:\n${_all}")
endif()
ck_file("${_ws}/.vscode/settings.json")
file(READ "${_ws}/.vscode/settings.json" _c)
ck(_c MATCHES "\"cmake\\.cmakePath\": \"\\$\\{workspaceFolder\\}/\\.pixi/bin/cmake\"")
ck(_c MATCHES "\"cmake\\.configureOnOpen\": true")
ck(_c MATCHES "__POLYORCH_GENERATED_BEGIN__")
ck(_c MATCHES "__POLYORCH_GENERATED_END__")
ck(NOT _c MATCHES "\"${_ws}")            # never an absolute workspace path
# guidance: the two-step self-sufficient text rides the same output
ck(_all MATCHES "Delete Cache and Reconfigure")
ck(_all MATCHES "bootstrap settings file has been written")
ck(_all MATCHES "reload the VS Code window")

# ---- V2 offline twin: region update + user-content preservation ------------
# A fake toolchain cmake OUTSIDE the workspace (script-mode _s is under /tmp,
# genuinely outside CMAKE_SOURCE_DIR) exercises the absolute-fallback row
# shape while keeping the file-level assertions simple.
set(_cand "${_s}/pixi/bin/cmake")
file(MAKE_DIRECTORY "${_s}/pixi/bin")
file(WRITE "${_cand}" "#!/bin/sh\n")
set(_ws2 "${_s}/wsroot2")
set(_f2 "${_ws2}/.vscode/settings.json")
file(MAKE_DIRECTORY "${_ws2}/.vscode")
set(PolyOrch_VSCODE_DIR "${_ws2}/.vscode")
polyorch_bootstrap_hint(CANDIDATE_CMAKE "${_cand}")      # seeds the region
file(READ "${_f2}" _before)
polyorch_bootstrap_hint(CANDIDATE_CMAKE "${_cand}")      # idempotent re-run
file(READ "${_f2}" _after)
ck_str("${_before}" "${_after}")
# ---- T1b: out-of-workspace candidate -> absolute fallback (documented shape,
# still marker-marked). The driver's scratch lives INSIDE the repo (tests/.scratch),
# so the candidate must be minted under a real /tmp root to leave CMAKE_SOURCE_DIR.
string(RANDOM LENGTH 8 ALPHABET "abcdefghijklmnopqrstuvwxyz0123456789" _bh_rand)
set(_bh_absroot "/tmp/polyorch-bh-${_bh_rand}")
file(MAKE_DIRECTORY "${_bh_absroot}/bin")
file(WRITE "${_bh_absroot}/bin/cmake" "#!/bin/sh\n")
set(_ws1b "${_s}/wsroot1b")
set(PolyOrch_VSCODE_DIR "${_ws1b}/.vscode")
polyorch_bootstrap_hint(CANDIDATE_CMAKE "${_bh_absroot}/bin/cmake")
ck_file("${_ws1b}/.vscode/settings.json")
file(READ "${_ws1b}/.vscode/settings.json" _c1b)
ck(_c1b MATCHES "cmake\\.cmakePath.*${_bh_absroot}/bin/cmake")
ck(NOT _c1b MATCHES "workspaceFolder")
ck(_c1b MATCHES "__POLYORCH_GENERATED_BEGIN__")
file(REMOVE_RECURSE "${_bh_absroot}")

# ---- V2: managed-region REPLACED; relocation updates the row in place ----
set(_ws2 "${_s}/wsroot2")
set(_f2 "${_ws2}/.vscode/settings.json")
file(MAKE_DIRECTORY "${_ws2}/.vscode")
set(PolyOrch_VSCODE_DIR "${_ws2}/.vscode")
polyorch_bootstrap_hint(CANDIDATE_CMAKE "${_cand}")      # seeds the region
file(READ "${_f2}" _before)
polyorch_bootstrap_hint(CANDIDATE_CMAKE "${_cand}")      # idempotent re-run
file(READ "${_f2}" _after)
ck_str("${_before}" "${_after}")
# relocating the candidate updates the row in place (V2 semantics)
set(_cand2 "${_s}/pixi2/bin/cmake")
file(MAKE_DIRECTORY "${_s}/pixi2/bin")
file(WRITE "${_cand2}" "#!/bin/sh\n")
polyorch_bootstrap_hint(CANDIDATE_CMAKE "${_cand2}")
file(READ "${_f2}" _moved)
ck(_moved MATCHES "pixi2/bin/cmake")
ck(NOT _moved MATCHES "pixi/bin/cmake")
# everything above the BEGIN marker is exactly the untouched open brace
string(FIND "${_moved}" "// __POLYORCH_GENERATED_BEGIN__" _b)
string(SUBSTRING "${_moved}" 0 "${_b}" _user)
string(COMPARE EQUAL "${_user}" "{\n" _ueq)
ck(_ueq)

message(STATUS "t-bootstrap-hint: OK (workspaceFolder literal + markers + configureOnOpen + two-step guidance + region update)")
