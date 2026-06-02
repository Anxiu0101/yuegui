///|
/// Default scaffold templates for `yuegui init`.

///|
/// Template for moon.mod.
pub fn init_moon_mod(site_name : String) -> String {
  let buf = @builtin.StringBuilder::new()
  buf.write_string("name = \"\{site_name}\"\n")
  buf.write_string("\n")
  buf.write_string("version = \"0.1.0\"\n")
  buf.write_string("\n")
  buf.write_string("import {\n")
  buf.write_string("  \"Anxiu0101/yuegui\",\n")
  buf.write_string("}\n")
  buf.to_string()
}

///|
/// Template for moon.pkg.
pub fn init_moon_pkg() -> String {
  let buf = @builtin.StringBuilder::new()
  buf.write_string("import {\n")
  buf.write_string("  \"Anxiu0101/yuegui\",\n")
  buf.write_string("}\n")
  buf.write_string("\n")
  buf.write_string("options(\n")
  buf.write_string("  \"is-main\": true,\n")
  buf.write_string(")\n")
  buf.to_string()
}

///|
/// Template for main.mbt.
pub fn init_main_mbt(site_name : String) -> String {
  let buf = @builtin.StringBuilder::new()
  buf.write_string("fn main {\n")
  buf.write_string("  @yuegui.dispatch({\n")
  buf.write_string("    title: \"\{site_name}\",\n")
  buf.write_string("    base_url: \"\",\n")
  buf.write_string("    language: \"en\",\n")
  buf.write_string("    source_dir: \"content\",\n")
  buf.write_string("    theme_dir: \"theme\",\n")
  buf.write_string("    output_dir: \"public\",\n")
  buf.write_string("    typst_mode: \"semantic-html\",\n")
  buf.write_string("    typst_fallback: \"svg-embed\",\n")
  buf.write_string("    dev_port: 3000,\n")
  buf.write_string("    dev_host: \"127.0.0.1\",\n")
  buf.write_string("  })\n")
  buf.write_string("}\n")
  buf.to_string()
}

///|
/// Template for .gitignore.
pub fn init_gitignore() -> String {
  let buf = @builtin.StringBuilder::new()
  buf.write_string("_build/\n")
  buf.write_string(".mooncakes/\n")
  buf.write_string("public/\n")
  buf.write_string("*.exe\n")
  buf.to_string()
}

///|
/// Template for yuegui.bat.
pub fn init_yuegui_bat() -> String {
  "@echo off\r\nmoon run . -- %*\r\n"
}

///|
/// Template for yuegui.sh.
pub fn init_yuegui_sh() -> String {
  "#!/bin/sh\nexec moon run . -- \"$@\"\n"
}

///|
/// Template for yuegui.ps1.
pub fn init_yuegui_ps1() -> String {
  "moon run . -- @args\n"
}

///|
/// Template for content/index.md.
pub fn index_markdown(site_name : String) -> String {
  let buf = @builtin.StringBuilder::new()
  buf.write_string("+++\n")
  buf.write_string("title = \"\{site_name}\"\n")
  buf.write_string("description = \"Welcome to \{site_name}\"\n")
  buf.write_string("+++\n")
  buf.write_string("\n")
  buf.write_string("# Welcome to \{site_name}\n")
  buf.write_string("\n")
  buf.write_string(
    "This site was built with **[Yuegui](https://github.com/Anxiu0101/yuegui)**.\n",
  )
  buf.write_string("\n")
  buf.write_string("## Getting Started\n")
  buf.write_string("\n")
  buf.write_string("Create new pages in the `content/` directory.\n")
  buf.write_string("\n")
  buf.write_string("- Markdown files use `.md` extension.\n")
  buf.write_string("- Typst files use `.typ` extension.\n")
  buf.write_string(
    "- Wikilinks: `[[getting-started]]` cross-reference pages.\n",
  )
  buf.write_string("\n")
  buf.write_string("Run `yuegui build` to build the site.\n")
  buf.to_string()
}

