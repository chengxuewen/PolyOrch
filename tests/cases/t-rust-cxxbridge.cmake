include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

# WP7 cxxbridge cluster, offline legs.
#  A. _polyorch_rust_cxxbridge_cmd argv tables -- the three invocation
#     shapes of corr:1925 (builtin --header --output), corr:1954 (per-file
#     header) and corr:1956-1958 (per-file source with --include AFTER
#     --output, order locked). Guards: HEADER+INCLUDE nonsense, a source
#     form without RUST, unknown args, missing required keywords.
#  B. Stub-tool rule-execution leg (posix shell): drives tests/fixtures/
#     cxxbridge through _driver.cmake -- a REAL rust pair build with the
#     STUB cxxbridge (tool-stubs/bin) pinned via PREFIX + VERSION, so
#     discovery, version gate, directory layout, generated-file wiring,
#     static-library compilation of the generated source and the
#     touch-reruns-on-source-change DEPENDS edge all execute for real
#     with zero network (the bridge .rs files never enter the cargo
#     module tree -- cxxbridge parses them, cargo never compiles them).
#     Child generator is forced to Unix Makefiles (the rule-text reads
#     below are Makefile-shaped; t-rust-knobs precedent).

# ------------------------------------------------------------- A. argv tables --
_polyorch_rust_cxxbridge_cmd(TOOL /tp/cxxbridge HEADER OUTPUT /gen/rust/cxx.h
    OUT_CMD _c)
ck_str("${_c}" "/tp/cxxbridge;--header;--output;/gen/rust/cxx.h")

_polyorch_rust_cxxbridge_cmd(TOOL /tp/cxxbridge RUST /m/src/bridge.rs
    HEADER OUTPUT /h/bridge.h OUT_CMD _c)
ck_str("${_c}" "/tp/cxxbridge;/m/src/bridge.rs;--header;--output;/h/bridge.h")

_polyorch_rust_cxxbridge_cmd(TOOL /tp/cxxbridge RUST /m/src/bridge.rs
    OUTPUT /s/bridge.cpp INCLUDE greet-lib-cxx/bridge.h OUT_CMD _c)
ck_str("${_c}"
    "/tp/cxxbridge;/m/src/bridge.rs;--output;/s/bridge.cpp;--include;greet-lib-cxx/bridge.h")

# Guards (child cmake -P, the ck_call_fail family from t-rust-knobs).
_polyorch_pixi_scratch(_s)
macro(cb_fail name rx)
    set(_body "${ARGN}")
    string(REPLACE ";" "\n" _body "${_body}")
    file(WRITE "${_s}/${name}.cmake"
        "include(\"${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake\")\n${_body}\nmessage(FATAL_ERROR \"GUARD-NOT-FIRED\")\n")
    execute_process(
        COMMAND "${CMAKE_COMMAND}" -P "${_s}/${name}.cmake"
        RESULT_VARIABLE _rc OUTPUT_VARIABLE _o ERROR_VARIABLE _e)
    string(REGEX REPLACE "[ \r\n\t]+" " " _txt "${_o}${_e}")
    if(_rc EQUAL 0)
        message(FATAL_ERROR "cb_fail(${name}): child exited 0, expected FATAL [${rx}]")
    endif()
    if(_txt MATCHES "GUARD-NOT-FIRED")
        message(FATAL_ERROR "cb_fail(${name}): call passed validation")
    endif()
    if(NOT _txt MATCHES "${rx}")
        message(FATAL_ERROR "cb_fail(${name}): rc=${_rc} but output lacks [${rx}]: ${_txt}")
    endif()
endmacro()

cb_fail(cb-noout "_polyorch_rust_cxxbridge_cmd: missing required argument 'C_OUTPUT'"
    "_polyorch_rust_cxxbridge_cmd(TOOL t HEADER OUT_CMD _c)")
cb_fail(cb-norust "cxxbridge_cmd: RUST is required for the source invocation"
    "_polyorch_rust_cxxbridge_cmd(TOOL t OUTPUT /o OUT_CMD _c)")
cb_fail(cb-hdrinc "cxxbridge_cmd: INCLUDE belongs to the source invocation only"
    "_polyorch_rust_cxxbridge_cmd(TOOL t RUST r HEADER OUTPUT /o INCLUDE i OUT_CMD _c)")
cb_fail(cb-badarg "_polyorch_rust_cxxbridge_cmd: unknown args: --wat"
    "_polyorch_rust_cxxbridge_cmd(TOOL t --wat OUTPUT /o OUT_CMD _c)")

message(STATUS "t-rust-cxxbridge : planner tables OK")

