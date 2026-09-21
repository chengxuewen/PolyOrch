include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")

# _polyorch_pixi_env_arg: an empty environment must not inject a stray -e.
set(_l install)
_polyorch_pixi_env_arg(_l "")
list(LENGTH _l _n)
ck(${_n} EQUAL 1)

_polyorch_pixi_env_arg(_l "dev")
list(LENGTH _l _n)
ck(${_n} EQUAL 3)
list(GET _l 1 _t)
ck_str("${_t}" "-e")
list(GET _l 2 _t)
ck_str("${_t}" "dev")

message(STATUS "env-arg: OK")
