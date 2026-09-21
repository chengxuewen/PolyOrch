include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")

# polyorch_pixi_scripts_install: the universal activation trio lands next to
# the manifest (the scripts resolve pixi.toml from their own directory), is
# idempotent, and honors WORKDIR or the manifest-context default. Fully
# offline, no pixi needed.
_polyorch_pixi_scratch(_ws)
file(WRITE "${_ws}/pixi.toml" "# stub manifest for scripts install\n")

polyorch_pixi_scripts_install(WORKDIR "${_ws}")
foreach(_f pixi.sh pixi.bat pixi.ps1)
    ck_file("${_ws}/${_f}")
endforeach()

if(UNIX)
    # Executability proof by launch: with the exec bit missing, CMake itself
    # refuses and reports "Permission denied"; whatever the script then
    # exits with (stub manifest, pixi guards) is irrelevant -- we only assert
    # that it STARTED. (Note: `cmake -E test` no longer exists in CMake 4.)
    execute_process(COMMAND "${_ws}/pixi.sh" RESULT_VARIABLE _rc
        OUTPUT_QUIET ERROR_VARIABLE _err)
    string(FIND "${_err}" "Permission denied" _pd)
    ck(${_pd} EQUAL -1)
endif()

# Idempotent re-install.
polyorch_pixi_scripts_install(WORKDIR "${_ws}")
ck_file("${_ws}/pixi.ps1")

# The copied pixi.sh must be byte-identical to the shipped one (managed file).
execute_process(COMMAND "${CMAKE_COMMAND}" -E compare_files
    "${_ws}/pixi.sh" "${CMAKE_CURRENT_LIST_DIR}/../../scripts/pixi.sh"
    RESULT_VARIABLE _rc)
ck(${_rc} EQUAL 0)

# Default WORKDIR = directory of the resolved manifest.
_polyorch_pixi_scratch(_ws2)
file(WRITE "${_ws2}/pixi.toml" "# stub\n")
set(PolyOrch_PIXI_MANIFEST "${_ws2}/pixi.toml" CACHE FILEPATH "" FORCE)
polyorch_pixi_scripts_install()
ck_file("${_ws2}/pixi.sh")

# Missing WORKDIR with no manifest context must hard-fail (child: FATAL here
# would abort the file on the success path too).
execute_process(COMMAND "${CMAKE_COMMAND}"
    -DPolyOrch_PIXI_MANIFEST=
    -P "${CMAKE_CURRENT_LIST_DIR}/_scripts_nodefault.cmake"
    RESULT_VARIABLE _rc)
ck_fail_rc(_rc)

message(STATUS "scripts-install: OK")
