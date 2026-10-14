# requires: sh
# t-rust-run-gui -- the T-H9 GUI keyword on polyorch_rust_run: the button
# carries the shared display-probe chain (markers + argv forwarding),
# the non-GUI shape keeps the bare direct exec, and the unknown-knob
# surface stays closed. Fixture = the WP3 stub toolchain (no real cargo
# invoked; configure-shape assertions only).
cmake_policy(SET CMP0219 NEW)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")
_polyorch_pixi_scratch(_s)
set(_b "${_s}/run-gui")

file(WRITE "${_s}/proj/CMakeLists.txt" [=[
cmake_minimum_required(VERSION 3.25)
project(rng NONE)
include("${POLYORCH_CMAKE_DIR}/PolyOrchRustHelpers.cmake")
set(PolyOrch_RUST_CARGO_EXECUTABLE /bin/true CACHE FILEPATH "" FORCE)
set(PolyOrch_RUSTC_EXECUTABLE /bin/true CACHE FILEPATH "" FORCE)
add_executable(bin_x IMPORTED)
set_target_properties(bin_x PROPERTIES IMPORTED_LOCATION "${CMAKE_BINARY_DIR}/bin_x")
polyorch_rust_run(TARGET bin_x GUI)
add_executable(bin_y IMPORTED)
set_target_properties(bin_y PROPERTIES IMPORTED_LOCATION "${CMAKE_BINARY_DIR}/bin_y")
polyorch_rust_run(TARGET bin_y)
]=])

set(_cmd_dir "${CMAKE_CURRENT_LIST_DIR}/../../cmake")
execute_process(COMMAND "${CMAKE_COMMAND}"
    -S "${_s}/proj" -B "${_b}"
    "-DPOLYORCH_CMAKE_DIR=${_cmd_dir}"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _o ERROR_VARIABLE _e)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "configure failed (log: ${_o}${_e})")
endif()

foreach(h bin_x bin_y)
    set(_bm "${_b}/CMakeFiles/${h}-run.dir/build.make")
    if(NOT EXISTS "${_bm}")
        message(FATAL_ERROR "missing ${h}-run build.make")
    endif()
    file(READ "${_bm}" _body)
    set(_want "WAYLAND_SOCKET")
    if(h STREQUAL "bin_y")
        set(_want "bin_y")   # bare exec: no probe markers
    endif()
    if(h STREQUAL "bin_x")
        foreach(marker "WAYLAND_SOCKET" ".X11-unix" "DISPLAY=:0" "exec")
            if(NOT _body MATCHES "${marker}")
                message(FATAL_ERROR "GUI button missing probe marker: ${marker}")
            endif()
        endforeach()
    else()
        if(_body MATCHES "WAYLAND_SOCKET")
            message(FATAL_ERROR "non-GUI button leaked the probe chain")
        endif()
    endif()
endforeach()
message(STATUS "t-rust-run-gui: GUI markers present + bare form clean -- PASS")
