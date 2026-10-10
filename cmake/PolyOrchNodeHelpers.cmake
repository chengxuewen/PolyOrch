# PolyOrchNodeHelpers.cmake -- the node/npm bridge (D29, WP-node-alpha)
#
# Five verbs mirroring the rust face, under the eight user adjudications of
# 2026-09-30 (.omo/plans/2026-09-30-node-bridge-alpha.md, D29):
#   1. corepack abstraction   -- one entry for npm/pnpm (yarn rides along);
#      the project's own "packageManager" field picks the PM, we never pin.
#   2. dist/ convention       -- artifacts land in <manifest-dir>/dist unless
#      OUTPUT_DIR overrides; reading package.json (main/module/exports) is
#      manifest reading (legal), reading tsconfig/vite.config is config
#      probing (forbidden -- we never do it).
#   3. dev-server DEFER       -- run is a ONE-SHOT verb; a long-lived dev
#      server is not the build graph's job (the orchestrator does not run
#      processes).
#   4. scripts dispatch only  -- polyorch_node_build runs `<pm> run build`;
#      we never invoke tsc/vite/swc ourselves (the whitepaper's "does not
#      compile code itself" clause).
#   5. three-tier discovery   -- explicit -DPolyOrchNodeExe= > PATH node >
#      pixi env glob, then STATUS degradation (the rust-nodejs idiom; nvm
#      users: `nvm use` before configuring -- documented, not special-cased).
#
# IDE source mount (2026-10-09, rust-face parity -- the python face carries
# the same FOLDER idiom; this is the SOURCES half): every verb node lists
# the package's display files (js/mjs/cjs/ts/tsx/jsx glob minus
# node_modules/dist/build/dot-dirs, + package.json + root lockfiles) as
# HEADER_FILE_ONLY SOURCES -- cosmetic, never compile inputs. NO_SOURCES
# opts out in build(); PolyOrch_NODE_SOURCES_PLAIN is the escape hatch.
# Naming: real targets are kebab-case; fused trees namespace them through
# PolyOrch_NODE_TARGET_PREFIX (this module's own knob -- A2: the name says
# NODE and means NODE; the rust knob stays the rust knob's). Fusion loop
# wiring is in examples/CMakeLists.txt.
#
# Requires CMake >= 3.25 (PARSE_ARGV, string(JSON ...)).

cmake_minimum_required(VERSION 3.25)

# ---------------------------------------------------------------------------
# options
# ---------------------------------------------------------------------------

# PolyOrch_NODE_VSCODE_DEBUG -- emit js-debug launch rows for handles
# registered by polyorch_node_debug() (default OFF; examples opt in).
# Declared AFTER the module's own cmake_minimum_required above and NOT at
# the file top like the python/rust gates (they carry no cmr): under
# CMP0077 NEW a consumer's preceding set() survives option(); declared
# before any cmr the policy context is OLD and option() WIPES the pre-set
# variable -- the standalone opt-in would silently no-op, invisible on
# node-less hosts (measured, D33).
option(PolyOrch_NODE_VSCODE_DEBUG
    "Generate VSCode js-debug launch configs for polyorch_node_debug handles" OFF)

# PolyOrch_NODE_SOURCES_PLAIN -- serve the IDE source mount as plain
# sources instead of HEADER_FILE_ONLY (escape hatch for IDE versions that
# fold header-class entries away; mirrors PolyOrch_RUST_SOURCES_PLAIN).
# Same post-cmr placement as the gate above -- the CMP0077 OLD-wipe
# deviation is a class, not a line (PIT-48 sweep doctrine).
option(PolyOrch_NODE_SOURCES_PLAIN
    "Serve node IDE display sources as plain sources instead of HEADER_FILE_ONLY" OFF)

# IDE grouping: every node creation site below consumes the fusion loop's
# PolyOrch_RUST_FOLDER_ROOT (the family root knob despite the historical
# RUST substring) exactly like the python face's run() does since 02df192.
# Deliberate behavior change recorded in D33: standalone node-web no longer
# synthesizes a relative-path FOLDER -- standalone stays unset, family law.

# ---------------------------------------------------------------------------
# discovery
# ---------------------------------------------------------------------------

