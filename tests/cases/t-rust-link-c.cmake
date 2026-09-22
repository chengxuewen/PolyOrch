# e2e: required
# requires: system-rust
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

# P-2 acceptance (Task 4), fixture-driver edition: a Rust STATIC artifact
# linked by a real C consumer, end to end -- the ONLY place the
# native-static-libs probe runs against a live toolchain
# (t-rust-native-libs only exercises the parser). Drives
# tests/fixtures/link-c (probe ON, staticlib + C capp) through
# tests/fixtures/_driver.cmake and asserts the chain's physical effects:
# the probe found non-empty system libs, the STATIC interface equals them,
# libm is in the set (the symbol the C link cannot resolve without the
# interface -- cc links libc but not libm implicitly), the link command
# carries -lm and the staticlib, and capp runs and prints the marker.

polyorch_requires(system-rust _req)
if(NOT _req)
    message(STATUS "t-rust-link-c : SKIP (no system cargo on PATH or in ~/.cargo/bin)")
    return()
endif()

set(_cfg "$ENV{POLYORCH_TEST_CONFIG}")
if(NOT _cfg)
    set(_cfg Debug)
endif()
_polyorch_pixi_scratch(_s)
set(_b "${_s}/b")

set(_dargs "-DFIXTURE=${CMAKE_CURRENT_LIST_DIR}/../fixtures/link-c"
           "-DBUILD=${_b}" "-DCONFIG=${_cfg}" "-DTARGETS=capp")
if("$ENV{POLYORCH_TEST_GENERATOR}")
    list(APPEND _dargs "-DGENERATOR=$ENV{POLYORCH_TEST_GENERATOR}")
endif()

execute_process(COMMAND "${CMAKE_COMMAND}" ${_dargs}
    -P "${CMAKE_CURRENT_LIST_DIR}/../fixtures/_driver.cmake"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
set(_dlog "${_out}${_err}")
drv_echo(_dlog)
if(_dlog MATCHES "DRIVER: skip")
    message(STATUS "t-rust-link-c : SKIP (fixture gate: capability absent at configure)")
    return()
endif()
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "rust-link-c: driver failed (${_rc})\n${_dlog}")
endif()

# The probe must have produced a non-empty system-lib list on this host and
# the STATIC import must carry it as its link interface.
file(READ "${_b}/native_libs.txt" _libs)
file(READ "${_b}/iface.txt" _iface)
message(STATUS "rust-link-c: probe native libs = [${_libs}]")
if(_libs STREQUAL "")
    message(FATAL_ERROR "rust-link-c: probe produced no native libs on this toolchain")
endif()
if(NOT _iface STREQUAL _libs)
    message(FATAL_ERROR "rust-link-c: STATIC interface [${_iface}] != probe libs [${_libs}]")
endif()
# libm must be in the set here: that is the symbol the C link cannot resolve
# without the interface (cc links libc but not libm implicitly).
if(NOT _libs MATCHES "(^|;)m($|;)")
    message(FATAL_ERROR "rust-link-c: probe libs [${_libs}] lack libm 'm' (pow test invalid)")
endif()

# The build step must have carried the link: a missing system-lib interface
# fails it with an undefined-reference to pow().
drv_get(_dlog capp _capp)

# The generated link command must carry a probe lib (-lm) and the static lib.
file(GLOB _linktxt "${_b}/CMakeFiles/capp.dir/link.txt")
if(_linktxt)
    file(READ "${_linktxt}" _lt)
    string(STRIP "${_lt}" _lt)
    if(NOT _lt MATCHES "-lm")
        message(FATAL_ERROR "rust-link-c: capp link line lacks -lm from the probe:\n${_lt}")
    endif()
    if(NOT _lt MATCHES "probe_staticlib")
        message(FATAL_ERROR "rust-link-c: capp link line does not reference the staticlib:\n${_lt}")
    endif()
else()
    # Ninja generator has no link.txt; the successful build above is the proof.
    message(STATUS "rust-link-c: link.txt not present (non-Makefile generator); relying on build success")
endif()

# --- run: the linked binary executes and prints the marker. -----------------
ck_file("${_capp}")
file(SIZE "${_capp}" _sz)
ck(_sz GREATER 0)
execute_process(COMMAND "${_capp}"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _cout ERROR_VARIABLE _cerr)
message(STATUS "rust-link-c: capp output: ${_cout}")
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "rust-link-c: capp exited ${_rc}\n${_cout}${_cerr}")
endif()
if(NOT _cout MATCHES "POLYORCH_RUST_LINK_OK")
    message(FATAL_ERROR "rust-link-c: capp stdout lacks marker:\n${_cout}${_cerr}")
endif()

message(STATUS "rust-link-c: OK (Rust staticlib linked + run by a C consumer; probe libs [${_libs}])")
