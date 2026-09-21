include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")

# _polyorch_pixi_scratch: created, writable, unique per call. Script mode
# (cmake -P) provides no configure-time binary dir, which is the hole it fills.
_polyorch_pixi_scratch(_d1)
_polyorch_pixi_scratch(_d2)
ck(IS_DIRECTORY "${_d1}")

string(COMPARE NOTEQUAL "${_d1}" "${_d2}" _diff)
ck(${_diff})

file(WRITE "${_d1}/probe" "x")
ck(EXISTS "${_d1}/probe")

message(STATUS "scratch: OK")
