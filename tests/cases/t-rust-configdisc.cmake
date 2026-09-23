# e2e: required
# requires: system-rust
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

# WP9 gap-8: config_discovery (reference test/config_discovery, offline
# inversion). The fixture's .cargo/config.toml sets [build] rustflags
# (--cfg=cfg_disc_flag) and [env] CFG_DISC_ENV; the crate consumes BOTH at
# COMPILE time (cfg selects the printed arm, env! hard-errors when the var
# is absent). A successful build + the FLAG|cfg-disc-env-ok run output is
# proof cargo discovered the file through PolyOrch's WORKING_DIRECTORY +
# --manifest-path combo -- and that the rule's empty-RUSTFLAGS elision holds
# (an emitted RUSTFLAGS= would have shadowed the config's rustflags and the
# MISSING arm would have printed).
polyorch_requires(system-rust _req)
if(NOT _req)
    message(STATUS "t-rust-configdisc : SKIP (no system cargo on PATH or in ~/.cargo/bin)")
    return()
endif()

set(_cfg "$ENV{POLYORCH_TEST_CONFIG}")
if(NOT _cfg)
    set(_cfg Debug)
endif()
_polyorch_pixi_scratch(_s)
set(_b "${_s}/b")

drv_run(_dlog _rc SKIP_VAR _skip
    FIXTURE "${CMAKE_CURRENT_LIST_DIR}/../fixtures/config-disc"
    BUILD "${_b}" CONFIG "${_cfg}" TARGETS cargo-build-cd-bin)
if(_skip)
    message(STATUS "t-rust-configdisc : SKIP (fixture gate: capability absent at configure)")
    return()
endif()

drv_get(_dlog bin _cb)
ck_file("${_cb}")
execute_process(COMMAND "${_cb}"
    RESULT_VARIABLE _lrc OUTPUT_VARIABLE _lout ERROR_VARIABLE _lerr)
message(STATUS "rust-configdisc: cd-probe output: ${_lout}")
if(NOT _lrc EQUAL 0 OR NOT _lout MATCHES "CONFIGDISC:FLAG\|ENV:cfg-disc-env-ok")
    message(FATAL_ERROR "rust-configdisc: discovery markers wrong (rc=${_lrc}): ${_lout}${_lerr}")
endif()

message(STATUS "rust-configdisc: OK (cargo config discovered via the rule's cwd+manifest combo; elision held)")
