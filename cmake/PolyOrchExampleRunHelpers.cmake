# PolyOrchExampleRunHelpers.cmake -- the native-example run surface.
#
# polyorch_example_run(TARGET <existing-executable-target>
#                      [ARGS "a;b"] [GUI] [FOLDER <ide>])
#
# Emits `<TARGET>-run`: one button that executes an ALREADY-REGISTERED
# native (non-cargo) executable target -- the counterpart of
# polyorch_rust_run on the rust face, for the plain add_executable lanes.
# The GUI flavor wraps the exec in the display-probe chain (see below);
# the non-GUI flavor is a bare exec.
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
    set(_s [==[
if [ -z "$${DISPLAY:-}" ] && [ -z "$${WAYLAND_DISPLAY:-}" ] &&
   [ -z "$${WAYLAND_SOCKET:-}" ] && compgen -G '/tmp/.X11-unix/X*' >/dev/null; then
    DISPLAY=:0; export DISPLAY
    echo 'polyorch run surface: no display variables, falling back to DISPLAY=:0 (local X socket probe)' >&2
fi
exec "$$0" "$$@"
==]==])
    string(REGEX REPLACE "\$\$" "\$" _s "${_s}")
    set(${OUT} "${_s}" PARENT_SCOPE)
endfunction()

function(polyorch_example_run)
    set(_one TARGET FOLDER)
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

    if(ER_GUI)
        _polyorch_gui_probe_script(_probe_script)
        set(_cmd
            ${CMAKE_COMMAND} -E env sh -c "${_probe_script}"
            $<TARGET_FILE:${ER_TARGET}> ${ER_ARGS})
        add_custom_target("${ER_TARGET}-run"
            COMMAND ${_cmd}
            USES_TERMINAL
            VERBATIM
            COMMENT "run ${ER_TARGET} (GUI display-probe chain)")
    else()
        add_custom_target("${ER_TARGET}-run"
            COMMAND $<TARGET_FILE:${ER_TARGET}> ${ER_ARGS}
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
