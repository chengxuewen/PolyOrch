# requires: node
# t-node-ts-debug -- the live TS chain (D37): real tsc build -> dist + map ->
# launch/tasks rows carrying sourceMaps + preLaunchTask. Direct -S/-B configures
# (no fixture driver): MC-safe by shape, the t-node-debug twin. tsc is probed
# with the example's own three tiers (PIT-58: gate tiers == product tiers);
# no tsc -> contract skip at this gate. Assertions are substring/FIND -- the
# generated file is JSONC, string(JSON) would choke (B6a). The carrier opts in
# in-file (a normal variable, measured to shadow -D=OFF), so the OFF polarity
# runs on a scratch copy with the opt-in line removed -- same spec shape, the
# gate left at the library default OFF.
cmake_policy(SET CMP0219 NEW)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

polyorch_requires(node _req)
if(NOT _req)
    message(STATUS "t-node-ts-debug : SKIP (no node+pm on PATH/pixi-glob)")
    return()
endif()

# tsc three tiers -- mirror examples/node-ts-basic's own probe exactly (PIT-58)
find_program(_tsc tsc)
if(NOT _tsc)
    find_program(_tsc tsc PATHS "$ENV{HOME}/.pixi/bin")
endif()
if(NOT _tsc)
    file(GLOB _tsg "$ENV{HOME}/.pixi/envs/*/bin/tsc")
    list(LENGTH _tsg _tsn)
    if(_tsn GREATER 0)
        list(GET _tsg 0 _tsc)
    endif()
endif()
if(NOT _tsc)
    message(STATUS "t-node-ts-debug : SKIP (no tsc -- pixi global install typescript)")
    return()
endif()

# node three tiers -- same shape, for the demo run leg
find_program(_node node)
if(NOT _node)
    find_program(_node node PATHS "$ENV{HOME}/.pixi/bin")
endif()
if(NOT _node)
    file(GLOB _ng "$ENV{HOME}/.pixi/envs/*/bin/node")
    list(LENGTH _ng _nn)
    if(_nn GREATER 0)
        list(GET _ng 0 _node)
    endif()
endif()

cmake_path(GET _tsc PARENT_PATH _tsdir)
cmake_path(GET _node PARENT_PATH _ndir)
# The build rule must NOT depend on the invoker's ambient PATH (D37 fix,
# user-found in the real VSCode F5 chain: task shell PATH lacks the tool
# dir -> `tsc: not found`). We run `cmake --build` with a stripped PATH
# below to reproduce that shell exactly. The configure/demo legs use the
# discovered absolute tools, so they keep the full env.
set(_env "PATH=$ENV{PATH}:${_tsdir}:${_ndir}:$ENV{HOME}/.pixi/bin")
set(_task_env "PATH=/usr/bin:/bin")

_polyorch_pixi_scratch(_s)
get_filename_component(_ex
    "${CMAKE_CURRENT_LIST_DIR}/../../examples/node-ts-basic" ABSOLUTE)
get_filename_component(_rcmake "${CMAKE_CURRENT_LIST_DIR}/../../cmake" ABSOLUTE)

# dist lands in the SOURCE tree (tsc -p . is package-relative): never let a
# stale one fake the map assertion
file(REMOVE_RECURSE "${_ex}/dist")

