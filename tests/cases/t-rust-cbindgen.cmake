# requires: posix-shell
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

# WP7 cbindgen cluster, offline legs.
#  A. _polyorch_rust_cbindgen_cmd argv tables -- corr:2224-2233 order
#     locked (cmake -E env TARGET= CARGO= RUSTC= tool --output --crate
#     [--depfile=] flags), including the ALWAYS-emitted env triple with
#     empty values (byte-for-byte the reference shape) and the FLAGS
#     tail. Guards on required keywords and unknown args.
#  B. Signature guards of the public face (child cmake -P: the HEADER_NAME
#     and both-signatures-absent FATALs fire before any setup read, so
#     script mode reaches them).
#  C. Stub-tool legs (posix shell, Unix Makefiles forced -- rule-text
#     reads, t-rust-knobs precedent): drives tests/fixtures/cbindgen.
#     The STUB echoes its environment into the generated header, so the
#     auto-mode triple (host layer -> HOST_TARGET through the empty-cross
#     normalization) and the manual-mode TARGET_TRIPLE are asserted
#     FUNCTIONALLY, not just in rule text. Cargo rules are generated but
#     only the regen targets build -- zero crate compilation here.

# ------------------------------------------------------------- A. argv tables --
_polyorch_rust_cbindgen_cmd(TOOL /tp/cbindgen CRATE mycrate OUTPUT /h/o.h
    TRIPLE t1 CARGO /c RUSTC /r OUT_CMD _c)
ck_str("${_c}"
    "${CMAKE_COMMAND};-E;env;TARGET=t1;CARGO=/c;RUSTC=/r;/tp/cbindgen;--output;/h/o.h;--crate;mycrate")

_polyorch_rust_cbindgen_cmd(TOOL /tp/cbindgen CRATE mycrate OUTPUT /h/o.h
    DEPFILE /d/o.h.d OUT_CMD _c)
ck_str("${_c}"
    "${CMAKE_COMMAND};-E;env;TARGET=;CARGO=;RUSTC=;/tp/cbindgen;--output;/h/o.h;--crate;mycrate;--depfile=/d/o.h.d")

_polyorch_rust_cbindgen_cmd(TOOL /tp/cbindgen CRATE mycrate OUTPUT /h/o.h
    DEPFILE /d/o.h.d FLAGS "f1;-O;/p" OUT_CMD _c)
ck_str("${_c}"
    "${CMAKE_COMMAND};-E;env;TARGET=;CARGO=;RUSTC=;/tp/cbindgen;--output;/h/o.h;--crate;mycrate;--depfile=/d/o.h.d;f1;-O;/p")

# ---------------------------------------------------------------- B. guards --
_polyorch_pixi_scratch(_s)
macro(cg_fail name rx)
    set(_body "${ARGN}")
    string(REPLACE ";" "\n" _body "${_body}")
    file(WRITE "${_s}/${name}.cmake"
        "include(\"${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake\")\n${_body}\nmessage(FATAL_ERROR \"GUARD-NOT-FIRED\")\n")
    execute_process(
        COMMAND "${CMAKE_COMMAND}" -P "${_s}/${name}.cmake"
        RESULT_VARIABLE _rc OUTPUT_VARIABLE _o ERROR_VARIABLE _e)
    string(REGEX REPLACE "[ \r\n\t]+" " " _txt "${_o}${_e}")
    if(_rc EQUAL 0)
        message(FATAL_ERROR "cg_fail(${name}): child exited 0, expected FATAL [${rx}]")
    endif()
    if(_txt MATCHES "GUARD-NOT-FIRED")
        message(FATAL_ERROR "cg_fail(${name}): call passed validation")
    endif()
    if(NOT _txt MATCHES "${rx}")
        message(FATAL_ERROR "cg_fail(${name}): rc=${_rc} but output lacks [${rx}]: ${_txt}")
    endif()
endmacro()

cg_fail(cg-planner-noout "_polyorch_rust_cbindgen_cmd: missing required argument 'C_OUTPUT'"
    "_polyorch_rust_cbindgen_cmd(TOOL t CRATE c OUT_CMD _o)")
cg_fail(cg-planner-badarg "_polyorch_rust_cbindgen_cmd: unknown args: --wat"
    "_polyorch_rust_cbindgen_cmd(TOOL t --wat CRATE c OUTPUT o OUT_CMD _o)")
cg_fail(cg-noheader "polyorch_rust_cbindgen: missing required parameter .HEADER_NAME."
    "polyorch_rust_cbindgen(TARGET x)")
cg_fail(cg-nosig "unknown signature"
    "polyorch_rust_cbindgen(HEADER_NAME h.h)")
cg_fail(cg-manual-partial "unknown signature"
    "polyorch_rust_cbindgen(HEADER_NAME h.h MANIFEST_DIRECTORY /tmp BINDINGS_TARGET iface)")
# The unknown-TARGET guard fires AFTER _polyorch_rust_require_setup, so
# the child needs a faked setup cache -- passed as -D cache entries
# (bracket-quoted body: no escape acrobatics).
file(WRITE "${_s}/cg-unknowntarget.cmake"
    "include(\"${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake\")\n"
    "polyorch_rust_cbindgen(TARGET nope-lib HEADER_NAME h.h)\n"
    "message(FATAL_ERROR \"GUARD-NOT-FIRED\")\n")
