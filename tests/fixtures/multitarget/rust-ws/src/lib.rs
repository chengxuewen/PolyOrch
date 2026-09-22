pub fn hello_world() {
    println!("Hello, world!");
}

extern "C" {
    pub fn cpp_function(name: *const std::os::raw::c_char);
}
