# tests/fixtures/import-ws -- fixture for cases/t-rust-import-ws.cmake.
# polyorch_rust_import over a REAL cargo workspace (rust-ws/, two members)
# with a real pixi rust toolchain: `cargo metadata` runs for real (the offline
# half, the parser table, is t-rust-metadata.cmake).
#   dash-ed  [lib] crate-type=staticlib -> handle dash_ed, artifact libdash_ed.a
#   say-hi   bin                        -> handle say-hi-exe, runs, prints marker
# IMPORTED_TARGETS is asserted as an EXACT set (P4: a stray or missing handle
# fails). The negative leg re-enters cargo metadata with a ghost CRATES entry:
# configure this dir a second time with -DPOLYORCH_IW_CRATES=ghost-pkg and the
# FATAL phrase naming the available packages must appear.
cmake_minimum_required(VERSION 3.25)
project(polyorch-fixture-import-ws LANGUAGES NONE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(PolyOrchPixiHelpers)
include(PolyOrchRustHelpers)
include("${CMAKE_CURRENT_LIST_DIR}/../../cases/_requires.cmake")

polyorch_requires(pixi-rust _req)
if(NOT _req)
    message(STATUS "polyorch-fixture-import-ws : SKIP (no pixi env materialized with a cargo)")
    return()
endif()

# --- pixi bootstrap (WP2 deletes this block + pixi.toml) ----------------------
# Shared workspace override: a case that drives this fixture twice (positive
# + negative leg) points both configures at one pixi workspace so the second
# install replays the first one's lock instead of re-solving (the heredoc-era
# shared WORKDIR behavior). Default: one workspace per build dir.
if(POLYORCH_FIXTURE_PIXI_WS)
    set(_ws "${POLYORCH_FIXTURE_PIXI_WS}")
else()
    set(_ws "${CMAKE_BINARY_DIR}/pixi-ws")
endif()
file(MAKE_DIRECTORY "${_ws}")
file(COPY_FILE "${CMAKE_CURRENT_LIST_DIR}/pixi.toml" "${_ws}/pixi.toml")
polyorch_pixi_setup(MANIFEST "${_ws}/pixi.toml" ENVIRONMENT rust INSTALL)

# NO_NATIVE_PROBE: the link interface is t-rust-link-c's subject; this case
# is about the import registry itself.
polyorch_rust_setup(FROM pixi REQUIRED NO_NATIVE_PROBE)

set(_cws "${CMAKE_CURRENT_LIST_DIR}/rust-ws")

# Negative leg: an unknown CRATES package must FATAL the configure with the
# phrase naming the available packages (the case pins both halves of it).
if(POLYORCH_IW_CRATES)
    polyorch_rust_import(MANIFEST "${_cws}/Cargo.toml"
        CRATES "${POLYORCH_IW_CRATES}" IMPORTED_TARGETS _x)
    message(FATAL_ERROR "neg: ghost CRATES entry was accepted")
endif()

# Positive leg: import the workspace whole.
polyorch_rust_import(MANIFEST "${_cws}/Cargo.toml"
    IMPORTED_TARGETS _imps SKIPPED_TARGETS _skips FOLDER "polyorch-import")

file(WRITE "${CMAKE_BINARY_DIR}/imported.txt" "${_imps}")
file(WRITE "${CMAKE_BINARY_DIR}/skipped.txt" "${_skips}")

# P4 exact-set discipline, child side: no plausible-but-wrong handle may exist.
foreach(_x dash-ed say-hi dash_ed-exe dash-ed-exe lib_a)
    if(TARGET "${_x}")
        message(FATAL_ERROR "import: unexpected handle '${_x}' exists")
    endif()
endforeach()
if(NOT TARGET dash_ed-cargo OR NOT TARGET say-hi-exe-cargo)
    message(FATAL_ERROR "import: mediators dash_ed-cargo / say-hi-exe-cargo missing")
endif()

# Registry property + FOLDER pass-through evidence.
get_target_property(_pkg dash_ed POLYORCH_RUST_PACKAGE)
get_target_property(_fld say-hi-exe FOLDER)
file(WRITE "${CMAKE_BINARY_DIR}/pkg.txt" "${_pkg}")
file(WRITE "${CMAKE_BINARY_DIR}/fld.txt" "${_fld}")

# Artifact paths per the frozen naming contract (underscored staticlib). The
# genex of the real handle is written beside it so the case can pin
# table == actual for the binary too.
string(TOLOWER "${CMAKE_BUILD_TYPE}" _bt)
if(_bt STREQUAL "" OR _bt STREQUAL "debug")
    set(_profile debug)
else()
    set(_profile release)
endif()
_polyorch_rust_artifact_names(TRIPLE "${POLYORCH_RUST_HOST_TARGET}"
    KIND static CRATE dash_ed PROFILE "${_profile}" FILE_OUT _lf DIR_OUT _ld)
_polyorch_rust_artifact_names(TRIPLE "${POLYORCH_RUST_HOST_TARGET}"
    KIND bin CRATE say-hi PROFILE "${_profile}" FILE_OUT _bf DIR_OUT _bd)
file(GENERATE OUTPUT "${CMAKE_BINARY_DIR}/bin_path.txt" CONTENT "$<TARGET_FILE:say-hi-exe>")

set(POLYORCH_FIXTURE_ARTIFACTS
    "static_lib=${_ld}/${_lf}"
    "bin=${_bd}/${_bf}")
string(JOIN "\n" _af ${POLYORCH_FIXTURE_ARTIFACTS})
file(WRITE "${CMAKE_BINARY_DIR}/polyorch-fixture-artifacts.txt" "${_af}\n")
