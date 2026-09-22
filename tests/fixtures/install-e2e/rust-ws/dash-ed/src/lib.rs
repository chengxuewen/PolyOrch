extern "C" {
    fn pow(x: f64, y: f64) -> f64; // libm: NOT linked implicitly by cc
}

// BOTH operands arrive from the caller: a constant exponent (the heredoc-era
// pow(a, 2.0)) lets LLVM fold the call into multiplication under the cargo
// release profile -- measured: the release archive carries NO undefined `pow`
// then, silently un-biting the stripped-stub negative leg once the fixture
// honors CMAKE_BUILD_TYPE. A runtime `pow` call survives every profile: the
// final C link REQUIRES the probe's system-lib interface, shipped through
// the stub.
#[no_mangle]
pub extern "C" fn dash_pow(a: i32, b: i32) -> i32 {
    unsafe { pow(a as f64, b as f64) as i32 }
}
