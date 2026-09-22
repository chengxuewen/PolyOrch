// WP9 nostd feasibility leg (reference test/nostd): a #![no_std] crate with
// its own panic handler builds through polyorch_rust_build(STATIC) on the
// plain host target with ZERO crates.io deps -- the same shape the
// reference's NO_STD keyword test fixture compiles (rust-nostd-lib), minus
// the keyword: PolyOrch has no NO_STD argument (ledgered: the keyword's
// link-stripping role is inert here because the crate never references std,
// and the native-libs probe interface only ADDS system libs a C link
// tolerates). The -nostdlib C++ link leg of the reference is NOT ported:
// our STATIC handle's probe-attached system libs would fight it; the honest
// proof here is that the artifact builds and a normal C executable links
// and runs it.
#![no_std]

use core::panic::PanicInfo;

#[no_mangle]
pub extern "C" fn ns_add(a: i32, b: i32) -> i32 {
    a.wrapping_add(b)
}

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    loop {}
}
