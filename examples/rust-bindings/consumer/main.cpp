// Consumes the INSTALLED package: cbindgen-documented C ABI via the
// installed spine.h, linked through the replay stub's import location.
#include <cstdio>
#include "spine.h"

// The cxx bridge's C++-implemented surface ships with the CONSUMER (by
// design: those functions are the consumer's own code the bridge calls
// back into). The installed package only carries the Rust side.
double host_scale(double value, double factor) {
    return value * factor;
}

int main() {
    const char* msg = spine_greet("installed consumer");
    std::printf("%s (calls so far: %u)\n", msg, spine_calls());
    spine_string_free(const_cast<char*>(msg));
    return 0;
}
