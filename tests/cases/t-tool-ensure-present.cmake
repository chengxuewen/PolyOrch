# requires: pixi
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

# polyorch_pixi_tool_ensure: tool-only path. With pixi already present and the
# pin satisfied it must succeed WITHOUT installing; NO_PRECHECK + QUIET keep it
# fully offline. SKIPs (exit 0) when no pixi exists so the suite stays portable
# (the install path itself is exercised by t-bootstrap-e2e only when forced).
polyorch_requires(pixi _req)
if(NOT _req)
    message(STATUS "t-tool-ensure-present : SKIP (no pixi on this machine)")
    return()
endif()
# No pre-set: an empty normal variable would shadow the find result on
# cmake 4.4.3 (PIT -- the pre-D15 shape of this case silently skipped here).
find_program(_pixi NAMES pixi PATHS "$ENV{HOME}/.pixi/bin" "$ENV{PIXI_HOME}/bin")
ck(_pixi)

polyorch_pixi_tool_ensure(VERSION 0.1.0 NO_PRECHECK QUIET)
ck(PolyOrch_PIXI_EXECUTABLE)
ck(NOT PolyOrch_PIXI_VERSION VERSION_LESS 0.1.0)

# The locate cache must be reusable by the rest of the module unchanged.
polyorch_pixi_find(QUIET)
ck_str("${PolyOrch_PIXI_EXECUTABLE}" "${_pixi}")

message(STATUS "tool-ensure: OK")
