///|
/// Build/check pipeline: discover -> parse -> index -> validate -> report.

///|
/// Run dev server: build + serve + watch for rebuild.
pub fn run_dev(config : @core.YueguiConfig) -> Unit {
  let out_dir = config.output_dir
  println("dev: building site...")
  run_build(config)
  println("dev: initial build complete")
  @runtime.watch_dir(config.source_dir, fn() { run_build(config) })
  @runtime.start_dev_server(config.dev_host, config.dev_port, out_dir)
}

///|
/// Run a full build: discover -> parse -> index -> validate -> render -> theme -> emit.
pub fn run_build(config : @core.YueguiConfig) -> Unit {
  let content_dir = config.source_dir
  let files = try? @runtime.walk_dir(content_dir)
  let files = match files {
    Ok(f) => f
    Err(_) => {
      println("build: error reading '\{content_dir}/'")
      return
    }
  }
  if files.length() == 0 {
    println("build: no files found in '\{content_dir}/'")
    return
  }

  let docs : Array[@core.ParsedDocument] = []
  for file in files {
    let format = detect_source_format(file)
    let content = try? @runtime.read_file(file)
    match (format, content) {
      (Some(fmt), Ok(body)) => {
        let frontmatter : Map[String, String] = {}
        let source : @core.SourceDocument = {
          path: file,
          format: fmt,
          frontmatter,
          body,
        }
        let parsed = parse_document(source)
        docs.push(parsed)
      }
      (None, _) => docs.push(unsupported_doc(file))
      (_, Err(_)) => println("build: error reading '\{file}'")
    }
  }

  let site = build_index_with_html(docs, config.source_dir)
  let site = @core.check_route_collisions(site)
  let site = @core.check_broken_links(site)
  let site = @core.check_missing_titles(site)

  let has_errors = has_fatal(site.diagnostics)
  if has_errors {
    println("build: stopping due to validation errors")
    return
  }

  let msg = "build: typst mode=\"" +
    config.typst_mode +
    "\" (fallback=\"" +
    config.typst_fallback +
    "\")"
  println(msg)

  // Auto-navigation: check conflict, then scan if enabled
  let has_manual_nav = config.navigation.nav.length() > 0 ||
    config.navigation.sidebar.keys().count() > 0
  if config.auto_navigation {
    if has_manual_nav {
      println(
        "warning: auto_navigation=true but manual navigation has values; using manual navigation. Set auto_navigation=false to suppress.",
      )
    } else {
      println("build: auto-navigation scanning \{config.source_dir}/...")
      scan_and_write_nav(config.source_dir, "mbt")
    }
  }

  let layouts = @theme.load_layouts(config.theme_dir)
  let slot_diags = @core.check_template_slots(layouts)
  for diag in slot_diags {
    println("warning[" + diag.code + "]: " + diag.message)
  }

  emit_site(site, config)
}

///|
/// Run a full content check (no output).
pub fn run_check(config : @core.YueguiConfig) -> Unit {
  let content_dir = config.source_dir
  let files = try? @runtime.walk_dir(content_dir)
  let files = match files {
    Ok(f) => f
    Err(_) => {
      println("check: error reading '\{content_dir}/'")
      return
    }
  }
  if files.length() == 0 {
    println("check: no files found in '\{content_dir}/'")
    return
  }

  let docs : Array[@core.ParsedDocument] = []
  for file in files {
    let format = detect_source_format(file)
    let content = try? @runtime.read_file(file)
    match (format, content) {
      (Some(fmt), Ok(body)) => {
        let frontmatter : Map[String, String] = {}
        let source : @core.SourceDocument = {
          path: file,
          format: fmt,
          frontmatter,
          body,
        }
        let parsed = parse_document(source)
        docs.push(parsed)
      }
      (None, _) => docs.push(unsupported_doc(file))
      (_, Err(_)) => println("check: error reading '\{file}'")
    }
  }

  let site = build_index(docs, config.source_dir)
  let site = @core.check_route_collisions(site)
  let site = @core.check_broken_links(site)
  let site = @core.check_missing_titles(site)
  report_diagnostics(site)
}

///|
fn detect_source_format(path : String) -> @core.SourceFormat? {
  if path.has_suffix(".md") {
    Some(@core.SourceFormat::Markdown)
  } else if path.has_suffix(".typ") {
    Some(@core.SourceFormat::Typst)
  } else if path.has_suffix(".html") {
    Some(@core.SourceFormat::Html)
  } else {
    None
  }
}

