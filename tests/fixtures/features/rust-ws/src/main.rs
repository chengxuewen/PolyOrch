// Feature-gated prints (attribute cfg, not cfg! -- no constant folding
// decides the observable: absent features mean absent output lines).
fn main() {
    let mut feats: Vec<&str> = Vec::new();
    #[cfg(feature = "one")]
    feats.push("one");
    #[cfg(feature = "two")]
    feats.push("two");
    #[cfg(feature = "three")]
    feats.push("three");
    println!("FEATURES:{}", feats.join(","));
}

#[cfg(feature = "compile-breakage")]
compile_error!("POLYORCH_FEATURE_BREAKAGE default feature was not deactivated");
