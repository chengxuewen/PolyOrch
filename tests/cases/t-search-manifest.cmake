include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")

# _polyorch_pixi_search_manifest: nearest pixi.toml at or above START wins;
# an empty START yields an empty result (the walk guard). Negative cases that
# would depend on manifests above the scratch tree are not portable, so the
# empty-START path is what gets asserted here.
_polyorch_pixi_scratch(_root)
set(_leaf "${_root}/a/b/c")
file(MAKE_DIRECTORY "${_leaf}" "${_root}/empty")
file(WRITE "${_root}/pixi.toml" "# outer\n")
file(WRITE "${_root}/a/pixi.toml" "# inner\n")

_polyorch_pixi_search_manifest(_found "${_leaf}")
ck_str("${_found}" "${_root}/a/pixi.toml")

_polyorch_pixi_search_manifest(_none "")
ck_str("${_none}" "")

message(STATUS "search-manifest: OK")
