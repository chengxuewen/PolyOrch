include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")

# WP8: offline table lock for _polyorch_rust_install_plan -- the pure row
# planner behind polyorch_rust_install. Row encoding (documented at the
# function): `<file-expr>|<dest>|<perms>|<component>|<configurations>|<stub>`
# where multi-value fields are SPACE-joined (a row may never contain ';' or
# '|'), stub blocks are '%'-joined lines, and every destination already
# carries the folded PREFIX. Full-row equality is the lock: the real
# install() consumes these rows verbatim, so the bytes here are the bytes of
# the generated install rules and replay stub.

# rowf(<row> <idx> <out>): split one row into fields (no field may contain
# the delimiter, verified by the count check).
macro(rowf row idx out)
    string(REPLACE "|" ";" _rf_parts "${${row}}")
    list(LENGTH _rf_parts _rf_n)
    if(NOT _rf_n EQUAL 6)
        message(FATAL_ERROR "rowf (line ${CMAKE_CURRENT_LIST_LINE}): row has ${_rf_n} fields, want 6: [${${row}}]")
    endif()
    list(GET _rf_parts ${idx} ${out})
endmacro()

set(_PE "OWNER_READ OWNER_WRITE GROUP_READ WORLD_READ OWNER_EXECUTE GROUP_EXECUTE WORLD_EXECUTE")
set(_PF "OWNER_READ OWNER_WRITE GROUP_READ WORLD_READ")

# ------------------------------------------------------------- A: bin base --
_polyorch_rust_install_plan(TRIPLE x86_64-unknown-linux-gnu KIND bin HANDLE app OUT_ROWS _rows)
list(LENGTH _rows _n)
ck(${_n} EQUAL 1)
list(GET _rows 0 _r)
ck_str("${_r}" "$<TARGET_FILE:app>|bin|${_PE}|||add_executable(app IMPORTED GLOBAL)%set_target_properties(app PROPERTIES IMPORTED_LOCATION     \"\${_POLYORCH_RUST_ROOT}/bin/$<TARGET_FILE_NAME:app>\")")

# ---------------------------------------------------------- B: static base --
_polyorch_rust_install_plan(TRIPLE x86_64-unknown-linux-gnu KIND static HANDLE dash_ed OUT_ROWS _rows)
list(LENGTH _rows _n)
ck(${_n} EQUAL 1)
list(GET _rows 0 _r)
ck_str("${_r}" "$<TARGET_FILE:dash_ed>|lib|${_PF}|||add_library(dash_ed STATIC IMPORTED GLOBAL)%set_target_properties(dash_ed PROPERTIES IMPORTED_LOCATION     \"\${_POLYORCH_RUST_ROOT}/lib/$<TARGET_FILE_NAME:dash_ed>\")")

# -------------------------------------------------------- C: shared (elf) --
# An ELF .so is a LIBRARY artifact: default lib/, exec bits (current shape).
_polyorch_rust_install_plan(TRIPLE x86_64-unknown-linux-gnu KIND shared HANDLE dash_ed OUT_ROWS _rows)
list(LENGTH _rows _n)
ck(${_n} EQUAL 1)
list(GET _rows 0 _r)
ck_str("${_r}" "$<TARGET_FILE:dash_ed>|lib|${_PE}|||add_library(dash_ed SHARED IMPORTED GLOBAL)%set_target_properties(dash_ed PROPERTIES IMPORTED_LOCATION     \"\${_POLYORCH_RUST_ROOT}/lib/$<TARGET_FILE_NAME:dash_ed>\")")

# ----------------------------------------------- D: shared gnu + implib --
# windows-gnu: the dll is the RUNTIME artifact (bin), the import library rides
# ARCHIVE (lib) with plain file perms and contributes the IMPORTED_IMPLIB stub
# line built from the basename of the configure-time literal path.
_polyorch_rust_install_plan(TRIPLE x86_64-w64-windows-gnu KIND shared HANDLE dash_ed
    IMPLIB_FILE /build/debug/deps/libdash_ed.dll.a OUT_ROWS _rows)
