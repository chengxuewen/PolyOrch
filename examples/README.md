# PolyOrch examples

| Example | Entry | Shows |
|---|---|---|
| `pixi-bootstrap/` | `cmake -P pixi-bootstrap/bootstrap.cmake [-DPIXI_PIN=x.y.z]` | cold start without pixi: locate/install the tool, solve + install an environment with lock-drift recovery, smoke-run a task |
| `pixi-configure/` | `cmake -S pixi-configure -B build` | read-only consumption during a normal configure step (`find` + `setup(REPORT)`) |
| `pixi-workspace/` | `cmake -S pixi-workspace -B build` | the workspace declared in CMake itself -- `polyorch_pixi_init(NAME/VERSION/CHANNELS/PLATFORMS/ENVIRONMENTS_DIR/COPY_SCRIPTS)`, no external pixi.toml, env storage redirected, activation scripts installed beside `.pixi/` |
| `rust-basic/` | `cmake -P rust-basic/env-setup.cmake && cmake -S rust-basic -B build` | the rust helpers: `env-setup.cmake` installs the example's own pixi rust environment (the only network step), then `polyorch_rust_setup(FROM pixi REQUIRED)` selects its cargo/rustc, `polyorch_rust_build()` exports the binary as the imported target `greet-cli`, `polyorch_rust_test()` registers a non-default `cargo test` target, `polyorch_rust_run()` wires `--target run-greet-cli`; configure alone is host-safe (STATUS + skip while the env is absent) |

The tool-only half of the cold start is its own entry point --
`polyorch_pixi_tool_ensure([VERSION] [URL] [HASH] [NO_PRECHECK] [QUIET])` --
locate/install/verify the pixi binary and nothing else (no manifest, no lock,
no environment); `polyorch_pixi_bootstrap()` calls it as its [1/3] phase.

With `-DPolyOrch_BUILD_EXAMPLES=ON`, every example is also a build target --
discoverable and runnable without typing its entry command (each writes into
its own `standalone/` build dir, so they never collide with the embedded
configure):

```bash
cmake --build build --target PolyOrchExamplePixiBootstrap   # may reach the network
cmake --build build --target PolyOrchExamplePixiConfigure   # read-only
cmake --build build --target PolyOrchExamplePixiWorkspace   # writes its build dir
cmake --build build --target PolyOrchExampleRustBasic      # install env -> configure -> cargo build -> run (network on first run)
```

All examples except rust-basic stay offline once pixi itself is installed: the
pixi-configure and pixi-workspace manifests are dependency-free, and
`pixi-workspace` only writes the manifest + local config (no install).
`rust-basic/env-setup.cmake` solves + installs a rust toolchain from
conda-forge -- its configure step deliberately skips itself (STATUS, no
FATAL) until that env exists, so any host can carry it.
(no install). The version pin, manifest path and smoke task in `bootstrap.cmake`
are caller policy -- the PolyOrch module ships the mechanism, not the numbers.
