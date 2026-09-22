# requires: posix-shell
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")

# WP3 FindRust parity cluster, offline legs. Stubs are /bin/sh scripts
# (t-rust-executables machinery), so the whole case is POSIX-gated; the pure
# table legs would run anywhere but never see a non-POSIX host in this suite.
# Cluster A: polyorch_rust_version_ok table + PolyOrch_RUST_MIN_VERSION floor
# + version exports (POLYORCH_RUST_CARGO_VERSION, _VERSION_MAJOR/MINOR/PATCH).
# Mechanism reference: corr:FindRust.cmake:38-71 (_findrust_version_ok shape).
polyorch_requires(posix-shell _req)
if(NOT _req)
    message(STATUS "t-rust-findrust : SKIP (stubs need a POSIX shell)")
    return()
endif()

_polyorch_pixi_scratch(_s)

# Internal (case-local): write a direct-looking stub rustc/cargo pair printing
# VER into DIR. Deliberately NOT rustup-proxy-looking: `--version` under
# RUSTUP_FORCE_ARG0=rustup still prints plain rustc text (Cluster B adds the
# proxy stubs separately).
function(_fr_pair DIR VER)
    file(MAKE_DIRECTORY "${DIR}")
    file(WRITE "${DIR}/rustc" "#!/bin/sh
cat <<'STUB'
rustc ${VER} (abcdef123 2026-06-30)
binary: rustc
host: x86_64-unknown-linux-gnu
release: ${VER}
STUB
")
    file(WRITE "${DIR}/cargo" "#!/bin/sh
echo 'cargo ${VER} (fedcba987 2026-06-30)'
")
    file(CHMOD "${DIR}/rustc" "${DIR}/cargo"
        PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE
                    GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
endfunction()
_fr_pair("${_s}/tc198" "1.98.1")

# Proxy toolchain world (Cluster B): a rustup-proxy-looking rustc + a canned
# rustup, both in proxybin, over two concrete stub toolchains. The stub rustc
# answers the RUSTUP_FORCE_ARG0=rustup probe with rustup text (the canonical
# proxy tell, corr:FindRust.cmake:279-312) and otherwise behaves direct.
set(_tcw "${_s}/tcw")
file(MAKE_DIRECTORY "${_tcw}/proxybin")
file(WRITE "${_tcw}/proxybin/rustc" "#!/bin/sh
if [ \"$RUSTUP_FORCE_ARG0\" = \"rustup\" ]; then
    echo 'rustup 1.99.9 (stubproxy 2026-06-30)'
    exit 0
fi
cat <<'STUB'
rustc 1.98.1 (abcdef123 2026-06-30)
binary: rustc
host: x86_64-unknown-linux-gnu
release: 1.98.1
STUB
")
file(WRITE "${_tcw}/proxybin/cargo" "#!/bin/sh
echo 'cargo 1.98.1 (stubproxy 2026-06-30)'
")
    file(WRITE "${_tcw}/proxybin/rustup" "#!/bin/sh
if [ \"$1\" = toolchain ]; then
    cat <<'L'
stable-x86_64-unknown-linux-gnu (active, default) ${_tcw}/tc-stable
1.89.0-x86_64-unknown-linux-gnu ${_tcw}/tc-older
    customtc (override) ${_tcw}/tc-custom
L
    elif [ \"$1\" = show ]; then
    echo 'Default host: x86_64-unknown-linux-gnu'
    fi
")
file(CHMOD "${_tcw}/proxybin/rustc" "${_tcw}/proxybin/cargo"
            "${_tcw}/proxybin/rustup"
    PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE
                GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
# The listed paths are toolchain ROOTS (rustup -v convention); the code
# probes <root>/bin/rustc, so the concrete pairs live under bin/.
_fr_pair("${_tcw}/tc-stable/bin" "1.98.1")
_fr_pair("${_tcw}/tc-older/bin" "1.89.0")
_fr_pair("${_tcw}/tc-custom/bin" "1.50.0")

# --- child fork legs: expected-FATAL sections run BEFORE the parent's own
# assertions can be reached again (whole file re-executes; $ENV leg selector
# picks the scenario, ck_child_fail below inherits this env).
if(POLYORCH_CHILD)
    set(_leg "$ENV{POLYORCH_FINDRUST_LEG}")
    if(_leg STREQUAL "minfloor")
        # Floor above the stub's version, REQUIRED => the miss must be fatal
        # and name found-vs-required (pins "requires .* at least").
        set(PolyOrch_RUST_CARGO_EXECUTABLE "${_s}/tc198/cargo" CACHE INTERNAL "")
        set(PolyOrch_RUSTC_EXECUTABLE "${_s}/tc198/rustc" CACHE INTERNAL "")
        set(PolyOrch_RUST_MIN_VERSION "2.0.0" CACHE INTERNAL "")
        polyorch_rust_setup(FROM system REQUIRED NO_NATIVE_PROBE)
        message(FATAL_ERROR "expected setup to reject 1.98.1 under a 2.0.0 floor")
    endif()
    if(_leg STREQUAL "badtoolchain")
        # Unknown explicit toolchain name in a working rustup world must
        # FATAL and list what IS available (find:491-497).
        set(ENV{PATH} "${_tcw}/proxybin:$ENV{PATH}")
        set(PolyOrch_RUST_TOOLCHAIN "nope-not-here" CACHE INTERNAL "")
        polyorch_rust_setup(FROM system REQUIRED NO_NATIVE_PROBE)
        message(FATAL_ERROR "expected setup to reject an unknown rustup toolchain name")
    endif()
    message(FATAL_ERROR "t-rust-findrust child: unknown leg '${_leg}'")
endif()

# ---------------------------------------------------------------- version_ok --
# No constraint => always ok (find:67-70 mirror).
polyorch_rust_version_ok("1.98.1" _ok)
ck_str("${_ok}" "TRUE")
# VERSION without EXACT is a floor (find:59-61: VERSION_GREATER_EQUAL).
polyorch_rust_version_ok("1.98.1" _ok VERSION "1.90")
ck_str("${_ok}" "TRUE")
polyorch_rust_version_ok("1.80.0" _ok VERSION "1.90")
ck_str("${_ok}" "FALSE")
polyorch_rust_version_ok("1.98.1" _ok VERSION "1.98.1")
ck_str("${_ok}" "TRUE")
# EXACT pins equality.
polyorch_rust_version_ok("1.98.1" _ok VERSION "1.98.1" EXACT)
ck_str("${_ok}" "TRUE")
polyorch_rust_version_ok("1.98.0" _ok VERSION "1.98.1" EXACT)
ck_str("${_ok}" "FALSE")
# RANGE is inclusive on both ends (reference RANGE_MAX=INCLUDE default).
polyorch_rust_version_ok("1.95.0" _ok RANGE "1.90..2.0")
ck_str("${_ok}" "TRUE")
polyorch_rust_version_ok("1.90.0" _ok RANGE "1.90..2.0")
ck_str("${_ok}" "TRUE")
polyorch_rust_version_ok("2.0.0" _ok RANGE "1.90..2.0")
ck_str("${_ok}" "TRUE")
polyorch_rust_version_ok("2.5.0" _ok RANGE "1.90..2.0")
ck_str("${_ok}" "FALSE")
polyorch_rust_version_ok("1.89.9" _ok RANGE "1.90..2.0")
ck_str("${_ok}" "FALSE")
# Garbage actuals are FALSE, never a warning or FATAL (CMake VERSION_*
# comparisons would error on them -- the helper pre-validates).
polyorch_rust_version_ok("nightly" _ok VERSION "1.90")
ck_str("${_ok}" "FALSE")
polyorch_rust_version_ok("1.98.1-rc" _ok VERSION "1.0")
ck_str("${_ok}" "FALSE")
polyorch_rust_version_ok("" _ok VERSION "1.0")
ck_str("${_ok}" "FALSE")

# ------------------------------------------------------------------- floor ---
# Injection pins discovery deterministically (WP2 pair), so the floor is the
# only variable under test.
set(PolyOrch_RUST_CARGO_EXECUTABLE "${_s}/tc198/cargo" CACHE INTERNAL "")
set(PolyOrch_RUSTC_EXECUTABLE "${_s}/tc198/rustc" CACHE INTERNAL "")

# (a) empty knob => no floor at all (default = current semantics).
set(PolyOrch_RUST_MIN_VERSION "" CACHE INTERNAL "")
polyorch_rust_setup(FROM system REQUIRED NO_NATIVE_PROBE)
ck_str("${POLYORCH_RUST_FOUND}" "TRUE")
# exports: cargo version var + normalized rustc triple
ck_str("${POLYORCH_RUST_CARGO_VERSION}" "1.98.1")
ck_str("${POLYORCH_RUST_VERSION}" "1.98.1")
ck_str("${POLYORCH_RUST_RUSTC_VERSION}" "1.98.1")
ck_str("${POLYORCH_RUST_VERSION_MAJOR}" "1")
ck_str("${POLYORCH_RUST_VERSION_MINOR}" "98")
ck_str("${POLYORCH_RUST_VERSION_PATCH}" "1")

# (b) satisfied floor passes.
set(PolyOrch_RUST_MIN_VERSION "1.90" CACHE INTERNAL "")
polyorch_rust_setup(FROM system REQUIRED NO_NATIVE_PROBE)
ck_str("${POLYORCH_RUST_FOUND}" "TRUE")

# (c) missed floor without REQUIRED: soft miss, FOUND=FALSE (the REQUIRED
# hard-miss shape is the minfloor child leg pinned below).
set(PolyOrch_RUST_MIN_VERSION "2.0.0" CACHE INTERNAL "")
polyorch_rust_setup(FROM system NO_NATIVE_PROBE)
ck_str("${POLYORCH_RUST_FOUND}" "FALSE")

# (d) clearing the knob recovers (no stale-cache poisoning across setups).
set(PolyOrch_RUST_MIN_VERSION "" CACHE INTERNAL "")
polyorch_rust_setup(FROM system REQUIRED NO_NATIVE_PROBE)
ck_str("${POLYORCH_RUST_FOUND}" "TRUE")

# (e) REQUIRED + missed floor => FATAL naming found-vs-required.
set(ENV{POLYORCH_FINDRUST_LEG} "minfloor")
ck_child_fail("requires .* at least")
unset(ENV{POLYORCH_FINDRUST_LEG})


# ------------------------------------------------- toolchain list parsing ---
# Pure table over the canned `rustup toolchain list -v` text (mechanism:
# corr:FindRust.cmake:349-359 line grammar + default marker at 357).
_polyorch_rust_parse_toolchain_list(
    "stable-x86_64-unknown-linux-gnu (active, default) /opt/tc/stable"
    _n _p _h)
ck_str("${_n}" "stable-x86_64-unknown-linux-gnu")
ck_str("${_p}" "/opt/tc/stable")
ck_str("${_h}" "stable-x86_64-unknown-linux-gnu")
set(_multi
    "stable-x86_64-unknown-linux-gnu (active, default) /opt/tc/stable"
    "1.89.0-x86_64-unknown-linux-gnu /opt/tc/older"
    ""
    "???garbage"
    "customtc (override) /opt/tc/custom")
string(REPLACE ";" "
" _multi "${_multi}")
_polyorch_rust_parse_toolchain_list("${_multi}" _n _p _h)
ck_str("${_n}" "stable-x86_64-unknown-linux-gnu;1.89.0-x86_64-unknown-linux-gnu;customtc")
ck_str("${_p}" "/opt/tc/stable;/opt/tc/older;/opt/tc/custom")
ck_str("${_h}" "stable-x86_64-unknown-linux-gnu")
# No default marker at all => empty host (selection later falls back to the
# first enumerated name).
_polyorch_rust_parse_toolchain_list("solo_tc /opt/tc/solo" _n _p _h)
ck_str("${_n}" "solo_tc")
ck_str("${_h}" "")
# Tab separators must parse too.
_polyorch_rust_parse_toolchain_list("a_tc	/opt/a
x_tc (default) /opt/x" _n _p _h)
ck_str("${_n}" "a_tc;x_tc")
ck_str("${_h}" "x_tc")

# ------------------------------------------------------------- resolution ---
# The direct world: a plain non-proxy pair with NO rustup reachable (the
# tool shell PATH carries neither cargo nor rustup on this host). This is the
# branch that keeps conda/pixi-style rust working WITHOUT rustup.
unset(PolyOrch_RUST_CARGO_EXECUTABLE CACHE)
unset(PolyOrch_RUSTC_EXECUTABLE CACHE)
set(_path0 "$ENV{PATH}")
set(ENV{PATH} "${_s}/tc198:$ENV{PATH}")
polyorch_rust_setup(FROM system REQUIRED NO_NATIVE_PROBE)
ck_str("${POLYORCH_RUST_FOUND}" "TRUE")
ck_str("${POLYORCH_RUST_RUSTC}" "${_s}/tc198/rustc")
ck_str("${POLYORCH_RUST_TOOLCHAINS}" "direct")
ck_str("${POLYORCH_RUST_TOOLCHAIN_HOST}" "direct")
ck_str("${POLYORCH_RUST_TOOLCHAIN_direct_VERSION}" "1.98.1")

# The proxy world: PATH exposes only the proxy trio + canned rustup; setup
# must detect the proxy, enumerate, and land on the CONCRETE default
# toolchain binaries (reference contract: \"returns a concrete Rust version,
# not a rustup proxy\", corr:FindRust.cmake:7-9).
set(ENV{PATH} "${_tcw}/proxybin:$ENV{PATH}")
polyorch_rust_setup(FROM system REQUIRED NO_NATIVE_PROBE)
ck_str("${POLYORCH_RUST_FOUND}" "TRUE")
ck_str("${POLYORCH_RUST_RUSTC}" "${_tcw}/tc-stable/bin/rustc")
ck_str("${POLYORCH_RUST_CARGO}" "${_tcw}/tc-stable/bin/cargo")
ck_str("${POLYORCH_RUST_BIN_DIR}" "${_tcw}/tc-stable/bin")
ck_str("${POLYORCH_RUST_TOOLCHAINS}" "stable-x86_64-unknown-linux-gnu;1.89.0-x86_64-unknown-linux-gnu;customtc")
ck_str("${POLYORCH_RUST_TOOLCHAIN_HOST}" "stable-x86_64-unknown-linux-gnu")
ck_str("${POLYORCH_RUST_TOOLCHAIN_customtc_VERSION}" "1.50.0")
ck_str("${POLYORCH_RUST_TOOLCHAIN_customtc_PATH}" "${_tcw}/tc-custom")

# (f) unknown explicit toolchain name => FATAL listing available ones.
set(ENV{POLYORCH_FINDRUST_LEG} "badtoolchain")
ck_child_fail("Could not find toolchain .nope-not-here.")
unset(ENV{POLYORCH_FINDRUST_LEG})

# (g) the knob with an EXACT name: selection must not follow rustup's
# default -- the requested toolchain wins, version and all.
set(PolyOrch_RUST_TOOLCHAIN "customtc" CACHE INTERNAL "")
polyorch_rust_setup(FROM system REQUIRED NO_NATIVE_PROBE)
ck_str("${POLYORCH_RUST_RUSTC}" "${_tcw}/tc-custom/bin/rustc")
ck_str("${POLYORCH_RUST_RUSTC_VERSION}" "1.50.0")
ck_str("${POLYORCH_RUST_VERSION_PATCH}" "0")

# (h) toolchain-host fallback: a bare family name (\"stable\") is retried as
# `stable-<default host>` via `rustup show` (find:472-503).
set(PolyOrch_RUST_TOOLCHAIN "stable" CACHE INTERNAL "")
polyorch_rust_setup(FROM system REQUIRED NO_NATIVE_PROBE)
ck_str("${POLYORCH_RUST_RUSTC}" "${_tcw}/tc-stable/bin/rustc")
set(PolyOrch_RUST_TOOLCHAIN "" CACHE INTERNAL "")

# (i) the floor operates on the SELECTED toolchain, not rustup's default:
# a floor above customtc (1.50.0) with the knob pinned to it must miss.
set(PolyOrch_RUST_MIN_VERSION "1.90" CACHE INTERNAL "")
set(PolyOrch_RUST_TOOLCHAIN "customtc" CACHE INTERNAL "")
polyorch_rust_setup(FROM system NO_NATIVE_PROBE)
ck_str("${POLYORCH_RUST_FOUND}" "FALSE")
set(PolyOrch_RUST_MIN_VERSION "" CACHE INTERNAL "")
set(PolyOrch_RUST_TOOLCHAIN "" CACHE INTERNAL "")
set(ENV{PATH} "${_path0}")


# -------------------------------------------------------- derive-target -----
# _polyorch_rust_derive_target(OUT): override wins; otherwise the host
# triple recorded by the last successful setup (WP5b inserts the
# VS/processor/compiler-id chain before that fallback -- see the function).
_polyorch_rust_derive_target(_dt)
ck_str("${_dt}" "")          # no setup yet in scope: empty host, empty override
set(PolyOrch_RUST_CARGO_TARGET "wasm32-eabi-polyorch" CACHE INTERNAL "")
_polyorch_rust_derive_target(_dt)
ck_str("${_dt}" "wasm32-eabi-polyorch")
set(PolyOrch_RUST_CARGO_TARGET "" CACHE INTERNAL "")
set(ENV{PATH} "${_s}/tc198:$ENV{PATH}")
polyorch_rust_setup(FROM system REQUIRED NO_NATIVE_PROBE)   # direct world
_polyorch_rust_derive_target(_dt)
ck_str("${_dt}" "x86_64-unknown-linux-gnu")

# --------------------------------------------------------- script-mode -------
# Handles are a project-mode construct: add_executable is not scriptable
# (measured on 4.4.3), so the cmake -P setup above must NOT have created them.
if(TARGET PolyOrchRust::Rustc)
    message(FATAL_ERROR "PolyOrchRust::Rustc must not exist in script mode")
endif()

# ------------------------------------------------------- imported handles ----
# A real (non-script) child configure must get GLOBAL imported executable
# handles for the two tools, pointing at the resolved binaries, and a second
# setup must REPLACE the locations (idempotent re-run, reference find:902-915
# guarded with if(NOT TARGET)).
_fr_pair("${_s}/tcb" "9.9.9")
set(_frh "${_s}/handles")
file(MAKE_DIRECTORY "${_frh}/proj")
file(WRITE "${_frh}/proj/CMakeLists.txt" [==[
cmake_minimum_required(VERSION 3.25)
project(polyorch-frh LANGUAGES NONE)
list(APPEND CMAKE_MODULE_PATH "@CMKEDIR@")
include(PolyOrchRustHelpers)
set(PolyOrch_RUST_CARGO_EXECUTABLE "@A_CARGO@" CACHE FILEPATH "")
set(PolyOrch_RUSTC_EXECUTABLE "@A_RUSTC@" CACHE FILEPATH "")
polyorch_rust_setup(FROM system REQUIRED NO_NATIVE_PROBE)
foreach(_h PolyOrchRust::Rustc PolyOrchRust::Cargo)
    if(NOT TARGET ${_h})
        message(FATAL_ERROR "no imported handle ${_h} after setup")
    endif()
endforeach()
get_target_property(_r1 PolyOrchRust::Rustc IMPORTED_LOCATION)
get_target_property(_c1 PolyOrchRust::Cargo IMPORTED_LOCATION)
if(NOT _r1 STREQUAL "@A_RUSTC@" OR NOT _c1 STREQUAL "@A_CARGO@")
    message(FATAL_ERROR "handle locations not the resolved pair: [${_r1}] [${_c1}]")
endif()
set(PolyOrch_RUST_CARGO_EXECUTABLE "@B_CARGO@" CACHE FILEPATH "" FORCE)
set(PolyOrch_RUSTC_EXECUTABLE "@B_RUSTC@" CACHE FILEPATH "" FORCE)
polyorch_rust_setup(FROM system REQUIRED NO_NATIVE_PROBE)
get_target_property(_r2 PolyOrchRust::Rustc IMPORTED_LOCATION)
get_target_property(_c2 PolyOrchRust::Cargo IMPORTED_LOCATION)
if(NOT _r2 STREQUAL "@B_RUSTC@" OR NOT _c2 STREQUAL "@B_CARGO@")
    message(FATAL_ERROR "re-setup did not replace handle locations: [${_r2}] [${_c2}]")
endif()
file(WRITE "@OUT@" "OK")
]==])
# Substitute the @tokens@ by hand (read, replace, rewrite) — keeps the
# template free of accidental expansion at case-write time.
file(READ "${_frh}/proj/CMakeLists.txt" _frh_tpl)
string(REPLACE "@CMKEDIR@" "${CMAKE_CURRENT_LIST_DIR}/../../cmake" _frh_tpl "${_frh_tpl}")
string(REPLACE "@A_CARGO@" "${_s}/tc198/cargo" _frh_tpl "${_frh_tpl}")
string(REPLACE "@A_RUSTC@" "${_s}/tc198/rustc" _frh_tpl "${_frh_tpl}")
string(REPLACE "@B_CARGO@" "${_s}/tcb/cargo" _frh_tpl "${_frh_tpl}")
string(REPLACE "@B_RUSTC@" "${_s}/tcb/rustc" _frh_tpl "${_frh_tpl}")
string(REPLACE "@OUT@" "${_frh}/out.txt" _frh_tpl "${_frh_tpl}")
file(WRITE "${_frh}/proj/CMakeLists.txt" "${_frh_tpl}")
execute_process(
    COMMAND ${CMAKE_COMMAND} -S "${_frh}/proj" -B "${_frh}/b"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "handles child configure failed (${_rc}):\n${_out}${_err}")
endif()
ck_file("${_frh}/out.txt")

message(STATUS "rust-findrust: OK (version/floor + enumeration/knob + handles + derive seam)")
