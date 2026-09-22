#include <stdio.h>
#include <demo.h>

int main(void) {
    if (demo_add(2, 3) != 5) {
        printf("INSTALL_EXPORT_BAD_ADD\n");
        return 1;
    }
    int v = demo_pow(32, 2);
    if (v != 1024) {
        printf("INSTALL_EXPORT_BAD_POW %d\n", v);
        return 1;
    }
    printf("INSTALL_EXPORT_CONSUMED\n");
    return 0;
}