///|
/// Template for theme/layouts/default.html.
pub fn default_layout() -> String {
  let buf = @builtin.StringBuilder::new()
  buf.write_string("<!DOCTYPE html>\n")
  buf.write_string("<html lang=\"{{ site_language }}\">\n")
  buf.write_string("<head>\n")
  buf.write_string("  <meta charset=\"UTF-8\">\n")
  buf.write_string(
    "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n",
  )
  buf.write_string("  <title>{{ page_title }} — {{ site_title }}</title>\n")
  buf.write_string("  {{#if page_description}}\n")
  buf.write_string(
    "  <meta name=\"description\" content=\"{{ page_description }}\">\n",
  )
  buf.write_string("  {{/if}}\n")
  buf.write_string(
    "  <link rel=\"stylesheet\" href=\"/assets/theme/style.css\">\n",
  )
  buf.write_string("</head>\n")
  buf.write_string("<body>\n")
  buf.write_string("  <header>\n")
  buf.write_string("    <nav>\n")
  buf.write_string("      <a href=\"/\">{{ site_title }}</a>\n")
  buf.write_string("      {{#each site_pages}}\n")
  buf.write_string("        {{#if weight}}\n")
  buf.write_string("          <a href=\"{{ route }}\">{{ title }}</a>\n")
  buf.write_string("        {{/if}}\n")
  buf.write_string("      {{/each}}\n")
  buf.write_string("    </nav>\n")
  buf.write_string("  </header>\n")
  buf.write_string("  <main>\n")
  buf.write_string("    <article>\n")
  buf.write_string("      {{ page_content }}\n")
  buf.write_string("    </article>\n")
  buf.write_string("  </main>\n")
  buf.write_string("  <footer>\n")
  buf.write_string(
    "    <p>Built with <a href=\"https://github.com/Anxiu0101/yuegui\">Yuegui</a>.</p>\n",
  )
  buf.write_string("  </footer>\n")
  buf.write_string("</body>\n")
  buf.write_string("</html>\n")
  buf.to_string()
}

///|
/// Template for theme/layouts/post.html.
pub fn post_layout() -> String {
  let buf = @builtin.StringBuilder::new()
  buf.write_string("<!DOCTYPE html>\n")
  buf.write_string("<html lang=\"{{ site_language }}\">\n")
  buf.write_string("<head>\n")
  buf.write_string("  <meta charset=\"UTF-8\">\n")
  buf.write_string(
    "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n",
  )
  buf.write_string("  <title>{{ page_title }} — {{ site_title }}</title>\n")
  buf.write_string("  {{#if page_description}}\n")
  buf.write_string(
    "  <meta name=\"description\" content=\"{{ page_description }}\">\n",
  )
  buf.write_string("  {{/if}}\n")
  buf.write_string(
    "  <link rel=\"stylesheet\" href=\"/assets/theme/style.css\">\n",
  )
  buf.write_string("</head>\n")
  buf.write_string("<body>\n")
  buf.write_string("  <header>\n")
  buf.write_string("    <nav>\n")
  buf.write_string("      <a href=\"/\">{{ site_title }}</a>\n")
  buf.write_string("      <a href=\"/blog/\">Blog</a>\n")
  buf.write_string("    </nav>\n")
  buf.write_string("  </header>\n")
  buf.write_string("  <main>\n")
  buf.write_string("    <article class=\"post\">\n")
  buf.write_string("      <header class=\"post-header\">\n")
  buf.write_string("        <h1>{{ page_title }}</h1>\n")
  buf.write_string(
    "        {{#if page_date}}<time>{{ page_date }}</time>{{/if}}\n",
  )
  buf.write_string(
    "        {{#if page_author}}<span class=\"author\">by {{ page_author }}</span>{{/if}}\n",
  )
  buf.write_string("      </header>\n")
  buf.write_string(
    "      <div class=\"post-content\">{{ page_content }}</div>\n",
  )
  buf.write_string("    </article>\n")
  buf.write_string("  </main>\n")
  buf.write_string("  <footer>\n")
  buf.write_string(
    "    <p>Built with <a href=\"https://github.com/Anxiu0101/yuegui\">Yuegui</a>.</p>\n",
  )
  buf.write_string("  </footer>\n")
  buf.write_string("</body>\n")
  buf.write_string("</html>\n")
  buf.to_string()
}

