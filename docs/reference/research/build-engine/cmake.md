# CMake Profile

> Sources: https://cmake.org/, https://cmake.org/download/, https://gitlab.kitware.com/cmake/cmake (canonical upstream), https://github.com/Kitware/CMake (GitHub mirror), https://cmake.org/cmake/help/latest/ (CMake 4.4.3 documentation). Researched 2026-09-18.
> Not a derived document: facts here are externally sourced.

**Repository disambiguation.** CMake's canonical upstream repository is hosted on GitLab at `gitlab.kitware.com/cmake/cmake`. The repository at `github.com/Kitware/CMake` is a mirror: its own metadata describes it as "Mirror of CMake upstream repository" and points its homepage at the GitLab URL (source: https://api.github.com/repos/Kitware/CMake, 2026-09-18). The official download page links its file tables into the GitLab `master` branch, reinforcing GitLab as authoritative (source: https://cmake.org/download/, 2026-09-18). Treat GitLab as the source of record and GitHub as a read-only replica for cloning and release artifact retrieval.

## 1. Product Profile

| Field | Value |
|---|---|
| Name | CMake |
| Maintainer | Kitware, Inc. and Contributors; documentation copyright reads "2000-2026 Kitware, Inc. and Contributors" (source: https://cmake.org/cmake/help/latest/, 2026-09-18) |
| Category | Cross-platform build system generator, plus test (CTest) and packaging (CPack) tools |
| Latest stable | 4.4.3, published 2026-08-25 (source: https://cmake.org/download/ and https://api.github.com/repos/Kitware/CMake/releases/latest, 2026-09-18) |
| Previous stable | 4.3.5 (source: https://cmake.org/download/, 2026-09-18) |
| License | BSD-3-Clause, license file `LICENSE.rst` (source: https://api.github.com/repos/Kitware/CMake/license, 2026-09-18) |
| Implementation language | C/C++; the GitHub repository reports "C" as the primary language (source: https://api.github.com/repos/Kitware/CMake, 2026-09-18) |
| Canonical repository | `https://gitlab.kitware.com/cmake/cmake` (source: https://cmake.org/download/, 2026-09-18) |
| Mirror | `https://github.com/Kitware/CMake` (source: https://api.github.com/repos/Kitware/CMake, 2026-09-18) |
| Default branch | `master` (source: https://api.github.com/repos/Kitware/CMake, 2026-09-18) |
| Configuration files | `CMakeLists.txt` (project build description) and `CMakePresets.json` / `CMakeUserPresets.json` (source: https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html, 2026-09-18) |
| State file | `CMakeCache.txt`, created on the first configure run in an empty build tree and populated with customizable settings (source: https://cmake.org/cmake/help/latest/manual/cmake.1.html, 2026-09-18) |
| Command-line entry points | `cmake`, `ctest`, `cpack`; graphical `cmake-gui` and `ccmake` (source: https://cmake.org/cmake/help/latest/manual/cmake.1.html, 2026-09-18) |
| Documentation | https://cmake.org/cmake/help/latest/ (rendered for 4.4.3) |

The project describes itself as "A Powerful Software Build System" and positions CMake around cross-platform C++ building (source: https://cmake.org/, 2026-09-18). The documentation defines it more precisely as "the command-line interface of the cross-platform buildsystem generator CMake" (source: https://cmake.org/cmake/help/latest/manual/cmake.1.html, 2026-09-18).

**What CMake is.** CMake is the front half of a build: it turns a project description written in the CMake language into a native build system, then provides a uniform CLI to build, install, test, and package that project regardless of the native tool underneath.

**What CMake is not.** It is not a compiler, not a package manager, and not a workspace-level scheduler. Dependency acquisition is delegated to `find_package`, `FetchContent`, `ExternalProject`, toolchain files, or an external package manager (source: https://cmake.org/cmake/help/latest/command/find_package.html and https://cmake.org/cmake/help/latest/module/FetchContent.html, 2026-09-18). Incremental execution is delegated to the generated native build system once `cmake --build` hands off (source: https://cmake.org/cmake/help/latest/manual/cmake.1.html, 2026-09-18).

Distributions are published as binaries and source archives and include CTest and CPack as part of the release (source: https://cmake.org/download/, 2026-09-18).

## 2. Technical Characteristics

### Overall Architecture

CMake is a **build system generator**, not a build tool. The documented workflow has distinct stages:

1. **Configure and generate.** CMake reads `CMakeLists.txt` files and produces a native build system in a binary directory, for example Makefiles, Ninja files, or an IDE project. The canonical invocation is `cmake [<options>] -B <path-to-build> [-S <path-to-source>]`, and the older form `cmake [<options>] <path-to-source | path-to-existing-build>` is also documented. `-S` names the root source directory and `-B` names the build directory, which CMake creates if absent (source: https://cmake.org/cmake/help/latest/manual/cmake.1.html, 2026-09-18).
2. **Build.** `cmake --build <dir> [<options>] [-- <build-tool-options>]` abstracts the native build tool's command line, so callers do not invoke `make` or `ninja` directly. A preset form `cmake --build [<dir>] --preset <preset> [<options>]` is also documented, and since 4.3 a build directory and preset may be specified together; since 4.4, `--build <dir> --preset` no longer needs to run from the directory containing the presets files (source: https://cmake.org/cmake/help/latest/manual/cmake.1.html, 2026-09-18).
3. **Install.** `cmake --install <dir> [<options>]` runs the install rules without going through the generated build system. Options include `--config`, `--component` (multiple components supported as of 4.4), `--prefix`, and `--default-directory-permissions` (source: https://cmake.org/cmake/help/latest/manual/cmake.1.html, 2026-09-18).
4. **Test and package.** `ctest` runs tests and `cpack` produces installers and source packages; both are separate executables documented alongside `cmake` (source: https://cmake.org/cmake/help/latest/manual/cmake.1.html, 2026-09-18).

The **generator** is the abstraction seam. CMake supports command-line build tool generators (Makefile generators, Ninja generators, a FASTBuild generator) and IDE build tool generators (Visual Studio generators, Xcode, and others); IDE generators are documented as configuring their own environment, so CMake may be launched from any environment when they are used (source: https://cmake.org/cmake/help/latest/manual/cmake-generators.7.html, 2026-09-18). Generator selection is controlled by `-G <generator-name>`; if no generator is supplied, CMake checks the `CMAKE_GENERATOR` environment variable (added 3.15) and otherwise falls back to a builtin default. Some generators additionally accept `-T <toolset-spec>` and `-A <platform-name>` (source: https://cmake.org/cmake/help/latest/manual/cmake.1.html and https://cmake.org/cmake/help/latest/envvar/CMAKE_GENERATOR.html, 2026-09-18).

The **file API** is the machine-readable seam for tooling. It lives in `<build>/.cmake/api/v1/`, with a `query/` directory written by clients and a `reply/` directory written by CMake; clients read replies only when referenced by an `index-*.json` reply index, and CMake owns all reply files (source: https://cmake.org/cmake/help/latest/manual/cmake-file-api.7.html, 2026-09-18).

Cache configuration is part of the configure contract. `-D <var>:<type>=<value>` creates or updates a cache entry, and `-C <initial-cache>` pre-loads a script that populates cache entries before the first pass through the project's list files, with loaded entries taking priority over project defaults (source: https://cmake.org/cmake/help/latest/manual/cmake.1.html, 2026-09-18).

### Key Capabilities

- **Platform-independent build description.** The CMake language organizes content as directories, scripts, and modules, with command invocations, bracket/quoted/unquoted arguments, escape sequences, variable references, comments, control structures, and lists. All values are stored as strings, and lists are semicolon-separated within a single string (source: https://cmake.org/cmake/help/latest/manual/cmake-language.7.html, 2026-09-18).
- **Targets with transitive usage requirements.** `add_executable()` and `add_library()` define binary targets, including `STATIC`, `SHARED`, `MODULE`, `OBJECT`, and `INTERFACE` libraries. `target_link_libraries()` accepts `PRIVATE`, `INTERFACE`, and `PUBLIC` to control propagation of transitive compile and link properties such as `INTERFACE_LINK_LIBRARIES` (source: https://cmake.org/cmake/help/latest/manual/cmake-buildsystem.7.html, 2026-09-18).
- **Alias targets for naming consistency.** `add_library(<name> ALIAS <target>)` creates a read-only alternate name; the documented pattern is to install and export with a namespace, then define an alias so downstreams can link to `Upstream::lib1` whether it comes from `find_package` or the same build. Alias targets are not mutable, installable, or exportable (source: https://cmake.org/cmake/help/latest/manual/cmake-buildsystem.7.html, 2026-09-18).
- **Build configurations.** CMake defines the standard configurations `Debug`, `Release`, `RelWithDebInfo`, and `MinSizeRel`. For single-configuration generators the configuration is set at configure time by `CMAKE_BUILD_TYPE` and cannot change at build time; its default is often an empty string, which is not the same as `Debug`. For multi-configuration generators the available set is given by `CMAKE_CONFIGURATION_TYPES`, and the actual configuration is chosen at build time while `CMAKE_BUILD_TYPE` is ignored. String comparisons against these variables are case-sensitive (source: https://cmake.org/cmake/help/latest/manual/cmake-buildsystem.7.html, 2026-09-18).
- **Presets as a machine-readable build contract.** `CMakePresets.json` is a versioned JSON document with a root `version`, an optional `cmakeMinimumRequired`, `include`, and `vendor`, and arrays `configurePresets`, `buildPresets`, `testPresets`, `packagePresets`, and `workflowPresets` (source: https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html, 2026-09-18).
- **Toolchain files for cross compiling.** Toolchain files set `CMAKE_SYSTEM_NAME` and language compilers; the CLI `--toolchain <path-to-file>` option (added 3.21) is equivalent to setting `CMAKE_TOOLCHAIN_FILE`, and the `toolchainFile` preset field (presets version 3, CMake 3.21) provides the same via presets. Documented target families include Android, iOS/tvOS/visionOS/watchOS, Windows Phone, and Emscripten (source: https://cmake.org/cmake/help/latest/manual/cmake-toolchains.7.html and https://cmake.org/cmake/help/latest/manual/cmake.1.html, 2026-09-18).
- **Install, export, and import.** `install(TARGETS ... EXPORT <name>)` associates targets with an export set, and `install(EXPORT <name> NAMESPACE <ns> DESTINATION <dir>)` writes an import file for the install tree; `export(TARGETS)` and `export(EXPORT)` write build-tree import files instead (source: https://cmake.org/cmake/help/latest/command/install.html and https://cmake.org/cmake/help/latest/command/export.html, 2026-09-18).
- **Package discovery.** `find_package()` has Module mode, which searches `Find<PackageName>.cmake` on `CMAKE_MODULE_PATH` and among CMake's bundled Find Modules, and Config mode, which searches for package configuration files such as `<PackageName>Config.cmake`; the basic signature tries Module first and falls back to Config, while the full signature searches only Config mode. Since 3.24, every call also first consults `CMAKE_FIND_PACKAGE_REDIRECTS_DIR` (source: https://cmake.org/cmake/help/latest/command/find_package.html, 2026-09-18).
- **Version compatibility policy.** `cmake_minimum_required(VERSION <min>[...<policy_max>])` sets the policy version and errors if the running CMake is older than `<min>`; it also implicitly invokes `cmake_policy(VERSION ...)`, and policies introduced at or before the policy version default to NEW behavior (source: https://cmake.org/cmake/help/latest/command/cmake_minimum_required.html, 2026-09-18).
- **Dependency acquisition.** `FetchContent` populates content at configure time and `FetchContent_MakeAvailable()` adds it to the build; `ExternalProject_Add()` downloads at build time; `add_subdirectory()` and `include()` consume content directly. `FetchContent_Declare()` is first-call-wins, and later calls for the same content name are ignored (source: https://cmake.org/cmake/help/latest/module/FetchContent.html and https://cmake.org/cmake/help/latest/module/ExternalProject.html, 2026-09-18).
- **Testing and packaging.** CTest runs tests with `--test-dir`, parallel `-j`, and test presets; CPack generates installers and source packages from `CPackConfig.cmake` using per-format generators selected by `-G` or `CPACK_GENERATOR` (source: https://cmake.org/cmake/help/latest/manual/ctest.1.html and https://cmake.org/cmake/help/latest/manual/cpack.1.html, 2026-09-18).
- **Diagnostics as a managed subsystem.** CMake 4.4 tracks diagnostic actions in a state type managed by `cmake_diagnostic()`, with categories documented in `cmake-diagnostics(7)`; `CMD_INSTALL_ABSOLUTE_DESTINATION` is one such category and can be controlled by `-Winstall-absolute-destination` or a preset `warnings` object (source: https://cmake.org/cmake/help/latest/release/4.4.html, 2026-09-18).
- **Instrumentation.** `cmake-instrumentation(7)` provides timing and trace data; its data version was updated to 1.1 in 4.4, and 4.4 added `captureOutput` for stdout/stderr of instrumented commands and `compileTrace` for compiler-generated trace files such as Clang `-ftime-trace` (source: https://cmake.org/cmake/help/latest/release/4.4.html, 2026-09-18).
- **Multi-language projects.** Languages are enabled by `project()` or `enable_language()`; C and CXX are enabled by default, and `NONE` enables no languages (source: https://cmake.org/cmake/help/latest/manual/cmake-toolchains.7.html, 2026-09-18). CMake 4.4 adds CUDA language level 23 with NVCC 13.3 and above, and C++ 20 named modules with `clang-cl` except under Visual Studio generators (source: https://cmake.org/cmake/help/latest/release/4.4.html, 2026-09-18).

### Tech Stack

| Layer | Technology |
|---|---|
| Implementation | C/C++ (source: https://api.github.com/repos/Kitware/CMake, 2026-09-18) |
| Build description language | The CMake language, organized as command invocations with quoted and unquoted arguments, variable references, control structures, and generator expressions (source: https://cmake.org/cmake/help/latest/manual/cmake-language.7.html, 2026-09-18) |
| Configuration data | JSON: `CMakePresets.json` and the file API reply files, both with documented schemas (source: https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html and https://cmake.org/cmake/help/latest/manual/cmake-file-api.7.html, 2026-09-18) |
| Native generators | Makefile generators, Ninja generators, FASTBuild, Visual Studio generators, Xcode (source: https://cmake.org/cmake/help/latest/manual/cmake-generators.7.html, 2026-09-18) |
| Testing and packaging | CTest and CPack (source: https://cmake.org/cmake/help/latest/manual/ctest.1.html and https://cmake.org/cmake/help/latest/manual/cpack.1.html, 2026-09-18) |
| Helper modules | `GNUInstallDirs`, `CMakePackageConfigHelpers`, `CMakeFindDependencyMacro`, `GenerateExportHeader` (source: https://cmake.org/cmake/help/latest/manual/cmake-modules.7.html, 2026-09-18) |

## 3. Feature Overview

### Core Modules

- **`cmake` executable.** Actions documented in the synopsis: generate a build system, build a project, install a project, open a project (`cmake --open <dir>`, supported only by some generators), run a script (`-P`), run a command-line tool (`-E`), run the find-package tool, run a workflow preset, and view help (source: https://cmake.org/cmake/help/latest/manual/cmake.1.html, 2026-09-18).
- **The CMake language runtime and policy engine.** Directories, scripts, and modules form the language's organization; `cmake_minimum_required()` and `cmake_policy()` control which policies use NEW behavior; all policies introduced up to the policy version are set to NEW (source: https://cmake.org/cmake/help/latest/manual/cmake-language.7.html and https://cmake.org/cmake/help/latest/command/cmake_minimum_required.html, 2026-09-18).
- **Bundled modules.** Examples documented in the manuals: `FetchContent`, `ExternalProject`, `GNUInstallDirs`, `CMakePackageConfigHelpers`, `CMakeFindDependencyMacro`, `GenerateExportHeader`, and the Find Modules used in Module mode (source: https://cmake.org/cmake/help/latest/manual/cmake-modules.7.html, 2026-09-18).
- **CTest.** Test runner with run-tests, build-and-test, dashboard-client, and script modes; `ctest --test-dir <path-to-build>` selects the build tree (source: https://cmake.org/cmake/help/latest/manual/ctest.1.html, 2026-09-18).
- **CPack.** Packaging program with per-format generators, steered by `CPackConfig.cmake`; `-G` selects a semicolon-separated generator list and `-C` selects configurations for multi-config builds (source: https://cmake.org/cmake/help/latest/manual/cpack.1.html, 2026-09-18).
- **File API.** Versioned JSON query/reply protocol for IDEs and external tools; user-wide queries can be placed in `api/v1/query` under `CMAKE_CONFIG_DIR` as of 3.31 (source: https://cmake.org/cmake/help/latest/manual/cmake-file-api.7.html, 2026-09-18).
- **Diagnostics and instrumentation.** `cmake-diagnostics(7)` catalogs diagnostic categories, and `cmake-instrumentation(7)` exposes build instrumentation data (source: https://cmake.org/cmake/help/latest/release/4.4.html, 2026-09-18).
- **Graphical and text front ends.** `cmake-gui` and `ccmake` (source: https://cmake.org/cmake/help/latest/manual/cmake.1.html, 2026-09-18).

### Notable Features

- **Preset inheritance, macros, and conditions.** Presets support `inherits`, `${sourceDir}`, `${hostSystemName}`, and other macros, plus a `condition` object (presets version 3) that can gate availability such as Windows-only presets (source: https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html, 2026-09-18).
- **Workflow presets.** Added in presets version 6 (CMake 3.25), a workflow preset chains a configure step followed by build, test, or package steps whose `configurePreset` matches; it is run with `cmake --workflow --preset <name>` (source: https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html and https://cmake.org/cmake/help/latest/manual/cmake.1.html, 2026-09-18).
- **Relocatable install destinations.** `GNUInstallDirs` defines `CMAKE_INSTALL_<dir>` values such as `CMAKE_INSTALL_BINDIR` and `CMAKE_INSTALL_LIBDIR`, intended to be relative to the prefix so they convert to absolute paths in a relocatable way. Absolute `DESTINATION` paths do not work with `cmake --install --prefix` or with CPack installer generators, and 4.4 adds the `CMD_INSTALL_ABSOLUTE_DESTINATION` diagnostic to warn or error on them (source: https://cmake.org/cmake/help/latest/module/GNUInstallDirs.html and https://cmake.org/cmake/help/latest/command/install.html, 2026-09-18).
- **Build-tree versus install-tree exports.** `export(TARGETS)` / `export(EXPORT)` produce files specific to the build tree that should never be installed; `install(EXPORT)` produces the install-tree import file. Build-tree export files are documented as not relocatable (source: https://cmake.org/cmake/help/latest/command/export.html, 2026-09-18).
- **Config package version files.** `write_basic_package_version_file()` from `CMakePackageConfigHelpers` generates a version file read by `find_package()` to decide compatibility and set `<PackageName>_VERSION*` variables; documented compatibility modes include `AnyNewerVersion` (source: https://cmake.org/cmake/help/latest/guide/importing-exporting/index.html, 2026-09-18).
- **Common Package Specification (CPS).** Added in 4.3, `install(PACKAGE_INFO <name> EXPORT <export-name> ...)` installs a CPS file exporting targets for dependent projects, and `export(PACKAGE_INFO ...)` produces the build-tree equivalent with imported targets implicitly in the package-name namespace (source: https://cmake.org/cmake/help/latest/command/install.html and https://cmake.org/cmake/help/latest/command/export.html, 2026-09-18).
- **File sets.** Sources may be assigned to file sets such as `HEADERS`, and the codemodel reply exposes `fileSets` plus `fileSetIndexes` for targets (source: https://cmake.org/cmake/help/latest/manual/cmake-file-api.7.html, 2026-09-18).
- **Parallel installation.** Since 3.31, projects can enable the `INSTALL_PARALLEL` global property; subdirectories added by `add_subdirectory()` then install independently and cross-subdirectory ordering is not guaranteed (source: https://cmake.org/cmake/help/latest/command/install.html, 2026-09-18).
- **Install copying behavior.** Since 3.22, the `CMAKE_INSTALL_MODE` environment variable can override the default copying behavior of `install()`, for example to symlink instead of copy (source: https://cmake.org/cmake/help/latest/command/install.html, 2026-09-18).
- **Job server integration.** Custom steps can declare `JOB_SERVER_AWARE <bool>` (added 3.28), ExternalProject install steps can declare `INSTALL_JOB_SERVER_AWARE <bool>` (added 4.0), and CTest participates in job server integration when parallelism is unrestricted (source: https://cmake.org/cmake/help/latest/module/ExternalProject.html and https://cmake.org/cmake/help/latest/manual/ctest.1.html, 2026-09-18).
- **Machine-readable version banner.** `cmake --version=json-v1` prints extended version information as JSON, described by a published JSON schema (source: https://cmake.org/cmake/help/latest/manual/cmake.1.html, 2026-09-18).
- **Keyword help from the CLI.** `cmake --help <keyword>` prints the manual entry for a property, variable, command, policy, generator, or module, with dedicated variants such as `--help-policy` and `--help-property` (source: https://cmake.org/cmake/help/latest/manual/cmake.1.html, 2026-09-18).

### Extensibility / Plugin Mechanism

CMake has no conventional plugin registry. Extensibility is achieved through the language and documented protocols:

- **Functions and macros** defined in `CMakeLists.txt` or included `.cmake` files; the file API `cmakeFiles` object kind lists `CMakeLists.txt` files and included `.cmake` files (source: https://cmake.org/cmake/help/latest/manual/cmake-file-api.7.html, 2026-09-18).
- **Bundled Find Modules and project-provided find modules** on `CMAKE_MODULE_PATH` for Module-mode discovery (source: https://cmake.org/cmake/help/latest/command/find_package.html, 2026-09-18).
- **Generator expressions** such as `$<TARGET_OBJECTS:name>` and `$<CONFIG>`, which let target definitions compute values that depend on the build configuration. `$<CONFIG>` preserves the casing of the configuration as set by the user or CMake defaults (source: https://cmake.org/cmake/help/latest/manual/cmake-buildsystem.7.html, 2026-09-18).
- **The `vendor` field** in presets, reserved by domain-name key for vendor-specific data such as IDE settings, which CMake stores without interpreting except to verify that it is a map (source: https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html, 2026-09-18).
- **Cache variables** (`-D<var>=<value>`, `-C <initial-cache>`, and preset `cacheVariables` with a typed `BOOL` form shown in the documentation) as the primary external configuration surface (source: https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html and https://cmake.org/cmake/help/latest/manual/cmake.1.html, 2026-09-18).
- **The file API** as the integration protocol for IDEs and external build tooling, including the IDE Integration Guide (source: https://cmake.org/cmake/help/latest/guide/ide-integration/index.html, 2026-09-18).
- **Diagnostics control** through `cmake_diagnostic()`, the `-W` command-line family, and preset `warnings` objects, which lets tooling tune reporting without editing project files (source: https://cmake.org/cmake/help/latest/release/4.4.html, 2026-09-18).

## 4. Status & Ecosystem

CMake is on a mature, fast-moving release line. The latest stable release is 4.4.3, published 2026-08-25, with 4.3.5 as the previous stable release (source: https://cmake.org/download/ and https://api.github.com/repos/Kitware/CMake/releases/latest, 2026-09-18). Release notes are published for 4.4 down to 3.0 (source: https://cmake.org/cmake/help/latest/release/index.html, 2026-09-18).

Recent compatibility-relevant changes:

- **4.0** removed compatibility with CMake versions older than 3.5: calls to `cmake_minimum_required()` or `cmake_policy()` that set an older policy version now issue an error, though the `VERSION <min>...<max>` syntax still allows supporting older CMake while setting newer policies (source: https://cmake.org/cmake/help/latest/release/4.0.html, 2026-09-18).
- **4.3** added `install(PACKAGE_INFO)` / `export(PACKAGE_INFO)` for CPS, and permitted a build directory together with `--preset` on `cmake --build` (source: https://cmake.org/cmake/help/latest/command/install.html and https://cmake.org/cmake/help/latest/manual/cmake.1.html, 2026-09-18).
- **4.4** relaxed preset file lookup: `cmake --build <dir> --preset` no longer requires the current directory to contain presets, `--presets-file` was added, workflow presets no longer strictly require presets files in the top-level source directory, `--component` accepts multiple components, CUDA level 23 is supported with NVCC 13.3 and above, and C++ 20 named modules work with `clang-cl` outside Visual Studio generators (source: https://cmake.org/cmake/help/latest/manual/cmake.1.html and https://cmake.org/cmake/help/latest/release/4.4.html, 2026-09-18).
- **4.4 diagnostics and instrumentation** introduced the `cmake_diagnostic()` state model, the `CMD_INSTALL_ABSOLUTE_DESTINATION` category, instrumentation data version 1.1, `captureOutput`, and `compileTrace` (source: https://cmake.org/cmake/help/latest/release/4.4.html, 2026-09-18).

The ecosystem around CMake is built on stable machine-readable surfaces rather than binary plugins: the file API for IDE integration, the presets JSON schema for CI and tooling, and package configuration files for dependency consumption. IDE integration is documented as its own guide (source: https://cmake.org/cmake/help/latest/guide/ide-integration/index.html, 2026-09-18). Binary and source distributions are published for a range of platforms and include CTest, CPack, and `cmake-gui` components (source: https://cmake.org/download/, 2026-09-18).

Governance is vendor-led: Kitware maintains the upstream GitLab repository and the documentation carries a Kitware copyright, while the license is permissive BSD-3-Clause (source: https://api.github.com/repos/Kitware/CMake and https://cmake.org/cmake/help/latest/, 2026-09-18). The GitHub mirror tracks upstream closely, showing a push timestamp of 2026-09-18 in its metadata (source: https://api.github.com/repos/Kitware/CMake, 2026-09-18).

Distribution and documentation are versioned in lockstep: the download page publishes a latest release and a previous release, and the rendered documentation at `cmake.org/cmake/help/latest/` reports the same version (4.4.3) in its page headers and footer (source: https://cmake.org/download/ and https://cmake.org/cmake/help/latest/, 2026-09-18). An adapter can therefore pin behavior against a documentation version rather than inferring it from a binary alone.

## 5. Market Positioning

CMake occupies a different position from hermetic monorepo orchestrators. Its documented scope is a single project's build description plus its test, install, and packaging phases. It generates a native build system and then hands control of actual execution and incrementality to that native tool, which is why `cmake --build` is documented as abstracting the native build tool's command line rather than replacing it (source: https://cmake.org/cmake/help/latest/manual/cmake.1.html, 2026-09-18).

Consequences that follow directly from the documented design:

- **Project-local, not workspace-level.** CMake has no documented workspace or monorepo graph concept; multi-project builds are expressed with `add_subdirectory()`, `FetchContent`, or `ExternalProject`, each of which has different lifecycle semantics (configure time for FetchContent, build time for ExternalProject) (source: https://cmake.org/cmake/help/latest/module/FetchContent.html and https://cmake.org/cmake/help/latest/module/ExternalProject.html, 2026-09-18).
- **Non-hermetic by design.** Configuration executes project code. There is no documented sandbox in the build system manual; dependency resolution is delegated to `find_package`, FetchContent, ExternalProject, or a toolchain file (source: https://cmake.org/cmake/help/latest/command/find_package.html and https://cmake.org/cmake/help/latest/manual/cmake-toolchains.7.html, 2026-09-18).
- **Strong interoperability surfaces.** The install/export model produces relocatable config packages consumed by `find_package`, and the file API exposes the project model to external tools, which is why IDE and tooling integration is a first-class documented concern (source: https://cmake.org/cmake/help/latest/guide/importing-exporting/index.html and https://cmake.org/cmake/help/latest/guide/ide-integration/index.html, 2026-09-18).
- **Broad language reach.** The toolchain manual documents languages enabled through `project()` and `enable_language()`, and the 4.4 notes add CUDA and `clang-cl` module support, confirming that CMake's reach extends past plain C and C++ (source: https://cmake.org/cmake/help/latest/manual/cmake-toolchains.7.html and https://cmake.org/cmake/help/latest/release/4.4.html, 2026-09-18).
- **Generator-agnostic callers.** Because `cmake --build` abstracts the native tool and `CMAKE_GENERATOR` selects a default when `-G` is absent, callers can stay generator-agnostic while projects retain generator-specific options via `-T` and `-A` (source: https://cmake.org/cmake/help/latest/envvar/CMAKE_GENERATOR.html and https://cmake.org/cmake/help/latest/manual/cmake.1.html, 2026-09-18).

The practical positioning for an orchestrator: CMake is the compatibility surface for the existing C/C++ project base, not a competitor for monorepo-wide graph scheduling, caching, or dependency unification.

## 6. Product Highlights

- **A generator abstraction with many native back ends.** One project description can target Makefiles, Ninja, FASTBuild, Visual Studio, or Xcode (source: https://cmake.org/cmake/help/latest/manual/cmake-generators.7.html, 2026-09-18).
- **Presets as a first-class, versioned contract.** The JSON schema has shipped incrementally since 3.19 and now covers configure, build, test, package, and workflow presets, with inheritance, conditions, macros, includes, and a vendor extension point (source: https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html, 2026-09-18).
- **A complete install and export model.** Targets are installed and exported as namespaced imported targets, with generated config and version files that `find_package` consumes (source: https://cmake.org/cmake/help/latest/guide/importing-exporting/index.html, 2026-09-18).
- **A documented tool integration protocol.** The file API exposes codemodel, cache, cmakeFiles, toolchains, configureLog, and other object kinds as versioned JSON (source: https://cmake.org/cmake/help/latest/manual/cmake-file-api.7.html, 2026-09-18).
- **An explicit compatibility policy.** The `cmake_minimum_required` range and the policy engine give projects a documented way to declare the behavior they expect and to be warned about newer policies (source: https://cmake.org/cmake/help/latest/command/cmake_minimum_required.html, 2026-09-18).
- **Cross-compilation as a documented, portable pattern.** Toolchain files plus `--toolchain` and the `toolchainFile` preset field unify cross builds across many target families (source: https://cmake.org/cmake/help/latest/manual/cmake-toolchains.7.html, 2026-09-18).
- **Testing and packaging included.** CTest and CPack ship with the same distributions and participate in the same presets model through test and package presets (source: https://cmake.org/cmake/help/latest/manual/ctest.1.html, https://cmake.org/cmake/help/latest/manual/cpack.1.html, 2026-09-18).
- **Operational visibility.** Diagnostics categories and the instrumentation data stream give orchestration tooling structured signals for warnings, timing, and trace capture (source: https://cmake.org/cmake/help/latest/release/4.4.html, 2026-09-18).
- **A stable cache and directory model.** `CMakeCache.txt` is created in an empty build tree and holds customizable settings, which gives tooling a stable per-build artifact to inspect or invalidate (source: https://cmake.org/cmake/help/latest/manual/cmake.1.html, 2026-09-18).
- **A single build entry point with a native escape hatch.** `cmake --build` accepts `-- <build-tool-options>` to forward generator-specific flags, so callers keep one command while projects keep native options (source: https://cmake.org/cmake/help/latest/manual/cmake.1.html, 2026-09-18).

## 7. Value to PolyOrch

PolyOrch's CMake adapter is the compatibility path: it invokes `cmake --build` and consumes `install/` artifacts, while Xmake remains the native build engine and Pixi manages environments. The points below are bucketed by what the adapter should do.

### [Adopt] Directly reusable

- **[Adopt] Drive the adapter through the `cmake` CLI, never through a generator.** Invoke `cmake -B <build-dir> -S <source-dir>` to configure and `cmake --build <build-dir>` to build. This is exactly the documented abstraction of the native build tool, so the adapter does not need per-generator knowledge (source: https://cmake.org/cmake/help/latest/manual/cmake.1.html, 2026-09-18).
- **[Adopt] Stage artifacts with `cmake --install <build-dir> --prefix <polyorch-staging-dir>`.** `--prefix` temporarily replaces `CMAKE_INSTALL_PREFIX` at install time, which gives PolyOrch a deterministic per-package staging root instead of relying on a project-chosen `install/` location (source: https://cmake.org/cmake/help/latest/manual/cmake.1.html, 2026-09-18).
- **[Adopt] Prefer `--preset` when `CMakePresets.json` exists.** Presets already encode `binaryDir`, `generator`, `toolchainFile`, `cacheVariables`, and environment, so the adapter should pass the preset name through rather than reconstructing those flags (source: https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html, 2026-09-18).
- **[Adopt] Use `--presets-file` in 4.4+ to avoid changing the working directory.** Since 4.4 the presets file can be supplied explicitly, and `--build <dir> --preset` no longer requires running from the presets directory, which removes a chdir from the adapter's execution model (source: https://cmake.org/cmake/help/latest/manual/cmake.1.html, 2026-09-18).
- **[Adopt] Detect the toolchain version with `cmake --version=json-v1`.** The JSON banner is schema-described, so the adapter can record the exact CMake version in build metadata without scraping text (source: https://cmake.org/cmake/help/latest/manual/cmake.1.html, 2026-09-18).
- **[Adopt] Read the project model from the file API.** Ask for the `codemodel` reply via `<build>/.cmake/api/v1/query/` and consume `index-*.json` from `reply/`. This gives targets, directories, file sets, and backtraces without parsing `CMakeLists.txt` (source: https://cmake.org/cmake/help/latest/manual/cmake-file-api.7.html, 2026-09-18).
- **[Adopt] Enforce a documented CMake floor and surface policy failures verbatim.** CMake 4.0 removed compatibility with versions older than 3.5, so projects that still call old `cmake_minimum_required()` versions fail hard; the adapter should treat that error as a routing signal, not retry it (source: https://cmake.org/cmake/help/latest/release/4.0.html, 2026-09-18).
- **[Adopt] Run the test phase through `ctest` and test presets when the project provides them.** `ctest --test-dir <build-dir>` plus parallel `-j` is the documented runner, and test presets expressed in `CMakePresets.json` map directly onto adapter flags (source: https://cmake.org/cmake/help/latest/manual/ctest.1.html and https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html, 2026-09-18).
- **[Adopt] Always specify the build configuration explicitly.** For single-config generators, `CMAKE_BUILD_TYPE` defaults to an empty string rather than `Debug`, so the adapter must pass an explicit type or preset value; for multi-config generators it must pass `--config` instead. This avoids a documented common misunderstanding (source: https://cmake.org/cmake/help/latest/manual/cmake-buildsystem.7.html, 2026-09-18).
- **[Adopt] Use `cmake_diagnostic()` categories and preset `warnings` for adapter-tunable reporting.** The adapter can raise or suppress specific diagnostics (for example `installAbsoluteDestination`) through `-W` flags or preset warnings rather than editing project files (source: https://cmake.org/cmake/help/latest/release/4.4.html, 2026-09-18).
- **[Adopt] Capture instrumentation data for build timing where the project enables it.** `cmake-instrumentation(7)` data can feed PolyOrch's build metrics, and 4.4's `compileTrace` can link compiler trace files into the run record (source: https://cmake.org/cmake/help/latest/release/4.4.html, 2026-09-18).
- **[Adopt] Pass generator-specific flags through the documented `--` separator.** `cmake --build <dir> -- <build-tool-options>` forwards options to the native tool, so PolyOrch can expose an escape hatch without bypassing the CMake CLI (source: https://cmake.org/cmake/help/latest/manual/cmake.1.html, 2026-09-18).
- **[Adopt] Inspect or invalidate the persistent build cache.** `CMakeCache.txt` is created in an empty build tree and stores customizable settings, so the adapter can treat it as the build-state marker for a given configure (source: https://cmake.org/cmake/help/latest/manual/cmake.1.html, 2026-09-18).
- **[Adopt] Prefer `cmake --install` over invoking a native `install` target.** It runs the install rules without relying on the generated build system, which keeps artifact staging uniform across generators (source: https://cmake.org/cmake/help/latest/manual/cmake.1.html, 2026-09-18).
- **[Adopt] Offer `CMAKE_GENERATOR` as an environment-level generator override.** When `-G` is absent CMake falls back to `CMAKE_GENERATOR` and then to a builtin default, so an adapter can set a session default without changing the command line (source: https://cmake.org/cmake/help/latest/envvar/CMAKE_GENERATOR.html, 2026-09-18).

### [Adapt] Reusable with modification

- **[Adapt] Treat `install/` as a PolyOrch-owned staging convention, not a CMake contract.** CMake's real contract is `CMAKE_INSTALL_PREFIX` plus `GNUInstallDirs`. The adapter should always pass `--prefix` and then resolve artifacts under that prefix, and it should document that `install/` is PolyOrch's chosen layout (source: https://cmake.org/cmake/help/latest/module/GNUInstallDirs.html and https://cmake.org/cmake/help/latest/manual/cmake.1.html, 2026-09-18).
- **[Adapt] Bridge Pixi toolchains through a generated toolchain file.** CMake has no environment manager, so PolyOrch should generate or point at a `toolchainFile` that sets `CMAKE_<LANG>_COMPILER` to the Pixi-provided compilers, and pass it via the preset field or `--toolchain` (source: https://cmake.org/cmake/help/latest/manual/cmake-toolchains.7.html, 2026-09-18).
- **[Adapt] Overlay PolyOrch settings via `CMakeUserPresets.json` or `--presets-file`, never by rewriting `CMakePresets.json`.** Presets support `include` and `inherits`, so an overlay is the documented extension path, and the `vendor` field is reserved for tool-owned data (source: https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html, 2026-09-18).
- **[Adapt] Express monorepo-internal dependencies through `CMAKE_PREFIX_PATH` and staged prefixes, not `add_subdirectory()`.** For CMake consumers, pointing `find_package` at the install prefixes of sibling packages keeps the PolyOrch build graph authoritative, whereas `add_subdirectory()` would merge subprojects into one configure (source: https://cmake.org/cmake/help/latest/command/find_package.html and https://cmake.org/cmake/help/latest/command/add_subdirectory.html, 2026-09-18).
- **[Adapt] Redirect `FetchContent` and `ExternalProject` to PolyOrch-managed dependencies where possible.** Config mode already consults `CMAKE_FIND_PACKAGE_REDIRECTS_DIR` before its normal search (since 3.24), and `FetchContent` can write redirects there; the adapter can pre-populate that directory so vendored fetches resolve to PolyOrch-resolved packages (source: https://cmake.org/cmake/help/latest/command/find_package.html and https://cmake.org/cmake/help/latest/module/FetchContent.html, 2026-09-18).
- **[Adapt] Handle multi-config generators explicitly.** For Visual Studio, Xcode, and Ninja Multi-Config, `CMAKE_BUILD_TYPE` is ignored and the configuration is chosen at build time, so the adapter must pass `--config` to both `cmake --build` and `cmake --install`, and read `CMAKE_CONFIGURATION_TYPES` to know what is available (source: https://cmake.org/cmake/help/latest/manual/cmake-buildsystem.7.html and https://cmake.org/cmake/help/latest/manual/cmake.1.html, 2026-09-18).
- **[Adapt] Version-gate file API parsing.** Object kinds such as `configureLog` and `cmakeFiles` were added in 4.1, and codemodel subversions advance (for example `fileSetIndexes` in codemodel 2.11), so the adapter must tolerate older replies and fall back to the CLI when a kind is absent (source: https://cmake.org/cmake/help/latest/manual/cmake-file-api.7.html, 2026-09-18).
- **[Adapt] Model CMake incrementality as generator-level, not CMake-level.** The adapter owns a stable `<build-dir>` per project and lets Ninja or Make do incremental work; PolyOrch's Core layer tracks and invalidates that directory rather than expecting CMake to cache (source: https://cmake.org/cmake/help/latest/manual/cmake-buildsystem.7.html, 2026-09-18).
- **[Adapt] Use cache preload and cache variables for PolyOrch-injected configuration.** `-C <initial-cache>` can preload a generated script whose entries take priority over project defaults, and `-D` updates cache entries; this is a safer injection point than editing `CMakeLists.txt` (source: https://cmake.org/cmake/help/latest/manual/cmake.1.html, 2026-09-18).
- **[Adapt] Split runtime and development artifacts with components.** `install()` components let a project separate `Runtime` and `Development` outputs, and 4.4 allows selecting multiple components on `cmake --install`; PolyOrch can use components to build slimmer per-package payloads (source: https://cmake.org/cmake/help/latest/command/install.html and https://cmake.org/cmake/help/latest/manual/cmake.1.html, 2026-09-18).
- **[Adapt] Support the CPS export path opportunistically.** Since 4.3, `install(PACKAGE_INFO)` emits a Common Package Specification file alongside traditional config packages; the adapter can consume CPS when present and fall back to `find_package` config packages otherwise (source: https://cmake.org/cmake/help/latest/command/install.html, 2026-09-18).
- **[Adapt] Keep the vcpkg and Conan bridges on the CMake side via toolchain files.** Xmake-native modules use the `vcpkg::` and `conan::` namespaces, but a CMake project brings its own dependency mechanism; PolyOrch should pass the package manager's toolchain file through `--toolchain` or the `toolchainFile` preset field rather than trying to inject Xmake namespaces into CMake (source: https://cmake.org/cmake/help/latest/manual/cmake-toolchains.7.html, 2026-09-18).
- **[Adapt] Record `CMAKE_INSTALL_<dir>` defaults when mapping artifacts.** Install destinations are relative to the prefix by default (`bin`, `lib`, `include`), but can be overridden, so the adapter should query the configured values or read them from the cache reply instead of hardcoding `lib` and `bin` (source: https://cmake.org/cmake/help/latest/module/GNUInstallDirs.html and https://cmake.org/cmake/help/latest/manual/cmake-file-api.7.html, 2026-09-18).
- **[Adapt] Be deliberate about `CMAKE_INSTALL_MODE`.** The environment variable overrides install copy behavior since 3.22; PolyOrch should set it intentionally (or leave it unset) so artifact staging is deterministic across environments (source: https://cmake.org/cmake/help/latest/command/install.html, 2026-09-18).
- **[Adapt] Do not enable parallel installation when install ordering matters.** Install rules in `add_subdirectory()` directories are interleaved in declaration order under policy `CMP0082`, but the opt-in `INSTALL_PARALLEL` property removes ordering guarantees, so an adapter must choose determinism or speed per project (source: https://cmake.org/cmake/help/latest/command/install.html, 2026-09-18).
- **[Adapt] Treat `CMakeUserPresets.json` and PolyOrch overlays as generated, not committed.** Presets are read as the union of `CMakePresets.json` and `CMakeUserPresets.json` in a directory, so PolyOrch should write its overlay into the user file or a dedicated overlay path and keep it out of the project's tracked sources (source: https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html, 2026-09-18).
- **[Adapt] Use user-wide file API queries only deliberately.** Since 3.31 users can add query files under `CMAKE_CONFIG_DIR`'s `api/v1/query`, which applies to all CMake projects; PolyOrch should scope queries to the project build tree unless a global query is intentional (source: https://cmake.org/cmake/help/latest/manual/cmake-file-api.7.html, 2026-09-18).
- **[Adapt] Read the diagnostics category list from the manual version in use.** Categories are documented in `cmake-diagnostics(7)` and evolve per release, so the adapter should version-gate which `-W` flags and preset `warnings` keys it sets (source: https://cmake.org/cmake/help/latest/release/4.4.html, 2026-09-18).

### [Avoid] Known pitfalls / not applicable

- **[Avoid] Do not parse `CMakeLists.txt` to discover targets.** The CMake language permits arbitrary functions, macros, and generator expressions, and the file API exists precisely to avoid this; parsing it would be brittle and version-sensitive (source: https://cmake.org/cmake/help/latest/manual/cmake-file-api.7.html, 2026-09-18).
- **[Avoid] Do not depend on build-tree export files across the workspace.** `export(TARGETS)` files are specific to the build tree and documented as not relocatable; only `install(EXPORT)` output belongs in PolyOrch's shared artifact space (source: https://cmake.org/cmake/help/latest/command/export.html, 2026-09-18).
- **[Avoid] Do not treat `github.com/Kitware/CMake` as canonical.** It is a mirror by its own description; pin checksums, PRs, and upstream references to the GitLab repository (source: https://api.github.com/repos/Kitware/CMake, 2026-09-18).
- **[Avoid] Do not assume absolute install destinations will work.** Absolute `DESTINATION` paths break `cmake --install --prefix` and CPack installer generators, and 4.4 added a diagnostic specifically to flag them; an adapter must not inject absolute destinations (source: https://cmake.org/cmake/help/latest/module/GNUInstallDirs.html, 2026-09-18).
- **[Avoid] Do not add retry loops around CMake configure or build.** A policy error, a missing compiler, or a failing compile is deterministic; retrying wastes orchestration time. The correct response is to surface the diagnostic and route or fail (source: https://cmake.org/cmake/help/latest/release/4.0.html, 2026-09-18).
- **[Avoid] Do not treat CMake as a hermetic or sandboxed environment.** Configure executes project code, and `FetchContent`/`ExternalProject` may reach the network; PolyOrch must not assume isolation, and should restrict or intercept network fetches at the environment layer (source: https://cmake.org/cmake/help/latest/module/ExternalProject.html and https://cmake.org/cmake/help/latest/module/FetchContent.html, 2026-09-18).
- **[Avoid] Do not assume every CMake project uses presets.** Presets exist only from 3.19 onward and are optional; the adapter needs a non-preset fallback path that supplies source directory, build directory, generator, configuration, and cache variables explicitly (source: https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html, 2026-09-18).
- **[Avoid] Do not modify a project's `CMakeLists.txt` or `CMakePresets.json` to fit PolyOrch.** Both are project-owned inputs; write PolyOrch-specific values to `CMakeUserPresets.json`, an overlay presets file, cache variables, or a generated toolchain file instead (source: https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html, 2026-09-18).
- **[Avoid] Do not use CMake's install step as a package manager.** `find_package` config packages and `install(EXPORT)` describe what a project already built; they do not resolve, download, or version dependencies. Dependency unification belongs to Pixi plus the vcpkg/Conan paths, not to the CMake adapter (source: https://cmake.org/cmake/help/latest/command/find_package.html, 2026-09-18).
- **[Avoid] Do not rely on `cmake --open` for automation.** It opens the generated project in an associated application and is documented as supported only by some generators, so it is unsuitable for headless orchestration (source: https://cmake.org/cmake/help/latest/manual/cmake.1.html, 2026-09-18).
- **[Avoid] Do not let subproject `add_subdirectory()` builds leak into PolyOrch's graph.** `FetchContent_MakeAvailable()` and `add_subdirectory()` merge content into the parent configure, which hides subproject boundaries; the adapter should prefer installed-package consumption when a project genuinely has multiple PolyOrch nodes (source: https://cmake.org/cmake/help/latest/module/FetchContent.html and https://cmake.org/cmake/help/latest/command/add_subdirectory.html, 2026-09-18).
- **[Avoid] Do not share one build directory across different toolchains or environments.** The configure cache persists in the build tree, so mixing toolchains in the same directory leaves stale configuration; PolyOrch should key build directories by configure inputs (source: https://cmake.org/cmake/help/latest/manual/cmake.1.html, 2026-09-18).
- **[Avoid] Do not treat CPack output as the artifact contract for the monorepo.** CPack generates installers and source packages for distribution, while PolyOrch consumes installed prefixes; coupling the graph to CPack would add a packaging layer PolyOrch does not need (source: https://cmake.org/cmake/help/latest/manual/cpack.1.html, 2026-09-18).
- **[Avoid] Do not use `cmake -E` as a general task runner.** It is a set of built-in command-line tools, not an orchestration API; PolyOrch should keep scheduling and file operations in its own Core layer (source: https://cmake.org/cmake/help/latest/manual/cmake.1.html, 2026-09-18).
- **[Avoid] Do not assume the default generator is Ninja or Make.** Generator selection falls back to a builtin default when neither `-G` nor `CMAKE_GENERATOR` is set, and that default is platform-dependent; the adapter must record the selected generator rather than assume one (source: https://cmake.org/cmake/help/latest/envvar/CMAKE_GENERATOR.html and https://cmake.org/cmake/help/latest/manual/cmake.1.html, 2026-09-18).

## Appendix (optional deep dives)

### A. Command-line surface relevant to an adapter

| Command | Purpose | Source |
|---|---|---|
| `cmake -B <build> [-S <source>]` | Configure and generate a build system | https://cmake.org/cmake/help/latest/manual/cmake.1.html |
| `cmake -G <generator> -T <toolset> -A <platform>` | Select generator, toolset, and platform | https://cmake.org/cmake/help/latest/manual/cmake.1.html |
| `cmake -D <var>=<value>` | Create or update a cache entry | https://cmake.org/cmake/help/latest/manual/cmake.1.html |
| `cmake -C <initial-cache>` | Preload a script that populates cache entries | https://cmake.org/cmake/help/latest/manual/cmake.1.html |
| `cmake --toolchain <file>` | Specify a cross-compiling toolchain file | https://cmake.org/cmake/help/latest/manual/cmake.1.html |
| `cmake --build <dir> [--preset <p>] [-- <tool-opts>]` | Build through the generated system | https://cmake.org/cmake/help/latest/manual/cmake.1.html |
| `cmake --install <dir> [--config <c>] [--component <c>] [--prefix <p>]` | Run install rules | https://cmake.org/cmake/help/latest/manual/cmake.1.html |
| `cmake --workflow [<preset>]` | Run a workflow preset chain | https://cmake.org/cmake/help/latest/manual/cmake.1.html |
| `cmake -P <script>` | Run a CMake-language script | https://cmake.org/cmake/help/latest/manual/cmake.1.html |
| `cmake -E <command>` | Run a built-in command-line tool | https://cmake.org/cmake/help/latest/manual/cmake.1.html |
| `cmake --find-package [<options>]` | Run the find-package tool | https://cmake.org/cmake/help/latest/manual/cmake.1.html |
| `cmake --version=json-v1` | Machine-readable version banner | https://cmake.org/cmake/help/latest/manual/cmake.1.html |
| `cmake --help <keyword>` | Print help for a property, variable, command, policy, generator, or module | https://cmake.org/cmake/help/latest/manual/cmake.1.html |
| `ctest --test-dir <dir> [-j <level>]` | Run tests | https://cmake.org/cmake/help/latest/manual/ctest.1.html |
| `cpack -G <generators> [-C <configs>]` | Generate installers or source packages | https://cmake.org/cmake/help/latest/manual/cpack.1.html |

All rows accessed 2026-09-18.

### B. Preset schema version history

| Preset version | Introduced in CMake | Added |
|---|---|---|
| 1 | 3.19 | Configure presets and macro expansion |
| 2 | 3.20 | Build presets, test presets |
| 3 | 3.21 | `condition` object; `installDir`, `toolchainFile`; optional `binaryDir` and `generator`; `${hostSystemName}` |
| 4 | 3.23 | `include`; build preset `resolvePackageReferences` |
| 6 | 3.25 | `packagePresets` and `workflowPresets` |

Source: https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html, accessed 2026-09-18. The documented example uses root `"version": 10`, and the format reference lists `configurePresets`, `buildPresets`, `testPresets`, `packagePresets`, `workflowPresets`, `include`, and `vendor`. This table lists the versions whose feature sets are stated explicitly in the manual and is not a complete enumeration of every intermediate version.

### C. Install and import flow

1. Define a target with `add_library()` or `add_executable()`.
2. Attach install rules with `install(TARGETS ... EXPORT <export-name> DESTINATION ...)`.
3. Write the install-tree import file with `install(EXPORT <export-name> NAMESPACE <ns> DESTINATION <dir>)`.
4. Optionally generate a version file with `write_basic_package_version_file()` and a config file that calls `find_dependency()` for transitive packages.
5. A consumer calls `find_package()` in Config mode and links the namespaced imported target.

Sources: https://cmake.org/cmake/help/latest/command/install.html, https://cmake.org/cmake/help/latest/guide/importing-exporting/index.html, https://cmake.org/cmake/help/latest/manual/cmake-packages.7.html, accessed 2026-09-18. Note that build-tree exports (`export()`) use the same target set but produce non-relocatable files that must not be installed (source: https://cmake.org/cmake/help/latest/command/export.html, 2026-09-18).

### D. File API object kinds

The file API reply index references versioned object kinds. Documented kinds include `codemodel` (version 2, with directory, target, and backtrace graph objects), `configureLog`, `cache`, `cmakeFiles`, and `toolchains`, each with its own major version and, for several kinds, a published JSON schema (source: https://cmake.org/cmake/help/latest/manual/cmake-file-api.7.html, 2026-09-18). When CMake fails to generate a build system it writes an `error-*.json` reply error index instead, added in 4.1, and only a subset of object kinds is provided in that case (source: https://cmake.org/cmake/help/latest/manual/cmake-file-api.7.html, 2026-09-18).

### E. Build configuration caveats

The manual warns that `CMAKE_BUILD_TYPE` and `CMAKE_CONFIGURATION_TYPES` are compared case-sensitively, while CMake treats configuration names case-insensitively internally in places that modify behavior, such as the `$<CONFIG:Debug>` generator expression (source: https://cmake.org/cmake/help/latest/manual/cmake-buildsystem.7.html, 2026-09-18). For an adapter this means configuration names must be passed through byte-exactly as the project defines them, not normalized casing.

### F. External project lifecycle

`FetchContent_Declare()` records download/update/patch options and is first-call-wins; the configure, build, install, and test steps are disabled for fetched content, which is why `FetchContent_MakeAvailable()` can add the content to the current build immediately (source: https://cmake.org/cmake/help/latest/module/FetchContent.html, 2026-09-18). `ExternalProject_Add()` instead downloads at build time and runs its steps through generated custom commands; for a non-CMake external project the default install step is documented to assume a Makefile-based build and run `make install` (source: https://cmake.org/cmake/help/latest/module/ExternalProject.html, 2026-09-18). The two lifecycles are not interchangeable, and an orchestrator that wants deterministic dependency resolution must decide which one it can intercept.


### G. Target types and pseudo targets

| Type | Created by | Notes | Source |
|---|---|---|---|
| Executable | `add_executable()` | Binary target producing an executable | https://cmake.org/cmake/help/latest/manual/cmake-buildsystem.7.html |
| Static library | `add_library(... STATIC)` or no type when `BUILD_SHARED_LIBS` is false | Archives of object files, produced by an archiver | https://cmake.org/cmake/help/latest/manual/cmake-buildsystem.7.html |
| Shared library | `add_library(... SHARED)` | Dynamically linked library | https://cmake.org/cmake/help/latest/manual/cmake-buildsystem.7.html |
| Module library | `add_library(... MODULE)` | Loadable module, not linked by consumers | https://cmake.org/cmake/help/latest/manual/cmake-buildsystem.7.html |
| Object library | `add_library(... OBJECT)` | Objects consumed via `$<TARGET_OBJECTS:name>` | https://cmake.org/cmake/help/latest/manual/cmake-buildsystem.7.html |
| Interface library | `add_library(... INTERFACE)` | No artifact; carries usage requirements only | https://cmake.org/cmake/help/latest/manual/cmake-buildsystem.7.html |
| Imported target | package config or export file | Describes a target built elsewhere | https://cmake.org/cmake/help/latest/manual/cmake-buildsystem.7.html |
| Alias target | `add_library(<name> ALIAS <target>)` | Read-only; not mutable, installable, or exportable | https://cmake.org/cmake/help/latest/manual/cmake-buildsystem.7.html |

All rows accessed 2026-09-18. The buildsystem manual also documents Apple frameworks and imported targets as target categories.

### H. Generator categories

| Category | Examples | Configuration model | Source |
|---|---|---|---|
| Command-line build tool generators | Makefile generators, Ninja generators, FASTBuild generator | Single-configuration (Makefile, Ninja) | https://cmake.org/cmake/help/latest/manual/cmake-generators.7.html |
| IDE build tool generators | Visual Studio generators, Xcode, other generators | Multi-configuration for Visual Studio and Xcode | https://cmake.org/cmake/help/latest/manual/cmake-generators.7.html |
| Multi-configuration generator | Ninja Multi-Config | Configuration chosen at build time | https://cmake.org/cmake/help/latest/manual/cmake-buildsystem.7.html |

All rows accessed 2026-09-18. IDE generators configure their own environment, so CMake may be launched from any environment when they are used (source: https://cmake.org/cmake/help/latest/manual/cmake-generators.7.html, 2026-09-18).