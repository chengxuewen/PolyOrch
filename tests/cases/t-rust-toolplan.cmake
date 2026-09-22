# requires: posix-shell
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

# WP7 tool-bootstrap face, offline legs.
#  A. _polyorch_rust_tool_version_check pure tables -- the lock-compare
#     semantics (corr:1839 VERSION_EQUAL exactness, no range logic); an
#     empty operand on either side is FALSE (a missing actual never
#     matches, a missing pin never "matches" -- the caller decides).
#  B. polyorch_rust_tool_bootstrap discovery legs against a STUB tool
#     script written into scratch (script-mode safe: no rules created,
#     no cargo needed): PREFIX/bin search hit, version gate hit/miss,
#     miss-without-ALLOW_INSTALL deferral (the exact STATUS phrase +
#     FALSE + NOTFOUND cache), and the ALLOW_INSTALL branch in script
#     mode (guard fires: cache + TRUE + NO target -- the rule creation
#     is the same CMAKE_SCRIPT_MODE_FILE skip class as the imported
#     handles in polyorch_rust_setup). The live cargo-install leg needs
#     crates.io + the shared-state authorization and rides with the
#     gated tool e2e cases, never here.

_polyorch_pixi_scratch(_s)

# ------------------------------------------------------- A. version tables --
function(_tv pin actual out)
    _polyorch_rust_tool_version_check("${pin}" "${actual}" _ok)
    if(_ok)
        set(${out} TRUE PARENT_SCOPE)
    else()
        set(${out} FALSE PARENT_SCOPE)
    endif()
endfunction()

_tv("1.0.131" "1.0.131" _r)   # exact lock equality
ck(_r)
_tv("1.0.131" "1.0.130" _r)  # patch delta fails
ck(NOT _r)
_tv("1.0.131" "1.0.132" _r)  # newer is still a MISS (exactness)
ck(NOT _r)
_tv("1.0" "1.0.0" _r)        # cmake VERSION_EQUAL component form
ck(_r)
_tv("2.0.0" "1.9.9" _r)
ck(NOT _r)
_tv("" "1.0.0" _r)           # empty pin -> FALSE (caller decides)
ck(NOT _r)
_tv("1.0.0" "" _r)           # empty actual -> FALSE
ck(NOT _r)
_tv("" "" _r)
ck(NOT _r)

# ------------------------------------------------------ B. bootstrap legs ---
set(_bin "${_s}/tbprefix/bin")
file(MAKE_DIRECTORY "${_bin}")
file(WRITE "${_bin}/cxxbridge"
    "#!/bin/sh\nif [ \"x$1\" = x--version ]; then echo \"cxxbridge 1.0.131\"; exit 0; fi\nexit 0\n")
file(WRITE "${_bin}/cxxold"
    "#!/bin/sh\nif [ \"x$1\" = x--version ]; then echo \"cxxbridge 1.0.90\"; exit 0; fi\nexit 0\n")
file(CHMOD "${_bin}/cxxbridge" "${_bin}/cxxold"
    PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)

# (b1) PREFIX/bin hit, no version pin -> TRUE, cache holds the stub path.
unset(CXXBRIDGE_CMD_TOOL CACHE)
polyorch_rust_tool_bootstrap(TOOL cxxbridge-cmd BINARY cxxbridge
    PREFIX "${_s}/tbprefix" OUT_VAR _ok)
ck(_ok)
ck_str("${CXXBRIDGE_CMD_TOOL}" "${_bin}/cxxbridge")

# (b2) version gate: pin matches the stub's --version -> TRUE.
unset(CXXBRIDGE_CMD_TOOL CACHE)
polyorch_rust_tool_bootstrap(TOOL cxxbridge-cmd BINARY cxxbridge VERSION 1.0.131
    PREFIX "${_s}/tbprefix" OUT_VAR _ok)
ck(_ok)

# (b3) version gate miss: the search hits the old stub but 1.0.90 != the
# pin -> the wrong-version tool is demoted to NOTFOUND and the call defers.
unset(CXXOLD_TOOL CACHE)
polyorch_rust_tool_bootstrap(TOOL cxxold BINARY cxxold VERSION 1.0.131
    PREFIX "${_s}/tbprefix" OUT_VAR _ok)
ck(NOT _ok)
ck(CXXOLD_TOOL MATCHES "NOTFOUND$")
# (b4) absent tool, no ALLOW_INSTALL -> exact deferred phrase + FALSE.
unset(CXXBRIDGE_TOOL CACHE)
polyorch_rust_tool_bootstrap(TOOL cxxbridge BINARY cxxbridge-absent
    PREFIX "${_s}/tbprefix" OUT_VAR _ok)
ck(NOT _ok)
ck(CXXBRIDGE_TOOL MATCHES "NOTFOUND$")