execute_process(
    COMMAND "${CMAKE_COMMAND}"
        -DPOLYORCH_RUST_FOUND:BOOL=TRUE
        -DPOLYORCH_RUST_CARGO:FILEPATH=${CMAKE_COMMAND}
        -DPOLYORCH_RUST_HOST_TARGET:STRING=x86_64-unknown-linux-gnu
        -P "${_s}/cg-unknowntarget.cmake"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _o ERROR_VARIABLE _e)
string(REGEX REPLACE "[ \r\n\t]+" " " _txt "${_o}${_e}")
if(_rc EQUAL 0 OR _txt MATCHES "GUARD-NOT-FIRED" OR NOT _txt MATCHES "is not a known target")
    message(FATAL_ERROR "cg-unknowntarget guard failed (rc=${_rc}): ${_txt}")
endif()

# ---------------------------------------------------- C. stub-tool rule legs --
polyorch_requires(posix-shell _req)
if(NOT _req)
    message(STATUS "t-rust-cbindgen : SKIP (posix shell stubs need a UNIX host)")
    return()
endif()

set(_cfg "$ENV{POLYORCH_TEST_CONFIG}")
if(NOT _cfg)
    set(_cfg Debug)
endif()
set(_b "${_s}/cgchild")
set(_stubs "${CMAKE_CURRENT_LIST_DIR}/../fixtures/tool-stubs")
drv_run(_dlog _rc SKIP_VAR _skip
    FIXTURE "${CMAKE_CURRENT_LIST_DIR}/../fixtures/cbindgen"
    BUILD "${_b}"
    CONFIG "${_cfg}"
    GENERATOR "Unix Makefiles"
    TARGETS polyorch-cbindgen-cb-lib-bindings\;polyorch-cbindgen-cb-manual-bindings
    PASSTHROUGH -DPOLYORCH_TEST_TOOL_PREFIX=${_stubs})
if(_skip)
    message(STATUS "t-rust-cbindgen : SKIP (fixture gate: capability absent at configure)")
    return()
endif()

# Functional env assertion through the stub header (auto leg): the host
# layer normalizes the effective triple to HOST_TARGET (the reference's
# corr:2114 switch with the PolyOrch empty-cross convention).
file(READ "${_b}/host_triple.txt" _host)
string(STRIP "${_host}" _host)
set(_g "${_b}/polyorch_generated/cbindgen")
ck_file("${_g}/cb-lib/include/rust-lib.h")
file(READ "${_g}/cb-lib/include/rust-lib.h" _ah)
ck(_ah MATCHES "polyorch-cbindgen-stub")
ck(_ah MATCHES "#pragma once")
ck(_ah MATCHES "void cb_fixture_stub_marker[(]void[)]")
ck(_ah MATCHES "TARGET=${_host} CARGO=")
# CARGO=/RUSTC=/ answered with the real setup paths (system route).
ck(_ah MATCHES "CARGO=/.+ RUSTC=/.+")
# depfile written by the stub at the path the rule passed.
ck_file("${_g}/cb-lib/depfile/rust-lib.h.d")

# Manual leg: explicit TARGET_TRiple literal + HEADER_NAME with a relative
# directory (corr:2210-2213).
ck_file("${_g}/cb-manual/include/sub/manual.h")
file(READ "${_g}/cb-manual/include/sub/manual.h" _mh)
ck(_mh MATCHES "TARGET=x86_64-unknown-linux-musl ")
ck_file("${_g}/cb-manual/depfile/sub/manual.h.d")

# Rule text of the auto leg (folded lines rejoined): the full -E env
# prefix, the crate, the depfile argument.
file(READ "${_b}/CMakeFiles/polyorch-cbindgen-cb-lib-bindings.rust_lib_h.dir/build.make" _mk)
string(REPLACE "\\\n" " " _mk "${_mk}")
ck(_mk MATCHES "-E env TARGET=")
ck(_mk MATCHES "--crate cb_fixture")
ck(_mk MATCHES "--depfile=")
# WORKING_DIRECTORY of the manifest dir materializes as the cd prefix
# (corr:2237) -- the generation sees the crate as its own workspace.
ck(_mk MATCHES "cd .+fixtures/cbindgen/rust &&")
# Env answered with real setup paths, no --unset leakage on this prefix
# (the reference emits a bare -E env here, corr:2224 -- no strip).
ck(_mk MATCHES "-E env TARGET=.+ CARGO=/")
ck(NOT _mk MATCHES "--unset")

# Re-runnability: a DEPFILE-carrying custom command under Makefiles gains
# the compiler_depend.ts toolstamp prerequisite and is re-issued on every
# build (CMake's deps machinery -- the reference's corr:2235 has the same
# property). The contract that matters: the second run SUCCEEDS and the
# header content is stable (the tool, not CMake, owns change detection).
file(READ "${_g}/cb-lib/include/rust-lib.h" _ah1)
execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_b}"
    --target polyorch-cbindgen-cb-lib-bindings
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _o ERROR_VARIABLE _e)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "t-rust-cbindgen: regen re-run failed (${_rc}):\n${_o}${_e}")
endif()
file(READ "${_g}/cb-lib/include/rust-lib.h" _ah2)
ck_str("${_ah2}" "${_ah1}")
message(STATUS "t-rust-cbindgen : OK")