# polyorch_node_setup([REQUIRED])
#
# Locates node + the package manager and caches:
#   PolyOrchNode_EXECUTABLE     -- node binary (cache FILEPATH)
#   PolyOrchNode_PM_EXECUTABLE  -- the dispatch prefix: a list whose first
#                                  entry is corepack or the PM itself
#                                  (e.g. "corepack;npm" or "npm;npm"), second
#                                  entry the bare PM name (npm|pnpm) used to
#                                  pick the workspace-flag template.
#   POLYORCH_NODE_FOUND         -- TRUE when both exist.
#
# Degradation contract (mirrors polyorch_rust_setup): without REQUIRED a
# missing toolchain is a STATUS note and POLYORCH_NODE_FOUND=FALSE; with
# REQUIRED it is FATAL. The user configuring this module explicitly is an
# environment statement -- fail loud for them (the rust-basic L34 idiom).
function(polyorch_node_setup)
    set(_opts REQUIRED QUIET)
    cmake_parse_arguments(PARSE_ARGV 0 S "" "" "${_opts}")

    set(_roots "$ENV{HOME}/.pixi/bin")
    # tier a FIRST: the explicit knob wins over everything (rust-nodejs
    # idiom; -DPolyOrchNodeExe=, name per adjudication A2). The PM tier
    # below was already knob-first; the node exe tier was not -- measured
    # 2026-10-08 the pre-knob find_program wrote the result variable and a
    # real PATH node beat the stub (the exact NO_CACHE-class footgun the
    # python face fixed in D32's contact round; the comment promised the
    # right thing while the order did the wrong one -- order IS the fix).
    if(PolyOrchNodeExe)
        set(PolyOrchNode_EXECUTABLE "${PolyOrchNodeExe}")
    else()
        # tier b: PATH (+ ~/.pixi/bin so a bare pixi install counts, same
        # as the rust face's cargo probe)
        find_program(PolyOrchNode_EXECUTABLE NAMES node
            HINTS ${_roots} NO_CACHE)
    endif()

    set(_found TRUE)
    if(NOT PolyOrchNode_EXECUTABLE)
        # tier c: a pixi env's bin/node (any env counts; the glob is the
        # rust-nodejs case's proven fallback)
        file(GLOB _pixi_node
            "$ENV{HOME}/.pixi/envs/*/bin/node"
            "/tmp/opencode/*/.pixi/envs/default/bin/node")
        list(LENGTH _pixi_node _pn)
        if(_pn GREATER 0)
            list(GET _pixi_node 0 PolyOrchNode_EXECUTABLE)
        endif()
    endif()
    if(NOT PolyOrchNode_EXECUTABLE)
        set(_found FALSE)
    endif()

    # PM discovery (adjudication 1): corepack proxies; without it, bare npm.
    # We never pin versions -- the project's packageManager field decides
    # through corepack itself.
    set(_pm "npm")
    set(_pm_argv)                     # dispatch prefix, may stay empty
    # tier-a for the PM too (the case passes the stub through PASSTHROUGH):
    # PolyOrchNodeCorepack=<path> wins, then PATH corepack, then bare npm.
    if(PolyOrchNodeCorepack)
        set(_pm_argv "${PolyOrchNodeCorepack}" "${_pm}")
    endif()
    if(NOT _pm_argv)
        find_program(PolyOrchNode_COREPACK NAMES corepack
            HINTS ${_roots} NO_CACHE)
    endif()
    if(NOT _pm_argv AND PolyOrchNode_COREPACK)
        set(_pm_argv "${PolyOrchNode_COREPACK}" "${_pm}")
    endif()
    if(NOT _pm_argv)
        # bare-npm tier: the explicit knob first (same contract as the
        # corepack one), then PATH
        if(PolyOrchNodeNpm)
            set(_pm_argv "${PolyOrchNodeNpm}")
        else()
            # HINTS ~/.pixi/bin: a pixi-global nodejs exposes npm beside
            # node (measured 2026-10-08: PATH-less interactive shells found
            # the node tier through its HINTS but failed the PM tier ->
            # half-missing degradation with the toolchain installed).
            find_program(PolyOrchNode_NPM NAMES npm
                HINTS ${_roots} NO_CACHE)
            if(PolyOrchNode_NPM)
                set(_pm_argv "${PolyOrchNode_NPM}")
            endif()
        endif()
    endif()
    if(NOT _pm_argv)
        # node without any PM cannot run scripts: POLYORCH_NODE_FOUND goes
        # FALSE (the verbs need the PM), but the STATUS says WHICH half is
        # missing -- "node not found" was a misleading report.
        set(_pm_missing TRUE)
        set(_found FALSE)
    elseif(PolyOrchNode_NPM)
        set(_pm_argv "${PolyOrchNode_NPM}")
    endif()
    set(PolyOrchNode_EXECUTABLE "${PolyOrchNode_EXECUTABLE}" CACHE FILEPATH
        "node binary (tier a/b/c resolved)" FORCE)
    set(PolyOrchNode_PM_EXECUTABLE "${_pm_argv}" CACHE STRING
        "node PM dispatch prefix (corepack-wrapped or bare npm)" FORCE)
    set(PolyOrchNode_PM_NAME "${_pm}" CACHE STRING
        "the bare PM name: npm|pnpm -- picks the workspace-flag template" FORCE)
    set(POLYORCH_NODE_FOUND "${_found}" CACHE BOOL "node toolchain located" FORCE)

    if(_found)
        execute_process(COMMAND "${PolyOrchNode_EXECUTABLE}" --version
            OUTPUT_VARIABLE _nv OUTPUT_STRIP_TRAILING_WHITESPACE
            RESULT_VARIABLE _nrc)
        set(_via "")
        if(PolyOrchNode_COREPACK)
            set(_via ", via corepack")
        endif()
        message(STATUS "polyorch_node: node ${_nv} (pm: ${_pm}${_via})")
    else()
        if(S_REQUIRED)
            message(FATAL_ERROR
                "polyorch_node_setup: node not found (pass -DPolyOrchNodeExe=<path>)")
        endif()
        if(NOT S_QUIET)
            if(_pm_missing)
                message(STATUS
                    "polyorch_node: node ${PolyOrchNode_EXECUTABLE} found but no "
                    "npm/corepack on PATH -- node verbs will not register "
                    "(install npm, or provide corepack; corepack ships with node)")
            else()
                message(STATUS
                    "polyorch_node: node not found -- node verbs will not register "
                    "(pass -DPolyOrchNodeExe=<path>, e.g. a pixi env's bin/node)")
            endif()
        endif()
    endif()
endfunction()

# ---------------------------------------------------------------------------
# naming
# ---------------------------------------------------------------------------

# _polyorch_node_apply_prefix(OUT NAME)
#
# A2: node owns its prefix helper (the rust one hardcodes the RUST knob and
# would silently drop our prefix -- Momus blocker 1 of the D28 round, do not
# "reuse" it). Empty knob = bare name. The caller-project key follows the
# D28 formula, node flavor.
function(_polyorch_node_apply_prefix out name)
    set(_p "")
    if(DEFINED ${PROJECT_NAME}_POLYORCH_NODE_TARGET_PREFIX
            AND NOT "${${PROJECT_NAME}_POLYORCH_NODE_TARGET_PREFIX}" STREQUAL "")
        set(_p "${${PROJECT_NAME}_POLYORCH_NODE_TARGET_PREFIX}")
    elseif(PolyOrch_NODE_TARGET_PREFIX)
        set(_p "${PolyOrch_NODE_TARGET_PREFIX}")
    endif()
    if(_p)
        set(${out} "${_p}-${name}" PARENT_SCOPE)
    else()
        set(${out} "${name}" PARENT_SCOPE)
    endif()
