# expect-log wspath: all legs pass
# Unit case for the shared ${workspaceFolder} rewrite rule (_polyorch_vscode_ws_path in
# PolyOrchVSCodeDebugHelpers.cmake) as the native and rust faces call it. Logic only: no configure,
# no fixture build tree, nothing written -- so it never SKIPs on a capability, and it keeps
# failing if a later refactor drops the rule. The rule is worth pinning: debug rows carried
# absolute machine paths (with a username) into committed .vscode files and nothing noticed.
#
# Every test path is DERIVED from CMAKE_SOURCE_DIR rather than hard-coded: under `cmake -P`
# that variable is the process working directory, so a literal here would itself be a machine
# assumption -- exactly the thing the rule under test removes.
#
# Scope note: the python and node faces share this helper but are NOT wired to it yet -- their
# own cases (t-node-vscode and friends) assert the absolute form as the contract, so extending
# the rule there is a deliberate contract change for that surface, not a free consistency win.
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
# the helpers file declares an option at load time, so its own dependency comes first
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchOptionHelpers.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchVSCodeDebugHelpers.cmake")

set(_src "${CMAKE_SOURCE_DIR}")
set(_ws "\${workspaceFolder}")

# 1 inside the tree -> the literal with the prefix stripped
_polyorch_vscode_ws_path("${_src}/build/bin/app" _o)
ck_str("${_o}" "${_ws}/build/bin/app")

# 2 the workspace root itself -> bare literal, no trailing slash
_polyorch_vscode_ws_path("${_src}" _o)
ck_str("${_o}" "${_ws}")

# 3 outside the tree -> stays ABSOLUTE. No workspace variable can express an outside path;
#   emitting the literal anyway would resolve to a nonexistent file (the pointing-at-air case).
_polyorch_vscode_ws_path("${_src}/../elsewhere/app" _o)
ck_str("${_o}" "${_src}/../elsewhere/app")

# 4 empty input stays empty (a face may legitimately carry no cwd)
_polyorch_vscode_ws_path("" _o)
ck_str("${_o}" "")

message("wspath: all legs pass (inside -> literal / root -> bare literal / outside -> absolute / empty -> empty)")
