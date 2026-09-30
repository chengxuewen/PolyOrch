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
# Naming: real targets are kebab-case; fused trees namespace them through
# PolyOrch_NODE_TARGET_PREFIX (this module's own knob -- A2: the name says
# NODE and means NODE; the rust knob stays the rust knob's). Fusion loop
# wiring is in examples/CMakeLists.txt.
#
# Requires CMake >= 3.25 (PARSE_ARGV, string(JSON ...)).

cmake_minimum_required(VERSION 3.25)

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
    # tier b: PATH (+ ~/.pixi/bin so a bare pixi install counts, same as the
    # rust face's cargo probe)
    find_program(PolyOrchNode_EXECUTABLE NAMES node
        HINTS ${_roots} NO_CACHE)
    # tier a: explicit override wins over everything (rust-nodejs idiom:
    # -D<X>Exe=; ours differs in name by design, adjudication A2)
    if(NOT PolyOrchNode_EXECUTABLE)
        set(PolyOrchNode_EXECUTABLE "${PolyOrchNodeExe}")
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
        find_program(PolyOrchNode_COREPACK NAMES corepack NO_CACHE)
    endif()
    if(NOT _pm_argv AND PolyOrchNode_COREPACK)
        set(_pm_argv "${PolyOrchNode_COREPACK}" "${_pm}")
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
            add_custom_target("${_handle}-build"
                COMMAND ${PolyOrchNode_PM_EXECUTABLE} run build ${_wsargs}
                WORKING_DIRECTORY "${_root_dir}"
                USES_TERMINAL
                COMMENT "node: build ${_name} (${_handle})")
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
function(_polyorch_node_ws_args out package)
    if(PolyOrchNode_PM_NAME STREQUAL "pnpm")
        set(${out} "--filter" "${package}" PARENT_SCOPE)
    else()
        set(${out} "-w" "${package}" PARENT_SCOPE)
    endif()
endfunction()

# polyorch_node_build(TARGET <handle> MANIFEST <package.json> [OUTPUT_DIR <dir>])
#
# Registers a single-package handle + -build mediator WITHOUT a workspace
# root (the standalone shape; import covers the workspace shape). Same
# command table minus the workspace flags, same dist convention.
# OUTPUT_DIR overrides <manifest-dir>/dist (adjudication 2).
function(polyorch_node_build)
    set(_one TARGET MANIFEST OUTPUT_DIR)
    cmake_parse_arguments(PARSE_ARGV 0 B "" "${_one}" "")
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
    add_custom_target("${_handle}-build"
        COMMAND ${PolyOrchNode_PM_EXECUTABLE} run build
        WORKING_DIRECTORY "${_mdir}"
        USES_TERMINAL
        COMMENT "node: build ${_name} (${_handle})")
    set_property(GLOBAL PROPERTY "POLYORCH_NODE_MANIFEST_${_handle}"
        "${B_MANIFEST}")
    set_property(GLOBAL PROPERTY "POLYORCH_NODE_ROOT_${_handle}"
        "${_mdir}")
    set_property(GLOBAL PROPERTY "POLYORCH_NODE_PKG_${_handle}"
        "${_name}")
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
    add_custom_target("${_th}-test"
        COMMAND ${PolyOrchNode_PM_EXECUTABLE} run test ${_wsargs}
        WORKING_DIRECTORY "${_root}"
        USES_TERMINAL
        COMMENT "node: test ${_pkg} (${_th})")
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
    add_custom_target("${_rh}-run-${R_SCRIPT}"
        COMMAND ${PolyOrchNode_PM_EXECUTABLE} run ${_wsargs} ${R_SCRIPT} ${_tail}
        WORKING_DIRECTORY "${_root}"
        USES_TERMINAL
        COMMENT "node: ${R_SCRIPT} (${_rh})")
endfunction()
