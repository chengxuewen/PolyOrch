fn main() {
    // bridge() consumes the #[cxx::bridge] module and generates the
    // trampolines; the .file() list is for ADDITIONAL C++ sources only
    // (the Rust-side implementations in bridge_impl.rs are compiled by
    // cargo itself into the lib -- never list .rs files here).
    cxx_build::bridge("src/bridge.rs")
        .include("include")   // for the include!("spine/bridge_impl.h") pull-in
        .compile("spine_bridge");
}