endfunction()

# _polyorch_node_sanitize_name(OUT <npm-name>)
#
# A1 as amended by the implementation smoke: '/' -> '-', and the leading
# '@' is STRIPPED -- add_custom_target REJECTS '@'-headed names outright
# ("reserved or not valid", measured on this configure). So '@org/pkg' ->
# 'org-pkg'. The B degradation Momus pre-approved was exercised for real:
# the original A form kept the '@' and CMake said no. Collision between a
# scoped package and a hypothetical bare 'org-pkg' remains guarded by the
# duplicate-handle FATAL in import.
function(_polyorch_node_sanitize_name out name)
    string(REPLACE "/" "-" _san "${name}")
    string(REGEX REPLACE "^@" "" _san "${_san}")
    set(${out} "${_san}" PARENT_SCOPE)
endfunction()

# _polyorch_node_read_entry(OUT <manifest>)
#
# Entry-file resolution order (implementation memo): main -> module ->
# exports["."]. Empty result means the package has no declared entry; the
# handle's LOCATION then points at the dist DIRECTORY (a directory product
# is legal for an IMPORTED target of type INTERFACE... but keep v0.1 honest:
# we point at <dist> itself and document it).
function(_polyorch_node_read_entry out manifest)
    file(READ "${manifest}" _json)
    set(_entry "")
    foreach(_k main module)
        string(JSON _v ERROR_VARIABLE _jerr GET "${_json}" "${_k}")
        if(NOT _jerr AND NOT _v STREQUAL "")
            set(_entry "${_v}")
            break()
        endif()
    endforeach()
    if(_entry STREQUAL "")
        string(JSON _v ERROR_VARIABLE _jerr GET "${_json}" exports ".")
        if(NOT _jerr)
            # exports["."] may be a string or an object with a "default" key
            string(JSON _t ERROR_VARIABLE _terr TYPE "${_json}" exports ".")
            if(_t STREQUAL "STRING")
                set(_entry "${_v}")
            elseif(_t STREQUAL "OBJECT")
                string(JSON _v2 ERROR_VARIABLE _jerr2 GET "${_v}" "default")
                if(NOT _jerr2)
                    set(_entry "${_v2}")
                endif()
            endif()
        endif()
    endif()
    set(${out} "${_entry}" PARENT_SCOPE)
endfunction()

# _polyorch_node_mount_sources(TGT PKG_DIR) -- the rust face's
# _polyorch_rust_mount_sources ported (corr: the mount pair at
# PolyOrchRustHelpers 1366-1428). Attach the package's display files
# (source glob + package.json + root lockfiles) to TGT's SOURCES so IDE
# target trees show and open them at every verb node. COSMETIC ONLY: the
# PM owns the real build inputs (a script is dispatched, never compiled
# here), so a glob miss or stray hit never affects correctness -- that
# distinction is why the GLOB caution in the CMake docs does not apply.
# Excluded by design: node_modules/, dist/, build/ and every dot-dir --
# vendor trees would flood the IDE listing with thousands of files.
# SOFT = display-only caller (verb nodes): a missing dir skips the mount
# instead of failing the configure -- a display feature never fails a
# configure. build()/import call HARD: the dir's manifest was just read
# from it, so a miss here means it vanished mid-configure -- a real
# configuration error (the rust HARD stamp tripwire, same semantics).
function(_polyorch_node_mount_sources TGT PKG_DIR)
    cmake_parse_arguments(PARSE_ARGV 2 MM "SOFT" "" "")
    get_filename_component(_dir "${PKG_DIR}" ABSOLUTE)
    if(NOT IS_DIRECTORY "${_dir}")
        if(MM_SOFT)
            return()
        endif()
        message(FATAL_ERROR
            "_polyorch_node_mount_sources: package dir missing: ${_dir}")
    endif()
    # CONFIGURE_DEPENDS mirrors the rust mount comment: newly added files
    # appear on rebuild without a hand-run re-glob; LIST_DIRECTORIES false
    # keeps a directory named *.js out of the file list.
    file(GLOB_RECURSE _srcs CONFIGURE_DEPENDS LIST_DIRECTORIES false
        "${_dir}/*.js" "${_dir}/*.mjs" "${_dir}/*.cjs"
        "${_dir}/*.ts" "${_dir}/*.tsx" "${_dir}/*.jsx")
    set(_keep "")
    foreach(_f IN LISTS _srcs)
        file(RELATIVE_PATH _rel "${_dir}" "${_f}")
        if(_rel MATCHES "(^|/)(node_modules|dist|build|\\.[^/]+)(/|$)")
            continue()
        endif()
        list(APPEND _keep "${_f}")
    endforeach()
    # the manifest (and the lockfiles, once generated) are where dependency
    # edits live -- they join the display list explicitly (rust does the
    # same with Cargo.toml/Cargo.lock). A workspace member has no lockfile
    # of its own; the root's rides on the root's mount -- honest display.
    list(APPEND _keep "${_dir}/package.json")
    foreach(_lock package-lock.json pnpm-lock.yaml yarn.lock)
        if(EXISTS "${_dir}/${_lock}")
            list(APPEND _keep "${_dir}/${_lock}")
        endif()
    endforeach()
    list(REMOVE_DUPLICATES _keep)
    # HEADER_FILE_ONLY marks them "not compiled here" for CMake; some
    # IDE versions fold header-class entries away in target trees, so
    # PolyOrch_NODE_SOURCES_PLAIN=ON serves them as plain sources.
    if(PolyOrch_NODE_SOURCES_PLAIN)
        set_source_files_properties(${_keep} PROPERTIES
            HEADER_FILE_ONLY OFF)
    else()
        set_source_files_properties(${_keep} PROPERTIES
            HEADER_FILE_ONLY ON)   # IDE display, never compile inputs
    endif()
    set_property(TARGET "${TGT}" APPEND PROPERTY SOURCES ${_keep})