///|
fn unsupported_doc(file : String) -> @core.ParsedDocument {
  let source : @core.SourceDocument = {
    path: file,
    format: @core.SourceFormat::Html,
    frontmatter: {},
    body: "",
  }
  let caps : @core.RenderCapabilities = {
    format: @core.SourceFormat::Html,
    mode: @core.RenderMode::SemanticHtml,
    fidelity: @core.FidelityLevel::Unknown,
    warnings: [],
  }
  let diag = @core.warning(
    @core.E004_UNKNOWN_FORMAT,
    file,
    None,
    None,
    "Unsupported file format '\{file}', skipping.",
  )
  {
    source,
    title: None,
    headings: [],
    links: [],
    assets: [],
    diagnostics: [diag],
    render_capabilities: caps,
  }
}

///|
fn parse_document(source : @core.SourceDocument) -> @core.ParsedDocument {
  match source.format {
    @core.SourceFormat::Markdown => @format_markdown.parse(source)
    @core.SourceFormat::Typst => @format_typst.parse(source)
    @core.SourceFormat::Html => {
      let caps : @core.RenderCapabilities = {
        format: @core.SourceFormat::Html,
        mode: @core.RenderMode::SemanticHtml,
        fidelity: @core.FidelityLevel::Full,
        warnings: [],
      }
      {
        source,
        title: None,
        headings: [],
        links: [],
        assets: [],
        diagnostics: [],
        render_capabilities: caps,
      }
    }
  }
}

///|
fn build_index(
  docs : Array[@core.ParsedDocument],
  source_dir : String,
) -> @core.Site {
  let pages : Map[String, @core.SitePage] = {}
  let routes : Array[String] = []
  let all_diagnostics : Array[@core.Diagnostic] = []

  for doc in docs {
    let route = @core.filepath_to_route(doc.source.path, source_dir)
    routes.push(route)
    let title = match doc.title {
      Some(t) => t
      None => ""
    }
    let page : @core.SitePage = {
      route,
      title,
      content_html: "",
      source_format: doc.source.format,
      metadata: extract_page_meta(doc),
      outgoing_links: [],
      headings: doc.headings,
    }
    pages.set(route, page)
    for diag in doc.diagnostics {
      all_diagnostics.push(diag)
    }
  }

  { pages, routes, diagnostics: all_diagnostics }
}

///|
fn build_index_with_html(
  docs : Array[@core.ParsedDocument],
  source_dir : String,
) -> @core.Site {
  let pages : Map[String, @core.SitePage] = {}
  let routes : Array[String] = []
  let all_diagnostics : Array[@core.Diagnostic] = []

  // First pass: compute routes and build link index (route → route, slug → route)
  let link_index : Map[String, String] = {}
  for doc in docs {
    let route = @core.filepath_to_route(doc.source.path, source_dir)
    routes.push(route)
    link_index.set(route, route)
    let slug = path_to_slug(doc.source.path)
    link_index.set(slug, route)

    let title = match doc.title {
      Some(t) => t
      None => ""
    }
    let placeholder : @core.SitePage = {
      route,
      title,
      content_html: "",
      source_format: doc.source.format,
      metadata: extract_page_meta(doc),
      outgoing_links: [],
      headings: doc.headings,
    }
    pages.set(route, placeholder)
    for diag in doc.diagnostics {
      all_diagnostics.push(diag)
    }
  }

  // Second pass: render HTML with wikilink resolution, resolve outgoing links
  for doc in docs {
    let route = @core.filepath_to_route(doc.source.path, source_dir)
    let html = render_body_html(doc, link_index)
    let internal_links = resolve_internal_links(doc.links, link_index)
    let existing = pages[route]
    let page : @core.SitePage = {
      route: existing.route,
      title: existing.title,
      content_html: html,
      source_format: existing.source_format,
      metadata: existing.metadata,
      outgoing_links: internal_links,
      headings: existing.headings,
    }
    pages.set(route, page)
  }

  { pages, routes, diagnostics: all_diagnostics }
}

