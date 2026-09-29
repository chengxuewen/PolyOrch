//! The wrapping crate: declares the C++ library surface via cxx and re-
//! exports it. The bin (main.rs) calls through it.
// bridge.rs contains `pub mod bridge` (the #[cxx::bridge] module, the
// ecosystem-standard nesting), so the generated trampolines live one
// level down.
pub use bridge::bridge::{make_demo, Demo};
pub mod bridge;
