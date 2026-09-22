#ifndef POLYORCH_DEMO_H
#define POLYORCH_DEMO_H

/* Sidecar header installed by polyorch_rust_install(PUBLIC_HEADER ..):
 * the find_package consumer compiles against this file through the
 * INTERFACE_INCLUDE_DIRECTORIES line the replay stub re-attaches to the
 * static handle. */
int demo_add(int a, int b);
int demo_pow(int a, int b);

#endif /* POLYORCH_DEMO_H */