endfunction()

# _polyorch_node_mount_verb_targets(HANDLE TGT)
# run/test verb nodes reuse the POLYORCH_NODE_DIR_ stamp build()/import
# left on the handle. Silent skip when the stamp is absent -- display
# features never fail a configure. One layer simpler than the rust twin:
# node stamps the package dir globally per handle, so there is no
# manifest/CRATE deref chain to read (and no metadata authority exists
# for node -- the glob IS the list, cosmetically).
function(_polyorch_node_mount_verb_targets HANDLE TGT)
    get_property(_dir GLOBAL PROPERTY "POLYORCH_NODE_DIR_${HANDLE}")
    if(NOT _dir)
        return()
    endif()
    _polyorch_node_mount_sources("${TGT}" "${_dir}" SOFT)
endfunction()

# ---------------------------------------------------------------------------
# verbs
# ---------------------------------------------------------------------------

# polyorch_node_import(ROOT <root-package.json>)
#
# Reads the root manifest's "workspaces" globs, expands them, and registers
# one imported handle + one -build mediator per member. Members' `name`
# fields drive handles through _polyorch_node_sanitize_name (A1). Members
# depending on siblings via the `workspace:` protocol get -build dependency
# edges (same-root edges only -- registry deps do not graph, mirroring the
# rust import's philosophy). Skips non-directories and manifest-less matches
# loudly (STATUS, not silently).
function(polyorch_node_import)
    set(_one ROOT)
    cmake_parse_arguments(PARSE_ARGV 0 I "" "${_one}" "")
    if(NOT I_ROOT)
        message(FATAL_ERROR "polyorch_node_import: ROOT is required")
    endif()
    if(NOT POLYORCH_NODE_FOUND)
        message(STATUS "polyorch_node_import: skipped -- node toolchain absent")
        return()
    endif()
    get_filename_component(_root_dir "${I_ROOT}" DIRECTORY)
    file(READ "${I_ROOT}" _root_json)
    string(JSON _ws_type ERROR_VARIABLE _jerr TYPE "${_root_json}" workspaces)
    if(_jerr)
        message(FATAL_ERROR
            "polyorch_node_import: ${I_ROOT} has no workspaces field")
    endif()
    # workspaces: array of globs (npm/pnpm shape). The object-with-packages
    # shape (yarn) is NOT v0.1.
    if(NOT _ws_type STREQUAL "ARRAY")
        message(FATAL_ERROR
            "polyorch_node_import: workspaces must be an array of globs "
            "(the yarn object form is not supported in v0.1)")
    endif()
    string(JSON _n LENGTH "${_root_json}" workspaces)
    if(_n EQUAL 0)
        message(FATAL_ERROR "polyorch_node_import: empty workspaces array")
    endif()

    set(_handles "")
    math(EXPR _last "${_n} - 1")
    foreach(_i RANGE ${_last})
        # GET with the array index as the path tail (MEMBER is for OBJECT
        # key iteration; arrays go through GET <doc> workspaces <i>)
        string(JSON _glob GET "${_root_json}" workspaces ${_i})
        file(GLOB _member_dirs "${_root_dir}/${_glob}")
        foreach(_mdir ${_member_dirs})
            if(NOT IS_DIRECTORY "${_mdir}")
                continue()
            endif()
            set(_mf "${_mdir}/package.json")
            if(NOT EXISTS "${_mf}")
                message(STATUS
                    "polyorch_node_import: workspace match without manifest, skipped: ${_mdir}")
                continue()
            endif()
            file(READ "${_mf}" _mj)
            string(JSON _name ERROR_VARIABLE _jerr GET "${_mj}" name)
            if(_jerr)
                message(FATAL_ERROR
                    "polyorch_node_import: member without a name: ${_mf}")
            endif()
            _polyorch_node_sanitize_name(_handle "${_name}")
            _polyorch_node_apply_prefix(_handle "${_handle}")
            if(_handles MATCHES "(^|;)${_handle}(;|$)")
                message(FATAL_ERROR
                    "polyorch_node_import: duplicate sanitized handle '${_handle}' "
                    "(npm names differing only in scope separators collide; "
                    "adjust the workspace or rename a package)")
            endif()
            list(APPEND _handles "${_handle}")

            # the build mediator: the two-row template table (Momus fix 2).
            # WORKING_DIRECTORY is the root -- workspace commands are rooted.
            _polyorch_node_ws_args(_wsargs "${_name}")
            _polyorch_node_rule_path(_impenv)
            add_custom_target("${_handle}-build"
                COMMAND ${CMAKE_COMMAND} -E env "${_impenv}"
                    ${PolyOrchNode_PM_EXECUTABLE} run build ${_wsargs}
                WORKING_DIRECTORY "${_root_dir}"
                USES_TERMINAL
                COMMENT "node: build ${_name} (${_handle})")
            if(PolyOrch_RUST_FOLDER_ROOT)
                set_target_properties("${_handle}-build" PROPERTIES
                    FOLDER "${PolyOrch_RUST_FOLDER_ROOT}")
            endif()

            # IDE source mount on the member mediator (rust parity). No
            # per-member NO_SOURCES knob -- YAGNI; the opt-out lives where
            # rust has it: build().
            _polyorch_node_mount_sources("${_handle}-build" "${_mdir}")

            # entry + LOCATION (adjudication 2: dist/ convention)
            _polyorch_node_read_entry(_entry "${_mf}")
            set(_out_dir "${_mdir}/dist")
            if(_entry)
                set_property(TARGET "${_handle}-build" PROPERTY
                    IMPORTED_LOCATION_NOT_AVAILABLE "")
            endif()
            set_property(GLOBAL APPEND PROPERTY
                POLYORCH_NODE_HANDLES "${_handle}")
            set_property(GLOBAL PROPERTY "POLYORCH_NODE_MANIFEST_${_handle}"
                "${_mf}")
            set_property(GLOBAL PROPERTY "POLYORCH_NODE_PKG_${_handle}"
                "${_name}")
            set_property(GLOBAL PROPERTY "POLYORCH_NODE_ROOT_${_handle}"
                "${_root_dir}")
            set_property(GLOBAL PROPERTY "POLYORCH_NODE_DIR_${_handle}"
                "${_mdir}")
        endforeach()
    endforeach()

    # workspace: dependency edges (same root only)
    foreach(_handle ${_handles})
        get_property(_mf GLOBAL PROPERTY "POLYORCH_NODE_MANIFEST_${_handle}")
        file(READ "${_mf}" _mj)
        foreach(_sect dependencies devDependencies)
            string(JSON _deps ERROR_VARIABLE _jerr GET "${_mj}" "${_sect}")
            if(_jerr)
                continue()      # section absent
            endif()
            string(JSON _dn LENGTH "${_mj}" "${_sect}")
            math(EXPR _dlast "${_dn} - 1")
            foreach(_di RANGE ${_dlast})
                string(JSON _dep MEMBER "${_mj}" "${_sect}" ${_di})
                string(JSON _ver ERROR_VARIABLE _verr GET "${_mj}" "${_sect}" "${_dep}")
                if(_verr OR NOT _ver MATCHES "^workspace:")
                    continue()
                endif()
                _polyorch_node_sanitize_name(_dep_handle "${_dep}")
                _polyorch_node_apply_prefix(_dep_handle "${_dep_handle}")
                if(TARGET "${_dep_handle}-build")
                    add_dependencies("${_handle}-build" "${_dep_handle}-build")
                else()
                    message(STATUS
                        "polyorch_node_import: workspace dep '${_dep}' of "
                        "'${_handle}' matches no imported member -- edge skipped")
                endif()
            endforeach()
        endforeach()
    endforeach()

    # registry report (mirrors polyorch_rust_import's report line)
    list(LENGTH _handles _nh)
    set(_skipped_note)
    if(NOT _nh)
        set(_skipped_note " (0 members matched)")
    endif()
    message(STATUS
        "polyorch_node_import: ${_nh} handle(s) imported [${_handles}]${_skipped_note}")
    set(POLYORCH_NODE_IMPORT_HANDLES "${_handles}" PARENT_SCOPE)
