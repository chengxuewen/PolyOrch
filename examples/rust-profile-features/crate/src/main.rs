// env! reads POLYORCH_DEMO_GREETING at COMPILE time -- polyorch_rust_set_env_vars
// exports it to the cargo build (cmake -E env), so it bakes into the binary.
// Runtime std::env::var would NOT see it (the setter is a build-time channel;
// that distinction IS the lesson of this example).
fn main() {
    println!("profile={} env={}",
        if cfg!(debug_assertions) { "debug" } else { "release" },
        env!("POLYORCH_DEMO_GREETING"));

    #[cfg(feature = "greet-loud")]
    println!("[greet-loud feature is ON]");

    #[cfg(feature = "greet-formal")]
    println!("[greet-formal feature is ON]");

    #[cfg(not(any(feature = "greet-loud", feature = "greet-formal")))]
    println!("[no greet features: default build]");
}
