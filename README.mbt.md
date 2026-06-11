# 月桂 Yuegui

**MoonBit-native static site generator for technical publishing.**

[![Module](https://img.shields.io/badge/module-Anxiu0101%2Fyuegui-blue)](https://mooncakes.io/packages/Anxiu0101/yuegui)

Yuegui treats Markdown (stable) and Typst (experimental) as first-class source
formats in a shared site graph. It provides strong build-time diagnostics and
emits fast static HTML.

### Features

- **CommonMark via mizchi/markdown** — GFM tables, strikethrough, fenced code with language annotations
- **Wikilinks** — `[[/page/]]` resolves to `<a href="/page/">` with build-time broken link detection
- **Heading anchors** — `<h1>`-`<h6>` automatically get `id` attributes for permalink support
- **Frontmatter metadata** — title, description, date, author, tags propagate from frontmatter to templates
- **Syntax highlighting** — Prism.js (MIT) bundled in default theme (bash, json, markup, css, yaml)
- **Diagnostics-first** — broken links, route collisions, missing frontmatter are build-time errors
- **Adapter architecture** — parsers, renderers, and themes are swappable interfaces

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
moon run cmd/main -- build       # build test content
moon run cmd/main -- check       # validate without output
moon run cmd/main -- init x      # test scaffolding
```

## API Overview

```mbt check
///|
test "dispatch accepts YueguiConfig" {
  let config : @core.YueguiConfig = {
    title: "test",
    description: "",
    language: "en",
    base_url: "",
    source_dir: "content",
    theme_dir: "theme",
    output_dir: "public",
    auto_navigation: false,
    navigation: { nav: [], sidebar: {} },
    markdown_extensions: {},
    plugins: [],
    extra: {},
    typst_mode: "semantic-html",
    typst_fallback: "svg-embed",
    dev_port: 3000,
    dev_host: "127.0.0.1",
  }
  ignore(config)
}
```

The `YueguiConfig` struct captures all site-level configuration.
Pass it to `@yuegui.dispatch()` in your site's `main.mbt`.

## CLI Commands

| Command | Description |
|---|---|
| `yuegui init <name>` | Scaffold a new site project |
| `yuegui build` | Build static site to output directory |
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

## Modules

```
core             Content model, diagnostics, route/link validation
format_markdown  Markdown parser and renderer (CommonMark via mizchi/markdown)
format_typst     Typst adapter (experimental)
theme            Layout loader, template engine, Prism.js syntax highlighting
runtime          Filesystem, server, watcher
cli              Command parsing and dispatch
```

## License

Yuegui is licensed under Apache-2.0.

Third-party software bundled in this project (see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)):
- PrismJS — MIT license
