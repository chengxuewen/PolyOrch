#[cxx::bridge]
pub mod bridge {
    // NOTE: parsed by cxx_build (build.rs); cargo compiles the expansion.
    unsafe extern "C++" {
        // The wrapped C++ library surface. cxx turns `type Demo` into an
        // opaque Rust type; methods become &self calls.
        include!("demo/shim.h");
        type Demo;
        fn make_demo(seed: i32) -> UniquePtr<Demo>;
        fn eval(self: &Demo, value: i32) -> i32;
        fn level(self: &Demo) -> i32;
    }

}

