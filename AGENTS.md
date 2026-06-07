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
yuegui-moonbit-ssg/         ← workspace root (moon.work)
  yuegui/                   ← engine: Anxiu0101/yuegui
    moon.mod
    cmd/main/main.mbt       ← dev entry: @yuegui.dispatch(default_yuegui_config())
    core/                   → pure content model, YueguiConfig, diagnostics
    cli/                    → command parsing + build pipeline
    runtime/                → filesystem I/O via moonbitlang/x/fs
    theme/                  → template engine + asset copier
    format_markdown/        → Markdown parser/renderer
    format_typst/           → Typst adapter (experimental stub)
  site/                     ← official docs site
  moon.work                 ← enables local dependency resolution
```

Key architectural decisions (documented in `docs/development-logs/`):
- **Config in code**: no config file — `YueguiConfig` is a MoonBit struct passed to `@yuegui.dispatch({...})` in user's `main.mbt`
- **WASM by default**: `moon run . -- build` uses WASM backend, no C compiler needed, file I/O works via WASI
- **Native only for serve**: HTTP preview server needs C FFI (socket/thread); `build`/`check`/`init` all work on WASM
- **User site is a MoonBit project**: `my-site/` has `moon.mod` + `main.mbt` + `moon.pkg`, depends on `Anxiu0101/yuegui`
- **Workspace development**: `moon.work` at root lets `site/` test against local yuegui without publishing

## Essential Commands

### From workspace root (`yuegui-moonbit-ssg/`)

```bash
# Engine: build / check / test
moon -C yuegui run cmd/main -- build        # build demo content
moon -C yuegui run cmd/main -- check        # validate only
moon -C yuegui run cmd/main -- init x       # test scaffolding
moon -C yuegui check                        # type-check all packages
moon -C yuegui test                         # run tests
moon -C yuegui info && moon -C yuegui fmt   # regenerate .mbti + format

# Site docs (uses local yuegui via workspace)
moon -C site run . -- build                 # build site docs
moon -C site run . -- check                 # validate site docs
```

### Inside a directory directly

```bash
cd yuegui && moon run cmd/main -- build     # same as moon -C yuegui ...
cd site && moon run . -- build              # same as moon -C site ...
```

### User site workflow (inside my-site/)

```bash
yuegui build    # = moon run . -- build (WASM)
yuegui check    # = moon run . -- check
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
