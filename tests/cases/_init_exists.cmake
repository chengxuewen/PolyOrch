# Helper for t-init-workspace: init on an existing manifest WITHOUT FORCE or
# IF_NOT_EXISTS must FATAL_ERROR (reaching the last line is the failure the
# parent test detects by exit code).
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
polyorch_pixi_init(WORKDIR "${WS}")
message(FATAL_ERROR "expected rejection of existing manifest")
