fn manifest_dir() -> std::path::PathBuf {
    std::path::PathBuf::from(std::env::var("CARGO_MANIFEST_DIR").expect("manifest dir"))
}

fn main() {
    // cxx-build does not auto-track .file() inputs -- without these, the
    // shim's .o goes stale after shim edits (mangled-name drift shows up
    // as undefined symbols at link).
    println!("cargo:rerun-if-changed=../../cpp/shim/demo_shim.cc");
    println!("cargo:rerun-if-changed=../../cpp/shim/include/demo/shim.h");
    println!("cargo:rerun-if-changed=../../cpp/libdemo/include/demo/demo.h");
    // The include! in bridge.rs pulls demo/shim.h; the shim calls the real
    // library, whose header lives one level up. Both layers are on the
    // include path; the LIBRARY ITSELF is linked by CMake
    // (polyorch_rust_link_libraries), NOT here -- build.rs only compiles
    // the trampolines.
    cxx_build::bridge("src/bridge.rs")
        // manifest-anchored ABSOLUTE paths: cxx-build compiles the generated
        // .cpp with cwd = the OUT dir, so relative -I flags do not survive
        .include(manifest_dir().join("../../cpp/libdemo/include"))
        // the shim (bridge's C++ substance) compiles here too: cxx-build
        // provides rust/cxx.h for rust::String automatically
        .file(manifest_dir().join("../../cpp/shim/demo_shim.cc"))
        .include(manifest_dir().join("../../cpp/shim/include"))
        .compile("consumer_cxx");
}
