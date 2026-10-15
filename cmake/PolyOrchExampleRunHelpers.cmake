# PolyOrchExampleRunHelpers.cmake -- the native-example run surface.
#
# polyorch_example_run(TARGET <existing-executable-target>
#                      [ARGS "a;b"] [GUI] [FOLDER <ide>]
#                      [WORKING_DIRECTORY <dir>])
#
# Emits `<TARGET>-run`: one button that executes an ALREADY-REGISTERED
# native (non-cargo) executable target -- the counterpart of
# polyorch_rust_run on the rust face, for the plain add_executable lanes.
# The GUI flavor wraps the exec in the display-probe chain (see below);
# the non-GUI flavor is a bare exec.
#
# WORKING_DIRECTORY runs the button in <dir> through the native
# add_custom_target kwarg -- the house idiom of every run face here
# (python :241, node, rust buttons all carry it; the lone -E chdir wrap
# on the rust wasm-serve target exists for its own documented reason:
# that target CREATES the dir as its first command, which WORKING-
# DIRECTORY cannot know). The generator emits "cd <dir> && ..." for
# both Makefiles and Ninja, chdir outermost ahead of the GUI env wrap.
# Unset = the generator's build-directory default, command byte-unchanged.
#
# Deliberate NON-CHOICE: the button carries NO add_dependencies --
# whether running implies building is per-site (the host re-adds its
# own edges at its call sites); do not "helpfully" wire a build edge
# in here.
#
# GUI fallback chain (the VSCode-SSH-remote case is the norm, not the
# exception):
#   1. DISPLAY / WAYLAND_DISPLAY / WAYLAND_SOCKET non-empty -> exec
#      unchanged (local sessions AND VSCode SSH with ForwardX11 yes --
#      sshd injects localhost:10.0 and every child inherits it);
#   2. else a local X socket exists -> DISPLAY=:0 (physical-screen
#      workstations; XWayland sessions expose :0/:1 through that dir);
#   3. else exec unchanged and let winit/SDL report the connection
#      error (the toolkits' own message names the missing display -- a
#      supplier-side FATAL here would be build-time noise, since the
#      probe must ride exec time, never configure time).
#   The probe rides the COMMAND at exec time; the binary forwards via
#   ARGV (sh -c '... exec "$0" "$@"' <file> <args...>), never string
#   interpolation into the script body.
# The probe must reach sh -c as ONE argument: the list re-expansion
# shape set(_cmd ... "${probe}") + COMMAND ${_cmd} splits it at every
# ';' -- inline quoting at the call site is load-bearing (bug found
# by the first host consumer via the live E801 test; text-marker
# tests missed it because every fragment keeps its markers).
#
# CI/ctest never pass through the GUI wrapper (headless verification is
# the ctest example_* lane with its own argv).

include_guard(GLOBAL)

# _polyorch_gui_probe_script(OUT) -- the display-probe chain the GUI
# run surfaces share (polyorch_example_run + polyorch_rust_run GUI,
# T-H9). Evaluated when the button RUNS, never at configure time.
# The script body passes as ONE pre-expanded string: CMake must not
# parse the shell's ${DISPLAY:-} forms as its own variable
# references, so every $ the shell needs is written $$ inside the
# bracket template and string(REGEX REPLACE) collapses $$ -> $ before
# the COMMAND list is assembled (cmake -E env hands the body to sh
# verbatim). The binary rides argv $0, its arguments $@.
function(_polyorch_gui_probe_script OUT)
    # ONE single-line script: the Ninja generator flattens newlines in
    # quoted command arguments out of existence (measured: multi-line
    # shipped as "&&[" syntax errors) -- semicolons are the portable
    # separator. The bracket argument expands NOTHING, single $ rides
    # verbatim (the inherited $$+REGEX collapse never matched: see the
    # T-H9 history note below).
    # History: the quoted-era $$ + REGEX collapse was doubly broken --
    # the pattern never matched inner pairs AND the bracket-close was
    # malformed; both shipped into ninja command lines (user-reported,
    # 2026-10-14).
    set(_s [==[if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ] && [ -z "${WAYLAND_SOCKET:-}" ] && ls -d /tmp/.X11-unix/X* >/dev/null 2>&1; then DISPLAY=:0; export DISPLAY; echo 'polyorch run surface: no display variables, falling back to DISPLAY=:0 (local X socket probe)' >&2; fi; exec "$0" "$@"]==])
    set(${OUT} "${_s}" PARENT_SCOPE)
endfunction()

function(polyorch_example_run)
    set(_one TARGET FOLDER WORKING_DIRECTORY)
    set(_opt GUI)
    set(_multi ARGS)
    cmake_parse_arguments(PARSE_ARGV 0 ER "${_opt}" "${_one}" "${_multi}")
    if(ER_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR
            "polyorch_example_run: unknown args: ${ER_UNPARSED_ARGUMENTS}")
    endif()
    if(NOT ER_TARGET)
        message(FATAL_ERROR "polyorch_example_run: TARGET is required")
    endif()
    if(NOT TARGET "${ER_TARGET}")
        message(FATAL_ERROR
            "polyorch_example_run: no such target '${ER_TARGET}' "
            "(register the executable first)")
    endif()

    # guard the kwarg through: unset must leave both add_custom_target
    # calls byte-identical to the pre-WORKING_DIRECTORY shape (leg C).
    set(_wdir "")
    if(ER_WORKING_DIRECTORY)
        set(_wdir WORKING_DIRECTORY "${ER_WORKING_DIRECTORY}")
    endif()

    if(ER_GUI)
        _polyorch_gui_probe_script(_probe_script)
        add_custom_target("${ER_TARGET}-run"
            COMMAND ${CMAKE_COMMAND} -E env sh -c "${_probe_script}"
                    $<TARGET_FILE:${ER_TARGET}> ${ER_ARGS}
            ${_wdir}
            USES_TERMINAL
            VERBATIM
            COMMENT "run ${ER_TARGET} (GUI display-probe chain)")
    else()
        add_custom_target("${ER_TARGET}-run"
            COMMAND $<TARGET_FILE:${ER_TARGET}> ${ER_ARGS}
            ${_wdir}
            USES_TERMINAL
            VERBATIM
            COMMENT "run ${ER_TARGET}")
    endif()

    set(_fold "${ER_FOLDER}")
    if(NOT _fold)
        cmake_path(RELATIVE_PATH CMAKE_CURRENT_LIST_DIR
            BASE_DIRECTORY "${CMAKE_SOURCE_DIR}" OUTPUT_VARIABLE _fold)
    endif()
    set_target_properties("${ER_TARGET}-run" PROPERTIES FOLDER "${_fold}")
endfunction()
