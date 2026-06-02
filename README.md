# Yuegui

**MoonBit-native static site generator for technical publishing.**

[![Module](https://img.shields.io/badge/module-Anxiu0101%2Fyuegui-blue)](https://github.com/Anxiu0101/yuegui)

Yuegui treats Markdown (stable) and Typst (experimental) as first-class source formats in a shared site graph. It provides strong build-time diagnostics and
emits fast static HTML.

![example page](./public/yuegui.jpg)

## Prerequisites

- [MoonBit](https://docs.moonbitlang.com) toolchain
- C compiler (`gcc` or MSVC `cl.exe`) — only needed for `dev`/`serve` (HTTP preview server)

## Quick Start

### As a user — create a new site

```bash
yuegui init my-site     # scaffold site project + wrapper scripts
cd my-site
moon update             # fetch dependencies
yuegui build            # build to public/  (WASM, no C compiler needed)
yuegui dev              # preview server    (needs `--target native`)
```

Your site is a MoonBit project:

```
my-site/
  moon.mod    ← dependency on Anxiu0101/yuegui
  main.mbt    ← @yuegui.dispatch({ title: "My Site", ... })
  moon.pkg    ← is-main: true
  yuegui.bat  ← wrapper: moon run . -- %*
  content/    ← markdown source files
  theme/      ← layout templates + assets
  public/     ← build output (gitignored)
```

The wrapper scripts (`yuegui.bat` / `yuegui.sh`) let you run `yuegui build`
instead of typing `moon run . -- build`.

### As a contributor — develop Yuegui engine

```bash
git clone https://github.com/Anxiu0101/yuegui
cd yuegui
moon run cmd/main -- build       # build the demo site content
moon run cmd/main -- check       # validate without output
moon run cmd/main -- init x      # test scaffolding
```

## CLI Commands

| Command | Description |
|---|---|
| `yuegui init <name>` | Scaffold a new site project |
| `yuegui build` | Build static site to output directory (configurable in `main.mbt`) |
| `yuegui check` | Validate content, report diagnostics |
| `yuegui dev` | Start preview server with live reload (needs native backend) |
| `yuegui new page <slug>` | Scaffold a new page stub |
| `yuegui new post <slug>` | Scaffold a new blog post stub |

All commands run via `moon run` (WASM backend) by default — no C compiler
needed. The `dev` command requires `--target native` for HTTP serving.

## Native Build

Build a standalone executable for environments without MoonBit toolchain:

```bash
moon build cmd/main --target native
```

Output: `_build/native/debug/build/cmd/main/main.exe`

**Note:** The native exe is currently affected by a
[`moonbitlang/x/fs` CWD bug on Windows](./docs/development-logs/moonbit-windows-native-compilation.md).
Running via `moon run` (WASM) is the recommended approach.

## Modules

```
core             Content model, diagnostics, route/link validation
format_markdown  Markdown parser and render adapter
format_typst     Typst adapter (experimental)
theme            Layout loader, template engine
runtime          Filesystem, server, watcher
cli              Command parsing and dispatch
```

## License

Apache-2.0
