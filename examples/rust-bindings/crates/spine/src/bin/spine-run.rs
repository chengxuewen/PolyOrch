// The demo runner binary: proves the crate is sane independent of the C++
// consumer (calls the re-exported implementations directly -- trampolines
// are for the C++ side; implementations live beside the bridge module).
use spine::bridge::spine_add;
use spine::bridge::spine_echo;

fn main() {
    let echoed = spine_echo("runner");
    let sum = spine_add(19, 23);
    println!("{echoed}; spine_add(19,23) = {sum}");
}
