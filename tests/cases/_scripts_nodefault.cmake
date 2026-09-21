# Helper for t-scripts-install: no WORKDIR and no manifest context must
# FATAL_ERROR via _polyorch_pixi_require_context (reaching the last line is
# the failure the parent detects by exit code).
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
polyorch_pixi_scripts_install()
message(FATAL_ERROR "expected rejection without WORKDIR or manifest context")
