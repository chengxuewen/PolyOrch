// Input for cxxbridge only (parsed, never compiled by cargo): the real
// tool generates the bindings from this #[cxx::bridge]; the offline stub
// ignores the content and emits dummy files.
#[cxx::bridge]
mod ffi {
    extern "Rust" {
        fn hello_bridge() -> String;
    }
}
