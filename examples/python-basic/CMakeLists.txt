# PolyOrch example: run a python script through the python face (D32).
#
# The python face has no compile step: setup() locates an interpreter,
# run() registers a button and (gate ON here) a debugpy launch config.
# Configure reaches no network.
#
#   # standalone:
#   cmake -S examples/python-basic -B build -DPolyOrch_VSCODE_DIR=build/.vscode
#   cmake --build build --target greet-run        # python main.py
#   # F5 in VSCode afterwards: "PolyOrch: greet" stops on breakpoints
#
#   # embedded in a fused host (examples loop):
#   cmake ... -DPolyOrch_BUILD_RUST_EXAMPLES=ON   # button polyorch-python-basic-run-greet
cmake_minimum_required(VERSION 3.22)

# --- opt-in gate (rust-basic shape: standalone proceeds, fused hosts opt in)
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    set(_py_standalone TRUE)
else()
    set(_py_standalone FALSE)
endif()
if(NOT _py_standalone AND NOT PolyOrch_BUILD_RUST_EXAMPLES)
    return()
endif()

project(python-basic LANGUAGES NONE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
# Opt-in VSCode debugpy generation for this example's run targets (the F5
# out-of-the-box surface; the library default stays OFF -- rust-basic:64 idiom,
# the set MUST precede the include: the hook evaluates at include tail).
set(PolyOrch_PYTHON_VSCODE_DEBUG ON)
include(PolyOrchPythonHelpers)

if(_py_standalone)
    polyorch_python_setup(REQUIRED)
else()
    polyorch_python_setup()
    if(NOT POLYORCH_PYTHON_FOUND)
        message(STATUS
            "python-basic: needs python3; not on PATH, ~/.pixi/bin, or a pixi env "
            "-- example skipped (standalone runs still get the loud REQUIRED error)")
        return()
    endif()
endif()

# [1/1] The one verb: a run button + the debugpy registration. ENVS flows
#         through the -E env injection point; main.py reads POLYORCH_WHO.
polyorch_python_run(TARGET greet
    SCRIPT "${CMAKE_CURRENT_SOURCE_DIR}/main.py"
    ENVS "POLYORCH_WHO=fused")
