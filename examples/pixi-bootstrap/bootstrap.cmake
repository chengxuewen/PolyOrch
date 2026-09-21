# PolyOrch example: cold-start a pixi environment with CMake only.
#
#   cmake -P examples/pixi-bootstrap/bootstrap.cmake [-DPIXI_PIN=0.78.0]
#
# This is the bootstrap-shell-script replacement: locate pixi (install it via
# the official installer when absent or older than the pin), solve and install
# the environment with one lock-drift recovery, smoke-run a task, then
# install the activation trio (pixi.sh / pixi.bat / pixi.ps1) beside the
# manifest -- the next human step is: source ./pixi.sh
# Prerequisite: a host cmake >= 3.22 (chicken-and-egg: pixi normally supplies
# cmake, so this entry cannot itself be a configure step).
get_filename_component(_self "${CMAKE_CURRENT_LIST_DIR}" ABSOLUTE)
include("${_self}/../../cmake/PolyOrchPixiHelpers.cmake")

set(_args MANIFEST "${_self}/pixi.toml" TASK greet COPY_SCRIPTS)
if(PIXI_PIN)   # only pass VERSION when set: an empty oneValue arg warns (CMP0174)
    list(APPEND _args VERSION "${PIXI_PIN}")
endif()

polyorch_pixi_bootstrap(${_args})
