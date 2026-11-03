# Fixture payload for the thirdparty face (D50): the smallest honest
# upstream -- a static library that installs an export set + a static config
# file, so the import verb's find_package(CONFIG ... NO_DEFAULT_PATH) has a
# real <Pkg>Config.cmake to consume.
cmake_minimum_required(VERSION 3.21)
project(tpdemo VERSION 1.2.3 LANGUAGES CXX)

add_library(tpdemo STATIC tpdemo.cpp)
target_include_directories(tpdemo PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<INSTALL_INTERFACE:include>)

install(TARGETS tpdemo EXPORT tpdemo-targets ARCHIVE DESTINATION lib)
install(FILES tpdemo.h DESTINATION include)
install(EXPORT tpdemo-targets FILE tpdemoTargets.cmake
    NAMESPACE tpdemo:: DESTINATION lib/cmake/tpdemo)
install(FILES tpdemoConfig.cmake DESTINATION lib/cmake/tpdemo)
