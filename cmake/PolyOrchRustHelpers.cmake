# PolyOrch Rust helpers -- cargo/rustc toolchain selection and build wrappers.
#
# This module drives an existing cargo installation; it never installs Rust.
# Two routes locate the toolchain (polyorch_rust_setup):
#   system : cargo/rustc on PATH (find_program)
#   pixi   : cargo/rustc inside a pixi environment, resolved through
#            polyorch_pixi_env_paths() from PolyOrchPixiHelpers.cmake (the
#            caller must include that module and set up pixi first)
#
# Artifacts are named by the target triple's object family (msvc / gnu /
# macho / elf), never by the host: the same table serves host builds and
# (later) cross builds. Libraries enter the build tree as IMPORTED targets
# backed by the cargo-build-<TARGET> mediator custom target; an auto-build
# edge (add_dependencies on the IMPORTED target, propagated to its linkers)
# makes every consumer order the mediator before linking.
# The legacy <TARGET>-cargo name survives as a compatibility shim target.
# Build inputs (profile, features, flags, env) live in POLYORCH_RUST_*
# properties of the mediator and expand in the rule at generate time; the
# polyorch_rust_set_features / set_env_vars / add_cargo_flags / add_rustflags
# setters mutate them after polyorch_rust_build() took effect, keyed by the
# declared TARGET name (set_ functions replace, add_ functions append).
# polyorch_rust_import() batch-imports a whole cargo workspace from
# `cargo metadata` (one build wrapper per importable target, plus the
# IMPORTED_TARGETS registry). Naming: lib handles carry underscores, bin
# handles the suffix "-exe", a staticlib+cdylib target the pair
# "-static"/"-shared" -- rules + gen: citations in the import section below.
# polyorch_rust_install() stages built artifacts (bin/ + lib/) and can emit
# a <name>-rust.cmake replay stub for second-stage C consumers; the
# [PREBUILD <t>] keyword on polyorch_rust_build names an explicit
# user-owned target to run before cargo.
#
# All cargo invocations share one isolated target directory,
# ${CMAKE_BINARY_DIR}/.cargo-target, so polyorch_rust_clean() is a plain
# directory removal and never needs a working cargo.
#
# Result variables of polyorch_rust_setup are the POLYORCH_RUST_* set
# (documented exception to the brand-casing rule, see decisions.md D11);
# cache knobs are PolyOrch_RUST_* (incl. the executable-injection pair
# PolyOrch_RUST_CARGO_EXECUTABLE / PolyOrch_RUSTC_EXECUTABLE and the
# PolyOrch_RUST_CARGO_TARGET triple selector, see polyorch_rust_setup);
# public functions are polyorch_rust_*.
#
# Out of scope by design (add a `ponytail:` note at the seam when needed):
# --target cross-compilation triples, rust-version enforcement, cargo
# bench/fmt/clippy wrappers, and the
# multi-config per-<CONFIG> artifact staging/copy strategy (multi-config
# generators resolve to the debug profile today).
#
# Include-time contract: zero side effects -- definitions and comments only.
# Requires CMake >= 3.25 (PARSE_ARGV, NO_CACHE find_program, cmake_path).

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

# ------------------------------------------------------------------- setup ---

# polyorch_rust_setup([FROM <system|pixi>] [REQUIRED] [NO_NATIVE_PROBE])
# Locate cargo + rustc and record the result in the POLYORCH_RUST_* variables:
#   POLYORCH_RUST_FOUND        TRUE/FALSE
#   POLYORCH_RUST_CARGO        absolute path to cargo
#   POLYORCH_RUST_RUSTC        absolute path to rustc
#   POLYORCH_RUST_VERSION      "cargo --version" version token
#   POLYORCH_RUST_RUSTC_VERSION "rustc -vV" release: token (rustc's own
#                               version; may differ from cargo's in mixed
#                               toolchains)
#   POLYORCH_RUST_HOST_TARGET  `rustc -vV` host triple (artifact naming key)
#   POLYORCH_RUST_ROUTE        system | pixi (drives the PATH wrapper)
#   POLYORCH_RUST_BIN_DIR      directory holding the cargo binary
#   POLYORCH_RUST_CARGO_TARGET the --target triple selected for the build
#                              (echo of PolyOrch_RUST_CARGO_TARGET; empty =
#                              host default -- routing not implemented, WP5)
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
    if(_probe_ok)
        set(_found TRUE)
    endif()
    # FORCE not needed: re-setting a CACHE INTERNAL variable of the same type
    # does not overwrite, so clear first -- a miss after a hit must not leave
    # stale paths behind.
    foreach(_v POLYORCH_RUST_FOUND POLYORCH_RUST_CARGO POLYORCH_RUST_RUSTC
               POLYORCH_RUST_VERSION POLYORCH_RUST_RUSTC_VERSION
               POLYORCH_RUST_HOST_TARGET
               POLYORCH_RUST_ROUTE POLYORCH_RUST_BIN_DIR
               POLYORCH_RUST_CARGO_TARGET)
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
        set(POLYORCH_RUST_HOST_TARGET "${_host}" CACHE INTERNAL "PolyOrch rust toolchain (polyorch_rust_setup)")
        set(POLYORCH_RUST_ROUTE "${_from}" CACHE INTERNAL "PolyOrch rust toolchain (polyorch_rust_setup)")
        set(POLYORCH_RUST_BIN_DIR "${_bindir}" CACHE INTERNAL "PolyOrch rust toolchain (polyorch_rust_setup)")
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

# ------------------------------------------------------------------- build ---

# Internal: argv builder for `cargo build` (pure, no side effects).
# _polyorch_rust_cargo_args(PACKAGE <p> [KIND <bin|static|shared>] [CRATE <c>]
#                           [PROFILE <debug|release|custom>] [FEATURES a;b]
#                           [LOCKED] [FROZEN] [MANIFEST <path>] ARGO_OUT <var>)
# ARGO_OUT (keyword spelling frozen with the contract) receives:
#   build --package P [--manifest-path M] [--release|--profile X]
#         [--features a,b] [--bin C] [--locked|--frozen]
# --target-dir is NOT included: it names a build-tree path, so the caller
# appends it; this function stays pure.
function(_polyorch_rust_cargo_args)
    set(_opts LOCKED FROZEN)
    set(_one PACKAGE KIND CRATE PROFILE MANIFEST ARGO_OUT)
    set(_multi FEATURES)
    cmake_parse_arguments(PARSE_ARGV 0 C "${_opts}" "${_one}" "${_multi}")
    if(C_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR
            "_polyorch_rust_cargo_args unknown args: ${C_UNPARSED_ARGUMENTS}")
    endif()
    _polyorch_rust_must(C_PACKAGE C_ARGO_OUT)
    if(C_LOCKED AND C_FROZEN)
        message(FATAL_ERROR
            "_polyorch_rust_cargo_args: LOCKED and FROZEN are mutually exclusive")
    endif()
    if(C_KIND AND NOT C_KIND MATCHES "^(bin|static|shared)$")
        message(FATAL_ERROR
            "polyorch_rust: KIND must be bin|static|shared, got '${C_KIND}'")
    endif()
    if(C_KIND STREQUAL "bin" AND NOT C_CRATE)
        message(FATAL_ERROR
            "_polyorch_rust_cargo_args: KIND bin needs CRATE for --bin")
    endif()

    set(_argv build --package "${C_PACKAGE}")
    if(C_MANIFEST)
        list(APPEND _argv --manifest-path "${C_MANIFEST}")
    endif()
    if(C_PROFILE STREQUAL "release")
        list(APPEND _argv --release)
    elseif(C_PROFILE AND NOT C_PROFILE STREQUAL "debug")
        list(APPEND _argv --profile "${C_PROFILE}")
    endif()
    if(C_FEATURES)
        list(JOIN C_FEATURES "," _joined)
        list(APPEND _argv --features "${_joined}")
    endif()
    if(C_KIND STREQUAL "bin")
        list(APPEND _argv --bin "${C_CRATE}")
    endif()
    if(C_LOCKED)
        list(APPEND _argv --locked)
    elseif(C_FROZEN)
        list(APPEND _argv --frozen)
    endif()
    set(${C_ARGO_OUT} "${_argv}" PARENT_SCOPE)
