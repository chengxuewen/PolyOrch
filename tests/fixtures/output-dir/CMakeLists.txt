# tests/fixtures/output-dir -- fixture for cases/t-rust-output-dir.cmake:
# the reference output-directory machinery (corr "test/output directory",
# MIT c4786e7) adapted to the PolyOrch rust face. Three handles cover the
# three destination classes:
#   od-bin    -> RUNTIME_OUTPUT_DIRECTORY   (bin)
#   od-static -> ARCHIVE_OUTPUT_DIRECTORY   (staticlib)
#   od-shared -> LIBRARY_OUTPUT_DIRECTORY   (cdylib)
# Cache knobs from the case (via _driver PASSTHROUGH):
#   OD_MODE = targetprop | cachevar
#       targetprop: output dirs are set AFTER polyorch_rust_build -- the
#                   late-property leg (the reference's targetprop shape);
#                   only a generate-time (DEFERred) location read honours it.
#       cachevar:   CMAKE_*_OUTPUT_DIRECTORY set BEFORE the build calls --
#                   the creation-time property-initialisation leg
#                   (corr:2313 _corrosion_initialize_properties).
#   OD_MC=1 OD_CFG=<Config>  multi-config leg: declare the contract for the
#       given config only (the driver builds with --config <Config>).
# The destination values deliberately contain a literal space ("out bin")
# -- the reference's free space-path trick (corr:347 "tested to work with
# paths with spaces").
cmake_minimum_required(VERSION 3.25)
project(polyorch-fixture-output-dir LANGUAGES NONE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(PolyOrchRustHelpers)
include("${CMAKE_CURRENT_LIST_DIR}/../../cases/_requires.cmake")

polyorch_requires(system-rust _req)
if(NOT _req)
    message(STATUS "polyorch-fixture-output-dir : SKIP (no cargo on the child PATH)")
    return()
endif()

polyorch_rust_setup(REQUIRED NO_NATIVE_PROBE)

set(_ws "${CMAKE_CURRENT_LIST_DIR}/rust-ws/Cargo.toml")
set(_out_bin "${CMAKE_BINARY_DIR}/out bin")
set(_out_lib "${CMAKE_BINARY_DIR}/out lib")
set(_out_arc "${CMAKE_BINARY_DIR}/out arc")

if(OD_MODE STREQUAL "cachevar")
    # Leg B: variables BEFORE creation -- build() must seed the target
    # properties from them (corr:2313 init convention).
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${_out_bin}")
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${_out_lib}")
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${_out_arc}")
    polyorch_rust_build(TARGET od-bin    PACKAGE bin-greet CRATE greet-cli BINARY MANIFEST "${_ws}")
    polyorch_rust_build(TARGET od-static PACKAGE st-greet  CRATE st_greet  STATIC MANIFEST "${_ws}")
    polyorch_rust_build(TARGET od-shared PACKAGE sh-greet  CRATE sh_greet  SHARED MANIFEST "${_ws}")
else()
    # Leg A: properties AFTER the build calls -- only a generate-time read
    # sees them (the RED leg for the DEFER port).
    polyorch_rust_build(TARGET od-bin    PACKAGE bin-greet CRATE greet-cli BINARY MANIFEST "${_ws}")
    polyorch_rust_build(TARGET od-static PACKAGE st-greet  CRATE st_greet  STATIC MANIFEST "${_ws}")
    polyorch_rust_build(TARGET od-shared PACKAGE sh-greet  CRATE sh_greet  SHARED MANIFEST "${_ws}")
    set_target_properties(od-bin    PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${_out_bin}")
    set_target_properties(od-static PROPERTIES ARCHIVE_OUTPUT_DIRECTORY "${_out_arc}")
    set_target_properties(od-shared PROPERTIES LIBRARY_OUTPUT_DIRECTORY "${_out_lib}")
endif()

# Profile + config mapping for the contract, mirroring the rule semantics:
#   single-config: CMAKE_BUILD_TYPE unset/Debug -> debug, else release.
#   multi-config : Config Debug -> debug, else release; the cargo target dir
#                  gains a <Config> level and the staged dir the config name.
if(OD_MC)
    set(_cfg "${OD_CFG}")
    string(TOUPPER "${_cfg}" _cfg_up)
    if(_cfg STREQUAL "Debug")
        set(_prof debug)
    else()
        set(_prof release)
    endif()
    set(_cfgdir "/${_cfg}")
else()
    string(TOLOWER "${CMAKE_BUILD_TYPE}" _bt)
    if(_bt STREQUAL "" OR _bt STREQUAL "debug")
        set(_prof debug)
        set(_cfg "Debug")
    else()
        set(_prof release)
        set(_cfg "Release")
    endif()
    set(_cfgdir "")
endif()

# $<TARGET_FILE> reference-shape probes (generate-time values per config).
file(GENERATE OUTPUT "${CMAKE_BINARY_DIR}/tf-$<CONFIG>.txt"
    CONTENT "$<TARGET_FILE:od-bin>|$<TARGET_FILE:od-static>|$<TARGET_FILE:od-shared>")

_polyorch_rust_artifact_names(TRIPLE "${POLYORCH_RUST_HOST_TARGET}"
    KIND bin    CRATE greet-cli PROFILE "${_prof}" FILE_OUT _bf DIR_OUT _bd)
_polyorch_rust_artifact_names(TRIPLE "${POLYORCH_RUST_HOST_TARGET}"
    KIND static CRATE st_greet  PROFILE "${_prof}" FILE_OUT _sf DIR_OUT _sd)
_polyorch_rust_artifact_names(TRIPLE "${POLYORCH_RUST_HOST_TARGET}"
    KIND shared CRATE sh_greet  PROFILE "${_prof}" FILE_OUT _hf DIR_OUT _hd)

if(OD_MC)
    # cargo segregates the configs by its OWN profile dir (debug/release), so
    # the in-place artifact path is .cargo-target/<profile>/<bin> (shared base).
    set(_cargo "${CMAKE_BINARY_DIR}/.cargo-target/${_prof}/${_bf}")
else()
    set(_cargo "${_bd}/${_bf}")
endif()
set(POLYORCH_FIXTURE_ARTIFACTS
    "bin=${_out_bin}${_cfgdir}/${_bf}"
    "static_lib=${_out_arc}${_cfgdir}/${_sf}"
    "shared=${_out_lib}${_cfgdir}/${_hf}"
    "cargo_bin=${_cargo}")
string(JOIN "\n" _af ${POLYORCH_FIXTURE_ARTIFACTS})
file(WRITE "${CMAKE_BINARY_DIR}/polyorch-fixture-artifacts.txt" "${_af}\n")
