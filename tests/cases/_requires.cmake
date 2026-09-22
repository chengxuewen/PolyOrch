# tests/cases/_requires.cmake -- capability probes behind the `# requires:` marker.
#
# Marker contract (single shape, mirrored in tests/run.sh + tests/CMakeLists.txt
# headers and _inc.cmake -- change it in all four places or nowhere):
#   * A case declares a required capability with a comment line
#         # requires: <cap>
#     placed AFTER any expect/e2e marker lines and within the FIRST THREE LINES
#     of the file. The drivers never pre-gate on it -- they read the declaration
#     only to exempt the case from the SKIP veto below. The probe itself runs
#     IN THE CASE, so the ctest leg gets identical behavior for free.
#   * When the capability is missing the case MUST print the contract skip
#     line, exactly, and return 0:
#         <case-file-stem> : SKIP (<reason>)
#     i.e. the case id (file name without .cmake), SPACE COLON SPACE, "SKIP",
#     SPACE, "(" reason ")". run.sh counts it as a skip, ctest reports
#     "Skipped" (SKIP_REGULAR_EXPRESSION).
#   * Veto: a want-pass case WITHOUT the marker whose output contains
#     ": SKIP (" FAILS in both drivers -- a silent skip is never a pass.
#     Driver-level skip wording ("SKIP <path> (...)", emitted by run.sh and
#     ctest themselves) lacks the " : " and can never collide; t-driver-selflock
#     pins that non-collision.
#   * POLYORCH_TEST_E2E stays orthogonal: e2e gating happens in the drivers,
#     requires gating in the case; both must let a case run for it to run.
#   * Unknown capability name => FATAL_ERROR (typo-proof).
#
# Parent/child PATH split (load-bearing since WP2 flipped the fixture cases
# to system-rust): the PARENT case process gates on these probes, while
# fixture CHILDREN see the driver-composed PATH (tests/fixtures/_driver.cmake
# prepends ~/.cargo/bin + ~/.pixi/bin to the child environment only). The
# tool (non-login) shell has neither dir on PATH, so a PATH-only parent probe
# would SKIP cases whose children can actually build -- probing the driver's
# extra dirs too keeps the parent gate aligned with what the children see.
# `system-rust` therefore = cargo on PATH OR in ~/.cargo/bin (same convention
# as the `pixi` probe's PATHS ~/.pixi/bin). `no-system-rust` deliberately
# stays PATH-EXACT: it gates the toolchain-MISSING route (t-rust-setup-missing
# runs setup() in the PARENT, where the bare tool PATH is the honest
# environment), so the two probes measure different things on a rustup host
# and can be TRUE together. `rustup`/`nightly` remain PATH-only fallbacks.
#
# Usage in a case:
#   include("${CMAKE_CURRENT_LIST_DIR}/_requires.cmake")
#   polyorch_requires(pixi-rust _ok)
#   if(NOT _ok)
#       message(STATUS "t-example : SKIP (no pixi env with a materialized cargo)")
#       return()
#   endif()

