include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")

# WP5b linker control plane, offline legs. Fidelity context (ledgered): the
# pinned c4786e7 checkout contains NO CROSSCOMPILING_EMULATOR / RUNNER /
# embedded-linker mechanism (grep-verified absent), so the CONDITION LOGIC
# here is table-locked against the cargo env contract
# (CARGO_TARGET_<TUP>_LINKER / _RUNNER) and the two ported lessons: the
# wrapper file is configure-time materialized and NEVER a custom-command
# OUTPUT, and env values carry no shell quoting. No qemu presence is
# required or faked: children inject a FAKE emulator list and the rules are
# only GENERATED (cmake-as-cargo, nothing builds or executes).
#
# Legs:
#  A. _polyorch_rust_linker_plan pure tables (explicit > wrapper > default;
#     runner independent of the linker decision; msvc/macho/COFF guards;
#     ambient cache/format defaults);
#  B. generated-rule children: explicit knob, wrapper materialization,
#     default cc/c++ pick (CXX via link_libraries' recorded
#     LINKER_LANGUAGE, a generate-time late read), sysroot + compiler-target
#     -Clink-arg= additions and their hostbuild gate, LIBRARY_PATH join,
#     the STATIC-kind interface forwarding of polyorch_rust_link_libraries,
#     and the host layer's total linker-plane silence.
#  C. polyorch_rust_run's emulator prefix.

_polyorch_pixi_scratch(_s)
set(_cmkedir "${CMAKE_CURRENT_LIST_DIR}/../../cmake")

# ------------------------------------------------------------- plan tables --
# Direct calls (no macro: a macro would re-split ${ARGN} on the emulator
# list semicolons -- the very contract these legs lock).
set(_tn "")
set(_tv "")
set(_tw "")
set(_tc "")
set(_tr "")

# (a) explicit wins over everything (and suppresses the wrapper); no
# emulator -> no runner.
_polyorch_rust_linker_plan(TRIPLE x86_64-unknown-linux-musl EXPLICIT /my/ld EMULATOR "" EXEC_FORMAT "" WRAPPER_DIR /w OUT_ENV_NAME _tn OUT_VALUE _tv OUT_WRAPPER _tw OUT_WRAPPER_CONTENT _tc OUT_RUNNER _tr)
ck_str("${_tn}" "CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_LINKER")
ck_str("${_tv}" "/my/ld")
ck_str("${_tw}" "")
ck_str("${_tr}" "")

# (b) shell-style emulator -> wrapper + runner; content contract-checked
file(WRITE "${_s}/emu.sh" "#!/bin/sh\nexit 0\n")
_polyorch_rust_linker_plan(TRIPLE x86_64-unknown-linux-musl EXPLICIT "" EMULATOR "${_s}/emu.sh;-L;/sys" EXEC_FORMAT "" WRAPPER_DIR /w OUT_ENV_NAME _tn OUT_VALUE _tv OUT_WRAPPER _tw OUT_WRAPPER_CONTENT _tc OUT_RUNNER _tr)
ck_str("${_tv}" "")
ck_str("${_tw}" "/w/x86_64-unknown-linux-musl-linker")
ck_str("${_tr}" "CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_RUNNER=${_s}/emu.sh -L /sys")
ck(_tc MATCHES "^#!/bin/sh")
ck(_tc MATCHES "exec .*[$]@")

# (c) bare qemu binary: runner only -- a runner is NOT a linker driver
_polyorch_rust_linker_plan(TRIPLE armv7-unknown-linux-gnueabihf EXPLICIT "" EMULATOR "qemu-arm;-L;/sysroot" EXEC_FORMAT "" WRAPPER_DIR /w OUT_ENV_NAME _tn OUT_VALUE _tv OUT_WRAPPER _tw OUT_WRAPPER_CONTENT _tc OUT_RUNNER _tr)
ck_str("${_tn}" "CARGO_TARGET_ARMV7_UNKNOWN_LINUX_GNUEABIHF_LINKER")
ck_str("${_tv}" "")
ck_str("${_tw}" "")
ck_str("${_tr}" "CARGO_TARGET_ARMV7_UNKNOWN_LINUX_GNUEABIHF_RUNNER=qemu-arm -L /sysroot")

