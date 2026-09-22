# e2e: required
# requires: target-x86_64-unknown-linux-musl
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

# WP5 REAL cross leg -- the user-installed rustup target (x86_64-unknown-
# linux-musl) makes this a true end-to-end proof, not a stub: drives
# tests/fixtures/cross-musl through _driver with
# -DPolyOrch_RUST_CARGO_TARGET=x86_64-unknown-linux-musl and asserts the
# physical effects of the consumed routing:
#   * the cross artifacts exist under .cargo-target/<tup>/<profile>/ (the
#      driver-checked eager contract for bin + staticlib),
#   * the bin is an ELF (file(READ) magic) and `file -b` reports it
#      statically linked (musl self-contained -- the real thing),
#   * the staticlib is an ar archive,
#   * setup genuinely routed (routed.txt carries the triple),
#   * the hostbuild-flipped handle fell back to the HOST layer: its
#      generate-time $<TARGET_FILE> probe names .cargo-target/<profile>/
#      (NOT the <tup>/ dir), that file exists, is a dynamically linked
#      ELF -- the distinct directories are honored (no fakery; on this
#      non-cross... this IS a cross host, and the fall-back is observable).
# The generator is pinned to Unix Makefiles regardless of the matrix cell
# (the t-rust-output-dir single-config precedent): the eager-path artifact
# contract is written in single-config shape. The profile follows
# $ENV{POLYORCH_TEST_CONFIG} like the other fixture-driver cases.

polyorch_requires(target-x86_64-unknown-linux-musl _req)
if(NOT _req)
    message(STATUS "t-rust-musl : SKIP (rustup target x86_64-unknown-linux-musl not installed)")
    return()
endif()
find_program(_file_cmd NAMES file)
if(NOT _file_cmd)
    message(STATUS "t-rust-musl : SKIP (no file(1) to verify the ELF/static contracts)")
    return()
endif()

set(_tup "x86_64-unknown-linux-musl")
set(_cfg "$ENV{POLYORCH_TEST_CONFIG}")
if(NOT _cfg)
    set(_cfg Debug)
endif()
string(TOLOWER "${_cfg}" _cl)
if(_cl STREQUAL "debug")
    set(_prof debug)
else()
    set(_prof release)
endif()

_polyorch_pixi_scratch(_s)
set(_b "${_s}/b")

# \; protect the TARGETS list: expanding ${_dargs} would re-split a ';'
# element into three argv tokens (the t-rust-output-dir lesson).
set(_dargs "-DFIXTURE=${CMAKE_CURRENT_LIST_DIR}/../fixtures/cross-musl"
           "-DBUILD=${_b}" "-DCONFIG=${_cfg}" "-DGENERATOR=Unix Makefiles"
           "-DTARGETS=m-bin-cargo\\;m-st-cargo\\;hb-bin-cargo"
           "-DPASSTHROUGH=-DPolyOrch_RUST_CARGO_TARGET=${_tup}")

execute_process(COMMAND "${CMAKE_COMMAND}" ${_dargs}
    -P "${CMAKE_CURRENT_LIST_DIR}/../fixtures/_driver.cmake"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
set(_dlog "${_out}${_err}")
drv_echo(_dlog)
if(_dlog MATCHES "DRIVER: skip")
    message(STATUS "t-rust-musl : SKIP (fixture gate: capability absent at configure)")
    return()
endif()
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "rust-musl: driver failed (${_rc})\n${_dlog}")
endif()

# --- the knob genuinely routed ----------------------------------------------
ck_file("${_b}/routed.txt")
file(READ "${_b}/routed.txt" _routed)
ck_str("${_routed}" "${_tup}")

# --- the cross layer: eager contract paths exist (driver verified) -----------
drv_get(_dlog xbin _xb)
drv_get(_dlog xst _xs)
ck(_xb MATCHES "/\\.cargo-target/${_tup}/${_prof}/hello$")
ck(_xs MATCHES "/\\.cargo-target/${_tup}/${_prof}/libstm\\.a$")

file(READ "${_xb}" _magic HEX LIMIT 4)
ck_str("${_magic}" "7f454c46")            # ELF magic, read not guessed
execute_process(COMMAND "${_file_cmd}" -b "${_xb}"
    RESULT_VARIABLE _frc OUTPUT_VARIABLE _fout)
string(STRIP "${_fout}" _fout)
if(NOT _frc EQUAL 0)
    message(FATAL_ERROR "rust-musl: file(1) failed on ${_xb}")
endif()
message(STATUS "rust-musl: cross bin: ${_fout}")
# Measured contract (rust 1.98 default musl linking = STATIC PIE): the
# binary is ET_DYN, so file(1) still labels it "shared object, dynamically
# linked" (ldd answers the truth: "statically linked"). The load-bearing
# property is the ABSENCE of a program interpreter -- a static image has
# none -- contrasted below against the host leg, which must have one (the
# check cannot pass vacuously).
if(_fout MATCHES "interpreter")
    message(FATAL_ERROR "rust-musl: musl bin has a dynamic interpreter (not static): ${_fout}")
endif()

execute_process(COMMAND "${_file_cmd}" -b "${_xs}"
    RESULT_VARIABLE _frc2 OUTPUT_VARIABLE _fout2)
string(STRIP "${_fout2}" _fout2)
if(NOT _frc2 EQUAL 0 OR NOT _fout2 MATCHES "archive")
    message(FATAL_ERROR "rust-musl: cross staticlib is not an ar archive: [${_fout2}]")
endif()

# --- the hostbuild fall-back: distinct directories, honored ------------------
set(_tfhb "${_b}/tf-hb.txt")
ck_file("${_tfhb}")
file(READ "${_tfhb}" _hb)
string(STRIP "${_hb}" _hb)
message(STATUS "rust-musl: hostbuild bin: ${_hb}")
if(_hb MATCHES "${_tup}")
    message(FATAL_ERROR "rust-musl: hostbuild location stayed in the cross layer: ${_hb}")
endif()
if(NOT _hb MATCHES "/\\.cargo-target/${_prof}/hello$")
    message(FATAL_ERROR "rust-musl: hostbuild location not on the host layer: ${_hb}")
endif()
ck_file("${_hb}")
file(READ "${_hb}" _hmagic HEX LIMIT 4)
ck_str("${_hmagic}" "7f454c46")
execute_process(COMMAND "${_file_cmd}" -b "${_hb}"
    OUTPUT_VARIABLE _hfout)
string(STRIP "${_hfout}" _hfout)
message(STATUS "rust-musl: hostbuild bin: ${_hfout}")
# The contrast leg: the host fall-back binary IS dynamically linked with a
# real interpreter (/lib64/...), proving the cross check above discriminates.
if(NOT _hfout MATCHES "dynamically linked.*interpreter|interpreter.*dynamically linked")
    message(FATAL_ERROR "rust-musl: hostbuild fall-back is not a host dynamic ELF: ${_hfout}")
endif()

message(STATUS "rust-musl: OK (${_tup} bin static-ELF + staticlib archive under .cargo-target/${_tup}/${_prof}/; hostbuild fell back to ${_prof}/)")
