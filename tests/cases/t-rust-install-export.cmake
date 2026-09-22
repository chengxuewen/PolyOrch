# e2e: required
# requires: system-rust
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

# WP8 consumer chain: tests/fixtures/install-export stages a REAL
# cargo-built staticlib + bin through ONE full-shape polyorch_rust_install
# call (EXPORT + RUNTIME_DESTINATION + COMPONENT + PUBLIC_HEADER), and a
# SECOND, unrelated C project (consumer/) discovers the staged tree with a
# real find_package(polyorch-demo CONFIG REQUIRED) -- the generated
# <export>Config.cmake wrapper -> <export>-rust.cmake replay stub chain
# replaces the hand-written include() of the install-e2e fixture. Legs:
#   full-install layout + exec-bit split (RUNTIME/EXEC defaults) + staged
#   bin run; per-component --component filtering; the consumer builds +
#   RUNS (header usable at compile time, link through the staged .a);
#   and a negative leg that strips the re-attached INTERFACE_LINK lines
#   from the STAGED stub in place -- the same consumer must then FAIL to
#   link on `pow` (the fold-proof trick shared with t-rust-link-c /
#   t-rust-install-e2e, reused not re-invented).

polyorch_requires(system-rust _req)
if(NOT _req)
    message(STATUS "t-rust-install-export : SKIP (no system cargo on PATH or in ~/.cargo/bin)")
    return()
endif()

set(_cfg "$ENV{POLYORCH_TEST_CONFIG}")
if(NOT _cfg)
    set(_cfg Debug)
endif()
set(_drv "${CMAKE_CURRENT_LIST_DIR}/../fixtures/_driver.cmake")
set(_fx "${CMAKE_CURRENT_LIST_DIR}/../fixtures/install-export")
_polyorch_pixi_scratch(_r)
set(_b "${_r}/b")
set(_stage "${_r}/stage")

set(_genargs "")
if("$ENV{POLYORCH_TEST_GENERATOR}")
    set(_genargs "-DGENERATOR=$ENV{POLYORCH_TEST_GENERATOR}")
endif()

# --- producer: configure + build ---------------------------------------------
execute_process(COMMAND "${CMAKE_COMMAND}"
    "-DFIXTURE=${_fx}" "-DBUILD=${_b}" "-DCONFIG=${_cfg}"
    "-DTARGETS=polyorch-rust-all" ${_genargs}
    -P "${_drv}"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
set(_dlog "${_out}${_err}")
drv_echo(_dlog)
if(_dlog MATCHES "DRIVER: skip")
    message(STATUS "t-rust-install-export : SKIP (fixture gate: capability absent at configure)")
    return()
endif()
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "rust-install-export: producer driver failed (${_rc})\n${_dlog}")
endif()

file(READ "${_b}/imported.txt" _imps)
ck_str("${_imps}" "demo;say-exe")
file(READ "${_b}/name_static.txt" _sname)
file(READ "${_b}/name_bin.txt" _bname)
string(STRIP "${_sname}" _sname)
string(STRIP "${_bname}" _bname)

# --- full install ------------------------------------------------------------
execute_process(COMMAND "${CMAKE_COMMAND}" --install "${_b}" --prefix "${_stage}"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "rust-install-export: install failed (${_rc})\n${_out}${_err}")
endif()

# Layout: default ARCHIVE (lib/) + overridden RUNTIME (appbin/) + flat
# include/ sidecar + the generated cmake pair under lib/cmake/<export>/.
set(_staged_lib "${_stage}/lib/${_sname}")
set(_staged_bin "${_stage}/appbin/${_bname}")
set(_staged_hdr "${_stage}/include/demo.h")
set(_stub "${_stage}/lib/cmake/polyorch-demo/polyorch-demo-rust.cmake")
set(_config "${_stage}/lib/cmake/polyorch-demo/polyorch-demoConfig.cmake")
ck_file("${_staged_lib}")
ck_file("${_staged_bin}")
ck_file("${_staged_hdr}")
ck_file("${_stub}")
ck_file("${_config}")
ck(NOT EXISTS "${_stage}/bin/${_bname}")

# Permission split: the RUNTIME row got the OWNER/EXEC defaults, the
# archive and header rows the plain-file defaults (file(STAT) is not a
# command in this CMake; IS_EXECUTABLE is the one-shot check).
ck(IS_EXECUTABLE "${_staged_bin}")
ck(NOT IS_EXECUTABLE "${_staged_lib}")
ck(NOT IS_EXECUTABLE "${_staged_hdr}")