endfunction()

# _polyorch_node_ws_args(OUT <package-name>)
#
# The two-row workspace-flag table (Momus fix 2):
#   npm:  -w <name>   AFTER the subcommand
#   pnpm: --filter <name>  BEFORE the subcommand -> expressed as
#         run --filter <name> ... NO. pnpm requires the filter before the
#         subcommand; but `pnpm run` reads `--filter` fine as a pre-flag of
#         the `run` verb when placed before `run`. We dispatch:
#         npm  -> "-w;<name>"             (appended after `run build`)
#         pnpm -> "--filter;<name>;run;build" replaces the whole shape
# Since the mediator's COMMAND starts with "<pm> run build", pnpm needs the
# shape "<pm> --filter <name> run build". To keep ONE command site, this
# helper returns the FULL subcommand tail: for npm "-w <name>", for pnpm
# "--filter <name> run build"... which forces run-before/after knowledge at
# the caller. Cleaner: this module's mediators are built by
# _polyorch_node_build_command(OUT <list> NAME <pkg> SCRIPT <s>) below.
# _polyorch_node_rule_path <out>
# The PATH a package-manager rule carries so an npm script can resolve its
# own toolchain siblings (tsc, node) regardless of the AMBIENT PATH of
# whatever runs `cmake --build` (PIT-62: a VSCode task shell lacks the
# tool dir, so `npm run build` -> `tsc: not found`; the node-face twin of
# the rust PIT-14 host-env isolation). Prepends the node bin dir, the PM
# bin dir, and any example-declared tool dirs (PolyOrchNode_BUILD_ENV_PATH)
# to the configure-time PATH. The example sets the knob for tools that may
# live elsewhere than node (tsc is not guaranteed co-located).
function(_polyorch_node_rule_path out)
    get_filename_component(_nb "${PolyOrchNode_EXECUTABLE}" DIRECTORY)
    get_filename_component(_pb "${PolyOrchNode_PM_EXECUTABLE}" DIRECTORY)
    set(_pp "${_nb}:${_pb}")
    if(PolyOrchNode_BUILD_ENV_PATH)
        string(REPLACE ";" ":" _xp "${PolyOrchNode_BUILD_ENV_PATH}")
        string(APPEND _pp ":${_xp}")
    endif()
    set(${out} "PATH=${_pp}:$ENV{PATH}" PARENT_SCOPE)
endfunction()

function(_polyorch_node_ws_args out package)
    if(PolyOrchNode_PM_NAME STREQUAL "pnpm")
        set(${out} "--filter" "${package}" PARENT_SCOPE)
    else()
        set(${out} "-w" "${package}" PARENT_SCOPE)
    endif()
endfunction()

