include("${CMAKE_CURRENT_LIST_DIR}/_inc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/PolyOrchRustHelpers.cmake")

# Offline regression for _polyorch_rust_parse_native_libs (Task 4): the pure
# parser that turns a `rustc --print=native-static-libs` transcript into the
# two link-interface lists. Table-driven, no toolchain and no cargo executed --
# only the string normalisation is under test. The probe that FEEDS this parser
# (its real cc/cargo behaviour) is covered by t-rust-link-c.cmake (e2e).
#
# Mechanism ported from the reference probe parser (find:166-205); each case
# below pins one branch of that normalisation, including the shapes this linux
# host's toolchain actually emits and the ones the reference tolerates for
# darwin / windows (kept honest: those branches are NOT exercised end-to-end on
# this host, only parsed here).

# ck_pl <text-var> <expected-libs(|-joined)> <expected-dirs(|-joined)>
macro(ck_pl tv exp_libs exp_dirs)
    _polyorch_rust_parse_native_libs("${${tv}}" _libs _dirs)
    ck_str("${_libs}" "${exp_libs}")
    ck_str("${_dirs}" "${exp_dirs}")
endmacro()

# --- 1. the exact transcript this host's toolchain produced (measured 2026-09-21),
#        cargo noise lines wrapped around the marker line.
set(_t1 [==[
   Compiling required_libs_probe v0.1.0 (/tmp/probe)
note: link against the following native artifacts when linking against this static library. The order and any duplication can be significant on some platforms

note: native-static-libs: -lgcc_s -lutil -lrt -lpthread -lm -ldl -lc
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 0.06s
]==])
ck_pl(_t1 "gcc_s;util;rt;pthread;m;dl;c" "")

# --- 2. duplicated -l tokens de-duplicate, first-occurrence order kept.
set(_t2 "native-static-libs: -lpthread -lm -lpthread -lc -lm")
ck_pl(_t2 "pthread;m;c" "")

# --- 3. a search dir in the attached (-L<dir>) and spaced (-L <dir>) forms,
#        plus the -L native=<dir> form; de-duplicated too.
set(_t3 "native-static-libs: -lm -L/opt/rust/self-contained -lpthread")
ck_pl(_t3 "m;pthread" "/opt/rust/self-contained")
set(_t3b "native-static-libs: -L /a/b -lc -L /a/b")
ck_pl(_t3b "c" "/a/b")
set(_t3c "native-static-libs: -L native=/x/y -lm")
ck_pl(_t3c "m" "/x/y")

# --- 4. empty text and garbage with no marker both yield empty lists, no FATAL.
set(_t4 "")
ck_pl(_t4 "" "")
set(_t4b "error: could not compile\nnative static libs (no colon marker)")
ck_pl(_t4b "" "")

# --- 5. windows shapes: msvcrt is dropped (the C runtime stays the consumer's
#        choice), a bare '<name>.lib' loses its suffix, the -l= equals form is
#        accepted. Parsed only (no windows toolchain runs here).
set(_t5 "native-static-libs: -lmsvcrt -lmsvcrtd ws2_32.lib kernel32.lib -l=bcryptlib")
ck_pl(_t5 "ws2_32;kernel32;bcryptlib" "")

# --- 6. framework-style text (future darwin) is merged into single items, not
#        dropped: tolerated, parsed, but NOT exercised against a real toolchain
#        here. Over-claim guard: this branch only proves the parser does not
#        mangle a -framework pair.
set(_t6 "native-static-libs: -framework Security -framework CoreFoundation -lc")
ck_pl(_t6 "-framework Security;-framework CoreFoundation;c" "")

message(STATUS "rust-native-libs: OK (parse table: linux set, dedupe, -L dirs, empty/garbage, windows, framework)")
