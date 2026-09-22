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
# polyorch_rust_install() stages built artifacts (per-kind destination
# overrides, permission/component/configuration gating, PUBLIC_HEADER
# sidecars) and, with EXPORT, emits a <name>-rust.cmake replay stub plus
# a <name>Config.cmake find_package wrapper for second-stage consumers;
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
# the WP6 import-time build-face defaults PolyOrch_RUST_ALL_FEATURES /
# PolyOrch_RUST_NO_DEFAULT_FEATURES / PolyOrch_RUST_CARGO_FLAGS /
# PolyOrch_RUST_VERBOSE / PolyOrch_RUST_NO_USES_TERMINAL /
# PolyOrch_RUST_DEFAULT_KINDS apply when the per-target knob is absent
# (corr:690-700 + CORROSION_VERBOSE_OUTPUT corr:21 shape; the inverse
# terminal polarity kept exactly); public functions are polyorch_rust_*.
# Package versions surface via polyorch_rust_package_version as
# POLYORCH_RUST_PKG_<name>_VERSION (closes the deferred-register line).
#
# Cross-target routing (WP5): a consumed PolyOrch_RUST_CARGO_TARGET routes
# every build/test rule through --target=<tup> with the .cargo-target/<tup>/
# artifact namespace, an UNSTAMPED mediator (the hostbuild property flips the
# artifact layer at generate/defer time -- a stamped OUTPUT cannot), cc-rs
# env forwarding (corr:779-833), and the WP5b linker control plane
# (CARGO_TARGET_<TUP>_LINKER/_RUNNER via _polyorch_rust_linker_entries + the
# explicit PolyOrch_RUST_LINKER_<UP> cache knob), polyorch_rust_set_hostbuild
# and polyorch_rust_link_libraries. The HOST layer (empty triple) stays the
# byte-locked pre-WP5 shape.
# Out of scope by design (add a `ponytail:` note at the seam when needed):
# rust-version enforcement, cargo
# bench/fmt/clippy wrappers, and install-time relocations. Multi-config
# generators are supported (WP4): the profile keys on $<CONFIG>, the
# IMPORTED locations are per-CFG, and output-directory properties stage
# copies -- see _polyorch_rust_finalize below.
#
# Include-time contract: zero side effects -- definitions and comments only.
# Requires CMake >= 3.25 (PARSE_ARGV, NO_CACHE find_program, cmake_path).

include_guard(GLOBAL)

#
# Module organization (2026-09-22 ruling): toolchain discovery, triple
# families, artifact naming, native-libs probing and the cargo command
# wrapper live in PolyOrchFindRust.cmake (included below); this file holds
# the build-graph API (build/import/setters/test/run/clean/install).
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}")
include(PolyOrchFindRust)

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

