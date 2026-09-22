# PolyOrch FindRust -- rust toolchain discovery (system or pixi route), target
# triple families, artifact naming tables, native-static-libs probing, and the
# shared cargo-command wrapper (PATH composition + host-env isolation).
#
# Split out of PolyOrchRustHelpers.cmake on 2026-09-22 per the module
# organization ruling (user ruling 2026-09-22; file taxonomy mirrors the
# reference project's FindRust/Corrosion split -- see
# docs/reference/corrosion-ATTRIBUTION.md).
#
# Include-time contract: zero side effects -- definitions and comments only.
# Requires CMake >= 3.25 (PARSE_ARGV, cmake_path, NO_CACHE find_program).
include_guard(GLOBAL)

# ---------------------------------------------------------------- internals ---

# Internal: validate one injected executable (WP2 pair). An empty value is
# "not injected" (no-op); anything set must name a real file -- a suspicious
# toolchain source fails hard (invariant 5). NAME is the uppercase tool
# token used in the cache-variable spelling. Splitting the two calls avoids
# any key:value parsing, which would be fragile on Windows paths.
function(_polyorch_rust_check_injected NAME VALUE)
    if(VALUE AND NOT EXISTS "${VALUE}")
        message(FATAL_ERROR
            "polyorch_rust_setup: PolyOrch_RUST_${NAME}_EXECUTABLE is set but no such "
            "file: '${VALUE}' (unset it to fall back to discovery, or fix the path)")
    endif()
endfunction()

# Internal: fail when any named variable is undefined or empty. Every public
# entry point validates its required keywords through this, so the message
# shape ("polyorch_rust: ...") is stable enough to grep in tests.
function(_polyorch_rust_must)
    foreach(_name IN LISTS ARGN)
        if(NOT DEFINED ${_name} OR "${${_name}}" STREQUAL "")
            message(FATAL_ERROR "polyorch_rust: missing required argument '${_name}'")
        endif()
    endforeach()
endfunction()

# polyorch_rust_version_ok(<actual> <out-var> [VERSION <v> [EXACT]] [RANGE <min>..<max>])
# Pure version predicate. No constraint => TRUE (any version is fine).
# VERSION <v> is a floor (>=) unless EXACT pins equality; RANGE <min>..<max>
# is inclusive on both ends. A malformed ACTUAL (nightly suffixes, garbage,
# empty) is simply FALSE -- it never warns and never FATALs, because it is
# machine output being tested, not an author mistake; malformed CONSTRAINT
# arguments do FATAL (author-side).
#
# Adapted from corrosion (MIT, commit c4786e7): cmake/FindRust.cmake:38-71
# (the _findrust_version_ok shape; the reference reads find_package globals,
# this takes its inputs as arguments instead, per the no-find_package design).
function(polyorch_rust_version_ok ACTUAL_VERSION OUT_IS_OK)
    cmake_parse_arguments(PARSE_ARGV 2 V "EXACT" "VERSION;RANGE" "")
    if(V_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR
            "polyorch_rust_version_ok: unknown args: ${V_UNPARSED_ARGUMENTS}")
    endif()
    if(V_VERSION AND V_RANGE)
        message(FATAL_ERROR
            "polyorch_rust_version_ok: VERSION and RANGE are mutually exclusive")
    endif()
    set(_num "^[0-9]+(\\.[0-9]+)*$")
    if(V_VERSION AND NOT V_VERSION MATCHES "${_num}")
        message(FATAL_ERROR
            "polyorch_rust_version_ok: VERSION must be a dotted numeric version, got '${V_VERSION}'")
    endif()
    set(_lo "")
    set(_hi "")
    if(V_RANGE)
        if(NOT V_RANGE MATCHES "^([0-9]+(\\.[0-9]+)*)\\.\\.([0-9]+(\\.[0-9]+)*)$")
            message(FATAL_ERROR
                "polyorch_rust_version_ok: RANGE must be '<num>..<num>, got '${V_RANGE}'")
        endif()
        set(_lo "${CMAKE_MATCH_1}")
        set(_hi "${CMAKE_MATCH_3}")
    endif()
    set(_ok FALSE)
    if(NOT V_VERSION AND NOT V_RANGE)
        set(_ok TRUE)   # no version requirement specified => always okay (find:67-70)
    elseif(NOT ACTUAL_VERSION MATCHES "${_num}")
        set(_ok FALSE)  # unusable actual never matches, silently
    elseif(V_RANGE)
        if("${ACTUAL_VERSION}" VERSION_GREATER_EQUAL "${_lo}"
                AND "${ACTUAL_VERSION}" VERSION_LESS_EQUAL "${_hi}")
            set(_ok TRUE)
        endif()
    else()
        if(V_EXACT)
            if("${ACTUAL_VERSION}" VERSION_EQUAL "${V_VERSION}")
                set(_ok TRUE)
            endif()
        elseif("${ACTUAL_VERSION}" VERSION_GREATER_EQUAL "${V_VERSION}")
            set(_ok TRUE)
        endif()
    endif()
    set(${OUT_IS_OK} ${_ok} PARENT_SCOPE)
endfunction()

# Internal: object-family of a rust target triple.
#   windows+msvc        -> msvc   (foo.exe / foo.lib / foo.dll + foo.dll.lib)
#   windows+gnu|mingw   -> gnu    (foo.exe / libfoo.a / foo.dll + libfoo.dll.a)
#   apple|darwin        -> macho  (foo / libfoo.a / libfoo.dylib)
#   linux|android|bsd.. -> elf    (foo / libfoo.a / libfoo.so)
# Anything else is a hard error: silently guessing "unix" would hand back a
# wrong artifact name and a mysterious later file-not-found.
function(_polyorch_rust_triple_family TRIPLE OUT)
    string(TOLOWER "${TRIPLE}" _t)
    if(_t MATCHES "windows")
        if(_t MATCHES "msvc")
            set(_family msvc)
        elseif(_t MATCHES "mingw|gnu")
            set(_family gnu)
        else()
            message(FATAL_ERROR
                "polyorch_rust: unrecognized windows triple '${TRIPLE}' (neither msvc nor gnu)")
        endif()
    elseif(_t MATCHES "darwin|apple")
        set(_family macho)
    elseif(_t MATCHES "linux|android|bsd|solaris|illumos|dragonfly|nto|qnx|haiku")
        set(_family elf)
    else()
        message(FATAL_ERROR
            "polyorch_rust: unrecognized target triple '${TRIPLE}' "
            "(expected a windows, apple/darwin or linux-style triple)")
    endif()
    set(${OUT} ${_family} PARENT_SCOPE)
endfunction()

