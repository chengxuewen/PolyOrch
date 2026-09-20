# colcon Profile

> Sources: https://github.com/colcon/colcon-core, https://colcon.readthedocs.io/en/released/,
> https://pypi.org/project/colcon-core/, https://design.ros2.org/articles/build_tool.html,
> https://github.com/orgs/colcon/repositories, researched 2026-09-18
> Not a derived document: facts here are externally sourced.

**Framing note.** colcon is explicitly a **meta build tool**. It does not compile code itself. It
discovers packages, builds a dependency graph from manifests, topologically orders that graph, and
then delegates each package to an underlying build system (CMake, Make, setuptools, Cargo, Meson)
through extension points. Never describe it as a plain build system
(source: https://design.ros2.org/articles/build_tool.html, article written 2017-03, last modified 2021-01).

## 1. Product Profile

| Field | Value |
|---|---|
| Name | colcon (collective construction) |
| Repository | `github.com/colcon/colcon-core` (source: https://github.com/colcon/colcon-core, 2026-09-18) |
| Organization | `github.com/colcon`, 60 public repositories (source: https://github.com/orgs/colcon/repositories, 2026-09-18) |
| Version | `colcon-core` 0.21.3 (source: https://github.com/colcon/colcon-core/blob/master/colcon_core/__init__.py, 2026-09-18) |
| Release date | 0.21.3 uploaded to PyPI on 2026-09-17 (source: https://pypi.org/project/colcon-core/, 2026-09-18) |
| License | Apache-2.0 (source: https://github.com/colcon/colcon-core/blob/master/setup.cfg, 2026-09-18) |
| Implementation language | Python, `python_requires >=3.6` (source: https://github.com/colcon/colcon-core/blob/master/setup.cfg, 2026-09-18) |
| Config files | `package.xml` plus each package's native build files (per the verified anchor); user-side configuration via `colcon.pkg`, `.meta`, and `defaults.yaml` (source: https://colcon.readthedocs.io/en/released/user/configuration.html, 2026-09-18) |
| Author / maintainer | Dirk Thomas (source: https://github.com/colcon/colcon-core/blob/master/setup.cfg, 2026-09-18) |
| Development status | `Development Status :: 3 - Alpha` (source: https://github.com/colcon/colcon-core/blob/master/setup.cfg, 2026-09-18) |

colcon describes itself as "a command line tool to improve the workflow of building, testing and
using multiple software packages. It automates the process, handles the ordering and sets up the
environment to use the packages"
(source: https://github.com/colcon/colcon-core/blob/master/README.rst, 2026-09-18).

The name "colcon" is short for "collective construction", combining the first letters of two words
(source: https://github.com/colcon/colcon-core/blob/master/README.rst, 2026-09-18). It is distributed
as a set of separately installable Python packages. The `colcon-core` package carries the engine; all
build-system support (CMake, ROS, Python, Cargo, Meson) arrives as extension packages
(source: https://colcon.readthedocs.io/en/released/developer/design.html, 2026-09-18).

Origin note, kept to what the primary source records: the ROS 2 build-tool design article was written
by Dirk Thomas and states that he went on to develop colcon as a personal project, after which ROS 2
selected it as the universal build tool. The article does not attribute the project to a company
(source: https://design.ros2.org/articles/build_tool.html, written 2017-03, last modified 2021-01).

## 2. Technical Characteristics

### Overall Architecture

colcon is organized as a thin core plus a large surface of extension points. The stated goal is that
"It should be possible to add support for any kind of build system using extensions. `colcon-core`
only bundles Python support in order to bootstrap itself"
(source: https://colcon.readthedocs.io/en/released/developer/design.html, 2026-09-18).

The build-tool versus build-system boundary is drawn explicitly: "A build tool operates on a set of
packages. It determines the dependency graph and invokes the specific build system for each package
in topological order. The build tool itself should know as little as possible about the build system
used for a specific package"
(source: https://design.ros2.org/articles/build_tool.html, written 2017-03, last modified 2021-01).

The documented build pipeline for the `build` verb is a fixed sequence of stages:
`get_package_descriptors`, then `topological_order_packages`, then `select_package_decorators`, then
`get_jobs`, then `execute_jobs`, then `create_prefix_scripts`
(source: https://colcon.readthedocs.io/en/released/developer/program-flow.html, 2026-09-18). The `list`
verb follows the same front half but skips job creation and prints package name, path, and type
(source: https://colcon.readthedocs.io/en/released/developer/program-flow.html, 2026-09-18).

Explicitly out of scope for the tool itself: fetching package sources, installing dependencies, and
creating binary packages such as Debian packages. The design document says these "should be left for
other tools", while allowing extensions to add them
(source: https://colcon.readthedocs.io/en/released/developer/design.html, 2026-09-18).

### Key Capabilities

- Package discovery across a workspace, and package identification that returns the tuple
  `path`, `name`, and `type` (source: https://colcon.readthedocs.io/en/released/developer/extension-point.html, 2026-09-18).
- Identification extensions are grouped by priority. They run in priority order and the first
  extension that successfully identifies a package stops further extensions. Several extensions of
  equal priority all run, and identical results are required or a warning is printed and the path is
  skipped (source: https://colcon.readthedocs.io/en/released/developer/extension-point.html, 2026-09-18).
- Topological ordering of the package graph before any build work starts
  (source: https://colcon.readthedocs.io/en/released/developer/program-flow.html, 2026-09-18).
- Per-package build jobs keyed by the combination of a verb and a package type, for example building
  a Python package or building a CMake package
  (source: https://colcon.readthedocs.io/en/released/developer/extension-point.html, 2026-09-18).
- Pluggable execution models, with the highest-priority executor extension used by default
  (source: https://colcon.readthedocs.io/en/released/developer/extension-point.html, 2026-09-18).
- Environment materialization after a build, using shell extensions and environment extensions to
  generate per-shell setup scripts
  (source: https://colcon.readthedocs.io/en/released/developer/extension-point.html, 2026-09-18).
- Scoped builds with `--packages-select <name>` and `--packages-up-to <name>`
  (source: https://colcon.readthedocs.io/en/released/user/quick-start.html, 2026-09-18).

### Tech Stack

| Component | Role | Source |
|---|---|---|
| Python 3.6+ | Host language, entry-point plugin system | https://github.com/colcon/colcon-core/blob/master/setup.cfg, 2026-09-18 |
| `setuptools` | Packaging and entry-point declaration (`setup.cfg`) | https://github.com/colcon/colcon-core/blob/master/setup.cfg, 2026-09-18 |
| Runtime dependencies | `distlib`, `Empy`, `packaging`, `pytest` plus pytest plugins, `setuptools` | https://github.com/colcon/colcon-core/blob/master/setup.cfg, 2026-09-18 |
| `colcon-cmake` | CMake package identification plus CMake build and test tasks | https://github.com/colcon/colcon-cmake/blob/master/setup.cfg, 2026-09-18 |
| `colcon-ros` | ROS package identification and ROS task types | https://github.com/colcon/colcon-ros/blob/master/setup.cfg, 2026-09-18 |
| `catkin_pkg` | ROS manifest parsing, pulled in by `colcon-ros` | https://github.com/colcon/colcon-ros/blob/master/setup.cfg, 2026-09-18 |

A module survey of `colcon_core` (source: https://github.com/colcon/colcon-core/tree/master/colcon_core, 2026-09-18)
shows the engine split into `command.py`, `entry_point.py`, `extension_point.py`, `plugin_system.py`,
`topological_order.py`, `package_descriptor.py`, `package_decorator.py`, `dependency_descriptor.py`,
`subprocess.py`, and the `argument_parser/`, `environment/`, `event/`, `event_handler/`, `executor/`,
`output_style/`, `package_augmentation/`, `package_discovery/`, `package_identification/`,
`package_selection/`, `prefix_path/`, `python_project/`, `shell/`, `task/`, and `verb/` subpackages.

## 3. Feature Overview

### Core Modules

- **`colcon-core`**: the command line entry point, the extension-point registry, package discovery,
  graph ordering, job execution, and environment script generation. It registers the `build` and
  `test` verbs itself (source: https://github.com/colcon/colcon-core/blob/master/setup.cfg, 2026-09-18).
- **`colcon-cmake`**: "An extension for colcon-core to support CMake projects". It registers CMake
  package identification, a CMake build task, a CMake test task, and CMake-specific environment
  handling (`CMAKE_PREFIX_PATH`, `CMAKE_MODULE_PATH`)
  (source: https://github.com/colcon/colcon-cmake, 2026-09-18 and
  https://github.com/colcon/colcon-cmake/blob/master/setup.cfg, 2026-09-18).
- **`colcon-ros`**: "An extension for colcon-core to support ROS packages". It registers four task
  types for building and testing (`ros.ament_cmake`, `ros.ament_python`, `ros.catkin`, `ros.cmake`)
  and two prefix-path providers (`ament`, `catkin`). Its own version is 0.5.0
  (source: https://github.com/colcon/colcon-ros/blob/master/setup.cfg, 2026-09-18 and
  https://github.com/colcon/colcon-ros/blob/master/colcon_ros/__init__.py, 2026-09-18).
- **`colcon-common-extensions`**: "A meta package aggregating colcon-core as well as a set of common
  extensions". Its install list includes `colcon-argcomplete`, `colcon-bash`, `colcon-cd`,
  `colcon-cmake`, `colcon-core`, `colcon-defaults`, `colcon-devtools`, `colcon-library-path`,
  `colcon-metadata`, `colcon-notification`, `colcon-output`, `colcon-package-information`,
  `colcon-package-selection`, `colcon-parallel-executor`, `colcon-powershell`,
  `colcon-python-setup-py`, `colcon-recursive-crawl`, `colcon-ros`, `colcon-test-result`, and
  `colcon-zsh`, with `colcon-override-check` as an optional recommendation
  (source: https://github.com/colcon/colcon-common-extensions/blob/master/setup.cfg, 2026-09-18).

The organization also ships build-system extensions beyond the ROS stack: `colcon-meson` ("Extension
for colcon to support Meson packages") and `colcon-cargo` ("An extension for colcon-core to support
Rust projects built with Cargo"), plus `colcon-parallel-executor` ("Extension for colcon to process
packages in parallel")
(source: https://github.com/orgs/colcon/repositories, 2026-09-18).

### Notable Features

- **Workspace model.** A colcon workspace is conventionally `ws/src`, `ws/build`, `ws/install`, and
  `ws/log`. Builds are always out-of-source, each package gets its own build directory under a single
  `build` base, and a `COLCON_IGNORE` file tells colcon a directory contains no packages
  (source: https://colcon.readthedocs.io/en/released/user/what-is-a-workspace.html, 2026-09-18).
- **Isolated versus merged install.** The default is an isolated workspace where each package is
  installed into `install/<pkg>`. Isolated installs expose a package's tests only to the install
  artifacts of its declared dependencies, which is documented as a way to catch undeclared
  dependencies. `--merge-install` installs everything into one directory, which shortens environment
  variables on platforms with tighter limits such as Windows 10
  (source: https://colcon.readthedocs.io/en/released/user/isolated-vs-merged-workspaces.html, 2026-09-18).
- **Post-build environment scripts.** The install space contains `setup.<ext>` and
  `local_setup.<ext>` scripts for `bash`, `bat`, `ps1`, `sh`, `zsh`, plus `_local_setup_util` helpers.
  Sourcing a workspace sets the environment variables needed to use the built packages
  (source: https://colcon.readthedocs.io/en/released/user/what-is-a-workspace.html, 2026-09-18).
- **Overlay and underlay chaining.** An overlay workspace extends an underlay when it provides new
  packages. Only the last workspace in a chain needs to be sourced, because `setup.<ext>` sources its
  underlays first, while `local_setup.<ext>` sources only the current workspace
  (source: https://colcon.readthedocs.io/en/released/user/using-multiple-workspaces.html, 2026-09-18).
- **External metadata without source edits.** `colcon.pkg` declares `name`, `type`, `dependencies`
  (plus `build-dependencies`, `run-dependencies`, `test-dependencies`), additional `hooks`, and any
  command line argument for a package. `.meta` files carry the same data keyed by package name or
  path. `defaults.yaml` sets default CLI arguments globally at `$COLCON_HOME/defaults.yaml` or per
  workspace at `colcon_defaults.yaml`, with the workspace file overriding the global one
  (source: https://colcon.readthedocs.io/en/released/user/configuration.html, 2026-09-18).
- **Verb surface.** Beyond `build` and `test`, the released docs list `edit`, `graph`, `info`,
  `list`, `metadata`, `mixin`, and `test-result` verbs
  (source: https://colcon.readthedocs.io/en/released/index.html, 2026-09-18).

### Extensibility / Plugin Mechanism

Extensions are Python entry points. `colcon-core` declares its own entry-point groups and consumes
third-party packages that declare the same groups
(source: https://github.com/colcon/colcon-core/blob/master/setup.cfg, 2026-09-18). The registered
extension-point groups are: `colcon_core.argument_parser`, `colcon_core.environment`,
`colcon_core.environment_variable`, `colcon_core.event_handler`, `colcon_core.executor`,
`colcon_core.output_style`, `colcon_core.package_augmentation`, `colcon_core.package_discovery`,
`colcon_core.package_identification`, `colcon_core.package_selection`, `colcon_core.prefix_path`,
`colcon_core.python_testing`, `colcon_core.shell`, `colcon_core.shell.find_installed_packages`,
`colcon_core.task.build`, `colcon_core.task.test`, and `colcon_core.verb`
(source: https://github.com/colcon/colcon-core/blob/master/setup.cfg, 2026-09-18).

Documented semantics of the main groups:

- **VerbExtensionPoint**: each verb extension defines logic invoked by `colcon <verb>` and can add
  verb-specific `argparse` arguments
  (source: https://colcon.readthedocs.io/en/released/developer/extension-point.html, 2026-09-18).
- **PackageDiscoveryExtensionPoint**: used by package discovery to crawl for packages; `colcon-core`
  ships a path-based discovery extension
  (source: https://colcon.readthedocs.io/en/released/developer/extension-point.html, 2026-09-18 and
  https://github.com/colcon/colcon-core/blob/master/setup.cfg, 2026-09-18).
- **PackageIdentificationExtensionPoint**: decides whether a path contains a package and returns
  `path`, `name`, `type`, with priority-ordered, first-success-wins evaluation
  (source: https://colcon.readthedocs.io/en/released/developer/extension-point.html, 2026-09-18).
- **PackageAugmentationExtensionPoint**: adds arbitrary information to a package descriptor after
  discovery and identification, such as additional dependencies
  (source: https://colcon.readthedocs.io/en/released/developer/extension-point.html, 2026-09-18).
- **TaskExtensionPoint**: implements the logic for one verb-and-package-type combination, for example
  building a Python package. Parameters come from a context object and a job object
  (source: https://colcon.readthedocs.io/en/released/developer/extension-point.html, 2026-09-18).
- **ExecutorExtensionPoint**: executes a set of jobs, with the highest-priority executor used by
  default (source: https://colcon.readthedocs.io/en/released/developer/extension-point.html, 2026-09-18).
- **ShellExtensionPoint**: generates setup scripts and environment hooks for a specific shell, with a
  designated primary shell whose logic the others reuse
  (source: https://colcon.readthedocs.io/en/released/developer/extension-point.html, 2026-09-18).
- **EnvironmentExtensionPoint**: creates environment hooks for one environment variable and delegates
  script generation to the shell extensions
  (source: https://colcon.readthedocs.io/en/released/developer/extension-point.html, 2026-09-18).
- **EventHandlerExtensionPoint**: receives build events; `colcon-core` ships console and command-log
  handlers, and `colcon-cmake` ships a `compile_commands` handler
  (source: https://github.com/colcon/colcon-core/blob/master/setup.cfg, 2026-09-18 and
  https://github.com/colcon/colcon-cmake/blob/master/setup.cfg, 2026-09-18).

A dedicated template repository, `colcon/template-package`, exists for creating new extensions
(source: https://github.com/orgs/colcon/repositories, 2026-09-18). Extensions may declare minimum
versions of one another. `colcon-ros` requires `colcon-cmake>=0.2.6` and `colcon-core>=0.7.0`
(source: https://github.com/colcon/colcon-ros/blob/master/setup.cfg, 2026-09-18).

## 4. Status & Ecosystem

| Signal | Value | Source |
|---|---|---|
| `colcon-core` version | 0.21.3, uploaded 2026-09-17 | https://pypi.org/project/colcon-core/, 2026-09-18 |
| Packaging status | `Development Status :: 3 - Alpha` | https://github.com/colcon/colcon-core/blob/master/setup.cfg, 2026-09-18 |
| GitHub Releases on `colcon-core` | none published; the releases page is empty | https://github.com/colcon/colcon-core/releases, 2026-09-18 |
| Stars / forks on `colcon-core` | 133 stars, 60 forks, 74 open issues, 8 open pull requests | https://github.com/orgs/colcon/repositories, 2026-09-18 |
| Organization size | 60 public repositories | https://github.com/orgs/colcon/repositories, 2026-09-18 |
| Most-starred related repos | `colcon-bundle` (39), `colcon-cargo` (38), `colcon-cmake` (18), `colcon-ros` (15) | https://github.com/orgs/colcon/repositories, 2026-09-18 |
| Recent activity | `colcon-core`, `colcon-notification`, `colcon-output` all pushed 2026-09-17 | https://github.com/orgs/colcon/repositories, 2026-09-18 |

**ROS 2 adoption.** The ROS 2 design article records the decision directly: "Based on the above
information a decision has been made to pick colcon as the universal build tool", and "In ROS 2
Bouncy the universal build tool will be the recommended option". The same document records the build
farm and CI updates that follow from that decision
(source: https://design.ros2.org/articles/build_tool.html, written 2017-03, last modified 2021-01).

**ROS 1 and Gazebo.** colcon can build ROS 1 workspaces and Gazebo with its ignition dependencies.
The design article states explicitly that colcon "won't be the recommended build tool in ROS 1 for
the foreseeable future", while migration guides from `catkin_make_isolated` and `catkin_tools` are
published. The quick-start documentation includes sections for building ROS 2 packages, ROS 1
packages, and Gazebo and the ignition packages
(source: https://design.ros2.org/articles/build_tool.html, written 2017-03, last modified 2021-01 and
https://colcon.readthedocs.io/en/released/user/quick-start.html, 2026-09-18).

**Migration surface.** The documentation ships migration guides from `ament_tools`,
`catkin_make_isolated`, and `catkin_tools`, which indicates the tool's role as the successor to the
older ROS build tools (source: https://colcon.readthedocs.io/en/released/index.html, 2026-09-18).

**Ecosystem breadth.** Build-system coverage shipped by the organization includes CMake, ROS
(catkin and ament variants), Python `setup.py`, Meson, and Cargo, plus output, metadata, mixin,
notification, and result-reporting extensions
(source: https://github.com/orgs/colcon/repositories, 2026-09-18).

## 5. Market Positioning

colcon occupies a specific niche that is close to PolyOrch's own positioning but bounded by its ROS
heritage.

- **It is a meta-orchestrator, not a compiler.** The design article's build-tool versus build-system
  distinction puts colcon in the same category as PolyOrch: it owns graph construction, ordering, and
  environment setup, and delegates compilation to per-package build systems
  (source: https://design.ros2.org/articles/build_tool.html, written 2017-03, last modified 2021-01).
- **It is modular by construction.** The design goals state that "colcon-core only bundles Python
  support in order to bootstrap itself" and that support for any build system must be addable by
  extension. It encourages splitting functionality across Python packages to enforce modularity and
  loose coupling (source: https://colcon.readthedocs.io/en/released/developer/design.html, 2026-09-18).
- **It does not aim to be a monorepo-wide build product.** Fetching sources, installing dependencies,
  and producing binary packages are explicitly out of scope
  (source: https://colcon.readthedocs.io/en/released/developer/design.html, 2026-09-18).
- **Its gravity is the ROS ecosystem.** The package model is built around `package.xml`, and the
  richest task types (`ros.ament_cmake`, `ros.ament_python`, `ros.catkin`) are ROS-specific
  (source: https://github.com/colcon/colcon-ros/blob/master/setup.cfg, 2026-09-18). The tool can be
  used outside ROS (the design article calls out Gazebo), but the documented use cases are ROS 1,
  ROS 2, and Gazebo (source: https://design.ros2.org/articles/build_tool.html, 2026-09-18).
- **Competitive set.** For a general polyglot monorepo, colcon competes on ecosystem lock-in rather
  than on remote caching, hermeticity, or cross-language sandboxing. No such capability is documented
  in its own design or extension list
  (source: https://colcon.readthedocs.io/en/released/index.html, 2026-09-18).
- **PolyOrch's differentiation.** PolyOrch's own competitive framing records colcon as a "ROS 2 meta
  build tool" and names PolyOrch's difference as not being bound to the ROS ecosystem, targeting
  general polyglot monorepos while treating colcon as one adapter target
  (source: `docs/derived/competitive-analysis.md`, 2026-09-18).

## 6. Product Highlights

| Highlight | Why it matters | Source |
|---|---|---|
| Extension points at every pipeline stage | Discovery, identification, augmentation, selection, task, executor, shell, environment, and events are all replaceable | https://github.com/colcon/colcon-core/blob/master/setup.cfg, 2026-09-18 |
| Priority-based identification with first-success semantics | Multiple ecosystems can coexist in one workspace without a central dispatcher | https://colcon.readthedocs.io/en/released/developer/extension-point.html, 2026-09-18 |
| Isolated installs by default | Undeclared dependencies surface as test failures rather than silent success | https://colcon.readthedocs.io/en/released/user/isolated-vs-merged-workspaces.html, 2026-09-18 |
| Generated environment scripts | A built workspace becomes usable with one `source install/setup.bash` | https://colcon.readthedocs.io/en/released/user/what-is-a-workspace.html, 2026-09-18 |
| Layered defaults | Global and per-workspace CLI defaults compose cleanly | https://colcon.readthedocs.io/en/released/user/configuration.html, 2026-09-18 |
| Overlay chaining | Independent workspaces can extend one another and be sourced as a chain | https://colcon.readthedocs.io/en/released/user/using-multiple-workspaces.html, 2026-09-18 |
| Proven at ecosystem scale | Adopted as the ROS 2 universal build tool and wired into the ROS build farm | https://design.ros2.org/articles/build_tool.html, 2026-09-18 |

## 7. Value to PolyOrch

colcon is a rare case: it is both a **peer** to PolyOrch (a meta-orchestrator that dispatches to
underlying build systems) and a **dispatch target** (PolyOrch ships a Colcon adapter that invokes
`colcon build` on ROS 2 workspaces). Both relationships inform the buckets below.

### [Adopt] Directly reusable

1. **Adopt the strict build-tool versus build-system boundary.** colcon's documented rule is that the
   orchestrator "should know as little as possible about the build system"
   (source: https://design.ros2.org/articles/build_tool.html, written 2017-03, last modified 2021-01).
   Actionable: PolyOrch's core must never parse `CMakeLists.txt`, `meson.build`, or `xmake.lua`.
   All such knowledge belongs in adapters. This maps directly onto PolyOrch's existing adapter layer
   (source: `docs/architecture.md`, 2026-09-18).
2. **Adopt a uniform pipeline contract with named stages.** colcon's `build` verb runs descriptors,
   topological order, decorator selection, job creation, job execution, and prefix-script creation in
   that order (source: https://colcon.readthedocs.io/en/released/developer/program-flow.html, 2026-09-18).
   Actionable: give PolyOrch the same six named, observable stages so adapters and UI both hook a
   stable lifecycle instead of ad-hoc callbacks.
3. **Adopt priority-ordered, first-success type detection.** colcon runs identification extensions by
   priority, stops at the first success, and warns on equal-priority conflicts
   (source: https://colcon.readthedocs.io/en/released/developer/extension-point.html, 2026-09-18).
   Actionable: PolyOrch's project-type detection (CMake vs Xmake vs Meson vs Colcon) should use
   ordered detectors with deterministic tie-breaking, and must log which detector claimed a package.
4. **Adopt external metadata as a first-class input.** `colcon.pkg`, `.meta`, and `defaults.yaml`
   let users correct or extend build behavior without editing sources
   (source: https://colcon.readthedocs.io/en/released/user/configuration.html, 2026-09-18).
   Actionable: PolyOrch's `polyorch.toml` should support per-package overrides and global plus
   workspace-scoped defaults, mirroring colcon's two-tier default resolution.
5. **Adopt isolated packaging as the default workspace layout.** Isolated installs are the documented
   way to catch undeclared dependencies
   (source: https://colcon.readthedocs.io/en/released/user/isolated-vs-merged-workspaces.html, 2026-09-18).
   Actionable: default PolyOrch to per-package artifact trees, expose a merged mode only as an
   explicit opt-in for platforms with environment-variable length limits.
6. **Adopt post-build environment materialization as a build artifact.** colcon emits `setup.<ext>`
   and `local_setup.<ext>` scripts per shell
   (source: https://colcon.readthedocs.io/en/released/user/what-is-a-workspace.html, 2026-09-18).
   Actionable: every PolyOrch build should emit a machine-readable environment manifest plus a shell
   projection, so downstream packages and tooling consume one consistent environment description.
7. **Adopt the meta-package distribution pattern.** `colcon-common-extensions` aggregates core plus
   the common extension set in one installable unit
   (source: https://github.com/colcon/colcon-common-extensions/blob/master/setup.cfg, 2026-09-18).
   Actionable: ship a PolyOrch bundle that pulls the stable adapter set, so users get CMake, Xmake,
   Meson, and Colcon adapters without enumerating packages.
8. **Adopt an extension template repository.** `colcon/template-package` exists to scaffold new
   extensions (source: https://github.com/orgs/colcon/repositories, 2026-09-18). Actionable: provide
   a PolyOrch adapter template with the manifest, registration, and test harness pre-wired.
9. **Adopt overlay semantics as vocabulary.** colcon distinguishes overlay, underlay, extending, and
   overriding (source: https://colcon.readthedocs.io/en/released/user/using-multiple-workspaces.html, 2026-09-18).
   Actionable: PolyOrch's multi-root composition model should use the same precise terms instead of
   inventing new ones.

### [Adapt] Reusable with modification

1. **Adapt the extension-point registry to PolyOrch's own plugin mechanism.** colcon uses Python
   entry points because its host language is Python
   (source: https://design.ros2.org/articles/build_tool.html, written 2017-03, last modified 2021-01).
   PolyOrch's own implementation language is **Lua**, shipped as an Xmake addon (see `decisions.md` D3, 2026-09-20).
   Actionable: keep colcon's registry semantics (named groups, priority, first-success) but make the
   registration format language-neutral, such as adapter manifest files, so a Python-only plugin host
   is not baked into PolyOrch.
2. **Adapt event handlers to structured telemetry.** colcon's event handlers include console output
   and command logging, with output style as a separate extension point
   (source: https://github.com/colcon/colcon-core/blob/master/setup.cfg, 2026-09-18). Actionable:
   PolyOrch should emit build events as structured records consumed by the CLI, logs, and any
   dashboard, rather than letting extensions own console formatting.
3. **Adapt package augmentation to graph enrichment.** colcon augmentation adds fields such as extra
   dependencies to a descriptor
   (source: https://colcon.readthedocs.io/en/released/developer/extension-point.html, 2026-09-18).
   Actionable: in PolyOrch, use an equivalent pass to attach cross-ecosystem edges (a Cargo
   dependency of a package that is otherwise CMake) into the orchestration graph, without mutating
   the package's own manifest.
4. **Adapt executor extension selection.** colcon picks the highest-priority executor by default
   (source: https://colcon.readthedocs.io/en/released/developer/extension-point.html, 2026-09-18).
   Actionable: PolyOrch should expose a chosen scheduling policy in `polyorch.toml` and report the
   resolved policy, so priority is a default rather than an invisible decision.
5. **Adapt shell and environment extensions to Pixi-based environments.** colcon generates scripts for
   `sh`, `bash`, `zsh`, `bat`, and `ps1`
   (source: https://colcon.readthedocs.io/en/released/index.html, 2026-09-18). PolyOrch instead uses
   Pixi for environments. Actionable: keep colcon's idea of per-shell projection but make the
   environment source a Pixi environment, and generate shell scripts only as one projection of it.
6. **Adapt the `colcon.pkg` / `package.xml` manifests as translation inputs for the Colcon adapter.**
   Since PolyOrch only dispatches to colcon, it needs to read `package.xml` to build the outer graph,
   not to replace colcon's own discovery. Actionable: the Colcon adapter should parse enough of
   `package.xml` to place the workspace as a node in PolyOrch's graph, then delegate all per-package
   work to `colcon build`.
7. **Adapt overlay sourcing to PolyOrch's build ordering.** colcon's `setup.<ext>` transitively sources
   underlays while `local_setup.<ext>` does not
   (source: https://colcon.readthedocs.io/en/released/user/using-multiple-workspaces.html, 2026-09-18).
   Actionable: PolyOrch should compute its own explicit overlay chain and materialize a chain-aware
   environment, rather than depending on the user's shell sourcing order.
8. **Adapt versioned extension dependencies to adapter capability negotiation.** `colcon-ros` requires
   `colcon-cmake>=0.2.6` and `colcon-core>=0.7.0`
   (source: https://github.com/colcon/colcon-ros/blob/master/setup.cfg, 2026-09-18). Actionable:
   PolyOrch adapters should declare required core capabilities and peer adapter capabilities, and the
   core should fail fast with a clear message when they are unmet.
9. **Adapt the verb model to a smaller, PolyOrch-shaped verb set.** colcon ships `build`, `test`,
   `list`, `graph`, `info`, `edit`, `metadata`, `mixin`, and `test-result`
   (source: https://colcon.readthedocs.io/en/released/index.html, 2026-09-18). Actionable: PolyOrch
   should map these to its own CLI verbs, keeping `graph` and `list` inspection verbs because they
   are the cheapest way to debug a graph.
10. **Adapt scope flags.** colcon's `--packages-select` and `--packages-up-to` select one package or a
    package plus its recursive dependencies
    (source: https://colcon.readthedocs.io/en/released/user/quick-start.html, 2026-09-18).
    Actionable: PolyOrch should offer the same two scoping primitives for selective and
    dependency-closure builds.

### [Avoid] Known pitfalls / not applicable

1. **Avoid describing colcon as a build system.** Its own design article separates the build tool
   from the build system, and PolyOrch's Colcon adapter invokes `colcon build`, which is a dispatch,
   not a compile (source: https://design.ros2.org/articles/build_tool.html, written 2017-03, last
   modified 2021-01). Actionable: keep the "meta" qualifier in PolyOrch docs and code identifiers
   (`ColconAdapter`, not `ColconBuildSystem`).
2. **Avoid inheriting ROS coupling.** colcon's package model centers on `package.xml`, and its
   richest task types are ROS-specific
   (source: https://github.com/colcon/colcon-ros/blob/master/setup.cfg, 2026-09-18). PolyOrch's stated
   differentiation is not being bound to the ROS ecosystem
   (source: `docs/derived/competitive-analysis.md`, 2026-09-18).
   Actionable: the Colcon adapter must not leak `package.xml`, ament, or catkin assumptions into the
   PolyOrch core graph or config schema.
3. **Avoid treating colcon as a dependency or artifact manager.** Fetching sources, installing
   dependencies, and creating binary packages are explicitly out of scope for colcon
   (source: https://colcon.readthedocs.io/en/released/developer/design.html, 2026-09-18). Actionable:
   PolyOrch must keep Pixi, vcpkg, and Conan responsible for environment and dependency resolution,
   and not expect colcon to do it.
4. **Avoid assuming colcon provides a remote cache or remote execution.** No such capability appears
   in the design goals, the extension-point list, or the released verb list
   (source: https://colcon.readthedocs.io/en/released/index.html, 2026-09-18). Actionable: PolyOrch
   must own any caching or remote-execution feature, and should not advertise colcon as a cache layer.
5. **Avoid shell sourcing as the only environment activation path.** colcon's environment changes
   require a sourced script because a child process cannot modify its parent's environment, and the
   merged-install mode exists specifically to work around Windows environment-variable length limits
   (source: https://colcon.readthedocs.io/en/released/developer/environment.html, 2026-09-18 and
   https://colcon.readthedocs.io/en/released/user/isolated-vs-merged-workspaces.html, 2026-09-18).
   Actionable: PolyOrch should make its environment manifest the primary interface and treat shell
   scripts as a convenience projection, so non-POSIX and IDE-driven consumers are not second class.
6. **Avoid the removed "devel space" concept.** colcon "does by design not support the concept of a
   devel space as it exists in ROS 1" and requires each package to declare an install step
   (source: https://colcon.readthedocs.io/en/released/user/quick-start.html, 2026-09-18). Actionable:
   PolyOrch should not model an in-place development tree that skips installation, and should require
   packages to state their outputs.
7. **Avoid reading "Alpha" status as a stability promise.** `colcon-core` declares
   `Development Status :: 3 - Alpha` and publishes no GitHub Releases, distributing through PyPI and
   Debian packages instead
   (source: https://github.com/colcon/colcon-core/blob/master/setup.cfg, 2026-09-18 and
   https://github.com/colcon/colcon-core/releases, 2026-09-18). Actionable: PolyOrch should pin the
   colcon versions it is tested against in adapter metadata instead of assuming semantic-version
   stability from an alpha package.
8. **Avoid requiring a manifest to identify a package.** colcon can infer package names and
   dependencies when no manifest is present
   (source: https://design.ros2.org/articles/build_tool.html, written 2017-03, last modified 2021-01).
   Actionable: PolyOrch's Colcon adapter should handle manifest-less workspaces rather than failing
   discovery, and should record how the package was identified.
9. **Avoid mirroring colcon's out-of-scope gaps silently.** Because colcon declines packaging and
    dependency installation, those responsibilities fall on PolyOrch
    (source: https://colcon.readthedocs.io/en/released/developer/design.html, 2026-09-18). Actionable:
    PolyOrch's roadmap should state explicitly that packaging and dependency provisioning are
    PolyOrch-side (via Pixi, vcpkg, and Conan) and not delegated to the Colcon adapter.

## Appendix

### A. Entry-point groups registered by `colcon-core` (deep dive)

| Group | Shipped implementations |
|---|---|
| `colcon_core.environment` | `path`, `pythonpath`, `pythonscriptspath` |
| `colcon_core.event_handler` | `console_direct`, `console_start_end`, `log_command` |
| `colcon_core.executor` | `sequential` |
| `colcon_core.package_augmentation` | `python` |
| `colcon_core.package_discovery` | `path` |
| `colcon_core.package_identification` | `ignore`, `python` |
| `colcon_core.prefix_path` | `colcon` |
| `colcon_core.python_testing` | `pytest`, `setuppy_test` |
| `colcon_core.shell` | `bat`, `dsv`, `sh` |
| `colcon_core.shell.find_installed_packages` | `colcon_isolated`, `colcon_merged` |
| `colcon_core.task.build` | `python` |
| `colcon_core.task.test` | `python` |
| `colcon_core.verb` | `build`, `test` |
| `console_scripts` | `colcon` |

(source: https://github.com/colcon/colcon-core/blob/master/setup.cfg, 2026-09-18)

The `find_installed_packages` implementations `colcon_isolated` and `colcon_merged` correspond
directly to the isolated and merged install layouts
(source: https://colcon.readthedocs.io/en/released/user/isolated-vs-merged-workspaces.html, 2026-09-18).

### B. Package types contributed by `colcon-ros` (deep dive)

`colcon-ros` registers build and test task types `ros.ament_cmake`, `ros.ament_python`, `ros.catkin`,
and `ros.cmake`, plus prefix-path providers `ament` and `catkin` and an ament installed-package
finder (source: https://github.com/colcon/colcon-ros/blob/master/setup.cfg, 2026-09-18). This is the
concrete meaning of "colcon supports ROS packages": the core has no ROS knowledge, and all four ROS
package kinds enter through the same task extension point as any other build system.
