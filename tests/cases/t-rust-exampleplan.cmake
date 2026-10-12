# Adjudication 7 (2026-10-12): the EXAMPLE kind cluster, offline legs.
# Assertion layers mirror the bin machinery:
#  1. pure tables: _polyorch_rust_artifact_names (file + the /examples dir
#     segment, three families) and _polyorch_rust_copy_plan (src row carries
#     <profile>/examples/, host shape [SRC_DIR carries the profile, the real
#     caller contract] and cross-nested [TARGET+PROFILE] variant);
#  2. the cargo argv: KIND example -> --example <crate>; the CRATE-needed
#     guard fires through a child -P (covers bin and example together);
#  3. the metadata parser: a crafted cargo-metadata document (lib + bin +
#     example) yields records, the example as <name>-example|<name>|example,
#     and NO row for a plain lib target;
#  4. the mutual-exclusion guard (SHARED + EXAMPLE) fires at keyword-parse
#     time with MANIFEST supplied (the must-check precedes it), before any
#     setup gate -- child -P, nothing executes.
# The end-to-end proof is the host: VisiaEngine's 28 cargo examples build and
# run through the rust face. This case pins the machinery offline.
cmake_policy(SET CMP0219 NEW)
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")

_polyorch_pixi_scratch(_s)
set(ROOT "${CMAKE_CURRENT_LIST_DIR}/../..")   # uppercase: configure_file @ROOT@ token

# ------------------------------------------------------- pure naming tables --
_polyorch_rust_artifact_names(TRIPLE x86_64-unknown-linux-gnu KIND example
    CRATE E101_clear PROFILE debug BASE_DIR BD FILE_OUT _f DIR_OUT _d)
ck("${_f}" STREQUAL "E101_clear")
ck("${_d}" STREQUAL "BD/debug/examples")
_polyorch_rust_artifact_names(TRIPLE x86_64-unknown-linux-gnu KIND bin
    CRATE mytool PROFILE debug BASE_DIR BD FILE_OUT _f DIR_OUT _d)
ck("${_f}" STREQUAL "mytool")
ck("${_d}" STREQUAL "BD/debug")
_polyorch_rust_artifact_names(TRIPLE x86_64-pc-windows-msvc KIND example
    CRATE hello PROFILE release BASE_DIR BD FILE_OUT _f)
ck("${_f}" STREQUAL "hello.exe")
_polyorch_rust_artifact_names(TRIPLE aarch64-apple-darwin KIND example
    CRATE shaderc PROFILE debug BASE_DIR BD FILE_OUT _f)
ck("${_f}" STREQUAL "shaderc")

# ------------------------------------------------------------ copy plan rows --
_polyorch_rust_copy_plan(TRIPLE x86_64-unknown-linux-gnu KIND example
    CRATE E201_load_gltf SRC_DIR SD DEST_DIR DD OUT _row)
ck("${_row}" STREQUAL "SD/examples/E201_load_gltf|DD/E201_load_gltf")
_polyorch_rust_copy_plan(TRIPLE x86_64-pc-windows-msvc KIND example
    CRATE win1 SRC_DIR SD TARGET x86_64-pc-windows-msvc PROFILE release
    DEST_DIR DD OUT _row)
ck("${_row}" STREQUAL "SD/x86_64-pc-windows-msvc/release/examples/win1.exe|DD/win1.exe")

# ----------------------------------------------------------------- argv -----
_polyorch_rust_cargo_args(PACKAGE ex KIND example CRATE E301_switch_camera
    ARGO_OUT _a)
list(JOIN _a " " _argv_s)                     # NEVER reuse _s: it names the scratch dir
string(FIND "${_argv_s}" "--example E301_switch_camera" _p)
if(_p LESS 0)
    message(FATAL_ERROR "argv [${_argv_s}] lacks [--example E301_switch_camera]")
endif()

# child -P helpers: @ROOT@ embedded by configure_file (write-time expansion,
# immune to the file(WRITE) parent-evaluation trap).
configure_file("${CMAKE_CURRENT_LIST_DIR}/_example_child_nocrate.in"
    "${_s}/nocrate.cmake" @ONLY)
configure_file("${CMAKE_CURRENT_LIST_DIR}/_example_child_excl.in"
    "${_s}/excl.cmake" @ONLY)

macro(expect_fatal child phrase)
    execute_process(
        COMMAND "${CMAKE_COMMAND}" -P "${child}"
        RESULT_VARIABLE _rc OUTPUT_VARIABLE _o ERROR_VARIABLE _o)
    if(_rc EQUAL 0)
        message(FATAL_ERROR "expected FATAL from ${child}: ${_o}")
    endif()
    string(REGEX REPLACE "[ \n]+" " " _o "${_o}")
    string(FIND "${_o}" "${phrase}" _p)
    if(_p LESS 0)
        message(FATAL_ERROR "guard phrase [${phrase}] not found: ${_o}")
    endif()
endmacro()
expect_fatal("${_s}/nocrate.cmake" "KIND bin/example needs CRATE")
expect_fatal("${_s}/excl.cmake"
    "BINARY, STATIC, SHARED and EXAMPLE are mutually exclusive")

# ----------------------------------------------------- metadata target rows --
# The document is plain JSON text -- composed literally, no JSON API needed
# (the driver cmake may predate string(JSON SET_VALUE, 3.24): measured).
set(_doc
[==[{"packages":[{"name":"examples","targets":[{"name":"e1","kind":["bin"]},{"name":"E101_clear","kind":["example"]},{"name":"visiaengine_examples","kind":["lib"]}]}]}]==])

_polyorch_rust_metadata_targets("${_doc}" _specs)
list(FIND _specs "examples|e1-exe|e1|bin" _bi)
list(FIND _specs "examples|E101_clear-example|E101_clear|example" _ei)
list(FIND _specs "examples|visiaengine_examples|visiaengine_examples|static" _li)
if(_bi LESS 0 OR _ei LESS 0)
    message(FATAL_ERROR "bin/example rows missing: ${_specs}")
endif()
if(_li GREATER -1)
    message(FATAL_ERROR "plain lib should not yield a spec row: ${_specs}")
endif()
message(STATUS "t-rust-exampleplan: example cluster pinned")