///|
/// Extract the filename stem (without extension) from a content path to use as a link key.
fn path_to_slug(path : String) -> String {
  // Normalise backslashes to forward slashes
  let normalised = path.replace(old="\\", new="/")
  let last_slash = find_char_rev(normalised, "/")
  let basename = if last_slash >= 0 {
    normalised[last_slash + 1:].to_owned()
  } else {
    normalised
  }
  let dot = find_char(basename, ".")
  if dot >= 0 {
    basename[:dot].to_owned()
  } else {
    basename
  }
}

///|
/// Find the last occurrence of a character in a string, return index or -1.
fn find_char_rev(s : String, ch : String) -> Int {
  let len = s.length()
  for i = len - 1; i >= 0; i = i - 1 {
    if s[i:i + 1] == ch {
      return i
    }
  }
  -1
}

///|

///|
/// Resolve internal links through the link index, producing resolved route targets.
fn resolve_internal_links(
  links : Array[@core.Link],
  link_index : Map[String, String],
) -> Array[String] {
  let result : Array[String] = []
  for link in links {
    match link.kind {
      @core.LinkKind::Internal(target) => {
        // Try direct lookup first, then fall back to link_index
        let resolved = link_index.get_or_default(target, "")
        if resolved != "" {
          result.push(resolved)
        } else {
          // Keep unresolved links so check_broken_links can flag them
          result.push(target)
        }
      }
      _ => ()
    }
  }
  result
}

///|
fn render_body_html(
  doc : @core.ParsedDocument,
  link_index : Map[String, String],
) -> String {
  match doc.source.format {
    @core.SourceFormat::Markdown => {
      let resolved = @format_markdown.resolve_wikilinks(
        doc.source.body,
        link_index,
      )
      @format_markdown.render(resolved)
    }
    @core.SourceFormat::Typst => @format_typst.render(doc)
    @core.SourceFormat::Html => doc.source.body
  }
}

///|
fn extract_page_meta(doc : @core.ParsedDocument) -> @core.PageMetadata {
  let title = match doc.title {
    Some(t) => t
    None => ""
  }
  let fm = doc.source.frontmatter
  {
    title,
    description: fm.get("description"),
    date: fm.get("date"),
    author: fm.get("author"),
    tags: parse_tags(fm.get_or_default("tags", "")),
    draft: fm.get_or_default("draft", "false") == "true",
    layout: fm.get_or_default("layout", "default"),
    weight: parse_int_core(fm.get_or_default("weight", "0")),
  }
}

///|
/// Parse tags from a string: comma-separated or space-separated list.
fn parse_tags(raw : String) -> Array[String] {
  if raw.length() == 0 {
    return []
  }
  let result : Array[String] = []
  // Try comma-separated first
  if raw.find(",") != None {
    let parts = raw.split(",")
    for part in parts {
      let trimmed = part.trim()
      if trimmed.length() > 0 {
        result.push(trimmed.to_owned())
      }
    }
  } else {
    // Space-separated
    let parts = raw.split(" ")
    for part in parts {
      let trimmed = part.trim()
      if trimmed.length() > 0 {
        result.push(trimmed.to_owned())
      }
    }
  }
  result
}

///|
/// Parse an integer from a string, returning 0 on failure.
fn parse_int_core(s : String) -> Int {
  let len = s.length()
  let mut result = 0
  let mut negative = false
  for i = 0; i < len; i = i + 1 {
    let ch = s[i:i + 1]
    if i == 0 && ch == "-" {
      negative = true
    } else if ch >= "0" && ch <= "9" {
      result = result * 10 + (ch[0].to_int() - 48)
    }
  }
  if negative {
    -result
  } else {
    result
  }
}

///|
fn report_diagnostics(site : @core.Site) -> Unit {
  if site.diagnostics.length() == 0 {
    println("check: no issues found!")
    return
  }
  let mut err_count = 0
  let mut warn_count = 0
  let mut info_count = 0
  for diag in site.diagnostics {
    let label = match diag.level {
      @core.DiagnosticLevel::Error => "error"
      @core.DiagnosticLevel::Warning => "warning"
      @core.DiagnosticLevel::Info => "info"
    }
    let loc = diag.file_path
    println("\{label}[\{diag.code}]: \{loc}: \{diag.message}")
    match diag.level {
      @core.DiagnosticLevel::Error => err_count = err_count + 1
      @core.DiagnosticLevel::Warning => warn_count = warn_count + 1
      @core.DiagnosticLevel::Info => info_count = info_count + 1
    }
  }
  println("")
  println(
    "check: \{err_count} error(s), \{warn_count} warning(s), \{info_count} info(s)",
  )
  if err_count > 0 {
    abort("check failed with errors")
  }
}

