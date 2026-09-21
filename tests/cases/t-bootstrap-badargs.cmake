# expect: fail
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")

# Argument validation must run BEFORE anything touches the network: a cold
# machine (or CI) has to get a usage error, not a download failure.
polyorch_pixi_bootstrap(BOGUS)
message(FATAL_ERROR "expected rejection of unknown args")