endfunction()

# Internal: guard shared by every build-graph wrapper. Deliberately reads the
# variables (not COMMAND-era state) so a scratch run can inject them with -D.
function(_polyorch_rust_require_setup CALLER)
    if(NOT POLYORCH_RUST_FOUND OR NOT POLYORCH_RUST_CARGO OR
       NOT POLYORCH_RUST_HOST_TARGET)
        message(FATAL_ERROR
            "${CALLER}: call polyorch_rust_setup first (POLYORCH_RUST_FOUND "
            "is not TRUE; nothing is located yet)")
    endif()
endfunction()

# Internal: the one command line every wrapper shells out to. EVERY cargo
# invocation is prefixed by `cmake -E env` with the host-leak strip below --
# including the plain system route, so the former bare-cargo fast path is
# gone (the strip is the point; a raw invocation inherits the caller's
# compiler environment). With the pixi route PATH=<bin_dir>;<host PATH>
# rides the same prefix so the toolchain resolves its siblings; semicolons
# are escaped because a custom command re-splits list elements on them at
# generate time. ENV entries (KEY=VAL elements; generator-expression strings
# welcome) ride the prefix too.
#
# PIT-14 host-leak isolation. A conda/pixi-activated or gcc-wrapping shell
# leaks compiler-shaping variables into CMAKE's environment, and an
# unwrapped cargo inherits them: RUSTFLAGS / CARGO_ENCODED_RUSTFLAGS reach
# rustc for every crate (the measured -mcet host leak of PIT-14), and
# CFLAGS / CXXFLAGS / CC / CXX reach the cc-rs build scripts of any C
# dependency (ring, openssl-sys style), silently compiling C code with the
# host activation's flags or picking the host's chosen compilers. AR,
# RANLIB and PKG_CONFIG_* are deliberately NOT stripped: no measured leak,
# and an over-wide strip silently drops deliberate host choices -- widen
# only on evidence.
# Every variable in the strip can still be set explicitly: an assignment
# placed AFTER --unset wins (cmake 4.4.3 measured; unsetting an absent
# variable is a no-op), so PATH, the ENV entries and the RUSTFLAGS= entry
# below all trail the strip block.
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
function(polyorch_rust_build)
    set(_opts BINARY STATIC SHARED LOCKED FROZEN)
    set(_one TARGET PACKAGE CRATE PROFILE MANIFEST BASE_DIR FOLDER PREBUILD)
    set(_multi FEATURES DEPENDS)
    cmake_parse_arguments(PARSE_ARGV 0 B "${_opts}" "${_one}" "${_multi}")
    if(B_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "polyorch_rust_build: unknown args: ${B_UNPARSED_ARGUMENTS}")
    endif()
    _polyorch_rust_must(B_TARGET B_PACKAGE B_CRATE)
    set(_kind "")
    foreach(_k BINARY STATIC SHARED)
        if(B_${_k})
            if(_kind)
                message(FATAL_ERROR
                    "polyorch_rust_build: BINARY, STATIC and SHARED are mutually exclusive")
            endif()
            set(_kind "")
            if(_k STREQUAL "BINARY")
                set(_kind bin)
            else()
                string(TOLOWER "${_k}" _kind)
            endif()
        endif()
    endforeach()
    if(NOT _kind)
        message(FATAL_ERROR
            "polyorch_rust_build: pick exactly one of BINARY, STATIC, SHARED")
    endif()
    _polyorch_rust_require_setup(polyorch_rust_build)

    # --- profile resolution (corr:762 semantics, single-config scope) ------
    # No explicit PROFILE: cargo's debug profile follows an unset or Debug
    # CMAKE_BUILD_TYPE, release follows any other value. The flag, the
    # artifact directory and the rule stamp are all LITERAL and equal --
    # generator expressions are banned from BYPRODUCTS and unreliable in
    # OUTPUT (corr:905-909), and a genex flag paired with a literal stamp
    # would desync on a multi-config generator, whose per-config copy
    # strategy is a documented Non-goal. Stamp correctness beats partial
    # multi-config hope.
    # ponytail(MC): per-<CONFIG> resolution + copy-staging lands with the
    # multi-config cluster; multi-config generators stay on debug until then.
    # R-3 version floors: the resolved debug/release behaviour above is
    # verified on this host's toolchain only -- cmake 4.4.3 and cargo
    # 1.98.1 (pixi env, measured 2026-09-21, the exact binaries the e2e
    # suite drives). Any lower cargo ceiling for --profile/--features
    # equals-form handling is TBD (not probed here; do not cite a number).
    if(B_PROFILE)
        set(_prof "${B_PROFILE}")
    else()
        string(TOLOWER "${CMAKE_BUILD_TYPE}" _bt)
        if(_bt STREQUAL "" OR _bt STREQUAL "debug")
            set(_prof debug)
        else()
            set(_prof release)
        endif()
    endif()
    _polyorch_rust_target_dir(_td "${B_BASE_DIR}")
    _polyorch_rust_artifact_names(TRIPLE "${POLYORCH_RUST_HOST_TARGET}"
        KIND "${_kind}" CRATE "${B_CRATE}" PROFILE "${_prof}" BASE_DIR "${_td}"
        FILE_OUT _file DIR_OUT _dir IMPLIB_OUT _implib)
    set(_artifact "${_dir}/${_file}")
    get_filename_component(_base "${_artifact}" NAME_WE)
    if(_base STREQUAL B_TARGET)
        message(FATAL_ERROR
            "polyorch_rust_build: TARGET '${B_TARGET}' collides with the artifact base name '${_base}' -- an IMPORTED target named like its output file makes the Makefile generator silently swallow the producing rule (PIT-13). Give the CMake TARGET a different name.")
    endif()

    set(_flags "")
    if(B_LOCKED)
        list(APPEND _flags LOCKED)
    endif()
    if(B_FROZEN)
        list(APPEND _flags FROZEN)
    endif()

    # --- deferred build inputs (corr:702-735 pattern) ----------------------
    # The variable argv parts ride the mediator's POLYORCH_RUST_* properties
    # and expand at generate time, so a property change made AFTER this call
    # -- by the setter family below or a raw set_property -- still lands in
    # the rule. Everything is initialised from this call's keywords and is
    # empty unless given. FEATURES uses the equals form -- one argument,
    # immune to ';' re-splitting. CARGO_FLAGS and ENV_VARS are bare
    # list-property arguments: under COMMAND_EXPAND_LISTS each element
    # becomes its own argv entry and an EMPTY property emits NOTHING
    # (probed on cmake 4.4.3: no stray '' argument under VERBATIM; the
    # escaped `\;` pixi PATH prefix survives expansion unsplit). RUSTFLAGS
    # keeps the equals form as one KEY=VAL argument, so its property is a
    # plain STRING (a ';' list would split mid-value;
    # polyorch_rust_add_rustflags joins with spaces).
    set(_med "cargo-build-${B_TARGET}")
    set(_features_gx "$<$<BOOL:$<TARGET_PROPERTY:${_med},POLYORCH_RUST_FEATURES>>:--features=$<JOIN:$<TARGET_PROPERTY:${_med},POLYORCH_RUST_FEATURES>,,>>")
    set(_allf_gx "$<$<BOOL:$<TARGET_PROPERTY:${_med},POLYORCH_RUST_ALL_FEATURES>>:--all-features>")
    set(_nondf_gx "$<$<BOOL:$<TARGET_PROPERTY:${_med},POLYORCH_RUST_NO_DEFAULT_FEATURES>>:--no-default-features>")
    set(_flags_gx "$<TARGET_PROPERTY:${_med},POLYORCH_RUST_CARGO_FLAGS>")
    set(_env_gx "$<TARGET_PROPERTY:${_med},POLYORCH_RUST_ENV_VARS>")
    set(_rustflags_gx "$<$<BOOL:$<TARGET_PROPERTY:${_med},POLYORCH_RUST_RUSTFLAGS>>:RUSTFLAGS=$<TARGET_PROPERTY:${_med},POLYORCH_RUST_RUSTFLAGS>>")

    # Optional keywords are passed only when set: an empty quoted value
    # trips policy CMP0174's author warning on every configure.
    set(_mankw "")
    if(B_MANIFEST)
        set(_mankw MANIFEST "${B_MANIFEST}")
    endif()
    _polyorch_rust_cargo_args(PACKAGE "${B_PACKAGE}" KIND "${_kind}"
        CRATE "${B_CRATE}" PROFILE "${_prof}" ${_mankw} ${_flags} ARGO_OUT _argv)
    list(APPEND _argv "${_features_gx}" "${_allf_gx}" "${_nondf_gx}" "${_flags_gx}")
    list(APPEND _argv --target-dir "${_td}")
    _polyorch_rust_command(_cmd SUBCOMMAND ${_argv} ENV "${_env_gx}" "${_rustflags_gx}")

    set(_byproducts "")
    if(_implib)
        set(_implib_path "${_dir}/${_implib}")
        set(_byproducts BYPRODUCTS "${_implib_path}")
    endif()
    set(_depfiles "")
    if(B_MANIFEST)
        set(_depfiles DEPENDS "${B_MANIFEST}")
    endif()
    # ponytail: file-stamp granularity -- cargo's own fingerprint decides
    # whether an invocation recompiles; source files never enter DEPENDS.
    add_custom_command(OUTPUT "${_artifact}" ${_byproducts}
        COMMAND ${_cmd}
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
        ${_depfiles}
        COMMENT "cargo build ${B_PACKAGE} (${_kind})"
        COMMAND_EXPAND_LISTS
        VERBATIM)
    # Primary mediator: owns the rule and carries the POLYORCH_RUST_* build
    # inputs. Deliberately NOT ALL -- consumers reach it through the
    # auto-build edge below or the polyorch-rust-all aggregate.
    add_custom_target("${_med}" DEPENDS "${_artifact}")
    # Compatibility shim for the pre-rename <TARGET>-cargo name (existing
    # callers and IDE muscle memory keep working). A real target, not an
    # ALIAS: add_custom_target(x ALIAS y) configures but generates a rule
    # that runs the literal word ALIAS (rc=2, measured on cmake 4.4.3).
    add_custom_target("${B_TARGET}-cargo" DEPENDS "${_med}")
    # DEPRECATED: attaches extra prerequisites to the mediator; the
    # auto-build edge below already orders it for every consumer.
    if(B_DEPENDS)
        add_dependencies("${_med}" ${B_DEPENDS})
    endif()
    # Prebuild seam (corr:930-937 convention, explicit form): the named
    # user-owned target is ordered before the mediator, hence before cargo
    # -- code generators hang off it. A plain add_dependencies edge; the
    # target is otherwise unconstrained (it need not produce files).
    # ponytail(convention): corrosion auto-spawns cargo-prebuild_<T> plus a
    # cargo-prebuild aggregate; keeping the hook named is cheaper to decode
    # at 3am than the magic-name convention. The convention may layer on
    # this edge later without an ABI change.
    if(B_PREBUILD)
        add_dependencies("${_med}" "${B_PREBUILD}")
    endif()

    # Property carrier (corr:2313 init convention): every build input the
    # rule reads is a mediator target property, initialised from this call
    # and written by the setter family below.
    # One property per call: set_property's value list is GREEDY (a second
    # name after the values joins the first property's list -- measured on
    # 4.4.3), so multi-pair PROPERTY clauses silently fold everything into
    # the first name.
    set_property(TARGET "${_med}" PROPERTY POLYORCH_RUST_KIND "${_kind}")
    set_property(TARGET "${_med}" PROPERTY POLYORCH_RUST_CRATE "${B_CRATE}")
    set_property(TARGET "${_med}" PROPERTY POLYORCH_RUST_PACKAGE "${B_PACKAGE}")
    set_property(TARGET "${_med}" PROPERTY POLYORCH_RUST_PROFILE "${_prof}")
    set_property(TARGET "${_med}" PROPERTY POLYORCH_RUST_BASE_DIR "${_td}")
    set_property(TARGET "${_med}" PROPERTY POLYORCH_RUST_FEATURES "${B_FEATURES}")
    set_property(TARGET "${_med}" PROPERTY POLYORCH_RUST_ALL_FEATURES "")
    set_property(TARGET "${_med}" PROPERTY POLYORCH_RUST_NO_DEFAULT_FEATURES "")
    set_property(TARGET "${_med}" PROPERTY POLYORCH_RUST_CARGO_FLAGS "")
    set_property(TARGET "${_med}" PROPERTY POLYORCH_RUST_RUSTFLAGS "")
    set_property(TARGET "${_med}" PROPERTY POLYORCH_RUST_ENV_VARS "")

    if(_kind STREQUAL "bin")
        add_executable("${B_TARGET}" IMPORTED GLOBAL)
    else()
        add_library("${B_TARGET}" UNKNOWN IMPORTED GLOBAL)
    endif()
    set_target_properties("${B_TARGET}" PROPERTIES IMPORTED_LOCATION "${_artifact}")
    if(_implib)
        set_target_properties("${B_TARGET}" PROPERTIES IMPORTED_IMPLIB "${_implib_path}")
    endif()
    # Registry marker on the consumer-facing handle (mirrors what
    # polyorch_rust_import already set there), so polyorch_rust_install
    # validates handles from both registration paths the same way.
    set_property(TARGET "${B_TARGET}" PROPERTY POLYORCH_RUST_PACKAGE "${B_PACKAGE}")
    # System libraries a Rust staticlib needs at final link, from the setup-time
    # native-static-libs probe (_polyorch_rust_probe_native_libs). STATIC only:
    # a shared cdylib has already resolved these against its own link, and a
    # binary links them directly -- neither needs an interface. When the probe
    # produced nothing (opt-out, no cc, no_std) the properties stay UNSET and a
    # C consumer must supply its own system libs; pure-Rust consumers are
    # unaffected because they never re-enter the system linker.
    if(_kind STREQUAL "static")
        if(POLYORCH_RUST_NATIVE_LIBS)
            set_target_properties("${B_TARGET}" PROPERTIES
                INTERFACE_LINK_LIBRARIES "${POLYORCH_RUST_NATIVE_LIBS}")
        endif()
        if(POLYORCH_RUST_NATIVE_LIB_DIRS)
            set_target_properties("${B_TARGET}" PROPERTIES
                INTERFACE_LINK_DIRECTORIES "${POLYORCH_RUST_NATIVE_LIB_DIRS}")
        endif()
    endif()
    # Auto-build edge: a dependency added to an IMPORTED target propagates
    # to every target that links it (Makefile2 gains the mediator as a
    # prerequisite of the consumer; measured on cmake 4.4.3), replacing
    # per-consumer manual wiring of the mediator.
    add_dependencies("${B_TARGET}" "${_med}")
    # Opt-in aggregate: `cmake --build . --target polyorch-rust-all` builds
    # every rust artifact registered in the tree without putting cargo into
    # a bare build's default target set.
    if(NOT TARGET polyorch-rust-all)
        add_custom_target(polyorch-rust-all)
    endif()
    add_dependencies(polyorch-rust-all "${_med}")
    if(B_FOLDER)
        # all three handles join the same IDE folder: the imported target
        # consumers link, the mediator that owns the rule, and the shim.
        set_target_properties("${B_TARGET}" "${_med}" "${B_TARGET}-cargo"
            PROPERTIES FOLDER "${B_FOLDER}")
    endif()
