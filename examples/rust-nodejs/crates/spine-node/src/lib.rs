use napi_derive::napi;

/// The wrapped API surface: #[napi] exports become require()-able.
#[napi]
pub fn add(a: i32, b: i32) -> i32 {
    a + b
}

#[napi]
pub fn greet(who: String) -> String {
    format!("hello from spine-node, {who}!")
}
