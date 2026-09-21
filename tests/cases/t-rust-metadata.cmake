include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")

# Offline regression for _polyorch_rust_metadata_targets (Task 5): the pure
# parser that turns `cargo metadata --format-version 1` JSON into importable
# target records. Table-driven on canned JSON -- no toolchain, no cargo run.
# The real-metadata chain that FEEDS this parser is covered by
# t-rust-import-ws.cmake (e2e).
#
# Record shape (pipe-separated, one entry per importable kind):
#   <package>|<cmake_handle>|<cargo_selector>|<kind>   kind in {bin,static,shared}
# Naming contract under test (gen:137-142 rationale):
#   lib kinds:  handle = target name with dashes -> underscores -- cargo's own
#               lib artifact name, version-proof (explicit lib names never had
#               dashes; Rust >= 1.79 replaces inherited dashes too).
#   bin kinds:  handle = "<target>-exe" UNCONDITIONALLY (the bin artifact base
#               equals the raw target name, so a bare handle would trip the
#               PIT-13 collision guard); selector = raw name, dashes kept.
#   staticlib+cdylib on one target: the pair "<h>-static" + "<h>-shared".
# Non-importable kinds (lib/rlib/custom-build/proc-macro/test/...) yield no
# record (STATUS only). P4 exact-set idiom: sorted compare, so a stray or
# missing record fails.

# ck_md <json-var> <expected-sorted-records(|-joined)>
macro(ck_md jv exp)
    _polyorch_rust_metadata_targets("${${jv}}" _specs)
    list(SORT _specs)
    ck_str("${_specs}" "${exp}")
endmacro()

# --- 1. the two-package workspace shape: dashed staticlib lib + dashed bin,
#        a dual-kind lib target, plus noise kinds that must vanish.
set(_j1 [==[
{
  "id": "path+file:///ws/dash-ed#0.1.0",
  "packages": [
    {
      "name": "lib-a",
      "version": "0.1.0",
      "manifest_path": "/ws/lib-a/Cargo.toml",
      "targets": [
        { "kind": ["custom-build"], "crate_types": ["bin"], "name": "build-script-build", "src_path": "/ws/lib-a/build.rs" },
        { "kind": ["staticlib"], "crate_types": ["staticlib"], "name": "lib-a", "src_path": "/ws/lib-a/src/lib.rs" },
        { "kind": ["staticlib", "cdylib", "rlib"], "crate_types": ["staticlib", "cdylib", "rlib"], "name": "lib-a-all", "src_path": "/ws/lib-a/src/lib.rs" }
      ]
    },
    {
      "name": "tool",
      "version": "0.1.0",
      "manifest_path": "/ws/tool/Cargo.toml",
      "targets": [
        { "kind": ["bin"], "crate_types": ["bin"], "name": "run-tool", "src_path": "/ws/tool/src/main.rs" },
        { "kind": ["test"], "crate_types": ["bin"], "name": "it", "src_path": "/ws/tool/tests/it.rs" },
        { "kind": ["rlib"], "crate_types": ["rlib"], "name": "t-core", "src_path": "/ws/tool/src/core.rs" }
      ]
    }
  ],
  "workspace_members": ["path+file:///ws/dash-ed#0.1.0"],
  "metadata": null,
  "version": 1
}
]==])
ck_md(_j1 "lib-a|lib_a_all-shared|lib_a_all|shared;lib-a|lib_a_all-static|lib_a_all|static;lib-a|lib_a|lib_a|static;tool|run-tool-exe|run-tool|bin")

# --- 2. single-kind cdylib keeps the plain underscored handle (no -shared
#        suffix without a staticlib sibling).
set(_j2 [==[
{"packages":[{"name":"plug","targets":[
  {"kind":["cdylib"],"name":"my-plug"}
]}],"version":1}
]==])
ck_md(_j2 "plug|my_plug|my_plug|shared")

# --- 3. nothing importable yields an empty list, not a FATAL: a lib-only
#        package and a proc-macro package.
set(_j3 [==[
{"packages":[
  {"name":"plain","targets":[{"kind":["lib"],"name":"plain"}]},
  {"name":"pmac","targets":[{"kind":["proc-macro"],"name":"pmac"},{"kind":["custom-build"],"name":"build-script-build"}]}
],"version":1}
]==])
ck_md(_j3 "")

# --- 4. empty packages array (guarded loop, the RANGE-negative trap).
set(_j4 [==[{"packages":[],"version":1}]==])
ck_md(_j4 "")

# --- 5. bin with an underscore-free name still gets -exe; multiple bins in
#        one package each get their own record.
set(_j5 [==[
{"packages":[{"name":"two","targets":[
  {"kind":["bin"],"name":"alpha"},{"kind":["bin"],"name":"beta-x"},
  {"kind":["bin","extra"],"name":"gamma"}
]}],"version":1}
]==])
ck_md(_j5 "two|alpha-exe|alpha|bin;two|beta-x-exe|beta-x|bin;two|gamma-exe|gamma|bin")

message(STATUS "rust-metadata: OK (parse table: workspace shape, dual kind, dash rules, skips, empty)")
