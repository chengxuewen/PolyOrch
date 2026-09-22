#!/usr/bin/env bash
# scripts/ctest.sh -- the standard cmake+ctest entry for this LANGUAGES-NONE
# root, as an INDIRECT cmake invocation (per user directive 2026-09-22).
#
# Why this exists: the root project() declares LANGUAGES NONE (a pure helper
# tree), so CMake never probes a C++ compiler and CMAKE_CXX_COMPILER_ID stays
# empty -- but cmake/PolyOrchPlatformSupport.cmake (external CxxKit-lineage
# rewrite, root territory: DO NOT EDIT) dispatches its mkspec on that exact
# variable and FATALs standalone ("mkspec not Detected!").
#
# The indirect mechanism: CMAKE_PROJECT_TOP_LEVEL_INCLUDES runs BEFORE
# project(), where a plain set() of CMAKE_CXX_COMPILER_ID survives the
# LANGUAGES-NONE project() (measured on CMake 4.4.3). This script generates a
# throwaway inject file that probes the host C++ driver, then hands it to a
# normal `cmake` configure + `ctest` run. The root files stay untouched.
#
# Usage: scripts/ctest.sh [extra cmake -D flags...]
#   POLYORCH_TEST_E2E=ON scripts/ctest.sh     # also register the e2e cases
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build="${POLYORCH_CTEST_BUILD_DIR:-/tmp/polyorch-ctest}"

if [ ! -f "$here/scripts/inject.cmake" ]; then
    # Fallback for fresh clones: (re)generate the stable inject artifact.
    cat > "$here/scripts/inject.cmake" <<'INJ'
# Probes the host C++ driver and pre-seeds CMAKE_CXX_COMPILER_ID before
# project(PolyOrch ... LANGUAGES NONE). See scripts/ctest.sh header.
set(_po_cxx "")
if(DEFINED ENV{CXX} AND NOT "$ENV{CXX}" STREQUAL "")
  execute_process(COMMAND "$ENV{CXX}" --version RESULT_VARIABLE _rc OUTPUT_QUIET ERROR_QUIET)
  if(_rc EQUAL 0)
    set(_po_cxx "$ENV{CXX}")
  endif()
endif()
if(NOT _po_cxx)
  find_program(_po_gxx NAMES g++ c++ PATHS ENV PATH)
  if(_po_gxx)
    set(_po_cxx "${_po_gxx}")
  else()
    find_program(_po_clxx NAMES clang++ PATHS ENV PATH)
    if(_po_clxx)
      set(_po_cxx "${_po_clxx}")
    endif()
  endif()
endif()
if(_po_cxx)
  execute_process(COMMAND "${_po_cxx}" --version OUTPUT_VARIABLE _v ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE)
  if(_v MATCHES "gcc|GCC|g\\+\\+")
    set(CMAKE_CXX_COMPILER_ID GNU)
  elseif(_v MATCHES "[Cc]lang version|Apple")
    set(CMAKE_CXX_COMPILER_ID Clang)
  else()
    set(CMAKE_CXX_COMPILER_ID GNU)
  endif()
  execute_process(COMMAND "${_po_cxx}" -dumpfullversion -dumpversion OUTPUT_VARIABLE CMAKE_CXX_COMPILER_VERSION ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE)
  message(STATUS "inject: host C++ driver = ${_po_cxx} (${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION})")
else()
  message(FATAL_ERROR "inject: no C++ driver found (try CXX=<driver> $0)")
endif()
INJ
fi


# --- 2. configure (indirect: all real work is plain cmake invocations) ---
cmake -S "$here" -B "$build" -DCMAKE_PROJECT_TOP_LEVEL_INCLUDES="$here/scripts/inject.cmake" \
    -DPolyOrch_BUILD_TESTS=ON -DPolyOrch_BUILD_EXAMPLES=OFF \
    -DPolyOrch_TEST_E2E="${POLYORCH_TEST_E2E:-OFF}" \
    -DCMAKE_CXX_COMPILER=gcc "$@"

# --- 3. test ---
ctest --test-dir "$build" --output-on-failure "$@"
