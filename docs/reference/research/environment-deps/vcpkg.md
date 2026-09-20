# vcpkg Profile

> Sources: https://github.com/microsoft/vcpkg, https://github.com/microsoft/vcpkg-tool,
> https://learn.microsoft.com/en-us/vcpkg/, https://vcpkg.io/en/, researched 2026-09-18
> Not a derived document: facts here are externally sourced.

## 1. Product Profile

vcpkg is a free and open-source C/C++ package manager maintained by Microsoft and the C++
community. It runs on Windows, macOS, and Linux. The official documentation describes it as
"a C++ tool at heart" that "is written using C++ and CMake scripts", designed to address the
unique pain points of managing C/C++ libraries
(source: https://learn.microsoft.com/en-us/vcpkg/get_started/overview, 2026-09-18).

| Field | Value |
|---|---|
| Name | vcpkg |
| Ports repository | https://github.com/microsoft/vcpkg |
| Tool source repository | https://github.com/microsoft/vcpkg-tool |
| License | MIT for the repository code; ported libraries keep their original authors' licenses (source: https://github.com/microsoft/vcpkg, 2026-09-18) |
| Maintainer | Microsoft and the C++ community (source: https://learn.microsoft.com/en-us/vcpkg/get_started/overview, 2026-09-18) |
| Latest ports release | "2026-07-29 Release" (source: https://github.com/microsoft/vcpkg/releases.atom, 2026-09-18) |
| Latest tool release | "2026-07-27 Release" (source: https://github.com/microsoft/vcpkg-tool/releases.atom, 2026-09-18) |
| Release model | Rolling, date-stamped releases rather than semantic versioning (source: https://github.com/microsoft/vcpkg/releases.atom, 2026-09-18) |
| Primary configuration | `vcpkg.json` manifest, plus `vcpkg-configuration.json`; ports and registries |
| Supported hosts | Windows, macOS, Linux (source: https://learn.microsoft.com/en-us/vcpkg/get_started/overview, 2026-09-18) |
| Catalog size | The official site states 2862 open source libraries as of 2026-09-18 (source: https://vcpkg.io/en/, 2026-09-18) |

The project is split into two repositories. The `microsoft/vcpkg` repository hosts the curated
registry of ports; its README lists "Ports: Microsoft/vcpkg" and "Source code:
Microsoft/vcpkg-tool" (source: https://github.com/microsoft/vcpkg, 2026-09-18). The
`microsoft/vcpkg-tool` README states that it "contains the contents formerly at
https://github.com/microsoft/vcpkg in the 'toolsrc' tree, and build support"
(source: https://github.com/microsoft/vcpkg-tool, 2026-09-18). This split matters for any
consumer that tries to identify the implementation language of the project.

## 2. Technical Characteristics

### Overall Architecture

vcpkg has three cooperating layers:

1. **The vcpkg tool** (executable). This is the CLI that resolves dependency graphs, applies
   version constraints, drives builds, and manages installation trees. Its source lives in the
   separate `microsoft/vcpkg-tool` repository
   (source: https://github.com/microsoft/vcpkg-tool, 2026-09-18).
2. **The ports registry**. The `microsoft/vcpkg` repository is the curated registry: a
   collection of ports, each a directory containing a `vcpkg.json` metadata file and a
   `portfile.cmake` build script. A portfile "is a script that contains instructions on how to
   build and install a package within the vcpkg environment"
   (source: https://learn.microsoft.com/en-us/vcpkg/concepts/ports, 2026-09-18).
3. **The version databases and baselines**. Every registry contains a
   `versions/baseline.json` file and a `versions/` database that record the version that is
   considered current for each port
   (source: https://learn.microsoft.com/en-us/vcpkg/concepts/registries, 2026-09-18). A live
   sample of the curated baseline shows entries such as `zlib` at baseline `1.3.2` with
   `port-version` 2 (source: https://raw.githubusercontent.com/microsoft/vcpkg/master/versions/baseline.json, 2026-09-18).

Two operation modes exist (source: https://learn.microsoft.com/en-us/vcpkg/users/manifests, 2026-09-18):

- **Classic mode**: installs packages into a single global `installed` tree, keyed by triplet.
  Only one version of a port can be installed at a time in this mode.
- **Manifest mode**: declarative, driven by a `vcpkg.json` file. The documentation recommends
  manifest mode for most users and notes that it is required for versioning and custom
  registries. Each manifest gets its own `vcpkg_installed` directory created next to the
  manifest file, which allows different projects to depend on different versions of the same
  port (source: https://learn.microsoft.com/en-us/vcpkg/users/manifests, 2026-09-18).

The tool is distributed as date-stamped releases. Both the ports repository and the tool
repository publish releases named by date, for example "2026-07-29 Release" for ports and
"2026-07-27 Release" for the tool
(source: https://github.com/microsoft/vcpkg/releases.atom and https://github.com/microsoft/vcpkg-tool/releases.atom, 2026-09-18).

### Key Capabilities

- **Manifest-driven dependency declaration**: `vcpkg.json` lists dependencies, features, and
  optional version constraints. `vcpkg install` with no package arguments installs everything
  declared in the manifest (source: https://learn.microsoft.com/en-us/vcpkg/users/manifests, 2026-09-18).
- **Catalog-wide versioning**: vcpkg lets a project depend on a version set of compatible
  packages rather than micromanaging individual versions, while still allowing explicit pins
  (source: https://learn.microsoft.com/en-us/vcpkg/get_started/overview, 2026-09-18).
- **Binary caching**: built packages are cached and reused. Documented configurations include a
  local binary cache, a NuGet feed, and GitHub Packages
  (source: https://learn.microsoft.com/en-us/vcpkg/users/binarycaching, 2026-09-18).
- **Asset caching**: download mirrors let vcpkg operate in air-gapped and offline environments
  (source: https://learn.microsoft.com/en-us/vcpkg/users/assetcaching, 2026-09-18).
- **Custom registries**: the curated registry can be extended with Git or filesystem registries
  (source: https://learn.microsoft.com/en-us/vcpkg/concepts/registries, 2026-09-18).
- **Triplets**: a triplet is a target configuration (platform, architecture, linkage). Defaults
  are `x64-windows` on Windows, `x64-linux` on Linux, and `x64-osx` on macOS
  (source: https://learn.microsoft.com/en-us/vcpkg/concepts/triplets, 2026-09-18).
- **Multiple copies of a library on one system**: vcpkg can hold several versions of the same
  dependency, where system package managers typically install a single system-wide copy
  (source: https://learn.microsoft.com/en-us/vcpkg/get_started/overview, 2026-09-18).

### Tech Stack

| Aspect | Detail | Source |
|---|---|---|
| Tool implementation | C++ and CMake scripts (the documentation's own wording) | https://learn.microsoft.com/en-us/vcpkg/get_started/overview (2026-09-18) |
| Tool repository layout | C++ sources under a CMake build, formerly the `toolsrc` tree | https://github.com/microsoft/vcpkg-tool (2026-09-18) |
| Port build scripts | `portfile.cmake`, a CMake script per port | https://learn.microsoft.com/en-us/vcpkg/concepts/ports (2026-09-18) |
| Metadata format | JSON (`vcpkg.json`, `vcpkg-configuration.json`, `versions/*.json`) | https://learn.microsoft.com/en-us/vcpkg/reference/vcpkg-json (2026-09-18) |

**Implementation-language nuance (important).** The `microsoft/vcpkg` repository is dominated
by CMake portfiles, one `portfile.cmake` per port, so repository language statistics classify
that repository as a CMake codebase. The executable tool is not CMake: it is the C++ code in
the separate `microsoft/vcpkg-tool` repository, and the official overview describes the project
as written using C++ and CMake scripts
(source: https://learn.microsoft.com/en-us/vcpkg/get_started/overview and
https://github.com/microsoft/vcpkg-tool, 2026-09-18). Do not claim CMake is the implementation
language of vcpkg without stating that the CMake content is the port recipes and the build
glue, not the package manager itself.

## 3. Feature Overview

### Core Modules

| Module | Role | Source |
|---|---|---|
| `vcpkg.json` | Project or port manifest: name, version, dependencies, features, overrides, optional `builtin-baseline` | https://learn.microsoft.com/en-us/vcpkg/reference/vcpkg-json (2026-09-18) |
| `vcpkg-configuration.json` | Registry and overlay configuration: `default-registry`, `registries`, `overlay-ports`, `overlay-triplets` | https://learn.microsoft.com/en-us/vcpkg/reference/vcpkg-configuration-json (2026-09-18) |
| `portfile.cmake` | Per-port build and install script | https://learn.microsoft.com/en-us/vcpkg/concepts/ports (2026-09-18) |
| `versions/baseline.json` | Registry-wide version floor: the version considered current for every port | https://learn.microsoft.com/en-us/vcpkg/concepts/registries (2026-09-18) |
| `versions/<letter>-/<port>.json` | Per-port version history used by the versioning resolver | https://learn.microsoft.com/en-us/vcpkg/concepts/registries (2026-09-18) |
| Triplets (`triplets/`, `triplets/community`, overlay triplets) | Target configuration definitions | https://learn.microsoft.com/en-us/vcpkg/concepts/triplets (2026-09-18) |

A port may be a **standard port** (builds and installs one library), a **meta port** (imposes
constraints on the install graph without its own build files, for example `boost` grouping
related libraries), or a **script port** (a port that runs a script)
(source: https://learn.microsoft.com/en-us/vcpkg/concepts/ports, 2026-09-18).

### Notable Features

**Versioning schemes.** A manifest declares exactly one version property. The supported schemes
are (source: https://learn.microsoft.com/en-us/vcpkg/users/versioning, 2026-09-18):

| Manifest property | Scheme |
|---|---|
| `version` | Dot-separated numeric versions, for example `1.2.3` |
| `version-semver` | SemVer-compliant versions |
| `version-date` | Dates in `YYYY-MM-DD` form |
| `version-string` | Arbitrary strings |

By design, vcpkg does not compare versions that use different schemes: a package declaring
`version-string: 7.1.3` cannot be compared with the same package declaring `version: 7.1.4`,
even when the conversion looks obvious (source: https://learn.microsoft.com/en-us/vcpkg/users/versioning, 2026-09-18).

**Port versions.** A separate `port-version` axis tracks changes to packaging files
(`vcpkg.json`, `portfile.cmake`) without any change to the upstream library version. It starts
at 0 and resets to 0 whenever the package version changes. vcpkg text format is
`<version>#<port version>`, so `1.2.0#2` means version 1.2.0, port-version 2
(source: https://learn.microsoft.com/en-us/vcpkg/users/versioning, 2026-09-18).

**Baselines and constraints.** A baseline defines a global version floor for the dependency
graph. The `builtin-baseline` field names a commit of the curated registry that provides global
minimum version information, and is required for top-level manifests that use versioning
without an explicit default registry
(source: https://learn.microsoft.com/en-us/vcpkg/reference/vcpkg-json, 2026-09-18). Per-dependency
constraints use `version>=` for a minimum version and `overrides` for exact pins; overrides
from transitive manifests are ignored, only the top-level project's overrides apply
(source: https://learn.microsoft.com/en-us/vcpkg/reference/vcpkg-json, 2026-09-18).

**Registries.** There are three registry kinds: the built-in registry (the local curated clone),
Git registries, and filesystem registries
(source: https://learn.microsoft.com/en-us/vcpkg/concepts/registries, 2026-09-18). All registries
must contain `versions/baseline.json`. For Git registries and the built-in registry, the
baseline is a 40-character git commit sha; filesystem registries may use any valid JSON property
name and default to `"default"` when unspecified
(source: https://learn.microsoft.com/en-us/vcpkg/reference/vcpkg-configuration-json, 2026-09-18).

**Binary caching.** Beyond a local cache, the documentation offers NuGet feeds and GitHub
Packages. The docs also warn that binary caching is "not recommended as a binary distribution
mechanism" even though build output can be reused across systems
(source: https://learn.microsoft.com/en-us/vcpkg/users/binarycaching, 2026-09-18).

**Asset caching.** Download mirrors allow vcpkg to work in air-gapped and offline environments
by uploading and restoring source code and build tools
(source: https://learn.microsoft.com/en-us/vcpkg/users/assetcaching, 2026-09-18).

**Build system integration.** vcpkg documents CMake integration (a toolchain file and
`VCPKG_TARGET_TRIPLET`), MSBuild integration via `vcpkg integrate install`, and a manual
integration path for other build systems
(source: https://learn.microsoft.com/en-us/vcpkg/concepts/build-system-integration and
https://learn.microsoft.com/en-us/vcpkg/users/manifests, 2026-09-18). Editor integrations
documented by the README include Visual Studio, Visual Studio Code, CLion, and Qt Creator
(source: https://github.com/microsoft/vcpkg, 2026-09-18).

**Features.** Ports can declare optional features with their own dependencies, and manifests can
enable a dependency's features or disable its defaults through dependency fields such as
`default-features` and `features`
(source: https://learn.microsoft.com/en-us/vcpkg/reference/vcpkg-json, 2026-09-18).

### Extensibility / Plugin Mechanism

vcpkg does not expose a dynamic plugin API. Extension happens through declarative artifacts and
scripts:

- **Custom registries** registered through `vcpkg-configuration.json` extend the available port
  set while preserving versioning and binary caching behavior
  (source: https://learn.microsoft.com/en-us/vcpkg/concepts/registries, 2026-09-18).
- **Overlay ports** let a project substitute or add a port locally without editing the upstream
  registry (source: https://learn.microsoft.com/en-us/vcpkg/reference/vcpkg-configuration-json, 2026-09-18).
- **Overlay triplets** add or replace triplet definitions
  (source: https://learn.microsoft.com/en-us/vcpkg/concepts/triplets, 2026-09-18).
- **`portfile.cmake` scripts** are the per-port extension point for download, build, patch, and
  install logic (source: https://learn.microsoft.com/en-us/vcpkg/concepts/ports, 2026-09-18).

## 4. Status & Ecosystem

The project is actively released. The ports repository publishes rolling date-stamped releases;
the feed shows "2026-07-29 Release" followed by "2026.06.24 Release" and earlier entries, and the
tool repository similarly shows "2026-07-27 Release", "2026-07-24 Release", "2026-07-13 Release",
and earlier (source: https://github.com/microsoft/vcpkg/releases.atom and
https://github.com/microsoft/vcpkg-tool/releases.atom, 2026-09-18). The date-stamped naming is
the release model; do not read SemVer ordering into these names.

The catalog is large and community-fed. The official website states 2862 open source libraries
available for download and build in a single step as of 2026-09-18, maintained by the C++ team
and open source contributors (source: https://vcpkg.io/en/, 2026-09-18). Because this is a live
counter, treat the number as a dated observation rather than a fixed property.

The documentation is hosted at Microsoft Learn and is itself open source, with an "Edit" link on
each page pointing into the `MicrosoftDocs/vcpkg-docs` repository
(source: https://learn.microsoft.com/en-us/vcpkg/get_started/overview, 2026-09-18). The README
lists community channels (a Discord channel on the #include <C++> server and a Slack channel),
a website, and an email address (source: https://github.com/microsoft/vcpkg, 2026-09-18).

Supported hosts are Windows, macOS, and Linux
(source: https://learn.microsoft.com/en-us/vcpkg/get_started/overview, 2026-09-18). Community
triplets exist in a `triplets/community` folder; they are not covered by the curated registry's
continuous integration and port updates may break them, and a warning is printed when one is
used (source: https://learn.microsoft.com/en-us/vcpkg/concepts/triplets, 2026-09-18).

## 5. Market Positioning

vcpkg positions itself as a C/C++ specialist rather than a general system package manager. The
official overview compares it to system package managers and claims none of them deliver all of
the following: redistributable developer assets for debugging, prebuilt packages versus building
from source, catalog-wide versioning, multiple copies of the same library on one system, and a
large catalog (source: https://learn.microsoft.com/en-us/vcpkg/get_started/overview, 2026-09-18).

Its practical differentiators are Microsoft backing, tight CMake and MSBuild integration, a large
curated port catalog, manifest-based reproducibility, and binary caching. In the C/C++ package
manager space it is commonly evaluated alongside Conan; PolyOrch treats both as dependency
sources rather than competitors, reachable through the Xmake `vcpkg::` and `conan::` namespaces.

Within PolyOrch's stack, vcpkg occupies the C/C++ dependency slot. It is not an environment
manager (that is Pixi's role) and not a build orchestrator. Its relevance is the port catalog and
the versioning and caching semantics that the orchestrator must respect when it delegates
dependency resolution.

## 6. Product Highlights

- A single manifest (`vcpkg.json`) declares dependencies, features, version pins, and an
  optional baseline, making dependency state reviewable in source control
  (source: https://learn.microsoft.com/en-us/vcpkg/reference/vcpkg-json, 2026-09-18).
- Per-project `vcpkg_installed` trees remove the classic-mode restriction of one installed
  version per port, enabling version separation across projects
  (source: https://learn.microsoft.com/en-us/vcpkg/users/manifests, 2026-09-18).
- A machine-readable registry baseline (`versions/baseline.json`) plus per-port version files
  gives an orchestrator a deterministic way to compute the intended version set
  (source: https://learn.microsoft.com/en-us/vcpkg/concepts/registries, 2026-09-18).
- Binary caching turns repeated C/C++ builds into cache hits across machines and CI
  (source: https://learn.microsoft.com/en-us/vcpkg/users/binarycaching, 2026-09-18).
- Asset caching makes reproducible offline and air-gapped builds possible
  (source: https://learn.microsoft.com/en-us/vcpkg/users/assetcaching, 2026-09-18).
- The ports registry is itself a Git repository, so a baseline is expressible as a commit sha
  that fully identifies the intended port set
  (source: https://learn.microsoft.com/en-us/vcpkg/concepts/registries, 2026-09-18).

## 7. Value to PolyOrch

PolyOrch is a build orchestrator for polyglot monorepos. It dispatches CMake, Xmake, Meson, and
Colcon through adapters, uses Xmake as its native build engine, uses Pixi for environments, and
reaches C/C++ dependency sources through Xmake's `vcpkg::` and `conan::` namespaces.

### [Adopt] Directly reusable

- **Adopt manifest mode as the dependency contract.** Require each PolyOrch workspace member
  that consumes C/C++ libraries to carry a `vcpkg.json`, and have the orchestrator parse it
  rather than scraping build logs. Manifest mode is the documented recommended path and is the
  precondition for versioning and registries
  (source: https://learn.microsoft.com/en-us/vcpkg/users/manifests, 2026-09-18). Action: add
  `vcpkg.json` as a first-class recognized dependency file in PolyOrch's project model.
- **Adopt the per-project `vcpkg_installed` isolation model.** Mirror vcpkg's per-manifest
  installation tree in PolyOrch's workspace layout so two members can depend on different
  versions of the same port. Action: key PolyOrch's artifact and include paths on the manifest
  root, not on a global installed directory
  (source: https://learn.microsoft.com/en-us/vcpkg/users/manifests, 2026-09-18).
- **Adopt the baseline commit sha as the reproducibility anchor.** Record the `builtin-baseline`
  or registry baseline commit in PolyOrch's lock data so a build can be reproduced exactly.
  Action: treat the baseline sha as part of PolyOrch's dependency lock, and provide a command to
  bump it deliberately
  (source: https://learn.microsoft.com/en-us/vcpkg/reference/vcpkg-json, 2026-09-18).
- **Adopt the triplet as a first-class build dimension.** Default to `x64-windows`,
  `x64-linux`, and `x64-osx` by host, and make the triplet part of target identity. Action:
  include the triplet in every PolyOrch build graph node and cache key
  (source: https://learn.microsoft.com/en-us/vcpkg/concepts/triplets, 2026-09-18).
- **Adopt `vcpkg-configuration.json` semantics for registry routing.** Support
  `default-registry`, `registries`, `overlay-ports`, and `overlay-triplets` as understood
  configuration, and let PolyOrch surface them per workspace. Action: read and validate this file
  before dispatching dependency installs
  (source: https://learn.microsoft.com/en-us/vcpkg/reference/vcpkg-configuration-json, 2026-09-18).
- **Adopt binary caching as the default C/C++ build accelerator.** Configure vcpkg binary
  caching from PolyOrch's environment so CI and developer machines share artifacts. Action:
  expose a binary cache source in PolyOrch configuration and make the cache key include
  baseline, triplet, features, and compiler
  (source: https://learn.microsoft.com/en-us/vcpkg/users/binarycaching, 2026-09-18).
- **Adopt asset caching for offline and air-gapped builds.** Use vcpkg's download mirrors to
  keep dependency fetching reproducible without direct internet access. Action: make asset
  caching an opt-in PolyOrch mode for restricted environments
  (source: https://learn.microsoft.com/en-us/vcpkg/users/assetcaching, 2026-09-18).
- **Adopt custom registries and overlay ports for private dependencies.** Let a monorepo publish
  internal ports through a Git registry and patch upstream ports through overlays instead of
  forking. Action: document a per-workspace registry layout in PolyOrch
  (source: https://learn.microsoft.com/en-us/vcpkg/concepts/registries, 2026-09-18).
- **Adopt the features and default-features model for dependency variants.** Represent optional
  capabilities as vcpkg features rather than as separate ad hoc libraries, so PolyOrch can
  compute variant-aware dependency graphs. Action: map workspace feature flags onto vcpkg
  dependency `features` and `default-features`
  (source: https://learn.microsoft.com/en-us/vcpkg/reference/vcpkg-json, 2026-09-18).
- **Adopt the documented host triplet defaults in environment setup.** When PolyOrch prepares a
  build environment through Pixi, set the expected default triplet so dependency resolution is
  predictable across hosts
  (source: https://learn.microsoft.com/en-us/vcpkg/concepts/triplets, 2026-09-18).

### [Adapt] Reusable with modification

- **Adapt to heterogeneous version schemes.** vcpkg refuses to compare versions across schemes.
  PolyOrch's resolver must carry the declared scheme alongside every version it records and must
  never silently normalize between `version`, `version-semver`, `version-date`, and
  `version-string`. Action: store a `(scheme, value)` pair in PolyOrch lock entries
  (source: https://learn.microsoft.com/en-us/vcpkg/users/versioning, 2026-09-18).
- **Adapt the port-version axis.** Treat `port-version` as a distinct packaging revision that is
  independent of the upstream version, and surface it in lock output. Action: render versions as
  `version#port-version` wherever PolyOrch reports resolved C/C++ dependencies
  (source: https://learn.microsoft.com/en-us/vcpkg/users/versioning, 2026-09-18).
- **Adapt Xmake's generated manifest behavior.** Xmake's vcpkg manager generates a `vcpkg.json`
  with a `builtin-baseline` and exact-version `overrides` when a version is requested, and it
  writes `vcpkg-configuration.json` when registries are configured
  (source: https://raw.githubusercontent.com/xmake-io/xmake/master/xmake/modules/package/manager/vcpkg/install_package.lua, 2026-09-18).
  PolyOrch should not let that generated baseline float: expose it in configuration and pin it.
  Action: read Xmake's generated manifest and record its baseline into PolyOrch's lock, allowing
  a configured override.
- **Adapt Xmake's configuration surface instead of inventing a parallel one.** Xmake's vcpkg
  manager exposes `baseline`, `features`, `default_features`, `registries`, and
  `default_registries`
  (source: https://raw.githubusercontent.com/xmake-io/xmake/master/xmake/modules/package/manager/vcpkg/configurations.lua, 2026-09-18).
  Map PolyOrch dependency options onto these names rather than creating a competing vocabulary.
  Action: document the mapping in PolyOrch's vcpkg adapter.
- **Adapt the Xmake `vcpkg::` namespace as the integration boundary.** Xmake synthesizes
  `vcpkg::<port>` identifiers for discovered packages, for example in its search path
  (source: https://raw.githubusercontent.com/xmake-io/xmake/master/xmake/modules/package/manager/vcpkg/search_package.lua, 2026-09-18).
  PolyOrch should treat `vcpkg::name version` and `configs` as the authored interface, and treat
  the generated files as an implementation detail. Action: implement the adapter at the
  `add_requires` level and let Xmake own manifest generation.
- **Adapt manifest-mode version pinning awareness to Xmake versions.** The Xmake changelog for
  v2.6.3 records "Support vcpkg manifest mode and select version for package/install". PolyOrch
  must require a recent-enough Xmake and detect older engines. Action: add an Xmake version floor
  check to the vcpkg integration
  (source: https://raw.githubusercontent.com/xmake-io/xmake/master/CHANGELOG.md, 2026-09-18).
- **Adapt classic mode only as a legacy fallback.** Classic mode's single global installed tree
  cannot represent a polyglot monorepo's per-member version needs. PolyOrch may read a classic
  tree for migration, but must not build on it. Action: mark classic mode deprecated in PolyOrch
  config and warn
  (source: https://learn.microsoft.com/en-us/vcpkg/users/manifests, 2026-09-18).
- **Adapt the tool/ports split into two pinned versions.** The ports registry and the tool
  release on independent date-stamped cadences, so a baseline pin and a tool pin are distinct.
  Action: record both in PolyOrch's lock and allow independent upgrades
  (source: https://github.com/microsoft/vcpkg/releases.atom and
  https://github.com/microsoft/vcpkg-tool/releases.atom, 2026-09-18).
- **Adapt binary cache credentials to the environment layer.** A NuGet or GitHub Packages cache
  requires credentials that must not be hardcoded. Action: source cache credentials from
  PolyOrch's environment and secret management (Pixi and the host environment), never from
  committed config
  (source: https://learn.microsoft.com/en-us/vcpkg/users/binarycaching, 2026-09-18).
- **Adapt platform expressions to the polyglot platform matrix.** vcpkg manifests can express
  platform conditions and supported platforms. Action: map vcpkg platform expressions to
  PolyOrch's target matrix so a single workspace can express per-platform dependency rules
  (source: https://learn.microsoft.com/en-us/vcpkg/reference/vcpkg-json, 2026-09-18).
- **Adapt registry baselines for filesystem registries.** A filesystem registry may use a named
  baseline other than the Git sha, defaulting to `"default"`. Action: have PolyOrch's registry
  reader accept both a 40-character Git sha and a filesystem baseline name
  (source: https://learn.microsoft.com/en-us/vcpkg/reference/vcpkg-configuration-json, 2026-09-18).
- **Adapt the meta port and script port categories in graph modeling.** A meta port imposes
  constraints with no build of its own, and a script port runs a script. Action: model meta ports
  as graph-only nodes in PolyOrch so scheduling does not wait on a nonexistent build
  (source: https://learn.microsoft.com/en-us/vcpkg/concepts/ports, 2026-09-18).

### [Avoid] Known pitfalls / not applicable

- **Avoid classifying `microsoft/vcpkg` as a CMake implementation.** The repository is dominated
  by CMake portfiles, so language statistics report CMake, but the tool is C++ and lives in
  `microsoft/vcpkg-tool`. Action: never derive PolyOrch's language or tooling assumptions from
  the ports repository's language statistics
  (source: https://learn.microsoft.com/en-us/vcpkg/get_started/overview and
  https://github.com/microsoft/vcpkg-tool, 2026-09-18).
- **Avoid parsing `portfile.cmake` internals for dependency data.** The portfile is a build
  script, not a stable metadata contract. Action: read `vcpkg.json` and the versions database for
  metadata, and treat portfiles as black-box recipes
  (source: https://learn.microsoft.com/en-us/vcpkg/concepts/ports, 2026-09-18).
- **Avoid assuming a global installed tree in manifest mode.** Manifest installs land in
  `vcpkg_installed` next to the manifest, not in the global `installed` directory. Action: have
  PolyOrch discover include and library paths relative to the manifest root
  (source: https://learn.microsoft.com/en-us/vcpkg/users/manifests, 2026-09-18).
- **Avoid semantic-version assumptions about vcpkg itself.** Releases are date-stamped, not
  SemVer, for both ports and the tool. Action: compare release dates and commit shas, not version
  ordering
  (source: https://github.com/microsoft/vcpkg/releases.atom, 2026-09-18).
- **Avoid normalizing version strings across schemes.** vcpkg will not compare versions that use
  different schemes. Action: store the scheme and refuse to rank mixed-scheme versions in
  PolyOrch's resolver
  (source: https://learn.microsoft.com/en-us/vcpkg/users/versioning, 2026-09-18).
- **Avoid depending on community triplets for production builds.** Community triplets are not
  covered by continuous integration and may break on port updates. Action: restrict PolyOrch's
  supported triplet set to tested ones and make community triplets an explicit opt-in
  (source: https://learn.microsoft.com/en-us/vcpkg/concepts/triplets, 2026-09-18).
- **Avoid legacy `CONTROL` files.** Port metadata is expressed by `vcpkg.json`; `CONTROL` is
  documented as the older mechanism. Action: ignore `CONTROL` in PolyOrch's port reader
  (source: https://learn.microsoft.com/en-us/vcpkg/concepts/ports, 2026-09-18).
- **Avoid treating binary caching as a distribution channel.** The documentation explicitly
  warns it is not recommended as a binary distribution mechanism. Action: use vcpkg binary caches
  for build acceleration only, and use a deliberate artifact channel for releases
  (source: https://learn.microsoft.com/en-us/vcpkg/users/binarycaching, 2026-09-18).
- **Avoid editing upstream ports in place.** Local modifications should go through overlay ports
  so upstream updates do not conflict. Action: forbid in-place edits to the curated registry in
  PolyOrch workflows and require overlay ports
  (source: https://learn.microsoft.com/en-us/vcpkg/reference/vcpkg-configuration-json, 2026-09-18).
- **Avoid assuming ABI portability across triplets or hosts.** Binary cache entries are tied to
  target configuration, so a cache hit is not universal. Action: include triplet, compiler, and
  feature set in every PolyOrch cache key and never share a cache entry across triplets
  (source: https://learn.microsoft.com/en-us/vcpkg/users/binarycaching, 2026-09-18).
- **Avoid hardcoding baseline shas or registry URLs in PolyOrch source.** Xmake currently ships
  a default vcpkg baseline constant in its vcpkg install module, and that value changes over
  time. Action: make the baseline configurable and let PolyOrch pin it per workspace rather than
  relying on any tool's default
  (source: https://raw.githubusercontent.com/xmake-io/xmake/master/xmake/modules/package/manager/vcpkg/install_package.lua, 2026-09-18).

## Appendix

### A. Xmake integration facts (independent verification)

The PolyOrch reference index records that Xmake's `vcpkg::` and `conan::` namespaces are
confirmed real, from the Xmake documentation `using-third-party-packages.md`, researched
2026-09-18 (source: PolyOrch `docs/reference/README.md` verified anchors, 2026-09-18). The
recorded confirmed syntax includes `add_requires("vcpkg::zlib", "vcpkg::pcre2")`, manifest-mode
version pinning since Xmake v2.6.3 such as `add_requires("vcpkg::zlib 1.2.11")`, feature
selection via `{configs = {features = {"apng"}}}` on `vcpkg::libpng`, and custom registries via
`configs.registries`.

Independent checks against the Xmake repository corroborate the mechanism:

| Claim | Evidence | Source |
|---|---|---|
| Xmake generates `vcpkg::<port>` identifiers | `search_package.lua` prefixes results with `vcpkg::` | https://raw.githubusercontent.com/xmake-io/xmake/master/xmake/modules/package/manager/vcpkg/search_package.lua (2026-09-18) |
| Xmake supports vcpkg manifest mode and version selection | v2.6.3 changelog entry "Support vcpkg manifest mode and select version for package/install" | https://raw.githubusercontent.com/xmake-io/xmake/master/CHANGELOG.md (2026-09-18) |
| Xmake generates a manifest with a baseline | `install_package.lua` writes `vcpkg.json` containing `builtin-baseline` | https://raw.githubusercontent.com/xmake-io/xmake/master/xmake/modules/package/manager/vcpkg/install_package.lua (2026-09-18) |
| Xmake exposes registry configuration | `configurations.lua` declares `registries` and `default_registries` | https://raw.githubusercontent.com/xmake-io/xmake/master/xmake/modules/package/manager/vcpkg/configurations.lua (2026-09-18) |
| Xmake exposes baseline and feature configuration | `configurations.lua` declares `baseline`, `features`, `default_features` | https://raw.githubusercontent.com/xmake-io/xmake/master/xmake/modules/package/manager/vcpkg/configurations.lua (2026-09-18) |

The Xmake vcpkg manager module set lives under
`xmake/modules/package/manager/vcpkg/` and contains `configurations.lua`, `find_package.lua`,
`install_package.lua`, `search_package.lua`, and `utils.lua`
(source: https://raw.githubusercontent.com/xmake-io/xmake/master/xmake/modules/package/manager/vcpkg/, 2026-09-18).

### B. Versioning scheme reference

| Scheme | Accepts | Sorting | Example |
|---|---|---|---|
| `version` | Dot-separated numeric sections, no leading zeroes | Numeric per section, left to right | `0` < `0.1` < `1.0.0` < `1.1` |
| `version-semver` | SemVer-compliant strings | Per the SemVer specification | `1.0.0-1` < `1.0.0-alpha` < `1.0.0` |
| `version-date` | ISO-8601 `YYYY-MM-DD`, disambiguation allowed | Date order, then relaxed scheme rules | `2021-01-01` < `2021-02-01` |
| `version-string` | Arbitrary strings, `#` disallowed | No sorting of the string; only port versions compare | `watermelon#0` < `watermelon#1` |

(source: https://learn.microsoft.com/en-us/vcpkg/users/versioning, 2026-09-18)

### C. Release history observed on 2026-09-18

| Repository | Recent release titles (newest first) |
|---|---|
| `microsoft/vcpkg` | 2026-07-29 Release, 2026.06.24 Release, 2026.06.01 Release, 2026.05.25 Release, 2026.04.27 Release, 2026.03.18 Release |
| `microsoft/vcpkg-tool` | 2026-07-27 Release, 2026-07-24 Release, 2026-07-13 Release, 2026-05-27 Release, 2026-04-08 Release, 2026-04-06 Release |

(source: https://github.com/microsoft/vcpkg/releases.atom and
https://github.com/microsoft/vcpkg-tool/releases.atom, 2026-09-18)
