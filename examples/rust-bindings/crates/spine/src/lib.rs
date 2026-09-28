//! The flagship binding crate: one crate, two foreign surfaces.
//!
//! 1. C++ surface via #[cxx::bridge] (both directions: C++ calls Rust,
//!    Rust calls C++) -- built by cxx-build in build.rs, consumed by the
//!    C++ app under cpp/ through the generated headers + archive.
//! 2. C surface via #[no_mangle] extern "C" (c_abi module) -- documented
//!    by cbindgen and consumed through the installed header.
pub mod bridge;
pub mod c_abi;

