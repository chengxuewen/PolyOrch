// The C++ side the bridge calls INTO. The declarations stay in the GLOBAL
// namespace: cxx's generated trampoline resolves ::host_scale (the
// spine::bridge-spelled declarations in the generated header are its own
// forwarders, and a namespace-wrapped redeclaration would hide the symbol
// the trampoline looks up).
#pragma once
double host_scale(double value, double factor);
