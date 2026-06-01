///|
/// Build/check pipeline: discover -> parse -> index -> validate -> report.

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
      (None, _) => println("build: unsupported format '\{file}', skipping")
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
      (None, _) => println("check: unsupported format '\{file}', skipping")
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
    let page : @core.SitePage = {
      route,
      title,
      content_html: html,
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
  // 1. Create output directory
  let _ = try? @runtime.write_file("public/", "")

  // 2. For each page, render through theme and write
  let layout = get_default_layout()

  for route, page in site.pages {
    // create page-specific context
    let page_ctx = build_template_context(site, Some(page))
    let html = @theme.render(layout, page_ctx)
    // write to public/{route}/index.html
    let output_path = "public\{route}index.html"
    let _ = try? @runtime.write_file(output_path, html)
  }

  // 3. Emit sitemap
  let _ = try? @runtime.write_file("public/sitemap.xml", build_sitemap(site))

  // 4. Emit search index
  let _ = try? @runtime.write_file(
    "public/search-index.json",
    build_search_index(site),
  )

  println("build: site emitted to public/")
}

///|
/// Build the default layout template string.
fn get_default_layout() -> String {
  let b = @builtin.StringBuilder::new()
  b.write_string("<!DOCTYPE html>\n")
  b.write_string("<html lang=\"en\">\n")
  b.write_string("<head><meta charset=\"UTF-8\">\n")
  b.write_string("<title>{{ page_title }} - {{ site_title }}</title></head>\n")
  b.write_string("<body><main>{{ page_content }}</main></body>\n")
  b.write_string("</html>\n")
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
