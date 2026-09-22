include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")

# WP5 cross-routing cluster, offline legs (no real cross build needed -- the
# musl e2e is t-rust-musl's job). Three assertion layers:
#  1. pure tables: the TARGET-extension of _polyorch_rust_artifact_names and
#     _polyorch_rust_copy_plan (the .cargo-target/<tup>/<profile>/ nesting),
#     _polyorch_rust_triple_env_form (the CARGO_TARGET_/CC_ name form,
#     corr:Corrosion.cmake:600-607), and _polyorch_rust_forward_env (the
#     cc-rs trio + the Apple sysroot block, corr:779-833 -- stub toolchains
#     only, never real compilers);
#  2. generate-time rule text: injected-cache children (the t-rust-setters
#     pattern: fake POLYORCH_RUST_* caches + cmake-as-cargo, nothing
#     executes) proving the --target composition, its hostbuild suppression,
#     and the WP5 ordering contract: every forwarded assignment rides AFTER
#     the wrapper's --unset strip (an assignment after --unset wins, the
#     WP3-established rule -- this pins it in GENERATED text, not in the
#     builder's source order);
#  3. the hostbuild honesty leg: on a NON-cross host polyorch_rust_set_hostbuild
#     is observably a NO-OP versus the default -- asserted by equivalence
#     against a plain host child (same layer, same entries), not by faking
#     a cross build. The cross child additionally proves the name-scoped
#     suppression mechanism: BOTH triple-keyed names ride the rule, so a
#     hostbuild flip leaves cc-rs the host-keyed names it reads.

# ------------------------------------------------------- pure naming tables --
# t_dir <triple> <kind> <target-or-EMPTY> <profile-or-EMPTY> <expect-dir> <expect-file>
macro(t_dir tr kl xt pf ed ef)
    set(_pf "")
    if(NOT "${pf}" STREQUAL "EMPTY")
        set(_pf PROFILE "${pf}")
    endif()
    set(_xt "")
    if(NOT "${xt}" STREQUAL "EMPTY")
        set(_xt TARGET "${xt}")
    endif()
    _polyorch_rust_artifact_names(TRIPLE "${tr}" KIND "${kl}" CRATE greet
        BASE_DIR /p/td ${_pf} ${_xt} FILE_OUT _f DIR_OUT _d)
    ck_str("${_d}" "${ed}")
    ck_str("${_f}" "${ef}")
    unset(_pf)
    unset(_xt)
endmacro()

# host layer stays byte-locked (no TARGET => the pre-WP5 shape)
t_dir(x86_64-unknown-linux-gnu bin EMPTY EMPTY
    /p/td/debug greet)
t_dir(x86_64-unknown-linux-gnu static EMPTY release
    /p/td/release libgreet.a)
# cross layer: one nesting level deeper (cargo's own --target layout)
t_dir(x86_64-unknown-linux-musl bin x86_64-unknown-linux-musl EMPTY
    /p/td/x86_64-unknown-linux-musl/debug greet)
t_dir(x86_64-unknown-linux-musl static x86_64-unknown-linux-musl release
    /p/td/x86_64-unknown-linux-musl/release libgreet.a)
# file-name family follows the TRIPLE (a windows target names .exe); the
# directory segment follows TARGET -- the two inputs are deliberately
# independent rows (mingw family + musl dir below).
t_dir(x86_64-pc-windows-msvc bin x86_64-pc-windows-msvc EMPTY
    /p/td/x86_64-pc-windows-msvc/debug greet.exe)
t_dir(x86_64-pc-windows-gnu shared x86_64-unknown-linux-musl release
    /p/td/x86_64-unknown-linux-musl/release greet.dll)
# OUT_BASE_DIR never carries the triple segment
_polyorch_rust_artifact_names(TRIPLE x86_64-unknown-linux-musl KIND bin
    CRATE greet TARGET x86_64-unknown-linux-musl BASE_DIR /p/td
    FILE_OUT _f OUT_BASE_DIR _b)
ck_str("${_b}" "/p/td")

# --- copy plan: SRC_DIR is the target-dir BASE when TARGET/PROFILE ride ----
# legacy verbatim glue (no TARGET/PROFILE) -- one regression row.
_polyorch_rust_copy_plan(TRIPLE x86_64-unknown-linux-gnu KIND bin CRATE greet
    SRC_DIR /p/td/debug DEST_DIR /p/out OUT _p)
