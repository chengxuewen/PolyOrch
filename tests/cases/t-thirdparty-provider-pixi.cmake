# expect-log THIRD-PARTY-PROVIDER-PIXI-OK
# requires: cxx
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchThirdPartyHelpers.cmake")

# ck() token-joins its arguments and mangles escape-bearing patterns (_inc's
# own documented trap), so multi-word MATCHES assertions go through these
# function-scope helpers instead.
function(_ckm hay pat what)
    if(NOT "${hay}" MATCHES "${pat}")
        string(SUBSTRING "${hay}" 0 400 _snip)
        message(FATAL_ERROR "assert failed [${what}] -- pattern not found:\n  ${pat}\ntext:\n  ${_snip}")
    endif()
endfunction()
function(_cknm hay pat what)
    if("${hay}" MATCHES "${pat}")
        message(FATAL_ERROR "assert failed [${what}] -- forbidden pattern matched:\n  ${pat}")
    endif()
endfunction()

polyorch_requires(cxx _ok)
if(NOT _ok)
    message(STATUS "t-thirdparty-provider-pixi : SKIP (no c++ toolchain on PATH or the pixi dirs)")
    return()
endif()
find_program(_tp_cxx NAMES c++ g++ clang++ cl)
find_program(_tp_ninja NAMES ninja)
find_program(_tp_make NAMES make)
if(_tp_ninja)
    set(_tp_gen "Ninja")
elseif(_tp_make)
    set(_tp_gen "Unix Makefiles")
else()
    message(FATAL_ERROR "neither ninja nor make found -- the build verb needs a generator")
endif()

set(_fx "${CMAKE_CURRENT_LIST_DIR}/../fixtures/thirdparty-basic/payload-envprobe")
set(_work "$ENV{TMPDIR}/tp-provider")
file(REMOVE_RECURSE "${_work}")

# A fake pixi context: manifest + lock + an INSTALLED env prefix -- the first
# candidate polyorch_pixi_env_paths checks, so no real pixi binary is needed
# (its `info --json` probe just fails and is ignored).
file(MAKE_DIRECTORY "${_work}/pix/.pixi/envs/tpenv/include" "${_work}/pix/.pixi/envs/tpenv/lib/pkgconfig")
file(WRITE "${_work}/pix/pixi.toml" "[project]\nname = \"tpfake\"\nchannels = []\n")
file(WRITE "${_work}/pix/pixi.lock" "version: 1\n")
set(PolyOrch_PIXI_EXECUTABLE "${CMAKE_COMMAND}" CACHE INTERNAL "")
set(PolyOrch_PIXI_MANIFEST "${_work}/pix/pixi.toml" CACHE INTERNAL "")
set(_prefix "${_work}/pix/.pixi/envs/tpenv")

# poison the parent env: the provider must never let these reach the child
set(ENV{CPATH} "/poison/cpath")
set(ENV{CPLUS_INCLUDE_PATH} "/poison/cxxinc")
set(ENV{CONDA_PREFIX} "/poison/conda")
set(ENV{LIBRARY_PATH} "/poison/libpath")

polyorch_thirdparty_build(NAME tpenv SOURCE_DIR "${_fx}"
    BUILD_DIR "${_work}/b-pixi" INSTALL_DIR "${_work}/i-pixi" BUILD_TYPE Debug
    GENERATOR "${_tp_gen}" DEPENDENCY_PROVIDER pixi PIXI_ENVIRONMENT tpenv
    CMAKE_ARGS -DCMAKE_CXX_COMPILER=${_tp_cxx})
file(READ "${_work}/b-pixi/polyorch-thirdparty-tpenv-configure.log" _l1)

