fn main() {
    // musl = fully static: this binary runs anywhere with the right arch,
    // no glibc version dance.
    println!("musl-app: static binary, target triple baked at build time");
}