# polyorch_node_build(TARGET <handle> MANIFEST <package.json> [OUTPUT_DIR <dir>] [NO_SOURCES])
#
# Registers a single-package handle + -build mediator WITHOUT a workspace
# root (the standalone shape; import covers the workspace shape). Same
# command table minus the workspace flags, same dist convention.
# OUTPUT_DIR overrides <manifest-dir>/dist (adjudication 2).
function(polyorch_node_build)
    set(_one TARGET MANIFEST OUTPUT_DIR)
    set(_opts NO_SOURCES)
    cmake_parse_arguments(PARSE_ARGV 0 B "${_opts}" "${_one}" "")
    if(NOT B_TARGET OR NOT B_MANIFEST)
        message(FATAL_ERROR
            "polyorch_node_build: TARGET and MANIFEST are required")
    endif()
    if(NOT POLYORCH_NODE_FOUND)
        message(STATUS "polyorch_node_build: skipped -- node toolchain absent")
        return()
    endif()
    get_filename_component(_mdir "${B_MANIFEST}" DIRECTORY)
    file(READ "${B_MANIFEST}" _mj)
    string(JSON _name ERROR_VARIABLE _jerr GET "${_mj}" name)
    if(_jerr)
        message(FATAL_ERROR "polyorch_node_build: manifest without a name: ${B_MANIFEST}")
    endif()
    _polyorch_node_apply_prefix(_handle "${B_TARGET}")
    if(TARGET "${_handle}-build")
        message(FATAL_ERROR
            "polyorch_node_build: handle '${_handle}' already registered")
    endif()
    # PATH self-sufficiency (PIT-62, D37 user-found via the real VSCode F5
    # chain): wrap the PM invocation so the script resolves its own
    # toolchain siblings, never the invoker's ambient PATH.
    _polyorch_node_rule_path(_penv)
    add_custom_target("${_handle}-build"
        COMMAND ${CMAKE_COMMAND} -E env "${_penv}"
            ${PolyOrchNode_PM_EXECUTABLE} run build
        WORKING_DIRECTORY "${_mdir}"
        USES_TERMINAL
        COMMENT "node: build ${_name} (${_handle})")
    if(PolyOrch_RUST_FOLDER_ROOT)
        set_target_properties("${_handle}-build" PROPERTIES
            FOLDER "${PolyOrch_RUST_FOLDER_ROOT}")
    endif()

    # IDE source mount on the mediator (rust parity). HARD is a tripwire
    # only: _mdir is the directory of the manifest read a few lines above.
    if(NOT B_NO_SOURCES)
        _polyorch_node_mount_sources("${_handle}-build" "${_mdir}")
    endif()

    set_property(GLOBAL PROPERTY "POLYORCH_NODE_MANIFEST_${_handle}"
        "${B_MANIFEST}")
    set_property(GLOBAL PROPERTY "POLYORCH_NODE_ROOT_${_handle}"
        "${_mdir}")
    set_property(GLOBAL PROPERTY "POLYORCH_NODE_PKG_${_handle}"
        "${_name}")
    set_property(GLOBAL PROPERTY "POLYORCH_NODE_DIR_${_handle}"
        "${_mdir}")
    message(STATUS
        "polyorch_node_build: ${_handle} registered (single package ${_name})")
endfunction()

# polyorch_node_test(TARGET <handle>)
#
# Registers <handle>-test ONLY when the member's package.json declares
# scripts.test (loud STATUS skip otherwise -- never silent).
function(polyorch_node_test)
    set(_one TARGET)
    cmake_parse_arguments(PARSE_ARGV 0 T "" "${_one}" "")
    _polyorch_node_apply_prefix(_th "${T_TARGET}")
    get_property(_mf GLOBAL PROPERTY "POLYORCH_NODE_MANIFEST_${_th}")
    if(NOT _mf)
        message(FATAL_ERROR "polyorch_node_test: unknown handle '${T_TARGET}' "
            "(import first, or use the import-returned handle names)")
    endif()
    file(READ "${_mf}" _mj)
    string(JSON _has ERROR_VARIABLE _jerr GET "${_mj}" scripts test)
    if(_jerr)
        message(STATUS
            "polyorch_node_test: '${T_TARGET}' has no scripts.test -- not registered")
        return()
    endif()
    get_property(_root GLOBAL PROPERTY "POLYORCH_NODE_ROOT_${_th}")
    get_property(_pkg GLOBAL PROPERTY "POLYORCH_NODE_PKG_${_th}")
    _polyorch_node_ws_args(_wsargs "${_pkg}")
    _polyorch_node_rule_path(_tstenv)
    add_custom_target("${_th}-test"
        COMMAND ${CMAKE_COMMAND} -E env "${_tstenv}"
            ${PolyOrchNode_PM_EXECUTABLE} run test ${_wsargs}
        WORKING_DIRECTORY "${_root}"
        USES_TERMINAL
        COMMENT "node: test ${_pkg} (${_th})")
    if(PolyOrch_RUST_FOLDER_ROOT)
        set_target_properties("${_th}-test" PROPERTIES
            FOLDER "${PolyOrch_RUST_FOLDER_ROOT}")
    endif()
    # IDE parity: the test node mounts the same display files as the
    # build mediator (SOFT -- verb-node reuse of the stamped dir).
    _polyorch_node_mount_verb_targets("${_th}" "${_th}-test")
endfunction()

# polyorch_node_run(TARGET <handle> SCRIPT <name> [ARGS ...])
#
# ONE-SHOT script dispatch (adjudication 3: a long-lived dev server is not
# the build graph's job). ARGS pass through "--" to the script.
function(polyorch_node_run)
    set(_one TARGET SCRIPT)
    set(_multi ARGS)
    cmake_parse_arguments(PARSE_ARGV 0 R "" "${_one}" "${_multi}")
    if(NOT R_TARGET OR NOT R_SCRIPT)
        message(FATAL_ERROR "polyorch_node_run: TARGET and SCRIPT are required")
    endif()
    _polyorch_node_apply_prefix(_rh "${R_TARGET}")
    get_property(_root GLOBAL PROPERTY "POLYORCH_NODE_ROOT_${_rh}")
    if(NOT _root)
        message(FATAL_ERROR "polyorch_node_run: unknown handle '${R_TARGET}'")
    endif()
    get_property(_pkg GLOBAL PROPERTY "POLYORCH_NODE_PKG_${_rh}")
    _polyorch_node_ws_args(_wsargs "${_pkg}")
    set(_tail "")
    if(R_ARGS)
        list(APPEND _tail "--")
        list(APPEND _tail ${R_ARGS})
    endif()
    _polyorch_node_rule_path(_rnenv)
    add_custom_target("${_rh}-run-${R_SCRIPT}"
        COMMAND ${CMAKE_COMMAND} -E env "${_rnenv}"
            ${PolyOrchNode_PM_EXECUTABLE} run ${_wsargs} ${R_SCRIPT} ${_tail}
        WORKING_DIRECTORY "${_root}"
        USES_TERMINAL
        COMMENT "node: ${R_SCRIPT} (${_rh})")
    if(PolyOrch_RUST_FOLDER_ROOT)
        set_target_properties("${_rh}-run-${R_SCRIPT}" PROPERTIES
            FOLDER "${PolyOrch_RUST_FOLDER_ROOT}")
    endif()
    # IDE parity: the run node carries the same display files (the debug
    # workflow opens sources right where it launches).
    _polyorch_node_mount_verb_targets("${_rh}" "${_rh}-run-${R_SCRIPT}")
