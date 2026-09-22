// WP9 gap-5 (reference test/custom_profiles): the selected profile is read
// off cfg(debug_assertions) at RUNTIME output, never off a folded const.
// The reference's nodbg-style profile disables debug assertions while the
// default dev profile keeps them -- the two markers below can only both be
// produced if --profile actually reached rustc.
#[cfg(debug_assertions)]
fn mark() -> &'static str { "DBG" }
#[cfg(not(debug_assertions))]
fn mark() -> &'static str { "NODEBG" }

fn main() {
    println!("PROF:{}", mark());
}
