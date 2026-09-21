include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")

# _polyorch_pixi_json_array: quoted, comma-joined, no trailing comma.
_polyorch_pixi_json_array(_out "conda-forge" "https://mirror.example/repo")
set(_want "[\"conda-forge\",\"https://mirror.example/repo\"]")
ck_str("${_out}" "${_want}")

_polyorch_pixi_json_array(_one "conda-forge")
set(_want1 "[\"conda-forge\"]")
ck_str("${_one}" "${_want1}")

message(STATUS "json-array: OK")
