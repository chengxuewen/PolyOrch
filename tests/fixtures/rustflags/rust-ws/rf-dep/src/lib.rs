// Global-variant proof: PolyOrch's RUSTFLAGS is the env variant (ledgered
// deviation from the reference's `cargo rustc --` local form, and the
// mirror of its some_dependency leg which proves the LOCAL variant does NOT
// reach deps). Without --cfg=rf_glob this DEPENDENCY does not compile at
// all -- so the positive build is evidence the flag scope is global.
pub fn seen() -> &'static str {
    #[cfg(not(rf_glob))]
    compile_error!("POLYORCH_RUSTFLAGS_DEP_NOT_SEEN global RUSTFLAGS did not reach the dependency");
    "DEP"
}
