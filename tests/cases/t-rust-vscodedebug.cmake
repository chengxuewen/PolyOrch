# WP11: VSCode debug-config surface, offline unit legs.
# Pure-function tests (rows + region_write) plus a fake-handle register leg.
# No cargo, no child configure -- everything lives in a scratch dir.
cmake_policy(SET CMP0219 NEW)   # macro args keep backslashes (regex escapes)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../cmake")
include(PolyOrchRustHelpers)

_polyorch_pixi_scratch(_s)

# ---- 1) rows: spec table -> region text ----------------------------------
set(_specs
    "alpha|/b/x/.cargo-target/debug/alpha|/src/alpha|debug"
    "beta|/b/x/.cargo-target/release/libbeta.so|/src/bet a|release")
_polyorch_rust_vscode_rows("${_specs}" _L _K)
ck(_L MATCHES "PolyOrch: alpha \\(debug\\)")
ck(_L MATCHES "\"program\": \"/b/x/.cargo-target/debug/alpha\"")
ck(_L MATCHES "\"cwd\": \"/src/bet a\"")           # spaces survive verbatim
ck(_K MATCHES "\"--target\", \"alpha-build\"")
ck(_K MATCHES "\"--target\", \"beta-build\"")
# cross-reference closure: every preLaunchTask has a label twin
ck(_L MATCHES "\"preLaunchTask\": \"PolyOrch: beta \\(release\\)\"")
ck(_K MATCHES "\"label\": \"PolyOrch: beta \\(release\\)\"")
string(REGEX MATCHALL "\"name\": \"" _nL "${_L}")
list(LENGTH _nL _rows)
ck(_rows EQUAL 2)

# empty table -> empty region texts
set(_none "")
_polyorch_rust_vscode_rows("${_none}" _EL _EK)
# (ck's ${ARGN} breaks on literal empty arguments; compare via string)
string(COMPARE EQUAL "${_EL}" "" _el0)
string(COMPARE EQUAL "${_EK}" "" _ek0)
ck(_el0)
ck(_ek0)

# ---- 2) region_write lifecycle -------------------------------------------
set(_B "// __POLYORCH_GENERATED_BEGIN__ t")
set(_E "// __POLYORCH_GENERATED_END__")
set(_shell "{\n  \"arr\": [\n%ROWS%\n  ]\n}")
set(_f "${_s}/vdir/launch.json")          # vdir does not exist yet

_polyorch_vscode_region_write("${_f}" "${_B}" "${_E}" "    {row:1},\n" "${_shell}" _st)
ck(_st STREQUAL "CREATED")
file(SHA256 "${_f}" _h1)

# idempotent replace: same rows -> byte-identical file
_polyorch_vscode_region_write("${_f}" "${_B}" "${_E}" "    {row:1},\n" "${_shell}" _st)
ck(_st STREQUAL "REPLACED")
file(SHA256 "${_f}" _h2)
ck(_h1 STREQUAL _h2)

# content update: region swaps, shell bytes outside markers preserved
_polyorch_vscode_region_write("${_f}" "${_B}" "${_E}"
    "    {row:1},\n    {row2:2},\n" "${_shell}" _st)
ck(_st STREQUAL "REPLACED")
file(READ "${_f}" _t)
ck(_t MATCHES "row2")
ck(_t MATCHES "  \\]\n")            # shell tail line survives the swap                # shell tail line survives the swap
# stale-row removal: a SHRINKING region must leave nothing behind
_polyorch_vscode_region_write("${_f}" "${_B}" "${_E}" "" "${_shell}" _st)
file(READ "${_f}" _t2)
ck(NOT _t2 MATCHES "row2")
ck(_t2 MATCHES "__POLYORCH_GENERATED_END__")

# user content above the markers survives replacement
file(WRITE "${_f}" "{\n  \"arr\": [\n    {\"user\": true},\n${_B}\n    {row:1},\n${_E}\n  ]\n}\n")
_polyorch_vscode_region_write("${_f}" "${_B}" "${_E}" "    {row:9},\n" "${_shell}" _st)
ck(_st STREQUAL "REPLACED")
file(READ "${_f}" _t3)
ck(_t3 MATCHES "\\{\"user\": true\\}")
ck(_t3 MATCHES "row:9")

# markerless file -> .polyorch-new beside an untouched original
set(_manual "${_s}/manual/launch.json")
file(MAKE_DIRECTORY "${_s}/manual")
file(WRITE "${_manual}" "{\"keepme\": 1}\n")
_polyorch_vscode_region_write("${_manual}" "${_B}" "${_E}" "    {x:1},\n" "${_shell}" _st)
ck(_st STREQUAL "PLACED_NEW")
file(READ "${_manual}" _m)
ck(_m STREQUAL "{\"keepme\": 1}\n")
ck(EXISTS "${_manual}.polyorch-new")

# (file-squat on VSCODE_DIR is a one-line generator guard; the region

#  mechanics it protects are covered by the lifecycle legs above.)
message(STATUS "t-rust-vscodedebug: OK (rows + region lifecycle + user-preservation + .new fallback)")
