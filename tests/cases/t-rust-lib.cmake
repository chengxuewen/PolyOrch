# e2e: required
# requires: system-rust
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

# R3 LIB kind, end-to-end (system cargo route). Drives tests/fixtures/rust-lib
# through tests/fixtures/_driver.cmake:
#   leg 1  the mediator builds: cargo --lib runs through the wrapper and the
#          naming-table path .cargo-target/<profile>/libdemo_core.rlib appears,
#          non-empty (the driver asserts existence; the case pins the profile
#          directory + the file name shape);
#   leg 2  the --lib restriction: the package's bin (never_built) does NOT
#          exist next to the rlib -- the restriction is proven physically,
#          not by argv text;
#   leg 3  aggregate membership: a FRESH build dir builds the liball target
#          alone; the driver's artifact assertion passes only because the
#          aggregate edge pulls demo-build (a missing edge strands the rlib);
#   leg 4  reconfigure idempotence: a second configure of the same build dir
#          exits 0 with no target-redefinition error.
# The MC cells exclude this case (tests/matrix.sh family list): the fixture's
# artifacts contract is a configure-time literal path, the single-config shape
# (same rule as rule-wiring/import-ws/install-export).

polyorch_requires(system-rust _req)
if(NOT _req)
    message(STATUS "t-rust-lib : SKIP (no system cargo on PATH or in ~/.cargo/bin)")
    return()
endif()

set(_cfg "$ENV{POLYORCH_TEST_CONFIG}")
if(NOT _cfg)
    set(_cfg Debug)
endif()
string(TOLOWER "${_cfg}" _cl)
if(_cl STREQUAL "" OR _cl STREQUAL "debug")
    set(_want debug)
else()
    set(_want release)
endif()
_polyorch_pixi_scratch(_s)
set(_fx "${CMAKE_CURRENT_LIST_DIR}/../fixtures/rust-lib")

# ------------------------------------------------ leg 1: mediator builds ----
drv_run(_dlog _rc SKIP_VAR _skip
    FIXTURE "${_fx}" BUILD "${_s}/b1" CONFIG "${_cfg}" TARGETS demo-build)
if(_skip)
    message(STATUS "t-rust-lib : SKIP (fixture gate: capability absent at configure)")
    return()
endif()
drv_get(_dlog demo _art)
ck_file("${_art}")
if(NOT _art MATCHES "/\\.cargo-target/${_want}/libdemo_core\\.rlib$")
    message(FATAL_ERROR "rust-lib: artifact ${_art} not at .cargo-target/${_want}/libdemo_core.rlib")
endif()
file(SIZE "${_art}" _len)
ck(_len GREATER 0)

# ------------------------------------------- leg 2: --lib restriction -------
get_filename_component(_pdir "${_art}" DIRECTORY)
if(EXISTS "${_pdir}/never_built")
    message(FATAL_ERROR
        "rust-lib: bin never_built was built alongside the rlib -- the --lib restriction leaked (${_pdir}/never_built)")
endif()

# --------------------------------------- leg 3: aggregate edge, fresh dir ---
drv_run(_dlog2 _rc2 SKIP_VAR _skip2
    FIXTURE "${_fx}" BUILD "${_s}/b2" CONFIG "${_cfg}" TARGETS liball)
if(_skip2)
    message(STATUS "t-rust-lib : SKIP (fixture gate: capability absent at configure)")
    return()
endif()
drv_get(_dlog2 demo _art2)
ck_file("${_art2}")

# -------------------------------------- leg 4: reconfigure idempotence ------
# Re-run configure on the SAME dir b2 (drv always wipes; this leg needs the
# dirty tree). cargo is needed at configure (polyorch_rust_setup probe), so
# compose the child PATH exactly like the driver does.
set(_sep ":")
if(CMAKE_HOST_WIN32)
    set(_sep ";")
endif()
set(_cpath "$ENV{PATH}")
if(DEFINED ENV{HOME})
    foreach(_d "$ENV{HOME}/.cargo/bin" "$ENV{HOME}/.pixi/bin")
        if(EXISTS "${_d}")
            set(_cpath "${_d}${_sep}${_cpath}")
        endif()
    endforeach()
endif()
execute_process(COMMAND "${CMAKE_COMMAND}" -S "${_fx}" -B "${_s}/b2"
    "-DCMAKE_BUILD_TYPE=${_cfg}"
    ENVIRONMENT "PATH=${_cpath}"
    RESULT_VARIABLE _rc3 OUTPUT_VARIABLE _o3 ERROR_VARIABLE _o3)
if(NOT _rc3 EQUAL 0)
    message(FATAL_ERROR "rust-lib: reconfigure of b2 failed rc=${_rc3}: ${_o3}")
endif()
if(_o3 MATCHES "already defined|add_custom_target.*demo-build")
    message(FATAL_ERROR "rust-lib: reconfigure collided: ${_o3}")
endif()

message(STATUS "rust-lib: OK (rlib at ${_art}, bin unbuilt, aggregate edge live, reconfigure clean)")