# (d) explicit + emulator coexist: linker explicit, runner STILL forwarded
# (the two knobs are independent -- execution vs linking)
_polyorch_rust_linker_plan(TRIPLE x86_64-unknown-linux-musl EXPLICIT /my/ld EMULATOR "qemu-musl" EXEC_FORMAT "" WRAPPER_DIR /w OUT_ENV_NAME _tn OUT_VALUE _tv OUT_WRAPPER _tw OUT_WRAPPER_CONTENT _tc OUT_RUNNER _tr)
ck_str("${_tv}" "/my/ld")
ck_str("${_tw}" "")
ck_str("${_tr}" "CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_RUNNER=qemu-musl")

# (e) guards: msvc is absolute; macho and COFF veto the auto plane;
# explicit remains honored on windows-gnu (guard covers AUTO only)
_polyorch_rust_linker_plan(TRIPLE x86_64-pc-windows-msvc EXPLICIT "" EMULATOR "wine" EXEC_FORMAT "" WRAPPER_DIR /w OUT_ENV_NAME _tn OUT_VALUE _tv OUT_WRAPPER _tw OUT_WRAPPER_CONTENT _tc OUT_RUNNER _tr)
ck_str("${_tn}" "")
ck_str("${_tv}" "")
ck_str("${_tw}" "")
ck_str("${_tr}" "")
_polyorch_rust_linker_plan(TRIPLE aarch64-apple-ios EXPLICIT "" EMULATOR "sim-runner.sh" EXEC_FORMAT "" WRAPPER_DIR /w OUT_ENV_NAME _tn OUT_VALUE _tv OUT_WRAPPER _tw OUT_WRAPPER_CONTENT _tc OUT_RUNNER _tr)
ck_str("${_tn}" "CARGO_TARGET_AARCH64_APPLE_IOS_LINKER")
ck_str("${_tv}" "")
ck_str("${_tw}" "")
ck_str("${_tr}" "")
_polyorch_rust_linker_plan(TRIPLE x86_64-pc-windows-gnu EXPLICIT "" EMULATOR "${_s}/emu.sh" EXEC_FORMAT "COFF" WRAPPER_DIR /w OUT_ENV_NAME _tn OUT_VALUE _tv OUT_WRAPPER _tw OUT_WRAPPER_CONTENT _tc OUT_RUNNER _tr)
ck_str("${_tw}" "")
ck_str("${_tr}" "")
_polyorch_rust_linker_plan(TRIPLE x86_64-pc-windows-gnu EXPLICIT /x/clang-lld EMULATOR "" EXEC_FORMAT "COFF" WRAPPER_DIR /w OUT_ENV_NAME _tn OUT_VALUE _tv OUT_WRAPPER _tw OUT_WRAPPER_CONTENT _tc OUT_RUNNER _tr)
ck_str("${_tn}" "CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER")
ck_str("${_tv}" "/x/clang-lld")

# (f) ambient defaults: unset EXPLICIT keyword reads the per-triple cache
# knob; unset EXEC_FORMAT reads CMAKE_EXECUTABLE_FORMAT.
set(PolyOrch_RUST_LINKER_X86_64_UNKNOWN_LINUX_MUSL "/ambient/ld")
set(CMAKE_EXECUTABLE_FORMAT "COFF")
_polyorch_rust_linker_plan(TRIPLE x86_64-unknown-linux-musl EMULATOR "" WRAPPER_DIR /w OUT_ENV_NAME _tn OUT_VALUE _tv OUT_WRAPPER _tw OUT_WRAPPER_CONTENT _tc OUT_RUNNER _tr)
ck_str("${_tv}" "/ambient/ld")
unset(PolyOrch_RUST_LINKER_X86_64_UNKNOWN_LINUX_MUSL)
unset(CMAKE_EXECUTABLE_FORMAT)