///|
fn has_fatal(diagnostics : Array[@core.Diagnostic]) -> Bool {
  for diag in diagnostics {
    match diag.level {
      @core.DiagnosticLevel::Error => return true
      _ => ()
    }
  }
  false
}

///|
/// Emit site: apply theme, write output files.
fn emit_site(site : @core.Site, config : @core.YueguiConfig) -> Unit {
  let out_dir = config.output_dir
  let _ = try? @runtime.create_dir(out_dir)
  let _ = try? @runtime.create_dir(out_dir + "/assets")
  let _ = try? @runtime.create_dir(out_dir + "/assets/theme")

  @theme.copy_assets(config.theme_dir, out_dir)

  let layouts = @theme.load_layouts(config.theme_dir)
  let default_layout_tpl = match layouts.get("default") {
    Some(l) => l
    None => get_default_layout()
  }
  let post_layout_tpl = match layouts.get("post") {
    Some(l) => l
    None => get_post_layout()
  }

  for route, page in site.pages {
    let layout_name = page.metadata.layout
    let page_layout = if layout_name == "post" {
      post_layout_tpl
    } else {
      default_layout_tpl
    }
    let page_ctx = build_template_context(site, Some(page), config)
    let html = @theme.render(page_layout, page_ctx)
    let page_dir = out_dir + route
    let page_dir = if page_dir.has_suffix("/") {
      page_dir
    } else {
      page_dir + "/"
    }
    ignore(try? @runtime.create_dir(page_dir))
    let output_path = page_dir + "index.html"
    ignore(try? @runtime.write_file(output_path, html))
  }

  ignore(
    try? @runtime.write_file(
      out_dir + "/sitemap.xml",
      build_sitemap(site, config),
    ),
  )
  ignore(
    try? @runtime.write_file(
      out_dir + "/search-index.json",
      build_search_index(site),
    ),
  )
  ignore(
    try? @runtime.write_file(out_dir + "/manifest.json", build_manifest(site)),
  )

  println("build: site emitted to " + out_dir + "/")
}

///|
/// Build manifest.json with page count and build metadata.
fn build_manifest(site : @core.Site) -> String {
  let count = site.routes.length()
  let buf = @builtin.StringBuilder::new()
  buf.write_string("{\n")
  buf.write_string("  \"pages\": ")
  buf.write_string(count.to_string())
  buf.write_string(",\n")
  buf.write_string("  \"updated\": \"2026-06-01\",\n")
  buf.write_string("  \"generator\": \"yuegui 0.1.0\"\n")
  buf.write_string("}\n")
  buf.to_string()
}

///|
/// Build sitemap.xml.
fn build_sitemap(site : @core.Site, config : @core.YueguiConfig) -> String {
  let base_url = config.base_url
  let buf = @builtin.StringBuilder::new()
  buf.write_string("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  buf.write_string(
    "<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">\n",
  )
  for _route, page in site.pages {
    let p = page.route
    buf.write_string("  <url><loc>\{base_url}\{p}</loc></url>\n")
  }
  buf.write_string("</urlset>\n")
  buf.to_string()
}

///|
/// Build search-index.json.
fn build_search_index(site : @core.Site) -> String {
  let buf = @builtin.StringBuilder::new()
  buf.write_string("[")
  let mut first = true
  for _route, page in site.pages {
    if !first {
      buf.write_string(",\n")
    }
    first = false
    buf.write_string("  {\"title\":\"")
    buf.write_string(escape_json(page.title))
    buf.write_string("\",\"route\":\"")
    buf.write_string(escape_json(page.route))
    buf.write_string("\"}")
  }
  buf.write_string("\n]\n")
  buf.to_string()
}