# _polyorch_rust_artifact_names(TRIPLE <t> KIND <bin|static|shared> CRATE <name>
#                               FILE_OUT <var> [DIR_OUT <var>] [IMPLIB_OUT <var>]
#                               [PROFILE <debug|release|custom>]
#                               [BASE_DIR <path>] [OUT_BASE_DIR <var>])
# Pure naming table. FILE_OUT is the bare artifact file name; IMPLIB_OUT
# (always set, possibly empty, whenever requested) is the Windows import
# library name for a shared DLL. DIR_OUT is the ABSOLUTE directory the
# artifact lands in: <base>/<profile>, where base is BASE_DIR or the default
# ${CMAKE_BINARY_DIR}/.cargo-target. OUT_BASE_DIR receives that base.
function(_polyorch_rust_artifact_names)
    set(_one TRIPLE KIND CRATE FILE_OUT DIR_OUT IMPLIB_OUT PROFILE BASE_DIR OUT_BASE_DIR)
    cmake_parse_arguments(PARSE_ARGV 0 A "" "${_one}" "")
    if(A_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR
            "_polyorch_rust_artifact_names unknown args: ${A_UNPARSED_ARGUMENTS}")
    endif()
    _polyorch_rust_must(A_TRIPLE A_KIND A_CRATE A_FILE_OUT)
    if(NOT A_KIND MATCHES "^(bin|static|shared)$")
        message(FATAL_ERROR
            "polyorch_rust: KIND must be bin|static|shared, got '${A_KIND}'")
    endif()
    _polyorch_rust_triple_family("${A_TRIPLE}" _family)

    set(_lib "lib${A_CRATE}")
    if(_family STREQUAL "msvc")
        set(_lib "${A_CRATE}")          # MSVC names carry no lib prefix
    endif()

    set(_file "")
    set(_implib "")
    if(A_KIND STREQUAL "bin")
        if(_family MATCHES "^(msvc|gnu)$")
            set(_file "${A_CRATE}.exe")
        else()
            set(_file "${A_CRATE}")
        endif()
    elseif(A_KIND STREQUAL "static")
        if(_family STREQUAL "msvc")
            set(_file "${A_CRATE}.lib")
        else()
            set(_file "${_lib}.a")
        endif()
    else() # shared
        if(_family STREQUAL "msvc")
            set(_file "${A_CRATE}.dll")
            set(_implib "${A_CRATE}.dll.lib")
        elseif(_family STREQUAL "gnu")
            set(_file "${A_CRATE}.dll")
            set(_implib "lib${A_CRATE}.dll.a")
        elseif(_family STREQUAL "macho")
            set(_file "${_lib}.dylib")
        else()
            set(_file "${_lib}.so")
        endif()
    endif()

    set(_profile "debug")
    if(A_PROFILE STREQUAL "release")
        set(_profile release)
    elseif(A_PROFILE AND NOT A_PROFILE STREQUAL "debug")
        set(_profile "${A_PROFILE}")    # custom cargo profile -> own directory
    endif()
    set(_base "${A_BASE_DIR}")
    if(NOT _base)
        set(_base "${CMAKE_BINARY_DIR}/.cargo-target")
    endif()
    set(_dir "${_base}/${_profile}")

    set(${A_FILE_OUT} "${_file}" PARENT_SCOPE)
    if(A_DIR_OUT)
        set(${A_DIR_OUT} "${_dir}" PARENT_SCOPE)
    endif()
    if(A_IMPLIB_OUT)
        set(${A_IMPLIB_OUT} "${_implib}" PARENT_SCOPE)
    endif()
    if(A_OUT_BASE_DIR)
        set(${A_OUT_BASE_DIR} "${_base}" PARENT_SCOPE)
    endif()
endfunction()

# Internal: parse a `rustc --print=native-static-libs` transcript into the two
# link-interface lists a C consumer needs. Pure: TEXT in (the combined stdout
# + stderr of the probe), OUT_LIBS / OUT_DIRS out; it NEVER raises FATAL -- text
# without the marker simply yields empty lists.
#
# Mechanism ported from the reference's battle-tested probe parser
# (find:166-205): locate the `native-static-libs:` marker line, split it on
# whitespace, and normalise each token --
#   -l<name> / -l=<name>          -> bare <name> (CMake re-adds the -l)
#   <name>.lib (msvc)             -> suffix stripped
#   msvcrt / msvcrtd              -> dropped (the C runtime is the consumer's
#                                    choice; matches the reference filter)
#   -framework <Name>             -> merged into one '-framework <Name>' item
#                                    (kept for future darwin; NOT exercised on
#                                    this linux host -- no over-claim)
#   -L<dir> / -L <dir> / -L native=<dir> -> collected into OUT_DIRS
# Every other token (a raw linker flag, /defaultlib:, ...) is ignored: v0 only
# propagates plain system libs and search dirs. Both lists keep first-occurrence
# order and are de-duplicated.
function(_polyorch_rust_parse_native_libs TEXT OUT_LIBS OUT_DIRS)
    set(_libs "")
    set(_dirs "")
    set(_marker "")
    # CMake regex has no \r \n escapes and `foreach IN LISTS` splits on ';' not
    # newlines, so normalise line breaks to ';' and scan line by line with a
    # substring-anchored capture of everything after the marker (the whole
    # transcript carries cargo noise lines around it).
    string(REPLACE "\r" "" _txt "${TEXT}")
    string(REPLACE "\n" ";" _lines "${_txt}")
    foreach(_line IN LISTS _lines)
        if(_line MATCHES "native-static-libs:[ \t]*(.*)$")
            set(_marker "${CMAKE_MATCH_1}")
            break()
        endif()
    endforeach()
    if(_marker STREQUAL "")
        set(${OUT_LIBS} "" PARENT_SCOPE)
        set(${OUT_DIRS} "" PARENT_SCOPE)
        return()
    endif()
    string(REGEX REPLACE "[ \t]+" ";" _toks "${_marker}")
    set(_was_framework OFF)
    set(_want_dir OFF)
    foreach(_tok IN LISTS _toks)
        if(_tok STREQUAL "")
            continue()
        endif()
        if(_want_dir)
            set(_d "${_tok}")
            if(_d MATCHES "^native=(.*)$")
                set(_d "${CMAKE_MATCH_1}")
            endif()
            list(APPEND _dirs "${_d}")
            set(_want_dir OFF)
            continue()
        endif()
        if(_was_framework)
            list(APPEND _libs "-framework ${_tok}")
            set(_was_framework OFF)
            continue()
        endif()
        if(_tok STREQUAL "-framework")
            set(_was_framework ON)
            continue()
        endif()
        if(_tok STREQUAL "-L")
            set(_want_dir ON)
            continue()
        endif()
        if(_tok MATCHES "^-l=?(.+)$")
            set(_lib "${CMAKE_MATCH_1}")
            string(REGEX REPLACE "\\.lib$" "" _lib "${_lib}")
            if(NOT _lib MATCHES "^msvcrtd?$")
                list(APPEND _libs "${_lib}")
            endif()
            continue()
        endif()
        # Windows rustc emits bare '<name>.lib' (no -l): strip the suffix.
        if(_tok MATCHES "^(.+)\\.lib$")
            set(_lib "${CMAKE_MATCH_1}")
            if(NOT _lib MATCHES "^msvcrtd?$")
                list(APPEND _libs "${_lib}")
            endif()
            continue()
        endif()
        if(_tok MATCHES "^-L(.+)$")
            set(_d "${CMAKE_MATCH_1}")
            if(_d MATCHES "^native=(.*)$")
                set(_d "${CMAKE_MATCH_1}")
            endif()
            list(APPEND _dirs "${_d}")
            continue()
        endif()
    endforeach()
    list(REMOVE_DUPLICATES _libs)
    if(_dirs)
        list(REMOVE_DUPLICATES _dirs)
    endif()
    set(${OUT_LIBS} "${_libs}" PARENT_SCOPE)
    set(${OUT_DIRS} "${_dirs}" PARENT_SCOPE)
