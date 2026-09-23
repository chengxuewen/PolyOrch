#include <stdio.h>
extern int area_as_int(double w, double h);
int main(void) {
    printf("app: area(3, 4) = %d\n", area_as_int(3.0, 4.0));
    return 0;
}
