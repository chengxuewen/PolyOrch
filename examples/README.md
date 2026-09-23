# PolyOrch examples

| Example | Entry | Shows |
|---|---|---|
| `pixi-bootstrap/` | `cmake -P pixi-bootstrap/bootstrap.cmake [-DPIXI_PIN=x.y.z]` | cold start without pixi: locate/install the tool, solve + install an environment with lock-drift recovery, smoke-run a task |
| `pixi-configure/` | `cmake -S pixi-configure -B build` | read-only consumption during a normal configure step (`find` + `setup(REPORT)`) |
| `pixi-env-run/` | `cmake -S pixi-env-run -B build -DPolyOrch_EXAMPLE_PIXI=ON` | "what pixi buys you": materialize an env carrying ANY tool (the demo uses `cmake` itself), read its paths via `polyorch_pixi_env_paths`, and run env tools from configure and build targets. First run solves (domestic network: add `-DPolyOrch_PIXI_MIRROR=cn`), later runs are stamped no-ops |
| `pixi-workspace/` | `cmake -S pixi-workspace -B build` | the workspace declared in CMake itself -- `polyorch_pixi_init(NAME/VERSION/CHANNELS/PLATFORMS/ENVIRONMENTS_DIR/COPY_SCRIPTS)`, no external pixi.toml, env storage redirected, activation scripts installed beside `.pixi/` |
| `rust-import/` | `cmake -S rust-import -B build` | import an EXISTING cargo workspace: `polyorch_rust_import` reads it via `cargo metadata`, creates one imported handle per member (`dash_ed` staticlib, `say-hi-exe` bin) with their `cargo-build-*` mediators, and `polyorch_rust_run` wires the `run-*` wrapper -- your Rust code stays untouched |
| `rust-link-c/` | `cmake -S rust-link-c -B build` | the MIXED project, both directions in one graph: a C executable links a Rust C-ABI staticlib (the native-static-libs probe attaches the toolchain's system libs automatically), and a Rust binary links a C staticlib through `polyorch_rust_link_libraries` (the -L/-l conversion) |
| `rust-profile-features/` | `cmake -S rust-profile-features -B build` | steering ONE package from CMake with all five knobs: PROFILE (debug vs --release), `polyorch_rust_set_features` (cfg arms), `polyorch_rust_set_env_vars` (compile-time `env!` baking -- a handle without the var fails to compile), `polyorch_rust_add_rustflags`, `polyorch_rust_add_cargo_flags` |
| `rust-install-export/` | producer+consumer (see target) | the integration story: `polyorch_rust_install(TARGETS mathkit EXPORT mathkit-demo PUBLIC_HEADER ...)` stages lib+header+generated `mathkit-demoConfig.cmake`, and a completely unrelated C project consumes it with plain `find_package(mathkit-demo CONFIG REQUIRED)` + `target_link_libraries` |
| `rust-basic/` | `cmake -S rust-basic -B build` | the rust helpers on the system route: `polyorch_rust_setup()` (no `FROM` -- cargo/rustc from `PATH`) selects the toolchain, `polyorch_rust_build()` exports the binary as the imported target `greet`, `polyorch_rust_test()` registers a non-default `cargo test` target, `polyorch_rust_run()` wires `--target run-greet`; the whole example is offline -- nothing here installs or pins the toolchain (pinning is an environment concern, and the pixi `FROM pixi` route is a covered mechanism, not an example need) |

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
cmake --build build --target PolyOrchExampleRustBasic      # configure -> cargo build -> run (needs cargo on PATH)
```

All examples stay offline once pixi itself is installed: the pixi-configure
and pixi-workspace manifests are dependency-free, and `pixi-workspace` only
writes the manifest + local config (no install). `rust-basic` needs only a
cargo on `PATH`. The version pin, manifest path and smoke task in
`bootstrap.cmake` are caller policy -- the PolyOrch module ships the
mechanism, not the numbers.
