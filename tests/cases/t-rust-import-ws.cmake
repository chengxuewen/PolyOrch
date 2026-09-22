# e2e: required
# requires: system-rust
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

# Task 5 acceptance, fixture-driver edition: polyorch_rust_import over a REAL
# cargo workspace (fixtures/import-ws/rust-ws, two members, zero crates.io
# deps) driven through tests/fixtures/_driver.cmake. Exact-set discipline
# (P4), the underscored staticlib naming contract, running the imported bin,
# and the ghost-CRATES negative leg (a second driver configure with
# -DPOLYORCH_IW_CRATES=ghost-pkg whose FATAL must name the available
# packages). The offline half of the parser is t-rust-metadata.cmake.

polyorch_requires(system-rust _req)
if(NOT _req)
    message(STATUS "t-rust-import-ws : SKIP (no system cargo on PATH or in ~/.cargo/bin)")
    return()
endif()

set(_cfg "$ENV{POLYORCH_TEST_CONFIG}")
if(NOT _cfg)
    set(_cfg Debug)
endif()
set(_fx "${CMAKE_CURRENT_LIST_DIR}/../fixtures/import-ws")
_polyorch_pixi_scratch(_s)

set(_dargs "-DFIXTURE=${_fx}" "-DBUILD=${_s}/b" "-DCONFIG=${_cfg}"
           "-DTARGETS=polyorch-rust-all")
if("$ENV{POLYORCH_TEST_GENERATOR}")
    list(APPEND _dargs "-DGENERATOR=$ENV{POLYORCH_TEST_GENERATOR}")
endif()

execute_process(COMMAND "${CMAKE_COMMAND}" ${_dargs}
    -P "${CMAKE_CURRENT_LIST_DIR}/../fixtures/_driver.cmake"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
set(_dlog "${_out}${_err}")
drv_echo(_dlog)
if(_dlog MATCHES "DRIVER: skip")
    message(STATUS "t-rust-import-ws : SKIP (fixture gate: capability absent at configure)")
    return()
endif()
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "rust-import-ws: driver failed (${_rc})\n${_dlog}")
endif()

drv_get(_dlog static_lib _libp)
drv_get(_dlog bin _binp)

# Registry exact-set evidence (fixture wrote these at configure time).
file(READ "${_s}/b/imported.txt" _imps)
ck_str("${_imps}" "dash_ed;say-hi-exe")
file(READ "${_s}/b/skipped.txt" _skips)
ck_str("${_skips}" "")
file(READ "${_s}/b/pkg.txt" _pkg)
ck_str("${_pkg}" "dash-ed")
file(READ "${_s}/b/fld.txt" _fld)
ck_str("${_fld}" "polyorch-import")

# Staticlib evidence: underscored file name per the naming table, non-empty.
if(NOT _libp MATCHES "libdash_ed[.]a$")
    message(FATAL_ERROR "rust-import-ws: lib artifact path not underscored: ${_libp}")
endif()
ck_file("${_libp}")
file(SIZE "${_libp}" _lsz)
ck(_lsz GREATER 0)

# Table == actual: the naming-table bin equals the handle's real genex path.
file(READ "${_s}/b/bin_path.txt" _genbinp)
string(STRIP "${_genbinp}" _genbinp)
ck_str("${_binp}" "${_genbinp}")

# Binary evidence: the imported exe runs and prints the marker.
ck_file("${_binp}")
execute_process(COMMAND "${_binp}"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _bout ERROR_VARIABLE _berr)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "rust-import-ws: say-hi-exe exited ${_rc}\n${_bout}${_berr}")
endif()
if(NOT _bout MATCHES "IMPORT_WS_OK")
    message(FATAL_ERROR "rust-import-ws: bin stdout lacks marker:\n${_bout}")
endif()

# --- negative leg: unknown CRATES package names the available ones ----------
execute_process(COMMAND "${CMAKE_COMMAND}"
    "-DFIXTURE=${_fx}" "-DBUILD=${_s}/bneg" "-DCONFIG=${_cfg}"
    "-DPASSTHROUGH=-DPOLYORCH_IW_CRATES=ghost-pkg"
    -P "${CMAKE_CURRENT_LIST_DIR}/../fixtures/_driver.cmake"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
set(_dlog "${_out}${_err}")
if(_rc EQUAL 0)
    message(FATAL_ERROR "rust-import-ws: ghost CRATES driver exited 0, expected FATAL")
endif()
# Raw on-disk child configure log (the driver's STATUS echo re-wraps long
# lines and splits the phrases).
file(READ "${_s}/bneg/_configure.log" _cfl)
string(REPLACE "\n" " " _flat "${_cfl}")
if(NOT _flat MATCHES "no package 'ghost-pkg'")
    message(FATAL_ERROR "rust-import-ws: ghost CRATES rc=${_rc} but output lacks the phrase:\n${_cfl}")
endif()
if(NOT _flat MATCHES "available: dash-ed, say-hi")
    message(FATAL_ERROR "rust-import-ws: ghost CRATES message lacks the available list:\n${_cfl}")
endif()

message(STATUS "rust-import-ws: OK (import exact-set, libdash_ed.a + IMPORT_WS_OK run, ghost FATAL)")
