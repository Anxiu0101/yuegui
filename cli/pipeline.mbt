///|
/// Build/check pipeline: discover -> parse -> index -> validate -> report.

///|
/// Run dev server: build + serve + watch for rebuild.
pub fn run_dev() -> Unit {
  // First build
  println("dev: building site...")
  run_build()
  println("dev: initial build complete")

  // Start file watcher (stub on wasm-gc)
  @runtime.watch_dir("content", fn() { run_build() })
  @runtime.start_dev_server("127.0.0.1", 3000, "public/")
}

///|
/// Run a full build: discover -> parse -> index -> validate -> render -> theme -> emit.
pub fn run_build() -> Unit {
  let content_dir = "content"
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

  // 1-2. Parse and render all files
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

  // 3. Build index with rendered bodies
  let site = build_index_with_html(docs)

  // 4. Validate
  let site = @core.check_route_collisions(site)
  let site = @core.check_broken_links(site)
  let site = @core.check_missing_titles(site)

  // Report validation errors and stop if fatal
  let has_errors = has_fatal(site.diagnostics)
  if has_errors {
    println("build: stopping due to validation errors")
    return
  }

  // 6-7. Apply theme and emit
  emit_site(site)
}

///|
/// Run a full content check (no output).
pub fn run_check() -> Unit {
  let content_dir = "content"
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

  let site = build_index(docs)
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
/// Build a dummy ParsedDocument for unsupported files (emits E004).
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
fn build_index(docs : Array[@core.ParsedDocument]) -> @core.Site {
  let pages : Map[String, @core.SitePage] = {}
  let routes : Array[String] = []
  let all_diagnostics : Array[@core.Diagnostic] = []

  for doc in docs {
    let route = @core.filepath_to_route(doc.source.path)
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
/// Build site index with rendered HTML bodies.
fn build_index_with_html(docs : Array[@core.ParsedDocument]) -> @core.Site {
  let pages : Map[String, @core.SitePage] = {}
  let routes : Array[String] = []
  let all_diagnostics : Array[@core.Diagnostic] = []

  for doc in docs {
    let route = @core.filepath_to_route(doc.source.path)
    routes.push(route)
    let title = match doc.title {
      Some(t) => t
      None => ""
    }
    // render body HTML
    let html = render_body_html(doc)
    let internal_links = collect_internal_links(doc.links)
    let page : @core.SitePage = {
      route,
      title,
      content_html: html,
      source_format: doc.source.format,
      metadata: extract_page_meta(doc),
      outgoing_links: internal_links,
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
/// Collect internal link targets from a list of links.
fn collect_internal_links(links : Array[@core.Link]) -> Array[String] {
  let result : Array[String] = []
  for link in links {
    match link.kind {
      @core.LinkKind::Internal(target) => result.push(target)
      _ => ()
    }
  }
  result
}

///|
/// Render a ParsedDocument's body to HTML based on format.
fn render_body_html(doc : @core.ParsedDocument) -> String {
  match doc.source.format {
    @core.SourceFormat::Markdown => @format_markdown.render(doc)
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
  {
    title,
    description: None,
    date: None,
    author: None,
    tags: [],
    draft: false,
    layout: "default",
    weight: 0,
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
/// Emit site: apply theme, write public/ files.
fn emit_site(site : @core.Site) -> Unit {
  // Copy theme assets to public/
  @theme.copy_assets("theme", "public")

  let layouts = @theme.load_layouts("theme")
  let default_layout = match layouts.get("default") {
    Some(l) => l
    None => get_default_layout()
  }
  let post_layout = match layouts.get("post") {
    Some(l) => l
    None => get_post_layout()
  }

  // For each page, render through theme and write
  for route, page in site.pages {
    let layout_name = page.metadata.layout
    let page_layout = if layout_name == "post" {
      post_layout
    } else {
      default_layout
    }
    let page_ctx = build_template_context(site, Some(page))
    let html = @theme.render(page_layout, page_ctx)
    let output_path = "public\{route}index.html"
    ignore(try? @runtime.write_file(output_path, html))
  }

  // Sitemap
  ignore(try? @runtime.write_file("public/sitemap.xml", build_sitemap(site)))

  // Search index
  ignore(
    try? @runtime.write_file(
      "public/search-index.json",
      build_search_index(site),
    ),
  )

  // Manifest
  ignore(try? @runtime.write_file("public/manifest.json", build_manifest(site)))

  println("build: site emitted to public/")
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
  b.write_string("  <title>{{ page_title }} - {{ site_title }}</title>\n")
  b.write_string("  {{#if page_description}}\n")
  b.write_string(
    "  <meta name=\"description\" content=\"{{ page_description }}\">\n",
  )
  b.write_string("  {{/if}}\n")
  b.write_string(
    "  <link rel=\"stylesheet\" href=\"/assets/theme/style.css\">\n",
  )
  b.write_string("</head>\n")
  b.write_string("<body>\n")
  b.write_string(
    "  <header><nav><a href=\"/\">{{ site_title }}</a></nav></header>\n",
  )
  b.write_string("  <main><article>{{ page_content }}</article></main>\n")
  b.write_string(
    "  <footer><p>Built with <a href=\"https://github.com/kozmosa/yuegui\">Yuegui</a>.</p></footer>\n",
  )
  b.write_string("</body>\n</html>\n")
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
  b.write_string("  <title>{{ page_title }} - {{ site_title }}</title>\n")
  b.write_string("  {{#if page_description}}\n")
  b.write_string(
    "  <meta name=\"description\" content=\"{{ page_description }}\">\n",
  )
  b.write_string("  {{/if}}\n")
  b.write_string(
    "  <link rel=\"stylesheet\" href=\"/assets/theme/style.css\">\n",
  )
  b.write_string("</head>\n")
  b.write_string("<body>\n")
  b.write_string(
    "  <header><nav><a href=\"/\">{{ site_title }}</a> <a href=\"/blog/\">Blog</a></nav></header>\n",
  )
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
  b.write_string(
    "  <footer><p>Built with <a href=\"https://github.com/kozmosa/yuegui\">Yuegui</a>.</p></footer>\n",
  )
  b.write_string("</body>\n</html>\n")
  b.to_string()
}

///|
/// Build template context from site and optional page.
fn build_template_context(
  site : @core.Site,
  page : @core.SitePage?,
) -> @theme.TemplateContext {
  let ctx = @theme.context()
  // site vars
  @theme.set(ctx, "site_title", @theme.str("My Site"))
  @theme.set(ctx, "site_language", @theme.str("en"))
  // pages list for {{#each site_pages}}
  let page_maps : Array[Map[String, @theme.ContextValue]] = []
  for _route, p in site.pages {
    let pm : Map[String, @theme.ContextValue] = {}
    pm.set("title", @theme.str(p.title))
    pm.set("route", @theme.str(p.route))
    page_maps.push(pm)
  }
  @theme.set(ctx, "site_pages", @theme.arr(page_maps))

  // page vars
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
/// Build sitemap.xml.
fn build_sitemap(site : @core.Site) -> String {
  let buf = @builtin.StringBuilder::new()
  buf.write_string("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  buf.write_string(
    "<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">\n",
  )
  for _route, page in site.pages {
    let p = page.route
    buf.write_string("  <url><loc>https://example.com\{p}</loc></url>\n")
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
