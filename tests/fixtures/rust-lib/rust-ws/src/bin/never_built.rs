// Presence of this bin is the --lib restriction proof: `cargo build --lib`
// must NOT build it. The e2e case asserts this path never exists after the
// mediator build; if anything ever builds the bin, its main() shouts.
fn main() {
    panic!("never_built bin was compiled -- the --lib restriction leaked");
}
