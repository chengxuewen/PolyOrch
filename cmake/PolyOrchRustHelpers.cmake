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
        message(FATAL_ERROR
            "polyorch_rust_build: pick exactly one of BINARY, STATIC, SHARED")
    endif()
    _polyorch_rust_require_setup(polyorch_rust_build)

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
    _polyorch_rust_target_dir(_td "${B_BASE_DIR}")
    _polyorch_rust_artifact_names(TRIPLE "${POLYORCH_RUST_HOST_TARGET}"
        KIND "${_kind}" CRATE "${B_CRATE}" PROFILE "${_prof}" BASE_DIR "${_td}"
        FILE_OUT _file IMPLIB_OUT _implib)
    if(_mc)
        set(_dir "${_td}/$<IF:$<OR:$<CONFIG:Debug>,$<CONFIG:>>,debug,release>")
    else()
        set(_dir "${_td}/${_prof}")   # == artifact_names DIR_OUT contract
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
    list(APPEND _argv "${_features_gx}" "${_allf_gx}" "${_nondf_gx}" "${_flags_gx}")
    list(APPEND _argv --target-dir "${_td}")
    _polyorch_rust_command(_cmd SUBCOMMAND ${_argv} ENV "${_env_gx}" "${_rustflags_gx}")

    set(_byproducts "")
    set(_implib_path "")
    if(_implib)
        # gnullvm: cargo emits the import library under deps/, not the
        # profile root (corr:334-337) -- the BYPRODUCTS stamp follows the
        # real source location so the rule stays honest there.
        set(_implib_path "${_dir}/${_implib}")
        if(POLYORCH_RUST_HOST_TARGET MATCHES "gnullvm$")
            set(_implib_path "${_dir}/deps/${_implib}")
        endif()
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
        "${_kind}" "${B_CRATE}" "${_td}" "${_prof}" "${_mc}")
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
function(_polyorch_rust_finalize target triple kind crate td prof mc)
    cmake_language(EVAL CODE "
        cmake_language(DEFER CALL
            _polyorch_rust_finalize_deferred
            [[${target}]] [[${triple}]] [[${kind}]] [[${crate}]]
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
function(_polyorch_rust_finalize_pass target triple crate td prof oprop f ck cfg mc out_loc out_src out_dir)
    if(NOT "${prof}" STREQUAL "per-config")
        set(_pd "${prof}")
    elseif("${cfg}" STREQUAL "Debug")
        set(_pd debug)
    else()
        set(_pd release)   # corr:762/772: every non-Debug config -> release
    endif()
    _polyorch_rust_copy_plan(TRIPLE "${triple}" KIND "${ck}" CRATE "${crate}"
        SRC_DIR "${td}/${_pd}" DEST_DIR "${td}/${_pd}" OUT _pr)
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
# the file-name half never carries a genex).
function(_polyorch_rust_finalize_deferred target triple kind crate td prof mc)
    if(ARGN)
        message(FATAL_ERROR
            "_polyorch_rust_finalize_deferred: unexpected additional arguments: ${ARGN}")
    endif()
    # File names from the frozen table (profile-independent; the
    # per-config sentinel only ever rides the directory).
    _polyorch_rust_artifact_names(TRIPLE "${triple}" KIND "${kind}"
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
                _polyorch_rust_finalize_pass("${target}" "${triple}" "${crate}"
                    "${td}" "${prof}" "${_oprop}" "${_f}" "${_ck}" "${_cfg}" TRUE
                    _loc _src _dir)
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
            _polyorch_rust_finalize_pass("${target}" "${triple}" "${crate}"
                "${td}" "${prof}" "${_oprop}" "${_f}" "${_ck}"
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