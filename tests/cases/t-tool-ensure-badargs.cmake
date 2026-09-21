# expect: fail
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")

# Argument validation before any locate/network work.
polyorch_pixi_tool_ensure(BOGUS)
message(FATAL_ERROR "expected rejection of unknown args")
