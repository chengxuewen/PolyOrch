use pyo3::prelude::*;

/// The wrapped API surface: plain #[pyfunction]s on a #[pymodule].
#[pyfunction]
fn add(a: i64, b: i64) -> i64 {
    a + b
}

#[pyfunction]
fn greet(who: &str) -> String {
    format!("hello from spine-py, {who}!")
}

#[pymodule]
fn spine_py(m: &Bound<'_, PyModule>) -> PyResult<()> {
    m.add_function(wrap_pyfunction!(add, m)?)?;
    m.add_function(wrap_pyfunction!(greet, m)?)?;
    Ok(())
}
