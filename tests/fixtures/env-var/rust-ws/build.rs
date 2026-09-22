// WP9 gap-4 (reference test/envvar): build.rs is the probe. A missing env
// var is a PANIC here -- the negative handle (no set_env_vars) fails to
// compile, so the positive build is evidence the vars reached the cargo
// process env. Values are baked via cargo:rustc-env and printed at runtime,
// so the case asserts the EXACT values crossed the boundary intact --
// including the one that rides a generate-time genex (the reference's
// INDIRECT_VAR_TEST leg; ours genexes the value side, the var NAME stays
// literal because polyorch_rust_set_env_vars validates `^[A-Za-z_]\w*=`).
fn main() {
    let a = std::env::var("POLYORCH_ENV_PROBE")
        .expect("POLYORCH_ENV_PROBE_NOT_SET build-script env");
    assert_eq!(a, "EXPECTED_VALUE");
    let g = std::env::var("POLYORCH_ENV_GENEX")
        .expect("POLYORCH_ENV_GENEX_NOT_SET build-script env");
    assert_eq!(g, "IND_VALUE");
    let v = std::env::var("POLYORCH_ENV_CARGO_VER")
        .expect("POLYORCH_ENV_CARGO_VER_NOT_SET build-script env");
    assert!(
        v.chars().next().is_some_and(|c| c.is_ascii_digit()),
        "POLYORCH_ENV_CARGO_VER not a version token: {v}"
    );
    println!("cargo:rustc-env=BAKED_PROBE={a}");
    println!("cargo:rustc-env=BAKED_GENEX={g}");
    println!("cargo:rustc-env=BAKED_VER={v}");
}