list(LENGTH _rows _n)
ck(${_n} EQUAL 2)
list(GET _rows 0 _r)
ck_str("${_r}" "$<TARGET_FILE:dash_ed>|bin|${_PE}|||add_library(dash_ed SHARED IMPORTED GLOBAL)%set_target_properties(dash_ed PROPERTIES IMPORTED_LOCATION     \"\${_POLYORCH_RUST_ROOT}/bin/$<TARGET_FILE_NAME:dash_ed>\")")
list(GET _rows 1 _r2)
ck_str("${_r2}" "/build/debug/deps/libdash_ed.dll.a|lib|${_PF}|||set_target_properties(dash_ed PROPERTIES IMPORTED_IMPLIB     \"\${_POLYORCH_RUST_ROOT}/lib/libdash_ed.dll.a\")")

# ------------------------------------------------------ E: destination + prefix --
# RUNTIME_DESTINATION overrides the bin default and the stub path follows;
# PREFIX folds in front of the resolved destination (never in front of the
# override's internals).
_polyorch_rust_install_plan(TRIPLE x86_64-unknown-linux-gnu KIND bin HANDLE app
    PREFIX app/ RUNTIME_DESTINATION mybin OUT_ROWS _rows)
list(GET _rows 0 _r)
rowf(_r 1 _dest)
ck_str("${_dest}" "app/mybin")
string(FIND "${_r}" "/app/mybin/" _at)
ck(NOT _at EQUAL -1)

# Non-win families ignore RUNTIME for shared (stays LIBRARY_DESTINATION):
_polyorch_rust_install_plan(TRIPLE x86_64-unknown-linux-gnu KIND shared HANDLE libx
    RUNTIME_DESTINATION mybin LIBRARY_DESTINATION mylib OUT_ROWS _rows)
list(GET _rows 0 _r)
rowf(_r 1 _dest)
ck_str("${_dest}" "mylib")

# ARCHIVE_DESTINATION moves the static artifact (and the implib row above D
# would follow the same key -- checked jointly in H).
_polyorch_rust_install_plan(TRIPLE x86_64-unknown-linux-gnu KIND static HANDLE libx
    ARCHIVE_DESTINATION arch OUT_ROWS _rows)
list(GET _rows 0 _r)
rowf(_r 1 _dest)
ck_str("${_dest}" "arch")

# ------------------------------------------------------- F: permissions --
# A flat PERMISSIONS override replaces BOTH defaults on EVERY row of the call
# (deviation vs the reference's per-type permission blocks -- ledgered).
_polyorch_rust_install_plan(TRIPLE x86_64-w64-windows-gnu KIND shared HANDLE libx
    PERMISSIONS OWNER_READ OWNER_WRITE IMPLIB_FILE /b/liblibx.dll.a OUT_ROWS _rows)
list(LENGTH _rows _n)
ck(${_n} EQUAL 2)
foreach(_r IN LISTS _rows)
    rowf(_r 2 _perms)
    ck_str("${_perms}" "OWNER_READ OWNER_WRITE")
endforeach()

# Caller-supplied custom defaults (the real function keeps its byte-identical
# fallbacks; the planner itself owns no literal permission set):
_polyorch_rust_install_plan(TRIPLE x86_64-unknown-linux-gnu KIND bin HANDLE app
    EXEC_PERMS E1 E2 FILE_PERMS F1 OUT_ROWS _rows)
list(GET _rows 0 _r)
rowf(_r 2 _perms)
ck_str("${_perms}" "E1 E2")

# ------------------------------------------------- G: component + configs --
# Both are per-call pass-through fields stamped on every row (the reference
# has NO component mechanism at the pin; these are PolyOrch extensions).
_polyorch_rust_install_plan(TRIPLE x86_64-unknown-linux-gnu KIND bin HANDLE app
    COMPONENT demoLib CONFIGURATIONS Release RelWithDebInfo OUT_ROWS _rows)
