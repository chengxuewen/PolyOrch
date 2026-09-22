# requires: system-rust
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

# WP6 package-version surfacing: polyorch_rust_package_version + its pure
# sibling _polyorch_rust_metadata_package_version (reference:
# corrosion_parse_package_version, corr:2267-2309, which file(READ)s the
# manifest and regexes [package] version -- ours reads the SAME metadata JSON
# the import machinery already consumes instead; deviation ledgered: the
# reference regex drops prerelease suffixes and needs a following table,
# cargo's metadata version field is exact).
#
# Layers:
#  1. pure table legs on canned JSON (always run, offline, no toolchain);
#  2. the public function against the REAL cargo on the existing import-ws
#     fixture (dash-ed 0.1.0 / say-hi 0.1.0 -- no new fixture, cargo metadata
#     --no-deps is network-free), gated by "# requires: system-rust": the
#     whole real half skips honestly when the host has no cargo;
#  3. negative identities (unknown package, dead manifest) through a
#     POLYORCH_CHILD re-exec, behind the same gate.

# ------------------------------------------------------------- pure tables ---
set(_pj [==[
{
  "packages": [
    { "name": "dash-ed", "version": "0.1.0", "targets": [] },
    { "name": "tool",    "version": "1.2.3-alpha.1", "targets": [] },
    { "name": "zero",    "version": "0.0.0", "targets": [] }
  ],
  "workspace_members": [],
  "version": 1
}
]==])

_polyorch_rust_metadata_package_version("${_pj}" dash-ed _v1)
ck_str("${_v1}" "0.1.0")
# prerelease rides verbatim (the reference's [0-9.]+ regex would truncate it)
_polyorch_rust_metadata_package_version("${_pj}" tool _v2)
ck_str("${_v2}" "1.2.3-alpha.1")
_polyorch_rust_metadata_package_version("${_pj}" zero _v3)
ck_str("${_v3}" "0.0.0")
# unknown package: OUT left UNDEFINED (the caller raises the error)
unset(_v4)
_polyorch_rust_metadata_package_version("${_pj}" no-such _v4)
ck(NOT DEFINED _v4)

# ------------------------------------------------------------------- gate ----
polyorch_requires(system-rust _sr)
if(NOT _sr)
    message(STATUS "t-rust-pkgver : SKIP (no system cargo for the real legs)")
    return()
endif()
find_program(_cargo NAMES cargo PATHS "$ENV{HOME}/.cargo/bin")
ck_file("${_cargo}")
set(_ws "${CMAKE_CURRENT_LIST_DIR}/../fixtures/import-ws/rust-ws/Cargo.toml")
ck_file("${_ws}")
get_filename_component(_wsdir "${_ws}" DIRECTORY)

# ------------------------------------------------------- public fn, real -----
# Injection style of t-rust-collision (the guards read variables), but with
# the REAL cargo -- nothing is compiled; `cargo metadata --no-deps` only.
set(POLYORCH_RUST_FOUND TRUE CACHE INTERNAL "")
set(POLYORCH_RUST_CARGO "${_cargo}" CACHE INTERNAL "")
set(POLYORCH_RUST_RUSTC "${_cargo}" CACHE INTERNAL "")
set(POLYORCH_RUST_HOST_TARGET "x86_64-unknown-linux-gnu" CACHE INTERNAL "")
set(POLYORCH_RUST_ROUTE "system" CACHE INTERNAL "")

polyorch_rust_package_version(PACKAGE dash-ed MANIFEST "${_ws}" OUT_VAR _dver)
ck_str("${_dver}" "0.1.0")
# cache surface: dashes normalized to underscores in the variable name
ck_str("${POLYORCH_RUST_PKG_dash_ed_VERSION}" "0.1.0")

polyorch_rust_package_version(PACKAGE say-hi MANIFEST "${_ws}" OUT_VAR _sver)
ck_str("${_sver}" "0.1.0")
ck_str("${POLYORCH_RUST_PKG_say_hi_VERSION}" "0.1.0")

# Cache short-circuit: dash-ed WITHOUT a manifest would run metadata in the
# case directory (no Cargo.toml anywhere above tests/cases -- the call would
# fail), so a clean 0.1.0 here proves the cached leg answered.
polyorch_rust_package_version(PACKAGE dash-ed OUT_VAR _dver2)
ck_str("${_dver2}" "0.1.0")

# ------------------------------------------------------- negative legs -------
# A package missing from the metadata must FATAL naming what IS available
# (same idiom as polyorch_rust_import's CRATES guard); a dead manifest FATALs
# with cargo's own error tail. The child re-exec keeps the parent's verdict
# independent of the FATAL paths.
if(POLYORCH_CHILD)
    if(POLYORCH_PKGVER_LEG STREQUAL unknown)
        polyorch_rust_package_version(PACKAGE not-a-crate MANIFEST "${_ws}"
            OUT_VAR _bad)
        message(FATAL_ERROR "GUARD-NOT-FIRED unknown-package")
    else()
        polyorch_rust_package_version(PACKAGE dash-ed
            MANIFEST "${_wsdir}/no-such-Cargo.toml" OUT_VAR _bad2)
        message(FATAL_ERROR "GUARD-NOT-FIRED dead-manifest")
    endif()
endif()

macro(pkgver_child leg rx)
    execute_process(
        COMMAND "${CMAKE_COMMAND}" "-DPOLYORCH_CHILD=1" "-DPOLYORCH_PKGVER_LEG=${leg}"
                -P "${CMAKE_CURRENT_LIST_FILE}"
        RESULT_VARIABLE _pv_rc OUTPUT_VARIABLE _pv_o ERROR_VARIABLE _pv_e)
    string(REGEX REPLACE "[ \r\n\t]+" " " _pv_txt "${_pv_o}${_pv_e}")
    if(_pv_rc EQUAL 0)
        message(FATAL_ERROR "pkgver child (${leg}) exited 0, expected FATAL [${rx}]")
    endif()
    if(_pv_txt MATCHES "GUARD-NOT-FIRED")
        message(FATAL_ERROR "pkgver child (${leg}) reached the sentinel -- guard did not fire")
    endif()
    if(NOT _pv_txt MATCHES "${rx}")
        message(FATAL_ERROR "pkgver child (${leg}) rc=${_pv_rc} output lacks [${rx}]: ${_pv_txt}")
    endif()
endmacro()

pkgver_child(unknown
    "polyorch_rust_package_version: no package 'not-a-crate' in the cargo metadata")
pkgver_child(deadmanifest
    "polyorch_rust_package_version: cargo metadata failed")

message(STATUS "pkgver: all legs pass")