ck_str("${_p}" "/p/td/debug/greet|/p/out/greet")
# base + TARGET + PROFILE (the WP5 cross construction)
_polyorch_rust_copy_plan(TRIPLE x86_64-unknown-linux-musl KIND bin CRATE greet
    SRC_DIR /p/td TARGET x86_64-unknown-linux-musl PROFILE debug
    DEST_DIR /p/out OUT _p)
ck_str("${_p}" "/p/td/x86_64-unknown-linux-musl/debug/greet|/p/out/greet")
# PROFILE alone (host glue through the same site)
_polyorch_rust_copy_plan(TRIPLE x86_64-unknown-linux-gnu KIND static CRATE greet
    SRC_DIR /p/td PROFILE release DEST_DIR /p/out OUT _p)
ck_str("${_p}" "/p/td/release/libgreet.a|/p/out/libgreet.a")
# gnullvm keeps the implib deps/ relocation INSIDE the cross nesting
_polyorch_rust_copy_plan(TRIPLE x86_64-w64-windows-gnullvm KIND implib CRATE greet
    SRC_DIR /p/td TARGET x86_64-w64-windows-gnullvm PROFILE debug
    DEST_DIR /p/out OUT _p)
ck_str("${_p}" "/p/td/x86_64-w64-windows-gnullvm/debug/deps/libgreet.dll.a|/p/out/libgreet.dll.a")
# TARGET without PROFILE: base/tup/file (documented edge; finalize never emits it)
_polyorch_rust_copy_plan(TRIPLE x86_64-unknown-linux-musl KIND bin CRATE greet
    SRC_DIR /p/td TARGET x86_64-unknown-linux-musl DEST_DIR /p/out OUT _p)
ck_str("${_p}" "/p/td/x86_64-unknown-linux-musl/greet|/p/out/greet")

# ------------------------------------------------------------- env name form --
macro(t_form tr want)
    _polyorch_rust_triple_env_form("${tr}" _u)
    ck_str("${_u}" "${want}")
endmacro()
t_form(x86_64-unknown-linux-musl X86_64_UNKNOWN_LINUX_MUSL)
t_form(aarch64-apple-darwin AARCH64_APPLE_DARWIN)
t_form(i686-pc-windows-msvc I686_PC_WINDOWS_MSVC)
t_form(X86_64-Unknown-Linux-GNU X86_64_UNKNOWN_LINUX_GNU)

# ------------------------------------------------------------ cc-rs forwarding --
macro(t_fwd_list got wantvar)
    string(JOIN ";" _wfl ${${wantvar}})
    string(JOIN ";" _gfl ${${got}})
    ck_str("${_gfl}" "${_wfl}")
endmacro()

# (1) elf cross triple, fully injected toolchain: trio in corr order, no
# ambient CMAKE_* leakage (every keyword passed explicitly).
set(_wf_exp CC_X86_64_UNKNOWN_LINUX_MUSL=/x/cc
    CXX_X86_64_UNKNOWN_LINUX_MUSL=/x/cxx AR_X86_64_UNKNOWN_LINUX_MUSL=/x/ar)
_polyorch_rust_forward_env(TRIPLE x86_64-unknown-linux-musl
    C_COMPILER /x/cc CXX_COMPILER /x/cxx AR /x/ar SYSROOT /x/root
    OSX_SYSROOT "" DEPLOYMENT_TARGET ""
    OUT_ENV _wf_e OUT_LINK_ARGS _wf_l)
t_fwd_list(_wf_e _wf_exp)
ck_str("${_wf_l}" "--sysroot=/x/root")

# (2) msvc family: absolute env gate (the task's "do not inject CC into env
# for MSVC" superset of corr's AR-only guard).
_polyorch_rust_forward_env(TRIPLE x86_64-pc-windows-msvc
    C_COMPILER /x/cl CXX_COMPILER /x/cl AR /x/lib SYSROOT /x
    OSX_SYSROOT "" DEPLOYMENT_TARGET ""
    OUT_ENV _wf_e2 OUT_LINK_ARGS _wf_l2)
ck_str("${_wf_e2}" "")
ck_str("${_wf_l2}" "")

# (3) macho block: SDKROOT + deployment target + the --sysroot link arg
# (corr:818-829 shape; the APPLE guards live at the callers -- table here).
set(_wf_exp3 CC_AARCH64_APPLE_DARWIN=/x/clang
    CXX_AARCH64_APPLE_DARWIN=/x/clang++
    SDKROOT=/sdks/A.sysroot MACOSX_DEPLOYMENT_TARGET=14.0)
