// The extern "C" surface cbindgen reads: real cbindgen (live leg) parses
// this through cargo metadata and emits the declaration; the offline stub
// ignores the file and echoes its environment into the header instead.
#[repr(C)]
pub struct Point {
    pub x: i32,
    pub y: i32,
}

#[no_mangle]
pub extern "C" fn cb_marker_fn(p: Point) -> i32 {
    p.x + p.y
}