# Internal: the USES_TERMINAL choice for cargo-carrying rules (WP6). Inverse
# polarity of the reference kept exactly (corr:696-700, applied at corr:915/
# 948): the default ASKS FOR the console; PolyOrch_RUST_NO_USES_TERMINAL
# removes it. Makefiles carry no textual trace of the option (measured on
# 4.4.3 -- it is a no-op there); a Ninja custom-command edge gains
# "pool = console". t-rust-knobs asserts both generated-text halves.
function(_polyorch_rust_uterm OUT)
    if(PolyOrch_RUST_NO_USES_TERMINAL)
        set(${OUT} "" PARENT_SCOPE)
    else()
        set(${OUT} USES_TERMINAL PARENT_SCOPE)
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
        # --- WP6 default kinds ------------------------------------------
        # No kind keyword: consult PolyOrch_RUST_DEFAULT_KINDS (default
        # STATIC;SHARED) and dispatch through this SAME single-kind
        # machinery -- one full build per kind, handles <TARGET>-static /
        # -shared / -exe (the import dual-kind pairing convention, so
        # mediators, shims, folders and the PIT-13 guard behave per
        # dispatched handle and the collision guard keeps its meaning).
        # A kind-less build therefore yields SUFFIXED handles only: the
        # bare TARGET name is never a target. Reference deviation
        # (ledgered): corrosion has no build-time default-kind surface --
        # its BUILD_SHARED_LIBS gate (corr:539-548) picks which member of
        # an already-built pair the umbrella target links. An EXPLICITLY
        # EMPTY list opts out: the historical FATAL stays the verdict.
        if(DEFINED PolyOrch_RUST_DEFAULT_KINDS AND
           PolyOrch_RUST_DEFAULT_KINDS STREQUAL "")
            message(FATAL_ERROR
                "polyorch_rust_build: pick exactly one of BINARY, STATIC, SHARED")
        endif()
        set(_dk "${PolyOrch_RUST_DEFAULT_KINDS}")
        if(NOT _dk)
            set(_dk STATIC SHARED)
        endif()
        set(_dkw "")
        foreach(_d ${_dk})
            string(TOLOWER "${_d}" _dl)
            if(NOT _dl MATCHES "^(bin|static|shared)$")
                message(FATAL_ERROR
                    "polyorch_rust_build: PolyOrch_RUST_DEFAULT_KINDS entry "
                    "'${_d}' is not one of bin|static|shared")
            endif()
            list(APPEND _dkw "${_dl}")
        endforeach()
        set(_fwd "")
        foreach(_v PROFILE MANIFEST BASE_DIR FOLDER PREBUILD)
            if(B_${_v})
                list(APPEND _fwd ${_v} "${B_${_v}}")
            endif()
        endforeach()
        if(B_FEATURES)
            list(APPEND _fwd FEATURES "${B_FEATURES}")
        endif()
        if(B_DEPENDS)
            list(APPEND _fwd DEPENDS "${B_DEPENDS}")
        endif()
        if(B_LOCKED)
            list(APPEND _fwd LOCKED)
        endif()
        if(B_FROZEN)
            list(APPEND _fwd FROZEN)
        endif()
        foreach(_dl ${_dkw})
            if(_dl STREQUAL "bin")
                polyorch_rust_build(TARGET "${B_TARGET}-exe"
                    PACKAGE "${B_PACKAGE}" CRATE "${B_CRATE}" BINARY ${_fwd})
            elseif(_dl STREQUAL "static")
                polyorch_rust_build(TARGET "${B_TARGET}-static"
                    PACKAGE "${B_PACKAGE}" CRATE "${B_CRATE}" STATIC ${_fwd})
            else()
                polyorch_rust_build(TARGET "${B_TARGET}-shared"
                    PACKAGE "${B_PACKAGE}" CRATE "${B_CRATE}" SHARED ${_fwd})
            endif()
        endforeach()
        return()
    endif()
    _polyorch_rust_require_setup(polyorch_rust_build)

    # WP6 global-default contradiction gate: the seeded ALL_FEATURES default
    # and this call's FEATURES would generate the exact argv pair the
    # setter rejects. Per-target override route: polyorch_rust_set_features
    # replaces all three feature properties (write-through).
    if(B_FEATURES AND PolyOrch_RUST_ALL_FEATURES)
        message(FATAL_ERROR
            "polyorch_rust_build: FEATURES and PolyOrch_RUST_ALL_FEATURES are mutually exclusive")
    endif()

    # --- WP5 cross routing ----------------------------------------------------
    # The consumed cross triple (empty = the host layer, byte-locked by
    # t-rust-artifact-paths). When set:
    #  * the rule carries --target=<tup>, suppressed per-invocation by the
    #    mediator's POLYORCH_RUST_HOST_BUILD property (a genex like every
    #    other deferred input, so the setter works after declaration);
    #  * artifacts live one level deeper (.cargo-target/<tup>/<profile>/) --
    #    cargo's own --target nesting -- and the file-name family follows
    #    the cross triple;
    #  * the mediator is an UNSTAMPED custom target (the reference's shape:
    #    its _cargo-build target carries no OUTPUT precisely because the
    #    artifact path depends on the late hostbuild property -- corr:915-920
    #    comment). Re-invocation is cargo-fingerprint-bounded. Deviation
    #    versus the stamped host rule, ledgered.
    set(_xtup "")
    if(POLYORCH_RUST_CARGO_TARGET)
        set(_xtup "${POLYORCH_RUST_CARGO_TARGET}")
    endif()
    set(_name_triple "${POLYORCH_RUST_HOST_TARGET}")
    set(_xseg "")
    if(_xtup)
        set(_name_triple "${_xtup}")
        set(_xseg "${_xtup}/")
    endif()

    # --- profile resolution (corr:762/772 semantics) -------------------------
    # No explicit PROFILE: cargo's debug profile follows Debug, release
    # follows any other value. SINGLE-CONFIG resolves LITERALLY at configure
    # -- flag, artifact directory and rule stamp are all equal strings.
    # The literal pairing is LOCKED behaviour (t-rust-artifact-paths pins the
    # naming-table dir, t-rust-import-ws pins $<TARGET_FILE> against it, and
    # the corr:905-909 stamp/desync argument keeps literal stamping the
    # honest choice for Makefiles/Ninja).
    # MULTI-CONFIG (WP4, port of corr:762 + corr:772): CMAKE_BUILD_TYPE is
    # empty there, so the profile is keyed on $<CONFIG> per build instead --
    # the rule carries the conditional --release flag and the artifact
    # directory carries $<IF:$<CONFIG:Debug>,debug,release>. The cargo
    # target dir stays the SHARED .cargo-target base (deviation from
    # corr:675-686's per-$<CONFIG> target dir, ledgered): cargo's own
    # profile directories already segregate the configs one level deeper,
    # which keeps the single-config layout byte-stable and makes
    # RelWithDebInfo share cargo's release profile exactly like the
    # reference's flag does.
    # R-3 version floors: the resolved debug/release behaviour above is
    # verified on this host's toolchain only -- cmake 4.4.3 and cargo
    # 1.98.1 (pixi env, measured 2026-09-21, the exact binaries the e2e
    # suite drives). Any lower cargo ceiling for --profile/--features
    # equals-form handling is TBD (not probed here; do not cite a number).
    set(_mc FALSE)
    if(CMAKE_CONFIGURATION_TYPES AND NOT B_PROFILE)
        set(_mc TRUE)
    endif()
    if(B_PROFILE)
        set(_prof "${B_PROFILE}")
    elseif(_mc)
        set(_prof "per-config")
    else()
        string(TOLOWER "${CMAKE_BUILD_TYPE}" _bt)
        if(_bt STREQUAL "" OR _bt STREQUAL "debug")
            set(_prof debug)
        else()
            set(_prof release)
        endif()
    endif()
    # WP9: DIRECTORY form of the profile (dev -> debug, the same mapping the
    # naming table applies; the `per-config` sentinel and custom names pass
    # through). The argv flag and the POLYORCH_RUST_PROFILE property keep the
    # profile NAME -- only the artifact directory is normalized.
    set(_pdir "${_prof}")
    if(_pdir STREQUAL "dev")
        set(_pdir debug)
    endif()
    _polyorch_rust_target_dir(_td "${B_BASE_DIR}")
    _polyorch_rust_artifact_names(TRIPLE "${_name_triple}"
        KIND "${_kind}" CRATE "${B_CRATE}" PROFILE "${_prof}" BASE_DIR "${_td}"
        TARGET "${_xtup}"
        FILE_OUT _file IMPLIB_OUT _implib)
    if(_mc)
        set(_dir "${_td}/${_xseg}$<IF:$<OR:$<CONFIG:Debug>,$<CONFIG:>>,debug,release>")
    else()
        set(_dir "${_td}/${_xseg}${_pdir}")   # == artifact_names DIR_OUT contract
    endif()
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
    # WP9 fidelity fix (corr:702-727): the reference wraps every deferred
    # build-input property read in GENEX_EVAL, so a generator expression a
    # user stores INSIDE the property value -- the app_features and
    # INDIRECT_VAR_TEST shapes of test/features / test/envvar -- expands at
    # generate time. A bare $<TARGET_PROPERTY> returns list values raw, and
    # a nested genex then survives LITERALLY into the cargo argv (measured).
    set(_feat_p "$<GENEX_EVAL:$<TARGET_PROPERTY:${_med},POLYORCH_RUST_FEATURES>>")
    set(_allf_p "$<GENEX_EVAL:$<TARGET_PROPERTY:${_med},POLYORCH_RUST_ALL_FEATURES>>")
    set(_nondf_p "$<GENEX_EVAL:$<TARGET_PROPERTY:${_med},POLYORCH_RUST_NO_DEFAULT_FEATURES>>")
    set(_features_gx "$<$<BOOL:${_feat_p}>:--features=$<JOIN:${_feat_p},,>>")
    set(_allf_gx "$<$<BOOL:${_allf_p}>:--all-features>")
    set(_nondf_gx "$<$<BOOL:${_nondf_p}>:--no-default-features>")
    set(_flags_gx "$<GENEX_EVAL:$<TARGET_PROPERTY:${_med},POLYORCH_RUST_CARGO_FLAGS>>")
    set(_env_gx "$<GENEX_EVAL:$<TARGET_PROPERTY:${_med},POLYORCH_RUST_ENV_VARS>>")

    # Optional keywords are passed only when set: an empty quoted value
    # trips policy CMP0174's author warning on every configure.
    set(_mankw "")
    if(B_MANIFEST)
        set(_mankw MANIFEST "${B_MANIFEST}")
    endif()
    set(_argprof "${_prof}")
    if(_mc)
        # MC auto-profile: no literal profile flag -- the conditional
        # --release (corr:762 verbatim) rides the argv instead; "debug" makes
        # the pure builder emit its no-flag default.
        set(_argprof debug)
    endif()
    _polyorch_rust_cargo_args(PACKAGE "${B_PACKAGE}" KIND "${_kind}"
        CRATE "${B_CRATE}" PROFILE "${_argprof}" ${_mankw} ${_flags} ARGO_OUT _argv)
    if(_mc)
        list(APPEND _argv "$<$<NOT:$<OR:$<CONFIG:Debug>,$<CONFIG:>>>:--release>")
    endif()

    # WP6 verbose: the global CORROSION_VERBOSE_OUTPUT analogue
    # (corr:21,588-589,891): --verbose on the cargo BUILD command only --
    # the reference gates no metadata/probe call with it, mirrored exactly.
    if(PolyOrch_RUST_VERBOSE)
        list(APPEND _argv --verbose)
    endif()
    list(APPEND _argv "${_features_gx}" "${_allf_gx}" "${_nondf_gx}" "${_flags_gx}")
    list(APPEND _argv --target-dir "${_td}")
    set(_hb "$<NOT:$<BOOL:$<TARGET_PROPERTY:${_med},POLYORCH_RUST_HOST_BUILD>>>")
    if(_xtup)
        # hostbuild gate: with the property TRUE the flag elides (an empty
        # argument vanishes under VERBATIM -- the proven pattern above).
        list(APPEND _argv "$<${_hb}:--target=${_xtup}>")
    endif()

    # --- WP5 cc-rs forwarding + WP5b linker plane (corr:779-833, 852-857) ----
    # Literal ENV material assembled per rule; the command wrapper guarantees
    # the --unset strip runs FIRST and these entries trail it (contract at
    # _polyorch_rust_command; t-rust-crossplan pins the order in generated
    # text). The forwarding trio is keyed to the EFFECTIVE triple, so a
    # hostbuild flip simply leaves the cross names unused (no gating needed).
    set(_sys "")
    if(_xtup AND CMAKE_CROSSCOMPILING AND CMAKE_SYSROOT)
        set(_sys "${CMAKE_SYSROOT}")
    endif()
    set(_osxsys "")
    set(_depver "")
    if(APPLE)
        set(_osxsys "${CMAKE_OSX_SYSROOT}")
        set(_depver "${CMAKE_OSX_DEPLOYMENT_TARGET}")
    endif()
    _polyorch_rust_forward_env(TRIPLE "${_name_triple}" SYSROOT "${_sys}"
        OSX_SYSROOT "${_osxsys}" DEPLOYMENT_TARGET "${_depver}"
        OUT_ENV _fwd_x OUT_LINK_ARGS _la_x)
    if(_xtup)
        # corr:860-867 shape (the honest non-msvc linker ADDITION): a
        # triple-targeted C/C++ toolchain (clang --target=...) must have its
        # target forwarded to the linker rustc invokes. Variable-presence
        # gated, and skipped when the explicit linker knob owns the link
        # (corr's "explicit property unset when this function runs" caveat
        # inverts for us: the cache knob is a static read). msvc is
        # unreachable -- the builder emitted no list.
        _polyorch_rust_triple_env_form("${_xtup}" _xtup_up)
        if((CMAKE_C_COMPILER_TARGET OR CMAKE_CXX_COMPILER_TARGET)
                AND NOT PolyOrch_RUST_LINKER_${_xtup_up})
            set(_ct "${CMAKE_C_COMPILER_TARGET}")
            if(NOT _ct)
                set(_ct "${CMAKE_CXX_COMPILER_TARGET}")
            endif()
            list(APPEND _la_x "--target=${_ct}")
        endif()
    endif()
    # Each link argument becomes its OWN -Clink-arg= token (RUSTFLAGS is
    # whitespace-split by cargo; a joined multi-arg -Clink-args= would
    # fragment -- corr passes theirs through `cargo rustc --` instead, a
    # surface PolyOrch does not have).
    set(_fwd_largs "")
    foreach(_la ${_la_x})
        string(APPEND _fwd_largs " -Clink-arg=${_la}")
    endforeach()
    string(STRIP "${_fwd_largs}" _fwd_largs)
    set(_fwd "${_fwd_x}")
    if(_xtup)
        # The host-keyed trio rides too (corr:809-819 host-target env
        # precedent): a hostbuild flip builds the host triple through the
        # SAME rule, and cc-rs then reads the host-keyed names. Distinct
        # names are guaranteed -- setup normalized host-equal routes to "".
        # No sysroot on the host names: the cross sysroot belongs to the
        # cross key only (and a host --sysroot would be wrong by
        # construction on a non-cross compile).
        _polyorch_rust_forward_env(TRIPLE "${POLYORCH_RUST_HOST_TARGET}"
            SYSROOT "" OSX_SYSROOT "" DEPLOYMENT_TARGET ""
            OUT_ENV _fwd_h)
        set(_fwd "${_fwd_h};${_fwd_x}")
    endif()
    _polyorch_rust_linker_entries("${_med}" _lnk)

    # Composed RUSTFLAGS entry: the user's property FIRST (byte-identical to
    # the pre-WP5 shape when it alone is set -- locked by t-rust-setters),
    # then link_libraries' -L/-l terms, then the hostbuild-gated sysroot
    # link-args. ONE assignment: two KEY=VAL entries would let the last
    # silently win. The whole entry elides when every part is empty -- an
    # empty RUSTFLAGS= would override a config.toml rustflags (measured,
    # cmake -E env sets it for real).
    set(_ll_gx "$<JOIN:$<TARGET_GENEX_EVAL:${_med},$<TARGET_PROPERTY:${_med},POLYORCH_RUST_LINK_LIBRARIES>>, >")
    set(_ld_gx "$<TARGET_GENEX_EVAL:${_med},$<TARGET_PROPERTY:${_med},POLYORCH_RUST_LINK_DIRS>>")
    # GENEX_EVAL (string semantics), NOT TARGET_GENEX_EVAL: the property is a
    # configure-time SPACE-JOINED string (polyorch_rust_add_rustflags), and
    # TGE would re-list its quoted elements -- a key="value" flag then
    # mis-parses the genex boundary (measured: stray '>' + argv splits).
    set(_rf_up "$<GENEX_EVAL:$<TARGET_PROPERTY:${_med},POLYORCH_RUST_RUSTFLAGS>>")
    set(_rf_entry "$<$<OR:$<BOOL:${_rf_up}>,$<BOOL:${_ll_gx}>,$<AND:$<BOOL:${_fwd_largs}>,${_hb}>>:RUSTFLAGS=${_rf_up}")
    string(APPEND _rf_entry "$<$<BOOL:${_ll_gx}>: ${_ll_gx}>")
    if(_fwd_largs)
        string(APPEND _rf_entry "$<${_hb}: ${_fwd_largs}>")
    endif()
    string(APPEND _rf_entry ">")
    # LIBRARY_PATH so cc-rs in build scripts finds the link_libraries dirs
    # (corr:748-757 rationale: RUSTFLAGS' -L never reaches build-script
    # linking). ':' join -- a Windows ';' form is deferred until a windows
    # validation leg exists (ledgered).
    set(_lp_entry "$<$<BOOL:${_ld_gx}>:LIBRARY_PATH=$<JOIN:${_ld_gx},:>>")
    _polyorch_rust_command(_cmd SUBCOMMAND ${_argv}
        ENV "${_fwd}" "${_lnk}" "${_lp_entry}" "${_env_gx}" "${_rf_entry}")

    set(_byproducts "")
    set(_implib_path "")
    if(_implib)
        # gnullvm: cargo emits the import library under deps/, not the
        # profile root (corr:334-337) -- the BYPRODUCTS stamp follows the
        # real source location so the rule stays honest there.
        set(_implib_path "${_dir}/${_implib}")
        if(_name_triple MATCHES "gnullvm$")
            set(_implib_path "${_dir}/deps/${_implib}")
        endif()
        set(_byproducts BYPRODUCTS "${_implib_path}")
    endif()
    set(_depfiles "")
    if(B_MANIFEST)
        set(_depfiles DEPENDS "${B_MANIFEST}")
    endif()

    _polyorch_rust_uterm(_uterm)
    # Primary mediator: owns the rule and carries the POLYORCH_RUST_* build
    # inputs. Deliberately NOT ALL -- consumers reach it through the
    # auto-build edge below or the polyorch-rust-all aggregate.
    if(_xtup)
        # Cross layer: NO OUTPUT stamp (the path depends on the late
        # hostbuild property -- the reference reaches the same conclusion
        # and stamps nothing, corr:915-920). The manifest rides as a plain
        # prerequisite; re-invocation is cargo-fingerprint-bounded.
        add_custom_target("${_med}"
            COMMAND ${_cmd}
            WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
            ${_depfiles}
            COMMENT "cargo build ${B_PACKAGE} (${_kind}, target ${_xtup})"
            COMMAND_EXPAND_LISTS
            ${_uterm}
            VERBATIM)
    else()
        # Host layer: file-stamp granularity -- cargo's own fingerprint
        # decides whether an invocation recompiles; source files never enter
        # DEPENDS. LOCKED shape (t-rust-artifact-paths).
        add_custom_command(OUTPUT "${_artifact}" ${_byproducts}
            COMMAND ${_cmd}
            WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
            ${_depfiles}
            COMMENT "cargo build ${B_PACKAGE} (${_kind})"
            COMMAND_EXPAND_LISTS
            ${_uterm}
            VERBATIM)
        add_custom_target("${_med}" DEPENDS "${_artifact}")
    endif()
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
    # WP6 import-time global defaults: the PolyOrch_RUST_* cache knobs seed
    # the SAME property carriers the setters write -- defaults, not
    # overrides: a later polyorch_rust_set_features call replaces what
    # build() initialised (its documented write-through), a raw
    # set_property likewise, and add_cargo_flags APPENDS after the seeded
    # global flags. Unset knobs expand to "" = the pre-WP5 byte shape.
    set_property(TARGET "${_med}" PROPERTY POLYORCH_RUST_ALL_FEATURES "${PolyOrch_RUST_ALL_FEATURES}")
    set_property(TARGET "${_med}" PROPERTY POLYORCH_RUST_NO_DEFAULT_FEATURES "${PolyOrch_RUST_NO_DEFAULT_FEATURES}")
    set_property(TARGET "${_med}" PROPERTY POLYORCH_RUST_CARGO_FLAGS "${PolyOrch_RUST_CARGO_FLAGS}")
    set_property(TARGET "${_med}" PROPERTY POLYORCH_RUST_RUSTFLAGS "")
    set_property(TARGET "${_med}" PROPERTY POLYORCH_RUST_ENV_VARS "")
    # WP5/WP5b routing carriers (all genex-consumed, all late-settable).
    set_property(TARGET "${_med}" PROPERTY POLYORCH_RUST_HOST_BUILD "")
    set_property(TARGET "${_med}" PROPERTY POLYORCH_RUST_LINK_LIBRARIES "")
    set_property(TARGET "${_med}" PROPERTY POLYORCH_RUST_LINK_LANGS "")
    set_property(TARGET "${_med}" PROPERTY POLYORCH_RUST_LINK_DIRS "")

    if(_kind STREQUAL "bin")
        add_executable("${B_TARGET}" IMPORTED GLOBAL)
    else()
        add_library("${B_TARGET}" UNKNOWN IMPORTED GLOBAL)
    endif()
    # Eager locations: the in-place cargo paths. The deferred finalize
    # registered at the end of this function REWRITES them from the late
    # property read -- but polyorch_rust_install() reads these at
    # configure time, so eager values must exist.
    set_target_properties("${B_TARGET}" PROPERTIES IMPORTED_LOCATION "${_artifact}")
    if(_implib)
        set_target_properties("${B_TARGET}" PROPERTIES IMPORTED_IMPLIB "${_implib_path}")
    endif()
    # Cachevar leg (port of corr:2313-2321 _corrosion_initialize_properties):
    # an IMPORTED target never consults CMAKE_*_OUTPUT_DIRECTORY on its own
    # (measured 4.4.3) and the finalize reads PROPERTIES, so mirror the
    # variables (and per-config ones) onto the handle at creation.
    # PDB_OUTPUT_DIRECTORY is not ported: the v0 rust face emits no pdb.
    foreach(_ov RUNTIME ARCHIVE LIBRARY)
        if(DEFINED CMAKE_${_ov}_OUTPUT_DIRECTORY)
            set_property(TARGET "${B_TARGET}" PROPERTY
                "${_ov}_OUTPUT_DIRECTORY" "${CMAKE_${_ov}_OUTPUT_DIRECTORY}")
        endif()
        foreach(_cfg ${CMAKE_CONFIGURATION_TYPES})
            string(TOUPPER "${_cfg}" _cfgu)
            if(DEFINED CMAKE_${_ov}_OUTPUT_DIRECTORY_${_cfgu})
                set_property(TARGET "${B_TARGET}" PROPERTY
                    "${_ov}_OUTPUT_DIRECTORY_${_cfgu}"
                    "${CMAKE_${_ov}_OUTPUT_DIRECTORY_${_cfgu}}")
            endif()
        endforeach()
    endforeach()
    # Registry marker on the consumer-facing handle (mirrors what
    # polyorch_rust_import already set there), so polyorch_rust_install
    # validates handles from both registration paths the same way.
    set_property(TARGET "${B_TARGET}" PROPERTY POLYORCH_RUST_PACKAGE "${B_PACKAGE}")
    # WP7: the manifest path rides the handle too (the reference's
    # INTERFACE_COR_PACKAGE_MANIFEST_PATH role, corr:1808/2116) -- read by
    # polyorch_rust_cxxbridge / polyorch_rust_cbindgen for their auto-mode
    # version derivation, package resolution and WORKING_DIRECTORY.
    if(B_MANIFEST)
        set_property(TARGET "${B_TARGET}" PROPERTY
            POLYORCH_RUST_MANIFEST "${B_MANIFEST}")
    endif()
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
    # WP4 deferred finalize: late-read the output-directory properties and
    # re-shape the IMPORTED locations (per-CFG on multi-config), staging a
    # POST_BUILD copy into any expressed output dir. Reference shape
    # corr:251-262; see _polyorch_rust_finalize.
    _polyorch_rust_finalize("${B_TARGET}" "${POLYORCH_RUST_HOST_TARGET}"
        "${_xtup}" "${_kind}" "${B_CRATE}" "${_td}" "${_pdir}" "${_mc}")
