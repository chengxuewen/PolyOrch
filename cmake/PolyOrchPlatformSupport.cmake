########################################################################################################################
#
# Library: CxxKit
#
# Copyright (C) 2026~Present ChengXueWen.
#
# License: MIT License
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
# documentation files (the "Software"), to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and
# to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial portions
# of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
# WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS
# OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
# OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
########################################################################################################################

#-----------------------------------------------------------------------------------------------------------------------
# polyorch_set01 finction
#-----------------------------------------------------------------------------------------------------------------------
function(polyorch_set01 result)
    if(${ARGN})
        set("${result}" 1 PARENT_SCOPE)
    else()
        set("${result}" 0 PARENT_SCOPE)
    endif()
endfunction()


#-----------------------------------------------------------------------------------------------------------------------
# CxxKit set system variable
#-----------------------------------------------------------------------------------------------------------------------
message(STATUS "Build in system: ${CMAKE_SYSTEM_NAME}")
set(PolyOrch_SYSTEM_NAME ${CMAKE_SYSTEM_NAME})
set(PolyOrch_SYSTEM_VERSION ${CMAKE_SYSTEM_VERSION})
set(PolyOrch_SYSTEM_PROCESSOR ${CMAKE_SYSTEM_PROCESSOR})
polyorch_set01(PolyOrch_SYSTEM_LINUX
    CMAKE_SYSTEM_NAME STREQUAL "Linux")
polyorch_set01(PolyOrch_SYSTEM_WINCE
    CMAKE_SYSTEM_NAME STREQUAL "WindowsCE")
polyorch_set01(PolyOrch_SYSTEM_WIN
    PolyOrch_SYSTEM_WINCE OR CMAKE_SYSTEM_NAME STREQUAL "Windows")
polyorch_set01(PolyOrch_SYSTEM_HPUX
    CMAKE_SYSTEM_NAME STREQUAL "HPUX")
polyorch_set01(PolyOrch_SYSTEM_ANDROID
    CMAKE_SYSTEM_NAME STREQUAL "Android")
polyorch_set01(PolyOrch_SYSTEM_NACL
    CMAKE_SYSTEM_NAME STREQUAL "NaCl")
polyorch_set01(PolyOrch_SYSTEM_INTEGRITY
    CMAKE_SYSTEM_NAME STREQUAL "Integrity")
polyorch_set01(PolyOrch_SYSTEM_VXWORKS
    CMAKE_SYSTEM_NAME STREQUAL "VxWorks")
polyorch_set01(PolyOrch_SYSTEM_QNX
    CMAKE_SYSTEM_NAME STREQUAL "QNX")
polyorch_set01(PolyOrch_SYSTEM_OPENBSD
    CMAKE_SYSTEM_NAME STREQUAL "OpenBSD")
polyorch_set01(PolyOrch_SYSTEM_FREEBSD
    CMAKE_SYSTEM_NAME STREQUAL "FreeBSD")
polyorch_set01(PolyOrch_SYSTEM_NETBSD
    CMAKE_SYSTEM_NAME STREQUAL "NetBSD")
polyorch_set01(PolyOrch_SYSTEM_WASM
    CMAKE_SYSTEM_NAME STREQUAL "Emscripten" OR EMSCRIPTEN)
polyorch_set01(PolyOrch_SYSTEM_SOLARIS
    CMAKE_SYSTEM_NAME STREQUAL "SunOS")
polyorch_set01(PolyOrch_SYSTEM_HURD
    CMAKE_SYSTEM_NAME STREQUAL "GNU")
# This is the only reliable way we can determine the webOS platform as the yocto recipe adds this compile definition
# into its generated toolchain.cmake file
polyorch_set01(PolyOrch_SYSTEM_WEBOS
    CMAKE_CXX_FLAGS MATCHES "-D__WEBOS__")
polyorch_set01(PolyOrch_SYSTEM_BSD
    APPLE OR OPENBSD OR FREEBSD OR NETBSD)
