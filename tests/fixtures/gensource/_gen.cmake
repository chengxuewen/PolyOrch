# tests/fixtures/gensource/_gen.cmake -- the generator (reference
# test/gensource/generator, as a cmake -P script: zero crates.io, zero
# compiled tools). Copies the INPUT marker into a valid .rs function body.
get_filename_component(_dir "${OUT}" DIRECTORY)
file(MAKE_DIRECTORY "${_dir}")
file(READ "${IN}" _marker)
string(STRIP "${_marker}" _marker)
file(WRITE "${OUT}" "pub fn gen_marker() -> &'static str { \"${_marker}\" }\n")
