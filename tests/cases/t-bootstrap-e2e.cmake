# e2e: required
include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")

# Full cold path against the bundled example manifest, run from a scratch copy
# so pixi.lock and .pixi/ never land in the repository. Offline once pixi
# exists (the demo manifest has zero dependencies); without pixi it will reach
# the network for the installer, so keep the precheck enabled there.
polyorch_pixi_find(QUIET)
if(NOT PolyOrch_PIXI_EXECUTABLE)
    message(STATUS "bootstrap-e2e: SKIP (no pixi; installer path not exercised)")
    return()
endif()

_polyorch_pixi_scratch(_s)
configure_file("${CMAKE_CURRENT_LIST_DIR}/../../examples/pixi-bootstrap/pixi.toml"
    "${_s}/pixi.toml" COPYONLY)

polyorch_pixi_bootstrap(MANIFEST "${_s}/pixi.toml" TASK greet
    NO_PRECHECK COPY_SCRIPTS QUIET)
ck(PolyOrch_PIXI_VERSION MATCHES ^[0-9]+[.][0-9]+[.][0-9]+$)
ck_file("${_s}/pixi.sh")
ck_file("${_s}/pixi.ps1")

message(STATUS "bootstrap-e2e: OK")