# Deferral phrase: captured from a child (STATUS never reaches the
# parent's own flow control).
file(WRITE "${_s}/tb-phrase.cmake"
    "include(\"${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake\")\n" 
    "polyorch_rust_tool_bootstrap(TOOL cxxbridge BINARY cxxbridge-absent PREFIX \"${_s}/tbprefix\" OUT_VAR _o)\n")
execute_process(COMMAND "${CMAKE_COMMAND}" -P "${_s}/tb-phrase.cmake"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _o ERROR_VARIABLE _e)
ck_str("${_rc}" "0")
string(REGEX REPLACE "[ \r\n\t]+" " " _txt "${_o}${_e}")
if(NOT _txt MATCHES "live bootstrap deferred .network gate.")
    message(FATAL_ERROR "t-rust-toolplan: deferral phrase missing from child output: ${_txt}")
endif()

# (b5) ALLOW_INSTALL in script mode: the rule-creation guard fires (no
# target registry in cmake -P), so the branch still resolves the cache to
# the build-tree path, reports TRUE and an EMPTY OUT_TARGET (rules are
# never created in script mode -- same guard class as the imported
# handles in polyorch_rust_setup). The setup cache is faked the way
# t-rust-knobs fakes it; no toolchain is executed.
unset(DEMO_TOOL CACHE)
set(POLYORCH_RUST_FOUND TRUE CACHE INTERNAL "")
set(POLYORCH_RUST_CARGO "${CMAKE_COMMAND}" CACHE INTERNAL "")
set(POLYORCH_RUST_RUSTC "${CMAKE_COMMAND}" CACHE INTERNAL "")
set(POLYORCH_RUST_HOST_TARGET "x86_64-unknown-linux-gnu" CACHE INTERNAL "")
set(POLYORCH_RUST_ROUTE "system" CACHE INTERNAL "")
set(POLYORCH_RUST_BIN_DIR "" CACHE INTERNAL "")
set(POLYORCH_RUST_CARGO_TARGET "" CACHE INTERNAL "")
polyorch_rust_tool_bootstrap(TOOL demo ALLOW_INSTALL VERSION 9.9.9
    PREFIX "${_s}/tbinstall" LOCKED QUIET OUT_VAR _ok OUT_TARGET _t)
ck(_ok)
ck_str("${_t}" "")
ck_str("${DEMO_TOOL}" "${_s}/tbinstall/bin/demo${CMAKE_EXECUTABLE_SUFFIX}")
unset(POLYORCH_RUST_FOUND CACHE)
unset(POLYORCH_RUST_CARGO CACHE)
unset(POLYORCH_RUST_RUSTC CACHE)
unset(POLYORCH_RUST_HOST_TARGET CACHE)
unset(POLYORCH_RUST_ROUTE CACHE)
unset(POLYORCH_RUST_BIN_DIR CACHE)
unset(POLYORCH_RUST_CARGO_TARGET CACHE)

# (b6) cache-name derivation: dashes normalize to underscores.
unset(CXXBRIDGE_CMD_TOOL CACHE)
polyorch_rust_tool_bootstrap(TOOL cxxbridge-cmd BINARY cxxbridge-absent
    PREFIX "${_s}/tbprefix" OUT_VAR _ok)
ck(NOT _ok)
ck(DEFINED CACHE{CXXBRIDGE_CMD_TOOL})

# (b7) guards: missing TOOL and unknown arguments FATAL.
macro(tb_fail name rx)
    set(_body "${ARGN}")
    string(REPLACE ";" "\n" _body "${_body}")
    file(WRITE "${_s}/${name}.cmake"
        "include(\"${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake\")\n${_body}\nmessage(FATAL_ERROR \"GUARD-NOT-FIRED\")\n")
    execute_process(
        COMMAND "${CMAKE_COMMAND}" -P "${_s}/${name}.cmake"
        RESULT_VARIABLE _rc OUTPUT_VARIABLE _o ERROR_VARIABLE _e)
    string(REGEX REPLACE "[ \r\n\t]+" " " _txt "${_o}${_e}")
    if(_rc EQUAL 0)
        message(FATAL_ERROR "tb_fail(${name}): child exited 0, expected FATAL [${rx}]")
    endif()
    if(_txt MATCHES "GUARD-NOT-FIRED")
        message(FATAL_ERROR "tb_fail(${name}): call passed validation")
    endif()
    if(NOT _txt MATCHES "${rx}")
        message(FATAL_ERROR "tb_fail(${name}): rc=${_rc} but output lacks [${rx}]: ${_txt}")
    endif()
endmacro()

tb_fail(tb-notool "polyorch_rust_tool_bootstrap: missing required parameter TOOL"
    "polyorch_rust_tool_bootstrap(BINARY x OUT_VAR _o)")
tb_fail(tb-badarg "polyorch_rust_tool_bootstrap: unknown args: --wat"
    "polyorch_rust_tool_bootstrap(TOOL x --wat OUT_VAR _o)")

message(STATUS "t-rust-toolplan : OK")