_polyorch_rust_forward_env(TRIPLE aarch64-apple-darwin
    C_COMPILER /x/clang CXX_COMPILER /x/clang++ AR "" SYSROOT ""
    OSX_SYSROOT /sdks/A.sysroot DEPLOYMENT_TARGET 14.0
    OUT_ENV _wf_e3 OUT_LINK_ARGS _wf_l3)
t_fwd_list(_wf_e3 _wf_exp3)
ck_str("${_wf_l3}" "--sysroot=/sdks/A.sysroot")

# (4) language-not-enabled guard: empty injected values emit nothing, and the
# AR/compiler entries are independently gated.
_polyorch_rust_forward_env(TRIPLE x86_64-unknown-linux-musl
    C_COMPILER "" CXX_COMPILER "" AR /x/ar SYSROOT "" OSX_SYSROOT ""
    DEPLOYMENT_TARGET "" OUT_ENV _wf_e4)
ck_str("${_wf_e4}" "AR_X86_64_UNKNOWN_LINUX_MUSL=/x/ar")

_polyorch_pixi_scratch(_s)
set(_cmkedir "${CMAKE_CURRENT_LIST_DIR}/../../cmake")

# ------------------------------------------------- generated-rule children --
# The shared template body; xplat_make substitutes per child. LANGUAGES C so
# CMAKE_C_COMPILER is REAL (the trio must come from an actual discovery),
# the rust toolchain faked (cmake-as-cargo, nothing executes). Unix Makefiles
# forced for greppable rule text (the t-rust-setters precedent).
file(WRITE "${_s}/_xplat.in" [==[
cmake_minimum_required(VERSION 3.25)
project(polyorch-xplat LANGUAGES C)
list(APPEND CMAKE_MODULE_PATH "@CMKEDIR@")
include(PolyOrchRustHelpers)
set(POLYORCH_RUST_FOUND TRUE CACHE INTERNAL "")
set(POLYORCH_RUST_CARGO "@CMAKECMD@" CACHE INTERNAL "")
set(POLYORCH_RUST_RUSTC "@CMAKECMD@" CACHE INTERNAL "")
set(POLYORCH_RUST_HOST_TARGET "x86_64-unknown-linux-gnu" CACHE INTERNAL "")
set(POLYORCH_RUST_ROUTE "system" CACHE INTERNAL "")
set(POLYORCH_RUST_BIN_DIR "" CACHE INTERNAL "")
set(POLYORCH_RUST_CARGO_TARGET "@XT@" CACHE INTERNAL "")
polyorch_rust_build(TARGET xp-bin PACKAGE hello CRATE hello-cli BINARY)
if(@HB@)
    polyorch_rust_set_hostbuild(TARGET xp-bin)
endif()
file(GENERATE OUTPUT "${CMAKE_BINARY_DIR}/tf.txt" CONTENT "$<TARGET_FILE:xp-bin>")
]==])

function(xplat_make dir xt hb)
    file(MAKE_DIRECTORY "${dir}")
    file(READ "${_s}/_xplat.in" _tpl)
    string(REPLACE "@CMKEDIR@" "${_cmkedir}" _tpl "${_tpl}")
    string(REPLACE "@CMAKECMD@" "${CMAKE_COMMAND}" _tpl "${_tpl}")
    string(REPLACE "@XT@" "${xt}" _tpl "${_tpl}")
    string(REPLACE "@HB@" "${hb}" _tpl "${_tpl}")
    file(WRITE "${dir}/CMakeLists.txt" "${_tpl}")
    execute_process(COMMAND "${CMAKE_COMMAND}" -G "Unix Makefiles"
        -S "${dir}" -B "${dir}/b"
        RESULT_VARIABLE _rc OUTPUT_VARIABLE _o ERROR_VARIABLE _e)
    if(NOT _rc EQUAL 0)
        message(FATAL_ERROR "xplat child ${dir} configure failed (${_rc}):\n${_o}${_e}")
    endif()
endfunction()

macro(xplat_mk_read dir out)
    set(_mkf "${dir}/b/CMakeFiles/cargo-build-xp-bin.dir/build.make")
    ck_file("${_mkf}")
    file(READ "${_mkf}" _mkt)
    string(REPLACE "\\\n" " " _mkt "${_mkt}")   # rejoin folded recipe lines
    set(${out} "${_mkt}")
endmacro()
macro(xplat_tf_read dir out)
    ck_file("${dir}/b/tf.txt")
    file(READ "${dir}/b/tf.txt" ${out})
