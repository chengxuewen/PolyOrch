// The bridge's C++ substance (compiled by cxx-build via build.rs -- it
// supplies rust/cxx.h and the trampoline companions). Forwards into the
// real library, which CMake builds and links (see CMakeLists.txt).
#include "demo/shim.h"

Demo::Demo(int seed) : inner_(demo::Lib(seed)) {}
Demo::~Demo() = default;
int Demo::eval(int value) const { return inner_.eval(value); }
int Demo::level() const { return inner_.eval(0); }

std::unique_ptr<Demo> make_demo(int seed) {
    return std::unique_ptr<Demo>(new Demo(seed));
}
