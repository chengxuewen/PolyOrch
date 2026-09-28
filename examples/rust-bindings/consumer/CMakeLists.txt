# The installed-binding consumer: a completely unrelated C++ project that
# finds the installed spine-demo package and calls the C ABI surface.
cmake_minimum_required(VERSION 3.22)
project(spine-consumer LANGUAGES CXX)
find_package(spine-demo CONFIG REQUIRED)
add_executable(consumer main.cpp)
# the replay stub exports the REGISTERED handle names (fusion-prefixed in
# a fused host; bare standalone) -- the umbrella passes the spelling in
set(SPINE_LIB "spine-static" CACHE STRING "imported lib target from spine-demo")
target_link_libraries(consumer PRIVATE ${SPINE_LIB})
