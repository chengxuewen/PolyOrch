# Env-probe fixture for the P4 dependency-provider tests: the configure log
# is the evidence -- the child reports the exact env the provider handed it.
cmake_minimum_required(VERSION 3.24)
project(tpenv LANGUAGES CXX)
message(STATUS "PROBE CMAKE_PREFIX_PATH=[$ENV{CMAKE_PREFIX_PATH}]")
message(STATUS "PROBE CPATH=[$ENV{CPATH}]")
message(STATUS "PROBE CPLUS_INCLUDE_PATH=[$ENV{CPLUS_INCLUDE_PATH}]")
message(STATUS "PROBE CONDA_PREFIX=[$ENV{CONDA_PREFIX}]")
message(STATUS "PROBE LIBRARY_PATH=[$ENV{LIBRARY_PATH}]")
message(STATUS "PROBE COMPILER=${CMAKE_CXX_COMPILER}")
add_library(tpenv STATIC tpenv.cpp)
install(TARGETS tpenv ARCHIVE DESTINATION lib)
