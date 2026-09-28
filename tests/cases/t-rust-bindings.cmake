# requires: system-rust
cmake_policy(SET CMP0219 NEW)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

# WP14: the flagship binding example. Drives the STANDALONE tree end to
# end: cxxbridge -> C++ executable consumer (both bridge directions),
# cbindgen -> install(EXPORT) -> find_package consumer -> run.
_polyorch_pixi_scratch(_s)
set(_b "${_s}/rb")
drv_run(_dlog _rc SKIP_VAR _skip
    FIXTURE "${CMAKE_CURRENT_LIST_DIR}/../../examples/rust-bindings"
    BUILD "${_b}")
if(_skip)
    message(STATUS "t-rust-bindings : SKIP (fixture gate: no cargo)")
    return()
endif()

# The C++ executable consumer: build explicitly (custom target, not in the
# driver's default set) and run it -- both bridge directions must answer.
execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_b}"
    --target rust-bindings-app
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _bo ERROR_VARIABLE _be)
if(NOT _rc EQUAL 0)
    message(STATUS "app build rc=${_rc}: ${_be}${_bo}")
endif()
ck(_rc EQUAL 0)
# multi-config nests the artifact under the config dir; prefer the
# current POLYORCH_TEST_CONFIG's spelling (the MC cell runs Debug then
# Release against the same tree, so the bare-name glob would see two)
set(_cfg "$ENV{POLYORCH_TEST_CONFIG}")
set(_app "")
if(EXISTS "${_b}/${_cfg}/rust-bindings-app")
    set(_app "${_b}/${_cfg}/rust-bindings-app")
elseif(EXISTS "${_b}/rust-bindings-app")
    set(_app "${_b}/rust-bindings-app")
else()
    file(GLOB _app "${_b}/*/rust-bindings-app")
    list(GET _app 0 _app)
endif()
execute_process(COMMAND "${_app}" RESULT_VARIABLE _rc OUTPUT_VARIABLE _out)
ck(_rc EQUAL 0)
ck(_out MATCHES "spine echoes: c\\+\\+ app")
ck(_out MATCHES "spine_add = 42")
ck(_out MATCHES "host_scale\\(6,7\\) = 42.0")

# The installed-binding chain: install(EXPORT) -> find_package -> run.
execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_b}"
    --target rust-bindings-consumer
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _bo ERROR_VARIABLE _be)
if(NOT _rc EQUAL 0)
    message(STATUS "consumer build rc=${_rc}: ${_be}${_bo}")
    message(STATUS "CONSDBG b=[${_b}] t=[rust-bindings-consumer]")
endif()
ck(_rc EQUAL 0)
if(EXISTS "${_b}/consumer-build/${_cfg}/consumer")
    set(_consumer "${_b}/consumer-build/${_cfg}/consumer")
elseif(EXISTS "${_b}/consumer-build/consumer")
    set(_consumer "${_b}/consumer-build/consumer")
else()
    file(GLOB _consumer "${_b}/consumer-build/*/consumer")
    list(GET _consumer 0 _consumer)
endif()
execute_process(COMMAND "${_consumer}" RESULT_VARIABLE _rc OUTPUT_VARIABLE _out2)
ck(_rc EQUAL 0)
ck(_out2 MATCHES "hello from spine, installed consumer!")

# The zero-coverage verb this example carries: clean registered
# (generator-agnostic probe: the rule file mentions it)
file(GLOB _bf "${_b}/CMakeFiles/rust-bindings-clean.dir" "${_b}/build.ninja")
list(LENGTH _bf _nbf)
ck(_nbf GREATER 0)
if(EXISTS "${_b}/build.ninja")   # ninja tree: the rule must be named there
    file(READ "${_b}/build.ninja" _ninja_txt)
    string(FIND "${_ninja_txt}" "rust-bindings-clean" _cleanhit)
    ck(_cleanhit GREATER -1)
endif()

message(STATUS "t-rust-bindings: OK (cxx bridge C++ consumer + cbindgen install/export chain + clean verb)")
