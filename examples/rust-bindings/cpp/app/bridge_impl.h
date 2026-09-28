// Hand-written C++ side of the bridge (cxx resolves ::host_scale globally;
// see the header comment in crates/spine/include for the namespace story).
#pragma once
double host_scale(double value, double factor) {
    return value * factor;
}
