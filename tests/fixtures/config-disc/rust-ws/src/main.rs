// WP9 gap-8 (reference test/config_discovery, inverted to success-when-
// present): cargo must discover the fixture's `.cargo/config.toml` through
// the WORKING_DIRECTORY + --manifest-path combo PolyOrch's rule uses. Both
// halves are compile-time physical: [build] rustflags supplies the cfg
// (absent -> the MISSING arm is what compiles), and [env] supplies the
// value env! reads -- an undiscovered [env] entry is a COMPILE ERROR, not a
// runtime miss.
#[cfg(cfg_disc_flag)]
fn flagline() -> &'static str { "FLAG" }
#[cfg(not(cfg_disc_flag))]
fn flagline() -> &'static str { "MISSING" }

fn main() {
    println!("CONFIGDISC:{}|ENV:{}", flagline(), env!("CFG_DISC_ENV"));
}
