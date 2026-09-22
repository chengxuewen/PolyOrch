include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")

# Table lock for the two WP4 pure helpers (corr:130-148 + corr:334-337
# ports): _polyorch_rust_copy_plan (artifact staging pairs, incl. the
# gnullvm deps/ importlib relocation) and _polyorch_rust_sanitized_out_dir
# ($<CONFIG>-only output dirs). Offline; rejection legs re-exec a written
# child script (same shape as t-rust-setters' ck_call_fail).
_polyorch_pixi_scratch(_s)

macro(ck_call_fail name rx)
    set(_cf_body "${ARGN}")
    string(REPLACE ";" "\n" _cf_body "${_cf_body}")
    file(WRITE "${_s}/${name}.cmake"
        "include(\"${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake\")\n${_cf_body}\nmessage(FATAL_ERROR \"GUARD-NOT-FIRED\")\n")
    execute_process(
        COMMAND "${CMAKE_COMMAND}" -P "${_s}/${name}.cmake"
        RESULT_VARIABLE _cf_rc OUTPUT_VARIABLE _cf_o ERROR_VARIABLE _cf_e)
    string(REGEX REPLACE "[ \r\n\t]+" " " _cf_txt "${_cf_o}${_cf_e}")
    if(_cf_rc EQUAL 0)
        message(FATAL_ERROR "ck_call_fail(${name}): child exited 0, expected FATAL [${rx}]")
    endif()
    if(_cf_txt MATCHES "GUARD-NOT-FIRED")
        message(FATAL_ERROR "ck_call_fail(${name}): call passed validation (sentinel reached)")
    endif()
    if(NOT _cf_txt MATCHES "${rx}")
        message(FATAL_ERROR "ck_call_fail(${name}): rc=${_cf_rc} but output lacks [${rx}]: ${_cf_txt}")
    endif()
endmacro()

# t_pair <triple> <kind> <expect-src> <expect-dst-or-EMPTY>
# (SRC_DIR /p/td/debug and DEST_DIR /p/out are the glue inputs verbatim)
macro(t_pair tr kl es ed)
    _polyorch_rust_copy_plan(TRIPLE "${tr}" KIND "${kl}" CRATE greet
        SRC_DIR /p/td/debug DEST_DIR /p/out OUT _p)
    if("${ed}" STREQUAL "EMPTY")
        ck_str("${_p}" "")
    else()
        ck_str("${_p}" "${es}|${ed}")
    endif()
endmacro()

# --- main artifacts: the naming table glued to src/dest -----------------------
t_pair(x86_64-unknown-linux-gnu bin    /p/td/debug/greet     /p/out/greet)
t_pair(x86_64-unknown-linux-gnu static /p/td/debug/libgreet.a /p/out/libgreet.a)
t_pair(x86_64-unknown-linux-gnu shared /p/td/debug/libgreet.so /p/out/libgreet.so)
t_pair(aarch64-apple-darwin    shared /p/td/debug/libgreet.dylib /p/out/libgreet.dylib)
t_pair(x86_64-pc-windows-msvc  shared /p/td/debug/greet.dll   /p/out/greet.dll)
t_pair(x86_64-pc-windows-gnu   shared /p/td/debug/greet.dll   /p/out/greet.dll)
# --- import libraries --------------------------------------------------------
t_pair(x86_64-unknown-linux-gnu implib ""  EMPTY)
t_pair(aarch64-apple-darwin     implib ""  EMPTY)
t_pair(x86_64-pc-windows-msvc   implib /p/td/debug/greet.dll.lib  /p/out/greet.dll.lib)
t_pair(x86_64-pc-windows-gnu    implib /p/td/debug/libgreet.dll.a /p/out/libgreet.dll.a)
# gnullvm: cargo emits the implib under deps/ (corr:334-337); dst keeps the
# bare name. Both spellings in the wild are table-locked:
t_pair(x86_64-w64-windows-gnullvm implib /p/td/debug/deps/libgreet.dll.a /p/out/libgreet.dll.a)
# linux-gnullvm has NO dll.a at all (elf family): empty plan, not an error.
t_pair(x86_64-unknown-linux-gnullvm implib "" EMPTY)
# genex directory strings are glued verbatim (caller-owned evaluation):
_polyorch_rust_copy_plan(TRIPLE x86_64-unknown-linux-gnu KIND bin CRATE greet
    SRC_DIR "/p/td/$<IF:$<CONFIG:Debug>,debug,release>" DEST_DIR "/p/out/$<CONFIG>"
    OUT _p)
ck_str("${_p}" "/p/td/$<IF:$<CONFIG:Debug>,debug,release>/greet|/p/out/$<CONFIG>/greet")

# --- sanitize table -----------------------------------------------------------
macro(t_sani dir cfg want)
    unset(_sd)
    _polyorch_rust_sanitized_out_dir("${dir}" "${cfg}" _sd)
    if("${want}" STREQUAL "UNDEF")
        if(DEFINED _sd)
            message(FATAL_ERROR "t_sani(${dir}): expected undefined result, got [${_sd}]")
        endif()
    else()
        ck_str("${_sd}" "${want}")
    endif()
endmacro()
t_sani("/p/out"                  Release "/p/out")
t_sani("/p/out/$<CONFIG>"        Release "/p/out/Release")
t_sani("/p/out/$<CONFIG>"        Debug   "/p/out/Debug")
# empty config: the placeholder AND its preceding slash vanish (no "dir//sub")
t_sani("/p/out/$<CONFIG>"        ""      "/p/out")
t_sani("/p/out/$<CONFIG>/sub"    ""      "/p/out/sub")
# anything beyond $<CONFIG> leaves the result undefined for the caller
t_sani("/p/out/$<TARGET_FILE:x>" Release UNDEF)
t_sani("$<CONFIG:$<CONFIG>>"    Release UNDEF)

# --- rejection legs (children) -------------------------------------------------
ck_call_fail(cp-bad-triple
    "polyorch_rust: unrecognized target triple"
    "_polyorch_rust_copy_plan(TRIPLE bogus-triple KIND bin CRATE greet SRC_DIR /s DEST_DIR /d OUT o)")
ck_call_fail(cp-bad-kind
    "copy-plan KIND must be bin|static|shared|implib"
    "_polyorch_rust_copy_plan(TRIPLE x86_64-unknown-linux-gnu KIND weird CRATE greet SRC_DIR /s DEST_DIR /d OUT o)")
ck_call_fail(cp-missing-arg
    "polyorch_rust: missing required argument"
    "_polyorch_rust_copy_plan(TRIPLE x86_64-unknown-linux-gnu KIND bin CRATE greet DEST_DIR /d OUT o)")

message(STATUS "rust-copy-plan: OK (plan + sanitize tables locked)")
