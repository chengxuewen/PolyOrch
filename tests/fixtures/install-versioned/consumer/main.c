#include <stdio.h>
#include <vpack.h>

int main(void) {
    printf("VPINST_CONSUMED %d\n", vpack_answer());
    return 0;
}