# ---------------------------------------------------- B. stub-tool rule leg --
# Discovery + version gate + generation + compilation of the STUB's
# dummy output, end to end on Unix Makefiles (forced -- the rule-text
# reads below are Makefile-shaped, t-rust-knobs precedent; the child
# generator is deliberately NOT the cell's). No network, no crates.io:
# cxxbridge-cmd is the tool-stubs stand-in, pinned via PREFIX + the
# 1.0.131 banner.
polyorch_requires(posix-shell _req)
if(NOT _req)
    message(STATUS "t-rust-cxxbridge : SKIP (posix shell stubs need a UNIX host)")
    return()
endif()

set(_cfg "$ENV{POLYORCH_TEST_CONFIG}")
if(NOT _cfg)
    set(_cfg Debug)
endif()
set(_b "${_s}/cbchild")
set(_stubs "${CMAKE_CURRENT_LIST_DIR}/../fixtures/tool-stubs")
set(_dargs "-DFIXTURE=${CMAKE_CURRENT_LIST_DIR}/../fixtures/cxxbridge"
           "-DBUILD=${_b}" "-DCONFIG=${_cfg}"
           "-DGENERATOR=Unix Makefiles"
           "-DTARGETS=bridge-lib-cxx\\;cargo-build-bridge-lib-static"
# (the mediator is built EXPLICITLY: a STATIC consumer does not propagate
# the imported handle's auto-build edge -- that edge fires at final link;
# nothing here links a binary on purpose, keeping the leg cargo-cheap).
           "-DPASSTHROUGH=-DPOLYORCH_TEST_TOOL_PREFIX=${_stubs}\\;-DPOLYORCH_TEST_TOOL_VERSION=1.0.131")
execute_process(COMMAND "${CMAKE_COMMAND}" ${_dargs}
    -P "${CMAKE_CURRENT_LIST_DIR}/../fixtures/_driver.cmake"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
set(_dlog "${_out}${_err}")
drv_echo(_dlog)
if(_dlog MATCHES "DRIVER: skip")
    message(STATUS "t-rust-cxxbridge : SKIP (fixture gate: capability absent at configure)")
    return()
endif()
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "t-rust-cxxbridge: driver failed (${_rc})\n${_dlog}")
endif()

# Generated tree (layout mirror of corr:1879-1900: include/<cxx_t>/,
# include/rust/cxx.h, src/).
set(_g "${_b}/polyorch_generated/cxxbridge/bridge-lib-cxx")
ck_file("${_g}/include/rust/cxx.h")
file(READ "${_g}/include/rust/cxx.h" _cxxh)
ck(_cxxh MATCHES "polyorch-cxxbridge-stub")
ck(_cxxh MATCHES "#pragma once")
ck_file("${_g}/include/bridge-lib-cxx/bridge.h")
ck_file("${_g}/src/bridge.cpp")
file(READ "${_g}/src/bridge.cpp" _cpp)
ck(_cpp MATCHES "polyorch_cxxbridge_stub_symbol")
ck_file("${_g}/include/bridge-lib-cxx/sub/nested.h")
ck_file("${_g}/src/sub/nested.cpp")
# The static archive really compiled the generated source.
ck_file("${_b}/libbridge-lib-cxx.a")
# $<BUILD_INTERFACE:> include dir propagated to consumers (corr:1903-1907).
file(READ "${_b}/cxx_iface.txt" _iface)
ck(_iface MATCHES "polyorch_generated/cxxbridge/bridge-lib-cxx/include")

# Rule text (folded recipe lines rejoined, knobs pattern).
file(READ "${_b}/CMakeFiles/bridge-lib-cxx.dir/build.make" _mk)
string(REPLACE "\\\n" " " _mk "${_mk}")
ck(_mk MATCHES "--header --output")
ck(_mk MATCHES "--include bridge-lib-cxx/bridge[.]h")
ck(_mk MATCHES "rust/cxx[.]h")
ck(_mk MATCHES "sub/nested[.]cpp")

# Touch-reruns-on-source-change: the DEPENDS edge (corr:1959). regen-cxx
# depends on headers only, so this leg never re-enters cargo.
execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_b}" --target regen-cxx
    OUTPUT_QUIET ERROR_QUIET)
file(TOUCH "${CMAKE_CURRENT_LIST_DIR}/../fixtures/cxxbridge/rust/src/bridge.rs")
execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_b}" --target regen-cxx
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _o ERROR_VARIABLE _e)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "t-rust-cxxbridge: regen leg failed (${_rc}):\n${_o}${_e}")
endif()
string(REGEX REPLACE "[\r\n]+" " " _txt "${_o}${_e}")
if(NOT _txt MATCHES "Generating cxx bindings for crate bridge-lib and file bridge[.]rs")
    message(FATAL_ERROR
        "t-rust-cxxbridge: touch did not re-run the generation rule:\n${_o}${_e}")
endif()
message(STATUS "t-rust-cxxbridge : OK")
