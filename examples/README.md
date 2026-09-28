# PolyOrch examples

| Example | Entry | Shows |
|---|---|---|
| `pixi-bootstrap/` | `cmake -P pixi-bootstrap/bootstrap.cmake [-DPIXI_PIN=x.y.z]` | cold start without pixi: locate/install the tool, solve + install an environment with lock-drift recovery, smoke-run a task |
| `pixi-configure/` | `cmake -S pixi-configure -B build` | read-only consumption during a normal configure step (`find` + `setup(REPORT)`) |
| `pixi-env-run/` | `cmake -S pixi-env-run -B build -DPolyOrch_EXAMPLE_ROUTE=ON` | "what pixi buys you": materialize an env carrying ANY tool (the demo uses `cmake` itself), read its paths via `polyorch_pixi_env_paths`, and run env tools from configure and build targets. First run solves (domestic network: add `-DPolyOrch_PIXI_MIRROR=cn`), later runs are stamped no-ops |
| `pixi-workspace/` | `cmake -S pixi-workspace -B build` | the workspace declared in CMake itself -- `polyorch_pixi_init(NAME/VERSION/CHANNELS/PLATFORMS/ENVIRONMENTS_DIR/COPY_SCRIPTS)`, no external pixi.toml, env storage redirected, activation scripts installed beside `.pixi/` |
| `rust-import/` | `cmake -S rust-import -B build` | import an EXISTING cargo workspace: `polyorch_rust_import` reads it via `cargo metadata`, creates one imported handle per member (`dash_ed` staticlib, `say-hi-exe` bin) with their `cargo-build-*` mediators, and `polyorch_rust_run` wires the `run-*` wrapper -- your Rust code stays untouched |
| `rust-link-c/` | `cmake -S rust-link-c -B build` | the MIXED project, both directions in one graph: a C executable links a Rust C-ABI staticlib (the native-static-libs probe attaches the toolchain's system libs automatically), and a Rust binary links a C staticlib through `polyorch_rust_link_libraries` (the -L/-l conversion) |
| `rust-profile-features/` | `cmake -S rust-profile-features -B build` | steering ONE package from CMake with all five knobs: PROFILE (debug vs --release), `polyorch_rust_set_features` (cfg arms), `polyorch_rust_set_env_vars` (compile-time `env!` baking -- a handle without the var fails to compile), `polyorch_rust_add_rustflags`, `polyorch_rust_add_cargo_flags` |
| `rust-install-export/` | producer+consumer (see target) | the integration story: `polyorch_rust_install(TARGETS mathkit EXPORT mathkit-demo PUBLIC_HEADER ...)` stages lib+header+generated `mathkit-demoConfig.cmake`, and a completely unrelated C project consumes it with plain `find_package(mathkit-demo CONFIG REQUIRED)` + `target_link_libraries` |
| `rust-cross/` | `rustup target add x86_64-unknown-linux-musl` then `-DPolyOrch_RUST_CARGO_TARGET=<triple>` | cross-compiling in one graph: every handle routes through `--target` (artifacts nest under `.cargo-target/<triple>/`), while `polyorch_rust_set_hostbuild` opts one handle back OUT to the host layer -- device binary + build-machine binary, one configure |
| `rust-basic/` | `cmake -S rust-basic -B build` | the rust helpers on the system route: `polyorch_rust_setup()` (no `FROM` -- cargo/rustc from `PATH`) selects the toolchain, `polyorch_rust_build()` exports the binary as the imported target `greet`, `polyorch_rust_test()` registers a non-default `cargo test` target, `polyorch_rust_run()` wires `--target greet-run`; the whole example is offline -- nothing here installs or pins the toolchain (pinning is an environment concern, and the pixi `FROM pixi` route is a covered mechanism, not an example need) |

**Route matrix note**: every rust example carries BOTH routes -- the default
configure is the system route, and adding `-DPolyOrch_EXAMPLE_ROUTE=ON`
(+ `-DPolyOrch_PIXI_MIRROR=cn` on a domestic network) re-runs the SAME
example with the toolchain delivered by a pixi env (the umbrella targets
`PolyOrchExampleRust*Pixi` encode this). A dedicated "pixi rust" example
would duplicate the buttons; the route IS the option.

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

## Debugging rust targets in VSCode

Every rust example opts in to `PolyOrch_RUST_VSCODE_DEBUG` (the library
default stays OFF — nothing writes into your workspace unless you or an
example asks). After a configure, `<workspace root>/.vscode/` gains a
managed block in `launch.json` + `tasks.json`: one CodeLLDB launch config
per `polyorch_rust_run` target (Debug/Release profiles derive from the
artifact path) whose `preLaunchTask` builds exactly that crate's mediator
(`greet-build`) — F5 = incremental build of the real orchestrated artifact,
then debug. Reconfiguring regenerates the block in place; your own configs
above the markers are preserved byte-for-byte. Requirements: VSCode +
CMake Tools + the CodeLLDB extension.

- **Scope**: run targets only. Cross-routed binaries skip (remote debugging
  is a deferred surface), and `#[test]` debugging is deliberately delegated
  to rust-analyzer's test lens — cargo's fingerprint-hashed test binaries
  are unknowable at configure time, and per-test discovery is an editor
  concern the ecosystem already solved.
- **Wrong workspace root?** If you open folder A but configure subfolder B,
  pass `PolyOrch_RUST_VSCODE_DIR=<A>/.vscode` (e.g. via
  `cmake.configureSettings: { "PolyOrch_RUST_VSCODE_DIR":
  "${workspaceFolder}/.vscode" }`) so the files land where VSCode reads them.
- **Embedded hosts** get the block at the host root only when they actually
  build the rust examples — configuring examples means you want them, debug
  included; a host that never pulls an example sees nothing.

### Other IDEs (CLion, Qt Creator)

The generated launch/tasks files are VSCode formats; no other IDE reads
them (and `compile_commands.json` is code-insight only, never debug).
Manual one-time setup per IDE:

- **CLion**: Run > Edit Configurations > + > **Custom Build Application**;
  Executable = the artifact path from our generated launch.json; Before
  launch > Run Another Configuration, or build `greet-build` from the
  CMake target list first. (CMake `add_custom_target` itself never gains
  a debug button -- YouTrack CPP-43901/CPP-1313, open since 2010.)
- **Qt Creator**: Projects > Run > Add > **Custom Executable** with the
  artifact path; Projects > Build > Add Build Step > **Custom Process
  Step** for the cargo build (stored per-user in `.user` files -- not
  shareable).
- **Anything else**: `lldb <artifact>` / `gdb <artifact>` directly --
  the DWARF paths inside the cargo bytes point at the real sources.

