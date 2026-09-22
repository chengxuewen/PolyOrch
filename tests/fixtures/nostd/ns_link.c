extern int ns_add(int a, int b);

/* Only a compile+archive member: a #![no_std] crate's archive still carries
   the unwinding personality reference, so a FULL link (executable) is not
   what this fixture proves -- neither is it in the reference, whose
   nostd-cpp-lib is a STATIC target. The build itself (cargo compiles the
   no_std crate through PolyOrch's wrapper, CMake archives the consumer
   object that references its symbol) is the physical leg. */
int ns_call_twice(void) {
    return ns_add(20, 22);
}
