# requires: system-rust
cmake_policy(SET CMP0219 NEW)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

# WP16: "Python consumes a rust extension module". Drives the standalone
# tree: build the cdylib, run the demo target (which stages the module
# under its python import name and runs the consumer script), assert the
# output, and check the install rename (LANGUAGE_PRODUCT python).
_polyorch_pixi_scratch(_s)
set(_b "${_s}/rpx")
drv_run(_dlog _rc SKIP_VAR _skip
    FIXTURE "${CMAKE_CURRENT_LIST_DIR}/../../examples/rust-pyext"
    BUILD "${_b}")
if(_skip)
    message(STATUS "t-rust-pyext : SKIP (fixture gate: no cargo)")
    return()
endif()

# build the cdylib explicitly (custom target, not in the default set)
execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_b}"
    --target spine-py-build
    RESULT_VARIABLE _rc OUTPUT_QUIET ERROR_QUIET)
ck(_rc EQUAL 0)

# the demo target stages spine_py.so (import name) + runs the consumer
# through the resolved interpreter -- one stop
execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_b}"
    --target spine_py-demo
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(NOT _rc EQUAL 0)
    message(STATUS "pyext demo rc=${_rc}: ${_err}${_out}")
endif()
ck(_rc EQUAL 0)
ck(_out MATCHES "hello from spine-py")
string(FIND "${_out}" "add(19,23) = 42" _hit)
ck(_hit GREATER -1)
# the staged module exists post-demo (import-name contract)
file(GLOB _so "${_b}/.cargo-target/*/spine_py.so" "${_b}/.cargo-target/spine_py.so")
list(LENGTH _so _n)
ck(_n EQUAL 1)

message(STATUS "t-rust-pyext: OK (PyO3 cdylib + import-name staging + interpreter-driven consumer)")
