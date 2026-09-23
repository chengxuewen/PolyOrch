# The CONSUMER: a completely unrelated C project that knows nothing about
# cargo or PolyOrch -- only find_package. This is the integration story:
# build+install the producer once, then any project consumes the Rust
# library as if it were a native CMake package.
#
#   cmake -S consumer -B consumer-build \
#       -DCMAKE_PREFIX_PATH=<install prefix of the producer>
cmake_minimum_required(VERSION 3.22)
project(mathkit-consumer LANGUAGES C)

find_package(mathkit-demo CONFIG REQUIRED)

add_executable(consumer main.c)
target_link_libraries(consumer PRIVATE mathkit)