# ------------------------------------------------- generated-rule children --
# lp_make(<name> <langs> <xt> <expl> <emu-or-NONE> <cc> <sys> <ctt>
#        <libs> <hb> <cxxlib> <kind> <run0|run1>): configure-only child.
file(WRITE "${_s}/_lp.in" [==[
cmake_minimum_required(VERSION 3.25)
project(polyorch-linkplan LANGUAGES @LANGS@)
list(APPEND CMAKE_MODULE_PATH "@CMKEDIR@")
include(PolyOrchRustHelpers)
set(POLYORCH_RUST_FOUND TRUE CACHE INTERNAL "")
set(POLYORCH_RUST_CARGO "@CMAKECMD@" CACHE INTERNAL "")
set(POLYORCH_RUST_RUSTC "@CMAKECMD@" CACHE INTERNAL "")
set(POLYORCH_RUST_HOST_TARGET "x86_64-unknown-linux-gnu" CACHE INTERNAL "")
set(POLYORCH_RUST_ROUTE "system" CACHE INTERNAL "")
set(POLYORCH_RUST_BIN_DIR "" CACHE INTERNAL "")
set(POLYORCH_RUST_CARGO_TARGET "@XT@" CACHE INTERNAL "")
set(PolyOrch_RUST_LINKER_X86_64_UNKNOWN_LINUX_MUSL "@EXPL@" CACHE INTERNAL "")
# test-only injections of toolchain-shaping variables (a real configure sets
# them via the toolchain file; the generated rule reads them identically):
set(CMAKE_CROSSCOMPILING_EMULATOR @EMUV@)
set(CMAKE_CROSSCOMPILING @CC@)
set(CMAKE_SYSROOT "@SYS@")
set(CMAKE_C_COMPILER_TARGET "@CTT@")
add_library(clib STATIC clib.c)
@CXXLIB@
polyorch_rust_build(TARGET lp-bin PACKAGE hello CRATE hello-cli @KIND@)
@LIBS@get_target_property(_if lp-bin INTERFACE_LINK_LIBRARIES)
file(WRITE "${CMAKE_BINARY_DIR}/iface.txt" "${_if}")
@HBK@@RUN@
]==])

function(lp_make name langs xt expl emu cc sys ctt libs hb cxxlib kind run)
    set(_d "${_s}/lp-${name}")
    file(MAKE_DIRECTORY "${_d}")
    file(WRITE "${_d}/clib.c" "int clib_marker(void) { return 7; }\n")
    if(cxxlib)
        file(WRITE "${_d}/cxlib.cpp" "int cx_marker() { return 8; }\n")
    endif()
    file(READ "${_s}/_lp.in" _tpl)
    if(emu STREQUAL "NONE")
        set(_v "")
    else()
        set(_v "\"${emu}\"")
    endif()
    if(cxxlib)
        set(_cxx "add_library(cxlib STATIC cxlib.cpp)")
    else()
        set(_cxx "")
    endif()
    if(hb)
        set(_hb "polyorch_rust_set_hostbuild(TARGET lp-bin)\n")
    else()
        set(_hb "")
    endif()
    if(run)
        set(_run "polyorch_rust_run(TARGET lp-bin)\n")
    else()
        set(_run "")
    endif()
    string(REPLACE "@CMKEDIR@" "${_cmkedir}" _tpl "${_tpl}")
    string(REPLACE "@CMAKECMD@" "${CMAKE_COMMAND}" _tpl "${_tpl}")
    string(REPLACE "@LANGS@" "${langs}" _tpl "${_tpl}")
    string(REPLACE "@XT@" "${xt}" _tpl "${_tpl}")
    string(REPLACE "@EXPL@" "${expl}" _tpl "${_tpl}")
    string(REPLACE "@EMUV@" "${_v}" _tpl "${_tpl}")
    string(REPLACE "@CC@" "${cc}" _tpl "${_tpl}")
    string(REPLACE "@SYS@" "${sys}" _tpl "${_tpl}")
    string(REPLACE "@CTT@" "${ctt}" _tpl "${_tpl}")
    string(REPLACE "@LIBS@" "${libs}" _tpl "${_tpl}")
    string(REPLACE "@CXXLIB@" "${_cxx}" _tpl "${_tpl}")
    string(REPLACE "@KIND@" "${kind}" _tpl "${_tpl}")
    string(REPLACE "@HBK@" "${_hb}" _tpl "${_tpl}")
    string(REPLACE "@RUN@" "${_run}" _tpl "${_tpl}")
    file(WRITE "${_d}/CMakeLists.txt" "${_tpl}")
    execute_process(COMMAND "${CMAKE_COMMAND}" -G "Unix Makefiles"
        -S "${_d}" -B "${_d}/b"
        RESULT_VARIABLE _rc OUTPUT_VARIABLE _o ERROR_VARIABLE _e)
    if(NOT _rc EQUAL 0)
        message(FATAL_ERROR "lp child ${name} configure failed (${_rc}):\n${_o}${_e}")
    endif()
    set(_mkf "${_d}/b/CMakeFiles/cargo-build-lp-bin.dir/build.make")
    ck_file("${_mkf}")
    file(READ "${_mkf}" _mkt)
    string(REPLACE "\\\n" " " _mkt "${_mkt}")
    set(_lp_mk "${_mkt}" PARENT_SCOPE)
    set(_lp_d "${_d}" PARENT_SCOPE)