# The replay stub must carry the header directory for the static handle.
file(READ "${_stub}" _stubtxt)
string(REPLACE "\n" " " _stubflat "${_stubtxt}")
if(NOT _stubflat MATCHES "INTERFACE_INCLUDE_DIRECTORIES")
    message(FATAL_ERROR "rust-install-export: stub carries no include-dir line:\n${_stubtxt}")
endif()

# Staged bin is standalone: run it from the install tree (custom dest).
execute_process(COMMAND "${_staged_bin}"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _bout ERROR_VARIABLE _berr)
if(NOT _rc EQUAL 0 OR NOT _bout MATCHES "INSTALL_EXPORT_BIN")
    message(FATAL_ERROR "rust-install-export: staged bin rc=${_rc} out=[${_bout}${_berr}]")
endif()

# --- component filtering -------------------------------------------------------
# One component name was stamped on every artifact rule of the call; an
# unknown --component must stage nothing (the cmake pair is component-less
# but is likewise outside the requested component).
set(_cstage "${_r}/cstage")
execute_process(COMMAND "${CMAKE_COMMAND}" --install "${_b}" --prefix "${_cstage}"
    --component nosuchcomponent
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "rust-install-export: component-filter install failed (${_rc})\n${_out}${_err}")
endif()
ck(NOT EXISTS "${_cstage}/appbin/${_bname}")
ck(NOT EXISTS "${_cstage}/lib/${_sname}")
ck(NOT EXISTS "${_cstage}/include/demo.h")
execute_process(COMMAND "${CMAKE_COMMAND}" --install "${_b}" --prefix "${_cstage}"
    --component demo
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "rust-install-export: component 'demo' install failed (${_rc})\n${_out}${_err}")
endif()
ck_file("${_cstage}/appbin/${_bname}")
ck_file("${_cstage}/lib/${_sname}")
ck_file("${_cstage}/include/demo.h")

# --- find_package consumer: configure + build + RUN ---------------------------
execute_process(COMMAND "${CMAKE_COMMAND}"
    "-DFIXTURE=${_fx}/consumer" "-DBUILD=${_r}/cb" "-DCONFIG=${_cfg}"
    "-DPASSTHROUGH=-DCMAKE_PREFIX_PATH=${_stage}" ${_genargs}
    -P "${_drv}"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
set(_dlog "${_out}${_err}")
drv_echo(_dlog)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "rust-install-export: consumer driver failed (${_rc})\n${_dlog}")
endif()
drv_get(_dlog capp _capp)
ck_file("${_capp}")
execute_process(COMMAND "${_capp}"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _cout ERROR_VARIABLE _cerr)
if(NOT _rc EQUAL 0 OR NOT _cout MATCHES "INSTALL_EXPORT_CONSUMED")
    message(FATAL_ERROR "rust-install-export: consumer rc=${_rc} out=[${_cout}${_cerr}]")
endif()

# --- negative leg: stripped stub breaks the SAME consumer link on pow --------
string(REGEX REPLACE "[^\n]*INTERFACE_LINK[^\n]*" "" _badtxt "${_stubtxt}")
string(FIND "${_badtxt}" "INTERFACE_LINK" _still)
if(NOT _still EQUAL -1)
    message(FATAL_ERROR "rust-install-export: strip did not remove the INTERFACE_LINK lines")
endif()
file(WRITE "${_stub}" "${_badtxt}")
execute_process(COMMAND "${CMAKE_COMMAND}"
    "-DFIXTURE=${_fx}/consumer" "-DBUILD=${_r}/cbneg" "-DCONFIG=${_cfg}"
    "-DPASSTHROUGH=-DCMAKE_PREFIX_PATH=${_stage}" ${_genargs}
    -P "${_drv}"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
set(_dlog "${_out}${_err}")
if(_rc EQUAL 0)
    message(FATAL_ERROR
        "rust-install-export: NEGATIVE leg did not bite -- capp linked against the "
        "stripped stub, so the probed system libs were never load-bearing")
endif()
file(READ "${_r}/cbneg/_build.log" _bld)
string(REPLACE "\n" " " _flat "${_bld}")
if(NOT _flat MATCHES "undefined reference to .?pow")
    message(FATAL_ERROR "rust-install-export: neg link failed (rc=${_rc}) but not on pow:\n${_bld}")
endif()
string(REGEX MATCH "[^ ]*undefined reference to .?pow[^ ]*" _excerpt "${_flat}")

message(STATUS
    "rust-install-export: OK (full-shape install: lib/${_sname} + appbin/${_bname} "
    "+ include/demo.h + Config/stub pair; component filter; find_package consumer "
    "runs; stripped stub -> ${_excerpt})")
