# e2e: required
# requires: system-rust
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

# Task 6 acceptance (P-4 install-consumer chain), fixture-driver edition:
# tests/fixtures/install-e2e stages a REAL cargo-built staticlib + bin, the
# EXPORT replay stub is included by the SECOND, unrelated C project
# (fixtures/install-e2e/consumer, driven through the same _driver.cmake), and
# that consumer links + runs through the stub's re-attached interface. The
# negative leg strips the INTERFACE_LINK lines from a stub copy and the SAME
# consumer must then FAIL to link with an undefined `pow` -- proof that what
# the positive leg exercises is what the stub ships. The PREBUILD ordering
# edge (hook-lib built after the stamp target) is asserted by the stamp file
# the driver verifies.

polyorch_requires(system-rust _req)
if(NOT _req)
    message(STATUS "t-rust-install-e2e : SKIP (no system cargo on PATH or in ~/.cargo/bin)")
    return()
endif()

set(_cfg "$ENV{POLYORCH_TEST_CONFIG}")
if(NOT _cfg)
    set(_cfg Debug)
endif()
set(_drv "${CMAKE_CURRENT_LIST_DIR}/../fixtures/_driver.cmake")
set(_fx "${CMAKE_CURRENT_LIST_DIR}/../fixtures/install-e2e")
_polyorch_pixi_scratch(_r)
set(_b "${_r}/b")
set(_stage "${_r}/stage")

set(_genargs "")
if("$ENV{POLYORCH_TEST_GENERATOR}")
    set(_genargs "-DGENERATOR=$ENV{POLYORCH_TEST_GENERATOR}")
endif()

# --- main fixture: configure + build the aggregate (covers the PREBUILD leg) --
execute_process(COMMAND "${CMAKE_COMMAND}"
    "-DFIXTURE=${_fx}" "-DBUILD=${_b}" "-DCONFIG=${_cfg}"
    "-DTARGETS=polyorch-rust-all" ${_genargs}
    -P "${_drv}"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
set(_dlog "${_out}${_err}")
drv_echo(_dlog)
if(_dlog MATCHES "DRIVER: skip")
    message(STATUS "t-rust-install-e2e : SKIP (fixture gate: capability absent at configure)")
    return()
endif()
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "rust-install-e2e: driver failed (${_rc})\n${_dlog}")
endif()

file(READ "${_b}/imported.txt" _imps)
ck_str("${_imps}" "dash_ed;say-hi-exe")
drv_get(_dlog prebuild _stamp)
ck_file("${_stamp}")

# --- stage --------------------------------------------------------------------
execute_process(COMMAND "${CMAKE_COMMAND}" --install "${_b}" --prefix "${_stage}"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "rust-install-e2e: install failed (${_rc})\n${_out}${_err}")
endif()

file(READ "${_b}/name_static.txt" _sname)
file(READ "${_b}/name_bin.txt" _bname)
string(STRIP "${_sname}" _sname)
string(STRIP "${_bname}" _bname)
set(_staged_lib "${_stage}/lib/${_sname}")
set(_staged_bin "${_stage}/bin/${_bname}")
set(_stub "${_stage}/lib/cmake/demo/demo-rust.cmake")
ck_file("${_staged_lib}")
ck_file("${_staged_bin}")
ck_file("${_stub}")

# The staged binary is standalone: run it from the install tree.
execute_process(COMMAND "${_staged_bin}"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _bout ERROR_VARIABLE _berr)
if(NOT _rc EQUAL 0 OR NOT _bout MATCHES "INSTALL_E2E_BIN")
    message(FATAL_ERROR "rust-install-e2e: staged bin rc=${_rc} out=[${_bout}${_berr}]")
endif()

# --- positive consumer: a fresh project, C only, include(stub) ---------------
execute_process(COMMAND "${CMAKE_COMMAND}"
    "-DFIXTURE=${_fx}/consumer" "-DBUILD=${_r}/cb" "-DCONFIG=${_cfg}"
    "-DPASSTHROUGH=-DPOLYORCH_IE_STUB=${_stub}" ${_genargs}
    -P "${_drv}"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
set(_dlog "${_out}${_err}")
drv_echo(_dlog)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "rust-install-e2e: consumer driver failed (${_rc})\n${_dlog}")
endif()
drv_get(_dlog capp _capp)
ck_file("${_capp}")
execute_process(COMMAND "${_capp}"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _cout ERROR_VARIABLE _cerr)
if(NOT _rc EQUAL 0 OR NOT _cout MATCHES "INSTALL_E2E_CONSUMED")
    message(FATAL_ERROR "rust-install-e2e: consumer rc=${_rc} out=[${_cout}${_cerr}]")
endif()
# The stub must have carried the bin too: the consumer's genex path equals the
# staged binary, and the interface came back non-empty.
file(READ "${_r}/cb/exe.txt" _staged_via_stub)
string(STRIP "${_staged_via_stub}" _staged_via_stub)
if(NOT _staged_via_stub STREQUAL _staged_bin)
    message(FATAL_ERROR "rust-install-e2e: stub bin path [${_staged_via_stub}] != staged [${_staged_bin}]")
endif()
file(READ "${_r}/cb/ifl.txt" _ifl)
if(_ifl STREQUAL "")
    message(FATAL_ERROR "rust-install-e2e: stub re-attached no INTERFACE_LINK_LIBRARIES")
endif()
message(STATUS "rust-install-e2e: consumer link interface [${_ifl}]")

# --- negative leg: stripped stub must break the SAME consumer link ------------
file(READ "${_stub}" _stubtxt)
string(REGEX REPLACE "[^\n]*INTERFACE_LINK[^\n]*" "" _badtxt "${_stubtxt}")
string(FIND "${_badtxt}" "INTERFACE_LINK" _still)
if(NOT _still EQUAL -1)
    message(FATAL_ERROR "rust-install-e2e: strip did not remove the INTERFACE lines")
endif()
set(_badstub "${_stage}/lib/cmake/demo/demo-rust-bad.cmake")
file(WRITE "${_badstub}" "${_badtxt}")
execute_process(COMMAND "${CMAKE_COMMAND}"
    "-DFIXTURE=${_fx}/consumer" "-DBUILD=${_r}/cbneg" "-DCONFIG=${_cfg}"
    "-DPASSTHROUGH=-DPOLYORCH_IE_STUB=${_badstub}" ${_genargs}
    -P "${_drv}"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
set(_dlog "${_out}${_err}")
if(_rc EQUAL 0)
    message(FATAL_ERROR
        "rust-install-e2e: NEGATIVE leg did not bite -- capp linked against the "
        "stripped stub, so the probed system libs were never load-bearing")
endif()
# The bite must be the `pow` symbol specifically. Assert against the driver's
# raw on-disk build log: unprocessed child output (the driver's STATUS echo
# re-wraps long lines and splits the phrase).
file(READ "${_r}/cbneg/_build.log" _bld)
string(REPLACE "\n" " " _flat "${_bld}")
if(NOT _flat MATCHES "undefined reference to .?pow")
    message(FATAL_ERROR "rust-install-e2e: neg link failed (rc=${_rc}) but not on pow:\n${_bld}")
endif()
string(REGEX MATCH "[^ ]*undefined reference to .?pow[^ ]*" _excerpt "${_flat}")

message(STATUS
    "rust-install-e2e: OK (staged lib/${_sname} + bin/${_bname}, stub replay incl. "
    "bin-path equality + interface [${_ifl}]; stripped stub -> ${_excerpt})")
