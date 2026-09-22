# tests/fixtures/install-e2e/consumer -- the unrelated second C project of
# t-rust-install-e2e: includes the replay stub shipped by polyorch_rust_install
# (EXPORT demo) via -DPOLYORCH_IE_STUB=<demo-rust.cmake> and links + runs
# through it. The case points the SAME shape at a stripped stub copy for the
# negative leg: the link must then fail on `pow`.
cmake_minimum_required(VERSION 3.25)
project(polyorch-rust-install-consumer LANGUAGES C)

if(NOT POLYORCH_IE_STUB)
    message(FATAL_ERROR "consumer: -DPOLYORCH_IE_STUB=<replay stub> is required")
endif()
include("${POLYORCH_IE_STUB}")
if(NOT TARGET dash_ed)
    message(FATAL_ERROR "consumer: stub did not define dash_ed")
endif()
if(NOT TARGET say-hi-exe)
    message(FATAL_ERROR "consumer: stub did not define say-hi-exe")
endif()
get_target_property(_loc dash_ed IMPORTED_LOCATION)
if(NOT EXISTS "${_loc}")
    message(FATAL_ERROR "consumer: stub location does not exist: ${_loc}")
endif()
add_executable(capp "${CMAKE_CURRENT_LIST_DIR}/main.c")
target_link_libraries(capp PRIVATE dash_ed)
file(GENERATE OUTPUT "${CMAKE_BINARY_DIR}/capp.txt" CONTENT "$<TARGET_FILE:capp>")
file(GENERATE OUTPUT "${CMAKE_BINARY_DIR}/exe.txt" CONTENT "$<TARGET_FILE:say-hi-exe>")
get_target_property(_ifl dash_ed INTERFACE_LINK_LIBRARIES)
file(WRITE "${CMAKE_BINARY_DIR}/ifl.txt" "${_ifl}")

set(POLYORCH_FIXTURE_ARTIFACTS
    "capp=${CMAKE_BINARY_DIR}/capp${CMAKE_EXECUTABLE_SUFFIX}")
string(JOIN "\n" _af ${POLYORCH_FIXTURE_ARTIFACTS})
file(WRITE "${CMAKE_BINARY_DIR}/polyorch-fixture-artifacts.txt" "${_af}\n")
