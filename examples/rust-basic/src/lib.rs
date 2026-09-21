/// Build a greeting. The unit test below is what the example's
/// `polyorch_rust_test()` target hands to `cargo test`.
pub fn greet(name: &str) -> String {
    format!("hello, {name}!")
}

#[cfg(test)]
mod tests {
    use super::greet;

    #[test]
    fn greets() {
        assert_eq!(greet("polyorch"), "hello, polyorch!");
    }
}
