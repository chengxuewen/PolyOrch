// A C-ABI static library: the piece a CMake C/C++ target links against.
#[no_mangle]
pub extern "C" fn dash_ed_value() -> i32 {
    42
}
