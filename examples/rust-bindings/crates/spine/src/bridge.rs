#[cxx::bridge]
pub mod bridge {
    // NOTE: the macro AND build.rs both use this file (cxx_build locates (build.rs), NOT by the #[cxx::bridge] macro
    // -- the two would generate diverging trampolines. The doc item below

    // the module by the attribute; cargo compiles the macro expansion).
    //
    // Shared struct: C++ sees the same layout via the generated header.
    pub struct Sample {
        pub id: u32,
        pub label: String,
    }

    unsafe extern "C++" {
        // The hand-written C++ header with the real declarations; cxx
        // inlines its content into the generated header, so the symbol
        // lands in the namespace block the trampoline uses.
        include!("spine/bridge_impl.h");
        fn host_scale(value: f64, factor: f64) -> f64;
    }

    extern "Rust" {
        // Rust side implemented in bridge_impl.rs -- the "Rust implements,
        // C++ calls" direction.
        fn spine_echo(msg: &str) -> String;
        fn spine_add(a: i64, b: i64) -> i64;
        fn spine_make(id: u32, label: &str) -> Sample;
    }
}

// The extern "Rust" implementations: SAME FILE as the bridge declaration
// (cxx resolves `super::` within this file's module scope; the official
// cxx demo uses exactly this layout).
pub fn spine_echo(msg: &str) -> String {
    format!("spine echoes: {msg}")
}

pub fn spine_add(a: i64, b: i64) -> i64 {
    a + b
}

pub fn spine_make(id: u32, label: &str) -> bridge::Sample {
    bridge::Sample { id, label: label.to_string() }
}