endmacro()
# The strip-before-forward position check, one call per entry name:
# --unset=RUSTFLAGS strictly precedes every forwarded CC_ assignment.
macro(xplat_order_ck mk needle var)
    string(FIND "${${mk}}" "--unset=RUSTFLAGS" _p1)
    string(FIND "${${mk}}" "${needle}" _p2)
    ck(_p1 GREATER -1)
    if(NOT _p2 GREATER -1)
        message(FATAL_ERROR "${var}: rule lacks the cc-rs entry [${needle}]")
    endif()
    if(NOT _p1 LESS _p2)
        message(FATAL_ERROR "${var}: forwarding precedes the --unset strip [${needle}]")
    endif()
endmacro()

# --- child 1: cross route, default (no hostbuild) ---------------------------
set(_c1 "${_s}/xp-cross")
xplat_make("${_c1}" "x86_64-unknown-linux-musl" "FALSE")
xplat_mk_read("${_c1}" _mk1)
xplat_tf_read("${_c1}" _tf1)
if(NOT _mk1 MATCHES "--target=x86_64-unknown-linux-musl")
    message(FATAL_ERROR "xp-cross: rule lacks the --target flag")
endif()
xplat_order_ck(_mk1 "CC_X86_64_UNKNOWN_LINUX_MUSL=" xp-cross)
xplat_order_ck(_mk1 "CC_X86_64_UNKNOWN_LINUX_GNU=" xp-cross)
if(NOT _tf1 MATCHES "/\\.cargo-target/x86_64-unknown-linux-musl/debug/hello-cli$")
    message(FATAL_ERROR "xp-cross: location ${_tf1} not in the cross layer")
endif()

# --- child 2: cross route + hostbuild (fall back to the host layer) ---------
set(_c2 "${_s}/xp-hb")
xplat_make("${_c2}" "x86_64-unknown-linux-musl" "TRUE")
xplat_mk_read("${_c2}" _mk2)
xplat_tf_read("${_c2}" _tf2)
if(_mk2 MATCHES "--target=x86_64-unknown-linux-musl")
    message(FATAL_ERROR "xp-hb: hostbuild must suppress the --target flag")
endif()
if(NOT _tf2 MATCHES "/\\.cargo-target/debug/hello-cli$")
    message(FATAL_ERROR "xp-hb: location ${_tf2} did not fall back to the host layer")
endif()
# The suppression is NAME-SCOPED: the cross-named trio stays in the env (it
# simply goes unread when --target is omitted) and the host-named trio is
# present for exactly that fall-back build.
xplat_order_ck(_mk2 "CC_X86_64_UNKNOWN_LINUX_MUSL=" xp-hb)
xplat_order_ck(_mk2 "CC_X86_64_UNKNOWN_LINUX_GNU=" xp-hb)

# --- child 3+4: NON-cross host, hostbuild vs default -- observably equal ----
# Same rule as the plain host default: no --target anywhere, the host layer,
# the trio keyed to the HOST triple only (no cross names leak). Nothing
# faked: the property is simply inert when no foreign triple is routed.
set(_c3 "${_s}/xp-host-hb")
xplat_make("${_c3}" "" "TRUE")
xplat_mk_read("${_c3}" _mk3)
xplat_tf_read("${_c3}" _tf3)
set(_c4 "${_s}/xp-host")
xplat_make("${_c4}" "" "FALSE")
xplat_mk_read("${_c4}" _mk4)
xplat_tf_read("${_c4}" _tf4)
foreach(_v 3 4)
    if(_mk${_v} MATCHES "--target=")
        message(FATAL_ERROR "host child ${_v}: the host layer must never carry the flag form --target=...")
    endif()
    if(NOT _tf${_v} MATCHES "/\\.cargo-target/debug/hello-cli$")
        message(FATAL_ERROR "host child ${_v}: location ${_tf${_v}} off the host layer")
    endif()
    xplat_order_ck(_mk${_v} "CC_X86_64_UNKNOWN_LINUX_GNU=" "host child ${_v}")
    if(_mk${_v} MATCHES "CC_X86_64_UNKNOWN_LINUX_MUSL=")
        message(FATAL_ERROR "host child ${_v}: cross-named entry leaked into the host layer")
    endif()
endforeach()
# The no-op statement, mechanically: after rebasing each child's build dir
# out of its location, the two tf probes are IDENTICAL strings.
string(REPLACE "${_c3}/b" "<B>" _tf3r "${_tf3}")
string(REPLACE "${_c4}/b" "<B>" _tf4r "${_tf4}")
ck_str("${_tf3r}" "${_tf4r}")

message(STATUS "rust-crossplan: OK (naming/copy tables + env form + trio gate + generated --target/hostbuild/order/no-op legs)")
