# requires: system-rust
cmake_policy(SET CMP0219 NEW)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

# WP15: "Rust wraps an EXISTING C++ library". The C++ static lib is built
# by CMake, the shim compiles inside cxx-build, and the LIBRARY reaches
# the cargo link through polyorch_rust_link_libraries. Asserts the run
# output carries the library's computed value.
_polyorch_pixi_scratch(_s)
set(_b "${_s}/rcl")
drv_run(_dlog _rc SKIP_VAR _skip
    FIXTURE "${CMAKE_CURRENT_LIST_DIR}/../../examples/rust-cpp-lib"
    BUILD "${_b}")
if(_skip)
    message(STATUS "t-rust-cpplib : SKIP (fixture gate: no cargo)")
    return()
endif()

# the run target executed the binary inside the driver already; re-run for
# the output assertion (config-aware like the bindings case)
# the run target is custom (not in the driver's default set): build it
execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_b}"
    --target consumer-bin-build
    RESULT_VARIABLE _rc OUTPUT_QUIET ERROR_QUIET)
ck(_rc EQUAL 0)
# the artifact lives in the ISOLATED cargo target dir (single-config:
# .cargo-target/debug; MC: nested per config -- same layout the bindings
# case globs)
set(_cfg "$ENV{POLYORCH_TEST_CONFIG}")
if(_cfg AND EXISTS "${_b}/.cargo-target/${_cfg}/consumer")
    set(_bin "${_b}/.cargo-target/${_cfg}/consumer")
else()
    file(GLOB _bin "${_b}/.cargo-target/*/consumer" "${_b}/.cargo-target/consumer")
    # the cxxbridge generation dir nests a bin-shaped copy -- exclude it
    list(FILTER _bin EXCLUDE REGEX "/cxxbridge/")
    list(LENGTH _bin _n)
    ck(_n EQUAL 1)
    list(GET _bin 0 _bin)
endif()
execute_process(COMMAND "${_bin}" RESULT_VARIABLE _rc OUTPUT_VARIABLE _out)
ck(_rc EQUAL 0)
ck(_out MATCHES "demo level = 7")
# string(FIND) instead of MATCHES: the call syntax contains parens and a
# dot, and the regex-escape lifecycle across the ck macro keeps biting
string(FIND "${_out}" "demo.eval(10) = 37" _hit)
ck(_hit GREATER -1)   # Lib(seed=3).eval(10) = 10*3+7

message(STATUS "t-rust-cpplib: OK (CMake-built C++ lib -> link_libraries -> cargo link -> rust calls C++ class)")