polyorch_set01(PolyOrch_SYSTEM_DARWIN
    APPLE OR CMAKE_SYSTEM_NAME STREQUAL "Darwin")
polyorch_set01(PolyOrch_SYSTEM_IOS
    APPLE AND CMAKE_SYSTEM_NAME STREQUAL "iOS")
polyorch_set01(PolyOrch_SYSTEM_TVOS
    APPLE AND CMAKE_SYSTEM_NAME STREQUAL "tvOS")
polyorch_set01(PolyOrch_SYSTEM_WATCHOS
    APPLE AND CMAKE_SYSTEM_NAME STREQUAL "watchOS")
polyorch_set01(PolyOrch_SYSTEM_UIKIT
    APPLE AND (IOS OR TVOS OR WATCHOS))
polyorch_set01(PolyOrch_SYSTEM_MACOS
    APPLE AND NOT UIKIT)
polyorch_set01(PolyOrch_SYSTEM_UNIX UNIX)
polyorch_set01(PolyOrch_SYSTEM_WIN32 WIN32)
polyorch_set01(PolyOrch_SYSTEM_APPLE APPLE)
polyorch_set01(PolyOrch_SYSTEM_MAC APPLE)


#-----------------------------------------------------------------------------------------------------------------------
# CxxKit set processor variable
#-----------------------------------------------------------------------------------------------------------------------
message(STATUS "Build in processor: ${CMAKE_SYSTEM_PROCESSOR}")
message(STATUS "Build in processor: ${CMAKE_SYSTEM_PROCESSOR}")
string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" PolyOrch_SYSTEM_PROCESSOR)
polyorch_set01(PolyOrch_PROCESSOR_I386
    PolyOrch_SYSTEM_PROCESSOR STREQUAL "i386")
polyorch_set01(PolyOrch_PROCESSOR_I686
    PolyOrch_SYSTEM_PROCESSOR MATCHES "i686")
polyorch_set01(PolyOrch_PROCESSOR_X86_64
    PolyOrch_SYSTEM_PROCESSOR MATCHES "x86_64")
polyorch_set01(PolyOrch_PROCESSOR_X86
    PolyOrch_SYSTEM_PROCESSOR MATCHES "x86")
polyorch_set01(PolyOrch_PROCESSOR_AMD64
    PolyOrch_SYSTEM_PROCESSOR STREQUAL "amd64")
polyorch_set01(PolyOrch_PROCESSOR_AARCH64
    PolyOrch_SYSTEM_PROCESSOR STREQUAL "aarch64")
polyorch_set01(PolyOrch_PROCESSOR_ARM64
    PolyOrch_SYSTEM_PROCESSOR STREQUAL "arm64" OR PolyOrch_PROCESSOR_AARCH64)
polyorch_set01(PolyOrch_PROCESSOR_ARM32
    PolyOrch_SYSTEM_PROCESSOR STREQUAL "arm32")
polyorch_set01(PolyOrch_PROCESSOR_ARM
    PolyOrch_PROCESSOR_AARCH64 OR PolyOrch_PROCESSOR_ARM64 OR PolyOrch_PROCESSOR_ARM32)