endfunction()

# Internal: one-shot probe of the system libraries a Rust staticlib needs when
# it is finally linked into a C host. Builds a throwaway zero-dependency
# staticlib in a scratch build-tree directory and asks rustc which native libs
# it pulls -- the same probe the reference ships (find:141-159). The answer is
# a property of the toolchain + target triple, not the crate, so setup runs it
# ONCE and every STATIC import shares the cached result.
#
# Failure is a WARNING with an empty result, never a FATAL (R-7): a host with
# no working cc, a no_std-only toolchain, or an exotic triple must not break
# the configure. polyorch_rust_setup(NO_NATIVE_PROBE) skips it entirely.
#
# ponytail(per-crate): the std native-static-libs set is identical for any
# crate compiled against std, so a global probe covers the common case. A crate
# whose build script links extra native libs (ring / openssl-sys style) is NOT
# captured here -- the seam is a per-target re-probe, deferred until one is
# actually needed.
function(_polyorch_rust_probe_native_libs)
    # Script mode (`cmake -P`) has no build tree: there CMAKE_BINARY_DIR is the
    # CURRENT WORKING DIRECTORY (measured on 4.4.3), so scratching the probe crate
    # there would litter the source tree. The reliable script-mode signal is
    # CMAKE_SCRIPT_MODE_FILE (the same one _polyorch_pixi_scratch keys on). A
    # script-mode configure never links artifacts, so an empty interface is correct.
    if(CMAKE_SCRIPT_MODE_FILE)
        set(POLYORCH_RUST_NATIVE_LIBS "" CACHE INTERNAL "PolyOrch rust staticlib link libs (probe)")
        set(POLYORCH_RUST_NATIVE_LIB_DIRS "" CACHE INTERNAL "PolyOrch rust staticlib link dirs (probe)")
        return()
    endif()
    set(_dir "${CMAKE_BINARY_DIR}/.polyorch-rust-probe")
    file(REMOVE_RECURSE "${_dir}")
    file(MAKE_DIRECTORY "${_dir}/src")
    file(WRITE "${_dir}/Cargo.toml" [==[
[package]
name = "polyorch_native_probe"
version = "0.0.0"
edition = "2021"

[workspace]

[lib]
crate-type = ["staticlib"]
path = "src/lib.rs"
]==])
    file(WRITE "${_dir}/src/lib.rs" [==[
pub fn add(left: usize, right: usize) -> usize { left + right }
]==])
    # --print=native-static-libs stops after codegen (no link, so no cc needed
    # for the probe itself); --target pins the host triple so the reported set
    # matches the artifacts polyorch_rust_build names. The wrapper sheds the
    # inherited compiler env exactly like every other cargo call.
    _polyorch_rust_command(_cmd SUBCOMMAND
        rustc --lib --color never --target "${POLYORCH_RUST_HOST_TARGET}"
        -- --print=native-static-libs)
    execute_process(COMMAND ${_cmd} WORKING_DIRECTORY "${_dir}"
        RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
    if(NOT _rc EQUAL 0)
        message(WARNING
            "polyorch_rust: native-static-libs probe failed (cargo rustc rc=${_rc}); "
            "STATIC imports get no system-lib link interface. Re-run with "
            "polyorch_rust_setup(NO_NATIVE_PROBE) to silence this warning.")
        set(POLYORCH_RUST_NATIVE_LIBS "" CACHE INTERNAL "PolyOrch rust staticlib link libs (probe)")
        set(POLYORCH_RUST_NATIVE_LIB_DIRS "" CACHE INTERNAL "PolyOrch rust staticlib link dirs (probe)")
        return()
    endif()
    _polyorch_rust_parse_native_libs("${_out}${_err}" _libs _dirs)
    set(POLYORCH_RUST_NATIVE_LIBS "${_libs}" CACHE INTERNAL "PolyOrch rust staticlib link libs (probe)")
    set(POLYORCH_RUST_NATIVE_LIB_DIRS "${_dirs}" CACHE INTERNAL "PolyOrch rust staticlib link dirs (probe)")
    message(STATUS "polyorch_rust: staticlib native libs [${_libs}] (dirs [${_dirs}])")
endfunction()

# _polyorch_rust_parse_toolchain_list(TEXT OUT_NAMES OUT_PATHS OUT_HOST)
# Pure parser over the `rustup toolchain list --verbose` text. Line grammar
# (adapted from corrosion (MIT, commit c4786e7): cmake/FindRust.cmake:349-359):
#   <name>[ (active)|(active, default)|(default) (override)|(default)|
#          (override)] <toolchain-root-path>
# Non-empty unparsable lines are dropped silently (this parser never raises;
# the enumeration warns when nothing survives). The last line carrying a
# default marker names OUT_HOST (the reference's last-wins loop shape,
# find:357-359). The `(override)` dir/directory-override marker is parsed but
# not acted on: PolyOrch selects via PolyOrch_RUST_TOOLCHAIN or the default
# (deviation from find:361-363, recorded in the port ledger).
function(_polyorch_rust_parse_toolchain_list TEXT OUT_NAMES OUT_PATHS OUT_HOST)
    set(_names "")
    set(_paths "")
    set(_host "")
    string(REPLACE "\r" "" _txt "${TEXT}")
    string(REPLACE "\n" ";" _lines "${_txt}")
    foreach(_line IN LISTS _lines)
        # Strip first: tolerate indented lines (the reference's unanchored
        # regex matches a name after leading whitespace the same way).
        string(STRIP "${_line}" _line)
        if(_line MATCHES "^([a-zA-Z0-9._-]+)[ \t]*(\\(active\\)|\\(active, default\\)|\\(default\\) \\(override\\)|\\(default\\)|\\(override\\))?[ \t]+(.+)$")
            # Copy the groups first: the nested MATCHES below carries its own
            # capture group and would clobber CMAKE_MATCH_1.
            set(_nm "${CMAKE_MATCH_1}")
            set(_mk "${CMAKE_MATCH_2}")
            string(STRIP "${CMAKE_MATCH_3}" _pt)
            list(APPEND _names "${_nm}")
            list(APPEND _paths "${_pt}")
            if(_mk MATCHES "\\((active, )?default\\)")
                set(_host "${_nm}")
            endif()
        endif()
    endforeach()
    set(${OUT_NAMES} "${_names}" PARENT_SCOPE)
    set(${OUT_PATHS} "${_paths}" PARENT_SCOPE)
    set(${OUT_HOST} "${_host}" PARENT_SCOPE)
endfunction()

# Internal: enumerate the rustup-installed toolchains. Adapted from corrosion
# (MIT, commit c4786e7): cmake/FindRust.cmake:336-421 (command + per-entry
# `rustc --version` probe; entries whose rustc is missing or version-
# unparseable are dropped, find:393-398, instead of the reference keeping
# parallel NOTFOUND placeholders). Side effect: writes
# POLYORCH_RUST_TOOLCHAIN_<name>_PATH / _VERSION cache entries; OUT_NAMES
# receives the kept names (parallel to the cache entries), OUT_HOST the
# default-toolchain name (empty when none carried a default marker, or when
# the default entry itself was dropped).
function(_polyorch_rust_enumerate_toolchains RUSTUP OUT_NAMES OUT_HOST)
    execute_process(COMMAND "${RUSTUP}" toolchain list --verbose
        RESULT_VARIABLE _rc OUTPUT_VARIABLE _raw ERROR_QUIET)
    if(NOT _rc EQUAL 0)
        set(_raw "")
    endif()
    _polyorch_rust_parse_toolchain_list("${_raw}" _names _paths _host)
    set(_kept "")
    list(LENGTH _names _ln)
    if(_ln GREATER 0)
        math(EXPR _last "${_ln} - 1")
        set(_exe "")
        if(CMAKE_HOST_WIN32)
            set(_exe ".exe")
        endif()
        foreach(_i RANGE 0 ${_last})
            list(GET _names ${_i} _nm)
            list(GET _paths ${_i} _pt)
            set(_rv "")
            if(EXISTS "${_pt}/bin/rustc${_exe}")
                execute_process(COMMAND "${_pt}/bin/rustc${_exe}" --version
                    RESULT_VARIABLE _rc2 OUTPUT_VARIABLE _vo ERROR_QUIET)
                if(_rc2 EQUAL 0 AND _vo MATCHES "rustc ([0-9]+)\\.([0-9]+)\\.([0-9]+)")
                    set(_rv "${CMAKE_MATCH_1}.${CMAKE_MATCH_2}.${CMAKE_MATCH_3}")
                endif()
            endif()
            if(_rv)
                list(APPEND _kept "${_nm}")
                set(POLYORCH_RUST_TOOLCHAIN_${_nm}_PATH "${_pt}"
                    CACHE INTERNAL "PolyOrch rust toolchain (polyorch_rust_setup)")
                set(POLYORCH_RUST_TOOLCHAIN_${_nm}_VERSION "${_rv}"
                    CACHE INTERNAL "PolyOrch rust toolchain (polyorch_rust_setup)")
            else()
                message(AUTHOR_WARNING
                    "polyorch_rust_setup: toolchain '${_nm}' at ${_pt} has no version-parseable "
                    "${_pt}/bin/rustc; ignoring this toolchain")
            endif()
        endforeach()
    endif()
    if(_host AND NOT _host IN_LIST _kept)
        set(_host "")
    endif()
    set(${OUT_NAMES} "${_kept}" PARENT_SCOPE)
    set(${OUT_HOST} "${_host}" PARENT_SCOPE)
endfunction()

# _polyorch_rust_derive_target(OUT)
# Selector for the cargo --target triple, shaped after the reference
# derivation chain (corr:FindRust.cmake:659-791) reduced to the two links
# that exist today: the explicit PolyOrch_RUST_CARGO_TARGET override, else
# the rustc host triple recorded by the last successful setup. WP5b seam:
# insert the Windows VS_PLATFORM/PROCESSOR/compiler-id chain and the
# Android/OHOS ABI tables between the override and the host fallback
# (reference find:662-780) -- the fallback line below consumes what they
# would set (find:781-789). Not called by setup yet: the WP2 echo wiring
# is unchanged until WP5b; shipped with its table test so the seam is
# code, not a comment.
function(_polyorch_rust_derive_target OUT)
    if(PolyOrch_RUST_CARGO_TARGET)
        set(${OUT} "${PolyOrch_RUST_CARGO_TARGET}" PARENT_SCOPE)
        return()
    endif()
    # --- WP5b insertion point: platform-derived triple chains go above ---
    set(${OUT} "${POLYORCH_RUST_HOST_TARGET}" PARENT_SCOPE)
endfunction()

# ------------------------------------------------------------------- setup ---

# polyorch_rust_setup([FROM <system|pixi>] [REQUIRED] [NO_NATIVE_PROBE])
# Locate cargo + rustc and record the result in the POLYORCH_RUST_* variables:
#   POLYORCH_RUST_FOUND        TRUE/FALSE
#   POLYORCH_RUST_CARGO        absolute path to cargo
#   POLYORCH_RUST_RUSTC        absolute path to rustc
#   POLYORCH_RUST_VERSION      "cargo --version" version token
#   POLYORCH_RUST_CARGO_VERSION  alias of POLYORCH_RUST_VERSION (the cargo
#                               tool's own version, spelling matching the
#                               reference's Rust_CARGO_VERSION)
#   POLYORCH_RUST_RUSTC_VERSION "rustc -vV" release: token (rustc's own
#                               version; may differ from cargo's in mixed
#                               toolchains)
#   POLYORCH_RUST_VERSION_MAJOR/MINOR/PATCH
#                               normalized numeric triple parsed out of the
#                               rustc release token (suffixes like -nightly
#                               dropped) -- what the version comparisons
#                               below operate on; empty when the release
#                               token carries no numeric triple
#   POLYORCH_RUST_HOST_TARGET  `rustc -vV` host triple (artifact naming key)
#   POLYORCH_RUST_ROUTE        system | pixi (drives the PATH wrapper)
#   POLYORCH_RUST_BIN_DIR      directory holding the cargo binary
#   POLYORCH_RUST_CARGO_TARGET the --target triple selected for the build
#                              (echo of PolyOrch_RUST_CARGO_TARGET; empty =
#                              host default -- routing not implemented, WP5)
#   POLYORCH_RUST_TOOLCHAINS   names of the toolchains the resolved rustup
#                              install exposes, or the single entry `direct`
#                              when no rustup was involved; per toolchain,
#                              POLYORCH_RUST_TOOLCHAIN_<name>_PATH and _VERSION
#                              cache entries carry the data; the rustup
#                              default's name is POLYORCH_RUST_TOOLCHAIN_HOST
#                              (also `direct` in a non-rustup world)
# In PROJECT mode a successful setup also (re)creates the imported
# executable handles PolyOrchRust::Rustc / PolyOrchRust::Cargo carrying
# these binaries (re-setup replaces the IMPORTED_LOCATION; skipped under
# cmake -P, where add_executable is not scriptable).
# When the toolchain is found, setup also runs a one-shot native-static-libs
# probe (a throwaway staticlib + `rustc --print=native-static-libs`) that fills
#   POLYORCH_RUST_NATIVE_LIBS  system libs a Rust staticlib needs at final link
#   POLYORCH_RUST_NATIVE_LIB_DIRS  -L search dirs from the same probe
# which polyorch_rust_build(STATIC) attaches as the import's link interface. The
# probe is a WARNING with empty lists on failure (never a FATAL); skip it with
# NO_NATIVE_PROBE.
# FROM defaults to the PolyOrch_RUST_FROM cache value, then to "system".
# Injection pair: PolyOrch_RUST_CARGO_EXECUTABLE / PolyOrch_RUSTC_EXECUTABLE
# (cache string/filepath) are honored FIRST on either route -- when set they
# replace the route's find_program for that tool, and a set-but-nonexistent
# value is a FATAL regardless of REQUIRED (invariant 5: a suspicious
# toolchain source fails hard). An unset pair member falls back to the
# normal route search; the injection never changes POLYORCH_RUST_ROUTE --
# the route still selects the env-wrapper semantics. Reference equivalent:
# the user-var promotion in corr:FindRust.cmake:324-332 (naming-map row in
# docs/reference/corrosion-port-ledger.md).
# PolyOrch_RUST_CARGO_TARGET (cache string) selects the cargo --target
# triple; as of WP2 it is only defined + echoed into
# POLYORCH_RUST_CARGO_TARGET (a STATUS line when non-empty says routing is
# NOT implemented yet -- WP5 consumes it; empty = build for the host).
# PolyOrch_RUST_MIN_VERSION (cache string) floors the rustc version: empty
# (default) enforces nothing -- measured-only floors stay the rule (the
# deferred register stands); when set, a toolchain below the floor is a MISS
# (FOUND=FALSE, or a FATAL naming found-vs-required with REQUIRED).
# Reference equivalent: the find_package version predicate applied during
# toolchain selection (corr:FindRust.cmake:38-71,439-463).
# PolyOrch_RUST_TOOLCHAIN (cache string) pins a rustup toolchain by name:
# exact match first, else the bare family retried as `<name>-<default host>`
# via `rustup show`; an unknown name FATALs listing the available toolchains
# (find:472-503 shape). When UNSET: a PATH-discovered rustc that answers the
# RUSTUP_FORCE_ARG0=rustup proxy tell is descended into -- rustup beside it
# resolves the DEFAULT toolchain to its concrete binaries (the reference's
# contract: never hand back a proxy, find:7-9); a non-proxy rustc is used as
# found, with NO rustup required (conda/pixi shape). The injection pair
# outranks this knob per tool (WP2 contract preserved).
# A miss without REQUIRED sets FOUND=FALSE and reports by STATUS only;
# with REQUIRED it fails with the fix for that route. The pixi route first
# requires the pixi side to be set up -- its error message names
# polyorch_pixi_setup() (raised inside polyorch_pixi_env_paths()).
function(polyorch_rust_setup)
    set(_opts REQUIRED NO_NATIVE_PROBE)
    set(_one FROM)
    cmake_parse_arguments(PARSE_ARGV 0 S "${_opts}" "${_one}" "")
    if(S_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "polyorch_rust_setup: unknown args: ${S_UNPARSED_ARGUMENTS}")
    endif()

    set(_from "${S_FROM}")
    if(NOT _from)
        set(_from "${PolyOrch_RUST_FROM}")
    endif()
    if(NOT _from)
        set(_from system)
    endif()
    if(NOT _from MATCHES "^(system|pixi)$")
        message(FATAL_ERROR
            "polyorch_rust_setup: FROM must be system or pixi, got '${_from}'")
    endif()

    # Drop the previous run's per-toolchain cache entries here (before the
    # enumeration below writes fresh ones): the shared clear further down
    # must not race entries a re-run of the same name just re-probed.
    foreach(_old IN LISTS POLYORCH_RUST_TOOLCHAINS)
        unset(POLYORCH_RUST_TOOLCHAIN_${_old}_PATH CACHE)
        unset(POLYORCH_RUST_TOOLCHAIN_${_old}_VERSION CACHE)
    endforeach()
    # Injection first (see the contract above): validate, then bypass the
    # route's find_program per tool. EXISTS only -- the same standard the
    # reference's user vars use; an unreadable-but-present path surfaces as
    # a version-probe miss, not as a mysterious FATAL here.
    set(_inj_cargo "${PolyOrch_RUST_CARGO_EXECUTABLE}")
    set(_inj_rustc "${PolyOrch_RUSTC_EXECUTABLE}")
    _polyorch_rust_check_injected(CARGO "${_inj_cargo}")
    _polyorch_rust_check_injected(RUSTC "${_inj_rustc}")

    set(_miss "")
    if(_from STREQUAL "system")
        if(_inj_cargo)
            set(_cargo "${_inj_cargo}")
        else()
            find_program(_cargo NAMES cargo NO_CACHE)
        endif()
        if(_inj_rustc)
            set(_rustc "${_inj_rustc}")
        else()
            find_program(_rustc NAMES rustc NO_CACHE)
        endif()
        if(NOT _cargo OR NOT _rustc)
            set(_miss "no cargo/rustc on PATH")
        endif()

        # ---- rustup layer (WP3) ------------------------------------------------
        # Two doors into rustup (reference shape find:237-321): the explicit
        # PolyOrch_RUST_TOOLCHAIN knob looks for rustup first; otherwise a
        # PATH-discovered rustc is proxy-tested and rustup is adopted only when
        # it sits beside the proxy. Injection bypasses the proxy test entirely:
        # the WP2 injection contract keeps the given path verbatim (deviation
        # from find:296-307, which discards a proxy-pointing user compiler --
        # recorded in the port ledger). A non-proxy toolchain needs NO rustup:
        # the conda/pixi shape stays fully functional on this branch.
        set(_tc_names "")
        set(_tc_host "")
        # Landmine (measured on 4.4.3): find_program(<v> ... NO_CACHE) SKIPS the
        # search and leaves <v> untouched when <v> already exists as a regular
        # variable in scope -- even when it was pre-set empty. Every
        # NO_CACHE find below therefore writes a never-set result variable
        # and the value is copied into the flow variable afterwards.
        set(_rustup "")
        if(PolyOrch_RUST_TOOLCHAIN)
            find_program(_rup_a NAMES rustup NO_CACHE)
            set(_rustup "${_rup_a}")
            if(NOT _rustup)
                message(WARNING
                    "polyorch_rust_setup: PolyOrch_RUST_TOOLCHAIN='${PolyOrch_RUST_TOOLCHAIN}' "
                    "requested but rustup was not found; resolving without rustup")
            endif()
        elseif(_rustc AND NOT _inj_rustc)
            # The canonical proxy tell (adapted from find:279-312): rustup's
            # proxies are rustup under another argv[0], and RUSTUP_FORCE_ARG0
            # forces the tool identity -- a proxy answers --version as rustup,
            # a real toolchain answers as itself. Verified against rustup's
            # behavior on the validation host, not copied from docs.
            execute_process(
                COMMAND ${CMAKE_COMMAND} -E env RUSTUP_FORCE_ARG0=rustup
                    "${_rustc}" --version
                RESULT_VARIABLE _prc OUTPUT_VARIABLE _ppv ERROR_QUIET)
            if(_prc EQUAL 0 AND _ppv MATCHES "rustup ([0-9]|$)")
                get_filename_component(_proxdir "${_rustc}" DIRECTORY)
                find_program(_rup_b NAMES rustup HINTS "${_proxdir}" NO_DEFAULT_PATH NO_CACHE)
                set(_rustup "${_rup_b}")
                if(NOT _rustup)
                    message(WARNING
                        "polyorch_rust_setup: '${_rustc}' is a rustup proxy but no rustup "
                        "sits beside it; using the proxy binary directly")
                endif()
            endif()
        endif()
        if(_rustup)
            _polyorch_rust_enumerate_toolchains("${_rustup}" _tc_names _tc_host)
            if(_tc_names STREQUAL "")
                message(WARNING
                    "polyorch_rust_setup: `${_rustup} toolchain list --verbose` yielded no "
                    "usable toolchains; falling back to the discovered binaries")
                if(PolyOrch_RUST_TOOLCHAIN)
                    message(FATAL_ERROR
                        "polyorch_rust_setup: no usable rustup toolchain found for the "
                        "requested '${PolyOrch_RUST_TOOLCHAIN}'")
                endif()
                set(_rustup "")
            else()
                # Selection: the knob wins over the rustup default; an exact
                # miss is retried as `<knob>-<default host>` (rustup show
                # expansion, find:472-503) before the FATAL that lists what IS
                # available. Without the knob: the default, else the first
                # kept entry (a lone manually-linked toolchain prints no marker).
                set(_sel "")
                if(PolyOrch_RUST_TOOLCHAIN)
                    set(_want "${PolyOrch_RUST_TOOLCHAIN}")
                    if(NOT _want IN_LIST _tc_names)
                        execute_process(COMMAND "${_rustup}" show
                            RESULT_VARIABLE _sres OUTPUT_VARIABLE _sraw ERROR_QUIET)
                        if(NOT _sres EQUAL 0)
                            message(FATAL_ERROR
                                "polyorch_rust_setup: `${_rustup} show` failed (needed to expand "
                                "toolchain '${_want}' to its host form)")
                        endif()
                        set(_defhost "")
                        string(REPLACE "\r" "" _sraw "${_sraw}")
                        string(REPLACE "\n" ";" _slines "${_sraw}")
                        foreach(_sl IN LISTS _slines)
                            if(_sl MATCHES "^Default host: *([^ ]+)")
                                set(_defhost "${CMAKE_MATCH_1}")
                            endif()
                        endforeach()
                        if(NOT _defhost)
                            message(FATAL_ERROR
                                "polyorch_rust_setup: could not parse \"Default host\" from "
                                "`${_rustup} show` output")
                        endif()
                        if("${_want}-${_defhost}" IN_LIST _tc_names)
                            set(_want "${_want}-${_defhost}")
                        endif()
                    endif()
                    if(NOT _want IN_LIST _tc_names)
                        set(_avail "")
                        foreach(_t IN LISTS _tc_names)
                            string(APPEND _avail "  ${_t}\n")
                        endforeach()
                        message(FATAL_ERROR
                            "polyorch_rust_setup: Could not find toolchain '${PolyOrch_RUST_TOOLCHAIN}'. Available toolchains:\n${_avail}")
                    endif()
                    set(_sel "${_want}")
                elseif(_tc_host)
                    set(_sel "${_tc_host}")
                else()
                    list(GET _tc_names 0 _sel)
                endif()
                set(_tcbin "${POLYORCH_RUST_TOOLCHAIN_${_sel}_PATH}/bin")
                if(NOT _inj_rustc)
                    find_program(_res_r NAMES rustc HINTS "${_tcbin}" NO_DEFAULT_PATH NO_CACHE)
                    set(_rustc "${_res_r}")
                endif()
                if(NOT _inj_cargo)
                    find_program(_res_c NAMES cargo HINTS "${_tcbin}" NO_DEFAULT_PATH NO_CACHE)
                    set(_cargo "${_res_c}")
                endif()
                if(_cargo AND _rustc)
                    set(_miss "")
                else()
                    set(_miss "rustup toolchain '${_sel}' at ${_tcbin} ships no cargo/rustc (fix: set PolyOrch_RUST_CARGO_EXECUTABLE / PolyOrch_RUSTC_EXECUTABLE explicitly)")
                endif()
            endif()
        endif()
    else()
        if(NOT COMMAND polyorch_pixi_env_paths)
            message(FATAL_ERROR
                "polyorch_rust_setup(FROM pixi): PolyOrchPixiHelpers is not included; "
                "include(PolyOrchPixiHelpers), call polyorch_pixi_setup(), then retry")
        endif()
        # FATALs with "call polyorch_pixi_setup() first" when pixi lacks context.
        polyorch_pixi_env_paths(PREFIX_OUT _pixi_prefix BIN_OUT _pixi_bin)
        # conda layouts move executables per platform; search every bin dir.
        set(_pixi_dirs "${_pixi_bin}" "${_pixi_prefix}/Library/bin"
                       "${_pixi_prefix}/Scripts" "${_pixi_prefix}/bin")
        if(_inj_cargo)
            set(_cargo "${_inj_cargo}")
        else()
            find_program(_cargo NAMES cargo PATHS ${_pixi_dirs} NO_DEFAULT_PATH NO_CACHE)
        endif()
        if(_inj_rustc)
            set(_rustc "${_inj_rustc}")
        else()
            find_program(_rustc NAMES rustc PATHS ${_pixi_dirs} NO_DEFAULT_PATH NO_CACHE)
        endif()
        if(NOT _cargo OR NOT _rustc)
            set(_miss "pixi environment has no cargo/rustc (fix: polyorch_pixi_environment_add(TOOLS rust))")
        endif()
    endif()

    set(_version "")
    set(_rustc_version "")
    set(_host "")
    set(_probe_ok FALSE)
    if(_cargo AND _rustc)
        execute_process(COMMAND "${_rustc}" -vV
            RESULT_VARIABLE _rc OUTPUT_VARIABLE _vout ERROR_QUIET
            OUTPUT_STRIP_TRAILING_WHITESPACE)
        if(_rc EQUAL 0)
            # CMake has no \r \n regex escapes and no POSIX classes: match the
            # per-line form (^...$ anchors bind to each string-FOREACH line).
            # CMake regex has no \r \n escapes, and `foreach IN LISTS` splits on
            # ';' (not newlines), so convert line breaks to list separators first,
            # then match each line with the ^...$-anchored form.
            string(REPLACE "\r" "" _vout "${_vout}")
            string(REPLACE "\n" ";" _vlines "${_vout}")
            foreach(_vline IN LISTS _vlines)
                if(_vline MATCHES "^host: *([^ ]+)$")
                    set(_host "${CMAKE_MATCH_1}")
                elseif(_vline MATCHES "^release: *([^ ]+)$")
                    set(_rustc_version "${CMAKE_MATCH_1}")
                endif()
            endforeach()
        endif()
        execute_process(COMMAND "${_cargo}" --version
            RESULT_VARIABLE _rc OUTPUT_VARIABLE _cout ERROR_QUIET
            OUTPUT_STRIP_TRAILING_WHITESPACE)
        if(_rc EQUAL 0)
            string(REGEX MATCH "cargo [ ]*([^ ]+)" _m "${_cout}")
            set(_version "${CMAKE_MATCH_1}")
        endif()
        if(_host AND _version)
            set(_probe_ok TRUE)
        else()
            set(_miss "cargo/rustc located but their version probes failed (${_cargo})")
        endif()
    endif()

    set(_found FALSE)
    set(_rv_major "")
    set(_rv_minor "")
    set(_rv_patch "")
    set(_rv_norm "")
    if(_probe_ok)
        # Normalized triple from the rustc release token (the reference parses
        # the same out of `rustc --version --verbose`, find:620-624); suffixes
        # like 1.99.0-nightly normalize to 1.99.0 for comparison.
        if(_rustc_version MATCHES "^([0-9]+)\\.([0-9]+)\\.([0-9]+)")
            set(_rv_major "${CMAKE_MATCH_1}")
            set(_rv_minor "${CMAKE_MATCH_2}")
            set(_rv_patch "${CMAKE_MATCH_3}")
            set(_rv_norm "${_rv_major}.${_rv_minor}.${_rv_patch}")
        endif()
        if(PolyOrch_RUST_MIN_VERSION)
            polyorch_rust_version_ok("${_rv_norm}" _floor_ok
                VERSION "${PolyOrch_RUST_MIN_VERSION}")
            if(NOT _floor_ok)
                if(_rv_norm)
                    set(_miss "PolyOrch_RUST_MIN_VERSION requires rustc at least ${PolyOrch_RUST_MIN_VERSION}, found rustc ${_rustc_version}")
                else()
                    set(_miss "PolyOrch_RUST_MIN_VERSION requires rustc at least ${PolyOrch_RUST_MIN_VERSION}, but rustc version '${_rustc_version}' has no numeric triple")
                endif()
                set(_probe_ok FALSE)
            endif()
        endif()
    endif()
    if(_probe_ok)
        set(_found TRUE)
    endif()
    # FORCE not needed: re-setting a CACHE INTERNAL variable of the same type
    # does not overwrite, so clear first -- a miss after a hit must not leave
    # stale paths behind.
    foreach(_v POLYORCH_RUST_FOUND POLYORCH_RUST_CARGO POLYORCH_RUST_RUSTC
               POLYORCH_RUST_VERSION POLYORCH_RUST_RUSTC_VERSION
               POLYORCH_RUST_CARGO_VERSION
               POLYORCH_RUST_VERSION_MAJOR POLYORCH_RUST_VERSION_MINOR
               POLYORCH_RUST_VERSION_PATCH
               POLYORCH_RUST_HOST_TARGET
               POLYORCH_RUST_ROUTE POLYORCH_RUST_BIN_DIR
               POLYORCH_RUST_CARGO_TARGET POLYORCH_RUST_TOOLCHAINS
               POLYORCH_RUST_TOOLCHAIN_HOST)
        unset(${_v} CACHE)
    endforeach()
    # Probe results are cleared here so a configure that never reaches the probe
    # (opt-out, or a miss after a hit) can never leave a stale list behind for
    # polyorch_rust_build to attach.
    unset(POLYORCH_RUST_NATIVE_LIBS CACHE)
    unset(POLYORCH_RUST_NATIVE_LIB_DIRS CACHE)
    set(POLYORCH_RUST_FOUND ${_found} CACHE INTERNAL "PolyOrch rust toolchain (polyorch_rust_setup)")
    if(_found)
        get_filename_component(_bindir "${_cargo}" DIRECTORY)
        set(POLYORCH_RUST_CARGO "${_cargo}" CACHE INTERNAL "PolyOrch rust toolchain (polyorch_rust_setup)")
        set(POLYORCH_RUST_RUSTC "${_rustc}" CACHE INTERNAL "PolyOrch rust toolchain (polyorch_rust_setup)")
        set(POLYORCH_RUST_VERSION "${_version}" CACHE INTERNAL "PolyOrch rust toolchain (polyorch_rust_setup)")
        set(POLYORCH_RUST_RUSTC_VERSION "${_rustc_version}" CACHE INTERNAL "PolyOrch rust toolchain (polyorch_rust_setup)")
        set(POLYORCH_RUST_CARGO_VERSION "${_version}" CACHE INTERNAL "PolyOrch rust toolchain (polyorch_rust_setup)")
        set(POLYORCH_RUST_VERSION_MAJOR "${_rv_major}" CACHE INTERNAL "PolyOrch rust toolchain (polyorch_rust_setup)")
        set(POLYORCH_RUST_VERSION_MINOR "${_rv_minor}" CACHE INTERNAL "PolyOrch rust toolchain (polyorch_rust_setup)")
        set(POLYORCH_RUST_VERSION_PATCH "${_rv_patch}" CACHE INTERNAL "PolyOrch rust toolchain (polyorch_rust_setup)")
        set(POLYORCH_RUST_HOST_TARGET "${_host}" CACHE INTERNAL "PolyOrch rust toolchain (polyorch_rust_setup)")
        set(POLYORCH_RUST_ROUTE "${_from}" CACHE INTERNAL "PolyOrch rust toolchain (polyorch_rust_setup)")
        set(POLYORCH_RUST_BIN_DIR "${_bindir}" CACHE INTERNAL "PolyOrch rust toolchain (polyorch_rust_setup)")
        if(_tc_names)
            set(POLYORCH_RUST_TOOLCHAINS "${_tc_names}" CACHE INTERNAL "PolyOrch rust toolchain (polyorch_rust_setup)")
            set(POLYORCH_RUST_TOOLCHAIN_HOST "${_tc_host}" CACHE INTERNAL "PolyOrch rust toolchain (polyorch_rust_setup)")
        else()
            # Direct single-entry record: the toolchain root is two levels
            # above <root>/bin/rustc (find:526-530 shape); no rustup consulted.
            set(POLYORCH_RUST_TOOLCHAINS "direct" CACHE INTERNAL "PolyOrch rust toolchain (polyorch_rust_setup)")
            set(POLYORCH_RUST_TOOLCHAIN_HOST "direct" CACHE INTERNAL "PolyOrch rust toolchain (polyorch_rust_setup)")
            get_filename_component(_droot "${_rustc}" DIRECTORY)
            get_filename_component(_droot "${_droot}" DIRECTORY)
            set(POLYORCH_RUST_TOOLCHAIN_direct_PATH "${_droot}" CACHE INTERNAL "PolyOrch rust toolchain (polyorch_rust_setup)")
            set(POLYORCH_RUST_TOOLCHAIN_direct_VERSION "${_rv_norm}" CACHE INTERNAL "PolyOrch rust toolchain (polyorch_rust_setup)")
        endif()
        # Imported tool handles for consumers (custom commands, dependency
        # edges): PolyOrchRust::Rustc / PolyOrchRust::Cargo carry the resolved
        # binaries (reference find:902-915). Re-setup REPLACES the locations:
        # the reference's if(NOT TARGET) guard alone would pin the first pair
        # forever across a re-run with different knobs, so the property is
        # updated every time and the if(NOT TARGET) around the add only
        # prevents the duplicate-name error. Script mode has no target
        # registry consumer and add_executable is not scriptable there
        # (measured on 4.4.3), so creation is skipped exactly like the
        # native-libs probe skips it.
        if(NOT CMAKE_SCRIPT_MODE_FILE)
            if(NOT TARGET PolyOrchRust::Rustc)
                add_executable(PolyOrchRust::Rustc IMPORTED GLOBAL)
            endif()
            set_property(TARGET PolyOrchRust::Rustc PROPERTY IMPORTED_LOCATION "${_rustc}")
            if(NOT TARGET PolyOrchRust::Cargo)
                add_executable(PolyOrchRust::Cargo IMPORTED GLOBAL)
            endif()
            set_property(TARGET PolyOrchRust::Cargo PROPERTY IMPORTED_LOCATION "${_cargo}")
        endif()
        # WP2 echo-only (ponytail: consumed by the WP5 cross-routing cluster;
        # until then nothing passes --target, so a non-empty value is inert).
        set(POLYORCH_RUST_CARGO_TARGET "${PolyOrch_RUST_CARGO_TARGET}" CACHE INTERNAL "PolyOrch rust toolchain (polyorch_rust_setup)")
        message(STATUS "polyorch_rust: cargo ${_version} (host ${_host}, from ${_from})")
        if(POLYORCH_RUST_CARGO_TARGET)
            message(STATUS "polyorch_rust: PolyOrch_RUST_CARGO_TARGET="
                "${POLYORCH_RUST_CARGO_TARGET} recorded but --target routing is "
                "not implemented yet (WP5); the build stays on the host target")
        endif()
        if(S_NO_NATIVE_PROBE)
            message(STATUS "polyorch_rust: native-static-libs probe skipped (NO_NATIVE_PROBE)")
        else()
            _polyorch_rust_probe_native_libs()
        endif()
    else()
        if(S_REQUIRED)
            message(FATAL_ERROR
                "polyorch_rust_setup(FROM ${_from}) REQUIRED: ${_miss}")
        endif()
        message(STATUS "polyorch_rust: not found (${_miss}); POLYORCH_RUST_FOUND=FALSE")
    endif()
endfunction()

function(_polyorch_rust_command CMD_OUT)
    cmake_parse_arguments(PARSE_ARGV 1 R "" "" "SUBCOMMAND;ENV")
    if(R_SUBCOMMAND)
        set(_tail "${R_SUBCOMMAND}")
    else()
        set(_tail "")
    endif()
    set(_strip
        --unset=RUSTFLAGS
        --unset=CARGO_ENCODED_RUSTFLAGS
        --unset=CFLAGS
        --unset=CXXFLAGS
        --unset=CC
        --unset=CXX)
    if(POLYORCH_RUST_ROUTE STREQUAL "pixi")
        if(WIN32)
            set(_sep ";")
        else()
            set(_sep ":")
        endif()
        set(_path "PATH=${POLYORCH_RUST_BIN_DIR}${_sep}$ENV{PATH}")
        string(REPLACE ";" "\\;" _path "${_path}")
        set(_cmd ${CMAKE_COMMAND} -E env ${_strip} "${_path}" ${R_ENV} "${POLYORCH_RUST_CARGO}" ${_tail})
    else()
        set(_cmd ${CMAKE_COMMAND} -E env ${_strip} ${R_ENV} "${POLYORCH_RUST_CARGO}" ${_tail})
    endif()
    set(${CMD_OUT} "${_cmd}" PARENT_SCOPE)
endfunction()

# polyorch_rust_build(TARGET <n> PACKAGE <p> CRATE <c>
#                     [BINARY|STATIC|SHARED] [PROFILE <p>] [FEATURES a;b]
#                     [LOCKED|FROZEN] [MANIFEST <path>] [DEPENDS <t>...]
#                     [BASE_DIR <td>] [FOLDER <ide>] [PREBUILD <t>])
# Registers <TARGET> as an IMPORTED target pointing at the cargo artifact
# built into ${CMAKE_BINARY_DIR}/.cargo-target/<profile>/, plus the
# cargo-build-<TARGET> custom mediator that owns the rule. Linking <TARGET>
# suffices: the auto-build edge propagates the mediator ordering to every
# consumer. The legacy <TARGET>-cargo name is a compatibility shim. A bare
# cmake --build reaches the artifacts through the polyorch-rust-all
# aggregate target; the mediators themselves are deliberately NOT ALL.
# DEPENDS is deprecated -- superseded by the auto-build edge.
# Without PROFILE the cargo profile follows CMAKE_BUILD_TYPE at configure
# time: unset or Debug -> debug, any other value -> release (an explicit
# PROFILE always wins). MANIFEST doubles as the rule's file dependency.
# BASE_DIR relocates the cargo target dir (pixi ENVIRONMENTS_DIR-style
# redirects); test and clean accept the same keyword, so the trio always agrees.
