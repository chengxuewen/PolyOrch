// The compiled half of the fixture crate: plain Rust, no cxx dependency.
// bridge.rs and sub/nested.rs below are NEVER part of this module tree --
// cxxbridge reads them as text and cargo never sees them.
#[no_mangle]
pub extern "C" fn bridge_fixture_ping() -> i32 {
    7
}