///|
/// Template for theme/assets/style.css.
pub fn default_stylesheet() -> String {
  let buf = @builtin.StringBuilder::new()
  buf.write_string(":root {\n")
  buf.write_string(
    "  --font-sans: system-ui, -apple-system, Segoe UI, Roboto, sans-serif;\n",
  )
  buf.write_string("  --color-text: #1a1a2e;\n")
  buf.write_string("  --color-bg: #ffffff;\n")
  buf.write_string("  --color-accent: #2563eb;\n")
  buf.write_string("  --color-muted: #6b7280;\n")
  buf.write_string("  --max-width: 720px;\n")
  buf.write_string("}\n")
  buf.write_string("\n")
  buf.write_string(
    "*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }\n",
  )
  buf.write_string("\n")
  buf.write_string(
    "html { font-size: 16px; line-height: 1.7; color: var(--color-text); background: var(--color-bg); }\n",
  )
  buf.write_string("\n")
  buf.write_string(
    "body { font-family: var(--font-sans); max-width: var(--max-width); margin: 0 auto; padding: 2rem 1.5rem; }\n",
  )
  buf.write_string("\n")
  buf.write_string(
    "h1, h2, h3 { line-height: 1.3; margin-top: 2rem; margin-bottom: 0.75rem; font-weight: 600; }\n",
  )
  buf.write_string(
    "h1 { font-size: 2rem; } h2 { font-size: 1.5rem; } h3 { font-size: 1.25rem; }\n",
  )
  buf.write_string("\n")
  buf.write_string("p { margin-bottom: 1rem; }\n")
  buf.write_string("a { color: var(--color-accent); text-decoration: none; }\n")
  buf.write_string("a:hover { text-decoration: underline; }\n")
  buf.write_string(
    "code { font-family: var(--font-mono); font-size: 0.875em; }\n",
  )
  buf.write_string(
    "pre { background: #f3f4f6; border-radius: 8px; padding: 1rem; overflow-x: auto; }\n",
  )
  buf.write_string("ul, ol { margin-bottom: 1rem; padding-left: 1.5rem; }\n")
  buf.write_string(
    "footer { margin-top: 4rem; padding-top: 1.5rem; border-top: 1px solid #e5e7eb; text-align: center; font-size: 0.875rem; }\n",
  )
  buf.to_string()
}

///|
/// Template for content/{slug}/index.md.
pub fn page_template(slug : String) -> String {
  let buf = @builtin.StringBuilder::new()
  buf.write_string("+++\n")
  buf.write_string("title = \"\{slug}\"\n")
  buf.write_string("description = \"\"\n")
  buf.write_string("+++\n")
  buf.write_string("\n")
  buf.write_string("# \{slug}\n")
  buf.write_string("\n")
  buf.write_string("Write your content here.\n")
  buf.to_string()
}

///|
/// Template for content/blog/{post-slug}/index.md.
pub fn post_template(slug : String) -> String {
  let buf = @builtin.StringBuilder::new()
  buf.write_string("+++\n")
  buf.write_string("title = \"\{slug}\"\n")
  buf.write_string("description = \"\"\n")
  buf.write_string("date = \"2026-06-01\"\n")
  buf.write_string("author = \"\"\n")
  buf.write_string("layout = \"post\"\n")
  buf.write_string("+++\n")
  buf.write_string("\n")
  buf.write_string("# \{slug}\n")
  buf.write_string("\n")
  buf.write_string("Write your post here.\n")
  buf.to_string()
}
