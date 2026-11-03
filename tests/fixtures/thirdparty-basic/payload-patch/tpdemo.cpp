#include "tpdemo.h"
// PATCHED overlay (verify-before-apply leg): the answer changes so the test
// can observe the overlay landed. Same basename = verbatim replacement at
// the archive root (the P1 file-patch shape; diff-shaped patches stay the
// recipe's PATCH_COMMAND business).
int tp_answer(void) { return 43; }