# ---- ON polarity: carrier's in-file opt-in, output parked -----------------
execute_process(
    COMMAND "${CMAKE_COMMAND}" -S "${_ex}" -B "${_s}/on"
        "-DPolyOrch_VSCODE_DIR=${_s}/vson"
    ENVIRONMENT "${_env}"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
ck(_rc EQUAL 0)

# launch rows: built-entry program + sourceMaps + preLaunchTask (8-field spec)
file(READ "${_s}/vson/launch.json" _c)
string(FIND "${_c}" "\"program\": \"${_ex}/dist/index.js\"" _h)
ck(NOT _h LESS 0)                                        # package-root join
ck(_c MATCHES "\"sourceMaps\": true")
# outFiles must name GENERATED js (js-debug contract: configuration.ts
# "these glob patterns specify the generated JavaScript files"), NOT the
# .map -- a .map glob disables breakpoint prediction, and this carrier runs
# its total(5) at import so prediction is the only thing that binds in time
# (PIT-63, user-found grey breakpoint).
string(FIND "${_c}" "\"outFiles\": [\"${_ex}/**/*.js\", \"!${_ex}/node_modules/**\", ]" _h)
ck(NOT _h LESS 0)
string(FIND "${_c}" "\"preLaunchTask\": \"PolyOrch: node-ts-basic\"" _h)
ck(NOT _h LESS 0)                                        # bare label, standalone
file(READ "${_s}/vson/tasks.json" _tj)
string(FIND "${_tj}" "PolyOrch rust build tasks" _h)
ck(NOT _h LESS 0)                                        # marker byte-frozen
string(FIND "${_tj}" "\"label\": \"PolyOrch: node-ts-basic\"" _h)
ck(NOT _h LESS 0)
string(FIND "${_tj}" "\"--target\", \"node-ts-basic-build\"" _h)
ck(NOT _h LESS 0)                                        # mediator pin (D37)

# ---- build: real tsc through the mediator; artifacts + map source edge ----
execute_process(
    COMMAND "${CMAKE_COMMAND}" --build "${_s}/on" --target node-ts-basic-build
    ENVIRONMENT "${_task_env}"
    RESULT_VARIABLE _rc2 OUTPUT_VARIABLE _bout ERROR_VARIABLE _berr)
ck(_rc2 EQUAL 0)
ck(EXISTS "${_ex}/dist/index.js")                        # rows' program is real
ck(EXISTS "${_ex}/dist/index.js.map")
file(READ "${_ex}/dist/index.js.map" _map)
ck(_map MATCHES "src/index.ts")                          # the source edge
ck(EXISTS "${_ex}/vendor/tslib/dist/tslib.js")            # prebuilt vendor dist (Task 2)
ck(EXISTS "${_ex}/vendor/tslib/dist/tslib.js.map")
ck(EXISTS "${_ex}/vendor/tslib/dist/tslib.d.ts")
execute_process(
    COMMAND "${_node}" "${_ex}/dist/index.js"
    ENVIRONMENT "${_env}"
    RESULT_VARIABLE _rc3 OUTPUT_VARIABLE _dout ERROR_VARIABLE _derr)
ck(_rc3 EQUAL 0)
ck(_dout MATCHES "total=15")                             # the demo run leg
ck(_dout MATCHES "node-ts-basic/vendor-tslib: OK")         # vendor runtime leg (file: symlink)

# ---- OFF polarity: opt-in removed on a scratch copy, gate at default ------
file(COPY "${_ex}/CMakeLists.txt" "${_ex}/package.json"
     "${_ex}/tsconfig.json" "${_ex}/src"
     DESTINATION "${_s}/off-carrier")
file(READ "${_s}/off-carrier/CMakeLists.txt" _oc)
string(REPLACE "set(PolyOrch_NODE_VSCODE_DEBUG ON)"
    "# OFF-polarity carrier: in-file opt-in removed" _oc "${_oc}")
string(REPLACE "\${CMAKE_CURRENT_SOURCE_DIR}/../../cmake"
    "${_rcmake}" _oc "${_oc}")
file(WRITE "${_s}/off-carrier/CMakeLists.txt" "${_oc}")
execute_process(
    COMMAND "${CMAKE_COMMAND}" -S "${_s}/off-carrier" -B "${_s}/off"
        "-DPolyOrch_VSCODE_DIR=${_s}/vsoff"
    ENVIRONMENT "${_env}"
    RESULT_VARIABLE _rc4 OUTPUT_QUIET ERROR_QUIET)
ck(_rc4 EQUAL 0)
# the hook never registers the DEFER -> the generator never runs -> the files
# are absent ENTIRELY (zero footprint, not an empty region)
ck(NOT EXISTS "${_s}/vsoff/launch.json")
ck(NOT EXISTS "${_s}/vsoff/tasks.json")

# leave the repo pristine: dist is the one legal cleanup point outside scratch
# (the example's .gitignore is the git-side backstop, this is the re-run guard)
file(REMOVE_RECURSE "${_ex}/dist")

message(STATUS "t-node-ts-debug: OK (live tsc rows + sourceMaps/preLaunchTask + tasks mediator pin + dist/map/demo legs + OFF zero footprint)")