///|
/// Build the default layout template string (flat keys).
fn get_default_layout() -> String {
  let b = @builtin.StringBuilder::new()
  b.write_string("<!DOCTYPE html>\n")
  b.write_string("<html lang=\"{{ site_language }}\">\n")
  b.write_string("<head>\n")
  b.write_string("  <meta charset=\"UTF-8\">\n")
  b.write_string(
    "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n",
  )
  b.write_string("  <title>{{ page_title }} — {{ site_title }}</title>\n")
  b.write_string("  {{#if page_description}}\n")
  b.write_string(
    "  <meta name=\"description\" content=\"{{ page_description }}\">\n",
  )
  b.write_string("  {{/if}}\n")
  b.write_string(
    "  <link rel=\"stylesheet\" href=\"/assets/theme/style.css\">\n",
  )
  b.write_string(
    "  <link rel=\"stylesheet\" href=\"/assets/theme/prism.css\">\n",
  )
  b.write_string("</head>\n")
  b.write_string("<body>\n")
  b.write_string("  <header>\n")
  b.write_string("    <nav>\n")
  b.write_string("      <a href=\"/\">{{ site_title }}</a>\n")
  b.write_string("      {{#each site_nav}}\n")
  b.write_string("        {{#if text}}\n")
  b.write_string("          <a href=\"{{ url }}\">{{ text }}</a>\n")
  b.write_string("        {{/if}}\n")
  b.write_string("      {{/each}}\n")
  b.write_string("    </nav>\n")
  b.write_string("  </header>\n")
  b.write_string("  <main>\n")
  b.write_string("    <article>\n")
  b.write_string("      {{ page_content }}\n")
  b.write_string("    </article>\n")
  b.write_string("  </main>\n")
  b.write_string("  <footer>\n")
  b.write_string(
    "    <p>Built with <a href=\"https://github.com/Anxiu0101/yuegui\">Yuegui</a>.</p>\n",
  )
  b.write_string("  </footer>\n")
  b.write_string("  <script src=\"/assets/theme/prism.js\"></script>\n")
  b.write_string("</body>\n")
  b.write_string("</html>\n")
  b.to_string()
}

///|
/// Build a post layout template with date/author header.
fn get_post_layout() -> String {
  let b = @builtin.StringBuilder::new()
  b.write_string("<!DOCTYPE html>\n")
  b.write_string("<html lang=\"{{ site_language }}\">\n")
  b.write_string("<head>\n")
  b.write_string("  <meta charset=\"UTF-8\">\n")
  b.write_string(
    "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n",
  )
  b.write_string("  <title>{{ page_title }} — {{ site_title }}</title>\n")
  b.write_string("  {{#if page_description}}\n")
  b.write_string(
    "  <meta name=\"description\" content=\"{{ page_description }}\">\n",
  )
  b.write_string("  {{/if}}\n")
  b.write_string(
    "  <link rel=\"stylesheet\" href=\"/assets/theme/style.css\">\n",
  )
  b.write_string(
    "  <link rel=\"stylesheet\" href=\"/assets/theme/prism.css\">\n",
  )
  b.write_string("</head>\n")
  b.write_string("<body>\n")
  b.write_string("  <header>\n")
  b.write_string("    <nav>\n")
  b.write_string("      <a href=\"/\">{{ site_title }}</a>\n")
  b.write_string("      <a href=\"/blog/\">Blog</a>\n")
  b.write_string("    </nav>\n")
  b.write_string("  </header>\n")
  b.write_string("  <main>\n")
  b.write_string("    <article class=\"post\">\n")
  b.write_string("      <header class=\"post-header\">\n")
  b.write_string("        <h1>{{ page_title }}</h1>\n")
  b.write_string(
    "        {{#if page_date}}<time>{{ page_date }}</time>{{/if}}\n",
  )
  b.write_string(
    "        {{#if page_author}}<span class=\"author\">by {{ page_author }}</span>{{/if}}\n",
  )
  b.write_string("      </header>\n")
  b.write_string("      <div class=\"post-content\">{{ page_content }}</div>\n")
  b.write_string("    </article>\n")
  b.write_string("  </main>\n")
  b.write_string("  <footer>\n")
  b.write_string(
    "    <p>Built with <a href=\"https://github.com/Anxiu0101/yuegui\">Yuegui</a>.</p>\n",
  )
  b.write_string("  </footer>\n")
  b.write_string("  <script src=\"/assets/theme/prism.js\"></script>\n")
  b.write_string("</body>\n</html>\n")
  b.to_string()
}

