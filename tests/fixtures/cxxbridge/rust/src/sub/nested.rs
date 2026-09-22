// Second bridge file under a subdirectory: locks the reference's
// directory_component handling (corr:1935-1942) -- the generated header
// and source must land under sub/ on both sides of the tree.
#[cxx::bridge]
mod ffi2 {
    extern "Rust" {
        fn nested_bridge() -> u32;
    }
}
