# Pixi Profile

> Sources: https://github.com/prefix-dev/pixi (repository and README), https://github.com/prefix-dev/pixi/blob/main/LICENSE, https://github.com/prefix-dev/pixi/releases (release feed), https://pixi.prefix.dev/latest/ and its linked pages (official documentation), https://github.com/conda/rattler, https://github.com/astral-sh/uv, https://api.anaconda.org/package/conda-forge/ (package availability). Researched 2026-09-18.
> Not a derived document: facts here are externally sourced.

## 1. Product Profile

| Field | Value |
|---|---|
| Name | Pixi |
| Repository | `github.com/prefix-dev/pixi` (source: https://github.com/prefix-dev/pixi, 2026-09-18) |
| License | BSD-3-Clause, "Copyright (c) 2023, prefix.dev GmbH" (source: https://github.com/prefix-dev/pixi/blob/main/LICENSE, 2026-09-18) |
| Latest release | v0.81.0, published 2026-09-15 (source: https://github.com/prefix-dev/pixi/releases, 2026-09-18) |
| Implementation | Rust, built on the rattler libraries (source: https://github.com/prefix-dev/pixi/blob/main/README.md, 2026-09-18) |
| Workspace configuration | `pixi.toml`, also accepted as `[tool.pixi]` inside `pyproject.toml` (source: https://pixi.prefix.dev/latest/reference/pixi_manifest/, 2026-09-18) |
| Lock file | `pixi.lock`, a machine-generated YAML file with a version number (source: https://pixi.prefix.dev/latest/workspace/lock_file/, 2026-09-18) |
| Documentation home | `pixi.prefix.dev` (the `pixi.sh` links in the README redirect there) (source: https://pixi.prefix.dev/latest/, 2026-09-18) |
| Maintainer | prefix.dev GmbH, described in the README as the developer behind Pixi (source: https://github.com/prefix-dev/pixi/blob/main/README.md, 2026-09-18) |

The repository summary describes Pixi as a "Powerful system-level package manager for Linux, macOS and Windows written in Rust", building on top of the Conda ecosystem (source: https://github.com/prefix-dev/pixi, 2026-09-18). The README adds the workflow framing: Pixi is "a versatile developer workflow tool designed to streamline the management of your workspace's dependencies, tasks, and environments", "built on the foundation of the conda ecosystem", with "seamless integration with the PyPI ecosystem" (source: https://github.com/prefix-dev/pixi/blob/main/README.md, 2026-09-18). The documentation home states the goal plainly: "Pixi is a fast, modern, and reproducible package management tool for developers of all backgrounds" (source: https://pixi.prefix.dev/latest/, 2026-09-18).

This confirms the PolyOrch anchor: Pixi is a system-level package manager for Linux, macOS, and Windows, written in Rust on top of rattler, and it manages both environments and tasks. The task half is what overlaps with an orchestrator and needs an explicit boundary (Section 7).

## 2. Technical Characteristics

### Overall Architecture

Pixi is a single Rust binary that solves dependencies, materializes conda environments, runs tasks inside those environments, and generates or consumes a lock file.

- **Manifest.** A workspace is a directory containing `pixi.toml`, or a `pyproject.toml` with a `[tool.pixi]` section. Discovery priority is `--manifest-path`, then `pixi.toml`, then `pyproject.toml` in the current directory, then parent-directory search, then `$PIXI_PROJECT_MANIFEST` when `PIXI_IN_SHELL` is set (source: https://pixi.prefix.dev/latest/reference/pixi_manifest/, 2026-09-18).
- **Environments.** Conda environments live by default under `.pixi/envs`, one directory per environment, with `default` as the usual name. Pixi keeps each environment in sync with `pixi.lock` and re-syncs it automatically on commands such as `pixi run` and `pixi shell`; detached environments can be stored outside the workspace. The docs state the directories cannot be edited by hand and changes must go through the manifest (source: https://pixi.prefix.dev/latest/workspace/environment/, 2026-09-18).
- **Task runner.** Tasks are "essentially cross-platform shell commands, with a unified syntax across platforms", executed through the bundled `deno_task_shell` (source: https://pixi.prefix.dev/latest/reference/pixi_manifest/ and https://pixi.prefix.dev/latest/workspace/advanced_tasks/, 2026-09-18).
- **Lock file.** During lock creation Pixi resolves packages "for all environments and platforms listed in the manifest" (source: https://pixi.prefix.dev/latest/workspace/lock_file/, 2026-09-18).

### Key Capabilities

- **Multi-language.** Conda packages cover "multiple languages including Python, C++, and R", with PyPI as a second dependency source (source: https://github.com/prefix-dev/pixi/blob/main/README.md, 2026-09-18).
- **Cross-platform.** Linux, Windows, and macOS including Apple Silicon (source: https://github.com/prefix-dev/pixi/blob/main/README.md, 2026-09-18).
- **Multi-platform solving.** `[workspace].platforms` selects conda subdirs; documented examples include `win-64`, `linux-64`, `osx-64`, `osx-arm64`, and `win-arm64` (source: https://pixi.prefix.dev/latest/reference/pixi_manifest/, 2026-09-18).
- **Task graph.** Tasks declare `depends-on`, giving a documented execution order (source: https://pixi.prefix.dev/latest/workspace/advanced_tasks/, 2026-09-18).
- **Task caching.** Tasks with `inputs` and/or `outputs` are skipped when the environment, the resolved fingerprints, and the command are unchanged (source: https://pixi.prefix.dev/latest/workspace/advanced_tasks/, 2026-09-18).
- **Activation for subprocesses.** `pixi shell`, `pixi shell-hook`, and `pixi run` are the three activation paths; `pixi run` "runs its own cross-platform shell and has the ability to run tasks" (source: https://pixi.prefix.dev/latest/workspace/environment/, 2026-09-18).
- **Package building (preview).** Pixi can build conda packages through pluggable build backends, behind a `pixi-build` preview flag (source: https://pixi.prefix.dev/latest/build/backends/, 2026-09-18).

### Tech Stack

| Layer | Technology | Source |
|---|---|---|
| Implementation language | Rust | https://github.com/prefix-dev/pixi/blob/main/README.md, 2026-09-18 |
| Solver and package foundation | rattler (conda libraries in Rust) | https://github.com/prefix-dev/pixi/blob/main/README.md, 2026-09-18 |
| PyPI resolver | uv, integrated as a library (conda packages are passed to it as locked) | https://pixi.prefix.dev/latest/reference/pixi_manifest/, 2026-09-18 |
| Task shell | `deno_task_shell`, a limited bourne-shell implementation | https://pixi.prefix.dev/latest/workspace/advanced_tasks/, 2026-09-18 |
| Package formats | conda packages plus PyPI source and binary distributions | https://pixi.prefix.dev/latest/reference/pixi_manifest/, 2026-09-18 |
| Lock format | YAML with a `version` key (documented example shows `version: 6`) | https://pixi.prefix.dev/latest/workspace/lock_file/, 2026-09-18 |
| Default channel | conda-forge, described as over 30,000 packages | https://pixi.prefix.dev/latest/, 2026-09-18 |

## 3. Feature Overview

### Core Modules

Pixi is a flat CLI plus a manifest schema. The command surface (source: https://pixi.prefix.dev/latest/reference/cli/pixi/, 2026-09-18):

| Command | Responsibility |
|---|---|
| `add` / `remove` | Add or remove dependencies, then re-solve and install |
| `install` / `reinstall` | Install an environment, updating the lock file |
| `lock` | Solve and update `pixi.lock` without installing |
| `run` | Run a task or an executable inside the environment |
| `shell` / `shell-hook` | Start an activated shell, or print the activation script |
| `info` | Report system, workspace, and environment information; supports `--json` |
| `task` | Add, remove, alias, and list workspace tasks |
| `workspace` | Modify the manifest through the CLI (channels, platforms, environments, features, activation) |
| `global` | System-wide tool installation outside any workspace |
| `search` / `list` / `tree` | Package discovery and dependency inspection |
| `update` / `upgrade` | Move the lock file, and optionally the manifest, to newer versions |
| `publish` / `upload` | Build and publish conda packages to a channel |
| `exec` | Run a command in a temporary environment |
| `clean` / `config` / `completion` / `self-update` | Housekeeping and shell integration |

Top-level manifest tables include `[workspace]`, `[dependencies]`, `[pypi-dependencies]`, `[tasks]`, `[activation]`, `[target]`, `[feature]`, `[environments]`, and `[package]` with its nested `[package.build]` table (source: https://pixi.prefix.dev/latest/reference/pixi_manifest/, 2026-09-18).

### Notable Features

**Lock file.** `pixi.lock` has an `environments` map listing resolved packages per environment and platform, plus package definitions with `kind`, `name`, `version`, `build`, `subdir`, `url`, `sha256`, `md5`, `depends`, `constrains`, `license`, `size`, and `timestamp`. It carries a version number, documented as backward compatible but not forward compatible (source: https://pixi.prefix.dev/latest/workspace/lock_file/, 2026-09-18).

**Lock control flags.** `--frozen` installs exactly the locked set without updating the lock; `--locked` aborts when the lock is out of date with the manifest; `--no-install` rewrites the lock without touching the environment. Environment-variable equivalents are `PIXI_FROZEN`, `PIXI_LOCKED`, and `PIXI_NO_INSTALL` (source: https://pixi.prefix.dev/latest/workspace/lock_file/, 2026-09-18).

**Activation.** `pixi shell-hook` prints the activation commands, including `PATH`, `CONDA_PREFIX`, `PIXI_PROJECT_*`, `PIXI_ENVIRONMENT_NAME`, and per-package `etc/conda/activate.d/*.sh` scripts (for example the GCC, GFortran, G++, and rust scripts). The docs note that adding `bin` to `PATH` is not sufficient because those package scripts matter (source: https://pixi.prefix.dev/latest/workspace/environment/, 2026-09-18).

**Multi-environment via features.** `[feature.<name>]` bundles dependencies, PyPI dependencies, tasks, activation, channels, platforms, and constraints. `[environments]` selects which features compose an environment, with `no-default-feature` to exclude the implicit default feature and `solve-group` to force shared dependency versions across environments (source: https://pixi.prefix.dev/latest/reference/pixi_manifest/, 2026-09-18). In the lock file, packages carry an `environments` list so one row can serve several environments (source: https://pixi.prefix.dev/latest/workspace/multi_environment/, 2026-09-18).

**Per-platform configuration.** `[target.<platform>]` overrides dependencies, activation, and tasks per platform; the documented example overrides the Python version only on `win-64` and swaps the activation script for a `.bat` file on Windows. Platform entries can be inline tables pinning virtual packages, with keys `cuda`, `archspec`, `glibc`, `linux`, `macos` (alias `osx`), and `windows` mapped to the conda `__name` virtual packages. This is the documented replacement for the deprecated `[system-requirements]` table (source: https://pixi.prefix.dev/latest/reference/pixi_manifest/ and https://pixi.prefix.dev/latest/workspace/multi_platform_configuration/, 2026-09-18).

**Pixi version guard.** `[workspace].requires-pixi` is a conda version spec the running Pixi must satisfy before resolving or building; `">=0.40,<1.0"` fails an older Pixi with an error (source: https://pixi.prefix.dev/latest/reference/pixi_manifest/, 2026-09-18).

**Tasks in detail.** Fields include `cmd`, `depends-on`, `inputs`, `outputs`, `cwd`, `env`, `args`, `default-environment`, and `clean-env`. Arguments support MiniJinja templating with a `pixi` context exposing `pixi.platform`, `pixi.environment.name`, `pixi.manifest_path`, `pixi.version`, and platform booleans such as `pixi.is_win`. A shorthand syntax lets a task be an array of dependency task names, an alias (source: https://pixi.prefix.dev/latest/workspace/advanced_tasks/, 2026-09-18).

**Task shell semantics.** `deno_task_shell` offers built-ins (`cp`, `mv`, `rm`, `mkdir`, `echo`, `cat`, `exit`, `unset`, `xargs`), `&&`, `||`, `;`, pipelines, command substitution, redirects, and glob expansion. A failing command does not abort a multi-line task by default; fail-fast needs `&&` chaining or `set -e`. `clean-env` is Unix only (source: https://pixi.prefix.dev/latest/workspace/advanced_tasks/, 2026-09-18).

**Activation implementation.** Activation runs under `cmd.exe` on Windows and `bash` on Linux and macOS, and only `.sh`, `.bash`, and `.bat` scripts are supported. Scripts are called, not sourced, so only environment variables survive (sources: https://pixi.prefix.dev/latest/workspace/environment/ and https://pixi.prefix.dev/latest/reference/pixi_manifest/, 2026-09-18).

**Environment metadata.** On creation Pixi writes a `pixi` file into the environment's `conda-meta` directory with `manifest_path`, `environment_name`, `pixi_version`, and `environment_lock_file_hash` (source: https://pixi.prefix.dev/latest/workspace/environment/, 2026-09-18).

### Extensibility / Plugin Mechanism

Pixi has no general plugin API comparable to Xmake addons or Bazel rules. Its documented surfaces:

- **Build backends.** Building conda packages is delegated to backend executables that follow a protocol implemented by both Pixi and the backend, decoupling the backend from the manifest specification. Documented backends are `pixi-build-cmake`, `pixi-build-python`, `pixi-build-rattler-build`, `pixi-build-ros`, `pixi-build-r`, `pixi-build-rust`, and `pixi-build-mojo`. They are installed from channels declared under `[package.build]` and can be overridden with `PIXI_BUILD_BACKEND_OVERRIDE` and `PIXI_BUILD_BACKEND_OVERRIDE_ALL`; the docs include a "Debugging JSON-RPC" section for the protocol (source: https://pixi.prefix.dev/latest/build/backends/, 2026-09-18).
- **Tasks as extension points.** Any executable in the environment can be invoked by a task, which is the main user-facing automation surface (source: https://pixi.prefix.dev/latest/workspace/advanced_tasks/, 2026-09-18).
- **Configuration layering.** System, user, and project-local TOML files, with `PIXI_NO_CONFIG` and `PIXI_CONFIG_FILE` controlling which layers load (source: https://pixi.prefix.dev/latest/reference/environment_variables/, 2026-09-18).
- **Global tools.** `pixi global` installs tools outside a workspace with its own manifest; it is a user-machine surface, not a project extension mechanism (source: https://pixi.prefix.dev/latest/reference/cli/pixi/, 2026-09-18).

`pixi-build` is explicitly a preview: the docs warn it "is a preview flag, and will change until it is stabilized" and requires opting in via `workspace.preview = ["pixi-build"]` (sources: https://pixi.prefix.dev/latest/build/backends/pixi-build-cmake/ and https://pixi.prefix.dev/latest/build/workspace/, 2026-09-18).

## 4. Status & Ecosystem

- **Release cadence.** Frequent and pre-1.0: v0.81.0 on 2026-09-15, v0.80.0 on 2026-09-07, v0.79.0 on 2026-09-03, v0.78.0 on 2026-08-28, v0.77.1 on 2026-08-24, v0.77.0 on 2026-08-19 (source: https://github.com/prefix-dev/pixi/releases, 2026-09-18).
- **Adoption signal.** The repository page reported 7,736 stars at research time; star counts are a weak signal and are recorded only as a status marker (source: https://github.com/prefix-dev/pixi, 2026-09-18).
- **Community.** A Discord server is linked from the README (source: https://github.com/prefix-dev/pixi/blob/main/README.md, 2026-09-18).
- **Package ecosystem.** Pixi defaults to conda-forge, described as over 30,000 packages; private or hosted channels on prefix.dev and Quetz are supported (sources: https://pixi.prefix.dev/latest/ and https://pixi.prefix.dev/latest/reference/pixi_manifest/, 2026-09-18). As a cross-check on PolyOrch's stack, the anaconda.org conda-forge API listed `xmake` 3.1.1, `cmake` 4.4.3, `meson` 1.12.0, `ninja` 1.13.2, `colcon-common-extensions` 0.3.0, and `conan` 2.32.0, while `vcpkg` was present only at 2023.04.15 (source: https://api.anaconda.org/package/conda-forge/, 2026-09-18).
- **CI integration.** The official action is `prefix-dev/setup-pixi`; documented examples use `prefix-dev/setup-pixi@v0.10.0`, support installing multiple environments per job, cache environments, and expose `locked` and `frozen` inputs mapping to `pixi install --locked` and `pixi install --frozen` (source: https://pixi.prefix.dev/latest/integration/ci/github_actions/, 2026-09-18).
- **Containers.** Official images at `ghcr.io/prefix-dev/pixi`, with tags including `latest` on Ubuntu Noble, `focal`, `bullseye`, and CUDA base variants (source: https://pixi.prefix.dev/latest/deployment/container/, 2026-09-18).
- **Supply chain tooling.** Sigstore-based attestations are documented for publishing to prefix.dev, generated with `pixi publish --generate-attestation` and verifiable with tooling such as `gh attestation verify` (source: https://pixi.prefix.dev/latest/security/, 2026-09-18).
- **Governance.** Developed and branded by prefix.dev GmbH, which the LICENSE names as copyright holder (sources: https://github.com/prefix-dev/pixi/blob/main/README.md and https://github.com/prefix-dev/pixi/blob/main/LICENSE, 2026-09-18).

## 5. Market Positioning

Pixi positions itself as a cargo/npm/yarn-like experience for the conda ecosystem. The vision page states: "We created `pixi` because we want to have a cargo/npm/yarn like package management experience for conda" (source: https://pixi.prefix.dev/latest/misc/vision/, 2026-09-18). The FAQ compares Pixi against incumbents on installing Python, building packages, running predefined tasks, built-in lock files, speed, and use without Python; Pixi is the only listed tool marked as supporting per-project environments, built-in lock files, predefined tasks, and use without Python, with package building marked as in progress (source: https://pixi.prefix.dev/latest/misc/FAQ/, 2026-09-18).

| Category | Representative tools | Pixi's relation |
|---|---|---|
| Conda environment tools | conda, mamba, micromamba | Same solving and environment model, different UX, adds lock files and tasks |
| Python project tools | pip, poetry, uv | Overlaps for Python, but Pixi is language-agnostic and conda-first, and embeds uv for the PyPI half |
| Conda package builders | rattler-build, conda-build | Complementary: `pixi-build` drives backends rather than replacing them |
| Generic task runners | make, just, npm scripts | Adds cross-platform tasks and caching, but only inside its environment model |

Differentiators documented rather than asserted:

1. **Per-project, isolated environments.** Environments live under `.pixi/envs` by default and are kept in sync with the lock file automatically (source: https://pixi.prefix.dev/latest/workspace/environment/, 2026-09-18).
2. **One lock file across environments and platforms.** The lock resolves every declared environment and platform, which the docs argue can replace sharing a Docker container in many cases (source: https://pixi.prefix.dev/latest/workspace/lock_file/, 2026-09-18).
3. **Conda plus PyPI in one resolution.** uv is integrated as a library and conda packages are passed to it as locked, which the docs describe as unique among conda-based package managers that usually call pip from a subprocess (source: https://pixi.prefix.dev/latest/reference/pixi_manifest/, 2026-09-18).
4. **Cross-platform tasks.** One definition runs on Windows, macOS, and Linux through `deno_task_shell` (source: https://pixi.prefix.dev/latest/workspace/advanced_tasks/, 2026-09-18).
5. **Standalone binary.** A single Rust executable installed by shell script, PowerShell script, Homebrew, or `cargo install`, with no Python required (source: https://pixi.prefix.dev/latest/installation/, 2026-09-18).

The position that matters for PolyOrch: Pixi is a strong environment manager that also ships a task graph and a task cache, which are exactly what a build orchestrator already owns.

## 6. Product Highlights

- Manifest and lock file separate direct dependencies from the exact resolved set, with a documented lock version and backward compatibility guarantee (source: https://pixi.prefix.dev/latest/workspace/lock_file/, 2026-09-18).
- The lock resolves all environments and platforms in one pass, so a Linux CI job installs the pinned set a macOS developer uses (source: https://pixi.prefix.dev/latest/workspace/lock_file/, 2026-09-18).
- `requires-pixi` lets the workspace pin the tool version allowed to resolve it (source: https://pixi.prefix.dev/latest/reference/pixi_manifest/, 2026-09-18).
- `exclude-newer` provides time-based quarantine of new releases (source: https://pixi.prefix.dev/latest/reference/pixi_manifest/, 2026-09-18).
- Features and environments express test, dev, CUDA, or ROS variants without duplicating dependencies (source: https://pixi.prefix.dev/latest/reference/pixi_manifest/, 2026-09-18).
- `pixi info --json` provides machine-readable workspace, system, and environment information (source: https://pixi.prefix.dev/latest/reference/cli/pixi/info/, 2026-09-18).
- `pixi shell-hook` exposes activation as a portable script, a clean insertion point for non-interactive subprocess execution (source: https://pixi.prefix.dev/latest/workspace/environment/, 2026-09-18).
- Official GitHub Action and container images make CI adoption low-friction (sources: https://pixi.prefix.dev/latest/integration/ci/github_actions/ and https://pixi.prefix.dev/latest/deployment/container/, 2026-09-18).

## 7. Value to PolyOrch

PolyOrch's design places Pixi in the environment layer: PolyOrch pins toolchain versions in `pixi.toml`, relies on `pixi.lock` for reproducibility, and runs every build command under `pixi run`. The adapter layer dispatches CMake, Xmake, Meson, and Colcon, with Xmake as the native engine and vcpkg/Conan consumed through Xmake's `vcpkg::` and `conan::` namespaces. The points below are scoped to that design.

### [Adopt] Directly reusable

- **Adopt Pixi as the environment layer, with the toolchain declared in the manifest.** Because conda-forge carried `xmake` 3.1.1, `cmake` 4.4.3, `meson` 1.12.0, `ninja` 1.13.2, `colcon-common-extensions` 0.3.0, and `conan` 2.32.0 at research time, PolyOrch can pin an entire polyglot toolchain in `[dependencies]` and let one environment satisfy every adapter (source: https://api.anaconda.org/package/conda-forge/, 2026-09-18).
- **Adopt `pixi.lock` as the reproducibility anchor and commit it.** The docs state the lock is designed to be committed and that it serves as a resolution cache for faster CI; PolyOrch should treat it as a first-class input to its task and cache keys (source: https://pixi.prefix.dev/latest/workspace/lock_file/, 2026-09-18).
- **Adopt the lock control flags as PolyOrch execution modes.** Use `--locked` for runs that must fail when lock and manifest diverge, `--frozen` for hermetic builds that install exactly the locked set, and `--no-install` for lock-only refresh; the env-var equivalents (`PIXI_LOCKED`, `PIXI_FROZEN`, `PIXI_NO_INSTALL`) map cleanly onto PolyOrch modes (source: https://pixi.prefix.dev/latest/workspace/lock_file/, 2026-09-18).
- **Adopt `requires-pixi` to pin the environment manager version.** A spec such as `">=0.81,<1.0"` makes PolyOrch fail fast on a mismatched Pixi instead of resolving with an untested version (source: https://pixi.prefix.dev/latest/reference/pixi_manifest/, 2026-09-18).
- **Adopt `platforms` with inline virtual packages as the target matrix.** PolyOrch can express the full cross-build matrix in one manifest entry per platform, pinning `cuda` and `glibc` where needed, for example `{ platform = "linux-64", cuda = "12.0", glibc = "2.28" }` (source: https://pixi.prefix.dev/latest/reference/pixi_manifest/, 2026-09-18).
- **Adopt `pixi shell-hook` as the subprocess activation contract.** It emits `PATH`, `CONDA_PREFIX`, `PIXI_*` variables, and the package activation scripts that set compiler and runtime variables, so CMake, Xmake, Meson, and Colcon subprocesses see the pinned toolchain rather than the host one (source: https://pixi.prefix.dev/latest/workspace/environment/, 2026-09-18).
- **Adopt `pixi run <executable>` as the per-command wrapper.** Adapters should invoke `pixi run cmake ...` and `pixi run xmake ...` so the environment is activated per subprocess without PolyOrch reimplementing PATH and activation (source: https://pixi.prefix.dev/latest/workspace/environment/, 2026-09-18).
- **Adopt `pixi info --json` as the machine-readable integration feed.** This avoids parsing human-oriented logs or the manifest (source: https://pixi.prefix.dev/latest/reference/cli/pixi/info/, 2026-09-18).
- **Adopt `exclude-newer` as a supply-chain quarantine knob.** A cutoff such as `7d` excludes freshly published packages from solves, reducing exposure to a compromised release during the window when it is still canonical (source: https://pixi.prefix.dev/latest/reference/pixi_manifest/, 2026-09-18).
- **Adopt the environment metadata file as a verification handle.** `conda-meta/pixi` records `environment_lock_file_hash` and `pixi_version`, giving PolyOrch a cheap way to assert that the on-disk environment matches the expected lock file (source: https://pixi.prefix.dev/latest/workspace/environment/, 2026-09-18).
- **Adopt per-job isolation and cache redirection.** `PIXI_HOME`, `PIXI_CACHE_DIR`, and `PIXI_NO_CONFIG` let a job point at a job-local home and cache and ignore developer-level configuration, preventing state leaks between concurrent builds (source: https://pixi.prefix.dev/latest/reference/environment_variables/, 2026-09-18).
- **Adopt multi-environment composition for adapter variants.** Features and environments express test, CUDA, or ROS variants without duplicating the base dependency set, and `solve-group` keeps shared packages at identical versions (source: https://pixi.prefix.dev/latest/reference/pixi_manifest/, 2026-09-18).
- **Adopt the official CI and container paths.** `prefix-dev/setup-pixi@v0.10.0` installs several environments per job with caching, and `ghcr.io/prefix-dev/pixi` provides base images, cutting PolyOrch's bootstrap code (sources: https://pixi.prefix.dev/latest/integration/ci/github_actions/ and https://pixi.prefix.dev/latest/deployment/container/, 2026-09-18).

### [Adapt] Reusable with modification

- **Adapt the workspace layout: one Pixi workspace per PolyOrch workspace, not per package.** The lock and environment set are workspace-scoped, so splitting per package would multiply solves and break `solve-group` alignment; PolyOrch should keep one root `pixi.toml` and use features or environments for per-package or per-language variants (source: https://pixi.prefix.dev/latest/workspace/multi_environment/, 2026-09-18).
- **Adapt `[target.<platform>]` overrides to per-platform adapter selection.** Pixi already overrides dependencies, activation, and tasks per platform, so PolyOrch can declare Windows and Unix toolchain variants in one manifest instead of branching in its own code (source: https://pixi.prefix.dev/latest/workspace/multi_platform_configuration/, 2026-09-18).
- **Adapt `[activation]` to inject PolyOrch variables, respecting the script restriction.** Activation scripts are called, not sourced, so only environment variables survive and only `.sh`, `.bash`, and `.bat` are supported; PolyOrch should use `activation.env` or a minimal export-only script, never functions or aliases (source: https://pixi.prefix.dev/latest/reference/pixi_manifest/, 2026-09-18).
- **Adapt `pixi run` to a single-command wrapper, not a scheduler.** Pass exactly one executable and its arguments per invocation and let PolyOrch own ordering, parallelism, retries, and result classification; using Pixi tasks with `depends-on` for orchestration would create a second scheduler (see Avoid).
- **Adapt the task cache boundary.** Pixi reuses a task result only when the environment, the `inputs`/`outputs` fingerprints, and the command are unchanged; keep Pixi's cache for leaf developer tasks and key PolyOrch's own cache on the manifest plus `pixi.lock` hash so an environment change invalidates downstream builds (source: https://pixi.prefix.dev/latest/workspace/advanced_tasks/, 2026-09-18).
- **Adapt `--frozen` versus `--locked` to PolyOrch's dev and CI modes.** Interactive development can allow a re-solve; CI and release builds should pin with `--locked` or `--frozen` so a build never mutates the lock or installs an unexpected set (source: https://pixi.prefix.dev/latest/workspace/lock_file/, 2026-09-18).
- **Adapt multi-platform awareness in path handling.** A multi-platform lock contains one package list per platform and only the current platform is installed by default, so PolyOrch must not assume every locked package exists on disk and must select the target platform explicitly when cross-building (source: https://pixi.prefix.dev/latest/workspace/lock_file/, 2026-09-18).
- **Adapt package sources deliberately: prefer conda, use PyPI for the remainder.** The docs warn that PyPI packages "might be less stable than their conda counterparts" and recommend conda where possible; PolyOrch should make that a policy and record exceptions (source: https://pixi.prefix.dev/latest/reference/pixi_manifest/, 2026-09-18).
- **Adapt vcpkg and Conan provisioning away from conda-forge.** vcpkg on conda-forge was pinned at 2023.04.15 at research time, far behind current; PolyOrch should keep reaching vcpkg and Conan through Xmake's `vcpkg::` and `conan::` namespaces rather than expecting Pixi to supply current versions (source: https://api.anaconda.org/package/conda-forge/, 2026-09-18).
- **Adapt detached environments for sandboxed builds.** Environments can be stored outside the workspace, useful when the source tree is mounted read-only or shared across jobs (source: https://pixi.prefix.dev/latest/workspace/environment/, 2026-09-18).
- **Adapt `pixi global` only for developer conveniences.** Global tools live per user and are not part of the workspace lock, so PolyOrch must not depend on them for build correctness (source: https://pixi.prefix.dev/latest/reference/cli/pixi/, 2026-09-18).
- **Adapt task templating only where PolyOrch generates the manifest.** MiniJinja templating applies to manifest tasks, not to ad hoc CLI commands unless `--templated` is passed; template at generation time and keep the executed command explicit (source: https://pixi.prefix.dev/latest/workspace/advanced_tasks/, 2026-09-18).

### [Avoid] Known pitfalls / not applicable

- **Do not duplicate Pixi's task runner.** Pixi already models tasks, `depends-on` ordering, a task cache, per-task environments, and task arguments. PolyOrch's orchestration graph must remain in `polyorch.toml`; `[tasks]` may be generated as a developer convenience but must never be the source of truth, or the project will have two schedulers, two caches, and two definitions of when a build is up to date (source: https://pixi.prefix.dev/latest/workspace/advanced_tasks/, 2026-09-18).
- **Do not treat `pixi.toml` as PolyOrch's configuration authority.** It is Pixi's manifest; the source of truth for PolyOrch is `polyorch.toml`. Generate or template the Pixi manifest from PolyOrch's model and treat hand-written tasks or dependencies as overrides to reconcile.
- **Do not hand-edit `pixi.lock`.** The docs state it is built for machines and only made human readable for inspection, and that the lock version is backward but not forward compatible; PolyOrch should read it and hash it, never rewrite it (source: https://pixi.prefix.dev/latest/workspace/lock_file/, 2026-09-18).
- **Do not let `pixi run` mutate state during a governed build.** `pixi run` updates the lock file and installs the environment if required, so build steps must pass `--locked` or `--frozen` and a build cannot silently change its own inputs (source: https://pixi.prefix.dev/latest/reference/cli/pixi/run/, 2026-09-18).
- **Do not author complex shell logic in Pixi tasks.** `deno_task_shell` is a limited bourne-shell, a failing line does not abort a multi-line task by default, and `clean-env` is Unix only; keep orchestration in PolyOrch code and task commands to single tool invocations (source: https://pixi.prefix.dev/latest/workspace/advanced_tasks/, 2026-09-18).
- **Do not assume activation is shell-neutral.** Activation runs under `cmd.exe` on Windows and `bash` on Unix, and only `.sh`, `.bash`, and `.bat` scripts are honored; ship per-platform variants or use `activation.env` only (source: https://pixi.prefix.dev/latest/workspace/environment/, 2026-09-18).
- **Do not depend on `pixi-build` for the adapter layer.** It is behind the `pixi-build` preview flag and the docs state it will change until stabilized; the CMake backend also uses Ninja, which overlaps with PolyOrch's own CMake adapter rather than complementing it. Revisit only after stabilization and only if PolyOrch needs to publish conda packages (sources: https://pixi.prefix.dev/latest/build/backends/ and https://pixi.prefix.dev/latest/build/backends/pixi-build-cmake/, 2026-09-18).
- **Do not rely on a shared user-level Pixi home in parallel CI.** `PIXI_HOME` defaults to `~/.pixi` and `PIXI_CACHE_DIR` falls through `RATTLER_CACHE_DIR` and the XDG cache location, so concurrent jobs on one runner can contend unless both are set per job (source: https://pixi.prefix.dev/latest/reference/environment_variables/, 2026-09-18).
- **Do not assume one environment per platform in the lock.** Packages carry an `environments` list because several environments share rows, so cache keys and install checks must be environment-aware and platform-aware (source: https://pixi.prefix.dev/latest/workspace/multi_environment/, 2026-09-18).
- **Do not treat conda-forge as a supply-chain boundary for internal code.** Its packages are community-maintained; for governed builds use private channels and Pixi's Sigstore attestations when publishing internally (source: https://pixi.prefix.dev/latest/security/, 2026-09-18).
- **Do not leave the Pixi version floating.** The project is pre-1.0 with weekly releases, so pin the Pixi version in PolyOrch's bootstrap and mirror it in `requires-pixi`, because the lock file is not forward compatible (source: https://github.com/prefix-dev/pixi/releases, 2026-09-18).
- **Do not treat `pixi run` as bash.** It is `deno_task_shell`, so bash-only constructs beyond the documented syntax may not behave as expected; when a build genuinely needs a POSIX shell, invoke it as the executed program rather than relying on the task shell (source: https://pixi.prefix.dev/latest/workspace/advanced_tasks/, 2026-09-18).

## Appendix

### Minimal PolyOrch-style workspace manifest

```toml
[workspace]
name = "polyorch"
version = "0.1.0"
channels = ["conda-forge"]
platforms = [
  "linux-64",
  "osx-arm64",
  { platform = "linux-64", cuda = "12.0", glibc = "2.28" },
]
requires-pixi = ">=0.81,<1.0"
exclude-newer = "7d"

[dependencies]
cmake = ">=4.4.3,<5"
ninja = ">=1.13,<2"
meson = ">=1.12,<2"
xmake = ">=3.1.1,<4"
colcon-common-extensions = ">=0.3,<0.4"
conan = ">=2.32,<3"
python = ">=3.12,<3.13"

[tasks]
# Developer convenience only. PolyOrch owns the orchestration graph.
build = { cmd = "xmake", depends-on = ["configure"] }
configure = { cmd = "xmake f -m release" }
```

Field names and semantics come from the official manifest reference (source: https://pixi.prefix.dev/latest/reference/pixi_manifest/, 2026-09-18). The pinned versions mirror the conda-forge versions observed at research time (source: https://api.anaconda.org/package/conda-forge/, 2026-09-18).

### CLI surface relevant to PolyOrch integration

| Command | Purpose | Source |
|---|---|---|
| `pixi init` | Create a workspace with `pixi.toml` | https://pixi.prefix.dev/latest/first_workspace/, 2026-09-18 |
| `pixi install --locked` | Fail when the lock is out of date with the manifest | https://pixi.prefix.dev/latest/workspace/lock_file/, 2026-09-18 |
| `pixi install --frozen` | Install exactly the locked set without re-solving | https://pixi.prefix.dev/latest/workspace/lock_file/, 2026-09-18 |
| `pixi lock` | Re-solve and update the lock only | https://pixi.prefix.dev/latest/reference/cli/pixi/, 2026-09-18 |
| `pixi run -e <env> <cmd>` | Run one command or task in an environment | https://pixi.prefix.dev/latest/reference/cli/pixi/run/, 2026-09-18 |
| `pixi shell-hook` | Print the environment activation script | https://pixi.prefix.dev/latest/workspace/environment/, 2026-09-18 |
| `pixi info --json` | Machine-readable workspace and environment information | https://pixi.prefix.dev/latest/reference/cli/pixi/info/, 2026-09-18 |
| `pixi workspace platform add` | Modify the platform list through the CLI | https://pixi.prefix.dev/latest/reference/cli/pixi/, 2026-09-18 |
| `pixi task add ... --depends-on` | Define a task and its ordering edge | https://pixi.prefix.dev/latest/workspace/advanced_tasks/, 2026-09-18 |
| `pixi publish --generate-attestation` | Publish with a Sigstore attestation | https://pixi.prefix.dev/latest/security/, 2026-09-18 |


### Installation methods

The README and installation page document several supported install paths for the `pixi` binary (sources: https://github.com/prefix-dev/pixi/blob/main/README.md and https://pixi.prefix.dev/latest/installation/, 2026-09-18):

| Method | Command |
|---|---|
| Linux and macOS script | `curl -fsSL https://pixi.sh/install.sh | sh` |
| Homebrew | `brew install pixi` |
| Windows PowerShell | `irm -useb https://pixi.sh/install.ps1 | iex` |
| From source | `cargo install --locked --git https://github.com/prefix-dev/pixi.git pixi` |

The install scripts download the latest release, extract it, and place the `pixi` binary in `~/.pixi/bin`, creating that directory if needed (source: https://github.com/prefix-dev/pixi/blob/main/README.md, 2026-09-18). For a governed build this matters because the script path fetches the latest version, so PolyOrch should install a pinned release instead and then assert the version through `requires-pixi`.

### Manifest discovery priority

Pixi locates the workspace manifest with the following priority, highest first (source: https://pixi.prefix.dev/latest/reference/pixi_manifest/, 2026-09-18):

| Priority | Location |
|---|---|
| 6 | `--manifest-path` command-line argument |
| 5 | `pixi.toml` in the current working directory |
| 4 | `pyproject.toml` in the current working directory |
| 3 | `pixi.toml` or `pyproject.toml` found by walking parent directories (first match wins) |
| 1 | `$PIXI_PROJECT_MANIFEST` when `$PIXI_IN_SHELL` is set, as happens under `pixi shell` and `pixi run` |

For a monorepo, PolyOrch should always pass `--manifest-path` explicitly rather than relying on directory walking, so that the selected workspace is deterministic regardless of the adapter's working directory.

### Activation output for build subprocesses

`pixi shell-hook` prints an activation script in the following shape, which is the environment a build subprocess needs (source: https://pixi.prefix.dev/latest/workspace/environment/, 2026-09-18):

```shell
export PATH="/workspace/.pixi/envs/default/bin:..."
export CONDA_PREFIX="/workspace/.pixi/envs/default"
export PIXI_PROJECT_ROOT="/workspace"
export PIXI_PROJECT_MANIFEST="/workspace/pixi.toml"
export PIXI_ENVIRONMENT_NAME="default"
. "/workspace/.pixi/envs/default/etc/conda/activate.d/activate-gcc_linux-64.sh"
```

Any PolyOrch adapter that spawns a build tool should route through `pixi run` or source an equivalent `pixi shell-hook` output, so the compiler and runtime variables injected by conda packages are present.

### Lock file shape

The lock file has two parts: the environments block and the package definitions block (source: https://pixi.prefix.dev/latest/workspace/lock_file/, 2026-09-18):

```yaml
version: 6
environments:
  default:
    channels:
      - url: https://conda.anaconda.org/conda-forge/
    packages:
      linux-64:
        - conda: https://conda.anaconda.org/conda-forge/linux-64/python-3.12.2-....conda
packages:
  - kind: conda
    name: python
    version: 3.12.2
    build: h9f0c242_0_cpython
    subdir: osx-64
    url: https://conda.anaconda.org/conda-forge/osx-64/python-3.12.2-....conda
    sha256: 7647ac06c3798a182a4bcb1ff58864f1ef81eb3acea6971295304c23e43252fb
    timestamp: 1708118065292
```

The `version` key is documented as `6` in the current documentation, and the file is described as backward compatible but not forward compatible (source: https://pixi.prefix.dev/latest/workspace/lock_file/, 2026-09-18). PolyOrch should hash this file and treat it as an opaque input.