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
# with a non-imported `<TARGET>-cargo` mediator custom target, because
# add_dependencies() refuses IMPORTED targets (the corrosion approach).
#
# All cargo invocations share one isolated target directory,
# ${CMAKE_BINARY_DIR}/.cargo-target, so polyorch_rust_clean() is a plain
# directory removal and never needs a working cargo.
#
# Result variables of polyorch_rust_setup are the POLYORCH_RUST_* set
# (documented exception to the brand-casing rule, see decisions.md D11);
# cache knobs are PolyOrch_RUST_*; public functions are polyorch_rust_*.
#
# Out of scope by design (add a `ponytail:` note at the seam when needed):
# --target cross-compilation triples, workspace member discovery,
# rust-version enforcement, cargo bench/fmt/clippy wrappers.
#
# Include-time contract: zero side effects -- definitions and comments only.
# Requires CMake >= 3.25 (PARSE_ARGV, NO_CACHE find_program, cmake_path).

include_guard(GLOBAL)

# ---------------------------------------------------------------- internals ---

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

# ------------------------------------------------------------------- setup ---

# polyorch_rust_setup([FROM <system|pixi>] [REQUIRED])
# Locate cargo + rustc and record the result in the POLYORCH_RUST_* variables:
#   POLYORCH_RUST_FOUND        TRUE/FALSE
#   POLYORCH_RUST_CARGO        absolute path to cargo
#   POLYORCH_RUST_RUSTC        absolute path to rustc
#   POLYORCH_RUST_VERSION      "cargo --version" version token
#   POLYORCH_RUST_HOST_TARGET  `rustc -vV` host triple (artifact naming key)
#   POLYORCH_RUST_ROUTE        system | pixi (drives the PATH wrapper)
#   POLYORCH_RUST_BIN_DIR      directory holding the cargo binary
# FROM defaults to the PolyOrch_RUST_FROM cache value, then to "system".
# A miss without REQUIRED sets FOUND=FALSE and reports by STATUS only;
# with REQUIRED it fails with the fix for that route. The pixi route first
# requires the pixi side to be set up -- its error message names
# polyorch_pixi_setup() (raised inside polyorch_pixi_env_paths()).
function(polyorch_rust_setup)
    set(_opts REQUIRED)
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

    set(_miss "")
    if(_from STREQUAL "system")
        find_program(_cargo NAMES cargo NO_CACHE)
        find_program(_rustc NAMES rustc NO_CACHE)
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
        find_program(_cargo NAMES cargo PATHS ${_pixi_dirs} NO_DEFAULT_PATH NO_CACHE)
        find_program(_rustc NAMES rustc PATHS ${_pixi_dirs} NO_DEFAULT_PATH NO_CACHE)
        if(NOT _cargo OR NOT _rustc)
            set(_miss "pixi environment has no cargo/rustc (fix: polyorch_pixi_environment_add(TOOLS rust))")
        endif()
    endif()

    set(_version "")
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
               POLYORCH_RUST_VERSION POLYORCH_RUST_HOST_TARGET
               POLYORCH_RUST_ROUTE POLYORCH_RUST_BIN_DIR)
        unset(${_v} CACHE)
    endforeach()
    set(POLYORCH_RUST_FOUND ${_found} CACHE INTERNAL "PolyOrch rust toolchain (polyorch_rust_setup)")
    if(_found)
        get_filename_component(_bindir "${_cargo}" DIRECTORY)
        set(POLYORCH_RUST_CARGO "${_cargo}" CACHE INTERNAL "PolyOrch rust toolchain (polyorch_rust_setup)")
        set(POLYORCH_RUST_RUSTC "${_rustc}" CACHE INTERNAL "PolyOrch rust toolchain (polyorch_rust_setup)")
        set(POLYORCH_RUST_VERSION "${_version}" CACHE INTERNAL "PolyOrch rust toolchain (polyorch_rust_setup)")
        set(POLYORCH_RUST_HOST_TARGET "${_host}" CACHE INTERNAL "PolyOrch rust toolchain (polyorch_rust_setup)")
        set(POLYORCH_RUST_ROUTE "${_from}" CACHE INTERNAL "PolyOrch rust toolchain (polyorch_rust_setup)")
        set(POLYORCH_RUST_BIN_DIR "${_bindir}" CACHE INTERNAL "PolyOrch rust toolchain (polyorch_rust_setup)")
        message(STATUS "polyorch_rust: cargo ${_version} (host ${_host}, from ${_from})")
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

