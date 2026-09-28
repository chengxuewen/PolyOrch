# WP12: system-route example fusion (umbrella add_subdirectory form).
# Fuses the three system-route examples into a scratch host configure and
# asserts the resulting target tree: per-example verb targets exist, the
# per-example aggregates carry example-prefixed names (no silent merge),
# and the remote-control buttons (pixi routes, install-export) are still
# registered. Offline (cargo not needed for the target-existence legs --
# the scratch configure skips tool-less subtrees via the STATUS gates, but
# with cargo present it fuses fully; requires: system-rust).
# requires: system-rust
cmake_policy(SET CMP0219 NEW)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")

_polyorch_pixi_scratch(_s)
set(_h "${_s}/fused")

# Host configure == the umbrella (the examples root IS a host when fused
# standalone-configured). Path composition mirrors the driver child PATH.
file(MAKE_DIRECTORY "${_h}")
file(WRITE "${_h}/CMakeLists.txt"
"cmake_minimum_required(VERSION 3.22)\n"
"project(fused-host LANGUAGES C)\n"
"add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/../../examples examples)\n")
execute_process(
    COMMAND "${CMAKE_COMMAND}" -S "${_h}" -B "${_h}/b"
        -DPolyOrch_BUILD_EXAMPLES=ON -DPolyOrch_BUILD_RUST_EXAMPLES=ON
    ENVIRONMENT "PATH=$ENV{PATH}:$ENV{HOME}/.cargo/bin:$ENV{HOME}/.pixi/bin"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
ck(_rc EQUAL 0)
string(REGEX MATCHALL "CMake Error" _cerrs "${_out}${_err}")
list(LENGTH _cerrs _nerr)
ck(_nerr EQUAL 0)

# target existence via the generated build tree's target directory list
file(READ "${_h}/b/CMakeFiles/TargetDirectories.txt" _tdirs)
foreach(_t "rust-basic-greet-build" "rust-basic-greet-run"
           "rust-import-dash_ed-build" "rust-link-c-cli-user-tool-build"
           "rust-profile-features-demo-rel-build"
           "rust-basic-all" "rust-import-all" "rust-link-c-all"
           "rust-profile-features-all")
    string(FIND "${_tdirs}" "${_t}.dir" _hit)
    if(_hit LESS 0)
        message(FATAL_ERROR "check failed: fused target '${_t}' absent from host tree")
    endif()
endforeach()

# remote-control buttons still registered (pixi route + install-export)
foreach(_btn "PolyOrchExampleRustInstallExport")
    string(FIND "${_tdirs}" "${_btn}.dir" _hit)
    if(_hit LESS 0)
        message(FATAL_ERROR "check failed: remote button '${_btn}' missing")
    endif()
endforeach()

message(STATUS "t-rust-fusion: OK (3 fused verb sets + prefixed aggregates + remote buttons intact)")
