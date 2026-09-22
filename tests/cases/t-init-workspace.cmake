# requires: pixi
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

# Workspace creation entirely from CMake args (no external pixi.toml):
# NAME/VERSION round-trip through `pixi workspace <..> get`, CHANNELS/PLATFORMS
# land in pixi.toml, ENVIRONMENTS_DIR lands in .pixi/config.toml, and
# IF_NOT_EXISTS keeps user content while refreshing properties.
# Offline (init/set/config never download); needs pixi, else SKIP.
polyorch_requires(pixi _req)
if(NOT _req)
    message(STATUS "t-init-workspace : SKIP (no pixi on this machine)")
    return()
endif()

_polyorch_pixi_scratch(_ws)
polyorch_pixi_init(WORKDIR "${_ws}" NAME t-init-ws VERSION 0.3.7
    CHANNELS conda-forge PLATFORMS linux-64
    ENVIRONMENTS_DIR "${_ws}-detached")

file(READ "${_ws}/pixi.toml" _m)
ck(_m MATCHES t-init-ws)
ck(_m MATCHES 0[.]3[.]7)
ck(_m MATCHES conda-forge)
ck(_m MATCHES linux-64)

file(READ "${_ws}/.pixi/config.toml" _c)
ck(_c MATCHES detached-environments)
ck(_c MATCHES cache)

# IF_NOT_EXISTS: appended feature survives, name refresh still applies.
file(APPEND "${_ws}/pixi.toml" "\n[feature.kept]\n")
polyorch_pixi_init(WORKDIR "${_ws}" NAME t-init-ws IF_NOT_EXISTS)
file(READ "${_ws}/pixi.toml" _m2)
ck(_m2 MATCHES feature[.]kept)

# Default path on an existing manifest must hard-fail.
execute_process(COMMAND "${CMAKE_COMMAND}" "-DWS=${_ws}"
    -P "${CMAKE_CURRENT_LIST_DIR}/_init_exists.cmake" RESULT_VARIABLE _rc)
ck_fail_rc(_rc)

message(STATUS "init-workspace: OK")
