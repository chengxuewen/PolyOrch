extern "C" {
    fn pow(x: f64, y: f64) -> f64; // lives in libm: NOT linked implicitly by cc
    fn getpid() -> i32;             // lives in libc
}

// 2^10 via libm's pow(): resolving this symbol at final link REQUIRES the
// system-lib interface the native-static-libs probe attaches. The exponent
// arrives from the caller: a constant exponent lets LLVM fold the pow call
// away under the release profile (measured), which would make the -lm
// interface non-load-bearing in the Release matrix cells.
#[no_mangle]
pub extern "C" fn rust_calc(y: i32) -> i32 {
    unsafe { pow(2.0, y as f64) as i32 }
}

#[no_mangle]
pub extern "C" fn rust_pid() -> i32 {
    unsafe { getpid() }
}
