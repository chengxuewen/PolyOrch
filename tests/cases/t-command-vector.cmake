include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")

# _polyorch_pixi_command: argv first, then context flags; BARE drops context;
# --config-file wins over --no-config.
set(PolyOrch_PIXI_EXECUTABLE "/bin/true" CACHE FILEPATH "" FORCE)
set(PolyOrch_PIXI_MANIFEST "/x/pixi.toml" CACHE FILEPATH "" FORCE)
unset(PolyOrch_PIXI_CONFIG_FILE CACHE)
unset(PolyOrch_PIXI_NO_CONFIG CACHE)

_polyorch_pixi_command(_c install)
set(_w1 "/bin/true;install;-m;/x/pixi.toml")
ck_str("${_c}" "${_w1}")

_polyorch_pixi_command(_bare BARE config set a b)
set(_w2 "/bin/true;config;set;a;b")
ck_str("${_bare}" "${_w2}")

set(PolyOrch_PIXI_CONFIG_FILE "/y/config.toml" CACHE FILEPATH "" FORCE)
set(PolyOrch_PIXI_NO_CONFIG ON CACHE BOOL "" FORCE)
_polyorch_pixi_command(_cfg install)
list(GET _cfg -1 _tail)
ck_str("${_tail}" "/y/config.toml")
list(GET _cfg -2 _tail2)
ck_str("${_tail2}" "--config-file")
string(FIND "${_cfg}" "--no-config" _pos)
ck(${_pos} EQUAL -1)

unset(PolyOrch_PIXI_CONFIG_FILE CACHE)
_polyorch_pixi_command(_nc install)
list(GET _nc -1 _tail)
ck_str("${_tail}" "--no-config")

message(STATUS "command-vector: OK")
