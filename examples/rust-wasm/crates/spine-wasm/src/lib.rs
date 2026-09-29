use wasm_bindgen::prelude::*;

/// The web-facing API surface: #[wasm_bindgen] exports become the JS/TS
/// API of the generated pkg/ package (wasm-pack writes the .d.ts).
#[wasm_bindgen]
pub fn add(a: i32, b: i32) -> i32 {
    a + b
}

#[wasm_bindgen]
pub fn greet(who: &str) -> String {
    format!("hello from spine-wasm, {who}!")
}
