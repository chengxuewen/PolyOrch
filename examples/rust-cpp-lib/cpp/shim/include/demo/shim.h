// The wrapper the bridge binds to. Global namespace (cxx-friendly); the
// wrapped library keeps its own demo:: namespace -- the wrapper's member
// is a qualified demo::Lib, which is exactly the "wrapping a library you
// cannot edit" shape.
#pragma once
#include <memory>
#include "demo/demo.h"

namespace demo {
class Lib;
}

class Demo {
public:
    Demo(int seed);
    ~Demo();
    int eval(int value) const;
    int level() const;
private:
    demo::Lib inner_;
};

std::unique_ptr<Demo> make_demo(int seed);