endfunction()

# literal-substring macros (paths and flags contain regex metacharacters)
macro(lp_has tok)
    string(FIND "${_lp_mk}" "${tok}" _lp_f)
    if(_lp_f EQUAL -1)
        message(FATAL_ERROR "linkplan child: rule lacks [${tok}]")
    endif()
endmacro()
macro(lp_lacks tok)
    string(FIND "${_lp_mk}" "${tok}" _lp_f)
    if(NOT _lp_f EQUAL -1)
        message(FATAL_ERROR "linkplan child: rule must NOT contain [${tok}]")
    endif()
endmacro()
macro(lp_pos needle before)   # needle strictly after the first [before]
    string(FIND "${_lp_mk}" "${before}" _pb)
    string(FIND "${_lp_mk}" "${needle}" _pn)
    if(_pb EQUAL -1 OR _pn LESS_EQUAL _pb)
        message(FATAL_ERROR "linkplan child: [${needle}] not after [${before}] (${_pb}/${_pn})")
    endif()
endmacro()
function(lp_cache_val dir var out)
    file(STRINGS "${dir}/b/CMakeCache.txt" _lcv REGEX "^${var}:")
    list(GET _lcv 0 _l0)
    string(REGEX REPLACE "^[^=]*=(.*)$" "\\1" _v "${_l0}")
    set(${out} "${_v}" PARENT_SCOPE)
endfunction()

set(_mu "CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL")

# --- B1: explicit knob + emulator coexist (cross) ----------------------------
string(REPLACE ";" "\\;" _emu_esc "${_s}/emu.sh;-L;/sys")
lp_make(expl C "x86_64-unknown-linux-musl" "/my/ld" "${_emu_esc}" TRUE "" "" "" FALSE FALSE BINARY 1)
lp_has("${_mu}_LINKER=/my/ld")
lp_has("${_mu}_RUNNER=${_s}/emu.sh -L /sys")
lp_pos("${_mu}_LINKER=/my/ld" "--unset=RUSTFLAGS")
lp_pos("${_mu}_RUNNER=" "--unset=RUSTFLAGS")
if(EXISTS "${_lp_d}/b/.polyorch-rust/x86_64-unknown-linux-musl-linker")
    message(FATAL_ERROR "lp-expl: wrapper materialized despite an explicit linker")
endif()
lp_lacks("musl-linker")

# --- B2: wrapper leg (no explicit; shell-style emulator) ---------------------
lp_make(wrap C "x86_64-unknown-linux-musl" "" "${_emu_esc}" TRUE "" "" "" FALSE FALSE BINARY 1)
set(_wpath "${_lp_d}/b/.polyorch-rust/x86_64-unknown-linux-musl-linker")
ck_file("${_wpath}")
file(READ "${_wpath}" _wc)
ck(_wc MATCHES "^#!/bin/sh")
ck(_wc MATCHES "exec .*[$]@")
lp_has("${_mu}_LINKER=${_wpath}")
lp_has("${_mu}_RUNNER=")
# the wrapper is configure-time only: never referenced as a build-rule
# output/hash (the ported lesson -- an OUTPUT we touch gets claimed clean)
file(READ "${_lp_d}/b/CMakeFiles/Makefile2" _m2t)
string(FIND "${_m2t}" ".polyorch-rust" _m2f)
if(NOT _m2f EQUAL -1)
    message(FATAL_ERROR "lp-wrap: the wrapper leaked into Makefile2 rules")
