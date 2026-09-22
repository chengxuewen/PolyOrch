# expect-log selflock line-one marker honored
# selflock line two is harness noise the driver must never treat as expect-no-log
message("selflock line-one marker honored")
message("# selflock line two is harness noise the driver must never treat as expect-no-log")
# Driver-shape skip echo: the drivers' own skip wording ("SKIP <file> (...)")
# lacks the " : SKIP (" contract form, so it can never self-veto. This line
# proves the two shapes cannot collide while the case still passes.
message("SKIP cases/t-driver-selflock.cmake (driver-shape, never vetoed)")
