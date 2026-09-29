// The existing C++ library surface: what Rust is wrapping. Pure C++
// (a class with state) -- the shape of a real third-party library.
#pragma once
#include <string>

namespace demo {
class Lib {
public:
    Lib();
    explicit Lib(int seed);
    int eval(int value) const;          // stateful computation
    const char* name() const noexcept;  // static-ish identity
private:
    int seed_;
};
}
