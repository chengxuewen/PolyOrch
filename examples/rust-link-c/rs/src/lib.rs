// C-ABI geometry helpers, exported for the C consumer.
#[no_mangle]
pub extern "C" fn area_f64(w: f64, h: f64) -> f64 {
    w * h
}

#[no_mangle]
pub extern "C" fn area_as_int(w: f64, h: f64) -> i32 {
    (w * h) as i32
}
