// WP9 gap-7 (reference test/gensource, simplified to std-only): the body of
// gen_marker comes from a CMake-GENERATED file, pulled in through an
// absolute-path include! -- the generated file's location rides an env var
// the build rule exports (set_env_vars), not OUT_DIR, so the only moving
// part is the ordering: if PREBUILD does not order the generator before
// cargo, this include fails and the crate does not compile AT ALL.
include!(concat!(env!("POLYORCH_GEN_DIR"), "/incl.rs"));

fn main() {
    println!("GENSOURCE:{}", gen_marker());
}