# Internal: the one command line every wrapper shells out to. With the pixi
# route cargo is prefixed by `cmake -E env PATH=<bin_dir>;<host PATH>` so the
# toolchain resolves its siblings; semicolons are escaped because a custom
# command re-splits list elements on them at generate time.
function(_polyorch_rust_command CMD_OUT)
    cmake_parse_arguments(PARSE_ARGV 1 R "" "" "SUBCOMMAND")
    if(R_SUBCOMMAND)
        set(_tail "${R_SUBCOMMAND}")
    else()
        set(_tail "")
    endif()
    if(POLYORCH_RUST_ROUTE STREQUAL "pixi")
        if(WIN32)
            set(_sep ";")
        else()
            set(_sep ":")
        endif()
        set(_path "PATH=${POLYORCH_RUST_BIN_DIR}${_sep}$ENV{PATH}")
        string(REPLACE ";" "\\;" _path "${_path}")
        set(_cmd ${CMAKE_COMMAND} -E env "${_path}" "${POLYORCH_RUST_CARGO}" ${_tail})
    else()
        set(_cmd "${POLYORCH_RUST_CARGO}" ${_tail})
    endif()
    set(${CMD_OUT} "${_cmd}" PARENT_SCOPE)
endfunction()

# polyorch_rust_build(TARGET <n> PACKAGE <p> CRATE <c>
#                     [BINARY|STATIC|SHARED] [PROFILE <p>] [FEATURES a;b]
#                     [LOCKED|FROZEN] [MANIFEST <path>] [DEPENDS <t>...]
#                     [BASE_DIR <td>] [FOLDER <ide>])
# Registers <TARGET> as an IMPORTED target pointing at the cargo artifact
# built into ${CMAKE_BINARY_DIR}/.cargo-target/<profile>/, plus a non-imported
# <TARGET>-cargo custom target that owns the rule (IMPORTED targets reject
# add_dependencies, hence the mediator -- the corrosion trick). Build it, or
# add_dependencies(<consumer> <TARGET>-cargo) from the consumer: the mediator
# is deliberately NOT built by ALL.
# install stamp). MANIFEST doubles as the rule's file dependency.
# BASE_DIR relocates the cargo target dir (pixi ENVIRONMENTS_DIR-style
# redirects); test and clean accept the same keyword, so the trio always agrees.
function(polyorch_rust_build)
    set(_opts BINARY STATIC SHARED LOCKED FROZEN)
    set(_one TARGET PACKAGE CRATE PROFILE MANIFEST BASE_DIR FOLDER)
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

    # Optional keywords are passed only when set: an empty quoted value
    # trips policy CMP0174's author warning on every configure.
    set(_optargs "")
    if(B_PROFILE)
        list(APPEND _optargs PROFILE "${B_PROFILE}")
    endif()
    _polyorch_rust_target_dir(_td "${B_BASE_DIR}")
    _polyorch_rust_artifact_names(TRIPLE "${POLYORCH_RUST_HOST_TARGET}"
        KIND "${_kind}" CRATE "${B_CRATE}" ${_optargs} BASE_DIR "${_td}"
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
    set(_csopts "")
    if(B_PROFILE)
        list(APPEND _csopts PROFILE "${B_PROFILE}")
    endif()
    if(B_FEATURES)
        list(APPEND _csopts FEATURES "${B_FEATURES}")
    endif()
    if(B_MANIFEST)
        list(APPEND _csopts MANIFEST "${B_MANIFEST}")
    endif()
    _polyorch_rust_cargo_args(PACKAGE "${B_PACKAGE}" KIND "${_kind}"
        CRATE "${B_CRATE}" ${_csopts} ${_flags} ARGO_OUT _argv)
    list(APPEND _argv --target-dir "${_td}")
    _polyorch_rust_command(_cmd SUBCOMMAND ${_argv})

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
        VERBATIM)
    add_custom_target("${B_TARGET}-cargo" DEPENDS "${_artifact}")
    if(B_DEPENDS)
        add_dependencies("${B_TARGET}-cargo" ${B_DEPENDS})
    endif()

    if(_kind STREQUAL "bin")
        add_executable("${B_TARGET}" IMPORTED GLOBAL)
    else()
        add_library("${B_TARGET}" UNKNOWN IMPORTED GLOBAL)
    endif()
    set_target_properties("${B_TARGET}" PROPERTIES IMPORTED_LOCATION "${_artifact}")
    if(_implib)
        set_target_properties("${B_TARGET}" PROPERTIES IMPORTED_IMPLIB "${_implib_path}")
    endif()
    if(B_FOLDER)
        # both halves of the pair join the same IDE folder: the imported handle
        # consumers link, and the <TARGET>-cargo mediator they build.
        set_target_properties("${B_TARGET}" "${B_TARGET}-cargo"
            PROPERTIES FOLDER "${B_FOLDER}")
    endif()
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
