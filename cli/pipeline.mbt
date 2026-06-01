///|
/// Build/check pipeline: discover -> parse -> index -> validate -> report.

///|
/// Run a full content check.
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
