# No markers at all: an always-runnable canary. It touches no capability,
# prints a marker-free PASS and stamps $TMPDIR (exported by run.sh / set as
# the TMPDIR test property by ctest). run.sh trips a wire when the stamp is
# missing after its loop, so "the case list silently filtered to nothing"
# becomes red instead of a green empty run. This case must NEVER skip.
file(TOUCH "$ENV{TMPDIR}/polyorch-canary.stamp")
message("t-driver-canary: PASS (marker-free canary, driver-wired)")
