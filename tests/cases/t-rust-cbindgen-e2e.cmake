# e2e: required
# requires: cbindgen
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

# WP7 live leg: the REAL cbindgen on both signatures against the fixture
# crate's extern "C" surface. cbindgen reads the crate through the
# CARGO/RUSTC env the rule passes (cargo metadata only -- std-only crate,
# no registry access), so once the binary exists the leg is network
# clean; acquisition itself is the deferred ALLOW_INSTALL/crates.io half
# (same discipline as the cxxbridge live leg).

polyorch_requires(cbindgen _req)
if(NOT _req)
    message(STATUS "t-rust-cbindgen-e2e : SKIP (no cbindgen on PATH or in ~/.cargo/bin)")
    return()
endif()

set(_cfg "$ENV{POLYORCH_TEST_CONFIG}")
if(NOT _cfg)
    set(_cfg Debug)
endif()
_polyorch_pixi_scratch(_s)
set(_b "${_s}/cgx")
set(_dargs "-DFIXTURE=${CMAKE_CURRENT_LIST_DIR}/../fixtures/cbindgen"
           "-DBUILD=${_b}" "-DCONFIG=${_cfg}"
           "-DTARGETS=polyorch-cbindgen-cb-lib-bindings\\;polyorch-cbindgen-cb-manual-bindings")
if("$ENV{POLYORCH_TEST_GENERATOR}")
    list(APPEND _dargs "-DGENERATOR=$ENV{POLYORCH_TEST_GENERATOR}")
endif()
execute_process(COMMAND "${CMAKE_COMMAND}" ${_dargs}
    -P "${CMAKE_CURRENT_LIST_DIR}/../fixtures/_driver.cmake"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
set(_dlog "${_out}${_err}")
drv_echo(_dlog)
if(_dlog MATCHES "DRIVER: skip")
    message(STATUS "t-rust-cbindgen-e2e : SKIP (fixture gate: capability absent at configure)")
    return()
endif()
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "t-rust-cbindgen-e2e: driver failed (${_rc})\n${_dlog}")
endif()

set(_g "${_b}/polyorch_generated/cbindgen")
foreach(_hdr "cb-lib/include/rust-lib.h" "cb-manual/include/sub/manual.h")
    ck_file("${_g}/${_hdr}")
    file(READ "${_g}/${_hdr}" _h)
    ck(_h MATCHES "cb_marker_fn")   # the real declaration, parsed from lib.rs
    ck(_h MATCHES "extern \"C\"")
    ck(_h MATCHES "Point")          # the #[repr(C)] struct re-emitted
endforeach()
# The reference's depfile claim (corr:2235): real cbindgen lists sources.
file(READ "${_g}/cb-lib/depfile/rust-lib.h.d" _dep)
ck(_dep MATCHES "lib[.]rs")
message(STATUS "t-rust-cbindgen-e2e : OK")
