#include <stdio.h>
extern int dash_pow(int, int);
int main(void) {
    int v = dash_pow(32, 2);
    if (v != 1024) {
        printf("INSTALL_E2E_BAD %d\n", v);
        return 1;
    }
    printf("INSTALL_E2E_CONSUMED\n");
    return 0;
}
