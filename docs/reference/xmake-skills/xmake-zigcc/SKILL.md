---
name: xmake-zigcc
description: Use when compiling C/C++ with `zig cc` / `zig c++` in Xmake, or cross-compiling to another platform with zig as the cross compiler — `--toolchain=zigcc`, the `-target` tuple xmake derives from `-p/-a`, and when `--cross=<tuple>` is required. Also covers the `zig` toolchain for Zig code.
---

# Zig / Zig CC Toolchains

Xmake has two zig toolchains and they are not interchangeable:

| Toolchain | For | Toolset |
| --- | --- | --- |
| `zig` | Zig source code (`.zig`) | `zig build-exe`, `zig build-lib` … |
| `zigcc` | C/C++ source code | `zig cc`, `zig c++`, plus `ar`/`ranlib`/`objcopy`/`lld` |

## C/C++ with zig cc

```bash
xmake f --toolchain=zigcc -c
xmake
```

`zigcc` wires up the whole toolset, so static and shared libraries build too. Point at a
specific zig with `--zc`:

```bash
xmake f --toolchain=zigcc --zc=/opt/zig/zig -c
```

::: warning
Do not hand-set the tools with `--cc="zig cc" --cxx="zig c++" --ld="zig c++"`. That patches
three tools only: no `ar`/`ranlib`, and none of the `-target` handling below.
:::

## Cross-compiling with zig cc

zig cc *is* a cross compiler — it ships its own libc and headers, so no sysroot, no
cross-gcc, no `--sdk`. All xmake has to do is pass the right `-target <tuple>`.

For the platforms xmake knows, the tuple comes from `-p` + `-a`:

```bash
xmake f -p linux   -a arm64  --toolchain=zigcc -c
xmake f -p macosx  -a arm64  --toolchain=zigcc -c
xmake f -p windows -a x86_64 --toolchain=zigcc -c
xmake f -p mingw   -a x86_64 --toolchain=zigcc -c
xmake
```

| Platform | Tuple xmake passes |
| --- | --- |
| `linux` | `<arch>-linux-gnu` (`arm-linux-gnueabi`, `mips64-linux-gnuabi64`) |
| `macosx` | `<arch>-macos-none` |
| `windows` | `<arch>-windows-msvc` |
| `mingw` | `<arch>-windows-gnu` |

Arch names are translated too: `arm64` → `aarch64`, `arm` → `arm`, `ppc64` → `powerpc64`,
`loong64` → `loongarch64`, and `i386` → `x86` on zig >= 0.11.

For anything else, give the tuple yourself with `--cross`, it is passed through as-is:

```bash
xmake f -p cross   --cross=riscv64-linux-musl --toolchain=zigcc
xmake f -p freebsd --cross=x86_64-freebsd     --toolchain=zigcc
xmake f -p linux   --cross=x86_64-linux-musl  --toolchain=zigcc   # musl instead of gnu
xmake
```

::: warning
A platform outside the table above (e.g. `freebsd`) has **no** tuple of its own. Without
`--cross` no `-target` is passed at all, and xmake falls back to looking for a native
toolchain of that platform — the symptom is `error: toolchain not found!`.
:::

Pin a libc version when you need to run on older systems:

```bash
xmake f -p linux --cross=x86_64-linux-gnu.2.17 --toolchain=zigcc
```

## Zig code

```bash
xmake f --toolchain=zig -c            # explicit, it is auto-detected for .zig projects
xmake f --toolchain=zig --zc=/opt/zig/zig -c
xmake f --toolchain=zig -a arm64 -c
xmake f -p cross --cross=riscv64-linux-musl --toolchain=zig
```

```lua
target("hello")
    set_kind("binary")
    add_files("src/*.zig")
```

Zig can also consume C sources in the same target (C interop), and C targets can link zig
static libraries.

## Gotchas

- `--toolchain=zig` for `.zig` files, `--toolchain=zigcc` for C/C++ — mixing them up is the
  most common mistake.
- macOS targets use `-macos-none`: linking against system frameworks still needs the real
  SDK, so cross-compiling *to* macOS is limited.
- The tuple is a zig tuple, not a gnu triple: it is `x86_64-linux-gnu`, not
  `x86_64-unknown-linux-gnu`.
- Check what zig itself supports with `zig targets` when a tuple is rejected.