endfunction()

# polyorch_node_debug(TARGET <handle> [NAME <label>] [ARGS <a>...]
#                     [ENVS <K=V>...] [OUTFILES <glob,...>])
#
# Registers a js-debug launch row for the handle's package entry (main ->
# module -> exports["."]; npm entry semantics: relative to the PACKAGE
# ROOT, which is where dist/ lives in the dist/ convention -- the join
# NEVER re-adds dist/). TS debugging rides source maps: the launch points
# at the built entry and VSCode maps breakpoints back through outFiles.
# Pure configure-time registration -- no process, no PM call.
#
# GATE-FIRST (D33 ruling): with PolyOrch_NODE_VSCODE_DEBUG OFF the verb
# returns before ANY validation -- zero footprint in the strongest sense
# (no spec, no FATAL, not even for a ghost handle). The registration is a
# debug-surface side effect, not a build verb; the loud contracts below
# hold inside the gate-ON domain.
function(polyorch_node_debug)
    if(NOT PolyOrch_NODE_VSCODE_DEBUG)
        return()
    endif()
    set(_one TARGET NAME OUTFILES)
    set(_multi ARGS ENVS)
    cmake_parse_arguments(PARSE_ARGV 0 D "" "${_one}" "${_multi}")
    if(NOT D_TARGET)
        message(FATAL_ERROR "polyorch_node_debug: TARGET is required")
    endif()
    _polyorch_node_apply_prefix(_dh "${D_TARGET}")
    get_property(_dir GLOBAL PROPERTY "POLYORCH_NODE_DIR_${_dh}")
    get_property(_mf GLOBAL PROPERTY "POLYORCH_NODE_MANIFEST_${_dh}")
    if(NOT _dir OR NOT _mf)
        message(FATAL_ERROR
            "polyorch_node_debug: unknown handle '${D_TARGET}'")
    endif()
    if(NOT PolyOrchNode_EXECUTABLE)
        message(FATAL_ERROR
            "polyorch_node_debug: no node runtime -- run polyorch_node_setup first")
    endif()
    _polyorch_node_read_entry(_entry "${_mf}")
    if(_entry STREQUAL "")
        message(FATAL_ERROR
            "polyorch_node_debug: '${D_TARGET}' declares no entry (main/module/exports)")
    endif()
    string(REGEX REPLACE "^\\./" "" _entry "${_entry}")
    if(IS_ABSOLUTE "${_entry}")
        set(_prog "${_entry}")
    else()
        set(_prog "${_dir}/${_entry}")
    endif()
    if(D_NAME)
        _polyorch_node_sanitize_name(_lbl "${D_NAME}")
    else()
        set(_lbl "${_dh}")
    endif()
    foreach(_f "${_lbl}" "${_prog}" "${_dir}" ${D_OUTFILES})
        if(_f MATCHES "\\|")
            message(FATAL_ERROR
                "polyorch_node_debug: field '${_f}' contains the reserved '|'")
        endif()
    endforeach()
    foreach(_a ${D_ARGS})
        if(_a MATCHES "\\|")
            message(FATAL_ERROR
                "polyorch_node_debug: ARGS entry '${_a}' contains reserved '|'")
        endif()
    endforeach()
    foreach(_kv ${D_ENVS})
        if(NOT _kv MATCHES "^[A-Za-z_][A-Za-z0-9_]*=")
            message(FATAL_ERROR
                "polyorch_node_debug: ENVS entry '${_kv}' is not NAME=VALUE")
        endif()
        if(_kv MATCHES "\\|")
            message(FATAL_ERROR
                "polyorch_node_debug: ENVS entry '${_kv}' contains reserved '|'")
        endif()
    endforeach()
    string(REPLACE ";" "," _argsj "${D_ARGS}")
    string(REPLACE ";" "," _envsj "${D_ENVS}")
    set(_outj "${D_OUTFILES}")
    if(_outj STREQUAL "")
        # js-debug's outFiles names GENERATED JavaScript (not the .map);
        # the map path is derived from the matched .js via the sibling
        # .map / sourceMappingURL comment. `.map` here would match only
        # the map file, kill breakpoint PREDICTION (pre-load binding), and
        # a program that computes at import time would finish before the
        # runtime-only map path engages. Default = generated js + excl.
        set(_outj "${_dir}/**/*.js,!${_dir}/node_modules/**")
    endif()
    # RUNTIME joins the spec NOW (not at generate time): the row carries
    # the discovered tool of THIS configure -- three-tier doctrine, the
    # whole point of the discovery is that node may live only in a pixi
    # env and the VSCode GUI PATH will not know it.
    # FIELD 8 = the build mediator the preLaunchTask rebuilds (build()/import()
    # both create `${_handle}-build`). Its presence unlocks preLaunchTask + the
    # tasks.json row; sourceMaps rides every node row unconditionally. A legacy
    # 7-field row still renders (sourceMaps, no preLaunchTask, no task row).
    set_property(GLOBAL APPEND PROPERTY POLYORCH_NODE_DEBUG_SPECS
        "${_lbl}|${PolyOrchNode_EXECUTABLE}|${_prog}|${_dir}|${_argsj}|${_envsj}|${_outj}|${_dh}-build")