endif()

# --- B3: default linker (bare qemu): C compiler, RUNNER forwarded, run() prefixed
lp_make(dflt C "x86_64-unknown-linux-musl" "" "qemu-musl" TRUE "" "" "" FALSE FALSE BINARY 1)
lp_cache_val("${_lp_d}" CMAKE_C_COMPILER _ccv)
lp_has("${_mu}_LINKER=${_ccv}")
lp_has("${_mu}_RUNNER=qemu-musl")
lp_lacks("musl-linker")
set(_runmk "${_lp_d}/b/CMakeFiles/run-lp-bin.dir/build.make")
ck_file("${_runmk}")
file(READ "${_runmk}" _runt)
string(REPLACE "\\\n" " " _runt "${_runt}")
if(NOT _runt MATCHES "qemu-musl")
    message(FATAL_ERROR "lp-dflt: run target lacks the emulator prefix")
endif()

# --- B4: CXX pick via link_libraries (generate-time late read) ---------------
lp_make(cxx "C CXX" "x86_64-unknown-linux-musl" "" "NONE" TRUE "" ""
    "polyorch_rust_link_libraries(TARGET lp-bin clib cxlib)\n" FALSE TRUE BINARY 0)
lp_cache_val("${_lp_d}" CMAKE_CXX_COMPILER _cxxv)
lp_has("${_mu}_LINKER=${_cxxv}")
# the -L/-l conversion (TARGET_LINKER_FILE_* genex expanded at generate time)
lp_has("-L${_lp_d}/b")
lp_has("-lclib")
lp_has("-lcxlib")
lp_has("LIBRARY_PATH=${_lp_d}/b")
lp_pos("LIBRARY_PATH=" "--unset=RUSTFLAGS")
lp_pos("RUSTFLAGS=" "--unset=RUSTFLAGS")

# --- B5: sysroot + compiler-target link args ---------------------------------
lp_make(sysroot C "x86_64-unknown-linux-musl" "" "NONE" TRUE "/x/sys" "armeb-none-eabi"
    "" FALSE FALSE BINARY 0)
lp_has("RUSTFLAGS= -Clink-arg=--sysroot=/x/sys -Clink-arg=--target=armeb-none-eabi")
lp_pos("RUSTFLAGS=" "--unset=RUSTFLAGS")
# ...and the hostbuild gate: flag + static link args vanish, the
# triple-SCOPED linker/runner names simply go unread (kept, inert)
lp_make(sysroot-hb C "x86_64-unknown-linux-musl" "" "NONE" TRUE "/x/sys" "armeb-none-eabi"
    "" TRUE FALSE BINARY 0)
lp_lacks("-Clink-arg=--sysroot")
lp_lacks("-Clink-arg=--target=armeb")
lp_lacks("RUSTFLAGS=")
lp_lacks("--target=x86_64")

# --- B6: STATIC-kind link_libraries forwards the CMake interface -------------
lp_make(stat C "x86_64-unknown-linux-musl" "" "NONE" TRUE "" ""
    "polyorch_rust_link_libraries(TARGET lp-bin clib)\n" FALSE FALSE STATIC 0)
ck_file("${_lp_d}/b/iface.txt")
file(READ "${_lp_d}/b/iface.txt" _ifv)
ck_str("${_ifv}" "clib")
lp_lacks("-lclib")

# --- B7: host layer = total linker-plane silence ------------------------------
lp_make(host C "" "" "qemu-musl" FALSE "" "" "" FALSE FALSE BINARY 0)
lp_lacks("${_mu}_LINKER=")
lp_lacks("RUNNER=")
lp_lacks("-Clink-arg=")
lp_has("CC_X86_64_UNKNOWN_LINUX_GNU=")

message(STATUS "rust-linkplan: OK (plan tables + explicit/wrapper/default/CXX/sysroot-gate/static/host-silence/run-prefix legs)")