# Root capture at INCLUDE time (CMAKE_CURRENT_LIST_DIR here = tests/cases; a
# function body must not rely on it pointing at this file).
get_filename_component(_polyorch_req_root "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

function(polyorch_requires cap out)
    set(_ok FALSE)

    if(cap STREQUAL "system-rust")
        # PATH first, then the driver-composed dirs (see PATH note above).
        find_program(_pr_cargo NAMES cargo)
        if(NOT _pr_cargo)
            find_program(_pr_cargo NAMES cargo PATHS "$ENV{HOME}/.cargo/bin")
        endif()
        if(_pr_cargo)
            set(_ok TRUE)
        endif()

    elseif(cap STREQUAL "no-system-rust")
        # Inverse probe for cases that assert the toolchain-MISSING route
        # (t-rust-setup-missing): they may only run where PATH has no cargo.
        find_program(_pr_cargo NAMES cargo)
        if(NOT _pr_cargo)
            set(_ok TRUE)
        endif()

    elseif(cap STREQUAL "pixi")
        find_program(_pr_pixi NAMES pixi PATHS
            "$ENV{HOME}/.pixi/bin" "$ENV{PIXI_HOME}/bin")
        if(_pr_pixi)
            set(_ok TRUE)
        endif()

    elseif(cap STREQUAL "pixi-rust")
        # pixi present AND some pixi env store holds a materialized cargo.
        # Filesystem probe only -- never triggers a solve or the network.
        find_program(_pr_pixi NAMES pixi PATHS
            "$ENV{HOME}/.pixi/bin" "$ENV{PIXI_HOME}/bin")
        if(_pr_pixi)
            set(_pr_stores
                "$ENV{HOME}/.pixi/envs"
                "$ENV{PIXI_HOME}/envs"
                "${_polyorch_req_root}/.pixi/envs"
                "${_polyorch_req_root}/examples/*/.pixi/envs")
            set(_pr_hit "")
            foreach(_store IN LISTS _pr_stores)
                file(GLOB _cargo "${_store}/*/bin/cargo")
                if(_cargo)
                    set(_pr_hit "${_cargo}")
                    break()
                endif()
            endforeach()
            if(_pr_hit)
                set(_ok TRUE)
            endif()
        endif()

    elseif(cap STREQUAL "rustup")
        find_program(_pr_rustup NAMES rustup)
        if(_pr_rustup)
            set(_ok TRUE)
        endif()

    elseif(cap STREQUAL "generator-mc")
        # Ninja Multi-Config leg availability: MC fixture children are configured
        # with -G "Ninja Multi-Config", which needs the ninja binary on PATH
        # (the same gate tests/matrix.sh applies to its Ninja cells). Added for
        # WP4 -- the t-rust-output-dir MC legs are its only consumer.
        find_program(_pr_ninja NAMES ninja)
        if(_pr_ninja)
            set(_ok TRUE)
        endif()

    elseif(cap STREQUAL "nightly")
        find_program(_pr_rustc NAMES rustc)
        if(_pr_rustc)
            execute_process(COMMAND "${_pr_rustc}" --version
                OUTPUT_VARIABLE _pr_ver ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE)
            if(_pr_ver MATCHES nightly)
                set(_ok TRUE)
            endif()
        endif()

    elseif(cap STREQUAL "cxxbridge-cmd")
        # PATH first, then ~/.cargo/bin: a cargo-installed helper lands
        # in the rustup bin dir the parent tool shell does NOT carry on
        # PATH (same parent/child alignment argument as `system-rust`
        # above; the bootstrap's own discovery searches this dir too, so
        # the gate and the product route agree).
        find_program(_pr_cxxb NAMES cxxbridge)
        if(NOT _pr_cxxb)
            find_program(_pr_cxxb NAMES cxxbridge PATHS "$ENV{HOME}/.cargo/bin")
        endif()
        if(_pr_cxxb)
            set(_ok TRUE)
        endif()

    elseif(cap STREQUAL "cbindgen")
        # Same shape as cxxbridge-cmd (WP7 addition: the second
        # cargo-installable helper of the port, binary cbindgen).
        find_program(_pr_cb NAMES cbindgen)
        if(NOT _pr_cb)
            find_program(_pr_cb NAMES cbindgen PATHS "$ENV{HOME}/.cargo/bin")
        endif()
        if(_pr_cb)
            set(_ok TRUE)
        endif()

    elseif(cap STREQUAL "network" OR cap STREQUAL "crates-io")
        # ONE cheap HTTPS GET against the crates.io static host (robots-style
        # root; any HTTP answer -- even 403 -- proves reachability when the
        # transport itself does not error). Requires TMPDIR, which both
        # drivers export.
        if("$ENV{TMPDIR}" STREQUAL "")
            message(FATAL_ERROR
                "polyorch_requires(${cap}): TMPDIR is not set -- run cases through tests/run.sh or ctest, never bare cmake -P, when a network probe is involved")
        endif()
        set(_pr_dst "$ENV{TMPDIR}/.polyorch-net-probe")
        file(REMOVE "${_pr_dst}")
        file(DOWNLOAD "https://static.crates.io/" "${_pr_dst}"
            STATUS _pr_st TIMEOUT 10)
        file(REMOVE "${_pr_dst}")
        list(GET _pr_st 0 _pr_err)
        if(_pr_err EQUAL 0)
            set(_ok TRUE)
        endif()

    elseif(cap MATCHES "^target-(.+)$")
        # PATH first, then the driver-composed dir (same alignment argument
        # as `system-rust` above: the fixture CHILDREN build with the
        # toolchain the driver puts on their PATH -- ~/.cargo/bin carries a
        # rustup beside it -- so the parent gate must see it too, or a
        # target-gated e2e could never execute through run.sh).
        set(_pr_want "${CMAKE_MATCH_1}")
        find_program(_pr_rustup NAMES rustup)
        if(NOT _pr_rustup)
            find_program(_pr_rustup NAMES rustup PATHS "$ENV{HOME}/.cargo/bin")
        endif()
        if(_pr_rustup)
            execute_process(COMMAND "${_pr_rustup}" target list --installed
                OUTPUT_VARIABLE _pr_tl ERROR_QUIET)
            string(STRIP "${_pr_tl}" _pr_tl)
            string(REPLACE "\n" ";" _pr_tl "${_pr_tl}")
            foreach(_t IN LISTS _pr_tl)
                string(STRIP "${_t}" _t)
                if(_t STREQUAL _pr_want)
                    set(_ok TRUE)
                    break()
                endif()
            endforeach()
        endif()

    elseif(cap STREQUAL "posix-shell")
        # Inverse platform guard for cases whose fixtures are POSIX shell
        # stubs (t-rust-rustc-version).
        if(UNIX)
            set(_ok TRUE)
        endif()

    else()
        message(FATAL_ERROR
            "polyorch_requires: unknown capability '${cap}' (see the probe table in tests/cases/_requires.cmake)")
    endif()

    set(${out} ${_ok} PARENT_SCOPE)
endfunction()
