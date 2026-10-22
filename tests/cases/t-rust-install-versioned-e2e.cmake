# e2e: required
# requires: system-rust
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

# SR5 combined acceptance: a real cargo cdylib staged through the FULL
# install-face shape (SOVERSION/VERSION + NAMESPACE + handle=alias +
# COMPONENTS + SUITE_VERSION/COMPATIBILITY + STRIP + HEADERS_DIRECTORY +
# GLOB_HEADERS + STALE_GLOB). Legs: triple chain on disk (real file +
# symlinks resolving to it), --strip honored BOTH ways (the FILES-shape
# strip leg gates on CMAKE_INSTALL_DO_STRIP), the component-dispatching
# find_package consumer builds AND RUNS through vpack::lib, the unknown
# component fails loudly, and a stale version corpse is swept while
# unrelated files survive.
polyorch_requires(system-rust _req)
if(NOT _req)
    message(STATUS "t-rust-install-versioned-e2e : SKIP (no system cargo on PATH or in ~/.cargo/bin)")
    return()
endif()

set(_drv "${CMAKE_CURRENT_LIST_DIR}/../fixtures/_driver.cmake")
set(_fx "${CMAKE_CURRENT_LIST_DIR}/../fixtures/install-versioned")
_polyorch_pixi_scratch(_r)
set(_b "${_r}/b")
set(_stage "${_r}/stage")
set(_stage2 "${_r}/stage-stripped")

drv_run(_plog _prc FIXTURE "${_fx}" BUILD "${_b}"
    PASSTHROUGH "-DPolyOrch_RUST_AGGREGATE_NAME=polyorch-rust-all"
    TARGETS "polyorch-rust-all")
if(_plog MATCHES "DRIVER: skip")
    message(STATUS "t-rust-install-versioned-e2e : SKIP (fixture gate: capability absent at configure)")
    return()
endif()

# ---- install WITHOUT --strip ----
execute_process(COMMAND "${CMAKE_COMMAND}" --install "${_b}" --prefix "${_stage}"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _o ERROR_VARIABLE _e)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "versioned-e2e: install failed (${_rc})\n${_o}${_e}")
endif()

file(READ "${_b}/name_shared.txt" _sfname)
string(STRIP "${_sfname}" _sfname)
set(_real "${_stage}/lib/${_sfname}.0.1.2")
set(_mid "${_stage}/lib/${_sfname}.0")
set(_dev "${_stage}/lib/${_sfname}")
ck_file("${_real}")
ck(IS_SYMLINK "${_mid}")
ck(IS_SYMLINK "${_dev}")
file(REAL_PATH "${_mid}" _midres)
file(REAL_PATH "${_real}" _realres)
ck_str("${_midres}" "${_realres}")
file(REAL_PATH "${_dev}" _devres)
ck_str("${_devres}" "${_realres}")

# the plain install copied byte-identically (no strip without the flag):
drv_get(_plog shared _cargo_sofile)
file(SIZE "${_real}" _sz_nostrip)
file(SIZE "${_cargo_sofile}" _sz_cargo)
ck(${_sz_nostrip} EQUAL ${_sz_cargo})

# export family on disk: full stub + component stub + Config + ConfigVersion
ck_file("${_stage}/lib/cmake/vpack/vpack-rust.cmake")
ck_file("${_stage}/lib/cmake/vpack/vpack-rust-runtime.cmake")
ck_file("${_stage}/lib/cmake/vpack/vpackConfig.cmake")
ck_file("${_stage}/lib/cmake/vpack/vpackConfigVersion.cmake")
# P4 tree + P5 flat header
ck_file("${_stage}/include/vpack/impl.h")
ck_file("${_stage}/include/vpack.h")

# ---- find_package consumer: configure + build + RUN ----
drv_run(_clog _crc FIXTURE "${_fx}/consumer" BUILD "${_r}/cb"
    PASSTHROUGH "-DCMAKE_PREFIX_PATH=${_stage}")
drv_get(_clog capp _capp)
ck_file("${_capp}")
execute_process(COMMAND "${_capp}" RESULT_VARIABLE _rc OUTPUT_VARIABLE _cout)
if(NOT _rc EQUAL 0 OR NOT _cout MATCHES "VPINST_CONSUMED 42")
    message(FATAL_ERROR "versioned-e2e: consumer rc=${_rc} out=[${_cout}]")
endif()

# ---- negative: unknown component must bite ----
drv_run(_blog _brc FIXTURE "${_fx}/consumer" BUILD "${_r}/cbneg"
    EXPECT_FAIL PASSTHROUGH "-DCMAKE_PREFIX_PATH=${_stage}" "-DVPACK_BAD_COMP=nosuch")
string(REPLACE "\n" " " _bflat "${_blog}")
if(NOT _bflat MATCHES "component .nosuch. is not installed")
    message(FATAL_ERROR "unknown-component leg did not bite loudly:\n${_blog}")
endif()

# ---- stale sweep: corpse removed, unrelated survivor, staged set intact --
file(TOUCH "${_stage}/lib/${_sfname}.9.9.9")
file(TOUCH "${_stage}/lib/unrelated.txt")
execute_process(COMMAND "${CMAKE_COMMAND}" --install "${_b}" --prefix "${_stage}"
    RESULT_VARIABLE _rc)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "versioned-e2e: sweep re-install failed (${_rc})")
endif()
ck(NOT EXISTS "${_stage}/lib/${_sfname}.9.9.9")
ck_file("${_stage}/lib/unrelated.txt")
ck_file("${_real}")
ck(IS_SYMLINK "${_dev}")

# ---- install WITH --strip: the CODE leg fires ----
execute_process(COMMAND "${CMAKE_COMMAND}" --install "${_b}"
    --prefix "${_stage2}" --strip RESULT_VARIABLE _rc OUTPUT_VARIABLE _o ERROR_VARIABLE _e)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "versioned-e2e: --strip install failed (${_rc})\n${_o}${_e}")
endif()
set(_real2 "${_stage2}/lib/${_sfname}.0.1.2")
ck_file("${_real2}")
ck(IS_SYMLINK "${_stage2}/lib/${_sfname}")
# size witness (byte-level "no debug substring" probes are unstable after
# --strip-unneeded: Rust string tables keep "debug_*" words; the section
# removal shows deterministically in the size):
file(SIZE "${_real2}" _sz_strip)
if(NOT _sz_strip LESS _sz_nostrip)
    message(FATAL_ERROR "--strip did not shrink the artifact (${_sz_strip} >= ${_sz_nostrip}): FILES-row strip leg broken")
endif()

message(STATUS "t-rust-install-versioned-e2e: OK (chain ${_sfname} -> .0 -> .0.1.2, debug-present vs --strip-removed, component find_package consumer runs, stale corpse swept)")
