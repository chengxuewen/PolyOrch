# Helper for t-find-real: the located binary cannot satisfy this pin, so
# polyorch_pixi_find(VERSION) must FATAL_ERROR (reaching the last line is the
# failure the parent test checks for by exit code).
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
polyorch_pixi_find(QUIET VERSION 99.0.0)
message(FATAL_ERROR "expected version rejection")
