#include <stdio.h>
extern int rust_calc(int);   // exponent arrives at runtime: the pow reference
extern int rust_pid(void);   // survives the release profile (see lib.rs)
int main(void) {
    int v = rust_calc(10);
    int p = rust_pid();
    if (v != 1024 || p <= 0) {
        printf("POLYORCH_RUST_LINK_BAD calc=%d pid=%d\n", v, p);
        return 1;
    }
    printf("POLYORCH_RUST_LINK_OK pid=%d\n", p);
    return 0;
}
