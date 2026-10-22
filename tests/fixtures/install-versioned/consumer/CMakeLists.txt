# tests/fixtures/install-versioned/consumer -- second-stage find_package
# drive of t-rust-install-versioned-e2e: discovers the staged tree via
# <export>Config.cmake COMPONENTS dispatch, links the NAMESPACED+ALIASED
# imported target (vpack::lib), compiles against the replay stub's
# INTERFACE_INCLUDE_DIRECTORIES, and runs the binary (dev-symlink runtime
# chain). -DVPACK_BAD_COMP=<name> switches to the unknown-component
# negative leg (configure must fail loudly).
cmake_minimum_required(VERSION 3.25)
project(polyorch-install-versioned-consumer LANGUAGES C)

if(VPACK_BAD_COMP)
    find_package(vpack CONFIG REQUIRED COMPONENTS ${VPACK_BAD_COMP})
else()
    find_package(vpack CONFIG REQUIRED COMPONENTS runtime)
    if(NOT vpack_runtime_FOUND)
        message(FATAL_ERROR "consumer: vpack_runtime_FOUND not TRUE after dispatch")
    endif()
    if(NOT TARGET vpack::lib)
        message(FATAL_ERROR "consumer: stub did not register vpack::lib")
    endif()
    get_target_property(_loc vpack::lib IMPORTED_LOCATION)
    get_filename_component(_real "${_loc}" REALPATH)
    if(NOT _real MATCHES "libvkit\\.so\\.0\\.1\\.2$")
        message(FATAL_ERROR "consumer: IMPORTED_LOCATION is not the versioned real file: ${_loc}")
    endif()
    add_executable(capp "${CMAKE_CURRENT_LIST_DIR}/main.c")
    target_link_libraries(capp PRIVATE vpack::lib)
    set(POLYORCH_FIXTURE_ARTIFACTS "capp=${CMAKE_BINARY_DIR}/capp${CMAKE_EXECUTABLE_SUFFIX}")
    string(JOIN "\n" _af ${POLYORCH_FIXTURE_ARTIFACTS})
    file(WRITE "${CMAKE_BINARY_DIR}/polyorch-fixture-artifacts.txt" "${_af}\n")
endif()