endfunction()

# _polyorch_node_vscode_rows(SPECS LAUNCH_OUT TASKS_OUT)
# Pure spec-table -> JSONC region text (the python/rust rows siblings; the
# third out-var carries the matching tasks rows so the shared generator can
# merge rust-then-node rows under ONE frozen-marker tasks region).
# Spec row shape: NAME|RUNTIME|PROGRAM|CWD|ARGS|ENVS|OUTFILES[|BUILD_TARGET]
# -- the seven base fields are mandatory (empty fields still serialize the
# pipes); ARGS/ENVS/OUTFILES are comma-joined. BUILD_TARGET is optional:
# present and non-empty it unlocks preLaunchTask + a task row (sourceMaps
# rides EVERY node row unconditionally, outside this guard; the length guard
# keeps legacy 7-field rows rendering). js-debug is VSCode built-in -- no
# extension install (unlike CodeLLDB/debugpy). Embedded double-quotes
# unescaped: the family's known-deviation 2 (python rows header, same class).
function(_polyorch_node_vscode_rows SPECS LAUNCH_OUT TASKS_OUT)
    set(_L "")
    set(_K "")
    foreach(_row ${SPECS})
        string(REPLACE "|" ";" _f "${_row}")
        list(GET _f 0 _nm)
        list(GET _f 1 _rt)
        list(GET _f 2 _prog)
        list(GET _f 3 _cwd)
        list(GET _f 4 _args)
        list(GET _f 5 _envs)
        list(GET _f 6 _out)
        list(LENGTH _f _nfl)
        set(_bt "")
        if(_nfl GREATER 7)
            list(GET _f 7 _bt)
        endif()
        string(APPEND _L
"        {\n"
"            \"name\": \"PolyOrch: ${_nm}\",\n"
"            \"type\": \"node\",\n"
"            \"request\": \"launch\",\n"
"            \"runtimeExecutable\": \"${_rt}\",\n"
"            \"program\": \"${_prog}\",\n"
"            \"cwd\": \"${_cwd}\",\n"
"            \"console\": \"integratedTerminal\",\n"
"            \"skipFiles\": [\"<node_internals>/**\"]")
        string(APPEND _L ",\n            \"sourceMaps\": true")
        if(NOT _bt STREQUAL "")
            string(APPEND _L ",\n            \"preLaunchTask\": \"PolyOrch: ${_nm}\"")
            string(APPEND _K
"        {\n"
"            \"label\": \"PolyOrch: ${_nm}\",\n"
"            \"type\": \"shell\",\n"
"            \"command\": \"cmake\",\n"
"            \"args\": [\"--build\", \"${CMAKE_BINARY_DIR}\", \"--target\", \"${_bt}\"],\n"
"            \"problemMatcher\": []\n"
"        },\n")
        endif()
        if(NOT _out STREQUAL "")
            string(REPLACE "," ";" _ol "${_out}")
            set(_oj "")
            foreach(_o ${_ol})
                string(APPEND _oj "\"${_o}\", ")
            endforeach()
            string(APPEND _L ",\n            \"outFiles\": [${_oj}]")
        endif()
        if(NOT _args STREQUAL "")
            string(REPLACE "," ";" _al "${_args}")
            set(_aj "")
            foreach(_a ${_al})
                string(APPEND _aj "\"${_a}\", ")
            endforeach()
            string(APPEND _L ",\n            \"args\": [${_aj}]")
        endif()
        if(NOT _envs STREQUAL "")
            string(REPLACE "," ";" _el "${_envs}")
            set(_eo "")
            foreach(_kv ${_el})
                string(FIND "${_kv}" "=" _eq)
                string(SUBSTRING "${_kv}" 0 "${_eq}" _k)
                math(EXPR _v1 "${_eq} + 1")
                string(SUBSTRING "${_kv}" "${_v1}" -1 _v)
                string(APPEND _eo "\"${_k}\": \"${_v}\", ")
            endforeach()
            string(APPEND _L ",\n            \"env\": {${_eo}}")
        endif()
        string(APPEND _L "\n        },\n")
    endforeach()
    set(${LAUNCH_OUT} "${_L}" PARENT_SCOPE)
    set(${TASKS_OUT} "${_K}" PARENT_SCOPE)
endfunction()

# ===========================================================================
# Per-round include hook: register the SHARED end-of-configure generator
# ONCE per tree while this face's gate is ON (collapses with the rust and
# python faces' identical hooks via the shared POLYORCH_VSCODE_HOOKED flag
# -- single writer, one region, all rows merged; see
# PolyOrchVSCodeDebugHelpers). DEFER is configure-mode-only: script-mode
# cases (t-node-vscode) include this face with the gate OFF, so the branch
# never reaches cmake_language(DEFER) there (illegal under -P, measured).
# ===========================================================================
include("${CMAKE_CURRENT_LIST_DIR}/PolyOrchVSCodeDebugHelpers.cmake")
get_property(_polyorch_ndv_hooked GLOBAL PROPERTY POLYORCH_VSCODE_HOOKED)
if(PolyOrch_NODE_VSCODE_DEBUG AND NOT _polyorch_ndv_hooked)
    set_property(GLOBAL PROPERTY POLYORCH_VSCODE_HOOKED TRUE)
    # DEFER TO THE TOP-LEVEL DIRECTORY'S END, not the including
    # directory's: faces opted in by LATER sibling subdirs must have
    # registered their specs before the single writer runs (measured
    # defect 2026-10-08: python-first subdirectory fired the generator
    # with "node 0" and the later node rows were orphaned forever).
    cmake_language(DEFER DIRECTORY "${CMAKE_SOURCE_DIR}"
        CALL _polyorch_vscode_debug_generate)
endif()
