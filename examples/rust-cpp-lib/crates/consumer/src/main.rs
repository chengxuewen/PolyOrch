// The rust side calling the wrapped C++ library: construct through the
// bridge factory, call methods -- all via the generated trampolines.
fn main() {
    let demo = consumer::bridge::bridge::make_demo(3);
    let v = demo.eval(10);
    let lvl = demo.level();
    println!("demo level = {lvl}; demo.eval(10) = {v}");
}