endfunction()

# ------------------------------------------------------------------ import ---

# Internal: pure parser for `cargo metadata --format-version 1` JSON. Walks
# packages[] x targets[] with string(JSON) (the reference walks the same
# shape, gen:88-119) and emits one record per IMPORTABLE kind --
#   <package>|<cmake_handle>|<cargo_selector>|<kind>   kind in {bin,static,shared}
# -- ready for polyorch_rust_import to replay through polyorch_rust_build.
# staticlib -> static, cdylib -> shared, bin -> bin; every other kind
# (lib, rlib, proc-macro, custom-build, test, ...) yields nothing but a
# STATUS line. A target carrying BOTH staticlib and cdylib emits the pair
# "<h>-static" + "<h>-shared" (the reference registers one sub-target per
# lib kind too, gen:136-190).
#
# Naming rules -- gen:137-142 is the dash->underscore rationale:
#   * lib handles AND selectors: dashes replaced by underscores. Cargo names
#     the lib ARTIFACT after the crate name: explicit lib targets never had
#     dashes, and Rust >= 1.79 replaces inherited dashes too -- normalising
#     the metadata target name gives one version-proof handle + artifact name.
#     The raw metadata name is NEVER trusted for the crate identity (no
#     crate_name dependency); the normalization from target.name IS the
#     contract.
#   * bin handle: "<target>-exe" UNCONDITIONALLY, selector = raw target name
#     (cargo bin artifacts keep dashes). The suffix is not platform-
#     conditional: a bin's artifact base equals its raw target name, so a bare
#     handle would trip the PIT-13 collision guard in polyorch_rust_build on
#     every unix host. Predictable beats clever.
function(_polyorch_rust_metadata_targets JSON OUT_SPECS)
    set(_specs "")
    string(JSON _np LENGTH "${JSON}" "packages")
    if(_np GREATER 0)
        math(EXPR _plast "${_np} - 1")
        foreach(_pi RANGE 0 ${_plast})
            string(JSON _pkg GET "${JSON}" "packages" ${_pi})
            string(JSON _pname GET "${_pkg}" "name")
            string(JSON _tgts GET "${_pkg}" "targets")
            string(JSON _nt LENGTH "${_tgts}")
            if(_nt GREATER 0)
                math(EXPR _tlast "${_nt} - 1")
                foreach(_ti RANGE 0 ${_tlast})
                    string(JSON _tgt GET "${_tgts}" ${_ti})
                    string(JSON _tname GET "${_tgt}" "name")
                    string(JSON _kinds GET "${_tgt}" "kind")
                    string(JSON _nk LENGTH "${_kinds}")
                    set(_static OFF)
                    set(_shared OFF)
                    set(_bin OFF)
                    if(_nk GREATER 0)
                        math(EXPR _klast "${_nk} - 1")
                        foreach(_ki RANGE 0 ${_klast})
                            string(JSON _k GET "${_kinds}" ${_ki})
                            if(_k STREQUAL "staticlib")
                                set(_static ON)
                            elseif(_k STREQUAL "cdylib")
                                set(_shared ON)
                            elseif(_k STREQUAL "bin")
                                set(_bin ON)
                            endif()
                        endforeach()
                    endif()
                    set(_emitted OFF)
                    if(_bin)
                        list(APPEND _specs "${_pname}|${_tname}-exe|${_tname}|bin")
                        set(_emitted ON)
                    endif()
                    if(_static OR _shared)
                        string(REPLACE "-" "_" _lib "${_tname}")
                        if(_static AND _shared)
                            list(APPEND _specs "${_pname}|${_lib}-static|${_lib}|static")
                            list(APPEND _specs "${_pname}|${_lib}-shared|${_lib}|shared")
                        elseif(_static)
                            list(APPEND _specs "${_pname}|${_lib}|${_lib}|static")
                        else()
                            list(APPEND _specs "${_pname}|${_lib}|${_lib}|shared")
                        endif()
                        set(_emitted ON)
                    endif()
                    if(NOT _emitted)
                        message(STATUS
                            "polyorch_rust_import: skipping target '${_tname}' of package "
                            "'${_pname}' (kind ${_kinds} carries no importable artifact)")
                    endif()
                endforeach()
            endif()
        endforeach()
    endif()
    set(${OUT_SPECS} "${_specs}" PARENT_SCOPE)
