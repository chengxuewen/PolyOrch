// WP9 gap-2 (reference test/rustflags): every --cfg flavor the rustflags
// channel can carry selects real code. Absent flags mean absent markers --
// attribute cfg, no constant folding decides the observable. The negative
// handle (no flags at all) fails on rf-dep's compile_error, which is the
// cargo 1.80+ proof that env RUSTFLAGS really is the global variant: the
// cfg reaches every crate the rule compiles (warnings for the unset names
// would be the dead-man signal -- the reference's own some_dependency
// compile-error leg rests on the same scoping guarantee).
#[cfg(not(any(rf_mode = "debug", rf_mode = "release")))]
fn mode() -> &'static str { "none" }
#[cfg(rf_mode = "debug")]
fn mode() -> &'static str { "debug" }
#[cfg(rf_mode = "release")]
fn mode() -> &'static str { "release" }

fn main() {
    let mut m: Vec<&str> = Vec::new();
    #[cfg(rf_one)]
    m.push("ONE");
    #[cfg(rf_two = "v")]
    m.push("TWO");
    m.push(rf_dep::seen());
    println!("RUSTFLAGS:{}|MODE:{}", m.join(","), mode());
}