///|
/// Build template context from site and optional page.
fn build_template_context(
  site : @core.Site,
  page : @core.SitePage?,
  config : @core.YueguiConfig,
) -> @theme.TemplateContext {
  let ctx = @theme.context()
  @theme.set(ctx, "site_title", @theme.str(config.title))
  @theme.set(ctx, "site_language", @theme.str(config.language))
  let page_maps : Array[Map[String, @theme.ContextValue]] = []
  for _route, p in site.pages {
    let pm : Map[String, @theme.ContextValue] = {}
    pm.set("title", @theme.str(p.title))
    pm.set("route", @theme.str(p.route))
    page_maps.push(pm)
  }
  @theme.set(ctx, "site_pages", @theme.arr(page_maps))

  // Navigation
  let nav_maps : Array[Map[String, @theme.ContextValue]] = []
  for item in config.navigation.nav {
    let item_map = nav_item_to_map(item)
    nav_maps.push(item_map)
  }
  @theme.set(ctx, "site_nav", @theme.arr(nav_maps))

  match page {
    Some(p) => {
      @theme.set(ctx, "page_title", @theme.str(p.title))
      @theme.set(ctx, "page_content", @theme.str(p.content_html))
      @theme.set(ctx, "page_route", @theme.str(p.route))
      match p.metadata.description {
        Some(d) => @theme.set(ctx, "page_description", @theme.str(d))
        None => ()
      }
      match p.metadata.date {
        Some(d) => @theme.set(ctx, "page_date", @theme.str(d))
        None => ()
      }
      match p.metadata.author {
        Some(a) => @theme.set(ctx, "page_author", @theme.str(a))
        None => ()
      }
    }
    None => ()
  }
  ctx
}

///|
fn escape_json(s : String) -> String {
  let buf = @builtin.StringBuilder::new()
  let len = s.length()
  for i = 0; i < len; i = i + 1 {
    let ch = s[i:i + 1]
    if ch == "\"" {
      buf.write_string("\\\"")
    } else if ch == "\\" {
      buf.write_string("\\\\")
    } else if ch == "\n" {
      buf.write_string("\\n")
    } else {
      buf.write_string(ch.to_owned())
    }
  }
  buf.to_string()
}

///|
/// Convert a NavItem to a template context map.
fn nav_item_to_map(item : @core.NavItem) -> Map[String, @theme.ContextValue] {
  let m : Map[String, @theme.ContextValue] = {}
  match item {
    @core.NavItem::Link(text, url) => {
      m.set("type", @theme.str("link"))
      m.set("text", @theme.str(text))
      m.set("url", @theme.str(url))
    }
    @core.NavItem::Group(text, children) => {
      m.set("type", @theme.str("group"))
      m.set("text", @theme.str(text))
      let child_maps : Array[Map[String, @theme.ContextValue]] = []
      for child in children {
        child_maps.push(nav_item_to_map(child))
      }
      m.set("children", @theme.arr(child_maps))
    }
    @core.NavItem::Separator => m.set("type", @theme.str("separator"))
  }
  m
}

///|
/// Scan content/ and write nav.mbt (or nav.toml).
/// Called by both auto_navigation (build) and `yuegui post-scan`.
pub fn scan_and_write_nav(source_dir : String, format : String) -> Unit {
  let files = try? @runtime.walk_dir(source_dir)
  let files = match files {
    Ok(f) => f
    Err(_) => {
      println("scan: error reading '\{source_dir}/'")
      return
    }
  }
  let nav_items : Array[FlatNavEntry] = []
  for file in files {
    if !file.has_suffix(".md") &&
      !file.has_suffix(".typ") &&
      !file.has_suffix(".html") {
      continue
    }
    let rel = file[source_dir.length() + 1:].to_owned()
    let content = try? @runtime.read_file(file)
    let content = match content {
      Ok(c) => c
      Err(_) => continue
    }
    let (meta_title, draft, _published) = extract_frontmatter_meta(content)
    if draft {
      continue
    }
    let title = match meta_title {
      Some(t) => t
      None => {
        let dot = find_char(rel, ".")
        if dot >= 0 {
          rel[:dot].to_owned()
        } else {
          rel
        }
      }
    }
    let route = "/" + rel
    let route = if route.has_suffix(".md") ||
      route.has_suffix(".typ") ||
      route.has_suffix(".html") {
      route[:route.length() - 3].to_owned()
    } else {
      route
    }
    let route = if route.has_suffix("/index") {
      route[:route.length() - 6].to_owned()
    } else {
      route
    }
    let route = route + "/"
    nav_items.push({ title, route })
  }
  if format == "toml" {
    write_nav_toml(nav_items)
  } else {
    write_nav_mbt(nav_items)
  }
  println("scan: found \{nav_items.length()} pages")
}