# injection = the prefix's include/lib SUB-paths, nothing else (r4 C1)
_ckm("${_l1}" "PROBE CMAKE_PREFIX_PATH=\\[${_prefix}/include:${_prefix}/lib\\]" "sub-path injection")
# the bare prefix never appears as the injected value, and bin/ never rides in
_cknm("${_l1}" "CMAKE_PREFIX_PATH=\\[${_prefix}\\]" "bare-prefix injection")
_cknm("${_l1}" "tpenv/bin" "bin in the injection")
# every compiler-direct-read poison is stripped from the child
_ckm("${_l1}" "PROBE CPATH=\\[\\]" "CPATH sanitized")
_ckm("${_l1}" "PROBE CPLUS_INCLUDE_PATH=\\[\\]" "CPLUS_INCLUDE_PATH sanitized")
_ckm("${_l1}" "PROBE CONDA_PREFIX=\\[\\]" "CONDA_PREFIX sanitized")
_ckm("${_l1}" "PROBE LIBRARY_PATH=\\[\\]" "LIBRARY_PATH sanitized")
# C1 negative: the inner compiler is the call-site one verbatim -- no .pixi
# tree can ever sneak in through PATH discovery. Verbatim FIND (the tool
# path carries regex metacharacters like the `++` in c++).
string(FIND "${_l1}" "PROBE COMPILER=${_tp_cxx}" _cf)
ck(NOT _cf EQUAL -1)
_cknm("${_l1}" "COMPILER=[^ ]*\\.pixi" "pixi compiler leak")
file(GLOB _lib1 "${_work}/i-pixi/lib/libtpenv.*")
ck(_lib1)

# provider=system: sanitize only -- NO injection; the inherited value passes
set(ENV{CMAKE_PREFIX_PATH} "/inherit/me")
polyorch_thirdparty_build(NAME tpenv SOURCE_DIR "${_fx}"
    BUILD_DIR "${_work}/b-sys" INSTALL_DIR "${_work}/i-sys" BUILD_TYPE Debug
    GENERATOR "${_tp_gen}" DEPENDENCY_PROVIDER system
    CMAKE_ARGS -DCMAKE_CXX_COMPILER=${_tp_cxx})
file(READ "${_work}/b-sys/polyorch-thirdparty-tpenv-configure.log" _l2)
_ckm("${_l2}" "PROBE CMAKE_PREFIX_PATH=\\[/inherit/me\\]" "system provider passes the inherited value")
_ckm("${_l2}" "PROBE CPATH=\\[\\]" "system provider sanitizes")
_cknm("${_l2}" "tpenv/include" "system provider injects nothing")

# discipline 3: provider + lock hash + environment NAME all ride the key
string(RANDOM LENGTH 64 ALPHABET 1 RANDOM_SEED 21 _arch64)
file(SHA256 "${_work}/pix/pixi.lock" _locksha)
polyorch_thirdparty_fingerprint(_kNone ARCHIVE_SHA256 "${_arch64}" BUILD_TYPE Debug)
polyorch_thirdparty_fingerprint(_kPixi ARCHIVE_SHA256 "${_arch64}" BUILD_TYPE Debug
    DEPENDENCY_PROVIDER pixi PIXI_LOCK_SHA256 "${_locksha}" PIXI_ENVIRONMENT tpenv)
polyorch_thirdparty_fingerprint(_kPixi2 ARCHIVE_SHA256 "${_arch64}" BUILD_TYPE Debug
    DEPENDENCY_PROVIDER pixi PIXI_LOCK_SHA256 "${_locksha}" PIXI_ENVIRONMENT tpenv)
polyorch_thirdparty_fingerprint(_kOtherEnv ARCHIVE_SHA256 "${_arch64}" BUILD_TYPE Debug
    DEPENDENCY_PROVIDER pixi PIXI_LOCK_SHA256 "${_locksha}" PIXI_ENVIRONMENT other)
ck(NOT _kNone STREQUAL _kPixi)
ck_str("${_kPixi}" "${_kPixi2}")
ck(NOT _kPixi STREQUAL _kOtherEnv)

message(STATUS "THIRD-PARTY-PROVIDER-PIXI-OK")
