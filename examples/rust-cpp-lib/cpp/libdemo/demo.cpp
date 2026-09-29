#include "demo/demo.h"

namespace demo {
Lib::Lib() : seed_(1) {}
Lib::Lib(int seed) : seed_(seed) {}
int Lib::eval(int value) const { return value * seed_ + 7; }
const char* Lib::name() const noexcept { return "demo-lib"; }
}
