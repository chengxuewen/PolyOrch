# expect: fail
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")

# A double quote inside a channel name would produce invalid JSON; the helper
# must refuse instead of sanitizing it away.
_polyorch_pixi_json_array(_out "evil\"channel")
message(FATAL_ERROR "expected rejection, got: ${_out}")