#-----------------------------------------------------------------------------------------------------------------------
# CxxKit set cxx compiler variable
#-----------------------------------------------------------------------------------------------------------------------
message(STATUS "Build in cxx compiler: ${CMAKE_CXX_COMPILER_ID}")
set(PolyOrch_CXX_COMPILER_ID ${CMAKE_CXX_COMPILER_ID})
set(PolyOrch_CXX_COMPILER_VERSION ${CMAKE_CXX_COMPILER_VERSION})
polyorch_set01(PolyOrch_CXX_COMPILER_GNU
    CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
polyorch_set01(PolyOrch_CXX_COMPILER_MSVC
    MSVC OR CMAKE_CXX_COMPILER_ID STREQUAL "Msvc")
polyorch_set01(PolyOrch_CXX_COMPILER_MINGW
    MINGW OR CMAKE_CXX_COMPILER_ID STREQUAL "Mingw")
polyorch_set01(PolyOrch_CXX_COMPILER_CLANG
    CMAKE_CXX_COMPILER_ID MATCHES "Clang|IntelLLVM")
polyorch_set01(PolyOrch_CXX_COMPILER_APPLE_CLANG
    CMAKE_CXX_COMPILER_ID MATCHES "AppleClang")
polyorch_set01(PolyOrch_CXX_COMPILER_INTEL_LLVM
    CMAKE_CXX_COMPILER_ID STREQUAL "IntelLLVM")
polyorch_set01(PolyOrch_CXX_COMPILER_QCC
    CMAKE_CXX_COMPILER_ID STREQUAL "QCC") # CMP0047


#-----------------------------------------------------------------------------------------------------------------------
# CxxKit arch size variable
#-----------------------------------------------------------------------------------------------------------------------
if(CMAKE_SIZEOF_VOID_P EQUAL 8)
    set(PolyOrch_ARCH_BIT 64)
    set(PolyOrch_ARCH_NAME x64)
    set(PolyOrch_ARCH_64BIT TRUE)
elseif(CMAKE_SIZEOF_VOID_P EQUAL 4)
    set(PolyOrch_ARCH_BIT 32)
    set(PolyOrch_ARCH_NAME x86)
    set(PolyOrch_ARCH_32BIT TRUE)
endif()
message(STATUS "Build in bit: ${PolyOrch_ARCH_BIT}")


#-----------------------------------------------------------------------------------------------------------------------
# CxxKit vcpkg triplets variable
#-----------------------------------------------------------------------------------------------------------------------
if(PolyOrch_PROCESSOR_X86_64 OR PolyOrch_PROCESSOR_AMD64)
    if (PolyOrch_ARCH_64BIT)
        set(PolyOrch_VCPKG_TRIPLET_ARCH x64)
    else()
        set(PolyOrch_VCPKG_TRIPLET_ARCH x86)
    endif()
    set(PolyOrch_VCPKG_TRIPLET_ARCH_ARM OFF)
elseif(PolyOrch_PROCESSOR_I686 OR PolyOrch_PROCESSOR_I386)
    set(PolyOrch_VCPKG_TRIPLET_ARCH x86)
    set(PolyOrch_VCPKG_TRIPLET_ARCH_ARM OFF)
elseif(PolyOrch_PROCESSOR_ARM64 OR PolyOrch_PROCESSOR_AARCH64)
    set(PolyOrch_VCPKG_TRIPLET_ARCH arm64)
    set(PolyOrch_VCPKG_TRIPLET_ARCH_ARM ON)
elseif(PolyOrch_PROCESSOR_ARM32)
    set(PolyOrch_VCPKG_TRIPLET_ARCH arm32)
    set(PolyOrch_VCPKG_TRIPLET_ARCH_ARM ON)
else()
    message(FATAL_ERROR "Unknown processor arch.")
endif()

if(PolyOrch_SYSTEM_WIN)
    set(PolyOrch_VCPKG_TRIPLET_PLATFORM windows)
elseif(PolyOrch_SYSTEM_IOS)
    set(PolyOrch_VCPKG_TRIPLET_PLATFORM ios)
elseif(PolyOrch_SYSTEM_TVOS)
    set(PolyOrch_VCPKG_TRIPLET_PLATFORM tvos)
elseif(PolyOrch_SYSTEM_DARWIN)
    set(PolyOrch_VCPKG_TRIPLET_PLATFORM osx)
elseif(PolyOrch_SYSTEM_LINUX)
    set(PolyOrch_VCPKG_TRIPLET_PLATFORM linux)
elseif(PolyOrch_SYSTEM_ANDROID)
    set(PolyOrch_VCPKG_TRIPLET_PLATFORM android)
elseif(PolyOrch_SYSTEM_FREEBSD)
    set(PolyOrch_VCPKG_TRIPLET_PLATFORM freebsd)
elseif(PolyOrch_CXX_COMPILER_MINGW)
    set(PolyOrch_VCPKG_TRIPLET_PLATFORM mingw)
else()
    message(FATAL_ERROR "Unknown system platform.")
endif()
set(PolyOrch_VCPKG_TRIPLET "${PolyOrch_VCPKG_TRIPLET_ARCH}-${PolyOrch_VCPKG_TRIPLET_PLATFORM}" CACHE INTERNAL "" FORCE)
message(STATUS "Vcpkg triplet name: ${PolyOrch_VCPKG_TRIPLET}")


#-----------------------------------------------------------------------------------------------------------------------
# CxxKit platform compile arch variable
#-----------------------------------------------------------------------------------------------------------------------
string(TOUPPER "${CMAKE_BUILD_TYPE}" PolyOrch_UPPER_BUILD_TYPE)
string(TOLOWER "${CMAKE_BUILD_TYPE}" PolyOrch_LOWER_BUILD_TYPE)
string(TOLOWER "${CMAKE_SYSTEM_NAME}" PolyOrch_LOWER_SYSTEM_NAME)
string(TOLOWER "${CMAKE_CXX_COMPILER_ID}" PolyOrch_LOWER_CXX_COMPILER_ID)
string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" PolyOrch_LOWER_SYSTEM_PROCESSOR)
string(TOLOWER "${CMAKE_HOST_SYSTEM_NAME}" PolyOrch_LOWER_HOST_SYSTEM_NAME)
set(PolyOrch_X64_PROCESSORS "amd64" "x64" "x86_64")
set(PolyOrch_X86_PROCESSORS "i386" "i686" "x86")
set(PolyOrch_ARM32_PROCESSORS "arm32" "arm")
set(PolyOrch_AARCH64_PROCESSORS "aarch64")
set(PolyOrch_ARM64_PROCESSORS "arm64")
set(PolyOrch_ARMV7_PROCESSORS "armv7-a")
if(PolyOrch_LOWER_SYSTEM_PROCESSOR IN_LIST PolyOrch_X64_PROCESSORS)
    set(PolyOrch_PROCESSOR_MERGE_NAME x64)
elseif(PolyOrch_LOWER_SYSTEM_PROCESSOR IN_LIST PolyOrch_X86_PROCESSORS)
    set(PolyOrch_PROCESSOR_MERGE_NAME x86)
elseif(PolyOrch_LOWER_SYSTEM_PROCESSOR IN_LIST PolyOrch_ARM32_PROCESSORS)
    set(PolyOrch_PROCESSOR_MERGE_NAME arm32)
elseif(PolyOrch_LOWER_SYSTEM_PROCESSOR IN_LIST PolyOrch_ARM64_PROCESSORS)
    set(PolyOrch_PROCESSOR_MERGE_NAME arm64)
elseif(PolyOrch_LOWER_SYSTEM_PROCESSOR IN_LIST PolyOrch_ARMV7_PROCESSORS)
    set(PolyOrch_PROCESSOR_MERGE_NAME armv7)
elseif(PolyOrch_LOWER_SYSTEM_PROCESSOR IN_LIST PolyOrch_AARCH64_PROCESSORS)
    set(PolyOrch_PROCESSOR_MERGE_NAME aarch64)
else()
    message(FATAL_ERROR "Unknown system processor ${CMAKE_SYSTEM_PROCESSOR}.")
endif()
set(PolyOrch_PLATFORM_NAME "${PolyOrch_LOWER_SYSTEM_NAME}-${PolyOrch_PROCESSOR_MERGE_NAME}")
set(PolyOrch_PLATFORM_COMPILER_NAME "${PolyOrch_PLATFORM_NAME}-${PolyOrch_LOWER_CXX_COMPILER_ID}")
message(STATUS "Platform name: ${PolyOrch_PLATFORM_NAME}")
message(STATUS "Platform compiler name: ${PolyOrch_PLATFORM_COMPILER_NAME}")
set(PolyOrch_HOST_PLATFORM_NAME "${PolyOrch_LOWER_HOST_SYSTEM_NAME}-${CMAKE_HOST_SYSTEM_PROCESSOR}")
message(STATUS "Host platform name: ${PolyOrch_HOST_PLATFORM_NAME}")


#-----------------------------------------------------------------------------------------------------------------------
# CxxKit mkspecs version
#-----------------------------------------------------------------------------------------------------------------------
if(PolyOrch_SYSTEM_WIN32)
    set(PolyOrch_DEFAULT_PLATFORM_DEFINITIONS WIN32 _ENABLE_EXTENDED_ALIGNED_STORAGE)
    if(PolyOrch_ARCH_64BIT)
        list(APPEND PolyOrch_DEFAULT_PLATFORM_DEFINITIONS WIN64 _WIN64)
    endif()
    if(PolyOrch_CXX_COMPILER_MSVC)
        if(PolyOrch_CXX_COMPILER_CLANG)
            set(PolyOrch_DEFAULT_MKSPEC win32-clang-msvc)
        elseif(PolyOrch_PROCESSOR_ARM64)
            set(PolyOrch_DEFAULT_MKSPEC win32-arm64-msvc)
        else()
            set(PolyOrch_DEFAULT_MKSPEC win32-msvc)
        endif()
    elseif(PolyOrch_CXX_COMPILER_CLANG AND PolyOrch_CXX_COMPILER_MINGW)
        set(PolyOrch_DEFAULT_MKSPEC win32-clang-g++)
    elseif(PolyOrch_CXX_COMPILER_MINGW)
        set(PolyOrch_DEFAULT_MKSPEC win32-g++)
    endif()

    if(PolyOrch_CXX_COMPILER_MINGW)
        list(APPEND PolyOrch_DEFAULT_PLATFORM_DEFINITIONS MINGW_HAS_SECURE_API=1)
    endif()
elseif(PolyOrch_SYSTEM_LINUX)
    if(PolyOrch_CXX_COMPILER_GNU)
        set(PolyOrch_DEFAULT_MKSPEC linux-g++)
    elseif(PolyOrch_CXX_COMPILER_CLANG)
        set(PolyOrch_DEFAULT_MKSPEC linux-clang)
    endif()
elseif(PolyOrch_SYSTEM_ANDROID)
    if(PolyOrch_CXX_COMPILER_GNU)
        set(PolyOrch_DEFAULT_MKSPEC android-g++)
    elseif(PolyOrch_CXX_COMPILER_CLANG)
        set(PolyOrch_DEFAULT_MKSPEC android-clang)
    endif()
elseif(PolyOrch_SYSTEM_IOS)
    set(PolyOrch_DEFAULT_MKSPEC macx-ios-clang)
elseif(PolyOrch_SYSTEM_APPLE)
    set(PolyOrch_DEFAULT_MKSPEC macx-clang)
elseif(PolyOrch_SYSTEM_WASM)
    set(PolyOrch_DEFAULT_MKSPEC wasm-emscripten)
elseif(PolyOrch_SYSTEM_QNX)
    # Certain POSIX defines are not set if we don't compile with -std=gnuXX
    set(PolyOrch_ENABLE_CXX_EXTENSIONS ON)

    list(APPEND PolyOrch_DEFAULT_PLATFORM_DEFINITIONS _FORTIFY_SOURCE=2 _REENTRANT)

    set(compiler_aarch64le aarch64le)
    set(compiler_armle-v7 armv7le)
    set(compiler_x86-64 x86_64)
    set(compiler_x86 x86)
    foreach(arch aarch64le armle-v7 x86-64 x86)
        if(CMAKE_CXX_COMPILER_TARGET MATCHES "${compiler_${arch}}$")
            set(PolyOrch_DEFAULT_MKSPEC qnx-${arch}-qcc)
        endif()
    endforeach()
elseif(PolyOrch_SYSTEM_FREEBSD)
    if(PolyOrch_CXX_COMPILER_CLANG)
        set(PolyOrch_DEFAULT_MKSPEC freebsd-clang)
    elseif(PolyOrch_CXX_COMPILER_GNU)
        set(PolyOrch_DEFAULT_MKSPEC freebsd-g++)
    endif()
elseif(PolyOrch_SYSTEM_NETBSD)
    set(PolyOrch_DEFAULT_MKSPEC netbsd-g++)
elseif(PolyOrch_SYSTEM_OPENBSD)
    set(PolyOrch_DEFAULT_MKSPEC openbsd-g++)
elseif(PolyOrch_SYSTEM_SOLARIS)
    if(PolyOrch_CXX_COMPILER_GNU)
        if(PolyOrch_ARCH_64BIT)
            set(PolyOrch_DEFAULT_MKSPEC solaris-g++-64)
        else()
            set(PolyOrch_DEFAULT_MKSPEC solaris-g++)
        endif()
    else()
        if(PolyOrch_ARCH_64BIT)
            set(PolyOrch_DEFAULT_MKSPEC solaris-cc-64)
        else()
            set(PolyOrch_DEFAULT_MKSPEC solaris-cc)
        endif()
    endif()
elseif(PolyOrch_SYSTEM_HURD)
    set(PolyOrch_DEFAULT_MKSPEC hurd-g++)
endif()

if(NOT PolyOrch_DEFAULT_MKSPEC)
    message(FATAL_ERROR "mkspec not Detected!")
else()
    message(STATUS "Build in mkspec: ${PolyOrch_DEFAULT_MKSPEC}")
endif()

if(NOT DEFINED PolyOrch_DEFAULT_PLATFORM_DEFINITIONS)
    set(PolyOrch_DEFAULT_PLATFORM_DEFINITIONS "")
endif()

set(PolyOrch_PLATFORM_DEFINITIONS ${PolyOrch_DEFAULT_PLATFORM_DEFINITIONS} CACHE STRING "CxxKit platform specific pre-processor defines")


#-----------------------------------------------------------------------------------------------------------------------
# CxxKit parse version
#-----------------------------------------------------------------------------------------------------------------------
# Parses a version string like "xx.yy.zz" and sets the major, minor and patch variables.
function(polyorch_parse_version_string version_string out_var_prefix)
    string(REPLACE "." ";" version_list ${version_string})
    list(LENGTH version_list length)

    set(out_var "${out_var_prefix}_MAJOR")
    set(value "")
    if(length GREATER 0)
        list(GET version_list 0 value)
        list(REMOVE_AT version_list 0)
        math(EXPR length "${length}-1")
    endif()
    set(${out_var} "${value}" PARENT_SCOPE)

    set(out_var "${out_var_prefix}_MINOR")
    set(value "")
    if(length GREATER 0)
        list(GET version_list 0 value)
        set(${out_var} "${value}" PARENT_SCOPE)
        list(REMOVE_AT version_list 0)
        math(EXPR length "${length}-1")
    endif()
    set(${out_var} "${value}" PARENT_SCOPE)

    set(out_var "${out_var_prefix}_PATCH")
    set(value "")
    if(length GREATER 0)
        list(GET version_list 0 value)
        set(${out_var} "${value}" PARENT_SCOPE)
        list(REMOVE_AT version_list 0)
        math(EXPR length "${length}-1")
    endif()
    set(${out_var} "${value}" PARENT_SCOPE)
endfunction()

# Set up the separate version components for the compiler version, to allow mapping of qmake
# conditions like 'equals(PolyOrch_GCC_MAJOR_VERSION,5)'.
if(CMAKE_CXX_COMPILER_VERSION)
    polyorch_parse_version_string("${CMAKE_CXX_COMPILER_VERSION}" "PolyOrch_COMPILER_VERSION")
endif()
