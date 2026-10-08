# tests/fixtures/python-run -- fixture for cases/t-python-run.cmake (D32 T2).
# The python face's contract surface: interpreter resolution through the
# tier-a knob (the case passes a stub interpreter), the -E env injection
# point, ARGS passthrough, the run-<target> button grammar.
cmake_minimum_required(VERSION 3.25)
project(polyorch-fixture-python-run LANGUAGES NONE)

get_filename_component(_polyorch_cmake_dir
    "${CMAKE_CURRENT_SOURCE_DIR}/../../../cmake" ABSOLUTE)
list(APPEND CMAKE_MODULE_PATH "${_polyorch_cmake_dir}")
include(PolyOrchPythonHelpers)

# REQUIRED here: the case probe passed and the knob hands over a stub, so
# absence would be a product bug, not an environment fact (node-ws doctrine).
polyorch_python_setup(REQUIRED)

# fixture artifact contract BEFORE any early return (PIT-34).
set(POLYORCH_FIXTURE_ARTIFACTS
    "script=${CMAKE_CURRENT_SOURCE_DIR}/main.py")
string(JOIN "\n" _af ${POLYORCH_FIXTURE_ARTIFACTS})
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/polyorch-fixture-artifacts.txt" "${_af}\n")

# family verbs: ENVS + ARGS shape, NAME override shape
polyorch_python_run(TARGET greet SCRIPT "${CMAKE_CURRENT_SOURCE_DIR}/main.py"
    ARGS one two ENVS "PGREET=hi" "PMODE=fixture")
polyorch_python_run(TARGET calc SCRIPT "${CMAKE_CURRENT_SOURCE_DIR}/main.py"
    NAME fast)
