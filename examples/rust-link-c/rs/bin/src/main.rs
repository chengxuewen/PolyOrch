// The reverse direction: a Rust binary that calls INTO a C static library
// (declared here, provided by the CMake target below via link_libraries).
extern "C" {
    fn c_triple_seven() -> i32;
}
fn main() {
    unsafe { println!("cli-user: c_triple_seven() = {}", c_triple_seven()) };
}
