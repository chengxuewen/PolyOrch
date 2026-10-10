# requires: node
# t-node-sources -- the node-face IDE source mount (rust-face parity, the
# SOURCES half of the D32 IDE-tree idiom; the python face keeps its own
# copy -- sibling agent owns it). Assertion strategy copied from TWO
# in-repo precedents: (1) tests/cases/t-rust-ide-sources.cmake + its
# fixture -- the child resolves get_property(SOURCES) at its own configure
# and reports through a sources.txt channel; (2) tests/cases/t-node-debug.cmake
# -- direct two-polarity -S/-B executes, contract SKIP at the gate.
# The case COPIES the fixture to scratch and stages the vendor bait there
# (node_modules/dist/build/dot-dir/dotfile): a committed node_modules is
# swallowed by .gitignore:79, so the exclusion proof must be synthesized.
cmake_policy(SET CMP0219 NEW)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")

polyorch_requires(node _req)
if(NOT _req)
    message(STATUS "t-node-sources : SKIP (no node+pm on PATH/pixi-glob)")
    return()
endif()

_polyorch_pixi_scratch(_s)
get_filename_component(_fx
    "${CMAKE_CURRENT_LIST_DIR}/../fixtures/node-ide-sources" ABSOLUTE)
set(_fx2 "${_s}/mount-fx")
file(COPY "${_fx}/" DESTINATION "${_fx2}")
# exclusion bait -- the mount must never list any of these
file(WRITE "${_fx2}/node_modules/fake-pkg/index.js" "// vendor: must never mount\n")
file(WRITE "${_fx2}/node_modules/fake-pkg/deep/nested.ts" "// vendor deep: must never mount\n")
file(WRITE "${_fx2}/packages/ws-one/node_modules/other/index.jsx" "// member vendor: must never mount\n")
file(WRITE "${_fx2}/dist/bundle.mjs" "// built: must never mount\n")
file(WRITE "${_fx2}/build/out.cjs" "// build dir: must never mount\n")
file(WRITE "${_fx2}/.hidden/secret.tsx" "// dot-dir: must never mount\n")
file(WRITE "${_fx2}/src/.eslintrc.js" "// dotfile: must never mount\n")

get_filename_component(_cmkdir "${CMAKE_CURRENT_LIST_DIR}/../../cmake" ABSOLUTE)
set(_mdir "-DPOLYORCH_HARNESS_CMAKE_DIR=${_cmkdir}")

# ---- default polarity ------------------------------------------------------
execute_process(COMMAND "${CMAKE_COMMAND}" -S "${_fx2}" -B "${_s}/mb" ${_mdir}
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "t-node-sources: default configure failed (rc=${_rc}):\n${_out}${_err}")
endif()
file(READ "${_s}/mb/sources.txt" _t)

# pull the per-target rows (whole line per REGEX MATCH -- the rows embed ";"
# as the file separator, so a REPLACE-to-list would split them again)
string(REGEX MATCH "demo;[^\n]*" _demo "${_t}")
string(REGEX MATCH "nos;[^\n]*" _nos "${_t}")
string(REGEX MATCH "test;[^\n]*" _test "${_t}")
string(REGEX MATCH "run;[^\n]*" _run "${_t}")
string(REGEX MATCH "ws;[^\n]*" _ws "${_t}")
string(REGEX MATCH "hfo=[^\n]*" _hfo "${_t}")
ck(_demo MATCHES "n=")
ck(_hfo MATCHES "hfo=")

# inclusion: the src glob (three extensions), the manifest, the lockfile
ck(_demo MATCHES "src/index\\.js")
ck(_demo MATCHES "src/util\\.mjs")
ck(_demo MATCHES "src/helper\\.ts")
ck(_demo MATCHES "package\\.json")
ck(_demo MATCHES "package-lock\\.json")
string(REGEX MATCH "n=([0-9]+)" _ "${_demo}")
ck(CMAKE_MATCH_1 GREATER_EQUAL 5)

# exclusion: vendor trees, output conventions, dot-dirs, dotfiles
ck(NOT _demo MATCHES "node_modules")
ck(NOT _demo MATCHES "dist/bundle")
ck(NOT _demo MATCHES "build/out")
ck(NOT _demo MATCHES "[.]hidden")
ck(NOT _demo MATCHES "[.]eslintrc")

# NO_SOURCES opts out at build() (the rust knob's home)
ck(_nos MATCHES "n=0")

# verb-node parity: test/run carry the same display mount (SOFT reuse)
ck(_test MATCHES "src/index\\.js")
ck(_test MATCHES "package\\.json")
ck(_run MATCHES "src/index\\.js")
ck(_run MATCHES "package-lock\\.json")

# import per-member mediator: the member dir mounts, member vendor stays out
ck(_ws MATCHES "packages/ws-one/src/index\\.js")
ck(_ws MATCHES "packages/ws-one/package\\.json")
ck(NOT _ws MATCHES "node_modules")
ck(NOT _ws MATCHES "dist")

# HEADER_FILE_ONLY honored by default (get_source_file_property returns
# the ON/OFF spelling, measured -- escape-hatch polarity asserted below)
ck(_hfo MATCHES "^hfo=ON")

# ---- PLAIN polarity --------------------------------------------------------
execute_process(COMMAND "${CMAKE_COMMAND}" -S "${_fx2}" -B "${_s}/mp" ${_mdir}
    "-DPolyOrch_NODE_SOURCES_PLAIN=ON"
    RESULT_VARIABLE _rc2 OUTPUT_VARIABLE _out2 ERROR_VARIABLE _err2)
if(NOT _rc2 EQUAL 0)
    message(FATAL_ERROR "t-node-sources: PLAIN configure failed (rc=${_rc2}):\n${_out2}${_err2}")
endif()
file(READ "${_s}/mp/sources.txt" _t2)
ck(_t2 MATCHES "hfo=OFF")   # escape hatch served plain (ON/OFF spelling)
string(REGEX MATCH "^demo;[^\r\n]*" _d2 "${_t2}")
ck(_d2 MATCHES "src/index\\.js")        # same set, plain serving
ck(NOT _d2 MATCHES "node_modules")

# ---- mount must not perturb the chain (t-rust-ide-sources leg) -------------
execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_s}/mb" --target demo-build
    RESULT_VARIABLE _rc3 OUTPUT_QUIET ERROR_QUIET)
ck(_rc3 EQUAL 0)

message(STATUS "t-node-sources: OK (mount + exclusions + NO_SOURCES + verb parity + PLAIN polarity + mediator build)")