list(GET _rows 0 _r)
rowf(_r 3 _comp)
rowf(_r 4 _cfgs)
ck_str("${_comp}" "demoLib")
ck_str("${_cfgs}" "Release RelWithDebInfo")

# ---------------------------------------------------------- H: headers --
# HEADERS produce one file-perms row each (empty stub) into DEST_INCLUDE
# (default include/), and stamp an INTERFACE_INCLUDE_DIRECTORIES line at the
# END of the static/shared main stub block -- so a find_package consumer
# compiles against the sidecar. ARCHIVE_DESTINATION also moves the implib.
_polyorch_rust_install_plan(TRIPLE x86_64-unknown-linux-gnu KIND static HANDLE libx
    HEADERS /src/include/libx.h /src/include/extra.h OUT_ROWS _rows)
list(LENGTH _rows _n)
ck(${_n} EQUAL 3)
list(GET _rows 0 _r)
string(FIND "${_r}" "PROPERTIES INTERFACE_INCLUDE_DIRECTORIES \"\${_POLYORCH_RUST_ROOT}/include\")" _at)
ck(NOT _at EQUAL -1)
list(GET _rows 1 _r2)
ck_str("${_r2}" "/src/include/libx.h|include|${_PF}|||")
list(GET _rows 2 _r3)
ck_str("${_r3}" "/src/include/extra.h|include|${_PF}|||")

_polyorch_rust_install_plan(TRIPLE x86_64-unknown-linux-gnu KIND bin HANDLE app
    HEADERS /src/include/libx.h OUT_ROWS _rows)
list(LENGTH _rows _n)
ck(${_n} EQUAL 2)
list(GET _rows 0 _r)
if(_r MATCHES "INTERFACE_INCLUDE")
    message(FATAL_ERROR "t-rust-installplan: bin stub must not carry an include-dir line")
endif()

# A header into a prefixed tree lands under the folded DEST_INCLUDE, and the
# stub line uses the SAME folded directory (relocatability of the stub).
_polyorch_rust_install_plan(TRIPLE x86_64-apple-darwin KIND static HANDLE libx
    PREFIX app/ DEST_INCLUDE inc2 HEADERS /src/libx.h OUT_ROWS _rows)
list(GET _rows 0 _r)
string(FIND "${_r}" "INTERFACE_INCLUDE_DIRECTORIES \"\${_POLYORCH_RUST_ROOT}/app/inc2\")" _at)
ck(NOT _at EQUAL -1)
list(GET _rows 1 _r2)
rowf(_r2 1 _dest)
ck_str("${_dest}" "app/inc2")

# ------------------------------------------------------- I: guards --
if(POLYORCH_CHILD)
    if("$ENV{POLYORCH_INSTALLPLAN_CASE}" STREQUAL "kind")
        _polyorch_rust_install_plan(TRIPLE x86_64-unknown-linux-gnu KIND weird HANDLE a OUT_ROWS _o)
        message(FATAL_ERROR "expected rejection of KIND weird")
    elseif("$ENV{POLYORCH_INSTALLPLAN_CASE}" STREQUAL "missing")
        _polyorch_rust_install_plan(KIND bin HANDLE a OUT_ROWS _o)
        message(FATAL_ERROR "expected rejection of missing TRIPLE")
    else()
        _polyorch_rust_install_plan(TRIPLE x KIND bin HANDLE a OUT_ROWS _o KWARGEN)
        message(FATAL_ERROR "expected rejection of unknown keyword KWARGEN")
    endif()
endif()

set(ENV{POLYORCH_INSTALLPLAN_CASE} kind)
ck_child_fail("install-plan KIND must be bin\|static\|shared, got 'weird'")
set(ENV{POLYORCH_INSTALLPLAN_CASE} missing)
ck_child_fail("polyorch_rust: missing required argument 'A_TRIPLE'")
set(ENV{POLYORCH_INSTALLPLAN_CASE} unknown)
ck_child_fail("_polyorch_rust_install_plan unknown args")

message(STATUS "t-rust-installplan: OK (9 table legs + 3 guard pins)")