endfunction()

# polyorch_rust_import(MANIFEST <path> [CRATES a;b] [LOCKED|FROZEN]
#                      [FOLDER <ide>] IMPORTED_TARGETS <var>
#                      [SKIPPED_TARGETS <var>])
# Batch-import every importable target of a cargo workspace (or single
# package): runs `cargo metadata --no-deps --format-version 1` through the
# same isolation wrapper as every build (call shape gen:27-45;
# WORKING_DIRECTORY is the manifest's dir so cargo's upward .cargo/config
# walk applies, gen:39-42), parses the JSON with
# _polyorch_rust_metadata_targets and replays each record through
# polyorch_rust_build -- build stays the single registration point; import is
# sugar plus an exact registry. The cargo rc != 0 case FATALs with the last
# lines of cargo's stderr.
#   IMPORTED_TARGETS <var>  receives the SORTED list of created handles.
#   SKIPPED_TARGETS <var>   receives the sorted handles skipped for name
#                           collision (optional keyword).
#   CRATES <a;b>            restricts the import to these cargo PACKAGE names;
#                           an entry matching no package FATALs naming the
#                           available packages (measured from this same
#                           metadata, no second cargo call).
#   LOCKED / FROZEN         ride both the metadata call and every build rule.
# A handle colliding with an existing CMake target warns and skips
# (gen:121-133 precedent) instead of hard-failing the configure. Each created
# handle carries POLYORCH_RUST_PACKAGE = its cargo package name (gen:190).
function(polyorch_rust_import)
    set(_opts LOCKED FROZEN)
    set(_one MANIFEST FOLDER IMPORTED_TARGETS SKIPPED_TARGETS)
    set(_multi CRATES)
    cmake_parse_arguments(PARSE_ARGV 0 A "${_opts}" "${_one}" "${_multi}")
    if(A_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "polyorch_rust_import: unknown args: ${A_UNPARSED_ARGUMENTS}")
    endif()
    _polyorch_rust_must(A_MANIFEST A_IMPORTED_TARGETS)
    if(A_LOCKED AND A_FROZEN)
        message(FATAL_ERROR
            "polyorch_rust_import: LOCKED and FROZEN are mutually exclusive")
    endif()
    _polyorch_rust_require_setup(polyorch_rust_import)

    set(_lock "")
    if(A_LOCKED)
        set(_lock --locked)
    elseif(A_FROZEN)
        set(_lock --frozen)
    endif()
    _polyorch_rust_command(_cmd SUBCOMMAND
        metadata --no-deps --format-version 1
        --manifest-path "${A_MANIFEST}" ${_lock})
    get_filename_component(_mdir "${A_MANIFEST}" DIRECTORY)
    execute_process(COMMAND ${_cmd} WORKING_DIRECTORY "${_mdir}"
        RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
    if(NOT _rc EQUAL 0)
        string(REPLACE "\n" ";" _elines "${_err}")
        list(LENGTH _elines _en)
        if(_en GREATER 5)
            math(EXPR _estart "${_en} - 5")
            list(SUBLIST _elines ${_estart} 5 _elines)
        endif()
        string(JOIN "\n" _etail ${_elines})
        message(FATAL_ERROR
            "polyorch_rust_import: cargo metadata failed (rc=${_rc}) for "
            "'${A_MANIFEST}':\n${_etail}")
    endif()

    # CRATES entries are cargo PACKAGE names; availability is checked against
    # this same metadata document (one parse, no second cargo invocation).
    if(A_CRATES)
        string(JSON _np LENGTH "${_out}" "packages")
        set(_avail "")
        if(_np GREATER 0)
            math(EXPR _plast "${_np} - 1")
            foreach(_pi RANGE 0 ${_plast})
                string(JSON _pn GET "${_out}" "packages" ${_pi} "name")
                list(APPEND _avail "${_pn}")
            endforeach()
        endif()
        list(SORT _avail)
        foreach(_c IN LISTS A_CRATES)
            if(NOT _c IN_LIST _avail)
                string(REPLACE ";" ", " _avail_s "${_avail}")
                message(FATAL_ERROR
                    "polyorch_rust_import: no package '${_c}' in the cargo metadata "
                    "(available: ${_avail_s})")
            endif()
        endforeach()
    endif()

    _polyorch_rust_metadata_targets("${_out}" _specs)

    set(_lockb "")
    if(A_LOCKED)
        set(_lockb LOCKED)
    elseif(A_FROZEN)
        set(_lockb FROZEN)
    endif()
    set(_foldkw "")
    if(A_FOLDER)
        set(_foldkw FOLDER "${A_FOLDER}")
    endif()

    set(_imps "")
    set(_skips "")
    foreach(_spec IN LISTS _specs)
        string(REPLACE "|" ";" _rec "${_spec}")
        list(GET _rec 0 _pkg)
        list(GET _rec 1 _handle)
        list(GET _rec 2 _crate)
        list(GET _rec 3 _kind)
        if(A_CRATES AND NOT _pkg IN_LIST A_CRATES)
            continue()
        endif()
        if(TARGET "${_handle}")
            message(WARNING
                "polyorch_rust_import: target '${_handle}' already exists -- skipping "
                "this cargo target (rename it in Cargo.toml or narrow CRATES)")
            list(APPEND _skips "${_handle}")
            continue()
        endif()
        set(_kws "")
        if(_kind STREQUAL "bin")
            set(_kws BINARY)
        elseif(_kind STREQUAL "static")
            set(_kws STATIC)
        else()
            set(_kws SHARED)
        endif()
        polyorch_rust_build(TARGET "${_handle}" PACKAGE "${_pkg}" CRATE "${_crate}"
            ${_kws} MANIFEST "${A_MANIFEST}" ${_lockb} ${_foldkw})
        # Registry marker on the consumer-facing handle (gen:190 precedent);
        # the mediator already carries POLYORCH_RUST_PACKAGE from the build.
        set_property(TARGET "${_handle}" PROPERTY POLYORCH_RUST_PACKAGE "${_pkg}")
        list(APPEND _imps "${_handle}")
    endforeach()
    list(SORT _imps)
    list(SORT _skips)
    set(${A_IMPORTED_TARGETS} "${_imps}" PARENT_SCOPE)
    if(A_SKIPPED_TARGETS)
        set(${A_SKIPPED_TARGETS} "${_skips}" PARENT_SCOPE)
    endif()
    list(LENGTH _imps _ni)
    list(LENGTH _skips _ns)
    message(STATUS
        "polyorch_rust_import: ${_ni} target(s) imported [${_imps}] (${_ns} skipped)")
endfunction()

# ---------------------------------------------------------------- setters ---

# Internal: resolve the user-facing declared target name to its mediator.
# The setters key on the name given in polyorch_rust_build(TARGET ..); the
# build inputs live on the cargo-build-<TARGET> mediator, which is a
# directory-scoped target -- so every setter must be called from the scope
# that declared it (or a child scope), like the build call itself.
function(_polyorch_rust_mediator CALLER T OUT)
    if(NOT TARGET "${T}")
        message(FATAL_ERROR
            "${CALLER}: no target '${T}' (declare it with polyorch_rust_build first)")
    endif()
    set(_med "cargo-build-${T}")
    if(NOT TARGET "${_med}")
        message(FATAL_ERROR
            "${CALLER}: target '${T}' was not declared by polyorch_rust_build "
            "(no mediator '${_med}' carries its build inputs; setters take the "
            "declared TARGET name, not the mediator or the <-cargo shim)")
    endif()
    set(${OUT} "${_med}" PARENT_SCOPE)
endfunction()

# polyorch_rust_set_features(TARGET <n> [FEATURES a;b] [ALL_FEATURES]
#                            [NO_DEFAULT_FEATURES])
# Write-through replacement of the rule's three feature inputs: each call
# sets FEATURES, ALL_FEATURES and NO_DEFAULT_FEATURES to exactly what this
# call carries -- a call without FEATURES CLEARS the previous list. cargo
# refuses --all-features together with --features, so the pair is rejected
# here too; NO_DEFAULT_FEATURES composes with both. At least one selector
# is required: a bare call is ambiguous between "clear everything" and typo.
# FEATURES without NO_DEFAULT_FEATURES only ADDS to the default set (cargo
# semantics), so clearing defaults needs the explicit selector.
# ponytail(INHERITABLE): corrosion propagates feature choices along the
# link interface; cargo features are not a link-interface property and the
# transitive set is fixed at each cargo invocation -- a propagation half
# belongs with the Task 5 batch-import rework, not here. Not implemented.
function(polyorch_rust_set_features)
    cmake_parse_arguments(PARSE_ARGV 0 A "ALL_FEATURES;NO_DEFAULT_FEATURES"
        "TARGET" "FEATURES")
    if(A_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR
            "polyorch_rust_set_features: unknown args: ${A_UNPARSED_ARGUMENTS}")
    endif()
    _polyorch_rust_must(A_TARGET)
    if(A_ALL_FEATURES AND A_FEATURES)
        message(FATAL_ERROR
            "polyorch_rust_set_features: FEATURES and ALL_FEATURES are mutually exclusive")
    endif()
    if(NOT A_FEATURES AND NOT A_ALL_FEATURES AND NOT A_NO_DEFAULT_FEATURES)
        message(FATAL_ERROR
            "polyorch_rust_set_features: at least one selector "
            "(FEATURES / ALL_FEATURES / NO_DEFAULT_FEATURES) is required")
    endif()
    _polyorch_rust_mediator("polyorch_rust_set_features" "${A_TARGET}" _med)
    # One property per call (greedy value list, see polyorch_rust_build).
    set_property(TARGET "${_med}" PROPERTY POLYORCH_RUST_FEATURES "${A_FEATURES}")
    set_property(TARGET "${_med}" PROPERTY POLYORCH_RUST_ALL_FEATURES "${A_ALL_FEATURES}")
    set_property(TARGET "${_med}" PROPERTY POLYORCH_RUST_NO_DEFAULT_FEATURES "${A_NO_DEFAULT_FEATURES}")
endfunction()

# polyorch_rust_set_env_vars(TARGET <n> [VAR=VALUE ...])
# Write-through replacement of the KEY=VAL entries the rule exports through
# `cmake -E env` (see the pitfall note in _polyorch_rust_command): each call
# sets the complete set, a call with no entries clears it. Every entry must
# spell VAR=VALUE with a shell-identifier name -- anything else is a typo
# that would silently mis-shape the command, so it fails the configure.
function(polyorch_rust_set_env_vars)
    cmake_parse_arguments(PARSE_ARGV 0 A "" "TARGET" "")
    _polyorch_rust_must(A_TARGET)
    foreach(_e IN LISTS A_UNPARSED_ARGUMENTS)
        if(NOT _e MATCHES "^[A-Za-z_][A-Za-z0-9_]*=")
            message(FATAL_ERROR
                "polyorch_rust_set_env_vars: entries must be VAR=VALUE, got '${_e}'")
        endif()
    endforeach()
    _polyorch_rust_mediator("polyorch_rust_set_env_vars" "${A_TARGET}" _med)
    set_property(TARGET "${_med}" PROPERTY
        POLYORCH_RUST_ENV_VARS "${A_UNPARSED_ARGUMENTS}")
endfunction()

# polyorch_rust_add_cargo_flags(TARGET <n> [FLAGS <flag>...])
# APPENDS extra arguments to the cargo build argv (e.g. --offline --timings).
# Unlike the set_* functions this is additive: repeated calls accumulate; the
# flags ride the rule as separate argv entries (COMMAND_EXPAND_LISTS).
function(polyorch_rust_add_cargo_flags)
    cmake_parse_arguments(PARSE_ARGV 0 A "" "TARGET" "FLAGS")
    if(A_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR
            "polyorch_rust_add_cargo_flags: unknown args: ${A_UNPARSED_ARGUMENTS}")
    endif()
    _polyorch_rust_must(A_TARGET)
    _polyorch_rust_mediator("polyorch_rust_add_cargo_flags" "${A_TARGET}" _med)
    get_property(_cur TARGET "${_med}" PROPERTY POLYORCH_RUST_CARGO_FLAGS)
    set_property(TARGET "${_med}" PROPERTY
        POLYORCH_RUST_CARGO_FLAGS ${_cur} ${A_FLAGS})
endfunction()

# polyorch_rust_add_rustflags(TARGET <n> [FLAGS <flag>...])
# APPENDS to the RUSTFLAGS the rule exports. This is the GLOBAL variant: the
# env var reaches every crate cargo compiles for this rule (dependencies
# included), matching cargo's own RUSTFLAGS semantics. The property is a
# plain string joined with spaces -- per-crate local flags would need the
# `cargo rustc` subcommand.
# ponytail(local-rustflags): corrosion's local variant (last crate only) is
# the cargo-rustc rework; it lands with a future crate-scoped design, not
# half-implemented beside the global one.
function(polyorch_rust_add_rustflags)
    cmake_parse_arguments(PARSE_ARGV 0 A "" "TARGET" "FLAGS")
    if(A_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR
            "polyorch_rust_add_rustflags: unknown args: ${A_UNPARSED_ARGUMENTS}")
    endif()
    _polyorch_rust_must(A_TARGET)
    _polyorch_rust_mediator("polyorch_rust_add_rustflags" "${A_TARGET}" _med)
    get_property(_cur TARGET "${_med}" PROPERTY POLYORCH_RUST_RUSTFLAGS)
    string(REPLACE ";" " " _add "${A_FLAGS}")
    string(STRIP "${_cur} ${_add}" _new)
    set_property(TARGET "${_med}" PROPERTY POLYORCH_RUST_RUSTFLAGS "${_new}")
endfunction()

# ------------------------------------------------------- test / run / clean ---

# Internal: the cargo target directory all wrappers share: the BASE_DIR
# override when given, else .cargo-target under the build directory. One
# definition so clean can never drift from what build/test actually wrote.
function(_polyorch_rust_target_dir OUT BASE_OVERRIDE)
    if(BASE_OVERRIDE)
        set(${OUT} "${BASE_OVERRIDE}" PARENT_SCOPE)
    else()
        set(${OUT} "${CMAKE_BINARY_DIR}/.cargo-target" PARENT_SCOPE)
    endif()
endfunction()

# polyorch_rust_test(PACKAGE <p> [NAME <t>] [MANIFEST <path>] [ALL] [ARGS ...]
#                    [BASE_DIR <td>] [FOLDER <ide>])
# Registers a custom target running `cargo test --package P`. NAME defaults to
# `<p>-rusttest`. ALL adds it to the default target set. ARGS are appended
# verbatim (cargo treats them as filter / harness arguments). Like build, the
# rule is not written as ALL by default and the target only tests at build
# time, never at configure time.
function(polyorch_rust_test)
    set(_opts ALL)
    set(_one PACKAGE NAME MANIFEST BASE_DIR FOLDER)
    set(_multi ARGS)
    cmake_parse_arguments(PARSE_ARGV 0 T "${_opts}" "${_one}" "${_multi}")
    if(T_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "polyorch_rust_test: unknown args: ${T_UNPARSED_ARGUMENTS}")
    endif()
    _polyorch_rust_must(T_PACKAGE)
    _polyorch_rust_require_setup(polyorch_rust_test)

    set(_name "${T_NAME}")
    if(NOT _name)
        set(_name "${T_PACKAGE}-rusttest")
    endif()
    _polyorch_rust_target_dir(_td "${T_BASE_DIR}")
    set(_argv test --package "${T_PACKAGE}")
    if(T_MANIFEST)
        list(APPEND _argv --manifest-path "${T_MANIFEST}")
    endif()
    list(APPEND _argv --target-dir "${_td}")
    if(T_ARGS)
        list(APPEND _argv ${T_ARGS})
    endif()
    _polyorch_rust_command(_cmd SUBCOMMAND ${_argv})
    set(_all "")
    if(T_ALL)
        set(_all ALL)
    endif()
    add_custom_target("${_name}" ${_all} COMMAND ${_cmd}
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
        COMMENT "cargo test ${T_PACKAGE}"
        VERBATIM)
    if(T_FOLDER)
        set_target_properties("${_name}" PROPERTIES FOLDER "${T_FOLDER}")
    endif()
endfunction()

# polyorch_rust_run(TARGET <imported> [FOLDER <ide>])
# Registers `run-<TARGET>` that executes the imported artifact directly --
# deliberately not `cargo run`: the artifact path is already known, and one
# less cargo invocation keeps the rule set free of build/cargo overlap
# (ponytail: add cargo-run passthrough flags only when feature-gated runs
# actually need them). If the matching <TARGET>-cargo mediator exists it is
# wired as a dependency, so building run-<TARGET> builds the binary first.
function(polyorch_rust_run)
    set(_one TARGET FOLDER)
    cmake_parse_arguments(PARSE_ARGV 0 R "" "${_one}" "")
    if(R_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "polyorch_rust_run: unknown args: ${R_UNPARSED_ARGUMENTS}")
    endif()
    _polyorch_rust_must(R_TARGET)
    _polyorch_rust_require_setup(polyorch_rust_run)
    if(NOT TARGET "${R_TARGET}")
        message(FATAL_ERROR
            "polyorch_rust_run: no such target '${R_TARGET}' "
            "(register it with polyorch_rust_build first)")
    endif()
    add_custom_target("run-${R_TARGET}"
        COMMAND $<TARGET_FILE:${R_TARGET}>
        COMMENT "run $<TARGET_FILE:${R_TARGET}>")
    if(TARGET "${R_TARGET}-cargo")
        add_dependencies("run-${R_TARGET}" "${R_TARGET}-cargo")
    endif()
    if(R_FOLDER)
        set_target_properties("run-${R_TARGET}" PROPERTIES FOLDER "${R_FOLDER}")
    endif()
endfunction()

# polyorch_rust_clean([NAME <t>] [BASE_DIR <td>] [FOLDER <ide>])
# Registers a never-automatic target that deletes the isolated cargo
# target-dir. The isolation is the whole point: wiping that directory IS a
# full cargo clean, with no toolchain present and no cargo.toml walked.
function(polyorch_rust_clean)
    set(_one NAME BASE_DIR FOLDER)
    cmake_parse_arguments(PARSE_ARGV 0 C "" "${_one}" "")
    if(C_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "polyorch_rust_clean: unknown args: ${C_UNPARSED_ARGUMENTS}")
    endif()
    set(_name "${C_NAME}")
    if(NOT _name)
        set(_name rust-clean)
    endif()
    _polyorch_rust_target_dir(_td "${C_BASE_DIR}")
    add_custom_target("${_name}"
        COMMAND ${CMAKE_COMMAND} -E rm -rf "${_td}"
        COMMENT "removing cargo target directory ${_td}")
    if(C_FOLDER)
        set_target_properties("${_name}" PROPERTIES FOLDER "${C_FOLDER}")
    endif()
endfunction()


# ---------------------------------------------------------------- install ---

# polyorch_rust_install(TARGETS <handle>... [EXPORT <name>] [PREFIX <dir>])
# Installs the cargo artifacts behind previously-registered rust handles
# (binaries to <dir>bin/, archives and unix shared libs to <dir>lib/; a
# Windows-family dll stages to <dir>bin/ as its RUNTIME part with its
# import library beside the archives). macOS note: a dylib installs to
# <dir>lib/ like the ELF .so, but its embedded install_name still points
# into the build tree -- rewriting it (and staging Windows runtime dlls
# next to consumer exes) is the P2 backlog, not this function.
#
# EXPORT <name> additionally writes <name>-rust.cmake through
# file(GENERATE): a replay stub that recreates every handle as an
# IMPORTED GLOBAL target with its location rebuilt at include time
# relative to the stub's own directory, and installs it to
# <dir>lib/cmake/<name>/. The consumer side is a plain include():
#
#   include(<prefix>/lib/cmake/<name>/<name>-rust.cmake)
#   target_link_libraries(my-app PRIVATE dash_ed)
#
# No find_package Config package is generated (deliberate v0 scope cut).
# STATIC handles re-attach their probed INTERFACE_LINK_LIBRARIES /
# INTERFACE_LINK_DIRECTORIES into the stub as literal lists -- without
# them a C consumer of the installed .a cannot resolve the system libs
# the native-static-libs probe found (t-rust-install-e2e asserts both
# sides: the consumer links, and the same consumer FAILS to link when
# the stub copy has those lines stripped).
#
# PREFIX <dir> relocates the whole staged layout (bin/, lib/,
# lib/cmake/<name>) under one relative directory beside the install
# prefix; the stub travels with the tree because it resolves paths from
# its own location. One call per EXPORT name: the stub file is written
# whole, not appended (the reference makes the same assumption,
# corr:1389). Single-config only -- the artifact paths are the
# configure-time-resolved profile directories, no per-CONFIG matrix.
#
# Shape source: the reference's install rules (corr:1451-1604) -- the
# per-artifact install(FILES $<TARGET_FILE:t>) staging and the
# generated-imported-file idea of its export block. The install(EXPORT)
# / install(TARGETS EXPORT) machinery around it is NOT ported.
function(polyorch_rust_install)
    set(_one EXPORT PREFIX)
    set(_multi TARGETS)
    cmake_parse_arguments(PARSE_ARGV 0 A "" "${_one}" "${_multi}")
    if(A_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR
            "polyorch_rust_install: unknown args: ${A_UNPARSED_ARGUMENTS}")
    endif()
    _polyorch_rust_must(A_TARGETS)

    # Pass 1: validate every handle exists + is ours BEFORE install()
    # rules or the triple guard are touched, so a typo'd list never
    # half-registers and the actionable error wins over the setup guard.
    foreach(_h IN LISTS A_TARGETS)
        _polyorch_rust_mediator("polyorch_rust_install" "${_h}" _med)
        get_target_property(_pkg "${_h}" POLYORCH_RUST_PACKAGE)
        if(NOT _pkg)
            message(FATAL_ERROR
                "polyorch_rust_install: target '${_h}' is not a PolyOrch rust "
                "import (no POLYORCH_RUST_PACKAGE property)")
        endif()
    endforeach()
    if(NOT POLYORCH_RUST_HOST_TARGET)
        message(FATAL_ERROR
            "polyorch_rust_install: call polyorch_rust_setup first "
            "(no host triple to classify the artifact layout by)")
    endif()
    _polyorch_rust_triple_family("${POLYORCH_RUST_HOST_TARGET}" _fam)

    set(_p "${A_PREFIX}")
    if(_p AND NOT _p MATCHES "/$")
        string(APPEND _p "/")
    endif()
    # corr:1448/1477: archives plain, runtime artifacts plus exec bits.
    set(_exec_perms OWNER_READ OWNER_WRITE GROUP_READ WORLD_READ
                    OWNER_EXECUTE GROUP_EXECUTE WORLD_EXECUTE)
    set(_file_perms OWNER_READ OWNER_WRITE GROUP_READ WORLD_READ)

    set(_stub "")
    if(A_EXPORT)
        # Append, never set-with-list: a multi-argument set() would join
        # the lines with ';' and the stub would not parse (measured).
        string(APPEND _stub
            "# Generated by polyorch_rust_install() -- DO NOT EDIT.\n"
            "# Consume with a plain include():\n"
            "#   include(<install-prefix>/${_p}lib/cmake/${A_EXPORT}/${A_EXPORT}-rust.cmake)\n"
            "# No find_package Config is generated for these targets.\n"
            "get_filename_component(_POLYORCH_RUST_ROOT\n"
            "    \"\${CMAKE_CURRENT_LIST_DIR}/../../..\" ABSOLUTE)\n")
    endif()

    # Pass 2: stage + serialize. Every handle was validated in the
    # pre-pass, so only the kind lookup remains here.
    foreach(_h IN LISTS A_TARGETS)
        set(_med "cargo-build-${_h}")
        get_target_property(_kind "${_med}" POLYORCH_RUST_KIND)

        if(_kind STREQUAL "bin")
            install(FILES "$<TARGET_FILE:${_h}>" DESTINATION "${_p}bin"
                PERMISSIONS ${_exec_perms})
            if(A_EXPORT)
                string(APPEND _stub
                    "add_executable(${_h} IMPORTED GLOBAL)\n"
                    "set_target_properties(${_h} PROPERTIES IMPORTED_LOCATION "
                    "    \"\${_POLYORCH_RUST_ROOT}/bin/$<TARGET_FILE_NAME:${_h}>\")\n")
            endif()
        elseif(_kind STREQUAL "static")
            install(FILES "$<TARGET_FILE:${_h}>" DESTINATION "${_p}lib"
                PERMISSIONS ${_file_perms})
            if(A_EXPORT)
                string(APPEND _stub
                    "add_library(${_h} STATIC IMPORTED GLOBAL)\n"
                    "set_target_properties(${_h} PROPERTIES IMPORTED_LOCATION "
                    "    \"\${_POLYORCH_RUST_ROOT}/lib/$<TARGET_FILE_NAME:${_h}>\")\n")
                # Verbatim copy of the probe-attached interface (literal
                # lists by contract). A genex the user grafted onto the
                # handle is replayed as text and may not resolve in the
                # consumer context -- not our composition, documented here.
                get_target_property(_ifl "${_h}" INTERFACE_LINK_LIBRARIES)
                get_target_property(_ifd "${_h}" INTERFACE_LINK_DIRECTORIES)
                if(_ifl)
                    string(APPEND _stub
                        "set_target_properties(${_h} PROPERTIES INTERFACE_LINK_LIBRARIES \"${_ifl}\")\n")
                endif()
                if(_ifd)
                    string(APPEND _stub
                        "set_target_properties(${_h} PROPERTIES INTERFACE_LINK_DIRECTORIES \"${_ifd}\")\n")
                endif()
            endif()
        else() # shared
            if(_fam MATCHES "^(msvc|gnu)$")
                set(_srel bin)      # the dll is the RUNTIME artifact
            else()
                set(_srel lib)      # .so / .dylib (install_name caveat above)
            endif()
            install(FILES "$<TARGET_FILE:${_h}>" DESTINATION "${_p}${_srel}"
                PERMISSIONS ${_exec_perms})
            get_target_property(_implib "${_h}" IMPORTED_IMPLIB)
            if(_implib)
                install(FILES "${_implib}" DESTINATION "${_p}lib"
                    PERMISSIONS ${_file_perms})
            endif()
            if(A_EXPORT)
                string(APPEND _stub
                    "add_library(${_h} SHARED IMPORTED GLOBAL)\n"
                    "set_target_properties(${_h} PROPERTIES IMPORTED_LOCATION "
                    "    \"\${_POLYORCH_RUST_ROOT}/${_srel}/$<TARGET_FILE_NAME:${_h}>\")\n")
                if(_implib)
                    # The implib path is a configure-time literal written by
                    # polyorch_rust_build, so NAME extraction is lexical, not
                    # a genex parse.
                    get_filename_component(_impname "${_implib}" NAME)
                    string(APPEND _stub
                        "set_target_properties(${_h} PROPERTIES IMPORTED_IMPLIB "
                        "    \"\${_POLYORCH_RUST_ROOT}/lib/${_impname}\")\n")
                endif()
            endif()
        endif()
    endforeach()

    if(A_EXPORT)
        set(_stubfile "${CMAKE_CURRENT_BINARY_DIR}/${A_EXPORT}-rust.cmake")
        file(GENERATE OUTPUT "${_stubfile}" CONTENT "${_stub}")
        install(FILES "${_stubfile}" DESTINATION "${_p}lib/cmake/${A_EXPORT}")
    endif()
endfunction()