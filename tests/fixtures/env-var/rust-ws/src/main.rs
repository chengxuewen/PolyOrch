fn main() {
    println!(
        "ENVVARS:{}|{}|VER_SEEN",
        env!("BAKED_PROBE"),
        env!("BAKED_GENEX")
    );
}
