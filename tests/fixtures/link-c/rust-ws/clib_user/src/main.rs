extern "C" {
    fn clib_seven() -> i32;
}

fn main() {
    let v = unsafe { clib_seven() };
    println!("POLYORCH_LINKLIB_OK {}", v);
}
