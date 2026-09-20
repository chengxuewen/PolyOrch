# Conan Profile

> Sources: https://github.com/conan-io/conan, https://docs.conan.io/2/, https://pypi.org/pypi/conan/json, https://github.com/conan-io/conan-center-index, researched 2026-09-18
> Not a derived document: facts here are externally sourced.

## 1. Product Profile

Conan is a decentralized, open-source package manager for C and C++ (source: https://raw.githubusercontent.com/conan-io/conan/develop2/README.md, 2026-09-18). It is developed and maintained by JFrog and hosted at `github.com/conan-io/conan` (source: https://raw.githubusercontent.com/conan-io/conan/develop2/README.md, 2026-09-18).

| Field | Value | Source |
|---|---|---|
| Repository | `github.com/conan-io/conan` | README, 2026-09-18 |
| Version | 2.32.0 (released 2026-08-31) | PyPI JSON API, 2026-09-18 |
| License | MIT (Copyright (c) 2019 JFrog LTD) | `LICENSE.md`, 2026-09-18 |
| Implementation language | Python (`python_requires >= 3.7`) | `setup.py`, 2026-09-18 |
| Configuration files | `conanfile.py`, `conanfile.txt` | docs, 2026-09-18 |
| Homepage | https://conan.io | README, 2026-09-18 |
| Documentation | https://docs.conan.io | README, 2026-09-18 |
| Package registry (default remote) | `https://center2.conan.io` | docs, 2026-09-18 |

Conan 2.x is the current generation. Conan 2.0.0 was published on 2023-02-22, so the entire 2.x line is a multi-year evolution rather than a fresh rewrite (source: PyPI JSON API release history, 2026-09-18). The 2.32.0 source tree on the `develop2` branch identifies itself as `2.33.0-dev`, which confirms active development after the 2.32.0 release (source: https://raw.githubusercontent.com/conan-io/conan/develop2/conan/__init__.py, 2026-09-18).

Product-level positioning, in the project's own words (source: https://raw.githubusercontent.com/conan-io/conan/develop2/README.md, 2026-09-18):

- **Fully decentralized.** Users can host packages on their own servers.
- **Portable.** Supports Linux, macOS, Windows (native, WSL, MinGW), Solaris, FreeBSD, embedded, cross-compiling, Docker.
- **Binary management.** It creates, uploads and downloads binaries for any configuration and platform, including cross-compiled targets.
- **Build-system integration.** Integrates with any build system and provides tested support for major ones (CMake, MSBuild, Makefiles, Meson).
- **Extensible.** Python-based recipes plus extension points.
- **Stable.** Since 1.0 there is a stated commitment not to break package recipes and documented behavior.

The project's stated reasons for using it center on three claims: any number of binaries per package, no mandatory infrastructure to get started, and an open-source tool with optional JFrog Artifactory integration (source: https://conan.io, 2026-09-18).

For PolyOrch, Conan is one of the dependency sources reachable through Xmake's `conan::` namespace. The `conan::name/version` syntax is confirmed real: Xmake's own README lists `add_requires("conan::openssl/1.1.1g", {alias = "openssl", optional = true, debug = true})` (source: https://github.com/xmake-io/xmake/blob/dev/README.md, 2026-09-18). Conan is therefore an integration surface, not a competing orchestrator.

## 2. Technical Characteristics

### Overall Architecture

Conan is a client-server system. The client is a terminal application that holds the heavy logic for package creation and consumption, and keeps a local cache so that packages can be created and tested fully offline. The servers only store packages: they do not build or create them. Recipes are created by the client, and when binaries must be compiled from sources, that compilation also happens on the client (source: https://docs.conan.io/2/introduction.html, 2026-09-18).

The remote model is a push-pull model analogous to Git remotes: clients fetch packages from, and upload packages to, one or more named remotes (source: https://docs.conan.io/2/introduction.html, 2026-09-18). A client can work offline as long as no new packages are needed from a server, because the local cache is authoritative for already-downloaded artifacts (source: https://docs.conan.io/2/introduction.html, 2026-09-18).

Remotes are declared in `[CONAN_HOME]/remotes.json`, and the default file ships a single remote named `conancenter`. Since Conan 2.9.2 the default URL is `https://center2.conan.io`; the older `https://center.conan.io` is frozen and no longer receives updates (source: https://docs.conan.io/2/reference/config_files/remotes.html, 2026-09-18). Each remote entry has a required `name` and `url`, plus a `verify_ssl` flag (source: https://docs.conan.io/2/reference/config_files/remotes.html, 2026-09-18). The ConanCenter remote is backed by the `conan-center-index` repository, whose recipes are built automatically by a continuous integration system when pull requests are merged (source: https://raw.githubusercontent.com/conan-io/conan-center-index/master/README.md, 2026-09-18).

The core data model is the binary model. A recipe (package reference plus recipe revision) can have many binaries, and every binary is identified by its own `package_id`. The `package_id` is computed from "the current package configuration, settings, and options", so a change in architecture, compiler, build type, or an option such as `shared` produces a different `package_id` and therefore a different binary (source: https://docs.conan.io/2/reference/binary_model/package_id.html, 2026-09-18). A single `zlib/1.2.13` recipe revision can therefore carry separate binaries for macOS `apple-clang` static and Linux `gcc` shared, each with its own `package_id` (source: https://docs.conan.io/2/reference/binary_model/package_id.html, 2026-09-18).

Dependencies feed into the consumer's `package_id` through `package_id_mode`. The default mode is derived from the `package_type` of the dependency. Embed modes apply, for example, when a shared library or application consumes a static library, or when any binary consumes a header-only library, and those default to `full_mode` so that any change forces a consumer rebuild. Non-embed modes apply between static libraries, or between binaries linking a shared library, and default to `minor_mode`, where patch-version changes are ignored but minor or major changes force a rebuild (source: https://docs.conan.io/2/reference/binary_model/dependencies.html, 2026-09-18). The documentation stresses that a correct `package_type`, either stated explicitly or inferred from a `shared` option, is important because it controls this behavior (source: https://docs.conan.io/2/reference/binary_model/dependencies.html, 2026-09-18).

The recommended server for self-hosting is JFrog Artifactory Community Edition (CE), a free edition that includes a WebUI, LDAP authentication, virtual and remote repositories, a REST API, and generic repositories (source: https://docs.conan.io/2/introduction.html, 2026-09-18). A `conan_server` implementation also exists in the project (source: https://docs.conan.io/2/introduction.html, 2026-09-18).

### Key Capabilities

- **Decentralized package hosting.** Any number of named remotes can be added, enabled, disabled, renamed, or removed; login and logout are managed per remote (source: https://docs.conan.io/2/reference/commands/remote.html, 2026-09-18).
- **Binary or source consumption.** `conan install` accepts `--build` selectors including `never` (fail if a binary is missing), `missing` (build from source when no binary exists), and `cascade` (source: https://docs.conan.io/2/reference/commands/install.html, 2026-09-18).
- **Recipe creation and upload.** `conan create` exports a recipe to the local cache and then builds and packages it, optionally running a `test_package` consumer project to verify the result (source: https://docs.conan.io/2/reference/commands/create.html, 2026-09-18). `conan upload` pushes recipes and binaries to a remote, defaulting to all revisions that match (source: https://docs.conan.io/2/reference/commands/upload.html, 2026-09-18).
- **Cross-compilation.** Conan models separate host and build contexts, each with its own profile, which is the basis for cross-building (source: https://docs.conan.io/2/reference/config_files/profiles.html, 2026-09-18).
- **Reproducibility.** Lockfiles pin exact versions and recipe revisions so that new upstream releases do not silently change a resolved graph (source: https://docs.conan.io/2/tutorial/versioning/lockfiles.html, 2026-09-18).
- **Version ranges.** Requirements accept expressions such as `[>=1.0 <2]`, `[<3.2.1]`, and `[>2.0]`, plus the `~` and `^` shortcuts (source: https://docs.conan.io/2/reference/conanfile/attributes.html, 2026-09-18).
- **Integrity gating.** Recipes can declare a module-level `required_conan_version` using version-range syntax, and a global `core:required_conan_version` can enforce a floor for a team or CI fleet (source: https://docs.conan.io/2/reference/conanfile/attributes.html, 2026-09-18).
- **Shared team configuration.** `conan config install` installs remotes, profiles, and conf from a git repository, an HTTP URL, a local folder, or a zip file into the Conan home (source: https://docs.conan.io/2/reference/commands/config.html, 2026-09-18).

### Tech Stack

The client is a Python application. `setup.py` declares `python_requires='>=3.7'` and packages the `conan` project from `conans/requirements.txt` (source: https://raw.githubusercontent.com/conan-io/conan/develop2/setup.py, 2026-09-18). The runtime dependency set is: `requests`, `urllib3`, `colorama`, `PyYAML`, `patch-ng`, `fasteners`, `distro` (Linux/FreeBSD only), `Jinja2`, and `python-dateutil` (source: https://raw.githubusercontent.com/conan-io/conan/develop2/conans/requirements.txt, 2026-09-18). The server extras add `bottle`, `pluginbase`, and `PyJWT` (source: https://raw.githubusercontent.com/conan-io/conan/develop2/conans/requirements.txt, 2026-09-18).

The Jinja2 dependency is visible in profiles: profiles are rendered as templates, with the Python `platform` and `os` modules and a `profile_dir` variable injected into the render context, allowing settings to be computed from the running machine. For example, a profile can set `build_type = {{ os.getenv("MY_BUILD_TYPE") }}` or point `tools.cmake.cmaketoolchain:toolchain_file` at a file next to the profile (source: https://docs.conan.io/2/reference/config_files/profiles.html, 2026-09-18).

The build backend is setuptools plus wheel (source: https://raw.githubusercontent.com/conan-io/conan/develop2/pyproject.toml, 2026-09-18).

## 3. Feature Overview

### Core Modules

**Recipes.** `conanfile.py` is the recipe file that defines how a package is built and consumed. Public attributes and methods such as `build()` and `self.package_folder` are reserved for Conan; recipes must use underscore-prefixed names for their own state (source: https://docs.conan.io/2/reference/conanfile.html, 2026-09-18). Conan only reserves protected members that begin with `_conan`, so any other underscore name is safe for recipe authors (source: https://docs.conan.io/2/reference/conanfile.html, 2026-09-18).

**Recipe attributes.** The reference documents a large attribute surface, grouped as package reference, metadata, requirements, sources, binary model, build, folders and layout, layout, package information for consumers, and other. Notable entries include `name`, `version`, `package_type`, `settings`, `options`, `default_options`, `requires`, `tool_requires`, `python_requires`, `generators`, `layouts`, `test_package_folder`, and `required_conan_version` (source: https://docs.conan.io/2/reference/conanfile/attributes.html, 2026-09-18).

`package_type` accepts `application`, `library`, `shared-library`, `static-library`, `header-library`, `build-scripts`, `python-require`, and `unknown`. Declaring it is optional but "very strongly recommended" because it drives the default `package_id_mode` and the trait propagation to consumers (source: https://docs.conan.io/2/reference/conanfile/attributes.html, 2026-09-18). A companion `package_type_traits` attribute fixes individual traits (notably the runtime `run` trait) without changing the `package_type` used for linkage and `package_id` (source: https://docs.conan.io/2/reference/conanfile/attributes.html, 2026-09-18).

`settings` lists the first-level settings a recipe reads or that affect its `package_id`, most commonly `os`, `compiler`, `build_type`, and `arch`, and the recipe can then read sub-settings such as `compiler.cppstd` or `compiler.libcxx` (source: https://docs.conan.io/2/reference/conanfile/attributes.html, 2026-09-18). Reading an undeclared setting, such as `compiler.libcxx` for `msvc`, produces an error; `self.settings.get_safe()` returns `None` (or a supplied default) instead (source: https://docs.conan.io/2/reference/conanfile/attributes.html, 2026-09-18).

`requires` is a list or tuple of regular host-context dependencies and supports version ranges, for example `requires = "pkg/[>1.0 <1.8]"` (source: https://docs.conan.io/2/reference/conanfile/attributes.html, 2026-09-18). The documentation recommends the full `[>=lower <upper]` form over the `~` and `^` shortcuts because it is more explicit (source: https://docs.conan.io/2/reference/conanfile/attributes.html, 2026-09-18).

**Recipe methods.** Documented methods include `build()`, `build_id()`, `build_requirements()`, `build_system_requirements()`, `compatibility()`, `configure()`, `config_options()`, `deploy()`, `export()`, `export_sources()`, `finalize()`, and `generate()`, among others (source: https://docs.conan.io/2/reference/conanfile/methods.html, 2026-09-18). The `compatibility()` method defines binary compatibility at the recipe level (source: https://docs.conan.io/2/reference/conanfile/methods.html, 2026-09-18).

`layout()` is the method that declares where sources, build outputs, and packaged artifacts live. Its `self.folders` sub-attributes include `source`, `build`, `generators`, and `root`, and it also exposes `self.cpp.package`, `self.cpp.source`, and `self.cpp.build` for consumer-facing `CppInfo` metadata (source: https://docs.conan.io/2/reference/conanfile/methods/layout.html, 2026-09-18). `self.folders.generators` controls where generator and toolchain files are written: relative to the root build folder under `conan create`, and relative to the current directory under `conan install` (source: https://docs.conan.io/2/reference/conanfile/methods/layout.html, 2026-09-18).

`package_info()` declares what consumers need: include directories, library names, library paths, and so on, grouped as `CppInfo` objects. A package made of multiple libraries can declare components, each with its own `CppInfo`, and components can depend on each other or on components of other packages via a `requires` attribute. Properties such as `cmake_file_name` and `cmake_target_name` customize the generated CMake config names (source: https://docs.conan.io/2/reference/conanfile/methods/package_info.html, 2026-09-18).

`generate()` is the method where generators and toolchains are instantiated and executed, for example `tc = CMakeToolchain(self); tc.generate()` (source: https://docs.conan.io/2/reference/conanfile/methods/generate.html, 2026-09-18). Generators can also be selected declaratively with the `generators` attribute, such as `generators = "CMakeDeps", "CMakeToolchain"` (source: https://docs.conan.io/2/reference/conanfile/attributes.html, 2026-09-18).

**`conanfile.txt`.** The declarative alternative is a plain text file with sections such as `[requires]`, `[tool_requires]`, and `[generators]`. A `[tool_requires]` entry installs executable tools, not linkable libraries, and the CMakeDeps generator does not create CMake config files for them (source: https://docs.conan.io/2/reference/conanfile_txt.html, 2026-09-18). The file supports version ranges and pinned recipe revisions (source: https://docs.conan.io/2/reference/conanfile_txt.html, 2026-09-18). It is a fixed declarative list and cannot carry recipe logic (source: https://docs.conan.io/2/reference/conanfile_txt.html, 2026-09-18).

**Profiles.** A profile groups `[settings]`, `[options]`, and `[conf]` for a build configuration. Profiles live in `[CONAN_HOME]/profiles` by default, can be passed by absolute or relative path, and are shown per context with `conan profile show -pr myprofile`, which prints a Host profile and a Build profile block (source: https://docs.conan.io/2/reference/config_files/profiles.html, 2026-09-18). `conan profile detect` generates a profile from auto-detected environment values and accepts `--name`, `-f/--force`, and `-e/--exist-ok` (source: https://docs.conan.io/2/reference/commands/profile.html, 2026-09-18). `conan profile path default` reports the location of a named profile (source: https://docs.conan.io/2/reference/commands/profile.html, 2026-09-18).

**Settings model.** `settings.yml` defines the root settings tree. New top-level settings can be added (for example a `distro` key), and `null` values mean "undefined, valid for all other values". Recipes must declare any added setting in their `settings` attribute to have it affect `package_id` (source: https://docs.conan.io/2/reference/config_files/settings.html, 2026-09-18).

**Global configuration.** `global.conf` holds `core.*`, `tools.*`, and `user.*` entries. `core.xxx` values can only be defined in `global.conf` (or via `--core-conf`), not in profiles. `tools.yyy` can be set in `global.conf`, in profile `[conf]` sections, and via CLI `-c`. `user.zzz` values can be defined anywhere and must contain one `:` separator, for example `user.myorg:conf` (source: https://docs.conan.io/2/reference/config_files/global_conf.html, 2026-09-18). Profile values take priority over `global.conf` values, and a `[conf]` entry in a profile affects only its own context, host or build (source: https://docs.conan.io/2/reference/config_files/global_conf.html, 2026-09-18).

**Generators and tools.** Recipe tools are imported from `conan.tools.*`. The documented families include `conan.tools.cmake` (`CMakeDeps`, `CMakeConfigDeps`, `CMakeToolchain`, `CMake`, `cmake_layout`), `conan.tools.env` (`Environment`, `EnvVars`, `VirtualBuildEnv`, `VirtualRunEnv`), `conan.tools.gnu` (`AutotoolsDeps` and more), and Microsoft tooling such as `MSBuildToolchain`, `MSBuildDeps`, and `MSBuild` (source: https://docs.conan.io/2/reference/tools.html, 2026-09-18). A `MesonToolchain` reference page also exists (source: https://docs.conan.io/2/reference/tools/meson/mesontoolchain.html, 2026-09-18). Only documented public tools (not underscore-prefixed) may be used in recipes, and everything recipes may import belongs under `from conan.tools` (source: https://docs.conan.io/2/reference/tools.html, 2026-09-18).

The CMake integration is the most documented. `CMakeToolchain` produces a toolchain file used with `-DCMAKE_TOOLCHAIN_FILE=conan_toolchain.cmake`, and it is intended to run alongside `CMakeDeps`, not with legacy generators such as `cmake` or `cmake_paths` (source: https://docs.conan.io/2/reference/tools/cmake/cmaketoolchain.html, 2026-09-18). The toolchain translates the current package configuration, settings, and options into CMake toolchain syntax, and recipes can add `tc.variables`, `tc.preprocessor_definitions`, or `tc.cache_variables` before calling `tc.generate()` (source: https://docs.conan.io/2/reference/tools/cmake/cmaketoolchain.html, 2026-09-18). It also emits CMake presets prefixed `conan-` to avoid clashing with user presets (source: https://docs.conan.io/2/reference/tools/cmake/cmaketoolchain.html, 2026-09-18).

### Notable Features

**Binary compatibility via `package_id`.** Because the `package_id` is derived from settings and options, the same recipe can ship a static `gcc` Linux binary, a shared `apple-clang` macOS binary, and so on, all under one recipe revision. `conan list "zlib/1.2.13:*"` shows each `package_id` with the settings and options that produced it (source: https://docs.conan.io/2/reference/binary_model/package_id.html, 2026-09-18).

**Dependency-driven rebuild rules.** `package_id_mode` decides whether a dependency change forces a consumer rebuild. Embed relationships (for example a static library consumed by a shared library) use `full_mode`, while non-embed relationships (for example a shared library consumed by an application) use `minor_mode`, which tolerates patch-level dependency bumps (source: https://docs.conan.io/2/reference/binary_model/dependencies.html, 2026-09-18).

**Lockfiles.** `conan lock create` writes a `conan.lock` capturing resolved references including revisions. Lockfiles are strict by default: if a requirement cannot be matched in the lockfile, installation errors. `--lockfile-partial` relaxes this, `--lockfile-out` emits a new lockfile from the current graph, and `--lockfile-clean` drops unused entries (source: https://docs.conan.io/2/tutorial/versioning/lockfiles.html and https://docs.conan.io/2/reference/commands/install.html, 2026-09-18). By default, `conan install` uses a `conan.lock` beside the recipe or in the current working directory, if one exists (source: https://docs.conan.io/2/reference/commands/install.html, 2026-09-18).

**Method execution order.** `conan create` runs recipe methods in a documented order across four phases: export (`init`, `set_name`, `set_version`, `export`, `export_sources`), graph computation (`config_options`, `configure`, `requirements`, `build_requirements`), package computation (`validate_build`, `validate`, `package_id`, `layout`, `system_requirements`), and install (`source`, `build_id`, `generate`, `build`, `package`, `package_info`). The `generate`, `build`, and `package` steps are skipped when the binary is not built from source (source: https://docs.conan.io/2/reference/commands/create.html, 2026-09-18).

**Editable packages.** Conan provides an `editable` command family so a local package can be consumed in place without being exported to the cache. Path-dependent environment and configuration information is expressed through `layout()`, which distinguishes the cache form from the editable form (sources: https://docs.conan.io/2/reference/commands/editable.html and https://docs.conan.io/2/reference/conanfile/attributes.html, 2026-09-18).

**Test packages.** `conan create` looks for a `test_package` folder after the package is created and runs the consumer project inside it. `test_package_folder` changes the default folder name, `--test-folder=""` disables the test stage, and `--test-missing` runs the test only when the binary was built from source (sources: https://docs.conan.io/2/reference/conanfile/attributes.html and https://docs.conan.io/2/reference/commands/create.html, 2026-09-18).

**Upload controls.** `conan upload` requires a remote (`-r`), supports `--only-recipe`, `--force`, `--check`, `--dry-run`, a package query (`-p`), and the `latest` placeholder. A recipe can set `upload_policy = "skip"` to upload only the recipe and never its binaries, which is intended for packages that can only be built on the installation machine, such as system package wrappers. Upload compression is selectable via `core.upload:compression_format` with `zst`, `xz`, or `gz` (default `gz`) (source: https://docs.conan.io/2/reference/commands/upload.html, 2026-09-18).

**Authentication for CI.** `conan remote auth` uses the `CONAN_LOGIN_USERNAME` and `CONAN_PASSWORD` environment variables when available, and falls back to an interactive prompt otherwise. The documented scripting recommendation is `auth` over `login` (source: https://docs.conan.io/2/reference/commands/remote.html, 2026-09-18).

**Graph inspection.** Consumer commands include `conan graph` (dependency graph without fetching binaries), `conan list`, `conan inspect`, `conan cache`, `conan pkglist`, and `conan lock` (source: https://docs.conan.io/2/reference/commands.html, 2026-09-18). Several commands support a JSON output format via `-f json` (sources: https://docs.conan.io/2/reference/commands/install.html and https://docs.conan.io/2/reference/commands/upload.html, 2026-09-18).

### Extensibility / Plugin Mechanism

Conan exposes three distinct extension surfaces:

1. **`python_requires`.** A special recipe type (`package_type = "python-require"`) holds shared code and creates no binaries. Other recipes declare `python_requires = "pyreq/0.1"` and reach into it via `self.python_requires["pyreq"].module` (source: https://docs.conan.io/2/reference/extensions/python_requires.html, 2026-09-18). Python requires support version ranges, which the documentation recommends when the shared code evolves (source: https://docs.conan.io/2/reference/extensions/python_requires.html, 2026-09-18).

2. **Custom commands.** Python files named `cmd_<name>.py` placed under `[CONAN_HOME]/extensions/commands/` become `conan <name>`. A single subfolder level groups commands under a topic, invoked as `conan topic:command`; deeper nesting does not work (source: https://docs.conan.io/2/reference/extensions/custom_commands.html, 2026-09-18).

3. **Hooks.** Python files named `hook_*.py` stored anywhere under `[CONAN_HOME]/extensions/hooks/` activate automatically. Deactivation requires removing the file, because there is no configuration to keep a hook stored but inactive (source: https://docs.conan.io/2/reference/extensions/hooks.html, 2026-09-18).

Separately, `conan config install` is the sharing mechanism for extensions and configuration, and it accepts a git repository, HTTP URL, local folder, or zip file as its source (source: https://docs.conan.io/2/reference/commands/config.html, 2026-09-18).

## 4. Status & Ecosystem

- **Current release:** 2.32.0, published 2026-08-31 (source: https://pypi.org/pypi/conan/json, 2026-09-18).
- **Release cadence:** PyPI lists 367 releases; 2.30.0 was 2026-06-29, 2.31.0 was 2026-07-23, and 2.32.0 was 2026-08-31, an approximately monthly cadence (source: https://pypi.org/pypi/conan/json, 2026-09-18).
- **License:** MIT (source: https://raw.githubusercontent.com/conan-io/conan/develop2/LICENSE.md, 2026-09-18).
- **Maintainer:** JFrog LTD; the README describes "a full team of full-time maintainers" (source: https://raw.githubusercontent.com/conan-io/conan/develop2/README.md, 2026-09-18).
- **Package ecosystem:** ConanCenter is the default remote, currently `https://center2.conan.io`; the legacy `center.conan.io` stopped receiving updates on 2024-11-04 (source: https://raw.githubusercontent.com/conan-io/conan-center-index/master/README.md, 2026-09-18). Recipes in `conan-center-index` are built automatically by CI when pull requests are merged (source: https://raw.githubusercontent.com/conan-io/conan-center-index/master/README.md, 2026-09-18).
- **Community channels:** GitHub and the C++ Slack `#conan` channel (source: https://raw.githubusercontent.com/conan-io/conan/develop2/README.md, 2026-09-18).
- **Security reporting:** a Trust Center vulnerability reporting path is linked from the README (source: https://raw.githubusercontent.com/conan-io/conan/develop2/README.md, 2026-09-18).
- **Documentation versioning:** the docs site publishes per-minor-revision docs, and 2.32.0 pages carry "Edit on GitHub" links into the `release/2.32` branch of `conan-io/docs` (source: https://docs.conan.io/2/reference/conanfile.html, 2026-09-18).
- **Training:** JFrog Academy offers free Essentials and Advanced Conan 2 courses, linked from every documentation page (source: https://docs.conan.io/2/introduction.html, 2026-09-18).
- **Adoption evidence:** the README states Conan has been used in production by many companies since 1.0 (source: https://raw.githubusercontent.com/conan-io/conan/develop2/README.md, 2026-09-18). Star counts and contributor counts were not verifiable during this research and are omitted.
- **Self-hosting:** Artifactory CE is the recommended server, with `conan_server` also available (source: https://docs.conan.io/2/introduction.html, 2026-09-18).

## 5. Market Positioning

Conan positions itself as the package manager "C and C++ developers deserve", with the stated differentiators of decentralization, private self-hosting, binary management across configurations, and integration with any build system (sources: https://conan.io and https://raw.githubusercontent.com/conan-io/conan/develop2/README.md, 2026-09-18).

The direct alternative in the C/C++ dependency space is Microsoft's vcpkg, which PolyOrch also reaches through Xmake's `vcpkg::` namespace (source: https://github.com/xmake-io/xmake/blob/dev/README.md, 2026-09-18). The two differ in philosophy. Conan is decentralized and lets users host packages on their own servers, whereas vcpkg centers on a curated registry model. For PolyOrch, this matters less as a competition question and more as a coverage question: the two systems have partially overlapping package sets and mutually incompatible metadata, so a monorepo may legitimately use either or both.

Conan is explicitly designed to sit underneath a build system, not to replace one. Its documented integration targets are CMake, MSBuild, Makefiles, and Meson (source: https://raw.githubusercontent.com/conan-io/conan/develop2/README.md, 2026-09-18). It is therefore a peer of the environment and dependency layers rather than a peer of the orchestrators PolyOrch profiles separately.

The main strategic caveat is that Conan does not manage compilers or language runtimes. It consumes the ambient toolchain and encodes that toolchain into profiles and settings. Whoever sets up the toolchain (a container, an OS package manager, or Pixi) is upstream of Conan, and that is exactly the seam where PolyOrch has to be deliberate.

A second positioning note is that Conan 2 is a deliberate break from Conan 1. Concepts were renamed and some were dropped, and the ConanCenter remote split into a Conan 1 legacy endpoint and a Conan 2 endpoint. Users on Conan 1 are effectively on a frozen ecosystem (source: https://raw.githubusercontent.com/conan-io/conan-center-index/master/README.md, 2026-09-18).

## 6. Product Highlights

- **Decentralized by design.** Every client can push to and pull from any number of remotes, with no mandatory central registry (source: https://docs.conan.io/2/introduction.html, 2026-09-18).
- **Offline-capable client.** The client holds a local cache and can create and test packages without a server, working offline as long as no new packages are needed (source: https://docs.conan.io/2/introduction.html, 2026-09-18).
- **Configuration-addressed binaries.** `package_id` makes every binary variant addressable and cacheable, rather than treating a package as a single artifact (source: https://docs.conan.io/2/reference/binary_model/package_id.html, 2026-09-18).
- **Rebuild rules tied to linkage semantics.** `package_id_mode` defaults follow the embed or non-embed relationship between consumer and dependency, so a consumer is not rebuilt for a patch bump it cannot observe (source: https://docs.conan.io/2/reference/binary_model/dependencies.html, 2026-09-18).
- **Profiles as first-class configuration.** Host and build contexts each have a profile, which is the documented foundation for cross-compilation, and profiles are Jinja-rendered so they can adapt to the machine (source: https://docs.conan.io/2/reference/config_files/profiles.html, 2026-09-18).
- **Lockfiles for reproducible graphs.** Version ranges plus lockfiles give a resolved, pinned dependency graph suitable for CI (source: https://docs.conan.io/2/tutorial/versioning/lockfiles.html, 2026-09-18).
- **Build-system-neutral generators.** `CMakeToolchain` plus `CMakeDeps`, `MesonToolchain`, MSBuild tooling, Autotools tooling, and environment generators cover the mainstream build systems (source: https://docs.conan.io/2/reference/tools.html, 2026-09-18).
- **Structured machine output.** Several commands, including `install` and `upload`, accept `-f json`, which makes integration scriptable without parsing human output (sources: https://docs.conan.io/2/reference/commands/install.html and https://docs.conan.io/2/reference/commands/upload.html, 2026-09-18).
- **Three extension surfaces.** `python_requires`, custom commands, and hooks let a team extend Conan without forking it (sources: https://docs.conan.io/2/reference/extensions/python_requires.html, https://docs.conan.io/2/reference/extensions/custom_commands.html, https://docs.conan.io/2/reference/extensions/hooks.html, 2026-09-18).
- **Natural Xmake integration.** Xmake consumes Conan packages through the `conan::` namespace and generates the Conan inputs on the user's behalf (source: https://github.com/xmake-io/xmake/blob/dev/README.md, 2026-09-18).

## 7. Value to PolyOrch

PolyOrch is a build orchestrator for polyglot monorepos. It dispatches CMake, Xmake, Meson, and Colcon through adapters, uses Xmake as its native build engine, Pixi for environments, and vcpkg plus Conan as dependency sources reached through Xmake's `vcpkg::` and `conan::` namespaces. The points below are grouped by adopt, adapt, and avoid, and each names a concrete action.

### [Adopt] Directly reusable

- **[Adopt] Treat Conan as an optional dependency source, never a hard requirement.** PolyOrch should feature-detect the `conan` executable and only route `conan::` requirements when it is present, because Conan is one provider among several rather than the system of record for dependencies. Action: gate the Conan integration on a runtime capability probe and keep vcpkg, Xmake's own xmake-repo, and plain system packages as alternatives.

- **[Adopt] Reuse Xmake's `conan::` namespace instead of invoking the Conan CLI directly.** Xmake already handles `add_requires("conan::openssl/1.1.1g", {alias = "openssl"})`, so PolyOrch should express Conan dependencies in `xmake.lua` rather than shelling out to `conan install` itself (source: https://github.com/xmake-io/xmake/blob/dev/README.md, 2026-09-18). Action: the Conan code path lives inside the Xmake adapter, and no separate Conan adapter is introduced in v1.

- **[Adopt] Reuse Xmake's Conan option surface as PolyOrch's Conan configuration vocabulary.** Xmake exposes `remote`, `build`, `options`, `imports`, `build_requires`, `settings`, `settings_host`, `settings_build`, `conf`, `conf_host`, and `conf_build` for Conan packages (source: https://github.com/xmake-io/xmake/blob/dev/xmake/modules/package/manager/conan/configurations.lua, 2026-09-18). Action: PolyOrch's config schema for Conan dependencies mirrors this key set so users do not learn a second vocabulary.

- **[Adopt] Model per-target build configurations on Conan's settings and options.** Conan's `settings` list is the documented unit that affects `package_id`, most commonly `os`, `compiler`, `build_type`, and `arch`, plus sub-settings such as `compiler.cppstd` (source: https://docs.conan.io/2/reference/conanfile/attributes.html, 2026-09-18). Action: PolyOrch's build matrix should be expressible as Conan-compatible setting tuples so the same matrix drives both dependency selection and target builds.

- **[Adopt] Use lockfiles as PolyOrch's reproducibility primitive for dependency graphs.** `conan lock create` produces a strict `conan.lock`, and `--lockfile-out` emits one from the current graph (source: https://docs.conan.io/2/tutorial/versioning/lockfiles.html and https://docs.conan.io/2/reference/commands/install.html, 2026-09-18). Action: PolyOrch writes a per-environment lock artifact and treats a changed lockfile as an input-hash change for caching.

- **[Adopt] Read the dependency graph from `conan graph`, not from recipe text.** `conan graph` obtains dependency information without fetching binaries (source: https://docs.conan.io/2/reference/commands.html, 2026-09-18). Action: the Conan integration parses structured graph output for planning and for the PolyOrch dependency report.

- **[Adopt] Prefer JSON output modes over parsing human-readable output.** `conan install` and `conan upload` both support `-f json`, and `conan graph` exists precisely to expose graph data (sources: https://docs.conan.io/2/reference/commands/install.html and https://docs.conan.io/2/reference/commands/upload.html, 2026-09-18). Action: every Conan call PolyOrch makes for decision-making uses a structured output mode.

- **[Adopt] Use generator output as the CMake adapter boundary.** `CMakeToolchain` emits `conan_toolchain.cmake` for `-DCMAKE_TOOLCHAIN_FILE`, and pairs with `CMakeDeps` (source: https://docs.conan.io/2/reference/tools/cmake/cmaketoolchain.html, 2026-09-18). Action: PolyOrch passes the generated toolchain file and preset through the existing CMake adapter instead of re-implementing dependency injection.

- **[Adopt] Adopt the host/build profile split for cross-compilation.** Profiles exist separately per context, and `conan profile show` prints Host and Build blocks (source: https://docs.conan.io/2/reference/config_files/profiles.html, 2026-09-18). Action: PolyOrch's cross-compile targets are described as a host profile plus a build profile pair, which maps cleanly onto its own target model.

- **[Adopt] Distribute shared Conan configuration with `conan config install`.** It installs remotes, profiles, and conf from git, HTTP, a folder, or a zip into the Conan home (source: https://docs.conan.io/2/reference/commands/config.html, 2026-09-18). Action: PolyOrch can generate the config repository that `conan config install` consumes in CI, keeping remotes and profiles out of the monorepo tree.

- **[Adopt] Use `CONAN_LOGIN_USERNAME` and `CONAN_PASSWORD` for CI authentication.** `conan remote auth` reads these environment variables for scripting (source: https://docs.conan.io/2/reference/commands/remote.html, 2026-09-18). Action: PolyOrch's CI integration maps its secret store onto these two variables rather than inventing a credential convention.

- **[Adopt] Adopt the `package_type` vocabulary for PolyOrch's own package metadata.** The valid values (`application`, `library`, `shared-library`, `static-library`, `header-library`, `build-scripts`, `python-require`, `unknown`) are a ready-made classification for polyglot targets (source: https://docs.conan.io/2/reference/conanfile/attributes.html, 2026-09-18). Action: PolyOrch's target descriptor reuses these names so dependency semantics and rebuild rules stay aligned with Conan when Conan is in the graph.

### [Adapt] Reusable with modification

- **[Adapt] Generate the Conan profile from the Pixi environment instead of trusting auto-detection.** `conan profile detect` output is explicitly documented as not stable and may change in future releases (source: https://docs.conan.io/2/reference/commands/profile.html, 2026-09-18). Action: PolyOrch derives the Conan profile deterministically from the Pixi environment's compiler, version, and architecture, and does not run `conan profile detect` in any reproducible path.

- **[Adapt] Reconcile the Conan profile layer with Pixi, because both want to own the toolchain.** Conan encodes the compiler into profile `[settings]` and can inject environment through `VirtualBuildEnv` and `VirtualRunEnv` (sources: https://docs.conan.io/2/reference/config_files/profiles.html and https://docs.conan.io/2/reference/tools.html, 2026-09-18), while Pixi provides the environment and its activation. Action: PolyOrch declares Pixi as the single source of truth for the toolchain and generates Conan profiles from it, so the two systems never both set `CC`, `CXX`, or compiler settings.

- **[Adapt] Map PolyOrch target configurations explicitly onto Conan settings and options, never implicitly.** Settings that are not declared by a recipe do not affect its `package_id`, and undeclared sub-settings can cause resolution errors (source: https://docs.conan.io/2/reference/conanfile/attributes.html, 2026-09-18). Action: PolyOrch emits an explicit profile per target configuration and records which settings it pinned, rather than relying on Conan's defaults.

- **[Adapt] Adapt multi-configuration lockfiles to PolyOrch's per-target matrix.** A lockfile captures one resolved configuration; conditional requirements not covered by it fail unless `--lockfile-partial` is used (source: https://docs.conan.io/2/tutorial/versioning/lockfiles.html, 2026-09-18). Action: PolyOrch maintains one lockfile per environment and target, keyed in its cache index, instead of one global lock.

- **[Adapt] Adapt Xmake's generated `conanfile.txt` approach for the cases where PolyOrch must talk to Conan directly.** Xmake writes a `conanfile.txt` with `[requires]`, `[options]`, `[imports]`, and `[build_requires]` or `[tool_requires]` depending on the Conan major version (source: https://github.com/xmake-io/xmake/blob/dev/xmake/modules/package/manager/conan/v2/install_package.lua, 2026-09-18). Action: copy the generated-file boundary for escape hatch flows, but keep it internal to the adapter and never expose the generated file as a user-editable input.

- **[Adapt] Adapt Conan's `compatibility()` hook concept to PolyOrch's cache.** `compatibility()` defines binary compatibility at the recipe level, and `package_id_mode` decides when a dependency change forces a rebuild (sources: https://docs.conan.io/2/reference/conanfile/methods.html and https://docs.conan.io/2/reference/binary_model/dependencies.html, 2026-09-18). Action: PolyOrch's build cache invalidation should mirror these two rules rather than treating any dependency change as a full rebuild, and should expose an override for projects that need stricter behavior.

- **[Adapt] Carry Conan's `package_type` discipline into PolyOrch metadata.** `package_type` drives `package_id_mode` and trait propagation and is strongly recommended even though optional (source: https://docs.conan.io/2/reference/conanfile/attributes.html, 2026-09-18). Action: PolyOrch's own package descriptor records an equivalent classification so its cache and linking decisions stay consistent with Conan's semantics.

- **[Adapt] Borrow Conan's extension model shape for PolyOrch adapters.** Conan offers `python_requires` for shared recipe code, custom commands as `cmd_*.py`, and auto-activated hooks as `hook_*.py` (sources: https://docs.conan.io/2/reference/extensions/python_requires.html, https://docs.conan.io/2/reference/extensions/custom_commands.html, https://docs.conan.io/2/reference/extensions/hooks.html, 2026-09-18). Action: PolyOrch's adapter and hook surfaces follow the same convention-over-configuration pattern, with filename-based discovery and no registration boilerplate.

- **[Adapt] Adapt the `layout()` separation of cache and editable forms for workspace-local packages.** `layout()` distinguishes `self.folders.source`, `build`, and `generators`, and exposes `self.cpp.source` and `self.cpp.build` for editable consumption (source: https://docs.conan.io/2/reference/conanfile/methods/layout.html, 2026-09-18). Action: PolyOrch should adopt the same distinction between a workspace-local package and its packaged form, so developers do not need a full re-package cycle to test a change.

- **[Adapt] Adapt Conan's `global.conf` scope rules as a guard against configuration ambiguity.** `core.*` is confined to `global.conf`, `tools.*` can live in `global.conf` or profiles, `user.*` can live anywhere, and profile values win over `global.conf` (source: https://docs.conan.io/2/reference/config_files/global_conf.html, 2026-09-18). Action: PolyOrch's layered config should adopt explicit scope rules of its own and warn when a value is set at more than one layer with different results.

- **[Adapt] Adapt Conan's `core:required_conan_version` pattern as a PolyOrch version gate.** Recipes can enforce a Conan version range, and a global conf can enforce it for a fleet (source: https://docs.conan.io/2/reference/conanfile/attributes.html, 2026-09-18). Action: PolyOrch enforces a minimum Conan major version before invoking the integration, and reports a clear error rather than failing deep inside a recipe.

- **[Adapt] Adapt `conan config install` as the delivery channel for PolyOrch-managed profiles.** It accepts git, HTTP, folder, and zip sources (source: https://docs.conan.io/2/reference/commands/config.html, 2026-09-18). Action: PolyOrch generates a versioned config package per monorepo revision, so every CI job and developer machine resolves the same profiles and remotes.

### [Avoid] Known pitfalls / not applicable

- **[Avoid] Do not depend on `conan profile detect` output stability.** The documentation states plainly that its output is not stable and can change at any time (source: https://docs.conan.io/2/reference/commands/profile.html, 2026-09-18). Action: never snapshot `profile detect` output into PolyOrch's cache key; generate profiles from declared inputs only.

- **[Avoid] Do not use Conan 1 era recipe concepts.** `[imports]` is documented by the Xmake integration as deprecated in Conan 2.x, and `[build_requires]` became `[tool_requires]` in the Conan 2 generated file (sources: https://github.com/xmake-io/xmake/blob/dev/xmake/modules/package/manager/conan/configurations.lua and https://github.com/xmake-io/xmake/blob/dev/xmake/modules/package/manager/conan/v2/install_package.lua, 2026-09-18). Action: PolyOrch targets Conan 2 semantics only, and rejects Conan 1 configuration keys at config-validation time.

- **[Avoid] Do not let Conan and Pixi both manage the same dependency.** Pixi owns the conda environment while Conan owns its own cache and remotes, and both can inject build environment variables (sources: https://docs.conan.io/2/reference/tools.html and https://docs.conan.io/2/reference/config_files/profiles.html, 2026-09-18). Action: PolyOrch assigns each dependency to exactly one provider and fails validation when a package appears in both a `pixi.toml` dependency section and a `conan::` requirement.

- **[Avoid] Do not read or write the Conan cache by path.** The cache is managed by the client, and `conan cache` exists to return recipe and package paths (source: https://docs.conan.io/2/reference/commands.html, 2026-09-18). Action: PolyOrch calls Conan commands for any path it needs, so a cache layout change cannot break the integration.

- **[Avoid] Do not use `conanfile.txt` for anything that needs logic.** It is a declarative requirements list and cannot carry `python_requires`, hooks, or conditional requirements (source: https://docs.conan.io/2/reference/conanfile_txt.html, 2026-09-18). Action: any Conan integration beyond a fixed requirement list goes through a `conanfile.py` or through Xmake's `conan::` options.

- **[Avoid] Do not assume the old default remote still updates.** `center.conan.io` stopped receiving updates on 2024-11-04 and the default became `center2.conan.io` in Conan 2.9.2 (sources: https://docs.conan.io/2/reference/config_files/remotes.html and https://raw.githubusercontent.com/conan-io/conan-center-index/master/README.md, 2026-09-18). Action: PolyOrch's generated Conan configuration pins the remote URL explicitly and warns if the legacy URL is configured.

- **[Avoid] Do not treat Conan as a build orchestrator.** Conan's documented role is package creation and consumption with an explicit "integrates with any build system" scope (sources: https://docs.conan.io/2/introduction.html and https://raw.githubusercontent.com/conan-io/conan/develop2/README.md, 2026-09-18). Action: no scheduling, task graph, or adapter dispatch logic is delegated to Conan; it remains a dependency provider behind Xmake's namespace.

- **[Avoid] Do not assume a dependency change always forces a rebuild, or that it never does.** `package_id_mode` defaults to `full_mode` for embed relationships and `minor_mode` for non-embed relationships (source: https://docs.conan.io/2/reference/binary_model/dependencies.html, 2026-09-18). Action: PolyOrch documents which Conan relationship each target uses and surfaces the resulting rebuild behavior in its cache-key explanation, so users are not surprised by either outcome.

- **[Avoid] Do not mix recipes that use `conanfile.txt` with recipes that need conditional dependencies.** The text format has no conditional logic, so an environment-dependent requirement cannot be expressed there (source: https://docs.conan.io/2/reference/conanfile_txt.html, 2026-09-18). Action: PolyOrch validates dependency descriptors at config time and rejects a text-format descriptor that also declares an environment-conditional requirement.

- **[Avoid] Do not expose Conan extension hooks as PolyOrch extension points 1:1.** Conan hooks are auto-activated by filename with no way to keep one stored but inactive (source: https://docs.conan.io/2/reference/extensions/hooks.html, 2026-09-18). Action: if PolyOrch adopts filename-based hook discovery, it should still provide an explicit enable and disable switch, because the all-or-nothing activation model does not fit a shared monorepo.

- **[Avoid] Do not silently upgrade Conan across major versions.** Conan 2 renamed and removed Conan 1 concepts, and the ecosystem split across two remote endpoints (sources: https://github.com/xmake-io/xmake/blob/dev/xmake/modules/package/manager/conan/v2/install_package.lua and https://raw.githubusercontent.com/conan-io/conan-center-index/master/README.md, 2026-09-18). Action: PolyOrch pins the Conan major version it supports, fails loudly on a mismatch, and treats a major upgrade as an explicit user decision.

## Appendix

### A. Research Gaps

- GitHub star counts, contributor counts, and download counts were not captured because the GitHub API returned rate-limit errors during this research on 2026-09-18. They are omitted rather than estimated.
- The number of recipes in ConanCenter is not stated in the primary sources consulted, so it is omitted.
- The exact `MesonDeps` generator name could not be confirmed; only `MesonToolchain` was verified as a live reference page (source: https://docs.conan.io/2/reference/tools/meson/mesontoolchain.html, 2026-09-18). The broader `conan.tools.gnu` family is confirmed but the Meson dependency generator is left unspecified.
- The `conan build` command page was fetched but its detailed flag list was not extracted, so its exact options are not documented here beyond the fact that `layout()` applies to local `conan build` runs (source: https://docs.conan.io/2/reference/conanfile/methods/layout.html, 2026-09-18).

### B. Source List

- Project repository and README: https://github.com/conan-io/conan (2026-09-18)
- License: https://raw.githubusercontent.com/conan-io/conan/develop2/LICENSE.md (2026-09-18)
- Version and release dates: https://pypi.org/pypi/conan/json (2026-09-18)
- Python and dependency metadata: https://raw.githubusercontent.com/conan-io/conan/develop2/setup.py, https://raw.githubusercontent.com/conan-io/conan/develop2/pyproject.toml, https://raw.githubusercontent.com/conan-io/conan/develop2/conans/requirements.txt (2026-09-18)
- Documentation, introduction and architecture: https://docs.conan.io/2/introduction.html (2026-09-18)
- Recipes: https://docs.conan.io/2/reference/conanfile.html, https://docs.conan.io/2/reference/conanfile/attributes.html, https://docs.conan.io/2/reference/conanfile/methods.html, https://docs.conan.io/2/reference/conanfile_txt.html (2026-09-18)
- Method references: https://docs.conan.io/2/reference/conanfile/methods/layout.html, https://docs.conan.io/2/reference/conanfile/methods/generate.html, https://docs.conan.io/2/reference/conanfile/methods/package_info.html (2026-09-18)
- Binary model: https://docs.conan.io/2/reference/binary_model/package_id.html, https://docs.conan.io/2/reference/binary_model/dependencies.html (2026-09-18)
- Profiles and settings: https://docs.conan.io/2/reference/config_files/profiles.html, https://docs.conan.io/2/reference/config_files/settings.html, https://docs.conan.io/2/reference/config_files/global_conf.html (2026-09-18)
- Remotes: https://docs.conan.io/2/reference/config_files/remotes.html, https://docs.conan.io/2/reference/commands/remote.html (2026-09-18)
- Commands: https://docs.conan.io/2/reference/commands.html, https://docs.conan.io/2/reference/commands/install.html, https://docs.conan.io/2/reference/commands/create.html, https://docs.conan.io/2/reference/commands/build.html, https://docs.conan.io/2/reference/commands/upload.html, https://docs.conan.io/2/reference/commands/profile.html, https://docs.conan.io/2/reference/commands/config.html, https://docs.conan.io/2/reference/commands/editable.html (2026-09-18)
- Lockfiles: https://docs.conan.io/2/tutorial/versioning/lockfiles.html (2026-09-18)
- Tools and generators: https://docs.conan.io/2/reference/tools.html, https://docs.conan.io/2/reference/tools/cmake/cmaketoolchain.html, https://docs.conan.io/2/reference/tools/meson/mesontoolchain.html (2026-09-18)
- Extensions: https://docs.conan.io/2/reference/extensions/python_requires.html, https://docs.conan.io/2/reference/extensions/custom_commands.html, https://docs.conan.io/2/reference/extensions/hooks.html (2026-09-18)
- ConanCenter: https://github.com/conan-io/conan-center-index (2026-09-18)
- Xmake integration: https://github.com/xmake-io/xmake/blob/dev/README.md, https://github.com/xmake-io/xmake/blob/dev/xmake/modules/package/manager/conan/configurations.lua, https://github.com/xmake-io/xmake/blob/dev/xmake/modules/package/manager/conan/v2/install_package.lua (2026-09-18)

### C. Xmake Conan Option Mapping

PolyOrch reaches Conan through Xmake, so the Xmake option names are the practical interface. The table below maps each option to its meaning, as documented in the Xmake source (source: https://github.com/xmake-io/xmake/blob/dev/xmake/modules/package/manager/conan/configurations.lua, 2026-09-18).

| Xmake option | Meaning | Conan 2 note |
|---|---|---|
| `remote` | Conan remote to resolve against | Corresponds to `conan remote` names |
| `build` | Build selector passed to the Conan install | Mirrors `conan install --build` |
| `options` | Recipe option values | Example in source: `shared=True` |
| `imports` | Copy rules for built artifacts | Deprecated in Conan 2.x per the source comment |
| `build_requires` | Tool requirements for the build | Emitted as `[tool_requires]` for Conan 2 |
| `settings` | Host settings for the resolution | Example: `compiler=msvc` |
| `settings_host` | Settings for the host context | Matches Conan host profile |
| `settings_build` | Settings for the build context | Matches Conan build profile |
| `conf`, `conf_host`, `conf_build` | Conan configuration values | Matches Conan `[conf]` entries |

For Conan 2, Xmake writes a generated `conanfile.txt` containing `[requires]`, `[options]`, `[imports]`, and `[tool_requires]`; the Conan 1 generation path writes `[build_requires]` instead (source: https://github.com/xmake-io/xmake/blob/dev/xmake/modules/package/manager/conan/v2/install_package.lua, 2026-09-18).

### D. Glossary

- **Recipe.** A `conanfile.py` that defines how a package is built and consumed (source: https://docs.conan.io/2/reference/conanfile.html, 2026-09-18).
- **Recipe revision.** A content-addressed revision of a recipe reference; references in lockfiles and listings include it (source: https://docs.conan.io/2/reference/binary_model/package_id.html, 2026-09-18).
- **`package_id`.** The identifier of a specific binary produced from a recipe, computed from settings and options (source: https://docs.conan.io/2/reference/binary_model/package_id.html, 2026-09-18).
- **`package_id_mode`.** The rule that decides whether a dependency change forces a consumer rebuild, defaulting from `package_type` (source: https://docs.conan.io/2/reference/binary_model/dependencies.html, 2026-09-18).
- **Remote.** A named package server entry in `remotes.json`, used for listing, uploading, and downloading (source: https://docs.conan.io/2/reference/config_files/remotes.html, 2026-09-18).
- **Profile.** A named file holding `[settings]`, `[options]`, and `[conf]` for a build configuration, maintained separately for host and build contexts (source: https://docs.conan.io/2/reference/config_files/profiles.html, 2026-09-18).
- **Lockfile.** A `conan.lock` file that pins resolved versions and revisions, strict by default (source: https://docs.conan.io/2/tutorial/versioning/lockfiles.html, 2026-09-18).
- **Generator.** A recipe tool, such as `CMakeDeps` or `CMakeToolchain`, that writes files the build system consumes (source: https://docs.conan.io/2/reference/tools.html, 2026-09-18).
- **`tool_requires`.** The Conan 2 name for build-context executable requirements, replacing Conan 1 `build_requires` (source: https://docs.conan.io/2/reference/conanfile_txt.html, 2026-09-18).
- **`package_type`.** The classification of a package (application, library, and so on) that drives `package_id_mode` and trait propagation (source: https://docs.conan.io/2/reference/conanfile/attributes.html, 2026-09-18).
