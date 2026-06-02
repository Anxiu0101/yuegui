# Yuegui Project Guide

Module: `Anxiu0101/yuegui` — MoonBit-native static site generator.

Installed MoonBit skills (read these before guessing MoonBit behavior):
- `.agents/skills/moonbit-agent-guide/SKILL.md` — project layout, tooling, testing
- `.agents/skills/moonbit-orientation/SKILL.md` — language/toolchain orientation
- `.agents/skills/moonbit-c-binding/SKILL.md` — C FFI
- `.agents/skills/moonbit-refactoring/SKILL.md` — refactoring patterns
- `.agents/skills/moonbit-extract-spec-test/SKILL.md` — spec-driven testing

## Project Structure

```
yuegui/
  moon.mod             → module metadata + dependencies
  moon.pkg             → root package (re-exports dispatch for @yuegui.dispatch)
  yuegui.mbt           → root package: pub fn dispatch(config: SiteConfig)
  cmd/main/main.mbt    → dev entry: @cli.dispatch(@core.default_site_config())
  cmd/main/moon.pkg    → is-main: true
  core/                → pure content model, SiteConfig, diagnostics
  cli/                 → command parsing + build pipeline
  runtime/             → filesystem I/O via moonbitlang/x/fs
  theme/               → template engine + asset copier
  format_markdown/     → Markdown parser/renderer
  format_typst/        → Typst adapter (experimental stub)
```

Key architectural decisions (documented in `docs/development-logs/`):
- **Config in code**: no `yuegui.toml` — `SiteConfig` is a MoonBit struct passed to `@yuegui.dispatch({...})` in user's `main.mbt`
- **WASM by default**: `moon run . -- build` uses WASM backend, no C compiler needed, file I/O works via WASI
- **Native only for serve**: HTTP preview server needs C FFI (socket/thread); `build`/`check`/`init` all work on WASM
- **User site is a MoonBit project**: `my-site/` has `moon.mod` + `main.mbt` + `moon.pkg`, depends on `Anxiu0101/yuegui`

## Essential Commands

### Engine development (inside yuegui/)

```bash
moon run cmd/main -- build        # build demo content
moon run cmd/main -- check        # validate only
moon run cmd/main -- init x       # test scaffolding
moon run --target native cmd/main -- serve  # preview server
moon check                        # type-check all packages
moon test                         # run tests
moon info && moon fmt             # regenerate .mbti + format
```

### User site workflow (inside my-site/)

```bash
yuegui build    # = moon run . -- build (WASM)
yuegui check    # = moon run . -- check
yuegui dev      # = moon run --target native . -- serve
```

## Validation Loop

1. `moon check` — fast type-checking
2. `moon test` — run tests (use `--update` for snapshot changes)
3. `moon info && moon fmt` — regenerate interfaces + format
4. Review `pkg.generated.mbti` diffs to verify API changes are intentional

## Dependencies

- `moonbitlang/x@0.4.44` — filesystem I/O (`@fs`)
- `moonbitlang/core` — standard library (always available)
- `moonbitlang/core/argparse` — CLI argument parsing

## Development Log

Significant bugs, architectural decisions, and course corrections are recorded in:
- `docs/development-logs/moonbit-windows-native-compilation.md`
