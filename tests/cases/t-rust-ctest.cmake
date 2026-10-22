# t-rust-ctest -- polyorch_rust_test CTEST kw (D45/SR3). Pins:
#   (1) single source: the ctest entry and the button carry the SAME command
#       core (test --package P --manifest-path M --target-dir TD + the six
#       wrapper strips) -- the existence reason for the keyword;
#   (2) defaults: NAME <p>-test / LABELS rust / WORKING_DIRECTORY manifest
#       parent; SKIP_RETURN_CODE absent unless passed (77 is consumer posture);
#   (3) explicit overrides land (name/labels/wd/skip);
#   (4) negative: no CTEST kw => no ctest entry at all;
#   (5) unknown args FATAL (script-mode child re-exec; guards precede spawns).
# Assert surface: generated CTestTestfile.cmake + the button's build.make
# (Unix Makefiles pinned; COMMAND property unreadable on non-IMPORTED
# targets -- t-rust-clean sibling note). Test names appear plain-quoted OR
# bracket-quoted depending on their characters -- patterns carry the
# closing-bracket-or-quote character class.
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")

if(POLYORCH_CHILD)
    polyorch_rust_test(PACKAGE alpha NOPE)
    message(FATAL_ERROR "expected unknown-args FATAL")
endif()
ck_child_fail("polyorch_rust_test: unknown args: NOPE")

_polyorch_pixi_scratch(_s)
set(_proj "${_s}/proj")
set(_bld "${_s}/build")
set(_td "${_s}/td")
file(MAKE_DIRECTORY "${_proj}")
file(WRITE "${_proj}/CMakeLists.txt" [==[
cmake_minimum_required(VERSION 3.25)
project(rctest NONE)
enable_testing()
include("${POLYORCH_CMAKE_DIR}/PolyOrchRustHelpers.cmake")
set(POLYORCH_RUST_FOUND TRUE CACHE INTERNAL "")
set(POLYORCH_RUST_CARGO "/bin/true" CACHE INTERNAL "")
set(POLYORCH_RUST_RUSTC "/bin/true" CACHE INTERNAL "")
set(POLYORCH_RUST_HOST_TARGET "x86_64-unknown-linux-gnu" CACHE INTERNAL "")
set(POLYORCH_RUST_ROUTE "system" CACHE INTERNAL "")
set(POLYORCH_RUST_BIN_DIR "" CACHE INTERNAL "")

# negative leg: button only, no ctest entry
polyorch_rust_test(PACKAGE alpha MANIFEST "${POLYORCH_TEST_MANIFEST}"
    BASE_DIR "${POLYORCH_TEST_TD}" FOLDER x)
# defaults leg
polyorch_rust_test(PACKAGE beta MANIFEST "${POLYORCH_TEST_MANIFEST}"
    BASE_DIR "${POLYORCH_TEST_TD}" FOLDER x CTEST)
# explicit leg
polyorch_rust_test(PACKAGE gamma MANIFEST "${POLYORCH_TEST_MANIFEST}"
    BASE_DIR "${POLYORCH_TEST_TD}" FOLDER x
    CTEST CTEST_NAME custom-g CTEST_LABELS "rust;lanes"
    CTEST_WORKING_DIRECTORY "${POLYORCH_TEST_WD}" CTEST_SKIP_RETURN_CODE 77)
]==])

execute_process(COMMAND ${CMAKE_COMMAND}
    -G "Unix Makefiles"
    -S "${_proj}" -B "${_bld}"
    "-DPOLYORCH_CMAKE_DIR=${CMAKE_CURRENT_LIST_DIR}/../../cmake"
    "-DPOLYORCH_TEST_TD=${_td}"
    "-DPOLYORCH_TEST_MANIFEST=${_proj}/Cargo.toml"
    "-DPOLYORCH_TEST_WD=${_s}/wdx"
    RESULT_VARIABLE _rc OUTPUT_VARIABLE _o ERROR_VARIABLE _e)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "configure child failed rc=${_rc}\n${_o}\n---stderr---\n${_e}")
endif()

file(READ "${_bld}/CTestTestfile.cmake" _ct)
file(READ "${_bld}/CMakeFiles/beta-rusttest.dir/build.make" _bm)

# normalize: strip quotes/backslashes, flatten newlines+space runs so a
# Makefiles-wrapped recipe line and a CTestTestfile add_test line compare
function(_norm out in)
    string(REPLACE "\"" "" _t "${${in}}")
    string(REPLACE "\\" "" _t "${_t}")
    string(REPLACE "\n" " " _t "${_t}")
    while(_t MATCHES "  ")
        string(REPLACE "  " " " _t "${_t}")
    endwhile()
    set(${out} "${_t}" PARENT_SCOPE)
endfunction()
_norm(_bn _bm)
_norm(_cn _ct)

# (4) negative leg: exactly two entries; none names alpha
string(REGEX MATCHALL "add_test\\([^\n]*" _ats "${_ct}")
list(LENGTH _ats _n)
if(NOT _n EQUAL 2)
    list(LENGTH _ats _got)
    message(FATAL_ERROR "expected 2 add_test entries, got ${_got}:\n${_ct}")
endif()
foreach(_l IN LISTS _ats)
    if(_l MATCHES "alpha")
        message(FATAL_ERROR "CTEST-less call leaked an alpha entry: ${_l}")
    endif()
endforeach()

# (1) single source: beta's ctest core == beta's button core
set(_core "test --package beta --manifest-path ${_proj}/Cargo.toml --target-dir ${_td}")
string(FIND "${_bn}" "${_core}" _pb)
string(FIND "${_cn}" "${_core}" _pc)
if(_pb LESS 0)
    message(FATAL_ERROR "button recipe lost the pinned argv (normalized):\n${_bn}")
endif()
if(_pc LESS 0)
    message(FATAL_ERROR "ctest entry argv differs from the button (SINGLE SOURCE broken):\n${_cn}")
endif()
foreach(needle "--unset=RUSTFLAGS" "--unset=CXXFLAGS")
    if(NOT _cn MATCHES "${needle}" OR NOT _bn MATCHES "${needle}")
        message(FATAL_ERROR "wrapper strip missing on a surface: ${needle}")
    endif()
endforeach()

# (2) defaults: wd = manifest parent + labels rust + no SKIP on beta
if(NOT _cn MATCHES "beta-test PROPERTIES LABELS rust WORKING_DIRECTORY ${_proj}")
    message(FATAL_ERROR "beta defaults wrong (want LABELS rust + wd=manifest parent):\n${_cn}")
endif()
if(_ct MATCHES "beta-test[^\n]*SKIP_RETURN_CODE")
    message(FATAL_ERROR "SKIP_RETURN_CODE leaked onto the unset leg (posture belongs to the caller)")
endif()

# (3) explicit leg
if(NOT _cn MATCHES "custom-g PROPERTIES LABELS rust;lanes SKIP_RETURN_CODE 77 WORKING_DIRECTORY ${_s}/wdx")
    message(FATAL_ERROR "explicit overrides not applied as a set:\n${_cn}")
endif()

message(STATUS "t-rust-ctest: OK")
