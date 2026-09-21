# expect: fail
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")

# Mutually exclusive modes are rejected at entry, before any execution.
set(PolyOrch_PIXI_EXECUTABLE "/bin/true" CACHE FILEPATH "" FORCE)
set(PolyOrch_PIXI_MANIFEST "/x/pixi.toml" CACHE FILEPATH "" FORCE)
polyorch_pixi_install(FROZEN LOCKED)
message(FATAL_ERROR "expected rejection of FROZEN+LOCKED")