endfunction()

# ---------------------------------------------------------------------------
# WP4 output-directory machinery.
# Adapted from corrosion (MIT, commit c4786e7): cmake/Corrosion.cmake:130-376
# (+ corr:675-686,762-773,905-909 for the rule shape) -- per-config output-
# directory resolution, deferred IMPORTED_LOCATION(_<CFG>) / IMPORTED_IMPLIB
# (_<CFG>) setting and POST_BUILD copy staging. No wholesale copy; the
# mirrored mechanisms and their deviations are ledgered in
# docs/reference/corrosion-port-ledger.md.
# ---------------------------------------------------------------------------
# Internal: registration wrapper for the deferred finalize. The EVAL CODE
# + [[...]] wrapper is the reference's late-expansion shape (corr:251-262,
# 365-376): the ${} references expand NOW, the text re-parses at the end
# of the configure stage, and each [[...]] argument survives the deferral
# as a single semicolon-safe value.
function(_polyorch_rust_finalize target triple xtup kind crate td prof mc)
    cmake_language(EVAL CODE "
        cmake_language(DEFER CALL
            _polyorch_rust_finalize_deferred
            [[${target}]] [[${triple}]] [[${xtup}]] [[${kind}]] [[${crate}]]
            [[${td}]] [[${prof}]] [[${mc}]])")
endfunction()

# Internal: resolve one output-directory property into the staging
# directory for one config -- behaviour-identical to the per-config block
# of corr:176-200: PROP_<CFG> wins when set; else the base PROP, to which
# the config name is APPENDED under a multi-config generator when the
# value is genex-free (CMake's own MC default-path rule, corr:184-191);
# a $<CONFIG>-carrying value is used as-is. Single-config reads the base
# property only (corr:211-223). $<CONFIG> substitution and foreign-genex
# rejection run through _polyorch_rust_sanitized_out_dir (corr:139-147);
# a violation is a FATAL here (corr:196-199). OUT receives "" when the
# user expressed no directory -- PolyOrch then keeps the in-place cargo
# location (deviation from the reference's CMAKE_CURRENT_BINARY_DIR
# default: the locked single-config contract pins $<TARGET_FILE> at the
# cargo path, and MC in-place paths are per-config-correct anyway).
function(_polyorch_rust_role_outdir target prop cfg mc out)
    set(_d "")
    get_target_property(_b "${target}" "${prop}")
    if(_b AND NOT _b STREQUAL "NOTFOUND")
        set(_d "${_b}")
    endif()
    if(mc)
        string(TOUPPER "${cfg}" _cu)
        get_target_property(_pc "${target}" "${prop}_${_cu}")
        if(_pc)
            set(_d "${_pc}")               # already config-specific
        elseif(_d)
            string(GENEX_STRIP "${_d}" _bn)
            if(_d STREQUAL _bn)
                set(_d "${_d}/${cfg}")     # CMake's MC append (corr:187-188)
            endif()
        endif()
    endif()
    if(_d STREQUAL "")
        set(${out} "" PARENT_SCOPE)
        return()
    endif()
    _polyorch_rust_sanitized_out_dir("${_d}" "${cfg}" _ds)
    if(NOT DEFINED _ds)
        message(FATAL_ERROR
            "polyorch_rust: ${prop} of target ${target} contains an "
            "unsupported generator expression (output: '${_d}'); only "
            "\$<CONFIG> is supported in output directories.")
    endif()
    set(${out} "${_ds}" PARENT_SCOPE)
endfunction()

# Internal: one (role, config) pass of the finalizer. OUT_LOC receives the
# location for this config -- the staged file path, or the in-place cargo
# path (copy_plan is the single source of truth for the latter, which is
# what puts a gnullvm importlib under deps/). OUT_SRC/OUT_DIR carry the
# staging pair and are empty when no output directory is expressed.
function(_polyorch_rust_finalize_pass target triple crate td tseg prof oprop f ck cfg mc out_loc out_src out_dir)
    if(NOT "${prof}" STREQUAL "per-config")
        set(_pd "${prof}")
    elseif("${cfg}" STREQUAL "Debug")
        set(_pd debug)
    else()
        set(_pd release)   # corr:762/772: every non-Debug config -> release
    endif()
    # WP5: TARGET carries the cross segment ("" on the host layer); PROFILE
    # makes SRC_DIR the target-dir BASE (single construction site for both
    # layers -- see the copy-plan contract).
    _polyorch_rust_copy_plan(TRIPLE "${triple}" KIND "${ck}" CRATE "${crate}"
        SRC_DIR "${td}" TARGET "${tseg}" PROFILE "${_pd}"
        DEST_DIR "${td}/${_pd}" OUT _pr)
    string(REPLACE "|" ";" _pp "${_pr}")
    list(GET _pp 0 _src)
    _polyorch_rust_role_outdir("${target}" "${oprop}" "${cfg}" "${mc}" _dir)
    if(_dir STREQUAL "")
        set(${out_loc} "${_src}" PARENT_SCOPE)
        set(${out_src} "" PARENT_SCOPE)
        set(${out_dir} "" PARENT_SCOPE)
        return()
    endif()
    set(${out_loc} "${_dir}/${f}" PARENT_SCOPE)
    set(${out_src} "${_src}" PARENT_SCOPE)
    set(${out_dir} "${_dir}" PARENT_SCOPE)
endfunction()

# Internal: the deferred per-handle finalize -- corr:130-376 machinery in
# one pass (the reference's location loop corr:156-235 and copy staging
# corr:264-376 duplicate the same directory resolution, corr:294 comment;
# merging them keeps one truth). For every (role, config): late-read the
# output-directory property, set IMPORTED_LOCATION_<CFG> /
# IMPORTED_IMPLIB_<CFG> on multi-config (base property = last config, the
# reference's "last configuration wins", corr:229-234), and stage a
# POST_BUILD make_directory + copy_if_different into every expressed
# directory -- BYPRODUCTS carry literal file names on config-class genex
# dirs only (corr:905-909: target-specific genex are banned there, and
# the file-name half never carries a genex). WP5: a late read of the
# mediator's POLYORCH_RUST_HOST_BUILD re-selects the triple + the
# .cargo-target/<tup>/ segment, so a post-declaration hostbuild flip is
# honored by the locations (the cross rule is deliberately unstamped, so
# no build-system prerequisite strands).
function(_polyorch_rust_finalize_deferred target triple xtup kind crate td prof mc)
    if(ARGN)
        message(FATAL_ERROR
            "_polyorch_rust_finalize_deferred: unexpected additional arguments: ${ARGN}")
    endif()
    # WP5 late routing read: the hostbuild setter may have run AFTER
    # polyorch_rust_build, and this is the last moment it can still be
    # honored. TRUE falls the whole path resolution back to the host layer
    # (host file-name family, no .cargo-target/<tup>/ segment); the default
    # under a cross triple is the cross layer.
    get_target_property(_hb "cargo-build-${target}" POLYORCH_RUST_HOST_BUILD)
    set(_eff "${triple}")
    set(_seg "")
    if(xtup AND NOT _hb)
        set(_eff "${xtup}")
        set(_seg "${xtup}")
    endif()
    # File names from the frozen table (profile-independent; the
    # per-config sentinel and the WP5 triple segment only ever ride the
    # directory).
    _polyorch_rust_artifact_names(TRIPLE "${_eff}" KIND "${kind}"
        CRATE "${crate}" PROFILE "${prof}" FILE_OUT _file IMPLIB_OUT _implib)
    if("${kind}" STREQUAL "bin")
        set(_mprop RUNTIME_OUTPUT_DIRECTORY)
    elseif("${kind}" STREQUAL "static")
        set(_mprop ARCHIVE_OUTPUT_DIRECTORY)
    else()
        set(_mprop LIBRARY_OUTPUT_DIRECTORY)
    endif()
    # Roles: <imported-prop>|<output-dir-prop>|<file>|<copy-plan-kind>.
    # The implib row exists only for a Windows-family shared handle (the
    # naming table yields "" elsewhere), staged to ARCHIVE like corr:523-528.
    set(_roles "IMPORTED_LOCATION|${_mprop}|${_file}|${kind}")
    if("${kind}" STREQUAL "shared" AND NOT "${_implib}" STREQUAL "")
        list(APPEND _roles "IMPORTED_IMPLIB|ARCHIVE_OUTPUT_DIRECTORY|${_implib}|implib")
    endif()
    foreach(_role ${_roles})
        string(REPLACE "|" ";" _r "${_role}")
        list(GET _r 0 _iprop)
        list(GET _r 1 _oprop)
        list(GET _r 2 _f)
        list(GET _r 3 _ck)
        set(_srcs "")
        set(_dirs "")
        set(_byps "")
        set(_last "")
        if(mc)
            foreach(_cfg ${CMAKE_CONFIGURATION_TYPES})
                _polyorch_rust_finalize_pass("${target}" "${_eff}" "${crate}"
                    "${td}" "${_seg}" "${prof}" "${_oprop}" "${_f}" "${_ck}"
                    "${_cfg}" TRUE _loc _src _dir)
                if(_src)
                    list(APPEND _srcs "$<$<CONFIG:${_cfg}>:${_src}>")
                    list(APPEND _dirs "$<$<CONFIG:${_cfg}>:${_dir}>")
                    list(APPEND _byps "$<$<CONFIG:${_cfg}>:${_dir}/${_f}>")
                endif()
                string(TOUPPER "${_cfg}" _cu)
                set_property(TARGET "${target}" PROPERTY
                    "${_iprop}_${_cu}" "${_loc}")
                set(_last "${_loc}")
            endforeach()
        else()
            # One pass; CMAKE_BUILD_TYPE only feeds the $<CONFIG> rewrite.
            _polyorch_rust_finalize_pass("${target}" "${_eff}" "${crate}"
                "${td}" "${_seg}" "${prof}" "${_oprop}" "${_f}" "${_ck}"
                "${CMAKE_BUILD_TYPE}" FALSE _loc _src _dir)
            if(_src)
                set(_srcs "${_src}")
                set(_dirs "${_dir}")
                set(_byps "${_dir}/${_f}")
            endif()
            set(_last "${_loc}")
        endif()
        set_property(TARGET "${target}" PROPERTY "${_iprop}" "${_last}")
        if(_srcs)
            add_custom_command(TARGET "cargo-build-${target}" POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E make_directory ${_dirs}
                COMMAND ${CMAKE_COMMAND} -E copy_if_different ${_srcs} ${_dirs}
                BYPRODUCTS ${_byps}
                COMMENT "staging ${target} (${_f}) to the output directories"
                COMMAND_EXPAND_LISTS
                VERBATIM)
        endif()
    endforeach()
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

# Internal: pure reader of ONE package's version from
# `cargo metadata --format-version 1` JSON -- sibling of
# _polyorch_rust_metadata_targets over the same document. The reference's
# corrosion_parse_package_version (corr:2267-2309) instead file(READ)s the
# manifest and regexes the [package] table; deviation (ledgered): metadata
# is authoritative, needs no following table, and carries prerelease
# suffixes verbatim (the reference's [0-9.]+ regex would truncate them).
# OUT receives the version string and stays UNDEFINED when no package
# matches (the caller raises the error).
function(_polyorch_rust_metadata_package_version JSON PACKAGE OUT)
    string(JSON _np LENGTH "${JSON}" "packages")
    if(NOT _np GREATER 0)
        return()
    endif()
    math(EXPR _plast "${_np} - 1")
    foreach(_pi RANGE 0 ${_plast})
        string(JSON _pn GET "${JSON}" "packages" ${_pi} "name")
        if(_pn STREQUAL "${PACKAGE}")
            string(JSON _pv GET "${JSON}" "packages" ${_pi} "version")
            set(${OUT} "${_pv}" PARENT_SCOPE)
            return()
        endif()
    endforeach()
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
    # WP5 note: cargo metadata takes NO --target (measured: rc=1
    # "unexpected argument" on cargo 1.98.1). The probe is triple-free by
    # design -- with --no-deps the parser reads packages[].targets only,
    # never the platform-keyed dependency graph -- and every build rule the
    # replay creates carries the routing itself (see polyorch_rust_build).
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

# polyorch_rust_package_version(PACKAGE <p> [MANIFEST <path>] OUT_VAR <out>)
# Surface one cargo package's [package] version (reference:
# corrosion_parse_package_version, corr:2267-2309 -- naming-map + mechanism
# deviation on the port ledger; the deferred-register line "package-version
# exposure as a variable" closes with this function). A previously-resolved
# POLYORCH_RUST_PKG_<name>_VERSION cache entry (<p> with dashes normalized
# to underscores) answers WITHOUT invoking cargo; giving MANIFEST always
# re-reads that workspace (an explicit input beats the ambient cache).
# Otherwise runs `cargo metadata --no-deps --format-version 1` through the
# standard isolation wrapper -- deliberately NO --target (cargo metadata
# rejects it, measured 1.98.1; --no-deps reads only packages[]), in the
# manifest's directory or CMAKE_CURRENT_SOURCE_DIR without MANIFEST, so
# cargo's upward .cargo/config walk applies exactly like polyorch_rust_import.
# Failing metadata and an unknown package FATAL with polyorch_rust_import's
# own guard identities ("cargo metadata failed" / "no package '<p>' in the
# cargo metadata (available: ...)"), so callers grep one phrase family.
# OUT_VAR receives the version; the cache entry is written before returning
# so repeated calls re-resolve at most once.
function(polyorch_rust_package_version)
    set(_one PACKAGE MANIFEST OUT_VAR)
    cmake_parse_arguments(PARSE_ARGV 0 A "" "${_one}" "")
    if(A_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR
            "polyorch_rust_package_version: unknown args: ${A_UNPARSED_ARGUMENTS}")
    endif()
    _polyorch_rust_must(A_PACKAGE A_OUT_VAR)
    string(REPLACE "-" "_" _key "${A_PACKAGE}")
    set(_cvar "POLYORCH_RUST_PKG_${_key}_VERSION")
    if(NOT A_MANIFEST AND DEFINED ${_cvar})
        set(${A_OUT_VAR} "${${_cvar}}" PARENT_SCOPE)
        return()
    endif()
    _polyorch_rust_require_setup(polyorch_rust_package_version)
    set(_mankw "")
    set(_mdir "${CMAKE_CURRENT_SOURCE_DIR}")
    if(A_MANIFEST)
        set(_mankw --manifest-path "${A_MANIFEST}")
        get_filename_component(_mdir "${A_MANIFEST}" DIRECTORY)
    endif()
    _polyorch_rust_command(_cmd SUBCOMMAND
        metadata --no-deps --format-version 1 ${_mankw})
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
        set(_what "'${A_MANIFEST}'")
        if(NOT A_MANIFEST)
            set(_what "the workspace of '${_mdir}'")
        endif()
        message(FATAL_ERROR
            "polyorch_rust_package_version: cargo metadata failed (rc=${_rc}) for "
            "${_what}:\n${_etail}")
    endif()
    _polyorch_rust_metadata_package_version("${_out}" "${A_PACKAGE}" _v)
    if(NOT DEFINED _v)
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
        string(REPLACE ";" ", " _avail_s "${_avail}")
        message(FATAL_ERROR
            "polyorch_rust_package_version: no package '${A_PACKAGE}' in the cargo "
            "metadata (available: ${_avail_s})")
    endif()
    set(${_cvar} "${_v}" CACHE INTERNAL
        "PolyOrch rust package version (polyorch_rust_package_version)")
    set(${A_OUT_VAR} "${_v}" PARENT_SCOPE)
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

# polyorch_rust_set_hostbuild(TARGET <n>)
# Mark the declared handle's build HOST-BUILT (port of corr:1166-1172
# corrosion_set_hostbuild). Under an active cross route it (a) suppresses the
# rule's --target at generate time (mediator property genex -- later calls
# still land) and (b) makes the deferred finalize resolve the IMPORTED
# locations (and the file-name family) against the host .cargo-target layer.
# On a non-cross host the setter is observably a NO-OP versus the default --
# nothing targets a foreign triple to begin with; t-rust-crossplan asserts
# exactly that (no fakery) and t-rust-musl proves the distinct-directory
# fall-back under a real musl route. The eager (configure-time) locations set
# by polyorch_rust_build are cross-shaped until the finalize corrects them --
# a polyorch_rust_install of a hostbuild-flipped cross handle reads the
# stale-eager path (deviation, ledgered; polyorch_rust_install stays a
# host-layer surface in v0). Like the reference there is no DISABLED form:
# clear with a raw set_property(POLYORCH_RUST_HOST_BUILD "") if ever needed.
function(polyorch_rust_set_hostbuild)
    cmake_parse_arguments(PARSE_ARGV 0 A "" "TARGET" "")
    if(A_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR
            "polyorch_rust_set_hostbuild: unknown args: ${A_UNPARSED_ARGUMENTS}")
    endif()
    _polyorch_rust_must(A_TARGET)
    _polyorch_rust_mediator("polyorch_rust_set_hostbuild" "${A_TARGET}" _med)
    set_property(TARGET "${_med}" PROPERTY POLYORCH_RUST_HOST_BUILD TRUE)
endfunction()

# polyorch_rust_link_libraries(TARGET <n> <library|target|abs-path>...)
# Port of corr:1254-1310 corrosion_link_libraries, useful subset (the iOS
# EFFECTIVE_PLATFORM_NAME hack is not ported -- no Apple validation leg).
# STATIC-kind mediator: rust never invokes a linker for a staticlib, so the
# entries forward to the handle's own link interface instead (the reference's
# early-return shape, corr:1255-1264) -- APPEND keeps the probe-attached
# system libs intact. Otherwise each entry joins the rule's RUSTFLAGS entry
# through the POLYORCH_RUST_LINK_LIBRARIES mediator property (generate-time,
# like the other setters):
#   CMake target  -> -L$<TARGET_LINKER_FILE_DIR> + -l$<TARGET_LINKER_FILE_BASE_NAME>
#                    (+ LINKER_LANGUAGE recorded for the cross default-linker
#                    pick + an ordering edge on the mediator);
#   abs path      -> -Clink-arg=<path> (rustc verbatim-link form);
#   bare name     -> -l<name>.
# Limits shared with the reference: RUSTFLAGS is whitespace-split by cargo,
# so a linker-file directory containing a space breaks this path (a
# LIBRARY_PATH twin rides the same property for build-script linking).
function(polyorch_rust_link_libraries)
    cmake_parse_arguments(PARSE_ARGV 0 A "" "TARGET" "")
    _polyorch_rust_must(A_TARGET)
    if(NOT A_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR
            "polyorch_rust_link_libraries: at least one library is required")
    endif()
    _polyorch_rust_mediator("polyorch_rust_link_libraries" "${A_TARGET}" _med)
    get_target_property(_kind "${_med}" POLYORCH_RUST_KIND)
    if(_kind STREQUAL "static")
        set_property(TARGET "${A_TARGET}" APPEND PROPERTY
            INTERFACE_LINK_LIBRARIES "${A_UNPARSED_ARGUMENTS}")
        return()
    endif()
    foreach(_lib IN LISTS A_UNPARSED_ARGUMENTS)
        if(TARGET "${_lib}")
            set_property(TARGET "${_med}" APPEND PROPERTY
                POLYORCH_RUST_LINK_LIBRARIES
                "-L$<TARGET_LINKER_FILE_DIR:${_lib}>"
                "-l$<TARGET_LINKER_FILE_BASE_NAME:${_lib}>")
            set_property(TARGET "${_med}" APPEND PROPERTY
                POLYORCH_RUST_LINK_DIRS
                "$<TARGET_LINKER_FILE_DIR:${_lib}>")
            set_property(TARGET "${_med}" APPEND PROPERTY
                POLYORCH_RUST_LINK_LANGS
                "$<TARGET_PROPERTY:${_lib},LINKER_LANGUAGE>")
            add_dependencies("${_med}" "${_lib}")
        elseif(IS_ABSOLUTE "${_lib}")
            set_property(TARGET "${_med}" APPEND PROPERTY
                POLYORCH_RUST_LINK_LIBRARIES "-Clink-arg=${_lib}")
        else()
            set_property(TARGET "${_med}" APPEND PROPERTY
                POLYORCH_RUST_LINK_LIBRARIES "-l${_lib}")
        endif()
    endforeach()
endfunction()

# Internal: the WP5b linker/runner env entries for one cargo rule. MED is
# the mediator carrying POLYORCH_RUST_LINK_LANGS ("" for property-free rules
# like cargo test). Returns [] on the host layer. Entries ride the command
# wrapper AFTER the --unset strip (contract at _polyorch_rust_command).
function(_polyorch_rust_linker_entries MED OUT)
    set(_xt "${POLYORCH_RUST_CARGO_TARGET}")
    if(NOT _xt)
        set(${OUT} "" PARENT_SCOPE)
        return()
    endif()
    _polyorch_rust_linker_plan(TRIPLE "${_xt}"
        OUT_ENV_NAME _name OUT_VALUE _val OUT_WRAPPER _wrap
        OUT_WRAPPER_CONTENT _wrapc OUT_RUNNER _runner)
    set(_entries "")
    if(_wrap)
        # Configure-time materialization; the generated header carries the
        # never-a-custom-command-OUTPUT discipline (the ported lesson). A
        # later hostbuild flip leaves the file inert -- its env name is
        # triple-scoped.
        get_filename_component(_wd "${_wrap}" DIRECTORY)
        file(MAKE_DIRECTORY "${_wd}")
        file(WRITE "${_wrap}" "${_wrapc}")
        file(CHMOD "${_wrap}" PERMISSIONS
            OWNER_READ OWNER_WRITE OWNER_EXECUTE
            GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
        list(APPEND _entries "${_name}=${_wrap}")
    elseif(_val)
        # Explicit cache override (PolyOrch_RUST_LINKER_<TRIPLE-UP>) or a
        # decision the plan made from the emulator.
        list(APPEND _entries "${_name}=${_val}")
    elseif(_name AND (CMAKE_C_COMPILER OR CMAKE_CXX_COMPILER))
        # Default compiler-as-linker (corr:852-857 shape). Deviation,
        # ledgered: injected on CROSS rules only -- the reference injects on
        # the host too, redundant where rustc's default driver already is
        # the configure compiler. No quoting: file paths ride VERBATIM as
        # one KEY=VAL argument; the CXX-vs-C pick is a genex over the
        # recorded LINKER_LANGUAGEs so link_libraries may run later.
        if(CMAKE_CXX_COMPILER AND MED)
            list(APPEND _entries
                "${_name}=$<IF:$<IN_LIST:CXX,$<TARGET_GENEX_EVAL:${MED},$<TARGET_PROPERTY:${MED},POLYORCH_RUST_LINK_LANGS>>>,${CMAKE_CXX_COMPILER},${CMAKE_C_COMPILER}>")
        elseif(CMAKE_CXX_COMPILER)
            list(APPEND _entries "${_name}=${CMAKE_CXX_COMPILER}")
        else()
            list(APPEND _entries "${_name}=${CMAKE_C_COMPILER}")
        endif()
    endif()
    if(_runner)
        list(APPEND _entries "${_runner}")
    endif()
    set(${OUT} "${_entries}" PARENT_SCOPE)
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
    # WP5/WP5b: route cargo test through the consumed cross triple too. No
    # mediator here, so the entries are configure-time literals (the
    # default linker picks C++ over C when the CXX language is enabled).
    # Built test binaries EXECUTE under the forwarded RUNNER automatically.
    set(_fwd_env "")
    set(_lnk_env "")
    if(POLYORCH_RUST_CARGO_TARGET)
        list(APPEND _argv "--target=${POLYORCH_RUST_CARGO_TARGET}")
        _polyorch_rust_forward_env(TRIPLE "${POLYORCH_RUST_CARGO_TARGET}"
            OUT_ENV _fwd_env)
        _polyorch_rust_forward_env(TRIPLE "${POLYORCH_RUST_HOST_TARGET}"
            OUT_ENV _fwd_env_host)
        set(_fwd_env "${_fwd_env_host};${_fwd_env}")
        _polyorch_rust_linker_entries("" _lnk_env)
    else()
        _polyorch_rust_forward_env(TRIPLE "${POLYORCH_RUST_HOST_TARGET}"
            OUT_ENV _fwd_env)
    endif()
    if(T_ARGS)
        list(APPEND _argv ${T_ARGS})
    endif()
    _polyorch_rust_command(_cmd SUBCOMMAND ${_argv}
        ENV "${_fwd_env}" "${_lnk_env}")
    set(_all "")
    if(T_ALL)
        set(_all ALL)
    endif()

    _polyorch_rust_uterm(_uterm)
    add_custom_target("${_name}" ${_all} COMMAND ${_cmd}
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
        COMMENT "cargo test ${T_PACKAGE}"
        ${_uterm}
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
    # WP5b: a cross-routed binary cannot execute natively; prefix the
    # emulator (CMake's own CROSSCOMPILING_EMULATOR convention, the run()
    # counterpart of the CARGO_TARGET_<TUP>_RUNNER the build rule carries).
    set(_emu "")
    if(POLYORCH_RUST_CARGO_TARGET AND CMAKE_CROSSCOMPILING_EMULATOR)
        set(_emu ${CMAKE_CROSSCOMPILING_EMULATOR})
    endif()
    add_custom_target("run-${R_TARGET}"
        COMMAND ${_emu} $<TARGET_FILE:${R_TARGET}>
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

# Internal: pure staging plan for ONE rust handle of
# polyorch_rust_install. Inputs: the artifact-kind triplet (KIND + TRIPLE
# family + HANDLE), the PREFIX to fold in front of every destination,
# destination overrides, caller-supplied default permission sets
# (EXEC_PERMS / FILE_PERMS), a flat PERMISSIONS override, per-call
# COMPONENT / CONFIGURATIONS pass-through, the configure-time
# IMPLIB_FILE literal of a windows-family shared handle and the
# PUBLIC_HEADER list (HEADERS + optional DEST_INCLUDE). OUT_ROWS
# receives one row per staged file in emission order (main artifact,
# import library, headers):
#
#   <file-expr>|<destination>|<perms>|<component>|<configs>|<stub>
#
# Fields are |-joined; multi-value fields are SPACE-joined, so a row may
# never contain ';' or '|' (a path with either is unsupported -- same
# encoding contract as the copy plan). The stub field carries the '%'-
# joined lines the EXPORT replay file gains for this row ('' for header
# rows); ${_POLYORCH_RUST_ROOT} and $<TARGET_FILE_NAME:...> ride through
# as literal text, resolved later by file(GENERATE) / include. Kind
# defaults mirror the landed shape: bin -> runtime dest (bin), static
# -> archive dest (lib), shared -> runtime dest on the msvc/gnu
# families (the dll is the RUNTIME artifact, corr:1463-1576) else
# library dest (lib), implib -> archive dest, headers -> include dest
# (include/). The INTERFACE_INCLUDE_DIRECTORIES stub line is appended
# to the MAIN row of a static/shared handle when HEADERS are given --
# a bin consumer links nothing to compile against. Unknown KIND or
# unknown TRIPLE FATAL (the triple-family identity).
function(_polyorch_rust_install_plan)
    set(_one TRIPLE KIND HANDLE PREFIX RUNTIME_DESTINATION ARCHIVE_DESTINATION
        LIBRARY_DESTINATION DEST_INCLUDE COMPONENT IMPLIB_FILE OUT_ROWS)
    set(_multi EXEC_PERMS FILE_PERMS PERMISSIONS CONFIGURATIONS HEADERS)
    cmake_parse_arguments(PARSE_ARGV 0 A "" "${_one}" "${_multi}")
    if(A_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR
            "_polyorch_rust_install_plan unknown args: ${A_UNPARSED_ARGUMENTS}")
    endif()
    _polyorch_rust_must(A_TRIPLE A_KIND A_HANDLE A_OUT_ROWS)
    if(NOT A_KIND MATCHES "^(bin|static|shared)$")
        message(FATAL_ERROR
            "polyorch_rust: install-plan KIND must be bin|static|shared, got '${A_KIND}'")
    endif()
    _polyorch_rust_triple_family("${A_TRIPLE}" _fam)

    set(_dr bin)
    if(A_RUNTIME_DESTINATION)
        set(_dr "${A_RUNTIME_DESTINATION}")
    endif()
    set(_da lib)
    if(A_ARCHIVE_DESTINATION)
        set(_da "${A_ARCHIVE_DESTINATION}")
    endif()
    set(_dl lib)
    if(A_LIBRARY_DESTINATION)
        set(_dl "${A_LIBRARY_DESTINATION}")
    endif()
    set(_di include)
    if(A_DEST_INCLUDE)
        set(_di "${A_DEST_INCLUDE}")
    endif()

    # The landed permission defaults (corr:1448/1477) live here so bare
    # calls get them; callers may pass their own sets. A flat
    # PERMISSIONS override replaces BOTH sets on every row (the reference
    # parses per-type PERMISSIONS blocks, corr:1403-1441; the flat form is
    # the documented PolyOrch shape -- ledger deviation).
    string(JOIN " " _pe ${A_EXEC_PERMS})
    if(_pe STREQUAL "")
        set(_pe "OWNER_READ OWNER_WRITE GROUP_READ WORLD_READ OWNER_EXECUTE GROUP_EXECUTE WORLD_EXECUTE")
    endif()
    string(JOIN " " _pf ${A_FILE_PERMS})
    if(_pf STREQUAL "")
        set(_pf "OWNER_READ OWNER_WRITE GROUP_READ WORLD_READ")
    endif()
    if(A_PERMISSIONS)
        string(JOIN " " _pf ${A_PERMISSIONS})
        set(_pe "${_pf}")
    endif()
    string(JOIN " " _cfgs ${A_CONFIGURATIONS})
    set(_comp "${A_COMPONENT}")
    set(_pre "${A_PREFIX}")
    set(_h "${A_HANDLE}")

    if(A_KIND STREQUAL "bin")
        set(_d "${_dr}")
        set(_perm "${_pe}")
        set(_add "add_executable(${_h} IMPORTED GLOBAL)")
    elseif(A_KIND STREQUAL "static")
        set(_d "${_da}")
        set(_perm "${_pf}")
        set(_add "add_library(${_h} STATIC IMPORTED GLOBAL)")
    else()
        if(_fam MATCHES "^(msvc|gnu)$")
            set(_d "${_dr}")      # the dll is the RUNTIME artifact
        else()
            set(_d "${_dl}")      # .so / .dylib
        endif()
        set(_perm "${_pe}")
        set(_add "add_library(${_h} SHARED IMPORTED GLOBAL)")
    endif()
    set(_fd "${_pre}${_d}")
    set(_stub "${_add}%set_target_properties(${_h} PROPERTIES IMPORTED_LOCATION     \"\${_POLYORCH_RUST_ROOT}/${_fd}/$<TARGET_FILE_NAME:${_h}>\")")
    if(A_HEADERS AND NOT A_KIND STREQUAL "bin")
        string(APPEND _stub "%set_target_properties(${_h} PROPERTIES INTERFACE_INCLUDE_DIRECTORIES \"\${_POLYORCH_RUST_ROOT}/${_pre}${_di}\")")
    endif()
    string(JOIN "|" _row "$<TARGET_FILE:${_h}>" "${_fd}" "${_perm}" "${_comp}" "${_cfgs}" "${_stub}")
    set(_rows "${_row}")

    if(A_KIND STREQUAL "shared" AND A_IMPLIB_FILE)
        # The implib path is a configure-time literal written by
        # polyorch_rust_build, so NAME extraction is lexical, not a
        # genex parse (the pre-WP8 function did the same).
        get_filename_component(_ibn "${A_IMPLIB_FILE}" NAME)
        set(_ifd "${_pre}${_da}")
        string(JOIN "|" _irow "${A_IMPLIB_FILE}" "${_ifd}" "${_pf}" "${_comp}" "${_cfgs}" "set_target_properties(${_h} PROPERTIES IMPORTED_IMPLIB     \"\${_POLYORCH_RUST_ROOT}/${_ifd}/${_ibn}\")")
        list(APPEND _rows "${_irow}")
    endif()

    foreach(_hdr IN LISTS A_HEADERS)
        string(JOIN "|" _hrow "${_hdr}" "${_pre}${_di}" "${_pf}" "${_comp}" "${_cfgs}" "")
        list(APPEND _rows "${_hrow}")
    endforeach()

    set(${A_OUT_ROWS} "${_rows}" PARENT_SCOPE)
endfunction()
# polyorch_rust_install(TARGETS <handle>...
#   [EXPORT <name>] [PREFIX <dir>]
#   [RUNTIME_DESTINATION <dir>] [ARCHIVE_DESTINATION <dir>] [LIBRARY_DESTINATION <dir>]
#   [PERMISSIONS <perm>...] [COMPONENT <name>] [CONFIGURATIONS <cfg>...]
#   [PUBLIC_HEADER <file>...])
# Installs the cargo artifacts behind previously-registered rust handles
# (binaries to <dir>bin/, archives and unix shared libs to <dir>lib/; a
# Windows-family dll stages to <dir>bin/ as its RUNTIME part with its
# import library beside the archives). macOS note: a dylib installs to
# <dir>lib/ like the ELF .so, but its embedded install_name still points
# into the build tree -- rewriting it (and staging Windows runtime dlls
# next to consumer exes) is the P2 backlog, not this function.
#
# The three <KIND>_DESTINATION keywords override one default each
# (prefix-relative; the stub resolves destinations against its own
# directory, so overrides stay consumer-correct). PERMISSIONS is a FLAT
# override of both default sets -- unlike the reference's per-type
# blocks (corr:1403-1441, ledgered); without it the runtime artifacts
# keep OWNER/EXEC bits and the archives/headers are plain files
# (corr:1448/1477). COMPONENT stamps one component name on every
# install rule of the call (cmake --install --component <name>); it is
# a PolyOrch extension -- the pinned reference has NO component
# mechanism (grep-verified absent from corr:1338-1678). CONFIGURATIONS
# gates every rule the same way install()'s own keyword does; per-
# CONFIGURATION MULTI-CONFIG STAGING of the replay stub remains the
# documented seam (the stub carries one location per handle, the
# pre-WP8 shape -- gate one configuration per install invocation until
# an MC stub is built). PUBLIC_HEADER installs each FILE flat under
# <dir>include/ (no directory tree is preserved -- the reference walks
# INTERFACE_INCLUDE_DIRECTORIES/file-sets, corr:1632-1670, not ported)
# and appends an INTERFACE_INCLUDE_DIRECTORIES line to every
# static/shared replay entry so the header is consumer-visible.
#
# EXPORT <name> additionally writes <name>-rust.cmake through
# file(GENERATE): a replay stub that recreates every handle as an
# IMPORTED GLOBAL target with its location rebuilt at include time
# relative to the stub's own directory, and installs it to
# <dir>lib/cmake/<name>/ together with a generated <name>Config.cmake
# wrapper. The consumer side is a plain include():
#
#   include(<prefix>/lib/cmake/<name>/<name>-rust.cmake)
#   target_link_libraries(my-app PRIVATE dash_ed)
#
# or, as the fixture chain of t-rust-install-export consumes it,
#
#   find_package(<name> CONFIG REQUIRED)   # via CMAKE_PREFIX_PATH
#
# The reference relies on the user's own Config file to define
# PACKAGE_PREFIX_DIR before including <export>Corrosion.cmake
# (corr:1536); PolyOrch emits both files, the wrapper setting
# PACKAGE_PREFIX_DIR (unused by the self-locating stub, kept for the
# convention) and including the stub beside it. The root-package half
# (PolyOrch's own install/export chain) stays blocked-on-host.
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
# / install(TARGETS EXPORT) machinery around it is NOT ported (the
# reference's own install(EXPORT ...) leg is a FATAL at
# corr:1673-1674); the replay stub remains the single export mechanism
# (port plan G1 ruling).
function(polyorch_rust_install)
    set(_one EXPORT PREFIX RUNTIME_DESTINATION ARCHIVE_DESTINATION
        LIBRARY_DESTINATION COMPONENT)
    set(_multi TARGETS PERMISSIONS CONFIGURATIONS PUBLIC_HEADER)
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

    set(_p "${A_PREFIX}")
    if(_p AND NOT _p MATCHES "/$")
        string(APPEND _p "/")
    endif()
    # corr:1448/1477: archives plain, runtime artifacts plus exec bits.
    set(_exec_perms OWNER_READ OWNER_WRITE GROUP_READ WORLD_READ
                    OWNER_EXECUTE GROUP_EXECUTE WORLD_EXECUTE)
    set(_file_perms OWNER_READ OWNER_WRITE GROUP_READ WORLD_READ)

    # Per-call planner pass-through (IMPLIB_FILE joins it per handle).
    set(_extra "")
    foreach(_kw RUNTIME_DESTINATION ARCHIVE_DESTINATION LIBRARY_DESTINATION COMPONENT)
        if(A_${_kw})
            list(APPEND _extra "${_kw}" "${A_${_kw}}")
        endif()
    endforeach()
    foreach(_kw PERMISSIONS CONFIGURATIONS)
        if(A_${_kw})
            list(APPEND _extra ${_kw} ${A_${_kw}})
        endif()
    endforeach()
    if(A_PUBLIC_HEADER)
        list(APPEND _extra HEADERS ${A_PUBLIC_HEADER})
    endif()

    set(_stub "")
    if(A_EXPORT)
        # Append, never set-with-list: a multi-argument set() would join
        # the lines with ';' and the stub would not parse (measured).
        string(APPEND _stub
            "# Generated by polyorch_rust_install() -- DO NOT EDIT.\n"
            "# Consume with include(<install-prefix>/${_p}lib/cmake/${A_EXPORT}/${A_EXPORT}-rust.cmake)\n"
            "# or with find_package(${A_EXPORT} CONFIG) via the sibling Config file.\n"
            "get_filename_component(_POLYORCH_RUST_ROOT\n"
            "    \"\${CMAKE_CURRENT_LIST_DIR}/../../..\" ABSOLUTE)\n")
    endif()

    # Pass 2: plan + stage + serialize. Every handle was validated in the
    # pre-pass, so only the kind lookup and the implib literal remain.
    foreach(_h IN LISTS A_TARGETS)
        set(_med "cargo-build-${_h}")
        get_target_property(_kind "${_med}" POLYORCH_RUST_KIND)
        set(_plext ${_extra})
        if(_kind STREQUAL "shared")
            get_target_property(_implib "${_h}" IMPORTED_IMPLIB)
            if(_implib)
                list(APPEND _plext IMPLIB_FILE "${_implib}")
            endif()
        endif()
        _polyorch_rust_install_plan(TRIPLE "${POLYORCH_RUST_HOST_TARGET}"
            KIND "${_kind}" HANDLE "${_h}" PREFIX "${_p}"
            EXEC_PERMS ${_exec_perms} FILE_PERMS ${_file_perms}
            ${_plext} OUT_ROWS _rows)

        set(_ri 0)
        foreach(_row IN LISTS _rows)
            string(REPLACE "|" ";" _f "${_row}")
            list(GET _f 0 _art)
            list(GET _f 1 _dest)
            list(GET _f 2 _perms)
            list(GET _f 3 _comp)
            list(GET _f 4 _cfgs)
            list(GET _f 5 _sb)
            string(REPLACE " " ";" _perms "${_perms}")
            string(REPLACE " " ";" _cfgs "${_cfgs}")
            set(_iargs "")
            if(_comp)
                list(APPEND _iargs COMPONENT "${_comp}")
            endif()
            if(_cfgs)
                list(APPEND _iargs CONFIGURATIONS ${_cfgs})
            endif()
            install(FILES "${_art}" DESTINATION "${_dest}"
                PERMISSIONS ${_perms} ${_iargs})
            if(A_EXPORT AND NOT _sb STREQUAL "")
                string(REPLACE "%" "\n" _sb "${_sb}")
                string(APPEND _stub "${_sb}\n")
                # Verbatim copy of the probe-attached interface (literal
                # lists by contract), right after the static main entry.
                # A genex the user grafted onto the handle is replayed as
                # text and may not resolve in the consumer context -- not
                # our composition, documented here.
                if(_ri EQUAL 0 AND _kind STREQUAL "static")
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
            endif()
            math(EXPR _ri "${_ri} + 1")
        endforeach()
    endforeach()

    if(A_EXPORT)
        set(_stubfile "${CMAKE_CURRENT_BINARY_DIR}/${A_EXPORT}-rust.cmake")
        file(GENERATE OUTPUT "${_stubfile}" CONTENT "${_stub}")
        install(FILES "${_stubfile}" DESTINATION "${_p}lib/cmake/${A_EXPORT}")
        # The find_package entry point of the pair (the corr:1536
        # PACKAGE_PREFIX_DIR convention, emitted rather than user-written
        # -- deviation registered in the port ledger). Component and
        # configuration gating do not reach these two files: they install
        # unconditionally with CMake's default rules.
        set(_cfgfile "${CMAKE_CURRENT_BINARY_DIR}/${A_EXPORT}Config.cmake")
        file(WRITE "${_cfgfile}"
            "# Generated by polyorch_rust_install() -- DO NOT EDIT.\n"
            "# find_package(${A_EXPORT} CONFIG REQUIRED) entry point.\n"
            "get_filename_component(PACKAGE_PREFIX_DIR\n"
            "    \"\${CMAKE_CURRENT_LIST_DIR}/../../..\" ABSOLUTE)\n"
            "include(\"\${CMAKE_CURRENT_LIST_DIR}/${A_EXPORT}-rust.cmake\")\n")
        install(FILES "${_cfgfile}" DESTINATION "${_p}lib/cmake/${A_EXPORT}")
    endif()
endfunction()
# ------------------------------------------------------------------- WP7 ---
#
# Adapted from corrosion (MIT, commit c4786e7): cmake/Corrosion.cmake:
# 1786-1981 (corrosion_add_cxxbridge) and 2068-2264
# (corrosion_experimental_cbindgen). The tool-resolution half of both
# regions is factored into polyorch_rust_tool_bootstrap
# (PolyOrchFindRust) -- discovery-or-deferred-install shared by both
# clusters. Deviations (all on the port ledger): the cxx target is named
# <TARGET>-cxx (the reference takes the C++ target name as its first
# positional); the FILE_SET HEADERS attachment (corr:2194-2200) is not
# ported (the reference's pre-3.23 include-dirs shape becomes the only
# shape, the 3.25 floor deletes its branch); the cbindgen manual-mode
# signature gate additionally requires CARGO_PACKAGE (the reference's
# duplicated BINDINGS_TARGET term at corr:2090-2093 reads as a typo).

# Internal: pure argv builder for one cxxbridge invocation. Shapes locked
# against corr:1925 (--header --output), corr:1954 (RUST --header
# --output) and corr:1956-1958 (RUST --output --include, --include AFTER
# --output): <tool> [<rust>] [--header] --output <o> [--include <i>].
# OUT_CMD receives the list; the caller owns VERBATIM.
function(_polyorch_rust_cxxbridge_cmd)
    cmake_parse_arguments(PARSE_ARGV 0 C "HEADER"
        "TOOL;RUST;OUTPUT;INCLUDE;OUT_CMD" "")
    if(C_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR
            "_polyorch_rust_cxxbridge_cmd: unknown args: ${C_UNPARSED_ARGUMENTS}")
    endif()
    foreach(_k C_TOOL C_OUTPUT C_OUT_CMD)
        if(NOT DEFINED ${_k} OR "${${_k}}" STREQUAL "")
            message(FATAL_ERROR
                "_polyorch_rust_cxxbridge_cmd: missing required argument '${_k}'")
        endif()
    endforeach()
    if(NOT C_HEADER AND NOT C_RUST)
        message(FATAL_ERROR
            "_polyorch_rust_cxxbridge_cmd: RUST is required for the source invocation (no HEADER)")
    endif()
    if(C_HEADER AND C_INCLUDE)
        message(FATAL_ERROR
            "_polyorch_rust_cxxbridge_cmd: INCLUDE belongs to the source invocation only")
    endif()
    set(_argv "${C_TOOL}")
    if(C_RUST)
        list(APPEND _argv "${C_RUST}")
    endif()
    if(C_HEADER)
        list(APPEND _argv --header)
    endif()
    list(APPEND _argv --output "${C_OUTPUT}")
    if(C_INCLUDE)
        list(APPEND _argv --include "${C_INCLUDE}")
    endif()
    set(${C_OUT_CMD} "${_argv}" PARENT_SCOPE)
endfunction()

# polyorch_rust_cxxbridge(TARGET <rust-handle> FILES <file.rs>...
#                         [REGEN_TARGET <name>] [VERSION <v>] [PREFIX <dir>]
#                         [OUTPUT_DIR <dir>] [ALLOW_INSTALL])
# C++ bindings for a #[cxx::bridge] crate via cxxbridge (port of
# corrosion_add_cxxbridge). Creates the STATIC library <TARGET>-cxx, runs
# the tool as a BUILD-time custom command into
# polyorch_generated/cxxbridge/<TARGET>-cxx/ (OUTPUT_DIR relocates the
# root), and wires the generated sources/headers into it; consumers of
# <TARGET>-cxx get the include dir and the generation ordering through
# the normal link edges. FILES resolve against the crate manifest's src/
# like the reference (corr:1945 -- its "todo: convert absolute paths"
# note is resolved here: absolute FILES pass through); relative FILES
# need a handle carrying POLYORCH_RUST_MANIFEST (stamped by build/import
# with MANIFEST). The tool comes from polyorch_rust_tool_bootstrap:
# discovered (PATH + toolchain/bin + CARGO_HOME/bin + ~/.cargo/bin +
# PREFIX/bin) and, with VERSION absent, pinned by the cargo-tree probe
# against cxxbridge-cmd/cxx (corr:1680-1726). The lock-compare resolution
# and the explicit-permission install branch are the bootstrap's: the
# default surface here is discovery plus a loud FATAL -- corr:1850's
# auto-install shape only rides with ALLOW_INSTALL (crates.io egress).
# REGEN_TARGET names the header-only regeneration target
# (corr:1973-1979). The circular link edges to <TARGET>-static/-shared
# (corr:1912-1919) are ported verbatim; the PUBLIC generated headers
# (corr:1967-1971) are what make CMake order generation before either
# side of that cycle.
function(polyorch_rust_cxxbridge)
    cmake_parse_arguments(PARSE_ARGV 0 CB "ALLOW_INSTALL"
        "TARGET;VERSION;PREFIX;OUTPUT_DIR;REGEN_TARGET" "FILES")
    if(CB_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR
            "polyorch_rust_cxxbridge: unknown args: ${CB_UNPARSED_ARGUMENTS}")
    endif()
    foreach(_k CB_TARGET CB_FILES)
        if(NOT DEFINED ${_k} OR "${${_k}}" STREQUAL "")
            message(FATAL_ERROR
                "polyorch_rust_cxxbridge: missing required parameter `${_k}'")
        endif()
    endforeach()
    _polyorch_rust_require_setup(polyorch_rust_cxxbridge)

    set(_cxx "${CB_TARGET}-cxx")
    if(TARGET "${_cxx}")
        message(FATAL_ERROR
            "polyorch_rust_cxxbridge: target '${_cxx}' already exists")
    endif()

    # Manifest of the crate handle (the reference reads
    # INTERFACE_COR_PACKAGE_MANIFEST_PATH off the imported target,
    # corr:1808); any of the pair spellings answers.
    set(_mdir "")
    foreach(_h "${CB_TARGET}-static" "${CB_TARGET}-shared" "${CB_TARGET}")
        if(TARGET "${_h}")
            get_target_property(_mp "${_h}" POLYORCH_RUST_MANIFEST)
            if(_mp AND NOT _mp MATCHES "-NOTFOUND$" AND EXISTS "${_mp}")
                get_filename_component(_mdir "${_mp}" DIRECTORY)
                break()
            endif()
        endif()
    endforeach()

    set(_pin "${CB_VERSION}")
    if(NOT _pin)
        if(NOT _mdir)
            message(FATAL_ERROR
                "polyorch_rust_cxxbridge: no VERSION given and crate '${CB_TARGET}' carries no readable POLYORCH_RUST_MANIFEST -- cannot derive the pinned cxx version (pass VERSION, or build/import with MANIFEST)")
        endif()
        _polyorch_rust_cxx_version_required("${_mdir}" _pin)
        if(NOT _pin)
            message(FATAL_ERROR
                "polyorch_rust_cxxbridge: failed to find a dependency on `cxxbridge-cmd` / `cxx` for crate ${CB_TARGET} (corr:1820 identity; pass VERSION to skip the cargo-tree probe)")
        endif()
    endif()

    set(_prefkw "")
    if(CB_PREFIX)
        set(_prefkw PREFIX "${CB_PREFIX}")
    endif()
    set(_ailkw "")
    if(CB_ALLOW_INSTALL)
        set(_ailkw ALLOW_INSTALL)
    endif()
    # The cxxbridge install rule is QUIET exactly like corr:1867.
    polyorch_rust_tool_bootstrap(TOOL cxxbridge-cmd BINARY cxxbridge
        VERSION "${_pin}" ${_prefkw} ${_ailkw} QUIET
        OUT_VAR _tok OUT_TARGET _tt)
    if(NOT _tok)
        message(FATAL_ERROR
            "polyorch_rust_cxxbridge: cxxbridge ${_pin} unavailable -- put it on PATH or PREFIX/bin, or re-run with ALLOW_INSTALL (cargo install, crates.io egress)")
    endif()
    set(_tool "${CXXBRIDGE_CMD_TOOL}")
    set(_tdepkw "")
    if(_tt)
        set(_tdepkw DEPENDS "${_tt}")
    endif()

    set(_gen "${CB_OUTPUT_DIR}")
    if(NOT _gen)
        set(_gen "${CMAKE_CURRENT_BINARY_DIR}/polyorch_generated/cxxbridge/${_cxx}")
    endif()
    set(_hdir "${_gen}/include/${_cxx}")
    set(_sdir "${_gen}/src")

    add_library("${_cxx}" STATIC)
    target_include_directories("${_cxx}" PUBLIC
        $<BUILD_INTERFACE:${_gen}/include>
        $<INSTALL_INTERFACE:include>)
    # cxx headers use C++11 features (corr:1909-1910).
    target_compile_features("${_cxx}" PUBLIC cxx_std_11)
    foreach(_role static shared)
        if(TARGET "${CB_TARGET}-${role}")
            target_link_libraries("${_cxx}" PRIVATE "${CB_TARGET}-${role}")
            target_link_libraries("${CB_TARGET}-${role}" INTERFACE "${_cxx}")
        endif()
    endforeach()

    file(MAKE_DIRECTORY "${_gen}/include/rust")
    set(_cxxh "${_gen}/include/rust/cxx.h")
    _polyorch_rust_cxxbridge_cmd(TOOL "${_tool}" HEADER OUTPUT "${_cxxh}"
        OUT_CMD _cmd)
    add_custom_command(OUTPUT "${_cxxh}"
        COMMAND ${_cmd}
        ${_tdepkw}
        COMMENT "Generating rust/cxx.h header")

    set(_srcs "")
    set(_hdrs "${_cxxh}")
    foreach(_f IN LISTS CB_FILES)
        get_filename_component(_fn "${_f}" NAME_WE)
        get_filename_component(_fd "${_f}" DIRECTORY)
        set(_fdc "")
        if(_fd)
            set(_fdc "${_fd}/")
        endif()
        set(_h "${_fdc}${_fn}.h")
        set(_s "${_fdc}${_fn}.cpp")
        if(IS_ABSOLUTE "${_f}")
            set(_rs "${_f}")
        else()
            if(NOT _mdir)
                message(FATAL_ERROR
                    "polyorch_rust_cxxbridge: '${_f}' is manifest-relative but the crate handle carries no readable POLYORCH_RUST_MANIFEST (pass an absolute path)")
            endif()
            set(_rs "${_mdir}/src/${_f}")
        endif()
        file(MAKE_DIRECTORY "${_hdir}/${_fd}" "${_sdir}/${_fd}")
        _polyorch_rust_cxxbridge_cmd(TOOL "${_tool}" RUST "${_rs}"
            HEADER OUTPUT "${_hdir}/${_h}" OUT_CMD _cmd_h)
        _polyorch_rust_cxxbridge_cmd(TOOL "${_tool}" RUST "${_rs}"
            OUTPUT "${_sdir}/${_s}" INCLUDE "${_cxx}/${_h}" OUT_CMD _cmd_s)
        add_custom_command(
            OUTPUT "${_hdir}/${_h}" "${_sdir}/${_s}"
            COMMAND ${_cmd_h}
            COMMAND ${_cmd_s}
            DEPENDS "${_rs}" ${_tt}
            COMMENT "Generating cxx bindings for crate ${CB_TARGET} and file ${_f}")
        list(APPEND _srcs "${_sdir}/${_s}")
        list(APPEND _hdrs "${_hdir}/${_h}")
    endforeach()
    target_sources("${_cxx}" PRIVATE ${_srcs})
    # PUBLIC for the headers on purpose (corr:1967-1971): every target
    # depending on the cxx library also gets the files as a generation
    # dependency, which is what keeps the circular edge orderable.
    target_sources("${_cxx}" PUBLIC ${_hdrs})
    if(CB_REGEN_TARGET)
        # Headers only -- sources are not needed for a regeneration pass
        # (corr:1974-1975).
        if(TARGET "${CB_REGEN_TARGET}")
            message(FATAL_ERROR
                "polyorch_rust_cxxbridge: REGEN_TARGET '${CB_REGEN_TARGET}' already exists")
        endif()
        add_custom_target("${CB_REGEN_TARGET}"
            DEPENDS ${_hdrs}
            COMMENT "Generated cxx bindings for crate ${CB_TARGET}")
    endif()
endfunction()

# Internal: pure argv builder for one cbindgen run (corr:2224-2233 order:
# `cmake -E env TARGET= CARGO= RUSTC= <tool> --output <h> --crate <p>
# [--depfile=<d>] <flags...>`). TRIPLE may be a generator expression (the
# auto-mode hostbuild switch); the three env entries are ALWAYS emitted,
# empty value included -- byte-for-byte the reference shape.
function(_polyorch_rust_cbindgen_cmd)
    cmake_parse_arguments(PARSE_ARGV 0 C ""
        "TOOL;CRATE;OUTPUT;DEPFILE;TRIPLE;CARGO;RUSTC;OUT_CMD" "FLAGS")
    if(C_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR
            "_polyorch_rust_cbindgen_cmd: unknown args: ${C_UNPARSED_ARGUMENTS}")
    endif()
    foreach(_k C_TOOL C_CRATE C_OUTPUT C_OUT_CMD)
        if(NOT DEFINED ${_k} OR "${${_k}}" STREQUAL "")
            message(FATAL_ERROR
                "_polyorch_rust_cbindgen_cmd: missing required argument '${_k}'")
        endif()
    endforeach()
    set(_argv "${CMAKE_COMMAND}" -E env
        "TARGET=${C_TRIPLE}" "CARGO=${C_CARGO}" "RUSTC=${C_RUSTC}"
        "${C_TOOL}"
        --output "${C_OUTPUT}" --crate "${C_CRATE}")
    if(C_DEPFILE)
        list(APPEND _argv "--depfile=${C_DEPFILE}")
    endif()
    if(C_FLAGS)
        list(APPEND _argv ${C_FLAGS})
    endif()
    set(${C_OUT_CMD} "${_argv}" PARENT_SCOPE)
endfunction()

# polyorch_rust_cbindgen(TARGET <rust-handle> HEADER_NAME <h.h>
#                        [CBINDGEN_VERSION <v>] [PREFIX <dir>]
#                        [FLAGS f...] [ALLOW_INSTALL]
#     | MANIFEST_DIRECTORY <dir> CARGO_PACKAGE <p> BINDINGS_TARGET <iface>
#       [TARGET_TRIPLE <tup>] HEADER_NAME <h.h> [FLAGS ...] ...)
# C header generation for a #[no_mangle] extern "C" surface via cbindgen
# (port of corrosion_experimental_cbindgen, corr:2068-2264, both
# signatures). Auto mode attaches the header to the imported rust handle
# itself and derives package name, manifest dir and the generation-time
# TARGET triple from its properties (the hostbuild switch kept as the
# reference genex, corr:2113-2114, normalized through the PolyOrch host-
# layer convention: an empty cross triple IS the host). Manual mode
# attaches to a user-created INTERFACE target and takes the coordinates
# literally; a non-INTERFACE BINDINGS_TARGET gets the reference's
# AUTHOR_WARNING (corr:2141-2145). Regeneration on source changes rides
# the cbindgen DEPFILE (corr:2235); the targets
# polyorch-cbindgen-<bindings>-bindings[.<header-id>] port
# corr:2248-2260, mediator edge included in auto mode (the cargo build
# waits for fresh headers). CBINDGEN_VERSION is declared unimplemented
# upstream (corr:2052); PolyOrch WIRES it into the bootstrap lock compare
# -- a registered deviation (the strict superset: a pin is honored the
# moment one is given).
function(polyorch_rust_cbindgen)
    cmake_parse_arguments(PARSE_ARGV 0 CN "ALLOW_INSTALL"
        "TARGET;MANIFEST_DIRECTORY;CARGO_PACKAGE;BINDINGS_TARGET;TARGET_TRIPLE;HEADER_NAME;CBINDGEN_VERSION;PREFIX"
        "FLAGS")
    if(CN_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR
            "polyorch_rust_cbindgen: unknown args: ${CN_UNPARSED_ARGUMENTS}")
    endif()
    if(NOT CN_HEADER_NAME)
        message(FATAL_ERROR
            "polyorch_rust_cbindgen: missing required parameter `HEADER_NAME'")
    endif()
    if(NOT CN_TARGET AND NOT (CN_MANIFEST_DIRECTORY AND CN_CARGO_PACKAGE
                              AND CN_BINDINGS_TARGET))
        message(FATAL_ERROR
            "polyorch_rust_cbindgen: unknown signature -- choose either TARGET, or MANIFEST_DIRECTORY + CARGO_PACKAGE + BINDINGS_TARGET (corr:2095 identity, the reference's duplicated BINDINGS_TARGET gate term corrected here)")
    endif()
    _polyorch_rust_require_setup(polyorch_rust_cbindgen)

    set(_auto FALSE)
    if(CN_TARGET)
        set(_auto TRUE)
        if(NOT TARGET "${CN_TARGET}")
            message(FATAL_ERROR
                "polyorch_rust_cbindgen: TARGET '${CN_TARGET}' is not a known target (import it with polyorch_rust_build / polyorch_rust_import, or use the manual signature)")
        endif()
        set(_bt "${CN_TARGET}")
        # The reference's triple switch (corr:2113-2114): hostbuild flips
        # to HOST; otherwise the routed triple, which in the host layer
        # IS the host (PolyOrch empty-cross convention).
        set(_hb "$<BOOL:$<TARGET_PROPERTY:cargo-build-${CN_TARGET},POLYORCH_RUST_HOST_BUILD>>")
        set(_not_hb "${POLYORCH_RUST_CARGO_TARGET}")
        if(NOT _not_hb)
            set(_not_hb "${POLYORCH_RUST_HOST_TARGET}")
        endif()
        set(_triple "$<IF:${_hb},${POLYORCH_RUST_HOST_TARGET},${_not_hb}>")
        get_target_property(_mpath "${CN_TARGET}" POLYORCH_RUST_MANIFEST)
        if(NOT _mpath OR NOT EXISTS "${_mpath}")
            message(FATAL_ERROR
                "polyorch_rust_cbindgen: no package manifest found for ${CN_TARGET} (the handle carries no POLYORCH_RUST_MANIFEST -- build/import it with MANIFEST)")
        endif()
        get_filename_component(_mdir "${_mpath}" DIRECTORY)
        get_target_property(_pkg "${CN_TARGET}" POLYORCH_RUST_PACKAGE)
        if(NOT _pkg OR _pkg MATCHES "-NOTFOUND$")
            message(FATAL_ERROR
                "polyorch_rust_cbindgen: internal error: could not determine the cargo package name for cbindgen (no POLYORCH_RUST_PACKAGE on ${CN_TARGET})")
        endif()
    else()
        set(_bt "${CN_BINDINGS_TARGET}")
        cmake_path(ABSOLUTE_PATH CN_MANIFEST_DIRECTORY NORMALIZE
            OUTPUT_VARIABLE _mdir)
        if(NOT EXISTS "${_mdir}/Cargo.toml")
            message(FATAL_ERROR
                "polyorch_rust_cbindgen: no package manifest in MANIFEST_DIRECTORY ${_mdir}")
        endif()
        set(_triple "${CN_TARGET_TRIPLE}")
        if(NOT _triple)
            set(_triple "${POLYORCH_RUST_CARGO_TARGET}")
            if(NOT _triple)
                set(_triple "${POLYORCH_RUST_HOST_TARGET}")
            endif()
        endif()
        set(_pkg "${CN_CARGO_PACKAGE}")
        get_target_property(_type "${_bt}" TYPE)
        if(NOT _type STREQUAL "INTERFACE_LIBRARY")
            message(AUTHOR_WARNING
                "polyorch_rust_cbindgen: the BINDINGS_TARGET is expected to be an `INTERFACE` library, but was `${_type}` instead (corr:2142)")
        endif()
    endif()
    message(STATUS "polyorch_rust_cbindgen: using package `${_pkg}` as crate for cbindgen")

    set(_prefkw "")
    if(CN_PREFIX)
        set(_prefkw PREFIX "${CN_PREFIX}")
    endif()
    set(_ailkw "")
    if(CN_ALLOW_INSTALL)
        set(_ailkw ALLOW_INSTALL)
    endif()
    # corr:2177: the cbindgen install rule quiets with the inverse of the
    # verbose output flag.
    set(_qkw "")
    if(NOT PolyOrch_RUST_VERBOSE)
        set(_qkw QUIET)
    endif()
    polyorch_rust_tool_bootstrap(TOOL cbindgen VERSION "${CN_CBINDGEN_VERSION}"
        ${_prefkw} ${_ailkw} ${_qkw}
        OUT_VAR _tok OUT_TARGET _tt)
    if(NOT _tok)
        message(FATAL_ERROR
            "polyorch_rust_cbindgen: cbindgen unavailable -- put it on PATH or PREFIX/bin, or re-run with ALLOW_INSTALL (cargo install, crates.io egress)")
    endif()
    set(_tool "${CBINDGEN_TOOL}")
    set(_tdepkw "")
    if(_tt)
        set(_tdepkw DEPENDS "${_tt}")
    endif()

    set(_gen "${CMAKE_CURRENT_BINARY_DIR}/polyorch_generated/cbindgen/${_bt}")
    set(_hdir "${_gen}/include")
    set(_hdr "${_hdir}/${CN_HEADER_NAME}")
    set(_dfl "${_gen}/depfile/${CN_HEADER_NAME}.d")
    # HEADER_NAME may carry relative directories -- BOTH placement dirs
    # get their full parent chain (corr:2212-2217: header dir and depfile
    # dir are resolved independently).
    get_filename_component(_hdr_parent "${_hdr}" DIRECTORY)
    get_filename_component(_dep_parent "${_dfl}" DIRECTORY)
    file(MAKE_DIRECTORY "${_hdr_parent}" "${_dep_parent}")

    # FILE_SET HEADERS (corr:2194-2200) is NOT ported -- the reference's
    # own pre-3.23 fallback becomes the only shape (ledgered).
    target_include_directories("${_bt}" INTERFACE
        $<BUILD_INTERFACE:${_hdir}>
        $<INSTALL_INTERFACE:include>)

    _polyorch_rust_cbindgen_cmd(TOOL "${_tool}" CRATE "${_pkg}"
        OUTPUT "${_hdr}" DEPFILE "${_dfl}" TRIPLE "${_triple}"
        CARGO "${POLYORCH_RUST_CARGO}" RUSTC "${POLYORCH_RUST_RUSTC}"
        FLAGS "${CN_FLAGS}" OUT_CMD _cmd)
    add_custom_command(
        OUTPUT "${_hdr}"
        COMMAND ${_cmd}
        ${_tdepkw}
        COMMENT "Generate cbindgen bindings for package ${_pkg} and output header ${_hdr}"
        DEPFILE "${_dfl}"
        COMMAND_EXPAND_LISTS
        WORKING_DIRECTORY "${_mdir}")

    set(_agg "polyorch-cbindgen-${_bt}-bindings")
    if(NOT TARGET "${_agg}")
        add_custom_target("${_agg}"
            COMMENT "Generate cbindgen bindings for package ${_pkg}")
    endif()
    string(MAKE_C_IDENTIFIER "${CN_HEADER_NAME}" _hid)
    set(_per "${_agg}.${_hid}")
    if(TARGET "${_per}")
        message(FATAL_ERROR
            "polyorch_rust_cbindgen: regeneration target '${_per}' already exists (same header generated twice for ${_bt})")
    endif()
    add_custom_target("${_per}" DEPENDS "${_hdr}")
    add_dependencies("${_agg}" "${_per}")
    add_dependencies("${_bt}" "${_agg}")
    if(_auto)
        # corr:2261-2263: the cargo build of the crate waits for fresh
        # headers (the annotations the generator reads are the source of
        # truth in both directions).
        add_dependencies("cargo-build-${CN_TARGET}" "${_agg}")
    endif()
endfunction()