///|
/// A flat navigation entry from content scanning.
priv struct FlatNavEntry {
  title : String
  route : String
}

///|
/// Split a string into lines (newline-separated).
fn split_lines(s : String) -> Array[String] {
  let result : Array[String] = []
  let len = s.length()
  let mut start = 0
  for i = 0; i < len; i = i + 1 {
    if s[i:i + 1] == "\n" {
      result.push(s[start:i].to_owned())
      start = i + 1
    }
  }
  if start < len {
    result.push(s[start:].to_owned())
  }
  result
}

///|
/// Find first occurrence of a single-char string, return index or -1.
fn find_char(s : String, ch : String) -> Int {
  let len = s.length()
  for i = 0; i < len; i = i + 1 {
    if s[i:i + 1] == ch {
      return i
    }
  }
  -1
}

///|
/// Extract title, draft, published from frontmatter (TOML between +++ delimiters).
fn extract_frontmatter_meta(content : String) -> (String?, Bool, Bool) {
  let lines = split_lines(content)
  let n = lines.length()
  if n < 3 {
    return (None, false, true)
  }
  if lines[0] != "+++" && lines[0] != "---" {
    return (None, false, true)
  }
  let delim = lines[0]
  let mut title : String? = None
  let mut draft = false
  let mut published = true
  for i = 1; i < n; i = i + 1 {
    if lines[i] == delim {
      break
    }
    let line = lines[i]
    if line[:5] == "title" {
      let eq = find_char(line, "=")
      if eq >= 0 {
        let val = line[eq + 1:].to_owned()
        let val = trim_leading_space(val)
        let val = unquote(val)
        title = Some(val)
      }
    } else if line == "draft = true" || line == "draft=true" {
      draft = true
    } else if line == "published = false" || line == "published=false" {
      published = false
    }
  }
  (title, draft, published)
}

///|
/// Trim leading whitespace from a string.
fn trim_leading_space(s : String) -> String {
  let len = s.length()
  let mut i = 0
  while i < len && (s[i:i + 1] == " " || s[i:i + 1] == "\t") {
    i = i + 1
  }
  if i == 0 {
    s
  } else {
    s[i:].to_owned()
  }
}

///|
/// Remove surrounding double quotes if present.
fn unquote(s : String) -> String {
  let len = s.length()
  if len >= 2 && s[0:1] == "\"" && s[len - 1:len] == "\"" {
    s[1:len - 1].to_owned()
  } else {
    s
  }
}

///|
/// Write nav.mbt (MoonBit format) from scanned entries.
fn write_nav_mbt(entries : Array[FlatNavEntry]) -> Unit {
  let buf = @builtin.StringBuilder::new()
  buf.write_string(
    "////\n/// Auto-generated by `yuegui post-scan`. DO NOT EDIT.\n/// Re-run `yuegui post-scan` to regenerate.\n////\n\n",
  )
  buf.write_string("fn auto_navigation() -> @yuegui.NavigationConfig {\n")
  buf.write_string("  {\n")
  buf.write_string("    nav: [\n")
  for entry in entries {
    let label = entry.title
    let link = entry.route
    buf.write_string("      Link(\"\{label}\", \"\{link}\"),\n")
  }
  buf.write_string("    ],\n")
  buf.write_string("    sidebar: {},\n")
  buf.write_string("  }\n")
  buf.write_string("}\n")
  let _ = try? @runtime.write_file("nav.mbt", buf.to_string())
  println("scan: wrote nav.mbt")
}

///|
/// Write nav.toml from scanned entries.
fn write_nav_toml(entries : Array[FlatNavEntry]) -> Unit {
  let buf = @builtin.StringBuilder::new()
  buf.write_string(
    "# Auto-generated by `yuegui post-scan`. DO NOT EDIT.\n# Re-run `yuegui post-scan` to regenerate.\n\n",
  )
  for entry in entries {
    buf.write_string("[[nav]]\n")
    buf.write_string("text = \"\{entry.title}\"\n")
    buf.write_string("link = \"\{entry.route}\"\n\n")
  }
  let _ = try? @runtime.write_file("nav.toml", buf.to_string())
  println("scan: wrote nav.toml")
}
