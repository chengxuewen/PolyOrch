// The plain-C surface: documented by cbindgen, consumed through the
// installed header by the find_package consumer.
use std::ffi::{c_char, CStr, CString};
use std::sync::atomic::{AtomicU32, Ordering};

static CALLS: AtomicU32 = AtomicU32::new(0);

/// Returns the number of times spine_greet has been called so far.
#[no_mangle]
pub extern "C" fn spine_calls() -> u32 {
    CALLS.load(Ordering::SeqCst)
}

/// Greets `who` through the C ABI. The returned string is heap-allocated
/// and owned by the caller: free it with spine_string_free.
#[no_mangle]
pub extern "C" fn spine_greet(who: *const c_char) -> *mut c_char {
    CALLS.fetch_add(1, Ordering::SeqCst);
    let who = unsafe {
        if who.is_null() { "stranger" } else { CStr::from_ptr(who).to_str().unwrap_or("stranger") }
    };
    let out = CString::new(format!("hello from spine, {who}!")).expect("nul-free");
    out.into_raw()
}

/// Frees a string previously returned by spine_greet.
#[no_mangle]
pub extern "C" fn spine_string_free(s: *mut c_char) {
    if !s.is_null() {
        unsafe { drop(CString::from_raw(s)) };
    }
}
