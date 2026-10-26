# t-bootstrap-park -- D48 T3: the never-rewrite contract on a markerless
# pre-existing settings.json. The generated document must park beside the
# original as settings.json.polyorch-new; the original stays byte-identical
# (sha256); the parked document carries the region markers and must NOT
# absorb the user's keys (it is a fresh generated document, not a merge).
cmake_policy(SET CMP0219 NEW)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchBootstrapHelpers.cmake")

_polyorch_pixi_scratch(_s)
set(_cand "${_s}/pixi/bin/cmake")
file(MAKE_DIRECTORY "${_s}/pixi/bin")
file(WRITE "${_cand}" "#!/bin/sh\n")

set(_ws "${_s}/wsroot")
set(_f "${_ws}/.vscode/settings.json")
file(MAKE_DIRECTORY "${_ws}/.vscode")
file(WRITE "${_f}" "{\n    \"editor.rulers\": [80]\n}\n")
file(SHA256 "${_f}" _ha)
set(PolyOrch_VSCODE_DIR "${_ws}/.vscode")
polyorch_bootstrap_hint(CANDIDATE_CMAKE "${_cand}")

ck_file("${_f}.polyorch-new")
file(SHA256 "${_f}" _hb)
ck_str("${_ha}" "${_hb}")
file(READ "${_f}.polyorch-new" _p)
ck(_p MATCHES "__POLYORCH_GENERATED_BEGIN__")
ck(NOT _p MATCHES "editor\\.rulers")

# re-running the hint re-parks (a markerless file is never adopted -- the
# user's file stays byte-identical FOREVER; adoption happens only by hand)
polyorch_bootstrap_hint(CANDIDATE_CMAKE "${_cand}")
file(SHA256 "${_f}" _hc)
ck_str("${_ha}" "${_hc}")
file(READ "${_f}" _now)
ck(NOT _now MATCHES "__POLYORCH_GENERATED_BEGIN__")

message(STATUS "t-bootstrap-park: OK (markerless file parked as .polyorch-new, original byte-identical)")
