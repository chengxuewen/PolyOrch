# requires: system-rust
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

cmake_policy(SET CMP0219 NEW)   # macro args keep backslashes (regex escapes)

# WP11 e2e: the VSCode debug surface against a real cargo fixture. Checks
# register output (spec row shape), the generated launch/tasks pair (JSONC
# fields, cross-reference closure), idempotency of a second configure, and
# that the launch program path materializes after building the mediator.
set(_cfg "$ENV{POLYORCH_TEST_CONFIG}")
if(NOT _cfg)
    set(_cfg Debug)
endif()
_polyorch_pixi_scratch(_s)
set(_b "${_s}/vd")
# cargo profile segment for the driven config (Debug->debug, else release --
# the matrix cells only exercise these two)
if(_cfg STREQUAL "Debug")
    set(_seg "debug")
else()
    set(_seg "release")
endif()

drv_run(_dlog _rc SKIP_VAR _skip
    FIXTURE "${CMAKE_CURRENT_LIST_DIR}/../fixtures/vsdbg"
    BUILD "${_b}" CONFIG "${_cfg}")
if(_skip)
    message(STATUS "t-rust-vsdbg : SKIP (fixture gate: no cargo)")
    return()
endif()

# ---- spec registration ---------------------------------------------------
file(READ "${_b}/properties.txt" _props)
ck(_props MATCHES "specs=vb\\|")                 # handle first
foreach(_leg "vsdbg-bin" "${_seg}/vsdbg-bin" "rs")
    # program carries the bin basename; segment derives from the target dir;
    # cwd points at the crate dir (semicolon-free so the row stays one token)
    ck(_props MATCHES "${_leg}")
endforeach()

# ---- generated documents --------------------------------------------------
file(READ "${_b}/vsout/launch.json" _lj)
file(READ "${_b}/vsout/tasks.json" _tj)
ck(_lj MATCHES "\"name\": \"PolyOrch: vb \\(${_seg}\\)\"")
ck(_lj MATCHES "\"type\": \"lldb\"")
ck(_lj MATCHES "\"program\": \"${_b}/\\.cargo-target/${_seg}/vsdbg-bin\"")
ck(_lj MATCHES "\"preLaunchTask\": \"PolyOrch: vb \\(${_seg}\\)\"")
ck(_tj MATCHES "\"label\": \"PolyOrch: vb \\(${_seg}\\)\"")     # closure
ck(_tj MATCHES "\"--target\", \"vb-build\"")
ck(_lj MATCHES "__POLYORCH_GENERATED_BEGIN__")

# ---- idempotency: a second configure must not touch the bytes -------------
file(SHA256 "${_b}/vsout/launch.json" _h1)
file(SHA256 "${_b}/vsout/tasks.json" _h2)
# same-tree incremental reconfigure (drv_run would wipe and re-drive);
# compose the child PATH the way the driver does (case env has no cargo)
execute_process(COMMAND "${CMAKE_COMMAND}" -S
    "${CMAKE_CURRENT_LIST_DIR}/../fixtures/vsdbg" -B "${_b}"
    ENVIRONMENT "PATH=$ENV{PATH}:$ENV{HOME}/.cargo/bin:$ENV{HOME}/.pixi/bin"
    RESULT_VARIABLE _rc OUTPUT_QUIET ERROR_QUIET)
ck(_rc EQUAL 0)
file(SHA256 "${_b}/vsout/launch.json" _h1b)
file(SHA256 "${_b}/vsout/tasks.json" _h2b)
ck(_h1 STREQUAL _h1b)
ck(_h2 STREQUAL _h2b)

# ---- the program path materializes after building the mediator ------------
execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_b}"
    --config "${_cfg}" --target vb-build
    RESULT_VARIABLE _rc OUTPUT_QUIET ERROR_QUIET)
ck(_rc EQUAL 0)
if(EXISTS "${_b}/.cargo-target/${_seg}/vsdbg-bin")
    set(_pe TRUE)
else()
    set(_pe FALSE)
endif()
ck(_pe)   # launch program == the real artifact the build produced


message(STATUS "t-rust-vsdbg: OK (register + docs + idempotency + artifact materialization)")

