// WP9 gap-3 (reference test/cargo_flags): the crate refuses to COMPILE
// unless all three features reached cargo through the CARGO_FLAGS argv
// channel -- the reference's exact compile_error-per-missing-feature shape.
#[cfg(not(feature = "one"))]
compile_error!("POLYORCH_CARGOFLAGS_MISSING=one");
#[cfg(not(feature = "two"))]
compile_error!("POLYORCH_CARGOFLAGS_MISSING=two");
#[cfg(not(feature = "three"))]
compile_error!("POLYORCH_CARGOFLAGS_MISSING=three");

fn main() {
    println!("CARGOFLAGS:one,two,three");
}
