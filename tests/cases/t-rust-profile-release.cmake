# e2e: required
# requires: system-rust
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")

# Profile <-> CMAKE_BUILD_TYPE binding (Task 2 acceptance, plan R-1 row):
# configures examples/rust-basic standalone with -DCMAKE_BUILD_TYPE=<cfg>
# where <cfg> comes from $ENV{POLYORCH_TEST_CONFIG} (unset => Debug), builds
# the mediator THROUGH THE BACK-COMPAT NAME (greet-cargo -- the rename to
# cargo-build-<T> must not break it), and asserts the cargo profile
# directory the artifact actually landed in:
#   Debug / unset  -> .cargo-target/debug/<bin>
#   anything else  -> .cargo-target/release/<bin>   (corr:762 semantics)
# and, on the release leg, that NO debug artifact was produced -- the guard
# against a Release cell passing via a debug artifact (matrix acceptance
# criterion "right reason"). Same system-rust requires gate as t-rust-rule-wiring.
polyorch_requires(system-rust _req)
if(NOT _req)
    message(STATUS "t-rust-profile-release : SKIP (no system cargo on PATH or in ~/.cargo/bin)")
    return()
endif()

set(_cfg "$ENV{POLYORCH_TEST_CONFIG}")
if(NOT _cfg)
    set(_cfg "Debug")
endif()

_polyorch_pixi_scratch(_s)
set(_src "${CMAKE_CURRENT_LIST_DIR}/../../examples/rust-basic")
set(_b "${_s}/pr-b")

# Same child-PATH recipe as tests/fixtures/_driver.cmake: the example's
# configure resolves the system route via find_program, so the child needs
# ~/.cargo/bin (the parent tool shell lacks it; the probe above already
# accounts for that). This case has no driver to hide behind.
set(_cpath "$ENV{PATH}")
if(EXISTS "$ENV{HOME}/.cargo/bin")
    set(_cpath "$ENV{HOME}/.cargo/bin:${_cpath}")
endif()

execute_process(COMMAND "${CMAKE_COMMAND}" -S "${_src}" -B "${_b}"
    "-DCMAKE_BUILD_TYPE=${_cfg}"
    ENVIRONMENT "PATH=${_cpath}"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "rust-profile-release: child configure failed (${_rc})\n${_out}${_err}")
endif()

execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_b}" --target greet-cargo
    ENVIRONMENT "PATH=${_cpath}"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "rust-profile-release: child build failed (${_rc})\n${_out}${_err}")
endif()

# Expected cargo profile dir: Debug / empty => debug, else release (corr:762).
string(TOLOWER "${_cfg}" _cfg_lc)
if(_cfg_lc STREQUAL "debug")
    set(_want "debug")
else()
    set(_want "release")
endif()

# Artifact base name from the frozen pure table, host triple by OS (same
# mapping as t-rust-rule-wiring).
if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Darwin")
    set(_tri aarch64-apple-darwin)
    if(CMAKE_HOST_SYSTEM_PROCESSOR STREQUAL "x86_64")
        set(_tri x86_64-apple-darwin)
    endif()
elseif(CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
    set(_tri x86_64-pc-windows-msvc)
else()
    set(_tri x86_64-unknown-linux-gnu)
endif()
_polyorch_rust_artifact_names(TRIPLE "${_tri}" KIND bin CRATE greet-cli
    PROFILE "${_want}" FILE_OUT _f)

set(_art "${_b}/.cargo-target/${_want}/${_f}")
ck_file("${_art}")
file(SIZE "${_art}" _len)
ck(_len GREATER 0)

if(NOT _want STREQUAL "debug")
    # Right-reason guard: a fresh scratch tree must NOT also hold a debug
    # build -- that would mean the rule still ignores CMAKE_BUILD_TYPE.
    _polyorch_rust_artifact_names(TRIPLE "${_tri}" KIND bin CRATE greet-cli
        PROFILE debug FILE_OUT _fdbg)
    if(EXISTS "${_b}/.cargo-target/debug/${_fdbg}")
        message(FATAL_ERROR
            "rust-profile-release: CMAKE_BUILD_TYPE=${_cfg} still produced "
            "the debug artifact (.cargo-target/debug/${_fdbg}) -- profile not bound to the config")
    endif()
endif()

message(STATUS "rust-profile-release: OK (${_cfg} -> .cargo-target/${_want}/${_f}, ${_len} bytes)")
