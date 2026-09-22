extern "C" {
    fn pow(x: f64, y: f64) -> f64; // libm: NOT linked implicitly by cc
}

// Both operands arrive from the caller so rustc can never const-fold the
// pow call away (the measured fold-proof trick of the install-e2e
// fixture): the final C link of the consumer REQUIRES the probed
// system-lib interface the stub re-attaches -- which is what bites the
// negative leg when the case strips those lines.
#[no_mangle]
pub extern "C" fn demo_pow(a: i32, b: i32) -> i32 {
    unsafe { pow(a as f64, b as f64) as i32 }
}

#[no_mangle]
pub extern "C" fn demo_add(a: i32, b: i32) -> i32 {
    a + b
}
