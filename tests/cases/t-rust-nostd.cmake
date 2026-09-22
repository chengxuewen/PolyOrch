# e2e: required
# requires: system-rust
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

# WP9 gap-9: nostd feasibility (reference test/nostd without its NO_STD
# keyword, which PolyOrch does not port -- ledgered). A #![no_std] crate
# with its own panic handler builds through the STANDARD wrapper, and a
# a C consumer links against it AS AN ARCHIVE MEMBER (the reference's
# nostd-cpp-lib shape; a full executable link would need the runtime the
# crate deliberately omits -- so the physical leg is the two archives).
polyorch_requires(system-rust _req)
if(NOT _req)
    message(STATUS "t-rust-nostd : SKIP (no system cargo on PATH or in ~/.cargo/bin)")
    return()
endif()

set(_cfg "$ENV{POLYORCH_TEST_CONFIG}")
if(NOT _cfg)
    set(_cfg Debug)
endif()
_polyorch_pixi_scratch(_s)
set(_b "${_s}/b")

set(_dargs "-DFIXTURE=${CMAKE_CURRENT_LIST_DIR}/../fixtures/nostd"
           "-DBUILD=${_b}" "-DCONFIG=${_cfg}" "-DTARGETS=ns-cpp")
if("$ENV{POLYORCH_TEST_GENERATOR}")
    list(APPEND _dargs "-DGENERATOR=$ENV{POLYORCH_TEST_GENERATOR}")
endif()
execute_process(COMMAND "${CMAKE_COMMAND}" ${_dargs}
    -P "${CMAKE_CURRENT_LIST_DIR}/../fixtures/_driver.cmake"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
set(_dlog "${_out}${_err}")
drv_echo(_dlog)
if(_dlog MATCHES "DRIVER: skip")
    message(STATUS "t-rust-nostd : SKIP (fixture gate: capability absent at configure)")
    return()
endif()
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "rust-nostd: driver failed (${_rc})\n${_dlog}")
endif()

drv_get(_dlog lib _ns)
drv_get(_dlog cpp _cpp)
ck_file("${_ns}")
ck_file("${_cpp}")
file(SIZE "${_ns}" _sz)
ck(_sz GREATER 0)
# The archive member is the physical leg: no_std compiled through the
# wrapper, and the C consumer object referencing ns_add archived against
# it (an executable link is NOT what the reference proves either -- the
# no_std archive still carries DW.ref.rust_eh_personality).
message(STATUS "rust-nostd: OK (no_std staticlib built via the standard wrapper; C consumer archived against it)")
